--!strict
-- One choice row of the SettingsPanel: label · two or more option buttons; the chosen one is Mustard, the others Ink.
-- Used for on/off switches ("On" / "Off") and the prompt mode ("Single" / "Multi"). Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local CartoonButton = require(script.Parent.Parent.CartoonButton)
local CartoonLabel = require(script.Parent.Parent.CartoonLabel)

const create = Vide.create

export type Option = { Key: string, Text: string }

export type Props = {
	Name: string,
	LayoutOrder: number,
	Label: string,
	Options: { Option },
	Value: () -> string, -- Key of the chosen option
	OnChange: (key: string) -> (),
	Height: number?,
	LabelWidth: number?,
	OptionWidth: number?,
}

const GAP = 6

return function(props: Props): Frame
	const height = props.Height or Theme.MinTouch
	const labelWidth = props.LabelWidth or 120
	const optionWidth = props.OptionWidth or 76

	const buttons: { any } = {
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, GAP),
		}),
	}
	for index, option in props.Options do
		table.insert(
			buttons,
			CartoonButton({
				Name = option.Key,
				LayoutOrder = index,
				Size = UDim2.fromOffset(optionWidth, height - 4),
				TextSize = 16,
				Text = option.Text,
				Outline = Theme.Outline.Normal,
				Tone = function(): Theme.Tone
					return if props.Value() == option.Key then Theme.Tone.Mustard else Theme.Tone.Ink
				end,
				OnActivated = function()
					if Vide.untrack(props.Value) ~= option.Key then
						props.OnChange(option.Key)
					end
				end,
			})
		)
	end

	return create("Frame")({
		Name = props.Name,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,

		CartoonLabel({
			Name = "Label",
			TextSize = 18,
			Text = props.Label,
			XAlignment = Enum.TextXAlignment.Left,
			Box = UDim2.fromOffset(labelWidth, height),
		}),

		create("Frame")({
			Name = "Options",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(1, -labelWidth, 1, 0),
			BackgroundTransparency = 1,
			buttons,
		}),
	}) :: Frame
end
