--!strict
-- Sunburst behind an Ink panel the size of the GemShop window (640 x 360): the rays spin slowly; "Visible" off stops
-- them. Motion.Reduced (Settings or the Roblox setting) keeps them still.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local Sunburst = require(script.Parent)

const create = Vide.create

type Controls = {
	Visible: () -> boolean,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Visible = true,
	},
}, function(props)
	const controls: Controls = (props.controls :: any)
	return create("Frame")({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(640, 360),
		BackgroundColor3 = Theme.Tone.Ink.Bottom,
		create("UICorner")({ CornerRadius = Theme.Radius.Card }),
		Sunburst({ Visible = controls.Visible }),
	})
end)
