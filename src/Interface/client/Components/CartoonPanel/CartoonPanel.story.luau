--!strict
-- CartoonPanel: every Tone of the kit side by side (pill, chip, card), on a day or night backdrop.
-- The studs texture shows once its id is in Icons.Ids.Studs; "Outline" / "Transparency" change the look live.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local CartoonPanel = require(script.Parent)
local CartoonLabel = require(script.Parent.Parent.CartoonLabel)

const create = Vide.create

type Controls = {
	Night: () -> boolean,
	Outline: () -> number,
	Transparency: () -> number,
}

const TONES: { { Name: string, Tone: Theme.Tone } } = {
	{ Name = "Ink", Tone = Theme.Tone.Ink },
	{ Name = "Cream", Tone = Theme.Tone.Cream },
	{ Name = "White", Tone = Theme.Tone.White },
	{ Name = "Mustard", Tone = Theme.Tone.Mustard },
	{ Name = "Teal", Tone = Theme.Tone.Teal },
	{ Name = "Green", Tone = Theme.Tone.Green },
	{ Name = "Violet", Tone = Theme.Tone.Violet },
	{ Name = "Slate", Tone = Theme.Tone.Slate },
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Night = false,
		Outline = UILabs.Slider(3, 0, 6, 1),
		Transparency = UILabs.Slider(0, 0, 0.9, 0.05),
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)

	const pills: { Instance } = {}
	for index, entry in TONES do
		table.insert(
			pills,
			CartoonPanel({
				Name = entry.Name,
				LayoutOrder = index,
				Size = UDim2.fromOffset(0, 48),
				AutomaticSize = Enum.AutomaticSize.X,
				Tone = entry.Tone,
				Outline = controls.Outline,
				Transparency = controls.Transparency,
				Studs = true,
				Padding = { Left = 16, Right = 16 },
				Children = {
					CartoonLabel({
						Box = UDim2.new(0, 0, 1, 0),
						AutomaticSize = Enum.AutomaticSize.X,
						Text = entry.Name,
						TextSize = 20,
						Color = entry.Tone.Text,
						Stroke = if entry.Tone.Stroke then 2 else 0,
					}),
				},
			})
		)
	end

	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = function()
			return if controls.Night() then Color3.fromHex("#1B2140") else Color3.fromHex("#8FD3F4")
		end,

		create("Frame")({
			Name = "Pills",
			Position = UDim2.fromOffset(24, 24),
			Size = UDim2.new(1, -48, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				Wraps = true,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 14),
			}),
			pills,
		}),

		CartoonPanel({
			Name = "Card",
			Position = UDim2.fromOffset(24, 180),
			Size = UDim2.fromOffset(320, 180),
			Tone = Theme.Tone.Cream,
			Outline = Theme.Outline.Thick,
			Radius = Theme.Radius.Card,
			Lip = 6,
			Studs = true,
			Gloss = false,
			Visible = true,
			Padding = 18,
			Children = {
				CartoonLabel({
					Box = UDim2.fromScale(1, 1),
					Text = "Cream card\nthick outline, lip 6, studs",
					TextSize = 20,
					Wrapped = true,
					Color = Theme.Color.Dark,
					Stroke = 0,
				}),
			},
		}),

		CartoonPanel({
			Name = "Chip",
			Position = UDim2.fromOffset(380, 200),
			Size = UDim2.fromOffset(72, 72),
			Rotation = 10,
			Tone = Theme.Tone.Mustard,
			Outline = Theme.Outline.Thick,
			Children = {
				CartoonLabel({ Box = UDim2.fromScale(1, 1), Text = "A", TextSize = 48, Stroke = 4 }),
			},
		}),
	})
end)
