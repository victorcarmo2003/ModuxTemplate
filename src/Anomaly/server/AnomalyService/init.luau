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
--               LoseNight("critical"), DEC-094), Succeed, Finish, Active, Looking (Gaze + Vision), SeenTick/See
--               (VitalService:SeeAnomaly), Rule, Spawn, Light, Vehicle, InZone, Kitchen, Traffic, Economy.
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
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Api = require(script.Api)
local Rules = require(script.Rules)
local Scheduler = require(script.Scheduler)
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

export type Run = {
	Occ: Api.Occurrence,
	Row: Content.Anomaly,
	Module: Api.Module,
	Record: Wire,
	Added: boolean,
	Starting: boolean,
	FinishPending: boolean,
	Done: boolean,
	Cues: { { Cue: string, Entity: number } },
	Failed: { [number]: boolean },
	CriticalSent: boolean,
	Seen: { [number]: number },
	SeenDone: { [number]: boolean },
}

export type Due = { Entry: Scheduler.Entry, RetryAt: number, Done: boolean }

export type Gaze = { Yaw: number, Pitch: number, At: number }

type TrafficHook = { Hold: (self: any, reason: string, on: boolean) -> () }

const TICK_RATE = 5 -- Hz (architecture.md §19.13: module Tick at 5 Hz)
const MAX_ID = 255 -- Anomalies record id range (network.md §13.5)
const STEP_MAX = 20 -- Anomalies.Step wire range
const ANCHOR_MAX = 65535 -- Anomalies.Anchor / AnomalyCue.Entity wire range
const SEED_MAX = 65535 -- AnomalyCue.Seed wire range
const RETRY = 1 -- s between two Start attempts of the same due entry (Start returned false)
const LINGER = 1 -- s a finished record stays in the set so clients see its last Phase
const GAZE_STALE = 1 -- s; the client sends at 10 Hz, an older gaze means it stopped (day, not Active)
const TARGET_SLACK = 2 -- studs; a hit this close to the target does not block the line of sight
const EYE_OFFSET = Vector3.new(0, 1.5, 0) -- HumanoidRootPart -> eye when the Head is missing
const DOMAIN = "anomaly"
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
	}
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
	-- the Night phase of this shift has started (the agenda is dropped when it ends)
	self.InNight = false :: boolean
	self.Gazes = {} :: { [Player]: Gaze }
	self.TensionOn = false :: boolean
	self.Traffic = nil :: TrafficHook?
	self.Warned = {} :: { [string]: boolean }
	-- Tension(on): created here so lower-priority services (PedestrianService 545) connect in their OnInit
	self.Tension = self.Libs.Signal.new() :: SignalLib.Signal<boolean>
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
	return workspace:Raycast(from, offset.Unit * (distance - TARGET_SLACK), params) ~= nil
end

function AnomalyService:Looking(player: Player, target: Vector3, range: number): boolean
	if typeof(target) ~= "Vector3" or not finite(range) then
		return false
	end
	if not self.Dependencies.RunStateService:IsActive(player) then
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
		Content.Sanity.SeeAngle,
		blocked
	)
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
	if phase == "Signal" or phase == "Active" or phase == "Resolved" or phase == "Failed" then
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
	run.Record = record
	self:Write(run)
end

function AnomalyService:FireCue(run: Run, cue: string, entity: number)
	const net = self.Dependencies.NetService
	if not self.Live or not net:IsRunning() then
		return
	end
	self.Libs.Net.AnomalyCue:fireClient(net.Audience, {
		Anomaly = run.Occ.Key,
		Cue = cue,
		Entity = entity,
		Seed = run.Occ.Rng:NextInteger(0, SEED_MAX),
	})
end

