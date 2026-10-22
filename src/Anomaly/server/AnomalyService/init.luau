--!strict
-- Anomaly core (architecture.md §19.13, T7, T10, T42, T43, T53; network.md §13.5; content-data.md §6.10; FEAT-019,
-- FEAT-022, FEAT-023, FEAT-024; DEC-025, DEC-045, DEC-054, DEC-060, DEC-073, DEC-074, DEC-094, DEC-195, DEC-204;
-- TASK-106). Run place only. Single writer of the Anomalies set (id = occurrence 1..255, cyclic per night), sender
-- of the AnomalyCue packet and responder of Gaze.
--
-- The core knows no anomaly. Each one is a module in Anomalies/<Ref>.luau (discovered at OnInit, contract in
-- Api.luau) with its server rule in Rules/<Ref>.luau (verb, window, params, IsCritical; T10). Without any module the
-- service runs empty: scheduled entries with no module are skipped silently.
--
--   Agenda      ShiftStarted of a night: Scheduler.Build (seed RunSeed, Day, Night, Attempt, "anomaly"); not in the
--               snapshot, a restore/repeat rebuilds it. During the Night phase (5 Hz) every due entry (At <= clock)
--               goes through Scheduler.Admit (MaxSimultaneous, MinGap, actor cap, ExclusiveWith) and module.Start;
--               Start false = retry in RETRY s; past the end of the window = dropped. Scripted entries are forced.
--   Context     one table of functions shared by every module (Api.Context): Publish (set), Cue (packet to
--               everyone, DEC-204), Fail (who pays, DEC-204; once per player per occurrence; critical ->
--               LoseNight("critical"), DEC-094), Succeed, Finish, Active, Looking (Gaze + Vision), Pitch (Gaze), SeenTick/See
--               (VitalService:SeeAnomaly), Rule, Spawn, Light, Vehicle, InZone, Kitchen, Traffic, Economy (AddSale:
--               the x2 of a customer anomaly served right, owner 2026-10-22). Wire phase "Queue": a customer anomaly
--               waiting for its order (Kit/CustomerActor conditions).
--   Stare       TASK-482 (DEC-294 §8; tech/stare-pressure.md): SeenTick of a row with Anomalies[k].Stare also counts
--               the continuous stare at the target in the narrow cone Sanity.Stare.Angle (Queue record only since
--               2026-10-22: a customer anomaly waiting for its order; the arrival is quiet). Looking
--               away Release s restarts the count. Past DrainAfter s the player loses PerSecond sanity per second
--               (whole points, the fraction carried), at most Cap per occurrence. The sight (SeeAnomaly, once per night
--               at SeeTime) comes first and is never repeated by the stare.
--   Events      CustomerService.Acted, LightService.SwitchChanged, InteractionService.Performed,
--               VehicleService.ShutterChanged (OnInit); KitchenService.Discarded when it exists (OnStart) -> OnEvent of
--               every running occurrence.
--   Gaze        c -> s, 10 Hz (network.md §13.5). Kept only from a member Active on a night shift; older than
--               GAZE_STALE s counts as not looking. Format check only (co-op, R10). A protected player (window closed
--               and inside the trailer, DEC-221) does not look at anything outside the trailer (architecture.md §19.14).
--   InZone      safe spot / trailer zone: flat distance from the root of an Active player to a MapPoint (owned here
--               since DEC-221).
--   Tension     signal Tension(on) while an occurrence of an anomaly with Anomalies[k].Tension runs; also
--               NpcService:SetTension(on) when it exists (TASK-108). PedestrianService listens to the signal.
--   Cleanup     NightEnd -> Stop(..., "NightOver"); NightLost, a new shift, any other phase -> "Restore"; set cleared.
--   Pressure    DEC-352 (Pressure.luau): by the sanity tier (Content.Sanity.Tiers), personal family D scares per player
--               and, by the crew's average, extra regular entries of tonight's pool queued like any other (Admit, grace,
--               window). Never under the tutorial hold.
--   Trip        Q-435 (Trip.luau, Content.Breaker): the breaker trips by itself a few times a night (LightService:
--               TripBreaker), only while no anomaly runs; not under the tutorial hold or the grace.
--   Beats       owner 2026-10-21 (Director.luau, Content.Nights.Beats, Provisional): one budget for everything that asks
--               the crew to act. Regular entries (not the fixed premiere, not scripted ones), trips, chores
--               (ChoreService) and suspense events (SuspenseService) ask BeatClear before they start and note it with
--               BeatBegin; Gap between two starts, MaxActive at once, the agenda first (Reserve).
--   Night event owner 2026-10-22 (Provisional; Scheduler.NightPool/NightAt, Content.Nights.Beats Night*): ONE mandatory
--               world event per night (a B/C/D anomaly with a verb; the breaker trip when none is open, Nights 1-2) at a
--               random minute, with priority over everything. StepNightEvent starts it whatever the grace, gap, caps,
--               window end and shut window say (it waits NightMaxWait s for a running anomaly, then goes anyway; a pool
--               key that ExclusiveWith something running is skipped, the last resort is the breaker). Its lock
--               (Director.lock: NightLead s before to NightTail s after) stops the rest: BeatClear refuses every kind
--               but "night", and the regular entries, the fixed premiere, the family D scares, the personal scares, the
--               trips and "behind you" wait. Still held by the dev hold and the tutorial.
--   Behind      owner 2026-10-21 (Behind.luau, Content.Nights.Behind, Provisional): in a calm stretch, a sound right
--               behind a player who cooks with the back to the window (a scripted behind_* family D scare, that
--               player only). Not a beat: no verb, no cost.
--   Ended       signal Ended(key, players) when an occurrence ends (Finish, NightOver, or a Restore once it left Signal or
--               someone failed): the members Active at its start plus whoever failed, still connected. Reader:
--               JournalService (TASK-335, TASK-345, Anomaly Tablet pages).
--
-- Hooks of services that do not exist yet (PROVISIONAL, TASK-106): TrafficService (TASK-104) is in
-- architecture.md §19.2 Require but was not in this build, so it is looked up by name at OnStart;
-- CustomerService:SpawnActor, NpcService:SetTension (TASK-108) and KitchenService:Alter/Discarded (TASK-109) are
-- used when the method/signal is there. Each missing hook degrades to "not available" (Spawn nil, Alter false,
-- Hold no-op). InteractionService is required beyond §19.2 for the Action event (Performed).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Sight = require(ReplicatedStorage.shared.Anomaly.Sight)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Api = require(script.Api)
local Rules = require(script.Rules)
local Scheduler = require(script.Scheduler)
local Pressure = require(script.Pressure)
local Trip = require(script.Trip)
local Director = require(script.Director)
local Behind = require(script.Behind)
local Vision = require(script.Vision)
local Modux = require(ServerScriptService.server.Modux)
local ModuxModules = require(ServerScriptService.server.Modux.Modules)

export type Occurrence = Api.Occurrence
export type Event = Api.Event
export type Context = Api.Context
export type Module = Api.Module
export type Rule = Api.Rule
export type Entry = Scheduler.Entry

-- Anomalies set record (network.md §13.5)
export type Wire = { Anomaly: string, Phase: Api.Phase, StartedAt: number, Step: number, Anchor: number }

-- Analytics trace of one occurrence (MetricsService funnel anomaly_<key>, owner 2026-10-20): Party = the run's UserIds
-- (shared table), Marks = seconds since StartedAt the first time each wire phase was reached, FailedAt = same per failure
export type Trace = {
	Key: string,
	Day: number,
	Night: number,
	Attempt: number,
	StartedAt: number,
	Party: { number },
	Marks: { [string]: number },
	FailedAt: { [number]: number },
}

export type Run = {
	Occ: Api.Occurrence,
	Row: Content.Anomaly,
	Module: Api.Module,
	Record: Wire,
	Added: boolean,
	Starting: boolean,
	FinishPending: boolean,
	Done: boolean,
	Cues: { { Cue: string, Entity: number, User: number? } },
	Failed: { [number]: boolean },
	CriticalSent: boolean,
	Seen: { [number]: number },
	SeenDone: { [number]: boolean },
	-- TASK-482 stare pressure per UserId (rows with Stare only)
	Stares: { [number]: Stare },
	-- UserIds Active when the occurrence started (Ended, TASK-335)
	Party: { number },
	Trace: Trace,
	-- Started was fired: Staged only follows it
	Announced: boolean,
}

export type Due = { Entry: Scheduler.Entry, RetryAt: number, Done: boolean }

-- The night's mandatory world event (owner 2026-10-22, Provisional). Phase: "none" (no agenda tonight) | "pending" |
-- "running" | "done". Pool = keys it may start, the drawn one first; the entry's key is "breaker" when the pool is empty
-- (the breaker trips instead). LockEndAt = server time the lock lets go (set when it starts).
export type NightEvent = {
	Entry: Scheduler.Entry?,
	Pool: { string },
	Phase: string,
	DueAt: number,
	StartedAt: number,
	RunId: number,
	LockEndAt: number,
}

export type Gaze = { Yaw: number, Pitch: number, At: number }

-- TASK-482: continuous stare of one player at one occurrence. Time = s staring, Away = s since the last stare,
-- Owed = sanity fraction not applied yet, Taken = sanity already drained by this occurrence
export type Stare = { Time: number, Away: number, Owed: number, Taken: number }

type TrafficHook = { Hold: (self: any, reason: string, on: boolean) -> () }

const TICK_RATE = 5 -- Hz (architecture.md §19.13: module Tick at 5 Hz)
const MAX_ID = 255 -- Anomalies record id range (network.md §13.5)
const STEP_MAX = 20 -- Anomalies.Step wire range
const ANCHOR_MAX = 65535 -- Anomalies.Anchor / AnomalyCue.Entity wire range
const SEED_MAX = 65535 -- AnomalyCue.Seed wire range
const RETRY = 1 -- s between two Start attempts of the same due entry (Start returned false)
const OPENING_AFTER = 2 -- game minutes into the Night phase before the scripted opening is sent (owner 2026-10-20, Q-415)
const LINGER = 1 -- s a finished record stays in the set so clients see its last Phase
-- s; the client sends at 10 Hz while the look changes, but a STILL look only every 1 s (CameraController
-- GAZE_HEARTBEAT) on an unreliable packet: a stale limit of 1 s dropped a steady stare between two heartbeats (ANM-006
-- only counted while the camera moved). Older than this = it stopped sending (day, not Active, not first person).
const GAZE_STALE = 1.6
const PITCH_STALE = 1.6 -- s; Pitch (TASK-484): a still look is resent only every 1 s (CameraController GAZE_HEARTBEAT)
const TARGET_SLACK = 2 -- studs; a hit this close to the target does not block the line of sight
const EYE_OFFSET = Vector3.new(0, 1.5, 0) -- HumanoidRootPart -> eye when the Head is missing
const DOMAIN = "anomaly"
const PRESSURE_DOMAIN = "pressure"
const TRIP_DOMAIN = "trip"
const BEHIND_DOMAIN = "behind"
const NIGHT_PHASE = "Night"
const PREFIX = "[AnomalyService]"

