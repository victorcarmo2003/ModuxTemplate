--!strict
-- ANM-009 The knock (anomalies.md N9; npcs.md NPC-017; architecture.md §19.13; FEAT-019; DEC-054, DEC-204, DEC-254,
-- DEC-255; TASK-117; TASK-333, owner 2026-10-15). Rule in Rules/ANM-009.luau. V2 family D (DEC-254): a scare whose
-- only answer is NOT opening the back door. Sound only on the server (Actor Audio, NpcCost 0); the one knocking is a
-- client-only figure outside the back door that only camera 2 shows (Effects/ANM-009, TASK-285 SecurityCam).
--
--   Start    Phase Active, Step 1, cue knock (Entity 1: "Rookie? It's me. It's Walt. Open up."). "Seen" (AudioZone,
--            FEAT-019): every active player in the trailer zone when the first knock sounds gets ctx.See.
--   Second   SecondAt s: Step 2, cue knock (Entity 2: "It's cold out here, Rookie.").
--   Door     from the start until Window + DoorGrace s: whoever OPENS the back door (Action trailer_exit / trailer_enter
--            with the leaf open, TrailerDoorService) is scared AT ONCE: cue jumpscare (Entity = UserId % 65536, only
--            that client shows the face), cue door_crack (napkins fly in), ScareFaint s later VitalService:Fall.
--            Once per player per occurrence; Phase Failed.
--   End      Window + DoorGrace + LeaveFor s: Phase Resolved when nobody opened (Failed otherwise), Linger s, Finish.
--   Stop     nothing to undo.
-- PROVISIONAL (TASK-333): the old shutter test at the end is gone (the window does nothing now); not opening is the
-- answer. The door service is resolved from its module like ANM-004 does.
--
-- Lock (TASK-592, owner 2026-10-19; PROVISIONAL Q-398): the answer is to RUN AND LOCK the back door. At the start the
-- door turns lockable (RestaurantDoorService:SetLockable: its prompt reads "Lock Door", hold 1 s); the first player who
-- locks it publishes Anchor = 1 (the client hears the bolt; the heavy blows then end on the latch holding). Series 1 and
-- 2 are normal, series 3 (Params Series3At) is the heavy one: HeavyHits blows HeavyGap s apart, each one bulging the door
-- (scene Door Bulge). Not locked by LockBy (the heavy series' start) = the prompt goes back to Open Door and on the last
-- blow (BurstAt) the door bursts open (SetOpen true, cue door_crack) and every active player gets the error below.
-- Opening the door by hand while it is not lockable still scares who opened. Stop releases the lock (the door is a door
-- again).
--
-- Restaurant (TASK-561, owner 2026-10-18; design/anomalies-v3-restaurant.md §8.3): the back door is DOOR-B, opened by
-- hand (RestaurantDoorService). At the start the door is shut if someone left it open (the draught slams it). Four
-- series instead of two (Params Series2At / Series3At / Series4At): far and soft, closer, Walt's voice, the voice
-- wrong; the scene (Content.HorrorScenes anm_009_knock) builds the silence, the handle and the latch over them.
-- "Seen" = every active player (the whole building hears it). Opening = jumpscare + -Sanity.RuleBroken through
-- ctx.Fail (DEC-277: no faint by itself), not VitalService:Fall.
-- Leaving (owner 2026-10-19): at Window + DoorGrace it gives up but is still there: the last soft knock, the steps and
-- its shadow sliding out of the gap (scene steps at 22 s) for LeaveFor s, Phase still Active, so opening the door
-- still scares. Only then Resolved (Failed otherwise); the record stays Linger s so the release plays, then Finish.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Kit.CustomerActor)

const REF = "ANM-009"
const SCARE_CUE = "jumpscare"
const ENTITY_MOD = 65536 -- AnomalyCue.Entity is 0..65535
const DOOR_ACTIONS: { [string]: boolean } = { door_toggle = true }
-- Defaults when Rules/ANM-009 is missing (same numbers as the rule file)
const DEFAULT_WINDOW = 13
const DEFAULT_SECOND_AT = 10.8
const DEFAULT_GRACE = 2
const DEFAULT_LEAVE_FOR = 4
const DEFAULT_LINGER = 4.5
const DEFAULT_SCARE_FAINT = 0.5
const DEFAULT_ZONE_POINT = "TRL"
const DEFAULT_ZONE_RADIUS = 24
const DEFAULT_SERIES3_AT = 10
const DEFAULT_HEAVY_HITS = 3
const DEFAULT_HEAVY_GAP = 1.2
const DEFAULT_LOCK_BY = 10
const LOCKED_ANCHOR = 1 -- record Anchor once someone locked the door (Effects/ANM-009)

