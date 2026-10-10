--!strict
-- StockCounter: flat preview of the pill plus the real BillboardGui on a temporary part 8 studs in front of the
-- Studio camera (removed when the story closes). "Auto" drains the stock 1 per 0.5 s and refills, to see the
-- switch to red at <= 2.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local StockCounter = require(script.Parent)

const create = Vide.create
const source = Vide.source
const cleanup = Vide.cleanup

const LOW = 2

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Amount = UILabs.Slider(7, 0, 30, 1),
		Capacity = UILabs.Slider(12, 1, 30, 1),
		Auto = false,
		InWorld = true,
	},
}, function(props)
	const controls = props.controls

	const drained = source(0)
	local clock = 0
	const connection = RunService.Heartbeat:Connect(function(dt: number)
		if not controls.Auto() then
			return
		end
		clock += dt
		if clock >= 0.5 then
			clock = 0
			drained((drained() + 1) % (controls.Capacity() + 1))
		end
	end)
	cleanup(connection)

	local function amount(): number
		return if controls.Auto() then controls.Capacity() - drained() else math.min(controls.Amount(), controls.Capacity())
	end
	local function text(): string
		return `{amount()}/{controls.Capacity()}`
	end
	local function low(): boolean
		return amount() <= LOW
	end

	const camera = workspace.CurrentCamera
	const anchor = Instance.new("Part")
	anchor.Name = "__StockCounterStory"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Size = Vector3.new(2, 1, 2)
	anchor.Color = Color3.fromHex("#C9D1D8")
	anchor.CFrame = camera.CFrame * CFrame.new(0, -1.5, -8)
	anchor.Parent = workspace
	cleanup(anchor)

	const billboard = StockCounter({
		Adornee = anchor,
		Text = text,
		Low = low,
		Visible = function()
			return controls.InWorld()
		end,
		StudsOffset = Vector3.new(0, 1.2, 0),
	})
	billboard.Parent = anchor

	-- Flat copy: the same component, shown through a ScreenGui-like frame (BillboardGui children reused).
	const flat = StockCounter({ Text = text, Low = low })
	const pill = flat:FindFirstChild("Pill") :: Frame
	pill.AnchorPoint = Vector2.new(0.5, 0.5)
	pill.Position = UDim2.fromScale(0.5, 0.5)
	pill.Size = UDim2.fromOffset(76, 30)
	cleanup(flat)

	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		pill,
	})
end)
