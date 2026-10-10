--!strict
--[[
	PedestrianController (TASK-123; architecture.md §19.17, §19.20, T46; network.md §13.7; DEC-169, DEC-183, DEC-188)

	Draws the passers-by the server decided. A passer-by has no model on the server (T46): the PedestrianService
	keeps a 1D record per slot in the `Pedestrians` set and every client draws its own local rig. Nothing here decides
	a spawn, a stop or a crossing (servidor decide, client apresenta).

	  * Record (slot 1..8): { Path, Species, Outfit, Speed, AnchorAt, AnchorDist, StopDist, HeldUntil }.
	  * Rig: CrewRig.Build(Species, Outfit) with `Tag = true` LOCAL (AnimalRig), so the RigController dresses it like
	    any NPC, including the local Night of the low band (DEC-169). `RigController:Prepare` dresses it before it is
	    parented (no Day frame). The Humanoid Build adds is removed (local actor, out of the 12 Humanoids, §19.17);
	    HumanoidRootPart anchored, every part without collision / query / touch. Pooled by Species + Outfit.
	  * Walk animation: `AnimController:Bind(model, "npc")` (locomotion by the measured speed of the HumanoidRootPart;
	    the AnimController pauses it past 120 studs or off screen by itself).
	  * Position: shared `Motion` (src/Traffic/shared/Motion.luau, TASK-104), the same rule as the cars. Path = the
	    NpcNode chain of `Content.WalkPaths.List[Path]` (MapIndex.Node positions, floor level); distance in studs along
	    the polyline from the first node. The anchor is a standstill; one Motion.Cursor per record; Motion.Sample
	    every frame. Rig pivot = HumanoidRootPart = ground + 3 studs (§18.5), facing along the path.
	  * LOD: farther than `WalkPaths.Rules.LodDistance` (120) from the camera the rig leaves the Workspace (still
	    integrated); it comes back re-dressed.

	PROVISIONAL (frontend-coder, until TASK-122 confirms; the server must use the same numbers):
	  (a) profile = Motion.Profile(length, {}, Speed, Speed, WALK_ACCEL, WALK_BRAKE): no slow stretch, accel and
	      brake 16 studs/s^2 (a walker reaches 8 studs/s in 0.5 s and stops on the curb line in ~2 studs);
	  (b) `Loop = true`: the polyline closes back to the first node and the distance wraps modulo its length;
	      `Loop = false`: past the end the rig hides until the server removes the record;
	  (c) a record that lands "in the past" blends to the computed place in BLEND_TIME (gap < SNAP_GAP).

	No input, no UI, never writes a set.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Motion = require(ReplicatedStorage.shared.Traffic.Motion)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

-- Fields of a Pedestrians record (network.md §13.7)
export type Record = {
	Path: number,
	Species: string,
	Outfit: string,
	Speed: number,
	AnchorAt: number,
	AnchorDist: number,
	StopDist: number,
	HeldUntil: number,
}

type Walk = {
	Line: Motion.Path,
	Loop: boolean,
}

type Walker = {
	Id: number,
	Record: Record,
	Walk: Walk?,
	Profile: Motion.Profile?,
	Cursor: Motion.Cursor?,
	Model: Model?,
	Root: BasePart?,
	Shown: boolean,
	Dist: number,
	Blend: number, -- studs added to Dist, decays to 0 in BLEND_TIME
	BlendAt: number,
}

const RULES = Content.WalkPaths.Rules
const LOD_DISTANCE = RULES.LodDistance
const LOD_MARGIN = 10 -- studs of hysteresis past LOD_DISTANCE before the rig leaves
const NPC_SET = "npc" -- Content.Animations.Locomotion
const SPAWN_LIFT = Vector3.new(0, 3, 0) -- HumanoidRootPart above the floor (§18.5)
const HEADING_HALF = 1 -- studs each side for the facing chord
const MAP_WAIT = 60 -- seconds MapIndex.WaitReady may wait for streaming
const PATH_RETRY = 2 -- seconds between lookups of a path whose nodes are not streamed in yet
const POOL_CAP = 8 -- idle rigs kept across Species + Outfit

-- Motion profile of a walker (PROVISIONAL, see header (a))
const WALK_ACCEL = 16
const WALK_BRAKE = 16

-- Latency blend (§8.1 rule, as the cars)
const BLEND_TIME = 0.2
const SNAP_GAP = 10

-- Path geometry ----------------------------------------------------------------------------------------------------

-- Polyline of a WalkPaths row (nil while a node is missing: not streamed in, or binding without it)
local function buildWalk(row: Content.WalkPath): (Walk?, string?)
	const points: { Vector3 } = {}
	for _, id in row.Nodes do
		const ok, info = pcall(MapIndex.Node, id)
		if not ok then
			return nil, id
		end
		table.insert(points, (info :: MapIndex.NodeInfo).Position)
	end
	if row.Loop and #points > 0 then
		table.insert(points, points[1])
	end
	const line = Motion.Path(points)
	if line == nil then
		return nil, row.Key
	end
	return { Line = line, Loop = row.Loop }, nil
end

-- Rig ------------------------------------------------------------------------------------------------------------

local function rigKey(record: Record): string
	return `{record.Species}/{record.Outfit}`
end

-- Local passer-by rig: tagged (RigController dresses it), no Humanoid, anchored root, no collision
local function buildRig(record: Record): Model?
	const options: CrewRig.BuildOptions = {
		Name = "Pedestrian",
		CustomerType = "pedestrian",
		Anchored = true,
		Tag = true,
		LookPack = "Day",
		Cap = false,
	}
	const ok, result = pcall(function(): Model
		return CrewRig.Build(record.Species, record.Outfit, options)
	end)
	if not ok then
		warn(`[PedestrianController] could not build {record.Species}/{record.Outfit}: {result}`)
		return nil
	end
	const model = result :: Model
	const humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid:Destroy()
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
	return model
end

local function rootOf(model: Model): BasePart?
	const root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

-- Controller -------------------------------------------------------------------------------------------------------

const PedestrianController = Modux.Controller(
	"PedestrianController",
	{ Require = { "RigController", "AnimController" }, Priority = 600 }
)

function PedestrianController:Setup()
	self.Walkers = {} :: { [number]: Walker }
	self.Walks = {} :: { [number]: Walk }
	self.WalkRetryAt = {} :: { [number]: number }
	self.Pool = {} :: { [string]: { Model } }
	self.Pooled = 0 :: number
	self.Folder = nil :: Folder?
	self.MapReady = false :: boolean
	self.Warned = {} :: { [string]: boolean }
	-- Vide source other Controllers may read: passers-by on the street now
	self.Count = Vide.source(0) :: Vide.Source<number>
end

function PedestrianController:Container(): Folder
	local folder = self.Folder
	if folder == nil or folder.Parent == nil then
		const created = Instance.new("Folder")
		created.Name = "Pedestrians"
		created.Parent = Workspace
		folder = created
		self.Folder = created
	end
	return folder :: Folder
end

function PedestrianController:WarnOnce(key: string, message: string)
	if self.Warned[key] then
		return
	end
	self.Warned[key] = true
	warn(`[PedestrianController] {message}`)
end

-- Geometry of a WalkPaths index (cached; nil until the map binding streams in)
function PedestrianController:WalkOf(index: number): Walk?
	const cached = self.Walks[index]
	if cached then
		return cached
	end
	if not self.MapReady then
		return nil
	end
	const row = Content.WalkPaths.List[index]
	if row == nil then
		self:WarnOnce(`row{index}`, `Pedestrians.Path {index} is not a Content.WalkPaths row`)
		return nil
	end
	const now = os.clock()
	const retry = self.WalkRetryAt[index]
	if retry and now < retry then
		return nil
	end
	if retry ~= nil then
		-- a node was missing last time: re-read the binding (streaming may have brought it)
		MapIndex.Refresh()
	end
	const walk, missing = buildWalk(row)
	if walk == nil then
		self:WarnOnce(`walk{index}`, `WalkPath {row.Key}: node {missing} missing, its passers-by are not drawn yet`)
		self.WalkRetryAt[index] = now + PATH_RETRY
		return nil
	end
	self.Walks[index] = walk
	return walk
end

function PedestrianController:TakeRig(record: Record): Model?
	const pool = self.Pool[rigKey(record)]
	if pool and #pool > 0 then
		self.Pooled -= 1
		return table.remove(pool) :: Model
	end
	return buildRig(record)
end

function PedestrianController:ReleaseRig(walker: Walker)
	const model = walker.Model
	walker.Model = nil
	walker.Root = nil
	walker.Shown = false
	if model == nil then
		return
	end
	model.Parent = nil
	if self.Pooled >= POOL_CAP then
		model:Destroy()
		return
	end
	const key = rigKey(walker.Record)
	local pool = self.Pool[key]
	if pool == nil then
		pool = {}
		self.Pool[key] = pool
	end
	table.insert(pool, model)
	self.Pooled += 1
end

-- Profile and cursor of the walker's current record (the anchor is a standstill)
function PedestrianController:Reanchor(walker: Walker)
	const walk = walker.Walk
	if walk == nil then
		walker.Profile = nil
		walker.Cursor = nil
		return
	end
	const speed = walker.Record.Speed
	const profile = Motion.Profile(walk.Line.Length, {}, speed, speed, WALK_ACCEL, WALK_BRAKE)
	walker.Profile = profile
	walker.Cursor = Motion.Cursor(profile, walker.Record)
end

-- Distance along the path at server time `now` (nil while the path is unknown)
function PedestrianController:Distance(walker: Walker, now: number): number?
	const profile, cursor = walker.Profile, walker.Cursor
	if profile == nil or cursor == nil then
		return nil
	end
	const dist = Motion.Sample(profile, walker.Record, cursor, now)
	return dist
end

function PedestrianController:Apply(id: number, record: Record)
	const copy: Record = {
		Path = record.Path,
		Species = record.Species,
		Outfit = record.Outfit,
		Speed = record.Speed,
		AnchorAt = record.AnchorAt,
		AnchorDist = record.AnchorDist,
		StopDist = record.StopDist,
		HeldUntil = record.HeldUntil,
	}
	const walker = self.Walkers[id]
	if walker == nil then
		const fresh: Walker = {
			Id = id,
			Record = copy,
			Walk = self:WalkOf(copy.Path),
			Profile = nil,
			Cursor = nil,
			Model = nil,
			Root = nil,
			Shown = false,
			Dist = copy.AnchorDist,
			Blend = 0,
			BlendAt = 0,
		}
		self.Walkers[id] = fresh
		self:Reanchor(fresh)
		self.Count(Vide.untrack(self.Count) + 1)
		return
	end
	const old = walker.Record
	const samePath = old.Path == copy.Path
	const sameLook = old.Species == copy.Species and old.Outfit == copy.Outfit
	const shown = walker.Dist -- already includes the running blend
	if not sameLook then
		self:ReleaseRig(walker) -- pooled under the old look
	end
	if not samePath then
		walker.Walk = self:WalkOf(copy.Path)
	end
	walker.Record = copy
	self:Reanchor(walker)
	walker.Blend = 0
	if samePath and sameLook then
		const dist = self:Distance(walker, Workspace:GetServerTimeNow())
		if dist ~= nil then
			const gap = shown - dist
			if math.abs(gap) < SNAP_GAP then
				walker.Blend = gap
				walker.BlendAt = os.clock()
			end
		end
	end
end

function PedestrianController:Remove(id: number)
	const walker = self.Walkers[id]
	if walker == nil then
		return
	end
	self.Walkers[id] = nil
	self:ReleaseRig(walker)
	self.Count(math.max(Vide.untrack(self.Count) - 1, 0))
end

function PedestrianController:Hide(walker: Walker)
	if walker.Shown and walker.Model ~= nil then
		walker.Model.Parent = nil
	end
	walker.Shown = false
end

-- Rig in the Workspace (dressed before it is parented: no Day frame on the low band)
function PedestrianController:Show(walker: Walker): BasePart?
	local model = walker.Model
	if model == nil then
		model = self:TakeRig(walker.Record)
		if model == nil then
			return nil
		end
		walker.Model = model
		walker.Root = rootOf(model)
		self.Dependencies.AnimController:Bind(model, NPC_SET)
	end
	const m = model :: Model
	if not walker.Shown then
		self.Dependencies.RigController:Prepare(m)
		m.Parent = self:Container()
		walker.Shown = true
	end
	return walker.Root
end

function PedestrianController:Step()
	if next(self.Walkers) == nil then
		return
	end
	const now = Workspace:GetServerTimeNow()
	const clock = os.clock()
	const camera = Workspace.CurrentCamera
	const eye = if camera then camera.CFrame.Position else Vector3.zero
	for _, walker in self.Walkers do
		if walker.Walk == nil then
			walker.Walk = self:WalkOf(walker.Record.Path)
			if walker.Walk == nil then
				continue
			end
			self:Reanchor(walker)
		end
		const walk = walker.Walk :: Walk
		const dist = self:Distance(walker, now)
		if dist == nil then
			continue
		end
		if walker.Blend ~= 0 then
			const left = 1 - (clock - walker.BlendAt) / BLEND_TIME
			if left <= 0 then
				walker.Blend = 0
			else
				walker.Dist = dist + walker.Blend * left
			end
		end
		if walker.Blend == 0 then
			walker.Dist = dist
		end
		const length = walk.Line.Length
		local s = walker.Dist
		if walk.Loop then
			s = s % length
		elseif s >= length or s < 0 then
			-- past the end: the server removes the record when the walk ends; hide meanwhile
			self:Hide(walker)
			continue
		end
		const ground = Motion.PointAt(walk.Line, s)
		const distance = (ground - eye).Magnitude
		const limit = if walker.Shown then LOD_DISTANCE + LOD_MARGIN else LOD_DISTANCE
		if distance > limit then
			self:Hide(walker)
			continue
		end
		const root = self:Show(walker)
		if root == nil then
			continue
		end
		const position = ground + SPAWN_LIFT
		root.CFrame = CFrame.lookAt(position, position + Motion.Heading(walk.Line, s, HEADING_HALF))
	end
end

-- Lifecycle ------------------------------------------------------------------------------------------------------

PedestrianController:OnInit(function(self)
	self:Setup()

	const pedestrians = self.Libs.Net.Pedestrians
	pedestrians:onAdded(function(id, record)
		self:Apply(id, record :: Record)
	end)
	pedestrians:onChanged(function(id, record)
		self:Apply(id, record :: Record)
	end)
	pedestrians:onRemoved(function(id)
		self:Remove(id)
	end)
end)

PedestrianController:OnStart(function(self)
	RunService.RenderStepped:Connect(function()
		self:Step()
	end)
	-- The map streams in after boot: wait off the start chain.
	task.spawn(function()
		if not MapIndex.WaitReady(MAP_WAIT) then
			warn("[PedestrianController] map binding not ready: passers-by wait for it")
		end
		self.MapReady = true
	end)
end)

return PedestrianController
