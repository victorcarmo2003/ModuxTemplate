--!strict
-- Shared pieces of the cooking focus stations (kitchen-focus.md §2): the pointer ray onto a plane, local props (kit food, the
-- plate, the hot dog in hand copied), the 3D line of a stroke and the bun space of a prop. Plain module, local instances only
-- (everything lives under the focus folder the station gets and goes with it).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

export type Bun = {
	-- the bun's frame: X along the bun (left to right on screen), Y up, Z across it; its centre on the top surface
	Frame: CFrame,
	Length: number,
	Width: number,
}

const Kit = {}

const LINE_WIDTH = 0.05
const PLATE_KIT = "plate"

-- Where the pointer (GUI space) meets the plane through `origin` with normal `normal`, nil when the ray runs parallel or away.
function Kit.OnPlane(screen: Vector2, origin: Vector3, normal: Vector3): Vector3?
	const camera = Workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	const ray = camera:ScreenPointToRay(screen.X, screen.Y)
	const denominator = ray.Direction:Dot(normal)
	if math.abs(denominator) < 1e-4 then
		return nil
	end
	const t = (origin - ray.Origin):Dot(normal) / denominator
	if t < 0 then
		return nil
	end
	return ray.Origin + ray.Direction * t
end

-- The first part of `among` (descendants) under the pointer, nil when none
function Kit.Hit(screen: Vector2, among: { Instance }): BasePart?
	const camera = Workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	const ray = camera:ScreenPointToRay(screen.X, screen.Y)
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = among
	const result = Workspace:Raycast(ray.Origin, ray.Direction * 60, params)
	return if result then result.Instance :: BasePart else nil
end

-- A world point in the bun space (x 0..1 along, y 0..1 across; outside the bun = outside 0..1)
function Kit.BunPoint(bun: Bun, world: Vector3): (number, number)
	const relative = bun.Frame:PointToObjectSpace(world)
	return relative.X / bun.Length + 0.5, relative.Z / bun.Width + 0.5
end

-- The world point of a bun-space point (on the top surface)
function Kit.BunWorld(bun: Bun, x: number, y: number, lift: number?): Vector3
	return (bun.Frame * CFrame.new((x - 0.5) * bun.Length, lift or 0, (y - 0.5) * bun.Width)).Position
end

local function quiet(model: Instance)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
		elseif part:IsA("LuaSourceContainer") or part:IsA("ProximityPrompt") then
			part:Destroy()
		end
	end
end

-- A local anchored copy of ReplicatedStorage.Assets.Items.Food.<name> (nil when the kit is missing)
function Kit.Food(name: string): Model?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const items = if assets then assets:FindFirstChild("Items") else nil
	const food = if items then items:FindFirstChild("Food") else nil
	const template = if food then food:FindFirstChild(name) else nil
	if template == nil or not template:IsA("Model") then
		return nil
	end
	const copy = template:Clone()
	quiet(copy)
	return copy
end

-- The model of a Tool as an anchored local Model (its Handle the PrimaryPart): the kit plate, or the hot dog in hand
function Kit.FromTool(tool: Instance): Model?
	const model = Instance.new("Model")
	model.Name = tool.Name
	for _, child in tool:GetChildren() do
		if child:IsA("BasePart") or child:IsA("Model") or child:IsA("Folder") then
			child:Clone().Parent = model
		end
	end
	const handle = model:FindFirstChild("Handle")
	if handle == nil or not handle:IsA("BasePart") then
		model:Destroy()
		return nil
	end
	model.PrimaryPart = handle
	quiet(model)
	return model
end

-- The kit plate Tool as a local model (a flat cream dish when the kit has none)
function Kit.Plate(): Model
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const items = if assets then assets:FindFirstChild("Items") else nil
	const tools = if items then items:FindFirstChild("Tools") else nil
	const kit = if tools then tools:FindFirstChild(PLATE_KIT) else nil
	const model = if kit then Kit.FromTool(kit) else nil
	if model ~= nil then
		return model
	end
	const dish = Instance.new("Model")
	dish.Name = "Plate"
	const part = Instance.new("Part")
	part.Name = "Handle"
	part.Size = Vector3.new(1.3, 0.08, 1.3)
	part.Color = Color3.fromHex("#F4F1EA")
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = dish
	dish.PrimaryPart = part
	quiet(dish)
	return dish
end

-- Places a model so its bounding box's bottom centre sits on `at`, turned like `rotation`
function Kit.SitOn(model: Model, at: CFrame)
	model:PivotTo(at)
	const box, size = model:GetBoundingBox()
	const shift = Vector3.new(at.Position.X - box.Position.X, at.Position.Y - (box.Position.Y - size.Y / 2), at.Position.Z - box.Position.Z)
	model:PivotTo(model:GetPivot() + shift)
end

-- One segment of a drawn line (a thin cylinder from a to b) under `parent`
function Kit.Segment(parent: Instance, a: Vector3, b: Vector3, color: Color3, width: number?): Part
	const thickness = width or LINE_WIDTH
	const part = Instance.new("Part")
	part.Name = "Stroke"
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	const length = math.max((b - a).Magnitude, 0.01)
	part.Size = Vector3.new(length, thickness, thickness)
	part.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
	part.Parent = parent
	return part
end

-- A ball (a joint of a line, a marker)
function Kit.Ball(parent: Instance, at: Vector3, color: Color3, size: number, transparency: number?): Part
	const part = Instance.new("Part")
	part.Name = "Mark"
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = transparency or 0
	part.Size = Vector3.new(size, size, size)
	part.Position = at
	part.Parent = parent
	return part
end

-- The top centre and the horizontal axes of the visible parts of an instance (a model, a folder): its bounding box on the floor plan
function Kit.Bounds(target: Instance): (Vector3, Vector3)
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = -low
	for _, part in target:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 then
			const half = part.Size / 2
			for _, corner in { Vector3.new(-1, -1, -1), Vector3.new(1, 1, 1), Vector3.new(-1, 1, 1), Vector3.new(1, -1, -1) } do
				const point = (part.CFrame * CFrame.new(half * corner)).Position
				low = low:Min(point)
				high = high:Max(point)
			end
		end
	end
	if low.X == math.huge then
		return Vector3.zero, Vector3.zero
	end
	return Vector3.new((low.X + high.X) / 2, high.Y, (low.Z + high.Z) / 2), high - low
end

return table.freeze(Kit)
