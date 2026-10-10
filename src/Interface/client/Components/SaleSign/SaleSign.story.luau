--!strict
-- SaleSign is a BillboardGui, so it is previewed in the 3D viewport: a temporary part 10 studs in front of the
-- Studio camera (removed when the story closes). "Day" below BuyFromDay shows "Available on Day N", from it on
-- "FOR SALE"; "Bought" hides the sign (ui-text.md §13).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local SaleSign = require(script.Parent)

const create = Vide.create
const cleanup = Vide.cleanup

const BUY_FROM_DAY = 5 -- Content.Vehicles.trailer.BuyFromDay

type Controls = {
	Day: () -> number,
	Bought: () -> boolean,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Day = UILabs.Slider(1, 1, 10, 1),
		Bought = false,
	},
}, function(props)
	const controls: Controls = (props.controls :: any)

	const camera = workspace.CurrentCamera
	const anchor = Instance.new("Part")
	anchor.Name = "__SaleSignStory"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Size = Vector3.new(2, 4, 0.3)
	anchor.Color = Theme.Color.Cream
	anchor.CFrame = camera.CFrame * CFrame.new(0, -2, -10)
	anchor.Parent = workspace
	cleanup(anchor)

	const billboard = SaleSign({
		Adornee = anchor,
		Visible = function()
			return not controls.Bought()
		end,
		Text = function()
			return if controls.Day() < BUY_FROM_DAY then `Available on Day {BUY_FROM_DAY}` else "FOR SALE"
		end,
		Offset = Vector3.new(0, 2.8, 0),
		MaxDistance = 200,
	})
	billboard.Parent = anchor

	return create("TextLabel")({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(460, 28),
		BackgroundTransparency = 1,
		FontFace = Theme.Font.Body,
		TextSize = 16,
		TextColor3 = Theme.Color.Text,
		Text = "SaleSign: see the 3D viewport; move Day, toggle Bought",
	})
end)
