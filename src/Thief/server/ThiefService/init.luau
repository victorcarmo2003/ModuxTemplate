--!strict
-- Day thief, Quick Quentin (FEAT-013, NPC-007; DEC-050, DEC-159, DEC-182; architecture.md §19.10; network.md §13.4;
-- TASK-072). Run place only. Single writer of the Thief set (record 1). Numbers from Content.Thief and from the Cash
-- Drawer Lock effects (UpgradeService: DrawerOpenTime, StealPct).
--
-- Day: at ShiftStarted (not at night) Draw.roll(RunSeed, Day) decides if the day has a thief, its minute inside
-- WindowClock and its lurk point; at most MaxPerDay. When the clock reaches that minute in a day selling phase (Open)
-- it spawns at Spawn (ST-R) through NpcService (Role "Thief": counts in the NPC cap). Cap full -> retry after CapRetry
-- seconds until the window ends; past the window the day stays without a thief.
--
-- States (Thief.State): Lurking (walks to the lurk point without crossing a street, then waits up to LurkMax facing
-- the vehicle) -> nobody Active within ZoneRadius of the current vehicle's Zone_Center for ZoneEmptyTime ->
-- Approaching (walks to the drawer in ApproachTime fixed: speed = distance / ApproachTime, DEC-182) -> Opening
-- (DrawerOpenTime s; StartedAt/Duration drive the bar over Bar_Thief) -> Fleeing (ST-R or EX-E) -> None.
-- A member entering the zone while Approaching or Opening = caught: +CatchReward into the drawer ("Catch"), notice
-- thief_caught to everyone, RunState.Counters.quentin_caught_day = Day (boss call of the next day). Opening done:
-- Steal(floor(Drawer x StealPct / 100)) when Drawer >= MinDrawer, notice thief_stole. Zone check at 4 Hz (§19.10;
-- NPC-007 asks cancel <= 0.5 s). No snapshot (alive only); a restore re-runs ShiftStarted and the same draw.
--
-- PROVISIONAL (no Content field yet, asked to the architect in the TASK-072 note): walk speed to the lurk point and
-- run speed when fleeing; the drawer target is the Q1 point (the counter spot in front of the drawer, same on cart
-- and trailer, DEC-086); "in the zone" = horizontal distance; a lurking thief leaves when the shop stops selling.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Charm = require(ReplicatedStorage.Packages.Charm)
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Draw = require(script.Draw)
local Modux = require(ServerScriptService.server.Modux)

export type State = "None" | "Lurking" | "Approaching" | "Opening" | "Fleeing"

-- Thief set record (network.md §13.4)
export type Record = { State: State, StartedAt: number, Duration: number }

-- Why the thief leaves (Flee)
export type Outcome = "caught" | "stole" | "empty" | "gave_up" | "closed"

type Active = {
	Id: number, -- NpcId
	Lurk: string,
	Token: number, -- matches self.Token while this thief is the current one
	Arrived: boolean, -- reached the lurk point
	LurkStartedAt: number, -- server time of arrival at the lurk point
	EmptyFor: number, -- seconds the zone has been empty (Lurking)
	ApproachEndsAt: number,
	OpenEndsAt: number,
}

const RECORD = 1 -- single record (network.md §13.4)
const TICK_RATE = 4 -- Hz (architecture.md §19.10)
const DURATION_MAX = 30 -- Thief.Duration wire range
const ZONE_POINT = "Zone_Center" -- inside the Vehicle model (architecture.md §18.4)
const DRAWER_POINT = "Q1" -- PROVISIONAL drawer target (see header)
const VEHICLE_TAG = "Vehicle"
const VEHICLE_ATTRIBUTE = "Vehicle"
const CAUGHT_COUNTER = "quentin_caught_day" -- RunState.Counters key read by BossService (§19.9)
const NOTICE_CAUGHT = "thief_caught"
const NOTICE_STOLE = "thief_stole"
const DRAWER_OPEN_STAT = "DrawerOpenTime"
const STEAL_STAT = "StealPct"
-- PROVISIONAL speeds (studs/s) until Content.Thief has them (TASK-072 note to the architect)
const WALK_SPEED = 12
const FLEE_SPEED = 20
const MOVE_TIMEOUT = 8 -- Humanoid:MoveTo gives up at 8 s
const POLL = 0.1

