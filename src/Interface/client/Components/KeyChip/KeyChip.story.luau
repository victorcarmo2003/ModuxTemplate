--!strict
-- KeyChip on a light card at three texts: the number sits in the middle of the badge. "Text" edits the first one.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local KeyChip = require(script.Parent)

const create = Vide.create

type Controls = {
	Text: () -> string,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Text = "1",
	},
}, function(props)
	const controls: Controls = (props.controls :: any)
	local function constant(text: string): () -> string
		return function()
			return text
		end
	end
	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.Cream,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 24),
		}),
		KeyChip({ Text = controls.Text }),
		KeyChip({ Text = constant("2") }),
		KeyChip({ Text = constant("C") }),
		KeyChip({ Text = constant("Right") }),
	})
end)
