--!strict
-- World/Strokes: the sauce on the bun as 3D segments, and the guide dots of the zig-zag (docs/tech/prep-3d.md §3.4, §8; TASK-205).
-- A stroke is a chain of low cylinders lying on the bun (one Part per segment, a pool made once: Rules.World.Budget.SaucePool, at
-- most SauceSegmentsPerStroke per stroke and SauceSegmentsPerPlate per plate; samples closer than the step are dropped). The guide
-- dots (Part pool) follow the zig-zag of Content.Prep.Build.Sauce.Path and go out as the stroke covers them (a shape, not a colour).
-- The EditableMesh tube of TASK-218 would replace `Add` behind Rules.World.Editable; nothing here creates one. No Modux, no Vide,
-- no network; nothing is created per frame.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Plane = require(script.Parent.Plane)
local Theme = require(game:GetService("StarterPlayer").StarterPlayerScripts.client.Interface.Components.Theme)

export type Strokes = {
	-- Starts a stroke of this colour (a stroke already running is kept as it is).
	Begin: (self: Strokes, color: Color3) -> (),
	-- Extends it to a bun-space point; true when a segment was laid (the budget and the step decide).
	Add: (self: Strokes, uv: Vector2) -> boolean,
	-- The stroke ends and stays on the plate.
	Keep: (self: Strokes) -> (),
	-- The stroke is thrown away (a cancelled or invalid gesture).
	Drop: (self: Strokes) -> (),
	-- The guide dots of the zig-zag on (list of bun-space points) or off (nil).
	SetDots: (self: Strokes, dots: { Vector2 }?) -> (),
	-- The dots the stroke points cover go out.
	Cover: (self: Strokes, points: { Vector2 }, reach: number, aspect: number) -> (),
	Count: (self: Strokes) -> number,
	-- The plate slid by `delta` (studs): every laid segment and dot goes with it.
	Shift: (self: Strokes, delta: Vector3) -> (),
	-- Everything off (the plate is gone).
	Clear: (self: Strokes) -> (),
	Destroy: (self: Strokes) -> (),
}

const Strokes = {}

const COLORS: { [string]: Color3 } = {
	ketchup = Color3.fromHex("#E2402E"),
	mustard = Color3.fromHex("#F6C12B"),
	cream_cheese = Color3.fromHex("#FFF8EA"),
}

-- The colour of a sauce (food, not a UI state).
function Strokes.ColorOf(key: string): Color3
	return COLORS[key] or Color3.fromHex("#FFF8EA")
end

local function newPart(folder: Folder, name: string, ball: boolean): Part
	const part = Instance.new("Part")
	part.Name = name
	part.Shape = if ball then Enum.PartType.Ball else Enum.PartType.Cylinder
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.one * 0.1
	part.Parent = folder
	return part
end