local function now(): number
	return workspace:GetServerTimeNow()
end

local function flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function positionOf(instance: Instance): Vector3?
	if instance:IsA("Attachment") then
		return instance.WorldPosition
	elseif instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Model") then
		return instance:GetPivot().Position
	end
	return nil
end

const ThiefService = Modux.Service("ThiefService", {
	Require = {
		"PlaceService",
		"NetService",
		"RoundService",
		"RunStateService",
		"NpcService",
		"EconomyService",
		"UpgradeService",
	},
	Priority = 580,
})

function ThiefService:Setup()
	self.Enabled = false :: boolean
	self.Record = self.Libs.Charm.atom({ State = "None", StartedAt = 0, Duration = 0 } :: Record) :: Charm.Atom<Record>
	-- Today's draw (nil = no thief left to spawn today)
	self.Plan = nil :: Draw.Plan?
	-- Server time before which a planned spawn does not retry (CapRetry)
	self.RetryAt = 0 :: number
	-- Thieves spawned today (MaxPerDay)
	self.Today = 0 :: number
	self.Current = nil :: Active?
	-- Bumped at every new thief and abort: stale movement threads stop
	self.Token = 0 :: number
	self.Warned = {} :: { [string]: boolean }
end

function ThiefService:WarnOnce(key: string, message: string)
	if self.Warned[key] then
		return
	end
	self.Warned[key] = true
	warn(`[ThiefService] {message}`)
end

-- Reads -----------------------------------------------------------------------------------------------------------

function ThiefService:GetState(): State
	return self.Record().State
end

function ThiefService:GetPlan(): Draw.Plan?
	return self.Plan
end

function ThiefService:SetState(state: State, duration: number?)
	self.Record({
		State = state,
		StartedAt = if state == "None" then 0 else now(),
		Duration = math.clamp(duration or 0, 0, DURATION_MAX),
	})
end

-- Day selling phase: the thief only works in it (FEAT-013: day only)
function ThiefService:IsDaySelling(): boolean
	const round = self.Dependencies.RoundService
	if not round:IsStarted() or round:IsNight() then
		return false
	end
	const row = Content.Shift.ByKey[round:GetPhase()]
	return row ~= nil and row.Selling and row.Kind ~= "Night"
end

-- Zone_Center of the current vehicle (UpgradeService:GetVehicle), or the vehicle pivot, or nil without binding.
function ThiefService:ZoneCenter(): Vector3?
	const key = self.Dependencies.UpgradeService:GetVehicle()
	for _, vehicle in CollectionService:GetTagged(VEHICLE_TAG) do
		if vehicle:GetAttribute(VEHICLE_ATTRIBUTE) ~= key or not vehicle:IsDescendantOf(workspace) then
			continue
		end
		const point = vehicle:FindFirstChild(ZONE_POINT, true)
		const position = if point then positionOf(point) else nil
		if position ~= nil then
			return position
		end
		self:WarnOnce(`zone:{key}`, `Vehicle '{key}' has no {ZONE_POINT}: using its pivot`)
		return positionOf(vehicle)
	end
	self:WarnOnce(`vehicle:{key}`, `no Vehicle '{key}' in the Workspace: the zone is never empty`)
	return nil
end

-- Some member Active (connected, standing, not Down/Spectator) with the HRP within ZoneRadius of the zone centre.
-- No binding = guarded (never empty).
function ThiefService:ZoneGuarded(): boolean
	const center = self:ZoneCenter()
	if center == nil then
		return true
	end
	const radius = Content.Thief.ZoneRadius
	const runState = self.Dependencies.RunStateService
	for _, player in Players:GetPlayers() do
		if not runState:IsActive(player) then
			continue
		end
		const character = player.Character
		const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		const humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if root ~= nil and root:IsA("BasePart") and humanoid ~= nil and humanoid.Health > 0 then
			if flat(root.Position, center) <= radius then
				return true
			end
		end
	end
	return false
end

-- Movement (own threads; every one stops when the token changes) --------------------------------------------------

