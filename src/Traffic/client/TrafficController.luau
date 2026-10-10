--!strict
--[[
	TrafficController (TASK-105; architecture.md §8.1, §8.2, §19.17, T21; network.md §6.2, §13.7; FEAT-033, FEAT-036;
	DEC-087, DEC-095, DEC-103, DEC-130, DEC-133, DEC-198)

	Draws the street cars the server decided, and reports when one of them hits the OWN character. Nothing here
	decides a stop, a start, a spawn or a hit: the TrafficService does (servidor decide, client interpola).

	  * Traffic set (slot 1..8): one local car per record. Model from the TASK-099 kit
	    (`ReplicatedStorage.Assets.Vehicles.Cars/<Shape>`, paint `Paints/<Color>` moved in as `Paint`), chosen by
	    `Content.Traffic.LookOf(Look)`. Anchored, no collision / query / touch (§8.1). Pooled per Look.
	  * Position: 1D distance along the route path (`TrafficPath` / `PathId` = `Routes[].Path`) from the record
	    { AnchorAt, AnchorDist, StopDist, HeldUntil } (§8.1 rule; see "Motion" below). Same function of server time on
	    every client, so two clients draw a car at the same place. A record that lands "in the past" (ping) blends to
	    the computed place in BLEND_TIME instead of snapping (never a jump > 6 studs on screen, §8.1 "Latência").
	  * Hit (§8.2): every frame, the box of each moving car (>= Traffic.HitMinSpeed) is tested against the own
	    HumanoidRootPart only. Contact -> local prediction (Physics state + impulse along the car + up, stands up after
	    KnockTime) and `CarHit { Car }` to the server, which validates and runs the real Knock / DropHeld / immunity.
	    One hit per car per record life and none during the local immunity window. No hit while the own state is not
	    Active or the character is `Frozen` (hide, cutscene).
	  * LOD: wheels spin and the car moves every frame up to LOD_NEAR studs from the camera; up to LOD_FAR it moves at
	    FAR_RATE without spinning wheels; past LOD_FAR the model is parked (still integrated, still hit-tested: a car
	    that far cannot touch the own character anyway). Parts move with one BulkMoveTo per car.
	  * Night (RoundController.IsNight): headlights Neon Cream + short Beam, no real light (style guide §2.3).

	Motion (PROVISIONAL, frontend-coder, until TASK-104 ships `src/Traffic/shared/Motion.luau`): the shared pure
	function does not exist yet, so the §8.1 rule lives here in `step`, integrated on a fixed grid of MOTION_DT from
	AnchorAt (deterministic: every client gets the same distance for the same server time):
	  - speed at the anchor = profile speed there; 0 when the anchor already sits on the stop;
	  - profile: Traffic.SpeedStraight, Traffic.SpeedCrossing inside the `X-T` TrafficBox footprint; slows down ahead of
	    a slower stretch with Crossing.BrakeDecel, speeds up with Crossing.PullAway;
	  - StopDist > 0 still ahead and (HeldUntil = 0 or now < HeldUntil): brakes to stop exactly on StopDist and waits;
	    after HeldUntil it pulls away (the PARE needs no second record);
	  - path = ordered nodes of the TrafficPath (attribute `Order`, else the number in the name), distance in studs along
	    the polyline from the first node; a BasePart node counts at its bottom face (road surface).
	When the Motion module lands, `CarMotion` swaps to it (one place); the hit validation tolerates 8 studs (§8.2).

	No input (the player never commands a car), no UI, never writes a set.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

-- Fields of a Traffic record (network.md §6.2; Look 1..32 since TASK-097)
export type Record = {
	Route: number,
	Look: number,
	AnchorAt: number,
	AnchorDist: number,
	StopDist: number,
	HeldUntil: number,
}

type Path = {
	Points: { Vector3 },
	Cum: { number }, -- distance at each point
	Length: number,
	Slow: { { number } }, -- [from, to] stretches inside the X-T footprint (SpeedCrossing)
}

type Wheel = {
	Index: number, -- position in Car.Parts
	Centre: Vector3, -- axle centre, pivot space
	Radius: number,
}

type Kit = {
	Model: Model,
	Look: number,
	Parts: { BasePart },
	Offsets: { CFrame }, -- part CFrame in pivot space
	Wheels: { Wheel },
	Size: Vector3,
	Lamps: { BasePart },
	LampLook: { { Color: Color3, Material: Enum.Material } },
	Beams: { Beam },
}

type Car = {
	Id: number,
	Record: Record,
	Path: Path?,
	Kit: Kit?,
	-- grid integration (Motion); state at step K and K + 1
	K: number,
	S0: number,
	U0: number,
	S1: number,
	U1: number,
	-- shown state
	Dist: number,
	Speed: number,
	Blend: number, -- studs added to Dist, decays to 0 in BLEND_TIME
	BlendAt: number,
	Spin: number, -- wheel angle (rad)
	Hit: boolean, -- already reported a hit on the own character
	Parked: boolean,
	NextFarAt: number,
	CFrame: CFrame?,
}

const PATH_TAG = "TrafficPath"
const PATH_ATTRIBUTE = "PathId"
const BOX_TAG = "TrafficBox"
const BOX_ATTRIBUTE = "BoxId"
const CROSSING_BOX = "X-T" -- Content.Traffic.Conflicts (architecture.md §8.1)
const ORDER_ATTRIBUTE = "Order"
const FROZEN_ATTRIBUTE = "Frozen" -- CharacterService:Freeze (hide, cutscene)
const MAP_WAIT = 60 -- seconds MapIndex.WaitReady may wait for streaming
const PATH_RETRY = 2 -- seconds between lookups of a path that is not in the map yet

const TRAFFIC = Content.Traffic
const CROSSING = TRAFFIC.Crossing
const SPEED_STRAIGHT = TRAFFIC.SpeedStraight
const SPEED_CROSSING = TRAFFIC.SpeedCrossing
const BRAKE = CROSSING.BrakeDecel
const PULL_AWAY = CROSSING.PullAway
const HIT_MIN_SPEED = TRAFFIC.HitMinSpeed
const KNOCK_TIME = TRAFFIC.KnockTime
const GET_UP_TIME = TRAFFIC.GetUpTime
const IMMUNE_TIME = TRAFFIC.ImmuneTime
const IMPULSE_FORWARD = TRAFFIC.ImpulseForward
const IMPULSE_UP = TRAFFIC.ImpulseUp

-- Motion grid (PROVISIONAL until TASK-104 Motion): 30 Hz steps from AnchorAt, linear in between.
const MOTION_DT = 1 / 30
const STOP_EPSILON = 0.05 -- studs: on the stop line
const PROFILE_SAMPLE = 0.5 -- studs between footprint samples of the X-T box
const MAX_CATCH_UP = 20 * 60 * 30 -- grid steps a single frame may integrate (20 min of motion)

-- Latency blend (§8.1): reach the computed place in BLEND_TIME; a gap larger than SNAP_GAP is a different car.
const BLEND_TIME = 0.2
const SNAP_GAP = 40

-- LOD (PROVISIONAL, frontend-coder): studs from the camera
const LOD_NEAR = 160
const LOD_FAR = 260
const FAR_RATE = 15 -- Hz between LOD_NEAR and LOD_FAR

-- Hit box: car Size (kit attribute) grown by the HumanoidRootPart half extents (R6 HRP 2 x 2 x 1)
const HIT_MARGIN_X = 1
const HIT_MARGIN_Z = 0.5
const HIT_BELOW = 2 -- studs under the car base still counted (HRP centre ~3 above the road)
const HIT_ABOVE = 1

-- Night headlights (style guide §2.3: Neon Cream + short Beam, no real light). Beam look PROVISIONAL.
const CREAM = Color3.fromHex("#FFF1D6")
const BEAM_WIDTH_START = 1.2
const BEAM_WIDTH_END = 4
const BEAM_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.55),
	NumberSequenceKeypoint.new(1, 1),
})
const BEAM_PAIRS = { { "Beam_L", "Beam_L_End" }, { "Beam_R", "Beam_R_End" } }