function AnomalyService:Cue(occ: Api.Occurrence, cue: string, entity: number?)
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
		table.insert(run.Cues, { Cue = cue, Entity = target })
		return
	end
	self:FireCue(run, cue, target)
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
		if not critical then
			vital:Penalize(player, `anomaly:{occ.Key}`)
		end
	end
	if critical and not run.CriticalSent then
		-- DEC-074, DEC-094: the night is lost at once, no 10 s window. False (not losable now) is not retried.
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
	}
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
	if self.Live and self.Dependencies.NetService:IsRunning() then
		self.Libs.Net.Anomalies:add(id, run.Record)
		run.Added = true
	end
	for _, cue in run.Cues do
		self:FireCue(run, cue.Cue, cue.Entity)
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
		Cue = function(occ: Api.Occurrence, cue: string, entity: number?)
			self:Cue(occ, cue, entity)
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
		Looking = function(player: Player, target: Vector3, range: number): boolean
			return self:Looking(player, target, range)
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
			BeginHush = function(startedAt: number, holdUntil: number)
				light:BeginHush(startedAt, holdUntil)
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
		},
		Log = function(occ: Api.Occurrence, message: string)
			warn(`{PREFIX} {occ.Ref}#{occ.Id}: {message}`)
		end,
	}
end

-- Agenda ----------------------------------------------------------------------------------------------------------

function AnomalyService:BuildAgenda(info: { Day: number, Night: number, IsNight: boolean, Attempt: number })
	self.Queue = {}
	if not info.IsNight or info.Night < 1 then
		return
	end
	const nights = Content.Nights.List
	const night = nights[math.clamp(info.Night, 1, #nights)]
	const phase = Content.Shift.ByKey[NIGHT_PHASE]
	const candidates: { Scheduler.Candidate } = {}
	-- Cart nights (user request 2026-10-12): an anomaly whose only answer is a trailer object (Trailer "Needs": the light
	-- switch) is replaced, slot by slot and with the same age (3/2/1 occurrences), by its stand-in, an earlier anomaly
	-- the cart can handle. The trailer brings the anomaly back; without it the night just repeats older ones.
	const vehicle: Content.Vehicle? = Content.Vehicles.ByKey[self.Dependencies.VehicleService:Current()]
	const hasSwitch: boolean = vehicle ~= nil and vehicle.HasSwitch
	for _, row in Content.Anomalies.ActiveOn(info.Night) do
		local stand: Content.Anomaly? = nil
		if row.Trailer == "Needs" and not hasSwitch then
			stand = Content.Anomalies.StandIn(row)
		end
		if stand ~= nil then
			const swapped = candidate(stand)
			swapped.Night = row.Night
			table.insert(candidates, swapped)
		else
			table.insert(candidates, candidate(row))
		end
	end
	const rng = Random.new(
		Scheduler.Seed(self.Dependencies.RunStateService.Seed(), info.Day, info.Night, info.Attempt, DOMAIN)
	)
	const entries = Scheduler.Build({
		Night = info.Night,
		Anomalies = candidates,
		Occurrences = Content.Nights.Occurrences,
		Window = Content.Nights.Windows.Shift,
		MinGap = night.MinGap,
		MinutesPerSecond = if night.Duration > 0 then (phase.ClockTo - phase.ClockFrom) / night.Duration else 0,
	}, function(): number
		return rng:NextNumber()
	end)
	for _, entry in entries do
		table.insert(self.Queue, { Entry = entry, RetryAt = 0, Done = false })
	end
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
function AnomalyService:StepAgenda(t: number)
	if self.DevHeld then
		return
	end
	const minutes = self.Dependencies.RoundService:Minutes()
	const windowEnd = Content.Nights.Windows.Shift[2]
	const limits = self:Limits()
	for _, due in self.Queue do
		const entry = due.Entry
		if due.Done or entry.At > minutes or t < due.RetryAt then
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
			const row = Content.Anomalies.ByKey[entry.Key]
			const since = if self.LastStartAt > 0 then t - self.LastStartAt else math.huge
			const admitted = Scheduler.Admit(candidate(row), self:RunningCandidates(), limits, since)
			if not admitted then
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
			`{string.format("%02d:%02d", minutes // 60, minutes % 60)} {row.Ref}{if entry.Scripted
				then " scripted"
				else ""}{if due.Done then " done" else ""}{if self.Modules[entry.Key] == nil
				then " (no module)"
				else ""}`
		)
	end
	return table.concat(lines, "\n")
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
