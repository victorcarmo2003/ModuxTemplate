--!strict
--[[
	Cars: street cars of the cutscenes (Content.Cutscenes.Rules.Cars). The real car of the traffic kit
	(`ReplicatedStorage.Assets.Vehicles.Cars/<Shape>` + paint, Content.Traffic.LookOf, same as TrafficController),
	driven along a TrafficPath of the binding (`PathId` = the route): on its lane, never across a sidewalk or the Pad.
	It slows inside the conflict box (X-T) like the traffic (SpeedCrossing) and never brakes for anyone (DEC-133).

	Timing: the car is nearest to `Near` (Anchors.Point) at `Pass` s after its beat; the horn sounds HORN_LEAD s
	before. Shown only within REACH studs of that point; engine loop while shown. A pure function of its time, like
	every actor (late join lands on the same frame).
	No TrafficPath in the map -> no car (warned by the caller), never a car off the road.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)
local Motion = require(ReplicatedStorage.shared.Traffic.Motion)
local Anchors = require(ReplicatedStorage.shared.Cutscene.Anchors)

type Row = Content.CutsceneCar

export type Car = {
	Model: Model,
	Update: (t: number, last: number) -> (),
	Destroy: () -> (),
}

export type Hooks = {
	Play: (sound: string, at: Instance) -> (),
	Loop: (sound: string, at: Instance, on: boolean) -> (),
	Folder: Instance,
}

const TRAFFIC = Content.Traffic
const PATH_TAG = "TrafficPath"
const PATH_ATTRIBUTE = "PathId"
const BOX_TAG = "TrafficBox"
const BOX_ATTRIBUTE = "BoxId"
const ORDER_ATTRIBUTES = { "Index", "Order" }
const WHEELS = { "Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR" }
const DEFAULT_WHEEL_RADIUS = 1.4
const FALLBACK_SIZE = Vector3.new(7, 5, 12)
const FALLBACK_COLOR = Color3.fromHex("#F4B183")
const REACH = 110 -- studs each side of the pass point where the car is drawn
const HORN_LEAD = 0.5
const STEP = 0.5 -- studs of the time table
const BLEND = 8 -- studs to change between straight and crossing speed
const ENGINE_KEY = "car_engine"

type Wheel = { Index: number, Centre: Vector3, Radius: number }

const Cars = {}

local function nodeOrder(instance: Instance): number
	for _, attribute in ORDER_ATTRIBUTES do
		const value = instance:GetAttribute(attribute)
		if type(value) == "number" then
			return value
		end
	end
	const digits = string.match(instance.Name, "(%d+)%D*$")
	return if digits then tonumber(digits) or math.huge else math.huge
end

local function findTagged(tag: string, attribute: string, id: string): Instance?
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:GetAttribute(attribute) == id and instance:IsDescendantOf(Workspace) then
			return instance
		end
	end
	return nil
end

-- Polyline of a TrafficPath (nodes in binding order; a BasePart node counts at its bottom face, the road)
local function pathOf(route: string): Motion.Path?
	const container = findTagged(PATH_TAG, PATH_ATTRIBUTE, route)
	if container == nil then
		return nil
	end
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
		if node:IsA("BasePart") then
			table.insert(points, node.Position - Vector3.new(0, node.Size.Y / 2, 0))
		elseif node:IsA("Attachment") then
			table.insert(points, node.WorldPosition)
		end
	end
	return Motion.Path(points)
end

-- Cumulative time along the path (index i = distance (i - 1) x STEP), slower inside the conflict box
local function timeTable(path: Motion.Path): { number }
	local slow: { { number } } = {}
	for _, conflict in TRAFFIC.Conflicts.List do
		const box = findTagged(BOX_TAG, BOX_ATTRIBUTE, conflict.Box)
		if box ~= nil and box:IsA("BasePart") then
			const stretches = Motion.Stretches(path, box.CFrame, box.Size)
			for _, stretch in stretches do
				table.insert(slow, stretch)
			end
		end
	end
	const fast, crawl = TRAFFIC.SpeedStraight, TRAFFIC.SpeedCrossing
	local function speedAt(s: number): number
		local gap = math.huge
		for _, stretch in slow do
			if s >= stretch[1] and s <= stretch[2] then
				return crawl
			end
			gap = math.min(gap, math.abs(s - stretch[1]), math.abs(s - stretch[2]))
		end
		return crawl + (fast - crawl) * math.clamp(gap / BLEND, 0, 1)
	end
	const times: { number } = { 0 }
	local s = 0
	while s < path.Length do
		const ds = math.min(STEP, path.Length - s)
		const v = speedAt(s + ds / 2)
		table.insert(times, times[#times] + ds / v)
		s += ds
	end
	return times
end

local function timeAt(times: { number }, s: number): number
	const i = math.clamp(s / STEP, 0, #times - 1)
	const lo = math.floor(i)
	const hi = math.min(lo + 1, #times - 1)
	return times[lo + 1] + (times[hi + 1] - times[lo + 1]) * (i - lo)
end

local function distanceAt(times: { number }, t: number, length: number): number
	if t <= times[1] then
		return (t - times[1]) * TRAFFIC.SpeedStraight
	elseif t >= times[#times] then
		return length + (t - times[#times]) * TRAFFIC.SpeedStraight
	end
	local lo, hi = 1, #times
	while hi - lo > 1 do
		const mid = (lo + hi) // 2
		if times[mid] <= t then
			lo = mid
		else
			hi = mid
		end
	end
	const span = times[hi] - times[lo]
	const alpha = if span > 0 then (t - times[lo]) / span else 0
	return math.min(((lo - 1) + alpha) * STEP, length)
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

-- Kit car of a Look (same build as TrafficController.cloneLook)
local function cloneLook(look: number): Model
	const shape, paint = TRAFFIC.LookOf(look)
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const vehicles = if assets then assets:FindFirstChild("Vehicles") else nil
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

function Cars.Create(name: string, row: Row, hooks: Hooks): (Car?, string?)
	const path = pathOf(row.Route)
	if path == nil then
		return nil, `TrafficPath {row.Route} not in the map`
	end
	const near = Anchors.Point(row.Near)
	if near == nil then
		return nil, `"{row.Near}" not found`
	end
	const times = timeTable(path)
	const passAt = Motion.Project(path, near.Position)
	const passTime = timeAt(times, passAt)

	const model = cloneLook(row.Look)
	model.Name = name
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
	for _, wheelName in WHEELS do
		const part = model:FindFirstChild(wheelName)
		if part and part:IsA("BasePart") then
			const axle = part:FindFirstChild("Axle")
			const centre = if axle and axle:IsA("Attachment") then axle.WorldPosition else part.Position
			table.insert(wheels, { Index = index[part], Centre = pivot:PointToObjectSpace(centre), Radius = radius })
		end
	end
	const sizeAttribute = model:GetAttribute("Size")
	local length = 12
	if typeof(sizeAttribute) == "Vector3" then
		length = sizeAttribute.Z
	else
		const _, extents = model:GetBoundingBox()
		length = extents.Z
	end
	const half = length * 0.35

	local shown = false
	local lastS: number? = nil
	local spin = 0

	local function hide()
		if shown then
			shown = false
			model.Parent = nil
			hooks.Loop(ENGINE_KEY, model, false)
		end
	end

	return {
		Model = model,
		Update = function(t: number, last: number)
			const s = distanceAt(times, passTime + (t - row.Pass), path.Length)
			if s < math.max(passAt - REACH, 0) or s > math.min(passAt + REACH, path.Length) then
				hide()
				lastS = nil
				return
			end
			if not shown then
				shown = true
				model.Parent = hooks.Folder
				hooks.Loop(ENGINE_KEY, model, true)
			end
			const position = Motion.PointAt(path, s)
			const frame = CFrame.lookAt(position, position + Motion.Heading(path, s, half))
			if lastS ~= nil then
				spin = (spin - (s - lastS) / radius) % (2 * math.pi)
			end
			lastS = s
			const cframes: { CFrame } = table.create(#parts, CFrame.identity)
			for i, offset in offsets do
				cframes[i] = frame * offset
			end
			const roll = CFrame.Angles(spin, 0, 0)
			for _, wheel in wheels do
				const centre = CFrame.new(wheel.Centre)
				cframes[wheel.Index] = frame * centre * roll * centre:Inverse() * offsets[wheel.Index]
			end
			Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
			const honk = row.Pass - HORN_LEAD
			if last < honk and honk <= t then
				hooks.Play(row.Horn, model)
			end
		end,
		Destroy = function()
			hooks.Loop(ENGINE_KEY, model, false)
			model:Destroy()
		end,
	}, nil
end

return table.freeze(Cars)
