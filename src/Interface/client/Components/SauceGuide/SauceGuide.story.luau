--!strict
-- SauceGuide over the real hot dog (owner 2026-10-22: "monta um UI Labs pra gente visualizar sem dar play"). A ViewportFrame
-- shows the kit hot dog (Assets.Items.Tools.hot_dog) on the kit plate, seen like the condiment focus (from the front, Pitch
-- degrees down); the arrows follow the S of Content.Prep.Build.Sauce.Path put on the sausage the same way as the focus
-- (HotDogVisual.around). Tilt / Lift move the line on the sausage (the game's values: HotDogVisual.Tilt, Toppings GUIDE_LIFT),
-- Spacing / Size the arrows (Toppings GUIDE_SPACING / GUIDE_SIZE at 720 p). Tell the agent the numbers you like.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local HotDogVisual = require(ReplicatedStorage.shared.Item.HotDogVisual)
local SauceGuide = require(script.Parent)

const create = Vide.create
const source = Vide.source
const derive = Vide.derive
const cleanup = Vide.cleanup
-- Vide 0.4.1 types `create` for some classes only (ViewportFrame is not among them)
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

type Controls = {
	Tilt: () -> number,
	Lift: () -> number,
	Spacing: () -> number,
	Size: () -> number,
	Pitch: () -> number,
	Distance: () -> number,
	Guide: () -> boolean,
}

const BUN_LENGTH = 0.85 -- HotDogVisual: share of the Handle's long side the S covers
const BEAD = 0.05 -- share of the bun length (the drawn bead)
const STEPS = 6
const FOV = 40
const DISH_SCALE = 0.72 -- KitchenService attachDish

-- the kit hot dog on the kit plate's base, local copies (anchored, no scripts)
local function buildProp(): (Model, BasePart?, BasePart?)
	const model = Instance.new("Model")
	model.Name = "HotDogPreview"
	const tools = ReplicatedStorage:FindFirstChild("Assets")
	const items = if tools then tools:FindFirstChild("Items") else nil
	const kit = if items then items:FindFirstChild("Tools") else nil
	const hotDog = if kit then kit:FindFirstChild("hot_dog") else nil
	const plate = if kit then kit:FindFirstChild("plate") else nil
	local handle: BasePart? = nil
	local sausage: BasePart? = nil
	if hotDog ~= nil then
		for _, part in hotDog:GetDescendants() do
			if part:IsA("BasePart") then
				const copy = part:Clone()
				copy.Anchored = true
				for _, child in copy:GetChildren() do
					if child:IsA("JointInstance") or child:IsA("WeldConstraint") then
						child:Destroy()
					end
				end
				copy.Parent = model
				if part.Name == "Handle" then
					handle = copy
				elseif part.Name == "Sausage" then
					sausage = copy
				end
			end
		end
	end
	const plateHandle = if plate ~= nil then plate:FindFirstChild("Handle") else nil
	if plate ~= nil and handle ~= nil and plateHandle ~= nil and plateHandle:IsA("BasePart") then
		-- the plate's base top right under the bun (as the focus puts it)
		const base = handle.CFrame * CFrame.new(0, -handle.Size.Y / 2, 0)
		const kitTop = plateHandle.CFrame * CFrame.new(0, plateHandle.Size.Y / 2, 0)
		for _, part in plate:GetDescendants() do
			if part:IsA("BasePart") then
				const copy = part:Clone()
				copy.Anchored = true
				for _, child in copy:GetChildren() do
					if not child:IsA("DataModelMesh") and not child:IsA("SurfaceAppearance") and not child:IsA("Decal") then
						child:Destroy()
					elseif child:IsA("SpecialMesh") then
						child.Scale *= DISH_SCALE
					end
				end
				const offset = kitTop:ToObjectSpace(part.CFrame)
				copy.Size *= DISH_SCALE
				copy.CFrame = base * (offset - offset.Position + offset.Position * DISH_SCALE)
				copy.Parent = model
			end
		end
	end
	return model, handle, sausage
end

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Tilt = UILabs.Slider(math.deg(HotDogVisual.Tilt), -60, 80, 1),
		Lift = UILabs.Slider(1.25, -1, 2, 0.05),
		Spacing = UILabs.Slider(21, 10, 60, 1),
		Size = UILabs.Slider(18, 6, 40, 1),
		Pitch = UILabs.Slider(61, 10, 89, 1),
		Distance = UILabs.Slider(2.2, 1, 6, 0.1),
		Guide = true,
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)

	const model, handle, sausage = buildProp()
	cleanup(model)
	const camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	cleanup(camera)

	const size = source(Vector2.new(640, 360))

	-- the S on screen for these controls
	const points = derive(function(): { Vector2 }
		const tilt = math.rad(controls.Tilt())
		const pitch = math.rad(controls.Pitch())
		const distance = controls.Distance()
		const lift = controls.Lift()
		const screen = size()
		const bun, meat = handle, sausage
		if bun == nil or meat == nil then
			return {}
		end
		const along = bun.CFrame.RightVector
		const up = bun.CFrame.UpVector
		const across = bun.CFrame:VectorToWorldSpace(Vector3.zAxis)
		const axis = meat.Position
		const radius = HotDogVisual.radiusOf(model) or meat.Size.Y / 2
		const length = bun.Size.X * BUN_LENGTH
		const bead = math.max(length * BEAD, 0.04)
		-- the focus's camera: in front of the bun (the +across side), Pitch down
		const eye = axis + (across * math.cos(pitch) + up * math.sin(pitch)) * distance
		camera.CFrame = CFrame.lookAt(eye, axis)
		const out: { Vector2 } = {}
		for _, point in SauceGuide.Dense(Content.Prep.Build.Sauce.Path, STEPS) do
			const world = axis + along * ((point.X - 0.5) * length) + HotDogVisual.around(up, across, point.Y, tilt) * (radius + bead * lift)
			const at = SauceGuide.Project(camera, screen, world)
			if at ~= nil then
				table.insert(out, at)
			end
		end
		return out
	end)

	const viewport = createRaw("ViewportFrame")({
		Name = "Preview",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromHex("#6E7C8C"),
		Ambient = Color3.fromRGB(180, 170, 160),
		LightColor = Color3.fromRGB(255, 244, 228),
		LightDirection = Vector3.new(-0.4, -1, -0.6),
		CurrentCamera = camera,
		SauceGuide.Component({
			Points = points,
			Spacing = controls.Spacing,
			Size = controls.Size,
			Visible = controls.Guide,
		}),
	}) :: ViewportFrame
	model.Parent = viewport
	camera.Parent = viewport
	const measure = function()
		size(viewport.AbsoluteSize)
	end
	cleanup(viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure))
	task.defer(measure)

	return create("Frame")({
		Name = "Screen",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(640, 360),
		BackgroundTransparency = 1,
		viewport,
	})
end)
