--!strict
-- Server NPCs, minimal (architecture.md §12.3, §18.4, §18.6, T11; network.md §5; TASK-031).
-- Run place only. Owns the pool of animal rigs (DEC-149), their identity (NpcId, new on every spawn) and their look
-- attributes (Species, Outfit, CustomerType, LookPack; network.md §5.2). The server never dresses: each client does
-- (CrewRig.Dress, T40). Moves NPCs with Humanoid:MoveTo along A* routes on the NpcNode graph (MapIndex.Path).
-- Who spawns, where they queue and when they leave is CustomerService (TASK-032); this service only obeys.
--
-- Rules kept here:
--   - never more than Content.Flow.MaxNpc rigs (12, DEC-045); Opal is not one of them (DEC-191);
--   - customers (Role "Customer") never wear the crew uniform nor the raccoon; the raccoon in the thief outfit and
--     ThiefHat is Role "Thief" only (Quick Quentin, NPC-007; DEC-159, DEC-186; TASK-072). Pedestrians: DEC-183, Q-162;
--   - LookPack Day by day, Mid at night (DEC-181), refreshed at every ShiftStarted. Night is tension only (local
--     low-sanity swap on the client, DEC-168/169; anomaly mood, Q-159): SetTension(on) (AnomalyService, wave 3)
--     writes Night on Role "Customer" rigs whose outfit has the Night pack; actors and the thief keep the shift pack
--     so the anomaly sign never changes (Q-147 c). Tension drops at every ShiftStarted (PROVISIONAL, Q-159);
--   - Role "Actor" (wave 3, TASK-108): a customer-anomaly look (same draw as a customer, or forced) + the Variant
--     attribute (blank, mirror, raincoat) the client applies locally (TASK-110). Counts in the cap like any NPC;
--   - collision group Npc, not colliding with Players nor Npc (architecture.md §12.3);
--   - queue slots Q1..Q5 are never intermediate route steps (MAP-01 §9.1 note): AvoidQueue on by default;
--   - at most ROUTES_PER_FRAME A* searches per frame (§12.3);
--   - crosswalk edges wait for TrafficService:ReserveCrossing(cw, NpcId) on the near curb (§8.1, DEC-133; TASK-122,
--     Walker.Follow); released on the far curb, on the failsafe snap and on cancel.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Look = require(script.Look)
local Pool = require(script.Pool)
local Walker = require(script.Walker)
local Modux = require(ServerScriptService.server.Modux)

-- Who the NPC is (architecture.md §19.3). "Actor": customer anomaly (wave 3, CustomerService:SpawnActor).
export type Role = "Customer" | "Thief" | "Actor"

-- Customer-anomaly variant (architecture.md §19.13; ANM-001 blank, ANM-004 mirror, ANM-005 raincoat). Rig attribute.
export type Variant = "blank" | "mirror" | "raincoat"

export type Npc = {
	Id: number,
	Rig: Pool.Rig,
	Role: Role,
	CustomerType: string, -- "" for the thief
	Species: string,
	Outfit: string,
	Variant: Variant?, -- Role "Actor" only
	Node: string, -- last graph node reached (spawn point at first)
	Walk: number, -- walk order counter: a new order or a despawn cancels the running one
}

export type SpawnRequest = {
	Role: Role?, -- default "Customer". "Thief": Quick Quentin; CustomerType/Species/Outfit are ignored
	Variant: Variant?, -- required with Role "Actor", refused with any other role
	CustomerType: string?, -- default: weighted draw among the types unlocked this shift (Look.PickType)
	Species: string?, -- forced species (must belong to the type)
	Outfit: string?, -- forced civil outfit
	From: string?, -- spawn node/point id (default: SPAWN_POINTS)
	Rng: Random?, -- seeded Random of the run (architecture.md §4 rule 6); default: the service Random
}

export type WalkOptions = {
	AvoidQueue: boolean?, -- default true: Q1..Q5 only as start or goal
	AvoidCrossings: boolean?, -- default false (thief, wave 2)
	Face: boolean?, -- default true: on arrival, face the MapPoint direction of the goal (when it is a point)
}

type SpawnWeight = { Point: string, Weight: number }