-- Placeholder when the kit is missing in the place (PROVISIONAL): a plain block of a sedan's size
const FALLBACK_SIZE = Vector3.new(7, 5, 12)
const FALLBACK_COLOR = Color3.fromHex("#F4B183")
const DEFAULT_WHEEL_RADIUS = 1.4
const WHEELS = { "Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR" }

-- Motion (PROVISIONAL, see header) --------------------------------------------------------------------------------

-- Profile speed at distance `s` of `path`
local function speedAt(path: Path, s: number): number
	for _, stretch in path.Slow do
		if s >= stretch[1] and s <= stretch[2] then
			return SPEED_CROSSING
		end
	end
	return SPEED_STRAIGHT
end

-- Start of the next slower stretch ahead of `s` (math.huge if none)
local function nextSlow(path: Path, s: number): number
	for _, stretch in path.Slow do
		if stretch[1] > s then
			return stretch[1]
		end
	end
	return math.huge
end

-- The stop of `record` still binds at distance `s` and time `t`
local function holding(record: Record, s: number, t: number): boolean
	if record.StopDist <= 0 or s > record.StopDist + STOP_EPSILON then
		return false
	end
	return record.HeldUntil <= 0 or t < record.HeldUntil
end

-- Speed at the anchor: on the stop -> 0; otherwise the profile speed there.
local function anchorSpeed(path: Path, record: Record): number
	if record.StopDist > 0 and math.abs(record.AnchorDist - record.StopDist) <= STOP_EPSILON then
		return 0
	end
	return speedAt(path, record.AnchorDist)
