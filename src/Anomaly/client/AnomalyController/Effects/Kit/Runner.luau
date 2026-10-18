--!strict
-- The runner (owner 2026-10-18: "um boneco todo preto com olhos vermelhos"): a tall, thin, all-black figure with two red
-- glowing eyes, built from Parts (placeholder, original, Mild). Used by the red fog (Effects/ANM-021) and the outside
-- chase (OutsideController). Lives in Effects/Kit (a Folder), so AnomalyController never takes it for an effect.
--   Runner.Build(parent, name, scale?) -> Model   pivot at the feet, facing -Z; ~7.5 studs x scale tall
local Runner = {}

const BODY = Color3.fromHex("#08070B")
const EYE = Color3.fromRGB(255, 24, 24)
const DEFAULT_SCALE = 1.5

local function part(model: Model, name: string, size: Vector3, offset: CFrame, color: Color3, neon: boolean): Part
	const p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = offset
	p.Color = color
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = not neon
	p.Parent = model
	return p
end

function Runner.Build(parent: Instance, name: string, scale: number?): Model
	const model = Instance.new("Model")
	model.Name = name
	const root = part(model, "Torso", Vector3.new(1.6, 3.2, 0.9), CFrame.new(0, 4.6, 0), BODY, false)
	part(model, "Head", Vector3.new(1.3, 1.5, 1.2), CFrame.new(0, 6.95, -0.1), BODY, false)
	for _, x in { -0.32, 0.32 } do
		part(model, "Eye", Vector3.new(0.26, 0.14, 0.1), CFrame.new(x, 7.1, -0.72), EYE, true)
	end
	for _, x in { -0.45, 0.45 } do
		part(model, "Leg", Vector3.new(0.5, 3, 0.5), CFrame.new(x, 1.5, 0), BODY, false)
	end
	for _, x in { -1.1, 1.1 } do
		part(model, "Arm", Vector3.new(0.42, 3.6, 0.42), CFrame.new(x, 4.4, 0), BODY, false)
	end
	const glow = Instance.new("PointLight")
	glow.Color = EYE
	glow.Brightness = 1.2
	glow.Range = 5
	glow.Parent = model:FindFirstChild("Head")
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p ~= root then
			const weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = p
			weld.Parent = p
		end
	end
	model.PrimaryPart = root
	-- pivot at the feet (the torso is 4.6 up): PivotTo on the ground stands it ON the ground
	root.PivotOffset = CFrame.new(0, -root.Position.Y, 0)
	model:ScaleTo(scale or DEFAULT_SCALE)
	model.Parent = parent
	return model
end

-- Fade every part locally (0 = solid, 1 = gone)
function Runner.Fade(model: Model, amount: number)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = amount
		end
	end
end

return table.freeze(Runner)
