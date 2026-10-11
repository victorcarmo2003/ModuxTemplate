--!strict
-- TableSign is a BillboardGui, so it is previewed in the 3D viewport: a temporary part 7 studs in front of the Studio
-- camera (the prompt radius of buy_in_place; removed when the story closes). Switch Buy / NoCash and drag the price.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local TableSign = require(script.Parent)

const create = Vide.create
const cleanup = Vide.cleanup

type Controls = {
	Mode: () -> string,
	Price: () -> number,
	Title: () -> string,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Mode = UILabs.Choose({ "Buy", "NoCash" }),
		Price = UILabs.Slider(30, 1, 999, 1),
		Title = "Patio Table",
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)

	const camera = workspace.CurrentCamera
	const anchor = Instance.new("Part")
	anchor.Name = "__TableSignStory"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Size = Vector3.new(4, 0.3, 2)
	anchor.Color = Theme.Color.Cream
	anchor.CFrame = camera.CFrame * CFrame.new(0, -2, -7)
	anchor.Parent = workspace
	cleanup(anchor)

	const billboard = TableSign({
		Adornee = anchor,
		Visible = function()
			return true
		end,
		Mode = function(): TableSign.Mode
			return controls.Mode() :: TableSign.Mode
		end,
		Title = controls.Title,
		Price = function()
			return `${controls.Price()}`
		end,
		Offset = Vector3.new(0, 1.6, 0),
	})
	billboard.Parent = anchor

	return create("TextLabel")({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(380, 28),
		BackgroundTransparency = 1,
		FontFace = Theme.Font.Body,
		TextSize = 16,
		TextColor3 = Theme.Color.Text,
		Text = "TableSign: look at the part in front of the camera",
	})
end)