const GROUP = "Npc"
const PLAYERS_GROUP = "Players" -- CharacterService (TASK-018) puts the crew parts here
const FOLDER_NAME = "Npcs"
const PARKING_NAME = "NpcPool"
const THIEF_NPC = "NPC-007" -- Species/Outfits.ReservedFor of Quick Quentin
const THIEF_HAT = "ThiefHat" -- kit name, Assets.Crew.Hats (AST-053, DEC-159)
const THIEF_KEY = "Thief" -- pool geometry key suffix (no customer type, no accessories)
const VARIANT_ATTRIBUTE = "Variant" -- rig attribute read by the client (TASK-110)
const VARIANTS: { [string]: true } = { blank = true, mirror = true, raincoat = true }
const NIGHT_PACK = "Night"
const MAX_ID = 65535 -- NpcId wire range (Customers id, Sale.Npc)
const ROUTES_PER_FRAME = 2 -- architecture.md §12.3
const LIFT = 3 -- HumanoidRootPart above the floor point (architecture.md §18.5)
-- Arrival points (MAP-01 §9.1). Wave 1 has no SP-B: PROVISIONAL day split SP-A/D1 = 30/30 of the MAP-01 table
-- renormalised to 50/50; night = MAP-01 night column (SP-A 60, D1 40). No Content table holds these yet.
const SPAWN_POINTS: { Day: { SpawnWeight }, Night: { SpawnWeight } } = {
	Day = { { Point = "SP-A", Weight = 30 }, { Point = "D1", Weight = 30 } },
	Night = { { Point = "SP-A", Weight = 60 }, { Point = "D1", Weight = 40 } },
}

local function nodePosition(id: string): Vector3?
	const ok, info = pcall(MapIndex.Node, id)
	if ok then
		return info.Position
	end
	return nil
end

local function registerGroup(name: string)
	if not PhysicsService:IsCollisionGroupRegistered(name) then
		PhysicsService:RegisterCollisionGroup(name)
	end
end

const NpcService = Modux.Service("NpcService", {
	Require = { "PlaceService", "RoundService", "TrafficService" },
	Priority = 610,
})

function NpcService:Setup()
	self.Enabled = false :: boolean
	self.Pool = Pool.new(Content.Flow.MaxNpc) :: Pool.Pool
	self.Active = {} :: { [number]: Npc }
	self.ByModel = {} :: { [Model]: number }
	self.NextId = 0 :: number
	self.Random = Random.new() :: Random
	self.Frame = 1 :: number
	self.RouteFrame = 0 :: number
	self.RoutesInFrame = 0 :: number
	self.Folder = nil :: Folder?
	self.Parking = nil :: Folder?
	self.Warned = {} :: { [string]: boolean }
	-- Anomaly mood (SetTension; Q-159): Role "Customer" rigs wear the Night pack while on
	self.Tension = false :: boolean
	-- Created here so CustomerService (590) connects in its OnInit
	self.Spawned = self.Libs.Signal.new() :: SignalLib.Signal<number, Model>
	self.Despawned = self.Libs.Signal.new() :: SignalLib.Signal<number>
end

function NpcService:WarnOnce(key: string, message: string)
	if self.Warned[key] then
		return
	end
	self.Warned[key] = true
	warn(`[NpcService] {message}`)
end

-- Reads -----------------------------------------------------------------------------------------------------------

function NpcService:Get(id: number): Npc?
	return self.Active[id]
end

function NpcService:GetModel(id: number): Model?
	const npc = self.Active[id]
	return if npc then npc.Rig.Model else nil
end

-- Customer and Refuse prompt anchors of an active NPC (architecture.md §18.4).
function NpcService:Anchors(id: number): (Attachment?, Attachment?)
	const npc = self.Active[id]
	if npc == nil then
		return nil, nil
	end
	return npc.Rig.Customer, npc.Rig.Refuse
end

-- NpcId of the active rig that contains `instance` (prompt anchor, body part, the model itself).
function NpcService:IdOf(instance: Instance): number?
	local current: Instance? = instance
	while current ~= nil and current ~= workspace do
		if current:IsA("Model") then
			const id = self.ByModel[current]
			if id ~= nil then
				return id
			end
		end
		current = current.Parent
	end
	return nil
end

-- Last node reached by the NPC.
function NpcService:GetNode(id: number): string?
	const npc = self.Active[id]
	return if npc then npc.Node else nil
end

function NpcService:Count(): number
	return (Pool.counts(self.Pool))
end

function NpcService:Capacity(): number
	return self.Pool.Capacity
end

-- Rigs alive (active + parked) and rigs built since boot (soak check, T031-03).
function NpcService:PoolStats(): (number, number)
	const _, total = Pool.counts(self.Pool)
	return total, self.Pool.Builds