local function now(): number
	return workspace:GetServerTimeNow()
end

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function wireInt(value: number, low: number, high: number): number
	return math.clamp(math.floor(value), low, high)
end

-- Live Modux service by ID when it is in this build (no Require: TASK-104 did not exist yet). nil otherwise.
local function lookup(name: string): any
	for _, module in ModuxModules do
		if module.Name == name then
			const ok, service = pcall((require :: any), module)
			return if ok then service else nil
		end
	end
	return nil
end

-- Connects to a signal of a service that may not have it yet (TASK-109). nil signal = nothing to connect.
local function connectOptional(signal: any, name: string, handler: (...any) -> ())
	if signal == nil then
		return
	end
	const ok, problem = pcall(function()
		signal:Connect(handler)
	end)
	if not ok then
		warn(`[AnomalyService] could not connect to {name}: {problem}`)
	end
end

-- Content row by key, Ref (ANM-007) or night number ("7").
local function rowOf(text: string): Content.Anomaly?
	const byKey = Content.Anomalies.ByKey[text]
	if byKey ~= nil then
		return byKey
	end
	const upper = string.upper(text)
	const number = tonumber(text)
	for _, row in Content.Anomalies.List do
		if row.Ref == upper or (number ~= nil and row.Night == number) then
			return row
		end
	end
	return nil
end

local function candidate(row: Content.Anomaly): Scheduler.Candidate
	const scripted = row.Scripted
	return {
		Key = row.Key,
		Night = row.Night,
		NpcCost = row.NpcCost,
		ExclusiveWith = row.ExclusiveWith,
		Scripted = if scripted then { Night = scripted.Night, Clock = scripted.Clock } else nil,
		Family = row.Family,
		SkipAtmospheres = row.SkipAtmospheres,
		Actor = row.Actor,
	}
end

-- Key of the night event entry when no world anomaly is open tonight: the breaker trips instead
const NIGHT_BREAKER = "breaker"

local function newNightEvent(): NightEvent
	return { Entry = nil, Pool = {}, Phase = "none", DueAt = 0, StartedAt = 0, RunId = 0, LockEndAt = 0 }
end

const AnomalyService = Modux.Service("AnomalyService", {
	Require = {
		"PlaceService",
		"NetService",
		"RoundService",
		"RunStateService",
		"VitalService",
		"LightService",
		"CustomerService",
		"NpcService",
		"KitchenService",
		"ItemService",
		"EconomyService",
		"InteractionService",
		"VehicleService",
		"HallucinationService",
	},
	Priority = 570,
})

function AnomalyService:Setup()
	self.Enabled = false :: boolean
	-- Lync started and the Anomalies set is writable (OnStart)
	self.Live = false :: boolean
	-- discovered modules by anomaly key, and the reference module (dev "example")
	self.Modules = {} :: { [string]: Api.Module }
	self.Example = nil :: Api.Module?
	self.Context = nil :: Api.Context?
	-- agenda of the current night shift, in At order
	self.Queue = {} :: { Due }
	-- family D scares of the night (TASK-274): game minutes still to fire, ascending (V2, DEC-254)
	self.Scares = {} :: { number }
	-- owner 2026-10-20 (Provisional Q-415): the scripted opening of this night (Nights.Opening key), "" = none or played
	self.Opening = "" :: string
	-- server time before which no other family D scare is sent (one per Hallucinations.Rules.ScareGap, never a pile)
	self.NextScareAt = 0 :: number
	-- DEC-352 sanity pressure of the current night (personal scares, extra anomalies)
	self.Pressure = Pressure.new() :: Pressure.State
	-- Q-435 breaker trips of the current night
	self.Trip = Trip.new() :: Trip.State
	-- beat budget of the current night (Director.luau)
	self.Director = Director.new() :: Director.State
	-- the mandatory night event of the current night (owner 2026-10-22)
	self.NightEvent = newNightEvent() :: NightEvent
	-- "behind you" sounds of the current night (Behind.luau)
	self.Behind = Behind.new() :: Behind.State
	-- SecurityService, false when this build has none (IsWatching)
	self.Security = nil :: any
	self.Running = {} :: { [number]: Run }
	-- finished record id -> server time it leaves the set
	self.Removing = {} :: { [number]: number }
	self.NextId = 0 :: number
	-- server time of the last start (0 = none tonight)
	self.LastStartAt = 0 :: number
	-- shift the agenda belongs to (seeds of the occurrences)
	self.Shift = { Day = 1, Night = 0, IsNight = false, Attempt = 0 } :: { Day: number, Night: number, IsNight: boolean, Attempt: number }
	self.DevSerial = 0 :: number
	-- dev showcase: the natural agenda waits while true (ShowcaseService; never set outside dev mode)
	self.DevHeld = false :: boolean
	-- TutorialService (owner 2026-10-19): while it says so, no regular anomaly or scare starts (the tutorial customer comes first)
	self.Hold = nil :: (() -> boolean)?
	-- the Night phase of this shift has started (the agenda is dropped when it ends)
	self.InNight = false :: boolean
	self.Gazes = {} :: { [Player]: Gaze }
	self.TensionOn = false :: boolean
	self.Traffic = nil :: TrafficHook?
	self.Warned = {} :: { [string]: boolean }
	-- Tension(on): created here so lower-priority services (PedestrianService 545) connect in their OnInit
	self.Tension = self.Libs.Signal.new() :: SignalLib.Signal<boolean>
	-- Ended(key, players): one occurrence is over for these players (TASK-335, TASK-345; JournalService connects in its OnInit)
	self.Ended = self.Libs.Signal.new() :: SignalLib.Signal<string, { Player }>
	-- analytics (MetricsService, owner 2026-10-16; trace 2026-10-20): Started(key, party size, trace); Staged(trace, phase)
	-- every wire phase change after Started; Outcome(key, phase, failed players, party size, stop reason, trace) once per
	-- occurrence that ran
	self.Started = self.Libs.Signal.new() :: SignalLib.Signal<string, number, Trace>
	self.Staged = self.Libs.Signal.new() :: SignalLib.Signal<Trace, string>
	self.Outcome = self.Libs.Signal.new() :: SignalLib.Signal<string, string, { Player }, number, string, Trace>
end

function AnomalyService:WarnOnce(key: string, message: string)
	if self.Warned[key] then
		return
	end
	self.Warned[key] = true
	warn(`{PREFIX} {message}`)
end

-- Modules ---------------------------------------------------------------------------------------------------------

-- Requires every ModuleScript of script.Anomalies (sorted); "_" files are not scheduled (_Example = dev reference).
function AnomalyService:LoadModules()
	const folder = script:FindFirstChild("Anomalies")
	if folder == nil then
		return
	end
	const refs: { [string]: Content.Anomaly } = {}
	for _, row in Content.Anomalies.List do
		refs[row.Ref] = row
	end
	const children = folder:GetChildren()
	table.sort(children, function(a: Instance, b: Instance): boolean
		return a.Name < b.Name
	end)
	for _, child in children do
		if not child:IsA("ModuleScript") then
			continue
		end
		const ok, value = pcall((require :: any), child)
		if not ok then
			warn(`{PREFIX} Anomalies/{child.Name} failed to load: {value}`)
			continue
		end
		const module, problem = Api.check(child.Name, value, refs)
		if module == nil then
			warn(`{PREFIX} Anomalies/{problem}`)
			continue
		end
		if child.Name == "_Example" then
			self.Example = module
			continue
		elseif string.sub(child.Name, 1, 1) == "_" then
			continue
		end
		if child.Name ~= module.Ref then
			warn(`{PREFIX} Anomalies/{child.Name}: file name should be its Ref {module.Ref}`)
		end
		const row = refs[module.Ref]
		if self.Modules[row.Key] ~= nil then
			warn(`{PREFIX} Anomalies/{child.Name}: {module.Ref} already has a module, skipped`)
			continue
		end
		self.Modules[row.Key] = module
	end
end

-- Reads -----------------------------------------------------------------------------------------------------------

function AnomalyService:IsTension(): boolean
	return self.TensionOn
end

-- An occurrence of this anomaly (key or Ref) is running (e.g. ambulance waits during N8/N10, wave 4).
function AnomalyService:IsRunning(anomaly: string): boolean
	const row = rowOf(anomaly)
	if row == nil then
		return false
	end
	for _, run in self.Running do
		if run.Occ.Key == row.Key and not run.Done then
			return true
		end
	end
	return false
end

function AnomalyService:HasModule(anomaly: string): boolean
	const row = rowOf(anomaly)
	return row ~= nil and self.Modules[row.Key] ~= nil
end

function AnomalyService:GetRule(anomaly: string): Api.Rule?
	return Rules.Get(anomaly)
end

-- Players ---------------------------------------------------------------------------------------------------------

-- FEAT-023 active: connected, Active, spawned (a knocked player is still active).
function AnomalyService:ActivePlayers(): { Player }
	const runState = self.Dependencies.RunStateService
	const out: { Player } = {}
	for _, player in Players:GetPlayers() do
		const character = player.Character
		if runState:IsActive(player) and character ~= nil and character:FindFirstChild("HumanoidRootPart") ~= nil then
			table.insert(out, player)
		end
	end
	return out
end

-- Window closed and inside the trailer (VehicleService, DEC-221)
function AnomalyService:IsProtected(player: Player): boolean
	return self.Dependencies.VehicleService:IsProtected(player)
end