function Strokes.new(folder: Folder, rules: Content.PrepWorldRules, plane: Plane.Plane): Strokes
	const budget = rules.Budget
	const look = rules.Toppings.Stroke
	const dotRules = rules.Toppings.Dot
	const scale = rules.Board.Scale
	-- over the sausage that sits in the groove (its top is 0.09 x scale over the bun top), half a segment up
	const lift = 0.09 * scale + look.Width * scale * 0.5
	const free: { Part } = {}
	const all: { Part } = {}
	for _ = 1, budget.SaucePool do
		const part = newPart(folder, "SauceSegment", false)
		table.insert(all, part)
		table.insert(free, part)
	end
	const dots: { Part } = {}
	const dotUv: { Vector2 } = {}
	const dotOn: { boolean } = {}
	for _ = 1, 48 do
		table.insert(dots, newPart(folder, "GuideDot", true))
	end

	-- the guide path in the world, to pick a step that lets the whole zig-zag fit in the per-stroke budget
	local pathLength = 0
	do
		const path = Content.Prep.Build.Sauce.Path
		for index = 2, #path do
			pathLength += math.sqrt(((path[index].X - path[index - 1].X) * plane.Length) ^ 2 + ((path[index].Y - path[index - 1].Y) * plane.Width) ^ 2)
		end
	end
	const step = math.max(budget.SauceMinStep, pathLength * 1.1 / budget.SauceSegmentsPerStroke)

	local color = Color3.new(1, 1, 1)
	local running = false
	local last: Vector3? = nil
	local current: { Part } = {}
	local plate = 0

	const self = {} :: any

	local function lay(from: Vector3, to: Vector3): boolean
		const part = table.remove(free)
		if part == nil then
			return false
		end
		const length = (to - from).Magnitude
		const middle = (from + to) / 2
		part.Size = Vector3.new(length * 1.15, look.Width * scale, look.Width * scale)
		part.Color = color
		part.CFrame = CFrame.lookAt(middle, to) * CFrame.Angles(0, math.pi / 2, 0)
		part.Transparency = 0
		table.insert(current, part)
		plate += 1
		return true
	end

	local function point(uv: Vector2): Vector3
		return Plane.ToWorld(plane, Vector2.new(math.clamp(uv.X, -0.15, 1.15), math.clamp(uv.Y, -0.3, 1.3)), lift)
	end

	function self.Begin(_: any, wanted: Color3)
		color = wanted
		running = true
		last = nil
		table.clear(current)
	end

	function self.Add(_: any, uv: Vector2): boolean
		if not running then
			return false
		end
		const world = point(uv)
		const previous = last
		if previous == nil then
			last = world
			return false
		end
		if (world - previous).Magnitude < step then
			return false
		end
		if #current >= budget.SauceSegmentsPerStroke or plate >= budget.SauceSegmentsPerPlate then
			return false
		end
		if not lay(previous, world) then
			return false
		end
		last = world
		return true
	end

	function self.Keep(_: any)
		running = false
		last = nil
		table.clear(current)
	end

	function self.Drop(_: any)
		for _, part in current do
			part.Transparency = 1
			table.insert(free, part)
			plate -= 1
		end
		table.clear(current)
		running = false
		last = nil
	end

	function self.SetDots(_: any, list: { Vector2 }?)
		table.clear(dotUv)
		table.clear(dotOn)
		for index, part in dots do
			const uv = if list ~= nil then list[index] else nil
			if uv == nil then
				part.Transparency = 1
				continue
			end
			dotUv[index] = uv
			dotOn[index] = true
			part.Size = Vector3.one * dotRules.Size * scale
			part.Color = Theme.Color.Cream
			part.Material = Enum.Material.Neon
			part.Position = Plane.ToWorld(plane, uv, lift * 2)
			part.Transparency = 0.1
		end
	end

	function self.Cover(_: any, points: { Vector2 }, reach: number, aspect: number)
		for index, uv in dotUv do
			if not dotOn[index] then
				continue
			end
			for _, p in points do
				const dx = (p.X - uv.X) * aspect
				const dy = p.Y - uv.Y
				if dx * dx + dy * dy <= reach * reach then
					dotOn[index] = false
					dots[index].Transparency = 1
					break
				end
			end
		end
	end

	function self.Shift(_: any, delta: Vector3)
		for _, part in all do
			if part.Transparency < 1 then
				part.Position += delta
			end
		end
		for _, part in dots do
			if part.Transparency < 1 then
				part.Position += delta
			end
		end
	end

	function self.Count(_: any): number
		return plate
	end

	function self.Clear(_: any)
		for _, part in all do
			part.Transparency = 1
		end
		table.clear(free)
		for _, part in all do
			table.insert(free, part)
		end
		table.clear(current)
		plate = 0
		running = false
		last = nil
		self:SetDots(nil)
	end

	function self.Destroy(_: any)
		for _, part in all do
			part:Destroy()
		end
		for _, part in dots do
			part:Destroy()
		end
		table.clear(all)
		table.clear(free)
		table.clear(dots)
	end

	return self :: Strokes
end

return Strokes