end

-- Pack worn by every NPC now (DEC-181): Day by day, Mid at night.
function NpcService:Pack(): string
	return if self.Dependencies.RoundService:IsNight() then "Mid" else "Day"
end

-- Pack an NPC wears now: the shift pack, or Night under tension for Role "Customer" rigs whose outfit has it.
function NpcService:PackFor(role: Role, outfit: string): string
	if self.Tension and role == "Customer" then
		const row = Content.Outfits.ByKey[outfit]
		if row ~= nil then
			for _, pack in row.Packs do
				if pack == NIGHT_PACK then
					return NIGHT_PACK
				end
			end
		end
	end
	return self:Pack()
end

function NpcService:IsTension(): boolean
	return self.Tension
end

-- Customer type draw for the current shift (weighted, unlocked types only).
function NpcService:PickType(rng: Random?): string?
	const info = self.Dependencies.RoundService:Info()
	return Look.PickType(info.Day, info.Night, info.IsNight, rng or self.Random)
end

-- Spawn / despawn -------------------------------------------------------------------------------------------------

function NpcService:AllocateId(): number?
	for _ = 1, MAX_ID do
		self.NextId = self.NextId % MAX_ID + 1
		if self.Active[self.NextId] == nil then
			return self.NextId
		end
	end
	return nil
end