type RestaurantDoor = {
	IsOpen: (self: any, mapId: string?) -> boolean,
	SetOpen: (self: any, mapId: string, open: boolean, player: Player?) -> (),
	SetLockable: (self: any, reason: string, on: boolean) -> (),
	IsLockedByHand: (self: any) -> boolean,
	LockedBy: { Connect: (self: any, fn: (player: Player, mapId: string) -> ()) -> { Disconnect: (self: any) -> () } },
}

type State = {
	SecondAt: number,
	EndsAt: number, -- the door stops biting: Resolved / Failed
	Linger: number,
	FinishAt: number?, -- set at EndsAt
	ScareFaint: number,
	ZonePoint: string,
	ZoneRadius: number,
	Second: boolean,
	Series: { number }, -- restaurant: absolute times of series 2.. (cue knock Entity = index + 1)
	NextSeries: number,
	Scared: { [number]: boolean },
	AnyFailed: boolean,
	-- TASK-592: the lock
	LockBy: number, -- absolute: the lock stops counting (the heavy series)
	BurstAt: number, -- absolute: the last heavy blow; not locked = the door gives
	Lockable: boolean,
	Locked: boolean,
	Burst: boolean,
	Connection: { Disconnect: (self: any) -> () }?,
}

-- restaurant (owner 2026-10-18): the back door is RestaurantDoorService's DOOR-B, opened by hand (door_toggle)
local restaurantCache: RestaurantDoor? = nil
local function restaurantDoor(): RestaurantDoor
	if restaurantCache == nil then
		restaurantCache = (require :: any)(ServerScriptService.server.Vehicle.RestaurantDoorService) :: RestaurantDoor
	end
	return restaurantCache :: RestaurantDoor
end

local function param(rule: Api.Rule?, name: string, default: number): number
	if rule == nil then
		return default
	end
	const value = rule.Params[name]
	return if type(value) == "number" and value == value and value >= 0 and value ~= math.huge then value else default
end

local function text(rule: Api.Rule?, name: string, default: string): string
	if rule == nil then
		return default
	end
	const value = rule.Params[name]
	return if type(value) == "string" and value ~= "" then value else default
end

local function inZone(ctx: Api.Context, state: State, player: Player): boolean
	return true
end

-- Restaurant series 2.. as absolute times; a time past the window or out of order is dropped
local function seriesTimes(rule: Api.Rule?, startedAt: number, window: number): { number }
	const out: { number } = {}
	local last = 0
	for index = 2, 4 do
		const at = param(rule, `Series{index}At`, -1)
		if at <= last or at > window then
			continue
		end
		last = at
		table.insert(out, startedAt + at)
	end
	return out
end

-- V2 error (DEC-255): the face for the one who opened, the napkins for everyone, then the faint.
local function scare(ctx: Api.Context, occ: Api.Occurrence, state: State, player: Player)
	const userId = player.UserId
	if state.Scared[userId] then
		return
	end
	state.Scared[userId] = true
	if not state.AnyFailed then
		state.AnyFailed = true
		ctx.Publish(occ, { Phase = "Failed" })
		ctx.Cue(occ, "door_crack", 0)
	end
	ctx.Cue(occ, SCARE_CUE, userId % ENTITY_MOD, userId)
	ctx.Fail(occ, { player }) -- DEC-277: -35, falls only at zero
end