end

-- One grid step from (s, u), the state at grid time t, to the next grid point. Pure: same inputs, same outputs on every client.
local function step(path: Path, record: Record, s: number, u: number, t: number): (number, number)
	local target = speedAt(path, s)
	-- slow down ahead of the X-T box
	const slowAt = nextSlow(path, s)
	if slowAt < math.huge and u > SPEED_CROSSING then
		const room = slowAt - s
		if u * u - SPEED_CROSSING * SPEED_CROSSING >= 2 * BRAKE * math.max(room - u * MOTION_DT, 0) then
			target = SPEED_CROSSING
		end
	end
	if holding(record, s, t) then
		const room = record.StopDist - s
		if room <= STOP_EPSILON then
			return record.StopDist, 0
		end
		-- brake to stop exactly on StopDist (v^2 = 2 a d)
		if u * u >= 2 * BRAKE * math.max(room - u * MOTION_DT, 0) then
			const decel = u * u / (2 * room)
			local nu = math.max(u - decel * MOTION_DT, 0)
			local ns = s + (u + nu) * 0.5 * MOTION_DT
			if ns >= record.StopDist - STOP_EPSILON or nu <= 0 then
				ns = record.StopDist
				nu = 0
			end
			return ns, nu
		end
	end
	local nu: number
	if u < target then
		nu = math.min(u + PULL_AWAY * MOTION_DT, target)
	else
		nu = math.max(u - BRAKE * MOTION_DT, target)
	end
	local ns = s + (u + nu) * 0.5 * MOTION_DT
	if holding(record, s, t) and ns > record.StopDist then
		ns = record.StopDist
		nu = 0
	end
	return ns, nu
end

-- Path geometry -------------------------------------------------------------------------------------------------

local function nodeOrder(instance: Instance): number
	const order = instance:GetAttribute(ORDER_ATTRIBUTE)
	if type(order) == "number" then
		return order
	end
	const digits = string.match(instance.Name, "(%d+)%D*$")
	return if digits then tonumber(digits) or math.huge else math.huge
end

local function nodePosition(instance: Instance): Vector3?
	if instance:IsA("BasePart") then
		return instance.Position - Vector3.new(0, instance.Size.Y / 2, 0)
	elseif instance:IsA("Attachment") then
		return instance.WorldPosition
	end
	return nil
end

local function findTagged(tag: string, attribute: string, id: string): Instance?
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:GetAttribute(attribute) == id then
			return instance
		end
	end
	return nil
end

