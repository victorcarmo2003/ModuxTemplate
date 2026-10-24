--!strict
-- Contract of AnomalyService/Anomalies/*.luau and Rules/*.luau (architecture.md §19.13, T10, T43; FEAT-022, 023, 024;
-- DEC-054, DEC-074, DEC-204; TASK-106). Pure: no Modux, Lync or Charm, so modules require it for the types without
-- requiring the service.
--
-- A module is one file per anomaly, named by its Ref (Anomalies/ANM-007.luau), discovered by the service at OnInit
-- (files whose name starts with "_" are skipped: _Example.luau is the reference module). New anomaly = new file in
-- Anomalies/ (+ its rule in Rules/); the AnomalyService init is never edited.
--
-- Life of an occurrence (the scheduler, or the dev command, decides when):
--   Start(ctx, occ) -> true      occurrence runs; Publish/Cue made inside Start go out only when it returns true
--   Start(ctx, occ) -> false     no slot/actor now: nothing is published, the scheduler tries again later
--   Tick(ctx, occ, now)          5 Hz while it runs
--   OnEvent(ctx, occ, event)     every Event while it runs (customer action, switch, discard, window, any action)
--   ctx.Finish(occ)              the module ends it: Stop(ctx, occ, "Done"), record removed shortly after
--   Stop(ctx, occ, reason)       called exactly once: "Done" (Finish), "NightOver" (6:00 AM), "Restore" (night lost,
--                                restore, new shift, dev stop). Undo what Start did (actors, Hush, Hold, Alter)
--
-- Who pays (DEC-204): ctx.Fail(occ, { player }) for an action (who acted); ctx.Fail(occ, "active") for an omission on
-- a party target (every Active member); a personal target fails each player that failed. A player pays at most once
-- per occurrence (FEAT-024). Common rule: -Sanity.RuleBroken each (VitalService:Penalize). Critical rule (only
-- ANM-007, Rules.IsCritical): RoundService:LoseNight("critical"), no 10 s window (DEC-094).
-- "Seen" (-Sanity.SeeAnomaly, once per anomaly per player per night): ctx.SeenTick for Cone anomalies (1 s
-- accumulated in the gaze cone), ctx.See for AudioZone (N9: in the zone when the sound starts).

-- Verbs (FEAT-023, DEC-054): exactly one per anomaly, in Rules/ only (T10: never on the client). "shutter" = close the
-- trailer service window (was "hide", DEC-221). "hide" (V2 family B, DEC-254; TASK-272) = leave the trailer by the back
-- door and stand in a HideZone behind it before the monster looks in (Anomalies/Kit/Hide.luau). "lock" (TASK-592,
-- PROVISIONAL Q-398) = run to the restaurant's back door and lock it by hand (RestaurantDoorService:SetLockable).
export type Verb = "refuse" | "serve" | "dont_look" | "light" | "shutter" | "discard" | "safe_spot" | "hide" | "lock"

-- Anomalies set record phase (network.md §13.5). "Queue" (owner 2026-10-22, Provisional; anomalies-after-accept-proposal.md
-- §9): a customer anomaly whose order was taken at the end of the talk waits in the delivery queue and its condition runs
-- (Anomalies/Kit/CustomerActor); the scene's tension plays there, not on arrival.
export type Phase = "Signal" | "Active" | "Queue" | "Resolved" | "Failed"

export type StopReason = "Done" | "NightOver" | "Restore"

-- One occurrence. Id = record id of the Anomalies set (1..255, cyclic per night). Rng is seeded from the run seed,
-- the shift and the schedule slot (same run = same draws). State belongs to the module.
export type Occurrence = {
	Id: number,
	Key: string,
	Ref: string,
	StartedAt: number,
	Rng: Random,
	State: any,
}

-- Events fanned out to every running occurrence (architecture.md §19.13). Source of each:
--   Customer  CustomerService.Acted (take_order, serve, refuse, give_up; give_up has no Player)
--   Switch    LightService.SwitchChanged
--   Discard   KitchenService.Discarded (TASK-109; absent until then)
--   Shutter   VehicleService.ShutterChanged (DEC-221; Player = who toggled, nil = automatic opening or dev)
--   Action    InteractionService.Performed (any validated action, after its Run)
export type Event =
	{ Kind: "Customer", Npc: number, Action: string, Player: Player?, Result: string? }
	| { Kind: "Switch", On: boolean, Player: Player? }
	| { Kind: "Discard", Player: Player, Item: string, Altered: boolean }
	| { Kind: "Shutter", Closed: boolean, Player: Player? }
	| { Kind: "Action", Player: Player, Action: string, Anchor: Instance, Id: number }

-- Fields a module may publish on its record. Step 0..20, Anchor 0..65535 (NpcId or anchor index).
export type Fields = { Phase: Phase?, Step: number?, Anchor: number? }

-- Spec for CustomerService:SpawnActor (TASK-108 owns the shape: Variant blank/mirror/raincoat...). Opaque here.
export type ActorSpec = { [string]: any }

export type Context = {
	-- server time (workspace:GetServerTimeNow)
	Now: () -> number,
	-- set Anomalies (record of this occurrence)
	Publish: (occ: Occurrence, fields: Fields) -> (),
	-- packet AnomalyCue to everyone (DEC-204). cue = a key of the anomaly's Cues; entity = NpcId/anchor index (0)
	-- user: full UserId of a personal cue (Entity = UserId % 65536), so a 16-bit twin never sees it (DEC-320, B-13)
	Cue: (occ: Occurrence, cue: string, entity: number?, user: number?) -> (),
	-- -RuleBroken each (once per player per occurrence); critical -> LoseNight("critical"). Party scope -> Phase Failed
	Fail: (occ: Occurrence, who: { Player } | "active") -> (),
	-- Phase Resolved
	Succeed: (occ: Occurrence) -> (),
	-- ends the occurrence (Stop "Done")
	Finish: (occ: Occurrence) -> (),
	-- FEAT-023 active player: connected, Active, with a character (a knocked player is active)
	Active: () -> { Player },
	-- gaze cone (Sanity.SeeAngle, or `angle` degrees full cone: ~90 = anywhere on screen) up to range + line of sight.
	-- Not Active, no fresh Gaze, or protected (window closed, inside the trailer) with the target outside = false
	Looking: (player: Player, target: Vector3, range: number, angle: number?) -> boolean,
	-- TASK-484: signed camera pitch in degrees (+ = up) of an Active player's latest Gaze; nil = no fresh Gaze, not
	-- Active or watching the security cameras (a screen, not the eyes)
	Pitch: (player: Player) -> number?,
	-- accumulates dt for every Active player Looking at target; Sanity.SeeTime reached -> VitalService:SeeAnomaly
	SeenTick: (occ: Occurrence, target: Vector3, range: number, dt: number) -> (),
	-- direct "seen" (AudioZone anomalies): VitalService:SeeAnomaly(player, key)
	See: (occ: Occurrence, player: Player) -> (),
	-- server rule row of an anomaly (key or Ref); nil = no rule file yet
	Rule: (anomaly: string) -> Rule?,
	-- CustomerService:SpawnActor (TASK-108). nil = refused or not available yet
	Spawn: (spec: ActorSpec) -> number?,
	Light: {
		BeginHush: (startedAt: number, holdUntil: number, postsOnly: boolean?) -> (),
		EndHush: () -> (),
		IsLit: (position: Vector3) -> boolean,
		IsSwitchOn: () -> boolean,
	},
	-- VehicleService service window (architecture.md §19.14, DEC-221). Protected = window closed and inside the trailer
	Vehicle: {
		IsShutterClosed: () -> boolean,
		IsInside: (player: Player) -> boolean,
		IsProtected: (player: Player) -> boolean,
	},
	-- Active player's root within radius (flat distance) of a MapPoint (safe spot "SS"; trailer zone "TRL")
	InZone: (player: Player, pointId: string, radius: number) -> boolean,
	-- KitchenService:Alter (TASK-109). false = refused or not available yet
	Kitchen: { Alter: (kind: "rail" | "board") -> boolean },
	-- TrafficService:Hold (TASK-104). No-op without it
	Traffic: { Hold: (reason: string, on: boolean) -> () },
	-- DEC-051: an anomaly customer is not an arrival; the module counts it (+ Wrong) only on a failure.
	-- AddSale (owner 2026-10-22, Provisional): extra money into Cash (EconomyService:AddSale "Sale"; the x2 of a customer
	-- anomaly served right); returns what went in (0 outside a selling phase or Closing)
	Economy: { CountArrival: () -> (), CountResult: (result: string) -> (), AddSale: (amount: number) -> number },
	-- warn with the module prefix
	Log: (occ: Occurrence, message: string) -> (),
}

export type Module = {
	Ref: string,
	Start: (ctx: Context, occ: Occurrence) -> boolean,
	Tick: ((ctx: Context, occ: Occurrence, now: number) -> ())?,
	OnEvent: ((ctx: Context, occ: Occurrence, event: Event) -> ())?,
	Stop: (ctx: Context, occ: Occurrence, reason: StopReason) -> (),
}

-- Rules/<Ref>.luau (content-data.md §6.10; server only, T10). Window = deadline in s (0 = none). Params = numbers of
-- the anomaly (N3 DarkHold, N6 LookLimit/AutoOff, N7 Steps/StepEvery/BackEvery...). IsCritical only on ANM-007.
export type Rule = {
	Anomaly: string,
	Verb: Verb,
	LikelyWrongVerb: string?,
	Window: number,
	IsCritical: boolean,
	Params: { [string]: any },
}

const VERBS: { [string]: boolean } = {
	refuse = true,
	serve = true,
	dont_look = true,
	light = true,
	shutter = true,
	discard = true,
	safe_spot = true,
	hide = true,
	lock = true,
}

const Api = {}

Api.Verbs = table.freeze(VERBS)

-- Validates a required Anomalies/* value. refs = Content.Anomalies rows by Ref. Returns the module or (nil, problem).
function Api.check(name: string, value: any, refs: { [string]: any }): (Module?, string?)
	if type(value) ~= "table" then
		return nil, `{name}: must return a table`
	end
	if type(value.Ref) ~= "string" or refs[value.Ref] == nil then
		return nil, `{name}: Ref "{tostring(value.Ref)}" is not a Ref of Content.Anomalies`
	end
	if type(value.Start) ~= "function" or type(value.Stop) ~= "function" then
		return nil, `{name}: Start and Stop must be functions`
	end
	if value.Tick ~= nil and type(value.Tick) ~= "function" then
		return nil, `{name}: Tick must be a function or nil`
	end
	if value.OnEvent ~= nil and type(value.OnEvent) ~= "function" then
		return nil, `{name}: OnEvent must be a function or nil`
	end
	return value :: Module, nil
end

return table.freeze(Api)
