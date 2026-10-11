--!strict
-- CartoonLabel: the type scale of the kit (14 px minimum on a phone up to the 48 px grade letter), white with the
-- size-driven Ink stroke on the world, and Ink without stroke on a Cream card.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local CartoonLabel = require(script.Parent)
local CartoonPanel = require(script.Parent.Parent.CartoonPanel)

const create = Vide.create

type Controls = {
	Text: () -> string,
}

const SIZES = { 14, 16, 18, 22, 28, 48 }

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Text = "Night 3 · $1,234",
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)

	const light: { Instance } = {}
	const dark: { Instance } = {}
	for index, size in SIZES do
		table.insert(light, CartoonLabel({ LayoutOrder = index, Text = controls.Text, TextSize = size }))
		table.insert(
			dark,
			CartoonLabel({
				LayoutOrder = index,
				Text = controls.Text,
				TextSize = size,
				Color = Theme.Color.Dark,
				Stroke = 0,
			})
		)
	end

	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromHex("#8FD3F4"),

		create("Frame")({
			Position = UDim2.fromOffset(24, 24),
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			light,
		}),

		CartoonPanel({
			Position = UDim2.fromOffset(420, 24),
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			Tone = Theme.Tone.Cream,
			Outline = Theme.Outline.Thick,
			Radius = Theme.Radius.Card,
			Gloss = false,
			Padding = 16,
			Children = {
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 6),
				}),
				dark,
			},
		}),
	})
end)