-- Stretches of the polyline whose XZ falls inside the footprint of `box`
local function slowStretches(points: { Vector3 }, cum: { number }, box: BasePart?): { { number } }
	const out: { { number } } = {}
	if box == nil then
		return out
	end
	const cf = box.CFrame
	const half = box.Size / 2
	local from: number? = nil
	const length = cum[#cum]
	local s = 0
	local segment = 1
	while s <= length do
		while segment < #points - 1 and cum[segment + 1] < s do
			segment += 1
		end
		const a, b = points[segment], points[segment + 1]
		const span = cum[segment + 1] - cum[segment]
		const alpha = if span > 0 then (s - cum[segment]) / span else 0
		const pos = cf:PointToObjectSpace(a:Lerp(b, alpha))
		const inside = math.abs(pos.X) <= half.X and math.abs(pos.Z) <= half.Z
		if inside and from == nil then
			from = s
		elseif not inside and from ~= nil then
			table.insert(out, { from, s })
			from = nil
		end
		s += PROFILE_SAMPLE
	end
	if from ~= nil then
		table.insert(out, { from, length })
	end
	return out
end

local function buildPath(container: Instance, box: BasePart?): Path?
	const nodes: { Instance } = {}
	for _, child in container:GetDescendants() do
		if child:IsA("BasePart") or child:IsA("Attachment") then
			table.insert(nodes, child)
		end
	end
	table.sort(nodes, function(a: Instance, b: Instance): boolean
		const oa, ob = nodeOrder(a), nodeOrder(b)
		if oa == ob then
			return a.Name < b.Name
		end
		return oa < ob
	end)
	const points: { Vector3 } = {}
	for _, node in nodes do
		const position = nodePosition(node)
		if position then
			table.insert(points, position)
		end
	end
	if #points < 2 then
		return nil
	end
	const cum: { number } = { 0 }
	for i = 2, #points do
		cum[i] = cum[i - 1] + (points[i] - points[i - 1]).Magnitude
	end
	return {
		Points = points,
		Cum = cum,
		Length = cum[#cum],
		Slow = slowStretches(points, cum, box),
	}
end

-- Point at distance `s` (clamped extrapolation past the ends along the end segments)
local function pointAt(path: Path, s: number): Vector3
	const points, cum = path.Points, path.Cum
	local lo, hi = 1, #points
	if s <= 0 then
		hi = 2
	elseif s >= path.Length then
		lo = #points - 1
	else
		while hi - lo > 1 do
			const mid = (lo + hi) // 2
			if cum[mid] <= s then
				lo = mid
			else
				hi = mid
			end
		end
	end
	hi = lo + 1
	const span = cum[hi] - cum[lo]
	const alpha = if span > 0 then (s - cum[lo]) / span else 0
	return points[lo] + (points[hi] - points[lo]) * alpha
end

-- Pivot (base centre, LookVector = front) at distance `s`; heading from the chord over `half` studs each side
local function pivotAt(path: Path, s: number, half: number): CFrame
	const position = pointAt(path, s)
	const ahead = pointAt(path, s + half)
	const behind = pointAt(path, s - half)
	local direction = Vector3.new(ahead.X - behind.X, 0, ahead.Z - behind.Z)
	if direction.Magnitude < 1e-3 then
		direction = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(position, position + direction.Unit)
end

-- Kit -------------------------------------------------------------------------------------------------------------

local function vehiclesFolder(): Instance?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	return if assets then assets:FindFirstChild("Vehicles") else nil
end

local function fallbackModel(): Model
	const model = Instance.new("Model")
	const body = Instance.new("Part")
	body.Name = "Body"
	body.Size = FALLBACK_SIZE
	body.Color = FALLBACK_COLOR
	body.Material = Enum.Material.SmoothPlastic
	body.CFrame = CFrame.new(0, FALLBACK_SIZE.Y / 2, 0)
	body.Parent = model
	model.PrimaryPart = body
	body.PivotOffset = body.CFrame:Inverse()
	model:SetAttribute("Size", FALLBACK_SIZE)
	return model
end

-- Fresh model of a Look: kit car with one paint, or the placeholder block
local function cloneLook(look: number): Model
	const shape, paint = TRAFFIC.LookOf(look)
	const vehicles = vehiclesFolder()
	const cars = if vehicles then vehicles:FindFirstChild("Cars") else nil
	const template = if cars and shape then cars:FindFirstChild(shape) else nil
	if template == nil or not template:IsA("Model") then
		return fallbackModel()
	end
	const model = template:Clone()
	const paints = model:FindFirstChild("Paints")
	if paints then
		local chosen = if paint then paints:FindFirstChild(paint) else nil
		if chosen == nil then
			const default = model:GetAttribute("DefaultPaint")
			chosen = if type(default) == "string" then paints:FindFirstChild(default) else nil
		end
		if chosen then
			chosen.Name = "Paint"
			chosen.Parent = model
		end
		paints:Destroy()
	end
	return model
end

local function makeKit(look: number): Kit
	const model = cloneLook(look)
	model.Name = "TrafficCar"
	const pivot = model:GetPivot()
	const parts: { BasePart } = {}
	const offsets: { CFrame } = {}
	const index: { [BasePart]: number } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			table.insert(parts, descendant)
			table.insert(offsets, pivot:Inverse() * descendant.CFrame)
			index[descendant] = #parts
		end
	end
	const radiusAttribute = model:GetAttribute("WheelRadius")
	const radius = if type(radiusAttribute) == "number" and radiusAttribute > 0
		then radiusAttribute
		else DEFAULT_WHEEL_RADIUS
	const wheels: { Wheel } = {}
	for _, name in WHEELS do
		const part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			const axle = part:FindFirstChild("Axle")
			const centre = if axle and axle:IsA("Attachment") then axle.WorldPosition else part.Position
			const wheel: Wheel = { Index = index[part], Centre = pivot:PointToObjectSpace(centre), Radius = radius }
			table.insert(wheels, wheel)
		end
	end
	const sizeAttribute = model:GetAttribute("Size")
	local size: Vector3
	if typeof(sizeAttribute) == "Vector3" then
		size = sizeAttribute
	else
		local _, extents = model:GetBoundingBox()
		size = extents
	end
	const lamps: { BasePart } = {}
	const lampLook: { { Color: Color3, Material: Enum.Material } } = {}
	const headlights = model:FindFirstChild("Headlights")
	if headlights and headlights:IsA("BasePart") then
		table.insert(lamps, headlights)
		table.insert(lampLook, { Color = headlights.Color, Material = headlights.Material })
	end
	const beams: { Beam } = {}
	const body = model.PrimaryPart
	if body then
		for _, pair in BEAM_PAIRS do
			const a0 = body:FindFirstChild(pair[1])
			const a1 = body:FindFirstChild(pair[2])
			if a0 and a0:IsA("Attachment") and a1 and a1:IsA("Attachment") then
				const beam = Instance.new("Beam")
				beam.Name = "Headlight"
				beam.Attachment0 = a0
				beam.Attachment1 = a1
				beam.Color = ColorSequence.new(CREAM)
				beam.Transparency = BEAM_TRANSPARENCY
				beam.LightEmission = 1
				beam.LightInfluence = 0
				beam.Width0 = BEAM_WIDTH_START
				beam.Width1 = BEAM_WIDTH_END
				beam.FaceCamera = true
				beam.Segments = 1
				beam.Enabled = false
				beam.Parent = body
				table.insert(beams, beam)
			end
		end
	end
	return {
		Model = model,
		Look = look,
		Parts = parts,
		Offsets = offsets,
		Wheels = wheels,
		Size = size,
		Lamps = lamps,
		LampLook = lampLook,
		Beams = beams,
	}
end

local function setNight(kit: Kit, night: boolean)
	for i, lamp in kit.Lamps do
		if night then
			lamp.Material = Enum.Material.Neon
			lamp.Color = CREAM
		else
			lamp.Material = kit.LampLook[i].Material
			lamp.Color = kit.LampLook[i].Color
		end
	end
	for _, beam in kit.Beams do
		beam.Enabled = night
	end
end

-- Controller ------------------------------------------------------------------------------------------------------

const TrafficController = Modux.Controller(
	"TrafficController",
	{ Require = { "RoundController", "VitalController" }, Priority = 680 }
)

function TrafficController:Setup()
	self.Cars = {} :: { [number]: Car }
	self.Paths = {} :: { [string]: Path }
	self.PathRetryAt = {} :: { [string]: number }
	self.Pool = {} :: { [number]: { Kit } }
	self.Folder = nil :: Folder?
	self.MapReady = false :: boolean
	self.Night = false :: boolean
	-- local hit prediction
	self.ImmuneUntil = 0 :: number
	self.GetUpThread = nil :: thread?
	-- Vide source other Controllers may read (e.g. TASK-118): number of cars on the street now
	self.Count = Vide.source(0) :: Vide.Source<number>
end

function TrafficController:Container(): Folder
	local folder = self.Folder
	if folder == nil or folder.Parent == nil then
		const created = Instance.new("Folder")
		created.Name = "TrafficCars"
		created.Parent = Workspace
		folder = created
		self.Folder = created
	end
	return folder :: Folder
end

-- Route path of a record (cached; nil until the map binding streams in)
function TrafficController:PathOf(route: number): Path?
	const row = TRAFFIC.Routes.List[route]
	if row == nil then
		return nil
	end
	const cached = self.Paths[row.Path]
	if cached then
		return cached
	end
	if not self.MapReady then
		return nil
	end
	const now = os.clock()
	const retry = self.PathRetryAt[row.Path]
	if retry and now < retry then
		return nil
	end
	const container = findTagged(PATH_TAG, PATH_ATTRIBUTE, row.Path)
	const boxInstance = findTagged(BOX_TAG, BOX_ATTRIBUTE, CROSSING_BOX)
	const box = if boxInstance and boxInstance:IsA("BasePart") then boxInstance else nil
	const path = if container then buildPath(container, box) else nil
	if path == nil then
		if retry == nil then
			warn(`[TrafficController] TrafficPath {row.Path} missing or empty: its cars are not drawn yet`)
		end
		self.PathRetryAt[row.Path] = now + PATH_RETRY
		return nil
	end
	self.Paths[row.Path] = path
	return path
end

function TrafficController:TakeKit(look: number): Kit
	const pool = self.Pool[look]
	if pool and #pool > 0 then
		return table.remove(pool) :: Kit
	end
	const kit = makeKit(look)
	setNight(kit, self.Night)
	return kit
end

function TrafficController:ReleaseKit(kit: Kit)
	kit.Model.Parent = nil
	local pool = self.Pool[kit.Look]
	if pool == nil then
		pool = {}
		self.Pool[kit.Look] = pool
	end
	table.insert(pool, kit)
end

-- Grid state of `car` at step `k` from the anchor (integrates forward from the cached step)
function TrafficController:Advance(car: Car, path: Path, now: number)
	const record = car.Record
	const target = math.floor((now - record.AnchorAt) / MOTION_DT)
	if target < car.K then
		return
	end
	local steps = 0
	while car.K < target and steps < MAX_CATCH_UP do
		-- parked on a held stop: nothing changes until HeldUntil, jump the grid
		if car.U1 == 0 and holding(record, car.S1, record.AnchorAt + (car.K + 1) * MOTION_DT) then
			local last = target
			if record.HeldUntil > 0 then
				-- last grid index whose step still sees the hold (t_last < HeldUntil)
				last = math.min(target, math.ceil((record.HeldUntil - record.AnchorAt) / MOTION_DT) - 1)
			end
			if last > car.K then
				car.K = last
				car.S0, car.U0 = car.S1, car.U1
				continue
			end
		end
		car.K += 1
		car.S0, car.U0 = car.S1, car.U1
		car.S1, car.U1 = step(path, record, car.S0, car.U0, record.AnchorAt + car.K * MOTION_DT)
		steps += 1
	end
end

-- Distance and speed of `car` at server time `now` (Motion)
function TrafficController:CarMotion(car: Car, path: Path, now: number): (number, number)
	const record = car.Record
	if now <= record.AnchorAt then
		return record.AnchorDist, car.U0
	end
	self:Advance(car, path, now)
	const t0 = record.AnchorAt + car.K * MOTION_DT
	const alpha = math.clamp((now - t0) / MOTION_DT, 0, 1)
	return car.S0 + (car.S1 - car.S0) * alpha, car.U0 + (car.U1 - car.U0) * alpha
end

-- Resets the integration of `car` to its record
function TrafficController:Reanchor(car: Car)
	const path = car.Path
	const record = car.Record
	const u = if path then anchorSpeed(path, record) else 0
	car.K = 0
	car.S0, car.U0 = record.AnchorDist, u
	if path then
		car.S1, car.U1 = step(path, record, record.AnchorDist, u, record.AnchorAt)
	else
		car.S1, car.U1 = record.AnchorDist, u
	end
end

function TrafficController:Apply(id: number, record: Record)
	const now = Workspace:GetServerTimeNow()
	const copy: Record = {
		Route = record.Route,
		Look = record.Look,
		AnchorAt = record.AnchorAt,
		AnchorDist = record.AnchorDist,
		StopDist = record.StopDist,
		HeldUntil = record.HeldUntil,
	}
	local car = self.Cars[id]
	if car == nil then
		const fresh: Car = {
			Id = id,
			Record = copy,
			Path = self:PathOf(copy.Route),
			Kit = nil,
			K = 0,
			S0 = copy.AnchorDist,
			U0 = 0,
			S1 = copy.AnchorDist,
			U1 = 0,
			Dist = copy.AnchorDist,
			Speed = 0,
			Blend = 0,
			BlendAt = 0,
			Spin = 0,
			Hit = false,
			Parked = true,
			NextFarAt = 0,
			CFrame = nil,
		}
		self.Cars[id] = fresh
		self:Reanchor(fresh)
		self.Count(Vide.untrack(self.Count) + 1)
		return
	end
	const sameCar = car.Record.Route == copy.Route and car.Record.Look == copy.Look
	const shown = car.Dist -- already includes the running blend
	if not sameCar then
		-- slot reused by another car: fresh look, fresh hit
		if car.Kit then
			self:ReleaseKit(car.Kit)
			car.Kit = nil
		end
		car.Path = self:PathOf(copy.Route)
		car.Hit = false
		car.Parked = true
	end
	car.Record = copy
	self:Reanchor(car)
	car.Blend = 0
	const path = car.Path
	if sameCar and path then
		const dist = self:CarMotion(car, path, now)
		const gap = shown - dist
		if math.abs(gap) < SNAP_GAP then
			car.Blend = gap
			car.BlendAt = os.clock()
		end
	end
end

function TrafficController:Remove(id: number)
	const car = self.Cars[id]
	if car == nil then
		return
	end
	self.Cars[id] = nil
	if car.Kit then
		self:ReleaseKit(car.Kit)
	end
	self.Count(math.max(Vide.untrack(self.Count) - 1, 0))
end

function TrafficController:SetNight(night: boolean)
	if night == self.Night then
		return
	end
	self.Night = night
	for _, car in self.Cars do
		if car.Kit then
			setNight(car.Kit, night)
		end
	end
	for _, pool in self.Pool do
		for _, kit in pool do
			setNight(kit, night)
		end
	end
end

-- Moves every part of the car; wheels spin when `spin`
function TrafficController:Place(car: Car, kit: Kit, pivot: CFrame, spin: boolean)
	const cframes: { CFrame } = table.create(#kit.Parts, CFrame.identity)
	for i, offset in kit.Offsets do
		cframes[i] = pivot * offset
	end
	if spin then
		const roll = CFrame.Angles(car.Spin, 0, 0)
		for _, wheel in kit.Wheels do
			const centre = CFrame.new(wheel.Centre)
			cframes[wheel.Index] = pivot * centre * roll * centre:Inverse() * kit.Offsets[wheel.Index]
		end
	end
	Workspace:BulkMoveTo(kit.Parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Own character can be hit now (Active, not Frozen, not immune)
function TrafficController:OwnRoot(clock: number): BasePart?
	if clock < self.ImmuneUntil or not self.Dependencies.VitalController:IsActive() then
		return nil
	end
	const character = Players.LocalPlayer.Character
	if character == nil then
		return nil
	end
	const frozen = character:GetAttribute(FROZEN_ATTRIBUTE)
	if frozen == true or (type(frozen) == "string" and frozen ~= "") then
		return nil
	end
	const root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Local prediction of the hit (§8.2): Physics state + impulse along the car and up; stands up after KnockTime
-- unless the server Knock (TASK-100) took over. The server decides everything else.
function TrafficController:PredictHit(root: BasePart, carFront: Vector3, clock: number)
	self.ImmuneUntil = clock + KNOCK_TIME + GET_UP_TIME + IMMUNE_TIME
	const character = root.Parent
	const humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	end
	root.AssemblyLinearVelocity = carFront * IMPULSE_FORWARD + Vector3.new(0, IMPULSE_UP, 0)
	const previous = self.GetUpThread
	if previous and coroutine.status(previous) == "suspended" then
		task.cancel(previous)
	end
	self.GetUpThread = task.delay(KNOCK_TIME, function()
		self.GetUpThread = nil
		if humanoid and humanoid.Parent and humanoid:GetState() == Enum.HumanoidStateType.Physics then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

-- Box test of one car against the own HumanoidRootPart
function TrafficController:TestHit(car: Car, kit: Kit, pivot: CFrame, root: BasePart, clock: number): boolean
	if car.Hit or car.Speed < HIT_MIN_SPEED then
		return false
	end
	const size = kit.Size
	const at = pivot:PointToObjectSpace(root.Position)
	if math.abs(at.X) > size.X / 2 + HIT_MARGIN_X or math.abs(at.Z) > size.Z / 2 + HIT_MARGIN_Z then
		return false
	end
	if at.Y < -HIT_BELOW or at.Y > size.Y + HIT_ABOVE then
		return false
	end
	car.Hit = true
	self:PredictHit(root, pivot.LookVector, clock)
	self.Libs.Net.CarHit:fireServer({ Car = car.Id })
	return true
end

function TrafficController:Step(dt: number)
	if next(self.Cars) == nil then
		return
	end
	const now = Workspace:GetServerTimeNow()
	const clock = os.clock()
	const camera = Workspace.CurrentCamera
	const eye = if camera then camera.CFrame.Position else Vector3.zero
	local root = self:OwnRoot(clock)
	for _, car in self.Cars do
		if car.Path == nil then
			car.Path = self:PathOf(car.Record.Route)
			if car.Path == nil then
				continue
			end
			self:Reanchor(car)
		end
		const path = car.Path :: Path
		const dist, speed = self:CarMotion(car, path, now)
		if car.Blend ~= 0 then
			const left = 1 - (clock - car.BlendAt) / BLEND_TIME
			if left <= 0 then
				car.Blend = 0
			else
				car.Dist = dist + car.Blend * left
			end
		end
		if car.Blend == 0 then
			car.Dist = dist
		end
		car.Speed = speed
		local kit = car.Kit
		if kit == nil then
			kit = self:TakeKit(car.Record.Look)
			car.Kit = kit
		end
		const k = kit :: Kit
		-- off the route end: the server removes the record when the car leaves; hide meanwhile
		if car.Dist >= path.Length or car.Dist < 0 then
			if not car.Parked then
				k.Model.Parent = nil
				car.Parked = true
			end
			continue
		end
		const pivot = pivotAt(path, car.Dist, k.Size.Z * 0.35)
		car.CFrame = pivot
		const radius = if #k.Wheels > 0 then k.Wheels[1].Radius else DEFAULT_WHEEL_RADIUS
		car.Spin = (car.Spin - speed * dt / radius) % (2 * math.pi)
		const distance = (pivot.Position - eye).Magnitude
		if distance > LOD_FAR then
			if not car.Parked then
				k.Model.Parent = nil
				car.Parked = true
			end
		else
			const near = distance <= LOD_NEAR
			if car.Parked then
				k.Model.Parent = self:Container()
				car.Parked = false
				car.NextFarAt = 0
			end
			if near then
				self:Place(car, k, pivot, true)
			elseif clock >= car.NextFarAt then
				car.NextFarAt = clock + 1 / FAR_RATE
				self:Place(car, k, pivot, false)
			end
		end
		if root and self:TestHit(car, k, pivot, root, clock) then
			root = nil
		end
	end
end

-- Lifecycle ------------------------------------------------------------------------------------------------------

TrafficController:OnInit(function(self)
	self:Setup()

	const traffic = self.Libs.Net.Traffic
	traffic:onAdded(function(id, record)
		self:Apply(id, record :: Record)
	end)
	traffic:onChanged(function(id, record)
		self:Apply(id, record :: Record)
	end)
	traffic:onRemoved(function(id)
		self:Remove(id)
	end)
end)

TrafficController:OnStart(function(self)
	const round = self.Dependencies.RoundController
	Vide.root(function()
		Vide.effect(function()
			self:SetNight(round.IsNight())
		end)
		return nil
	end)
	RunService.RenderStepped:Connect(function(dt: number)
		self:Step(dt)
	end)
	-- The map streams in after boot: wait off the start chain.
	task.spawn(function()
		if not MapIndex.WaitReady(MAP_WAIT) then
			warn("[TrafficController] map binding not ready: traffic waits for it")
		end
		self.MapReady = true
	end)
end)

return TrafficController