function ThiefService:Alive(active: Active): boolean
	return self.Current == active and self.Token == active.Token
end

function ThiefService:Humanoid(id: number): Humanoid?
	const npc = self.Dependencies.NpcService:Get(id)
	return if npc then npc.Rig.Humanoid else nil
end

-- Straight MoveTo (off the graph). YIELDS until reached, timeout or the thief is replaced.
function ThiefService:MoveDirect(active: Active, target: Vector3): boolean
	const humanoid = self:Humanoid(active.Id)
	if humanoid == nil then
		return false
	end
	local finished: boolean? = nil
	const connection = humanoid.MoveToFinished:Connect(function(reached: boolean)
		finished = reached
	end)
	humanoid:MoveTo(target)
	const deadline = os.clock() + MOVE_TIMEOUT
	while finished == nil and self:Alive(active) and os.clock() < deadline do
		task.wait(POLL)
	end
	connection:Disconnect()
	return finished == true
end

function ThiefService:WalkIn(active: Active)
	const npcs = self.Dependencies.NpcService
	if npcs:WalkTo(active.Id, active.Lurk, { AvoidCrossings = true }) then
		if self:Alive(active) then
			active.Arrived = true
			active.LurkStartedAt = now()
			active.EmptyFor = 0
		end
		return
	end
	if self:Alive(active) and self:GetState() == "Lurking" then
		self:WarnOnce(`route:{active.Lurk}`, `no route to {active.Lurk}: thief removed`)
		self:Abort()
	end
end

-- Nearest exit first (straight line), then the others.
function ThiefService:ExitOrder(from: Vector3): { string }
	const exits = table.clone(Content.Thief.Exits)
	const distance: { [string]: number } = {}
	for _, exit in exits do
		const point = MapIndex.FindPoint(exit)
		distance[exit] = if point then flat(point.Position, from) else math.huge
	end
	table.sort(exits, function(a: string, b: string): boolean
		return distance[a] < distance[b]
	end)
	return exits
end

function ThiefService:RunAway(active: Active)
	const npcs = self.Dependencies.NpcService
	const humanoid = self:Humanoid(active.Id)
	const npc = npcs:Get(active.Id)
	if humanoid == nil or npc == nil then
		return
	end
	npcs:Stop(active.Id)
	humanoid.WalkSpeed = FLEE_SPEED
	-- Off the graph (drawer): back to the lurk node first, so the route starts where the rig stands
	if active.Arrived then
		const lurk = MapIndex.FindPoint(active.Lurk)
		if lurk ~= nil then
			self:MoveDirect(active, lurk.Position)
		end
	end
	for _, exit in self:ExitOrder(npc.Rig.Root.Position) do
		if not self:Alive(active) then
			return
		end
		if npcs:WalkTo(active.Id, exit, { AvoidCrossings = true, Face = false }) then
			break
		end
	end
	if self:Alive(active) then
		self:Remove()
	end
end

-- Life cycle --------------------------------------------------------------------------------------------------------

-- Spawns the thief at Spawn and sends it to `lurk`. Returns the NpcId, or nil + reason ("cap" = NPC cap full).
function ThiefService:Spawn(lurk: string): (number?, string?)
	const npcs = self.Dependencies.NpcService
	if npcs:Count() >= npcs:Capacity() then
		return nil, "cap"
	end
	const id = npcs:Spawn({ Role = "Thief", From = Content.Thief.Spawn })
	if id == nil then
		return nil, "refused"
	end
	const humanoid = self:Humanoid(id)
	if humanoid ~= nil then
		humanoid.WalkSpeed = WALK_SPEED
	end
	self.Token += 1
	const active: Active = {
		Id = id,
		Lurk = lurk,
		Token = self.Token,
		Arrived = false,
		LurkStartedAt = 0,
		EmptyFor = 0,
		ApproachEndsAt = 0,
		OpenEndsAt = 0,
	}
	self.Current = active
	self.Today += 1
	self:SetState("Lurking")
	task.spawn(function()
		self:WalkIn(active)
	end)
	return id, nil
end