-- Root of an Active player within radius (flat distance) of the MapPoint (architecture.md §19.14: "SS", 6 for N10;
-- TRL, 24 for the trailer zone of N8/N9)
function AnomalyService:InZone(player: Player, pointId: string, radius: number): boolean
	if not finite(radius) or not self.Dependencies.RunStateService:IsActive(player) then
		return false
	end
	const character = player.Character
	const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	const point = MapIndex.FindPoint(pointId)
	if root == nil or not root:IsA("BasePart") or point == nil then
		return false
	end
	const offset = root.Position - point.Position
	return Vector2.new(offset.X, offset.Z).Magnitude <= radius
end

-- Eye position: Head, or HumanoidRootPart + EYE_OFFSET.
local function eyeOf(player: Player): Vector3?
	const character = player.Character
	if character == nil then
		return nil
	end
	const head = character:FindFirstChild("Head")
	if head ~= nil and head:IsA("BasePart") then
		return head.Position
	end
	const root = character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return root.Position + EYE_OFFSET
	end
	return nil
end

-- Line of sight: anything but a player character between eye and target (minus TARGET_SLACK) blocks.
local function blocked(from: Vector3, to: Vector3): boolean
	const offset = to - from
	const distance = offset.Magnitude
	if distance <= TARGET_SLACK then
		return false
	end
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	const ignore: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character ~= nil then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	-- TASK-493: glass and invisible barriers (the counter's) do not block the view
	return not Sight.Clear(from, offset.Unit * (distance - TARGET_SLACK), params)
end

function AnomalyService:Looking(player: Player, target: Vector3, range: number, angle: number?): boolean
	if typeof(target) ~= "Vector3" or not finite(range) then
		return false
	end
	if not self.Dependencies.RunStateService:IsActive(player) then
		return false
	end
	-- TASK-337: a player watching the security cameras sees through a screen, never with the eyes (no "seen")
	if self:IsWatching(player) then
		return false
	end
	-- the closed window blocks the view out (the back door's little window does not count, §19.14)
	const vehicle = self.Dependencies.VehicleService
	if vehicle:IsProtected(player) and not vehicle:IsInsidePoint(target) then
		return false
	end
	const gaze = self.Gazes[player]
	if gaze == nil or now() - gaze.At > GAZE_STALE then
		return false
	end
	const eye = eyeOf(player)
	if eye == nil then
		return false
	end
	return Vision.Looking(
		eye,
		Vision.Direction(gaze.Yaw, gaze.Pitch),
		target,
		range,
		angle or Content.Sanity.SeeAngle,
		blocked
	)
end

-- TASK-484 (ANM-019 "don't look up"): signed pitch in degrees (+ = up) of the latest Gaze, or nil (see Api.Context.Pitch).
function AnomalyService:Pitch(player: Player): number?
	if not self.Dependencies.RunStateService:IsActive(player) or self:IsWatching(player) then
		return nil
	end
	const gaze = self.Gazes[player]
	if gaze == nil or now() - gaze.At > PITCH_STALE then
		return nil
	end
	return Vision.Signed(gaze.Pitch)
end

-- SecurityService (TASK-285) has the watcher in Watching; looked up by name (it is not in the Require list).
function AnomalyService:IsWatching(player: Player): boolean
	if self.Security == nil then
		self.Security = lookup("SecurityService") or false
	end
	const security = self.Security
	return security ~= false and type(security.Watching) == "table" and security.Watching[player] == true
end

-- Gaze responder body (network.md §13.5): night shift, Active; otherwise the stored gaze is dropped.
function AnomalyService:OnGaze(value: any, player: Player)
	if type(value) ~= "table" or not finite(value.Yaw) or not finite(value.Pitch) then
		return
	end
	if
		not self.Dependencies.RoundService:IsNight()
		or not self.Dependencies.RunStateService:IsActive(player)
	then
		self.Gazes[player] = nil
		return
	end
	self.Gazes[player] = { Yaw = value.Yaw, Pitch = value.Pitch, At = now() }
end

-- Occurrences -----------------------------------------------------------------------------------------------------

-- The run of an occurrence while it is alive (stale occurrence tables are ignored).
function AnomalyService:RunOf(occ: Api.Occurrence): Run?
	if type(occ) ~= "table" or type(occ.Id) ~= "number" then
		return nil
	end
	const run = self.Running[occ.Id]
	if run == nil or run.Occ ~= occ or run.Done then
		return nil
	end
	return run
end

function AnomalyService:AllocateId(): number?
	for _ = 1, MAX_ID do
		self.NextId = self.NextId % MAX_ID + 1
		const id = self.NextId
		if self.Running[id] == nil and self.Removing[id] == nil then
			return id
		end
	end
	return nil
end

function AnomalyService:Write(run: Run)
	if not run.Added or not self.Live or not self.Dependencies.NetService:IsRunning() then
		return
	end
	self.Libs.Net.Anomalies:update(run.Occ.Id, run.Record)
end

function AnomalyService:Publish(occ: Api.Occurrence, fields: Api.Fields)
	const run = self:RunOf(occ)
	if run == nil or type(fields) ~= "table" then
		return
	end
	const record = table.clone(run.Record)
	const phase = fields.Phase
	if phase == "Signal" or phase == "Active" or phase == "Queue" or phase == "Resolved" or phase == "Failed" then
		record.Phase = phase
	elseif phase ~= nil then
		self:WarnOnce(`phase:{occ.Key}`, `{occ.Ref}: Publish Phase "{tostring(phase)}" is not a wire phase`)
	end
	if finite(fields.Step) then
		record.Step = wireInt(fields.Step :: number, 0, STEP_MAX)
	end
	if finite(fields.Anchor) then
		record.Anchor = wireInt(fields.Anchor :: number, 0, ANCHOR_MAX)
	end
	if
		record.Phase == run.Record.Phase
		and record.Step == run.Record.Step
		and record.Anchor == run.Record.Anchor
	then
		return
	end
	const before = run.Record.Phase
	run.Record = record
	if record.Phase ~= before then
		const trace = run.Trace
		if trace.Marks[record.Phase] == nil then
			trace.Marks[record.Phase] = now() - trace.StartedAt
		end
		if run.Announced then
			self.Staged:Fire(trace, record.Phase)
		end
	end
	self:Write(run)
end

function AnomalyService:FireCue(run: Run, cue: string, entity: number, user: number?)
	const net = self.Dependencies.NetService
	if not self.Live or not net:IsRunning() then
		return
	end
	self.Libs.Net.AnomalyCue:fireClient(net.Audience, {
		Anomaly = run.Occ.Key,
		Cue = cue,
		Entity = entity,
		Seed = run.Occ.Rng:NextInteger(0, SEED_MAX),
		User = user,
	})
end

-- user: full UserId when the cue is personal (DEC-320, B-13; the modules pass it with Entity = UserId % 65536)
function AnomalyService:Cue(occ: Api.Occurrence, cue: string, entity: number?, user: number?)
	const run = self:RunOf(occ)
	if run == nil then
		return
	end
	if type(cue) ~= "string" or table.find(run.Row.Cues, cue) == nil then
		self:WarnOnce(`cue:{occ.Key}:{tostring(cue)}`, `{occ.Ref}: cue "{tostring(cue)}" is not in its Cues`)
		return
	end
	const target = if finite(entity) then wireInt(entity :: number, 0, ANCHOR_MAX) else 0
	if run.Starting then
		table.insert(run.Cues, { Cue = cue, Entity = target, User = user })
		return
	end
	self:FireCue(run, cue, target, user)
end

-- Who pays (DEC-204): a list = who acted / who failed; "active" = every active member (omission, party target).
function AnomalyService:Fail(occ: Api.Occurrence, who: { Player } | "active")
	const run = self:RunOf(occ)
	if run == nil then
		return
	end
	const list: { Player } = if who == "active" then self:ActivePlayers() elseif type(who) == "table" then who else {}
	const critical = Rules.IsCritical(occ.Key)
	const vital = self.Dependencies.VitalService
	for _, player in list do
		if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent == nil then
			continue
		end
		if run.Failed[player.UserId] then
			continue
		end
		run.Failed[player.UserId] = true
		run.Trace.FailedAt[player.UserId] = now() - run.Trace.StartedAt
		if not critical then
			vital:Penalize(player, `anomaly:{occ.Key}`)
		end
	end
	if critical and not run.CriticalSent then
		-- DEC-074, DEC-094: the night is lost at once, no 10 s window. False (not losable now) is not retried. No rule is
		-- critical since DEC-255 (Rules refuses IsCritical); kept for a future decision.
		run.CriticalSent = true
		self.Dependencies.RoundService:LoseNight("critical")
	end
	if run.Row.Scope == "Party" then
		self:Publish(occ, { Phase = "Failed" })
	end
end

function AnomalyService:Succeed(occ: Api.Occurrence)
	self:Publish(occ, { Phase = "Resolved" })
end

-- Fires Ended for one finished run: its party at the start plus whoever failed, still in the game (TASK-335, TASK-345).
-- A Restore counts only once the occurrence did something (left Signal, or someone failed).
function AnomalyService:EmitEnded(run: Run, reason: Api.StopReason)
	const failedPlayers: { Player } = {}
	for userId in run.Failed do
		const player = Players:GetPlayerByUserId(userId)
		if player ~= nil then
			table.insert(failedPlayers, player)
		end
	end
	self.Outcome:Fire(run.Occ.Key, run.Record.Phase, failedPlayers, #run.Party, reason, run.Trace)
	if reason == "Restore" and run.Record.Phase == "Signal" and next(run.Failed) == nil then
		return
	end
	const ids: { [number]: boolean } = {}
	for _, userId in run.Party do
		ids[userId] = true
	end
	for userId in run.Failed do
		ids[userId] = true
	end
	const players: { Player } = {}
	for userId in ids do
		const player = Players:GetPlayerByUserId(userId)
		if player ~= nil then
			table.insert(players, player)
		end
	end
	if #players > 0 then
		self.Ended:Fire(run.Occ.Key, players)
	end
end

function AnomalyService:CallStop(run: Run, reason: Api.StopReason)
	const ctx = self.Context
	if ctx == nil then
		return
	end
	const ok, problem = pcall(run.Module.Stop, ctx, run.Occ, reason)
	if not ok then
		warn(`{PREFIX} {run.Occ.Ref} Stop({reason}) errored: {problem}`)
	end
end

function AnomalyService:Finish(occ: Api.Occurrence)
	const run = self:RunOf(occ)
	if run == nil then
		return
	end
	if run.Starting then
		run.FinishPending = true
		return
	end
	run.Done = true
	self.Running[occ.Id] = nil
	if run.Added then
		self.Removing[occ.Id] = now() + LINGER
	end
	self:CallStop(run, "Done")
	self:EmitEnded(run, "Done")
	self:RefreshTension()
end

-- Every running occurrence stops with `reason`; the set is emptied.
function AnomalyService:StopAll(reason: Api.StopReason)
	const runs: { Run } = {}
	for _, run in self.Running do
		table.insert(runs, run)
	end
	table.sort(runs, function(a: Run, b: Run): boolean
		return a.Occ.Id < b.Occ.Id
	end)
	self.Running = {}
	for _, run in runs do
		run.Done = true
		self:CallStop(run, reason)
		self:EmitEnded(run, reason)
	end
	const hadRecords = #runs > 0 or next(self.Removing) ~= nil
	self.Removing = {}
	if hadRecords and self.Live and self.Dependencies.NetService:IsRunning() then
		self.Libs.Net.Anomalies:clear()
	end
	self:RefreshTension()
end

-- Starts one occurrence of `key` with `module`. slot seeds its Random. Returns (started, reason).
function AnomalyService:StartOccurrence(key: string, module: Api.Module, slot: number): (boolean, string?)
	const ctx = self.Context
	const row = Content.Anomalies.ByKey[key]
	if ctx == nil or row == nil then
		return false, "unknown"
	end
	const id = self:AllocateId()
	if id == nil then
		return false, "ids"
	end
	const shift = self.Shift
	const t = now()
	const occ: Api.Occurrence = {
		Id = id,
		Key = key,
		Ref = row.Ref,
		StartedAt = t,
		Rng = Random.new(
			Scheduler.Seed(
				self.Dependencies.RunStateService.Seed(),
				shift.Day,
				shift.Night,
				shift.Attempt,
				`{DOMAIN}|{key}|{slot}`
			)
		),
		State = nil,
	}
	const party: { number } = {}
	const run: Run = {
		Occ = occ,
		Row = row,
		Module = module,
		Record = { Anomaly = key, Phase = "Signal", StartedAt = t, Step = 0, Anchor = 0 },
		Added = false,
		Starting = true,
		FinishPending = false,
		Done = false,
		Cues = {},
		Failed = {},
		CriticalSent = false,
		Seen = {},
		SeenDone = {},
		Stares = {},
		Party = party,
		Trace = {
			Key = key,
			Day = shift.Day,
			Night = shift.Night,
			Attempt = shift.Attempt,
			StartedAt = t,
			Party = party,
			Marks = {},
			FailedAt = {},
		},
		Announced = false,
	}
	for _, player in self:ActivePlayers() do
		table.insert(run.Party, player.UserId)
	end
	self.Running[id] = run
	const ok, result = pcall(module.Start, ctx, occ)
	run.Starting = false
	if not ok then
		self.Running[id] = nil
		run.Done = true
		warn(`{PREFIX} {row.Ref} Start errored: {result}`)
		return false, "error"
	end
	if result ~= true then
		self.Running[id] = nil
		run.Done = true
		return false, "busy"
	end

	self.LastStartAt = t
	-- a beat (Director): the running occurrence itself counts as active, so no hold here
	Director.begin(self.Director, "anomaly", t, 0)
	if run.Record.Phase == "Signal" and run.Trace.Marks.Signal == nil then
		run.Trace.Marks.Signal = 0
	end
	run.Announced = true
	self.Started:Fire(key, #run.Party, run.Trace)
	-- TASK-284 (Content.ShopWindow, Provisional Q-270): this anomaly slams the service window shut as it starts
	if Content.ShopWindow.Anomalies[key] == "Closes" then
		self.Dependencies.VehicleService:SetShutter(true, nil, true)
	end
	if self.Live and self.Dependencies.NetService:IsRunning() then
		self.Libs.Net.Anomalies:add(id, run.Record)
		run.Added = true
	end
	for _, cue in run.Cues do
		self:FireCue(run, cue.Cue, cue.Entity, cue.User)
	end
	run.Cues = {}
	self:RefreshTension()
	if run.FinishPending then
		self:Finish(occ)
	end
	return true, nil
end

-- "Seen" ----------------------------------------------------------------------------------------------------------

function AnomalyService:See(occ: Api.Occurrence, player: Player)
	const run = self:RunOf(occ)
	if run == nil or typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	run.SeenDone[player.UserId] = true
	self.Dependencies.VitalService:SeeAnomaly(player, occ.Key)
end

-- 1 s (Sanity.SeeTime) accumulated in the cone -> SeeAnomaly (once per anomaly per player per night, VitalService).
function AnomalyService:SeenTick(occ: Api.Occurrence, target: Vector3, range: number, dt: number)
	const run = self:RunOf(occ)
	if run == nil or not finite(dt) or dt <= 0 then
		return
	end
	const need = Content.Sanity.SeeTime
	for _, player in self:ActivePlayers() do
		const userId = player.UserId
		if run.SeenDone[userId] or not self:Looking(player, target, range) then
			continue
		end
		const total = (run.Seen[userId] or 0) + dt
		run.Seen[userId] = total
		if total >= need then
			self:See(occ, player)
		end
	end
	-- owner 2026-10-22: the stare pressure only while a customer anomaly waits in the delivery queue (never on arrival)
	if run.Row.Stare and run.Record.Phase == "Queue" then
		self:StareTick(run, target, range, dt)
	end
end

-- TASK-482: stare count and sanity drain (header "Stare"). Called from SeenTick, same target and range.
function AnomalyService:StareTick(run: Run, target: Vector3, range: number, dt: number)
	const rules = Content.Sanity.Stare
	const vital = self.Dependencies.VitalService
	for _, player in self:ActivePlayers() do
		const userId = player.UserId
		local stare = run.Stares[userId]
		if stare == nil then
			stare = { Time = 0, Away = 0, Owed = 0, Taken = 0 }
			run.Stares[userId] = stare
		end
		const track = stare :: Stare
		if not self:Looking(player, target, range, rules.Angle) then
			track.Away += dt
			if track.Away >= rules.Release then
				track.Time = 0
				track.Owed = 0
			end
			continue
		end
		track.Away = 0
		track.Time += dt
		if track.Time < rules.DrainAfter or track.Taken >= rules.Cap then
			continue
		end
		track.Owed += rules.PerSecond * math.min(dt, track.Time - rules.DrainAfter)
		const whole = math.min(math.floor(track.Owed), rules.Cap - track.Taken)
		if whole >= 1 then
			track.Owed -= whole
			track.Taken += whole
			vital:AddSanity(player, -whole, `stare:{run.Occ.Key}`)
		end
	end
end

-- Tension ---------------------------------------------------------------------------------------------------------

function AnomalyService:RefreshTension()
	local on = false
	for _, run in self.Running do
		if not run.Done and run.Row.Tension then
			on = true
			break
		end
	end
	if on == self.TensionOn then
		return
	end
	self.TensionOn = on
	const npc = self.Dependencies.NpcService :: any
	if type(npc.SetTension) == "function" then
		const ok, problem = pcall(npc.SetTension, npc, on)
		if not ok then
			warn(`{PREFIX} NpcService:SetTension errored: {problem}`)
		end
	end
	self.Tension:Fire(on)
end

-- Events ----------------------------------------------------------------------------------------------------------

function AnomalyService:Emit(event: Api.Event)
	const ctx = self.Context
	if ctx == nil then
		return
	end
	const runs: { Run } = {}
	for _, run in self.Running do
		if not run.Starting and run.Module.OnEvent ~= nil then
			table.insert(runs, run)
		end
	end
	table.sort(runs, function(a: Run, b: Run): boolean
		return a.Occ.Id < b.Occ.Id
	end)
	for _, run in runs do
		const handler = run.Module.OnEvent
		if run.Done or handler == nil then
			continue
		end
		const ok, problem = pcall(handler, ctx, run.Occ, event)
		if not ok then
			warn(`{PREFIX} {run.Occ.Ref} OnEvent({event.Kind}) errored: {problem}`)
		end
	end
end

-- Context ---------------------------------------------------------------------------------------------------------

function AnomalyService:BuildContext(): Api.Context
	const light = self.Dependencies.LightService
	const economy = self.Dependencies.EconomyService
	const vehicle = self.Dependencies.VehicleService
	return {
		Now = now,
		Publish = function(occ: Api.Occurrence, fields: Api.Fields)
			self:Publish(occ, fields)
		end,
		Cue = function(occ: Api.Occurrence, cue: string, entity: number?, user: number?)
			self:Cue(occ, cue, entity, user)
		end,
		Fail = function(occ: Api.Occurrence, who: { Player } | "active")
			self:Fail(occ, who)
		end,
		Succeed = function(occ: Api.Occurrence)
			self:Succeed(occ)
		end,
		Finish = function(occ: Api.Occurrence)
			self:Finish(occ)
		end,
		Active = function(): { Player }
			return self:ActivePlayers()
		end,
		Looking = function(player: Player, target: Vector3, range: number, angle: number?): boolean
			return self:Looking(player, target, range, angle)
		end,
		Pitch = function(player: Player): number?
			return self:Pitch(player)
		end,
		SeenTick = function(occ: Api.Occurrence, target: Vector3, range: number, dt: number)
			self:SeenTick(occ, target, range, dt)
		end,
		See = function(occ: Api.Occurrence, player: Player)
			self:See(occ, player)
		end,
		Rule = function(anomaly: string): Api.Rule?
			return Rules.Get(anomaly)
		end,
		Spawn = function(spec: Api.ActorSpec): number?
			const customers = self.Dependencies.CustomerService :: any
			if type(customers.SpawnActor) ~= "function" then
				self:WarnOnce("nospawn", "Spawn without CustomerService:SpawnActor (TASK-108): refused")
				return nil
			end
			const ok, id = pcall(customers.SpawnActor, customers, spec)
			if not ok then
				warn(`{PREFIX} CustomerService:SpawnActor errored: {id}`)
				return nil
			end
			return if type(id) == "number" then id else nil
		end,
		Light = {
			BeginHush = function(startedAt: number, holdUntil: number, postsOnly: boolean?)
				light:BeginHush(startedAt, holdUntil, postsOnly)
			end,
			EndHush = function()
				light:EndHush()
			end,
			IsLit = function(position: Vector3): boolean
				return light:IsLit(position)
			end,
			IsSwitchOn = function(): boolean
				return light:IsSwitchOn()
			end,
		},
		Vehicle = {
			IsShutterClosed = function(): boolean
				return vehicle:IsShutterClosed()
			end,
			IsInside = function(player: Player): boolean
				return vehicle:IsInside(player)
			end,
			IsProtected = function(player: Player): boolean
				return vehicle:IsProtected(player)
			end,
		},
		InZone = function(player: Player, pointId: string, radius: number): boolean
			return self:InZone(player, pointId, radius)
		end,
		Kitchen = {
			Alter = function(kind: "rail" | "board"): boolean
				const kitchen = self.Dependencies.KitchenService :: any
				if type(kitchen.Alter) ~= "function" then
					self:WarnOnce("noalter", "Alter without KitchenService:Alter (TASK-109): refused")
					return false
				end
				const ok, done = pcall(kitchen.Alter, kitchen, kind)
				if not ok then
					warn(`{PREFIX} KitchenService:Alter errored: {done}`)
					return false
				end
				return done == true
			end,
		},
		Traffic = {
			Hold = function(reason: string, on: boolean)
				const traffic = self.Traffic
				if traffic == nil then
					self:WarnOnce("notraffic", "Hold without TrafficService (TASK-104): ignored")
					return
				end
				const ok, problem = pcall(traffic.Hold, traffic, reason, on)
				if not ok then
					warn(`{PREFIX} TrafficService:Hold errored: {problem}`)
				end
			end,
		},
		Economy = {
			CountArrival = function()
				economy:CountArrival()
			end,
			CountResult = function(result: string)
				economy:CountResult(result :: any)
			end,
			AddSale = function(amount: number): number
				const value = math.floor(amount)
				if not finite(value) or value <= 0 then
					return 0
				end
				return economy:AddSale(value, "Sale")
			end,
		},
		Log = function(occ: Api.Occurrence, message: string)
			warn(`{PREFIX} {occ.Ref}#{occ.Id}: {message}`)
		end,
	}
end

-- Agenda ----------------------------------------------------------------------------------------------------------

function AnomalyService:BuildAgenda(info: { Day: number, Night: number, IsNight: boolean, Attempt: number })
	self.Queue = {}
	self.Scares = {}
	self.Opening = ""
	self.NextScareAt = 0
	self.Pressure = Pressure.new()
	self.Trip = Trip.new()
	self.NightEvent = newNightEvent()
	Director.reset(self.Director)
	if not info.IsNight or info.Night < 1 then
		return
	end
	const nights = Content.Nights.List
	const night = nights[math.clamp(info.Night, 1, #nights)]
	const phase = Content.Shift.ByKey[NIGHT_PHASE]
	const candidates: { Scheduler.Candidate } = {}
	-- Cart nights (user request 2026-10-12): an anomaly whose only answer is a trailer object (Trailer "Needs": the light
	-- switch) is replaced, with the same age weight (3/2/1), by its stand-in, an earlier anomaly
	-- the cart can handle. The trailer brings the anomaly back; without it the night just repeats older ones.
	const vehicle: Content.Vehicle? = Content.Vehicles.ByKey[self.Dependencies.VehicleService:Current()]
	const hasSwitch: boolean = vehicle ~= nil and vehicle.HasSwitch
	-- V2 (TASK-271): the scheduler filters by family and atmosphere; here only rows with a module enter, so an
	-- anomaly still being built (TASK-272..274) never spends an event of the night
	for _, row in Content.Anomalies.ActiveOn(info.Night) do
		if self.Modules[row.Key] == nil then
			continue
		end
		local stand: Content.Anomaly? = nil
		if row.Trailer == "Needs" and not hasSwitch then
			stand = Content.Anomalies.StandIn(row)
		end
		if stand ~= nil then
			const swapped = candidate(stand)
			swapped.Night = row.Night
			swapped.Family = row.Family
			swapped.SkipAtmospheres = row.SkipAtmospheres
			table.insert(candidates, swapped)
		else
			table.insert(candidates, candidate(row))
		end
	end
	const runSeed = self.Dependencies.RunStateService.Seed()
	const rng = Random.new(Scheduler.Seed(runSeed, info.Day, info.Night, info.Attempt, DOMAIN))
	const input: Scheduler.Input = {
		Night = info.Night,
		Anomalies = candidates,
		Occurrences = Content.Nights.Occurrences,
		Families = night.Families,
		Atmosphere = night.Atmosphere,
		Events = night.Events + self:CrewEvents(),
		Premiere = night.NewAnomaly,
		PremiereAt = Content.Nights.PremiereAt[info.Night],
		-- owner 2026-10-22 (Provisional): the mandatory night event, a world anomaly with a verb (B/C/D)
		NightEvent = { Families = { "B", "C", "D" }, Grace = Content.Nights.Grace[info.Night], Span = Content.Nights.Beats.NightSpan },
		Window = Content.Nights.Windows.Shift,
		MinGap = night.MinGap,
		MinutesPerSecond = if night.Duration > 0 then (phase.ClockTo - phase.ClockFrom) / night.Duration else 0,
	}
	const entries = Scheduler.Build(input, function(): number
		return rng:NextNumber()
	end)
	-- DEC-352: its own seed, so the pressure never changes the agenda's draws
	Pressure.reset(
		self.Pressure,
		input,
		Scheduler.Seed(runSeed, info.Day, info.Night, info.Attempt, PRESSURE_DOMAIN)
	)
	Trip.reset(self.Trip, info.Night, Scheduler.Seed(runSeed, info.Day, info.Night, info.Attempt, TRIP_DOMAIN))
	Behind.reset(self.Behind, info.Night, Scheduler.Seed(runSeed, info.Day, info.Night, info.Attempt, BEHIND_DOMAIN))
	for _, entry in entries do
		table.insert(self.Queue, { Entry = entry, RetryAt = 0, Done = false })
	end
	-- family D (TASK-274): night.Scares scares without a verb, one per equal slice of the window, jittered inside it.
	-- Drawn after the agenda so the agenda's draws never change.
	-- Owner 2026-10-20 (Provisional Q-415): the window opens at 8 PM (Nights.ScaresFrom, was 9 PM) and the grace no longer
	-- holds it; a night with a scripted opening (Nights.Opening, first attempt) plays it first and draws after its end.
	const hasD = table.find(night.Families, "D") ~= nil
	const opening = Content.Nights.Opening[info.Night]
	local from = Content.Nights.ScaresFrom
	if hasD and opening ~= nil and info.Attempt == 0 then
		self.Opening = opening.Key
		from = math.max(from, opening.Until)
	end
	const window = { from, Content.Nights.Windows.Shift[2] }
	const count = if hasD then night.Scares else 0
	if count > 0 then
		const slice = (window[2] - window[1]) / count
		for index = 1, count do
			table.insert(self.Scares, window[1] + slice * (index - 1) + slice * (0.2 + 0.6 * rng:NextNumber()))
		end
		table.sort(self.Scares)
	end
	-- owner 2026-10-22 (Provisional): the mandatory night event. The pool lists the drawn key first; no pool = the breaker
	-- trips at a minute drawn here (after every other draw, so those never change)
	const pool = Scheduler.NightPool(input)
	local chosen: Due? = nil
	for _, due in self.Queue do
		if due.Entry.Night then
			chosen = due
			break
		end
	end
	const event = self.NightEvent
	if chosen ~= nil then
		const key = chosen.Entry.Key
		table.insert(event.Pool, key)
		for _, other in pool do
			if other ~= key then
				table.insert(event.Pool, other)
			end
		end
		event.Entry = chosen.Entry
	else
		const fallback: Scheduler.Entry = {
			Key = NIGHT_BREAKER,
			At = Scheduler.NightAt(input, function(): number
				return rng:NextNumber()
			end),
			Scripted = false,
			Slot = 0,
			Premiere = false,
			Night = true,
		}
		table.insert(self.Queue, { Entry = fallback, RetryAt = 0, Done = false })
		event.Entry = fallback
	end
	event.Phase = "pending"
end

-- Pressure host (DEC-352, Pressure.Host) ---------------------------------------------------------------------------

function AnomalyService:SanityOf(player: Player): (number, number)
	return self.Dependencies.VitalService:GetSanity(player)
end

-- one family D scare on this player's client only (the client picks what it can show now)
function AnomalyService:Scare(player: Player)
	self.Dependencies.HallucinationService:Scare(player, nil)
end

function AnomalyService:ScareGapUntil(): number
	return self.NextScareAt
end

-- entries still waiting, plus the occurrences running now
function AnomalyService:Queued(): { Scheduler.Entry }
	const out: { Scheduler.Entry } = {}
	for _, due in self.Queue do
		if not due.Done then
			table.insert(out, due.Entry)
		end
	end
	for _, run in self.Running do
		if not run.Done then
			table.insert(out, { Key = run.Occ.Key, At = 0, Scripted = false, Slot = 0, Premiere = false, Night = false })
		end
	end
	return out
end

function AnomalyService:Enqueue(entry: Scheduler.Entry)
	table.insert(self.Queue, { Entry = entry, RetryAt = 0, Done = false })
end

-- Trip host (Q-435, Trip.Host) ----------------------------------------------------------------------------------

-- an occurrence is running now (ChoreService waits for a calm moment too)
function AnomalyService:AnyRunning(): boolean
	for _, run in self.Running do
		if not run.Done then
			return true
		end
	end
	return false
end

-- an anomaly running now, the power already out / the bulb burnt, or the beat budget says wait (Director)
function AnomalyService:TripBusy(): boolean
	const light = self.Dependencies.LightService
	return self:AnyRunning() or light:IsBlackout() or light:IsBurnt() or not self:BeatClear("trip")
end

function AnomalyService:TripBreaker(): boolean
	const tripped = self.Dependencies.LightService:TripBreaker()
	if tripped then
		self:BeatBegin("trip", nil)
	end
	return tripped
end

-- members connected now (not Away), at least 1
function AnomalyService:CrewSize(): number
	local count = 0
	for _, member in self.Dependencies.RunStateService.Members() do
		if member.State ~= "Away" then
			count += 1
		end
	end
	return math.max(count, 1)
end

-- DEC-320 (Q-413): extra regular events for a bigger crew, by the members connected now (not Away), 1..4
function AnomalyService:CrewEvents(): number
	const list = Content.Nights.CrewEvents
	return list[math.clamp(self:CrewSize(), 1, #list)] or 0
end

-- Beat director (Director.luau, Content.Nights.Beats) ---------------------------------------------------------------

function AnomalyService:RunningCount(): number
	local count = 0
	for _, run in self.Running do
		if not run.Done then
			count += 1
		end
	end
	return count
end

-- Real seconds until the next regular entry of the agenda is due (0 when one is overdue, math.huge if none);
-- future = only entries not due yet (an overdue one is waiting for Admit or the director)
function AnomalyService:BeatDueIn(future: boolean?): number
	const nights = Content.Nights.List
	const night = nights[math.clamp(self.Shift.Night, 1, #nights)]
	const phase = Content.Shift.ByKey[NIGHT_PHASE]
	const span = phase.ClockTo - phase.ClockFrom
	if night == nil or span <= 0 then
		return math.huge
	end
	const minutes = self.Dependencies.RoundService:Minutes()
	local soonest = math.huge
	for _, due in self.Queue do
		if not due.Done and not due.Entry.Scripted and not (future and due.Entry.At <= minutes) then
			soonest = math.min(soonest, math.max(due.Entry.At - minutes, 0) * night.Duration / span)
		end
	end
	return soonest
end

-- May a beat of this kind start now? kind "anomaly" = the agenda itself (no Reserve); any other kind ("chore",
-- "trip", "suspense") also waits for a regular anomaly due within Beats.Reserve s. Every kind but "night" (the night
-- event, owner 2026-10-22) is refused during the night event's lock
function AnomalyService:BeatClear(kind: string): boolean
	const dueIn = if kind == "anomaly" or kind == "night" then math.huge else self:BeatDueIn()
	const ok = Director.clear(
		self.Director,
		Content.Nights.Beats,
		now(),
		self:CrewSize(),
		self:RunningCount(),
		dueIn,
		kind
	)
	return ok
end

-- The night event's lock is on now (owner 2026-10-22): nothing but the event itself starts. Refreshed every StepAgenda.
function AnomalyService:NightLocked(): boolean
	return Director.locked(self.Director, now())
end

-- Real seconds per game minute of the Night phase (0 when the night or the phase is not valid)
function AnomalyService:SecondsPerMinute(): number
	const nights = Content.Nights.List
	const night = nights[math.clamp(self.Shift.Night, 1, #nights)]
	const phase = Content.Shift.ByKey[NIGHT_PHASE]
	const span = phase.ClockTo - phase.ClockFrom
	if night == nil or span <= 0 then
		return 0
	end
	return night.Duration / span
end

-- A beat started now; it counts as active for `hold` s (nil = Beats.Hold, 0 = only the gap) or until BeatEnd
function AnomalyService:BeatBegin(key: string, hold: number?)
	Director.begin(self.Director, key, now(), if hold ~= nil then hold else Content.Nights.Beats.Hold)
end

function AnomalyService:BeatEnd(key: string)
	Director.finish(self.Director, key)
end

-- "Behind you" host (Behind.luau, Content.Nights.Behind) -------------------------------------------------------------

-- Why the night is not calm for a "behind you" sound now (nil = calm): an anomaly running, a beat active, the last
-- beat younger than Calm s, a regular anomaly due within Beats.Reserve (an overdue one held back by Admit or the
-- director does not count: it waits for the gap anyway), the power out
function AnomalyService:BehindWhy(): string?
	const t = now()
	const director = self.Director
	if Director.locked(director, t) then
		return "night event"
	end
	if self:RunningCount() > 0 then
		return "anomaly running"
	end
	if Director.count(director, t) > 0 then
		return "beat active (chore / trip)"
	end
	if director.LastAt > 0 and t - director.LastAt < Content.Nights.Behind.Calm then
		return string.format("last beat %.0fs ago (calm %ds)", t - director.LastAt, Content.Nights.Behind.Calm)
	end
	const due = self:BeatDueIn(true)
	if due < Content.Nights.Beats.Reserve then
		return string.format("anomaly due in %.0fs", due)
	end
	if self.Dependencies.LightService:IsBlackout() then
		return "power out"
	end
	return nil
end

function AnomalyService:BehindCalm(): boolean
	return self:BehindWhy() == nil
end

-- Active players near the window's counter spot, looking more than Behind.Facing degrees away from it (fresh Gaze, not
-- on the security cameras)
function AnomalyService:BehindTargets(): { Player }
	const rules = Content.Nights.Behind
	const point = MapIndex.FindPoint(rules.Point)
	const out: { Player } = {}
	if point == nil then
		return out
	end
	const t = now()
	for _, player in self:ActivePlayers() do
		if not self:InZone(player, rules.Point, rules.Near) or self:IsWatching(player) then
			continue
		end
		const gaze = self.Gazes[player]
		const eye = eyeOf(player)
		if gaze == nil or t - gaze.At > GAZE_STALE or eye == nil then
			continue
		end
		const look = Vision.Direction(gaze.Yaw, gaze.Pitch)
		const toward = point.Position - eye
		const flatLook = Vector3.new(look.X, 0, look.Z)
		const flatToward = Vector3.new(toward.X, 0, toward.Z)
		if flatLook.Magnitude < 1e-3 or flatToward.Magnitude < 1e-3 then
			continue
		end
		const cos = flatLook.Unit:Dot(flatToward.Unit)
		if math.deg(math.acos(math.clamp(cos, -1, 1))) >= rules.Facing then
			table.insert(out, player)
		end
	end
	return out
end

function AnomalyService:BehindScare(player: Player, key: string): number
	return self.Dependencies.HallucinationService:Scare(player, { key })
end

function AnomalyService:Limits(): Scheduler.Limits
	const nights = Content.Nights.List
	const night = nights[math.clamp(self.Shift.Night, 1, #nights)]
	return { MaxSimultaneous = night.MaxSimultaneous, MaxActors = Content.Flow.MaxActorsNight, MinGap = night.MinGap }
end

function AnomalyService:RunningCandidates(): { Scheduler.Candidate }
	const out: { Scheduler.Candidate } = {}
	for _, run in self.Running do
		if not run.Done then
			table.insert(out, candidate(run.Row))
		end
	end
	return out
end

-- Due entries of the agenda (Night phase only).
-- Holds the regular agenda while `hold` says so (TutorialService: a rookie's tutorial runs). Errors count as "no".
function AnomalyService:SetHold(hold: () -> boolean)
	self.Hold = hold
end

-- The tutorial holds everything now (regular events, the premiere, the scares and the opening)
function AnomalyService:TutorialHeld(): boolean
	const hold = self.Hold
	if hold ~= nil then
		const ok, held = pcall(hold)
		if ok and held then
			return true
		end
	end
	return false
end

-- The night's grace minute (Content.Nights.Grace) is not reached yet. Owner 2026-10-20 (Provisional Q-415): it holds only
-- the regular events that punish; the family D scares, the opening and the fixed premiere ignore it.
function AnomalyService:InGrace(minutes: number): boolean
	const grace = Content.Nights.Grace[self.Dependencies.RoundService:Info().Night]
	return grace ~= nil and (minutes % 1440) < grace and (minutes % 1440) >= Content.Nights.Windows.Calm[1]
end

-- The regular agenda waits now: the tutorial holds it, or the night's grace minute is not reached yet
function AnomalyService:Held(minutes: number): boolean
	return self:TutorialHeld() or self:InGrace(minutes)
end

-- Server-time window [from, until) of the night event's lock, nil when it is not locking (done, or the dev / tutorial
-- hold has the agenda). Pending: from NightLead s before it is due, no end until it starts; running: until the run
-- ends + NightTail (LockEndAt).
function AnomalyService:NightLockWindow(t: number, minutes: number): (number?, number?)
	const event = self.NightEvent
	const entry = event.Entry
	if entry == nil or event.Phase == "none" or event.Phase == "done" then
		return nil, nil
	end
	if event.Phase == "running" then
		return event.StartedAt, event.LockEndAt
	end
	const perMinute = self:SecondsPerMinute()
	if perMinute <= 0 or self.DevHeld or self:TutorialHeld() then
		return nil, nil
	end
	return t + (entry.At - minutes) * perMinute - Content.Nights.Beats.NightLead, math.huge
end

-- The night event: waits for its minute, then starts whatever the grace, the gap, the caps, the shut window and the window
-- end say; an anomaly running when it is due gets NightMaxWait s to finish. Tries the pool in order (an ExclusiveWith
-- or a failed Start moves to the next key), the breaker trip last.
function AnomalyService:StepNightEvent(t: number, minutes: number, tutorial: boolean)
	const event = self.NightEvent
	const entry = event.Entry
	const rules = Content.Nights.Beats
	if entry == nil then
		return
	end
	if event.Phase == "running" then
		-- the lock lets go Tail s after the run ends (or at the cap set when it started)
		-- (RunId -1 = the breaker trip: its lock runs a fixed NightSpan + NightTail)
		const run = self.Running[event.RunId]
		if event.RunId >= 0 and (run == nil or run.Done) and t + rules.NightTail < event.LockEndAt then
			event.LockEndAt = t + rules.NightTail
		end
		if t >= event.LockEndAt then
			event.Phase = "done"
		end
		return
	end
	if event.Phase ~= "pending" or tutorial or entry.At > minutes then
		return
	end
	if event.DueAt == 0 then
		event.DueAt = t
	end
	if self:RunningCount() > 0 and t - event.DueAt < rules.NightMaxWait then
		return
	end
	const running = self:RunningCandidates()
	for _, key in event.Pool do
		const module, row = self.Modules[key], Content.Anomalies.ByKey[key]
		if module == nil or row == nil then
			continue
		end
		local blocked = false
		for _, other in running do
			if other.Key == key or table.find(row.ExclusiveWith, other.Key) ~= nil or table.find(other.ExclusiveWith, key) ~= nil then
				blocked = true
				break
			end
		end
		if blocked then
			continue
		end
		const started = self:StartOccurrence(key, module, entry.Slot)
		if not started then
			continue
		end
		local runId = 0
		for id, run in self.Running do
			if run.Occ.Key == key and id > runId then
				runId = id
			end
		end
		event.Phase = "running"
		event.StartedAt = t
		event.RunId = runId
		-- an event that outlasts twice its span lets the lock go anyway (a blackout nobody fixes)
		event.LockEndAt = t + rules.NightSpan * 2 + rules.NightTail
		Director.begin(self.Director, "night", t, 0)
		self:NightEntryDone()
		return
	end
	-- last resort (and Nights 1-2, no world anomaly open): the breaker trips
	const tripped = self:TripBreaker()
	if not tripped then
		warn(`{PREFIX} night event: no anomaly could start and the breaker could not trip (power already out?)`)
	end
	Director.begin(self.Director, "night", t, rules.NightSpan)
	event.Phase = "running"
	event.StartedAt = t
	event.RunId = -1
	event.LockEndAt = t + rules.NightSpan + rules.NightTail
	self:NightEntryDone()
end

-- the night event's agenda entry is spent (listing, BeatDueIn)
function AnomalyService:NightEntryDone()
	const entry = self.NightEvent.Entry
	for _, due in self.Queue do
		if due.Entry == entry then
			due.Done = true
		end
	end
end

function AnomalyService:StepAgenda(t: number)
	if self.DevHeld then
		Director.lock(self.Director, math.huge, 0)
		return
	end
	const minutes = self.Dependencies.RoundService:Minutes()
	const tutorial = self:TutorialHeld()
	const held = tutorial or self:InGrace(minutes)
	const windowEnd = Content.Nights.Windows.Shift[2]
	const limits = self:Limits()
	-- owner 2026-10-22 (Provisional): the mandatory night event first, and its lock holds back everything else below
	self:StepNightEvent(t, minutes, tutorial)
	const lockFrom, lockUntil = self:NightLockWindow(t, minutes)
	Director.lock(self.Director, lockFrom or math.huge, lockUntil or 0)
	const locked = Director.locked(self.Director, t)
	-- owner 2026-10-20 (Provisional Q-415): the scripted opening first, as the Night phase starts (only the tutorial holds it)
	-- (OPENING_AFTER game minutes in, so the clients already show the Night phase and do not cancel it)
	if not tutorial and not locked and self.Opening ~= "" and minutes >= Content.Nights.Windows.Calm[1] + OPENING_AFTER then
		const key = self.Opening
		self.Opening = ""
		self.Dependencies.HallucinationService:Scare(nil, { key })
		self.NextScareAt = t + Content.HallucinationRules.ScareGap
	end
	-- family D: a scare due now plays for everyone (any key of the D catalogue); none past the window. Owner 2026-10-20
	-- (Provisional Q-415): not held by the grace, and one at a time (ScareGap apart) when several are due together
	if not tutorial and not locked and t >= self.NextScareAt and #self.Scares > 0 and self.Scares[1] <= minutes then
		table.remove(self.Scares, 1)
		if minutes < windowEnd then
			self.Dependencies.HallucinationService:Scare(nil, nil)
			self.NextScareAt = t + Content.HallucinationRules.ScareGap
		end
	end
	-- DEC-352: low sanity brings personal scares (any time of the Night phase) and extra entries (not in the grace)
	if not tutorial and not locked then
		Pressure.scares(self.Pressure, self, t)
		if not held then
			Pressure.extra(self.Pressure, self, t, minutes, windowEnd)
		end
	end
	-- Q-435: the breaker trips by itself (not in the grace, not past the window, never on top of an anomaly)
	if not held and not locked and minutes < windowEnd then
		Trip.step(self.Trip, self, t)
		-- owner 2026-10-21: a sound behind a player cooking with the back to the window, in a calm stretch
		Behind.step(self.Behind, self, t)
	end
	for _, due in self.Queue do
		const entry = due.Entry
		-- the night event has its own step (StepNightEvent); nothing else starts while its lock is on
		if due.Done or entry.Night or locked or entry.At > minutes or t < due.RetryAt then
			continue
		end
		const module = self.Modules[entry.Key]
		if module == nil then
			-- no module for this anomaly yet: the service runs empty (TASK-106)
			due.Done = true
			continue
		end
		if not entry.Scripted then
			if minutes >= windowEnd then
				due.Done = true
				continue
			end
			-- waits for the tutorial / the grace minute (Admit spaces the ones that piled up); the fixed premiere
			-- (owner 2026-10-20, Provisional Q-415) only for the tutorial
			if tutorial or (held and not entry.Premiere) then
				continue
			end
			const row = Content.Anomalies.ByKey[entry.Key]
			-- TASK-284 (Content.ShopWindow, Provisional Q-270): a shut window at the scheduled start avoids it
			if Content.ShopWindow.Anomalies[entry.Key] == "Blocks" and self.Dependencies.VehicleService:IsShutterClosed() then
				due.Done = true
				continue
			end
			const since = if self.LastStartAt > 0 then t - self.LastStartAt else math.huge
			const admitted = Scheduler.Admit(candidate(row), self:RunningCandidates(), limits, since)
			if not admitted then
				continue
			end
			-- the beat budget (Director): the fixed premiere does not wait for it
			if not entry.Premiere and not self:BeatClear("anomaly") then
				continue
			end
		end
		const started, reason = self:StartOccurrence(entry.Key, module, entry.Slot)
		if started or reason == "error" or reason == "unknown" then
			due.Done = true
		else
			due.RetryAt = t + RETRY
		end
	end
end

function AnomalyService:StepRuns(t: number)
	const ctx = self.Context
	if ctx == nil then
		return
	end
	const runs: { Run } = {}
	for _, run in self.Running do
		if run.Module.Tick ~= nil then
			table.insert(runs, run)
		end
	end
	table.sort(runs, function(a: Run, b: Run): boolean
		return a.Occ.Id < b.Occ.Id
	end)
	for _, run in runs do
		const tick = run.Module.Tick
		if run.Done or tick == nil then
			continue
		end
		const ok, problem = pcall(tick, ctx, run.Occ, t)
		if not ok then
			-- a module erroring at 5 Hz would flood the output: the occurrence ends instead
			warn(`{PREFIX} {run.Occ.Ref} Tick errored, finishing it: {problem}`)
			self:Finish(run.Occ)
		end
	end
end

function AnomalyService:StepRemovals(t: number)
	for id, at in self.Removing do
		if t < at then
			continue
		end
		self.Removing[id] = nil
		if self.Live and self.Dependencies.NetService:IsRunning() then
			self.Libs.Net.Anomalies:remove(id)
		end
	end
end

function AnomalyService:Step()
	const t = now()
	self:StepRemovals(t)
	const round = self.Dependencies.RoundService
	if not round:IsStarted() or round:GetPhase() ~= NIGHT_PHASE then
		return
	end
	self:StepAgenda(t)
	self:StepRuns(t)
end

-- Shifts ----------------------------------------------------------------------------------------------------------

function AnomalyService:OnShiftStarted(info: { Day: number, Night: number, IsNight: boolean, Attempt: number })
	self:StopAll("Restore")
	self.Shift = { Day = info.Day, Night = info.Night, IsNight = info.IsNight, Attempt = info.Attempt }
	self.InNight = false
	self.NextId = 0
	self.LastStartAt = 0
	self:BuildAgenda(info)
end

function AnomalyService:OnPhase(phase: string)
	if phase == NIGHT_PHASE then
		self.InNight = true
		return
	end
	-- Call and Prep come before the Night phase: the agenda built at ShiftStarted waits for it
	if self.InNight then
		self.InNight = false
		self.Queue = {}
		self.Scares = {}
		self.Opening = ""
		self.NightEvent = newNightEvent()
		Director.lock(self.Director, math.huge, 0)
	end
	if next(self.Running) ~= nil or next(self.Removing) ~= nil then
		self:StopAll(if phase == "NightEnd" then "NightOver" else "Restore")
	end
end

-- Dev (Commands/Anomaly.luau) -------------------------------------------------------------------------------------

function AnomalyService:DevCheck()
	if not self.Dependencies.PlaceService:IsDev() then
		error("dev mode only", 0)
	end
	if not self.Enabled then
		error("Run place only", 0)
	end
end

-- Forces an occurrence now (skips Admit and the clock). example = run Anomalies/_Example under this key.
function AnomalyService:DevForce(anomaly: string, example: boolean): string
	self:DevCheck()
	if self.Dependencies.RoundService:GetPhase() ~= NIGHT_PHASE then
		error("only during the Night phase (occurrences tick only then): /dev night <k>, then skip to Night", 0)
	end
	const row = rowOf(anomaly)
	if row == nil then
		error(`unknown anomaly "{anomaly}" (key, ANM-### or night number)`, 0)
	end
	const module = if example then self.Example else self.Modules[row.Key]
	if module == nil then
		error(
			if example
				then "Anomalies/_Example is missing"
				else `{row.Ref} has no module yet (Anomalies/{row.Ref}.luau); try "anomaly {row.Ref} example"`,
			0
		)
	end
	self.DevSerial += 1
	const started, reason = self:StartOccurrence(row.Key, module, 1000 + self.DevSerial)
	if not started then
		error(`{row.Ref} did not start ({reason})`, 0)
	end
	return `{row.Ref} {row.Key} started{if example then " (example module)" else ""}`
end

function AnomalyService:DevStop(): string
	self:DevCheck()
	const count = #self:RunningCandidates()
	self:StopAll("Restore")
	return `stopped {count} occurrence(s)`
end

-- Dev showcase hooks (src/Showcase/server/ShowcaseService; docs/tech/showcase.md). Same dev gate as the commands.

-- Holds the natural agenda (no scheduled start while true); forced occurrences are unaffected.
function AnomalyService:DevHoldAgenda(on: boolean)
	self:DevCheck()
	self.DevHeld = on
end

function AnomalyService:DevIsHeld(): boolean
	return self.DevHeld
end

-- Live occurrences for the panel: id, key, Ref, wire phase, step, age (s). Oldest first.
function AnomalyService:DevRuns(): { any }
	const out: { any } = {}
	const t = now()
	for id, run in self.Running do
		if not run.Done then
			table.insert(
				out,
				{
					Id = id,
					Key = run.Occ.Key,
					Ref = run.Occ.Ref,
					Phase = run.Record.Phase,
					Step = run.Record.Step,
					Age = t - run.Occ.StartedAt,
				}
			)
		end
	end
	table.sort(out, function(a: { Id: number }, b: { Id: number }): boolean
		return a.Id < b.Id
	end)
	return out
end

-- Newest live occurrence of an anomaly (key, Ref or night number), or nil.
function AnomalyService:DevOccurrence(anomaly: string): any
	const row = rowOf(anomaly)
	if row == nil then
		return nil
	end
	local found: any = nil
	for _, run in self.Running do
		if not run.Done and run.Occ.Key == row.Key and (found == nil or run.Occ.StartedAt >= found.StartedAt) then
			found = run.Occ
		end
	end
	return found
end

-- Stops the live occurrences of ONE anomaly ("Restore", like the dev stop). Returns how many.
function AnomalyService:DevStopKey(anomaly: string): number
	self:DevCheck()
	const row = rowOf(anomaly)
	if row == nil then
		error(`unknown anomaly "{anomaly}"`, 0)
	end
	local count = 0
	for id, run in self.Running do
		if run.Occ.Key == row.Key and not run.Done then
			run.Done = true
			self.Running[id] = nil
			if run.Added then
				self.Removing[id] = now() + LINGER
			end
			self:CallStop(run, "Restore")
			count += 1
		end
	end
	self:RefreshTension()
	return count
end

-- Injects an event as if the player had done the action (the occurrence judges it as in play). Used by the showcase
-- when the real action needs setup that the panel cannot do (a made hot dog, a discard at the bin).
function AnomalyService:DevEmit(event: any)
	self:DevCheck()
	self:Emit(event)
end

function AnomalyService:DevStatus(): string
	self:DevCheck()
	const lines: { string } = {}
	const modules: { string } = {}
	for _, row in Content.Anomalies.List do
		if self.Modules[row.Key] ~= nil then
			table.insert(modules, row.Ref)
		end
	end
	table.insert(lines, `modules: {if #modules > 0 then table.concat(modules, ", ") else "none"}`)
	table.insert(lines, `rules: {#Rules.Keys()}, tension: {if self.TensionOn then "on" else "off"}`)
	const t = now()
	for id, run in self.Running do
		table.insert(
			lines,
			`#{id} {run.Occ.Ref} {run.Record.Phase} step {run.Record.Step} anchor {run.Record.Anchor} for {string.format(
				"%.1f",
				t - run.Occ.StartedAt
			)}s`
		)
	end
	if next(self.Running) == nil then
		table.insert(lines, "no occurrence running")
	end
	return table.concat(lines, "\n")
end

-- Agenda of the current night: game clock (H:MM) and state of each entry.
function AnomalyService:DevAgenda(): string
	self:DevCheck()
	if #self.Queue == 0 then
		return "no agenda (day shift or outside the Night phase)"
	end
	const lines: { string } = { `Night {self.Shift.Night} attempt {self.Shift.Attempt}: {#self.Queue} entries` }
	for _, due in self.Queue do
		const entry = due.Entry
		const minutes = math.floor(entry.At) % 1440
		const row = Content.Anomalies.ByKey[entry.Key]
		table.insert(
			lines,
			`{string.format("%02d:%02d", minutes // 60, minutes % 60)} {if row ~= nil then row.Ref else entry.Key}{if entry.Night
				then " night"
				elseif entry.Scripted
				then " scripted"
				elseif entry.Premiere then " premiere"
				elseif entry.Slot > Pressure.EXTRA_SLOT then " extra (sanity)"
				else ""}{if due.Done then " done" else ""}{if self.Modules[entry.Key] == nil
				then " (no module)"
				else ""}`
		)
	end
	return table.concat(lines, "\n")
end

-- Sanity pressure (DEC-352): each Active player's tier, the next personal scare, the extras of tonight.
-- now = true: the next extra roll and every personal scare are due at once (the chance still holds).
function AnomalyService:DevPressure(nowToo: boolean): string
	self:DevCheck()
	const t = now()
	if nowToo then
		Pressure.hurry(self.Pressure, t)
	end
	return Pressure.describe(self.Pressure, self, t)
end

-- Breaker trips (Q-435): tonight's count and the next one. now = true: the next trip is due at once (still waits for a
-- calm moment: no anomaly running, power on, bulb fine).
function AnomalyService:DevTrip(nowToo: boolean): string
	self:DevCheck()
	const t = now()
	if nowToo then
		Trip.hurry(self.Trip, t)
	end
	return Trip.describe(self.Trip, t)
end

-- One player's "behind you" posture for dev: distance to the window spot, gaze age, angle away from it
function AnomalyService:DevBehindPosture(player: Player): string
	const rules = Content.Nights.Behind
	const point = MapIndex.FindPoint(rules.Point)
	const character = player.Character
	const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if point == nil or root == nil or not root:IsA("BasePart") then
		return `{player.Name}: no {rules.Point} point or no character`
	end
	const offset = root.Position - point.Position
	const distance = Vector2.new(offset.X, offset.Z).Magnitude
	const gaze = self.Gazes[player]
	if gaze == nil or now() - gaze.At > GAZE_STALE then
		return string.format("%s: %.0f studs (near %d), no fresh gaze (first person / cooking only)", player.Name, distance, rules.Near)
	end
	const look = Vision.Direction(gaze.Yaw, gaze.Pitch)
	const toward = point.Position - root.Position
	const flatLook, flatToward = Vector3.new(look.X, 0, look.Z), Vector3.new(toward.X, 0, toward.Z)
	local angle = 0
	if flatLook.Magnitude > 1e-3 and flatToward.Magnitude > 1e-3 then
		angle = math.deg(math.acos(math.clamp(flatLook.Unit:Dot(flatToward.Unit), -1, 1)))
	end
	return string.format("%s: %.0f studs (near %d), %.0f deg from the window (needs %d)", player.Name, distance, rules.Near, angle, rules.Facing)
end

-- "Behind you": tonight's count, the next try, why it is busy, each player's posture. arg "now" = the next one is due
-- at once; "steps" | "creak" | "tap" = play that one on the caller right now (no calm check; the client still needs
-- the back to the window)
function AnomalyService:DevBehind(arg: string?, caller: Player?): string
	self:DevCheck()
	const t = now()
	if arg ~= nil and arg ~= "" and arg ~= "now" then
		const key = `behind_{arg}`
		if table.find(Content.Nights.Behind.Keys, key) == nil then
			error(`unknown sound '{arg}': steps, creak or tap`, 0)
		end
		if caller == nil then
			error("run it from the chat (it plays on the caller)", 0)
		end
		const sent = self:BehindScare(caller, key)
		return `{key} sent to {caller.Name} ({sent} client); turn your back to the window to hear it`
	end
	if arg == "now" then
		Behind.hurry(self.Behind, t)
	end
	const why = self:BehindWhy()
	const lines: { string } = { `{Behind.describe(self.Behind, t)}; {if why == nil then "calm" else `busy: {why}`}` }
	for _, player in self:ActivePlayers() do
		table.insert(lines, self:DevBehindPosture(player))
	end
	return table.concat(lines, "\n")
end

-- Beat director: last beat, what counts as active now, the next regular anomaly
function AnomalyService:DevBeats(): string
	self:DevCheck()
	const t = now()
	const due = self:BeatDueIn()
	const next = if due == math.huge then "none" else string.format("in %.0fs", due)
	return `{Director.describe(self.Director, Content.Nights.Beats, t, self:CrewSize(), self:RunningCount())}; next anomaly {next}; {self:DescribeNightEvent(t)}`
end

-- Night event line for the dev commands: key, game clock, state and the lock
function AnomalyService:DescribeNightEvent(t: number): string
	const event = self.NightEvent
	const entry = event.Entry
	if entry == nil then
		return "night event: none (no agenda)"
	end
	const minutes = math.floor(entry.At) % 1440
	const lock = if Director.locked(self.Director, t) then "LOCK on" else "lock off"
	const pool = table.concat(event.Pool, ", ")
	return `night event: {entry.Key} at {string.format("%02d:%02d", minutes // 60, minutes % 60)} {event.Phase}, {lock}, pool [{pool}]`
end

-- Night event (owner 2026-10-22). now = it is due at once (still waits NightMaxWait s for a running anomaly)
function AnomalyService:DevNightEvent(nowToo: boolean): string
	self:DevCheck()
	const event = self.NightEvent
	const entry = event.Entry
	if nowToo then
		if entry == nil or event.Phase ~= "pending" then
			error(`the night event is {event.Phase}: only a pending one can be hurried`, 0)
		end
		entry.At = self.Dependencies.RoundService:Minutes()
	end
	return self:DescribeNightEvent(now())
end

-- Lifecycle -------------------------------------------------------------------------------------------------------

AnomalyService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self.Enabled = true
	self:LoadModules()
	-- every rule file validated once at boot (DEC-074 warning shows up here, not at the first failure)
	Rules.Keys()
	self.Context = self:BuildContext()

	-- Responder only here (Lync.start runs in NetService OnStart)
	self.Libs.Net.Gaze:onServer(function(value, player: Player)
		self:OnGaze(value, player)
	end)

	-- Higher-priority services ran their Setup before this OnInit (§19.0 rule 2)
	const round = self.Dependencies.RoundService
	round.ShiftStarted:Connect(function(info)
		self:OnShiftStarted(info)
	end)
	round.PhaseChanged:Connect(function(phase)
		self:OnPhase(phase)
	end)

	self.Dependencies.CustomerService.Acted:Connect(function(id, action, player, result)
		self:Emit({ Kind = "Customer", Npc = id, Action = action, Player = player, Result = result })
	end)
	self.Dependencies.LightService.SwitchChanged:Connect(function(on, player)
		self:Emit({ Kind = "Switch", On = on, Player = player })
	end)
	self.Dependencies.InteractionService.Performed:Connect(function(player, action, anchor, id)
		self:Emit({ Kind = "Action", Player = player, Action = action, Anchor = anchor, Id = id })
	end)
	self.Dependencies.VehicleService.ShutterChanged:Connect(function(closed, player)
		self:Emit({ Kind = "Shutter", Closed = closed, Player = player })
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.Gazes[player] = nil
	end)
end)

AnomalyService:OnStart(function(self)
	if not self.Enabled then
		return
	end
	-- Lync.start already ran (NetService OnStart, priority 1000)
	self.Live = true

	-- Optional hooks (PROVISIONAL until TASK-104/109 land; see header)
	const traffic = lookup("TrafficService")
	if traffic ~= nil and type(traffic.Hold) == "function" then
		self.Traffic = traffic :: TrafficHook
	end
	const kitchen = self.Dependencies.KitchenService :: any
	connectOptional(kitchen.Discarded, "KitchenService.Discarded", function(player: Player, item: string, altered: boolean)
		self:Emit({ Kind = "Discard", Player = player, Item = item, Altered = altered == true })
	end)
end)

AnomalyService:OnTick(function(self)
	if self.Enabled then
		self:Step()
	end
end, TICK_RATE)

return AnomalyService