const Knock: Api.Module = {
	Ref = REF,

	Start = function(ctx: Api.Context, occ: Api.Occurrence): boolean
		const rule = ctx.Rule(REF)
		const window = if rule ~= nil and rule.Window > 0 then rule.Window else DEFAULT_WINDOW
		const state: State = {
			SecondAt = occ.StartedAt + math.min(param(rule, "SecondAt", DEFAULT_SECOND_AT), window),
			EndsAt = occ.StartedAt
				+ window
				+ param(rule, "DoorGrace", DEFAULT_GRACE)
				+ param(rule, "LeaveFor", DEFAULT_LEAVE_FOR),
			Linger = param(rule, "Linger", DEFAULT_LINGER),
			ScareFaint = param(rule, "ScareFaint", DEFAULT_SCARE_FAINT),
			ZonePoint = text(rule, "ZonePoint", DEFAULT_ZONE_POINT),
			ZoneRadius = param(rule, "ZoneRadius", DEFAULT_ZONE_RADIUS),
			Second = false,
			Series = seriesTimes(rule, occ.StartedAt, window),
			NextSeries = 1,
			Scared = {},
			AnyFailed = false,
			LockBy = occ.StartedAt + math.min(param(rule, "LockBy", DEFAULT_LOCK_BY), window),
			BurstAt = occ.StartedAt
				+ math.min(
					param(rule, "Series3At", DEFAULT_SERIES3_AT)
						+ math.max(param(rule, "HeavyHits", DEFAULT_HEAVY_HITS) - 1, 0)
							* param(rule, "HeavyGap", DEFAULT_HEAVY_GAP),
					window
				),
			Lockable = false,
			Locked = false,
			Burst = false,
			Connection = nil,
		}
		occ.State = state
		-- nobody knocks on an open door: the draught slams it shut first
		const mapId = Content.Restaurant.ManualDoors[1]
		const door = restaurantDoor()
		if mapId ~= nil and door:IsOpen(mapId) then
			door:SetOpen(mapId, false, nil)
			ctx.Log(occ, `{mapId} was open: shut at the start`)
		end
		-- TASK-592: the prompt turns into "Lock Door" until LockBy
		door:SetLockable(REF, true)
		state.Lockable = true
		state.Connection = door.LockedBy:Connect(function(player: Player, _mapId: string)
			if occ.State ~= state or state.Locked or state.AnyFailed then
				return
			end
			state.Locked = true
			ctx.Publish(occ, { Anchor = LOCKED_ANCHOR })
			ctx.Log(occ, `{player.Name} locked the back door`)
		end)
		ctx.Publish(occ, { Phase = "Active", Step = 1, Anchor = 0 })
		ctx.Cue(occ, "knock", 1)
		-- AudioZone "seen": in the zone of the sound when it starts (the first knock)
		for _, player in ctx.Active() do
			if inZone(ctx, state, player) then
				ctx.See(occ, player)
			end
		end
		return true
	end,

	Tick = function(ctx: Api.Context, occ: Api.Occurrence, now: number)
		const state = occ.State :: State
		const at = state.Series[state.NextSeries]
		if at ~= nil and now >= at then
			state.NextSeries += 1
			ctx.Publish(occ, { Step = state.NextSeries })
			ctx.Cue(occ, "knock", state.NextSeries)
		end
		-- TASK-592: too late to lock once the heavy series starts; not locked = the door gives on its last blow
		if state.Lockable and not state.Locked and now >= state.LockBy then
			state.Lockable = false
			restaurantDoor():SetLockable(REF, false)
		end
		if not state.Locked and not state.Burst and state.FinishAt == nil and now >= state.BurstAt then
			state.Burst = true
			const mapId = Content.Restaurant.ManualDoors[1]
			if mapId ~= nil then
				restaurantDoor():SetOpen(mapId, true, nil)
			end
			for _, player in ctx.Active() do
				scare(ctx, occ, state, player)
			end
		end
		const finishAt = state.FinishAt
		if finishAt ~= nil then
			if now >= finishAt then
				ctx.Finish(occ)
			end
			return
		end
		if now < state.EndsAt then
			return
		end
		state.FinishAt = now + state.Linger
		if not state.AnyFailed then
			ctx.Succeed(occ)
		end
	end,

	-- Opening the back door while it knocks: scared at once (TASK-333)
	OnEvent = function(ctx: Api.Context, occ: Api.Occurrence, event: Api.Event)
		const state = occ.State :: State?
		if state == nil or state.FinishAt ~= nil or event.Kind ~= "Action" or not DOOR_ACTIONS[event.Action] then
			return
		end
		const open = restaurantDoor():IsOpen(nil)
		if open and not state.Locked then
			scare(ctx, occ, state, event.Player)
		end
	end,

	Stop = function(_ctx: Api.Context, occ: Api.Occurrence, _reason: Api.StopReason)
		const state = occ.State :: State?
		if state ~= nil then
			const connection = state.Connection
			if connection ~= nil then
				connection:Disconnect()
			end
			-- the door is a door again (a lock made by hand goes with the last lockable reason)
			restaurantDoor():SetLockable(REF, false)
		end
		occ.State = nil
	end,
}

return Knock