-- Thief gone (despawned), state None.
function ThiefService:Remove()
	const active = self.Current
	self.Current = nil
	self.Token += 1
	if active ~= nil then
		self.Dependencies.NpcService:Despawn(active.Id)
	end
	self:SetState("None")
end

-- Immediate removal (new shift, restore, dev).
function ThiefService:Abort()
	if self.Current ~= nil or self:GetState() ~= "None" then
		self:Remove()
	end
end

function ThiefService:Approach(active: Active)
	const humanoid = self:Humanoid(active.Id)
	const npc = self.Dependencies.NpcService:Get(active.Id)
	const target = MapIndex.FindPoint(DRAWER_POINT)
	if humanoid == nil or npc == nil or target == nil then
		self:WarnOnce("drawer", `no {DRAWER_POINT} point or rig: thief removed`)
		self:Abort()
		return
	end
	const approach = Content.Thief.ApproachTime
	const distance = flat(npc.Rig.Root.Position, target.Position)
	self.Dependencies.NpcService:Stop(active.Id)
	humanoid.WalkSpeed = math.max(distance / approach, 1)
	active.ApproachEndsAt = now() + approach
	self:SetState("Approaching", approach)
	task.spawn(function()
		self:MoveDirect(active, target.Position)
	end)
end

function ThiefService:Open(active: Active)
	const duration = self.Dependencies.UpgradeService:GetEffect(DRAWER_OPEN_STAT)
	active.OpenEndsAt = now() + duration
	self:SetState("Opening", duration)
end

-- Leaves (no theft unless Steal ran before). `outcome` only for the dev log.
function ThiefService:Flee(active: Active, _outcome: Outcome)
	self:SetState("Fleeing")
	task.spawn(function()
		self:RunAway(active)
	end)
end

function ThiefService:Caught(active: Active)
	const economy = self.Dependencies.EconomyService
	const runState = self.Dependencies.RunStateService
	const added = economy:AddSale(Content.Thief.CatchReward, "Catch")
	runState:Notify("all", NOTICE_CAUGHT, added)
	const counters = table.clone(runState.Counters())
	counters[CAUGHT_COUNTER] = self.Dependencies.RoundService:GetDay()
	runState.Counters(counters)
	self:Flee(active, "caught")
end

-- Opening finished: floor(Drawer x StealPct / 100) when Drawer >= MinDrawer (FEAT-013).
function ThiefService:Rob(active: Active)
	const economy = self.Dependencies.EconomyService
	const drawer = economy:GetDrawer()
	if drawer < Content.Thief.MinDrawer then
		self:Flee(active, "empty")
		return
	end
	const pct = self.Dependencies.UpgradeService:GetEffect(STEAL_STAT)
	const taken = economy:Steal(math.floor(drawer * pct / 100))
	if taken > 0 then
		self.Dependencies.RunStateService:Notify("all", NOTICE_STOLE, taken)
	end
	self:Flee(active, "stole")
end

-- Day plan ----------------------------------------------------------------------------------------------------------

function ThiefService:OnShiftStarted()
	self:Abort()
	self.Plan = nil
	self.RetryAt = 0
	self.Today = 0
	const round = self.Dependencies.RoundService
	if round:IsNight() then
		return
	end
	if Content.Thief.MaxPerDay < 1 then
		return
	end
	-- anomaly mode (Content.Mode.DayOnly = false, owner request 2026-10-14): the trailer is closed, nobody robs it
	if not Content.Mode.DayOnly then
		return
	end
	self.Plan = Draw.roll(self.Dependencies.RunStateService.Seed(), round:GetDay())
end

-- Leaving a phase: a lurking thief gives up when the shop stops selling; approaching or opening goes on while the
-- drawer still takes entries (day Closing), otherwise it flees.
function ThiefService:OnPhase()
	const active = self.Current
	if active == nil then
		return
	end
	const state = self:GetState()
	if state == "Lurking" and not self:IsDaySelling() then
		self:Flee(active, "closed")
	elseif (state == "Approaching" or state == "Opening") and not self.Dependencies.EconomyService:IsDrawerOpen() then
		self:Flee(active, "closed")
	end
end

