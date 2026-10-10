--!strict
-- HudPill: money pill (coin, bumps when Value goes up), day pill (sun/moon) and clock pill side by side.
-- Move "Value" up to see the bump.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local HudPill = require(script.Parent)
local Money = require(script.Parent.Money)

const create = Vide.create

type Controls = {
	Value: () -> number,
	Day: () -> number,
	Night: () -> boolean,
	Clock: () -> string,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Value = UILabs.Slider(123, 0, 5000, 1),
		Day = UILabs.Slider(3, 1, 100, 1),
		Night = false,
		Clock = "8:00 AM",
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)

	return create("Frame")({
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),

		HudPill({
			LayoutOrder = 1,
			Icon = function(): HudPill.Icon
				return "Coin"
			end,
			Text = function()
				return Money(controls.Value())
			end,
			Bump = controls.Value,
			MinWidth = 120,
		}),
		HudPill({
			LayoutOrder = 2,
			Height = 44,
			TextSize = 18,
			Icon = function(): HudPill.Icon
				return if controls.Night() then "Moon" else "Sun"
			end,
			Text = function()
				return if controls.Night() then "Night" else `Day {controls.Day()}`
			end,
		}),
		HudPill({
			LayoutOrder = 3,
			Text = controls.Clock,
			MinWidth = 140,
		}),
	})
end)
