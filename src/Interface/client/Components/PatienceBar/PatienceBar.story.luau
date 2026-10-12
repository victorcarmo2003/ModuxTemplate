--!strict
-- PatienceBar is a BillboardGui: previewed over a temporary ball 8 studs in front of the Studio camera. Flip Order to
-- swap the clock (Queue: blue -> yellow, clock; Order: green -> red, hot dog) and drag the fraction.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local PatienceBar = require(script.Parent)

const create = Vide.create
const cleanup = Vide.cleanup

type Controls = {
	Order: () -> boolean,
	Fraction: () -> number,
	Lift: () -> number,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Order = false,
		Fraction = UILabs.Slider(0.8, 0, 1, 0.01),
		Lift = UILabs.Slider(28, 0, 120, 1),
	},
}, function(props)
	const controls: Controls = (props.controls :: any)
	const camera = workspace.CurrentCamera
	const anchor = Instance.new("Part")
	anchor.Name = "__PatienceBarStory"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Shape = Enum.PartType.Ball
	anchor.Size = Vector3.new(1.4, 1.4, 1.4)
	anchor.Color = Theme.Color.Cream
	anchor.CFrame = camera.CFrame * CFrame.new(0, -2, -8)
	anchor.Parent = workspace
	cleanup(anchor)

	const billboard = PatienceBar({
		Adornee = anchor,
		Visible = function()
			return true
		end,
		Phase = function(): PatienceBar.Phase
			return if controls.Order() then "Order" else "Queue"
		end,
		Fraction = controls.Fraction,
		Lift = controls.Lift,
		Offset = Vector3.new(0, 1.2, 0),
		MaxDistance = 200,
	})
	billboard.Parent = anchor

	return create("TextLabel")({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(420, 28),
		BackgroundTransparency = 1,
		FontFace = Theme.Font.Body,
		TextSize = 16,
		TextColor3 = Theme.Color.Text,
		Text = "PatienceBar: look at the ball in front of the camera",
	})
end)