-- Planned spawn: in a day selling phase, once the clock reaches the minute; the window end cancels the day.
function ThiefService:StepPlan()
	const plan = self.Plan
	if plan == nil or self.Current ~= nil or not self:IsDaySelling() then
		return
	end
	if self.Today >= Content.Thief.MaxPerDay then
		self.Plan = nil
		return
	end
	const minutes = self.Dependencies.RoundService:Minutes()
	if minutes > Content.Thief.WindowClock[2] then
		self.Plan = nil
		return
	end
	if minutes < plan.At or os.clock() < self.RetryAt then
		return
	end
	const id, reason = self:Spawn(plan.Lurk)
	if id ~= nil then
		self.Plan = nil
	elseif reason == "cap" then
		self.RetryAt = os.clock() + Content.Thief.CapRetry
	else
		self:WarnOnce(`spawn:{reason}`, `thief spawn refused ({reason}): no thief today`)
		self.Plan = nil
	end
end

function ThiefService:StepActive(dt: number)
	const active = self.Current
	if active == nil then
		return
	end
	if self.Dependencies.NpcService:Get(active.Id) == nil then
		-- Despawned by someone else
		self.Current = nil
		self.Token += 1
		self:SetState("None")
		return
	end
	const thief = Content.Thief
	const state = self:GetState()
	const t = now()
	if state == "Lurking" then
		if not active.Arrived then
			return
		end
		if t - active.LurkStartedAt >= thief.LurkMax then
			self:Flee(active, "gave_up")
			return
		end
		if self:ZoneGuarded() then
			active.EmptyFor = 0
			return
		end
		active.EmptyFor += dt
		if active.EmptyFor >= thief.ZoneEmptyTime then
			self:Approach(active)
		end
	elseif state == "Approaching" or state == "Opening" then
		if self:ZoneGuarded() then
			self:Caught(active)
		elseif state == "Approaching" and t >= active.ApproachEndsAt then
			self:Open(active)
		elseif state == "Opening" and t >= active.OpenEndsAt then
			self:Rob(active)
		end
	end
end

function ThiefService:Step(dt: number)
	self:StepActive(dt)
	self:StepPlan()
end

-- Dev hooks (Commands/Thief.luau) -----------------------------------------------------------------------------------

-- Spawns the thief now (ignores chance, window and MaxPerDay; still day selling only). Returns the NpcId.
function ThiefService:DevNow(lurk: string?): number
	if not self.Dependencies.PlaceService:IsDev() then
		error("[ThiefService] DevNow is dev mode only", 2)
	end
	if not self.Enabled then
		error("[ThiefService] not the Run place", 2)
	end
	if not self:IsDaySelling() then
		error("[ThiefService] the thief only comes while the shop is open by day (skip to Open first)", 2)
	end
	const lurks = Content.Thief.Lurks
	if lurk ~= nil and table.find(lurks, lurk) == nil then
		error(`[ThiefService] lurk must be one of {table.concat(lurks, ", ")}`, 2)
	end
	self:Abort()
	self.Plan = nil
	const id, reason = self:Spawn(lurk or lurks[math.random(1, #lurks)])
	if id == nil then
		error(`[ThiefService] spawn refused ({reason})`, 2)
	end
	return id
end

-- Network -----------------------------------------------------------------------------------------------------------

ThiefService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self.Enabled = true

	-- RoundService (750) created its signals in its own OnInit, before ours
	const round = self.Dependencies.RoundService
	round.ShiftStarted:Connect(function()
		self:OnShiftStarted()
	end)
	round.PhaseChanged:Connect(function()
		self:OnPhase()
	end)
end)

ThiefService:OnStart(function(self)
	if not self.Enabled then
		return
	end

	-- Lync.start already ran (NetService OnStart, priority 1000). Late joiners get the record from the set.
	self.Libs.Net.Thief:add(RECORD, self.Record())
	self.Libs.Charm.effect(function()
		const record = self.Record()
		if self.Dependencies.NetService:IsRunning() then
			self.Libs.Net.Thief:update(RECORD, record)
		end
	end)
end)

ThiefService:OnTick(function(self)
	if self.Enabled then
		self:Step(1 / TICK_RATE)
	end
end, TICK_RATE)

return ThiefService
