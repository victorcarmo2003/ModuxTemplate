--!strict
-- StockPlate: flat preview of the plate plus the real SurfaceGui on a temporary plate 4 studs in front of the
-- Studio camera (removed when the story closes). "Icon" empty shows the Q-152 placeholder.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local StockPlate = require(script.Parent)

const create = Vide.create
const cleanup = Vide.cleanup

const LOW = 2
const SWATCH: { [string]: Color3 } = {
	Ketchup = Color3.fromHex("#E2402E"),
	Mustard = Color3.fromHex("#F6C12B"),
	Cheese = Color3.fromHex("#FFD45A"),
	Bacon = Color3.fromHex("#C9533E"),
	["Potato Sticks"] = Color3.fromHex("#F7D27A"),
	["Cream Cheese"] = Color3.fromHex("#FFF8EC"),
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Ingredient = UILabs.Choose({ "Ketchup", "Mustard", "Cheese", "Bacon", "Potato Sticks", "Cream Cheese" }),
		Icon = "",
		Amount = UILabs.Slider(7, 0, 75, 1),
		Capacity = UILabs.Slider(30, 1, 75, 1),
		Blocked = false,
		Vertical = false,
	},
}, function(props)
	const controls = props.controls

	local function text(): string
		return `{math.min(controls.Amount(), controls.Capacity())}/{controls.Capacity()}`
	end
	local function low(): boolean
		return controls.Amount() <= LOW
	end
	local function showCount(): boolean
		return not controls.Blocked()
	end

	const camera = workspace.CurrentCamera
	const plate = Instance.new("Part")
	plate.Name = "__StockPlateStory"
	plate.Anchored = true
	plate.CanCollide = false
	plate.Size = Vector3.new(1.2, 0.5, 0.05)
	plate.Color = Color3.fromHex("#C9D1D8")
	-- Same orientation as the camera: the plate's Back face (+Z) looks at it.
	plate.CFrame = camera.CFrame * CFrame.new(0, -0.4, -4)
	plate.Parent = workspace
	cleanup(plate)

	-- The in-world gui is rebuilt when the ingredient or layout changes (both are plain props).
	Vide.effect(function()
		const name = controls.Ingredient() :: string
		const vertical = controls.Vertical()
		plate.Size = if vertical then Vector3.new(0.6, 0.8, 0.05) else Vector3.new(1.2, 0.5, 0.05)
		const gui = Vide.untrack(function()
			return StockPlate({
				Adornee = plate,
				Face = Enum.NormalId.Back,
				Icon = controls.Icon,
				Label = name,
				Color = SWATCH[name] or Color3.new(1, 1, 1),
				Text = text,
				Low = low,
				ShowCount = showCount,
				Vertical = vertical,
			})
		end)
		gui.Parent = plate
		cleanup(gui)
	end)

	const flat = StockPlate({
		Face = Enum.NormalId.Front,
		Icon = controls.Icon,
		Label = "Ketchup",
		Color = SWATCH.Ketchup,
		Text = text,
		Low = low,
		ShowCount = showCount,
	})
	const body = flat:FindFirstChild("Plate") :: Frame
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.5)
	body.Size = UDim2.fromOffset(240, 100)
	cleanup(flat)

	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		body,
	})
end)
