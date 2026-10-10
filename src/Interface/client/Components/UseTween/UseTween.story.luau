--!strict
-- Toggle "AtEnd" to move the boxes; change Duration mid-flight to see it applied on the next tween.
-- Top box: default easing (Exponential Out). Bottom box: Linear (what the hold fill uses).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local UseTween = require(script.Parent)

const create = Vide.create

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		AtEnd = false,
		Duration = UILabs.Slider(0.6, 0, 3, 0.05),
	},
}, function(props)
	const controls = props.controls

	local function box(y: number, color: Color3, style: Enum.EasingStyle): Frame
		const position = UseTween(function()
			return if controls.AtEnd() then UDim2.new(1, -80, y, 0) else UDim2.new(0, 16, y, 0)
		end, function()
			return controls.Duration()
		end, style)

		return create("Frame")({
			AnchorPoint = Vector2.new(0, 0.5),
			Position = position,
			Size = UDim2.fromOffset(64, 64),
			BackgroundColor3 = color,
			create("UICorner")({ CornerRadius = UDim.new(0.25, 0) }),
		})
	end

	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		box(0.35, Theme.Color.Mustard, Enum.EasingStyle.Exponential),
		box(0.65, Theme.Color.Teal, Enum.EasingStyle.Linear),
	})
end)