function NpcService:PickSpawnPoint(isNight: boolean, rng: Random): string
	const list = if isNight then SPAWN_POINTS.Night else SPAWN_POINTS.Day
	local total = 0
	for _, entry in list do
		total += entry.Weight
	end
	local roll = rng:NextNumber() * total
	for _, entry in list do
		roll -= entry.Weight
		if roll < 0 then
			return entry.Point
		end
	end
	return list[#list].Point
end

-- Look of a spawn request: customer draw, or the reserved thief look (Role "Thief"). nil + reason when refused;
-- the third value is a WarnOnce key for refusals that repeat every spawn attempt (no type unlocked).
function NpcService:Choose(r: SpawnRequest, rng: Random): (Look.Choice?, string?, string?)
	const role = r.Role or "Customer"
	if role == "Thief" then
		const reserved, problem = Look.Reserved(THIEF_NPC)
		if reserved == nil then
			return nil, problem, nil
		end
		return { CustomerType = "", Species = reserved.Species, Outfit = reserved.Outfit }, nil, nil
	end
	if role ~= "Customer" and role ~= "Actor" then
		return nil, `unknown Role '{role}'`, nil
	end
	if role == "Actor" then
		if r.Variant == nil or not VARIANTS[r.Variant] then
			return nil, `Role Actor needs a Variant (blank, mirror, raincoat), got '{tostring(r.Variant)}'`, nil
		end
	elseif r.Variant ~= nil then
		return nil, `Variant is for Role Actor only (Role '{role}')`, nil
	end
	const info = self.Dependencies.RoundService:Info()
	const typeKey = r.CustomerType or Look.PickType(info.Day, info.Night, info.IsNight, rng)
	if typeKey == nil then
		return nil, `no customer type unlocked for Day {info.Day} / Night {info.Night}`, "no-type"
	end
	const choice, problem = Look.Pick(typeKey, rng, r.Species, r.Outfit)
	return choice, problem, nil
end

-- New NPC at a spawn point. Returns its NpcId, or nil (service off, pool full, bad request, no binding).
-- Every role counts in the cap (Content.Flow.MaxNpc). The thief keeps the WalkSpeed its owner sets (ThiefService).
function NpcService:Spawn(request: SpawnRequest?): number?
	if not self.Enabled then
		return nil
	end
	const r: SpawnRequest = request or {}
	const rng = r.Rng or self.Random
	const info = self.Dependencies.RoundService:Info()
	const role: Role = r.Role or "Customer"
	const isThief = role == "Thief"

	const choice, problem, onceKey = self:Choose(r, rng)
	if choice == nil then
		if onceKey ~= nil then
			self:WarnOnce(onceKey, problem or onceKey)
		else
			warn(`[NpcService] Spawn refused: {problem}`)
		end
		return nil
	end

	const from = r.From or self:PickSpawnPoint(info.IsNight, rng)
	const position = nodePosition(from)
	if position == nil then
		self:WarnOnce(`node:{from}`, `spawn node {from} not in the NpcNode graph (TASK-005 binding?)`)
		return nil
	end
	const point = MapIndex.FindPoint(from)
	const rotation = if point then point.Rotation else CFrame.identity

	const id = self:AllocateId()
	const parking = self.Parking
	const folder = self.Folder
	if id == nil or parking == nil or folder == nil then
		return nil
	end

	const poolKey = Look.Key(choice.Species, if isThief then THIEF_KEY else choice.CustomerType)
	const rig = Pool.acquire(self.Pool, poolKey, function(): Pool.Rig?
		const spec: Pool.BuildSpec = {
			Species = choice.Species,
			Outfit = choice.Outfit,
			CustomerType = if isThief then nil else choice.CustomerType,
			Hat = if isThief then THIEF_HAT else nil,
			Group = GROUP,
			Parking = parking,
		}
		const ok, result = pcall(Pool.build, spec)
		if not ok then
			self:WarnOnce(`build:{poolKey}`, `rig build failed: {result}`)
			return nil
		end
		return result
	end)
	if rig == nil then
		return nil
	end

	const model = rig.Model
	model.Name = `Npc_{id}`
	-- Look attributes before entering the Workspace: the client dresses the complete rig at once (Atomic streaming)
	model:SetAttribute("Outfit", choice.Outfit)
	model:SetAttribute("LookPack", self:PackFor(role, choice.Outfit))
	model:SetAttribute("NpcId", id)
	model:SetAttribute(VARIANT_ATTRIBUTE, if role == "Actor" then r.Variant else nil)
	if not isThief then
		rig.Humanoid.WalkSpeed = Content.CustomerTypes.ByKey[choice.CustomerType].WalkSpeed
	end
	model:PivotTo(CFrame.new(position + Vector3.new(0, LIFT, 0)) * rotation)
	model.Parent = folder
	if rig.Root:CanSetNetworkOwnership() then
		rig.Root:SetNetworkOwner(nil) -- server owns NPC physics (architecture.md §12.3)
	end

	const npc: Npc = {
		Id = id,
		Rig = rig,
		Role = role,
		CustomerType = choice.CustomerType,
		Species = choice.Species,
		Outfit = choice.Outfit,
		Variant = if role == "Actor" then r.Variant else nil,
		Node = from,
		Walk = 0,
	}
	self.Active[id] = npc
	self.ByModel[model] = id
	self.Spawned:Fire(id, model)
	return id
end

-- Back to the pool. Cancels any walk. false = unknown id.
function NpcService:Despawn(id: number): boolean
	const npc = self.Active[id]
	if npc == nil then
		return false
	end
	npc.Walk += 1
	self.Active[id] = nil
	self.ByModel[npc.Rig.Model] = nil
	const parking = self.Parking
	if parking ~= nil then
		Pool.release(self.Pool, npc.Rig, os.clock(), parking)
	end
	self.Despawned:Fire(id)
	return true
end

function NpcService:DespawnAll()
	const ids: { number } = {}
	for id in self.Active do
		table.insert(ids, id)
	end
	for _, id in ids do
		self:Despawn(id)
	end
end

-- Movement --------------------------------------------------------------------------------------------------------

-- A* on the graph, at most ROUTES_PER_FRAME per frame (yields to the next frame when the budget is spent).
function NpcService:Route(from: string, to: string, options: WalkOptions?): { string }?
	while true do
		if self.RouteFrame ~= self.Frame then
			self.RouteFrame = self.Frame
			self.RoutesInFrame = 0
		end
		if self.RoutesInFrame < ROUTES_PER_FRAME then
			break
		end
		task.wait()
	end
	self.RoutesInFrame += 1
	const o: WalkOptions = options or {}
	return MapIndex.Path(from, to, {
		AvoidQueue = o.AvoidQueue ~= false,
		AvoidCrossings = o.AvoidCrossings == true,
	})
end

-- Walks NPC `id` from its last node to node `target` along the graph. YIELDS until it arrives (true) or the walk
-- is cancelled by Stop, a newer WalkTo or Despawn, or there is no route (false). Call from its own thread.
function NpcService:WalkTo(id: number, target: string, options: WalkOptions?): boolean
	const npc = self.Active[id]
	if npc == nil then
		return false
	end
	npc.Walk += 1
	const order = npc.Walk
	local function alive(): boolean
		return self.Active[id] == npc and npc.Walk == order
	end

	if npc.Node == target then
		return true
	end
	const path = self:Route(npc.Node, target, options)
	if not alive() then
		return false
	end
	if path == nil then
		self:WarnOnce(`path:{npc.Node}>{target}`, `no route {npc.Node} -> {target} on the NpcNode graph`)
		return false
	end

	const points: { Vector3 } = {}
	const crossings: { [number]: string } = {}
	for index = 2, #path do
		const node = MapIndex.Node(path[index])
		table.insert(points, node.Position)
		const previous = MapIndex.Node(path[index - 1])
		if node.Crosswalk ~= nil and node.Crosswalk == previous.Crosswalk then
			crossings[index - 1] = node.Crosswalk
		end
	end
	const done = Walker.Follow(npc.Rig, points, alive, function(index: number)
		npc.Node = path[index + 1]
	end, self:Crossing(id, crossings))
	if not done or not alive() then
		return false
	end

	if options == nil or options.Face ~= false then
		const point = MapIndex.FindPoint(target)
		if point ~= nil then
			Walker.Face(npc.Rig, point.LookVector)
		end
	end
	return true
end

-- Crosswalk reservations of NPC `id` for Walker.Follow (TrafficService runs in game time only, never in OnInit)
function NpcService:Crossing(id: number, at: { [number]: string }): Walker.Crossing?
	if next(at) == nil then
		return nil
	end
	const traffic = self.Dependencies.TrafficService
	return {
		At = at,
		Reserve = function(cw: string): boolean
			return traffic:ReserveCrossing(cw, id)
		end,
		Release = function(cw: string)
			traffic:ReleaseCrossing(cw, id)
		end,
		MaxWait = Content.Traffic.Crossing.MaxWait,
	}
end

-- Cancels the current walk; the NPC stops where it is (its Node stays the last one reached).
function NpcService:Stop(id: number)
	const npc = self.Active[id]
	if npc == nil then
		return
	end
	npc.Walk += 1
	Walker.Stop(npc.Rig)
end

-- Look pack -------------------------------------------------------------------------------------------------------

-- Turn change (DEC-181) or tension change: every NPC gets the pack it should wear now (PackFor). Attribute only;
-- clients re-dress (T40).
function NpcService:RefreshPacks()
	for _, npc in self.Active do
		const pack = self:PackFor(npc.Role, npc.Outfit)
		if npc.Rig.Model:GetAttribute("LookPack") ~= pack then
			npc.Rig.Model:SetAttribute("LookPack", pack)
		end
	end
end

-- Anomaly mood (architecture.md §19.13 "Tensão"; Q-159, PROVISIONAL): AnomalyService calls it while an occurrence
-- with Anomalies[k].Tension runs. Customers on the street switch to the Night pack at once; new spawns too.
function NpcService:SetTension(on: boolean)
	if self.Tension == on then
		return
	end
	self.Tension = on
	self:RefreshPacks()
end

-- Dev hook (Command Bar; CustomerService does this for real in TASK-032) ------------------------------------------

-- Spawns `count` customers that walk to Q5, along the queue to Q1 and out by EX-E, then return to the pool.
function NpcService:DevParade(count: number?)
	if not self.Dependencies.PlaceService:IsDev() then
		error("[NpcService] DevParade is dev mode only", 2)
	end
	for _ = 1, count or 1 do
		const id = self:Spawn()
		if id == nil then
			warn("[NpcService] DevParade: spawn refused (pool full or no binding)")
			break
		end
		task.spawn(function()
			if self:WalkTo(id, "Q5") and self:WalkTo(id, "Q1", { AvoidQueue = false }) then
				task.wait(1)
				self:WalkTo(id, "EX-E")
			end
			self:Despawn(id)
		end)
		task.wait(1.5)
	end
end

NpcService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self.Enabled = true

	registerGroup(GROUP)
	registerGroup(PLAYERS_GROUP)
	PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(GROUP, PLAYERS_GROUP, false)

	const folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = workspace
	self.Folder = folder
	const parking = Instance.new("Folder")
	parking.Name = PARKING_NAME
	parking.Parent = ServerStorage
	self.Parking = parking

	-- RoundService (750) created its signals in its own OnInit, before ours
	self.Dependencies.RoundService.ShiftStarted:Connect(function()
		self.Tension = false -- a new shift starts calm; AnomalyService raises it again if needed
		self:RefreshPacks()
	end)
	-- Frame counter for the route budget (Route)
	RunService.Heartbeat:Connect(function()
		self.Frame += 1
	end)
end)

return NpcService
