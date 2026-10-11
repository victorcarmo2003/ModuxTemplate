--!strict
-- CartoonButton: primary Mustard, secondary Cream, Teal round close, Slate disabled. Press to see the squash; hover to
-- see the grow; "Enabled" off turns every button Slate and stops the clicks (the counter stays).
-- Icons show once their sheet is uploaded (Hud/* now, Ui/* after the AST-091 id goes in Icons.Ids).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local CartoonButton = require(script.Parent)
local CartoonLabel = require(script.Parent.Parent.CartoonLabel)

const create = Vide.create
const source = Vide.source

type Controls = {
	Enabled: () -> boolean,
	Text: () -> string,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Enabled = true,
		Text = "Buy · 45 Gems",
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)
	const clicks = source(0)
	local function click()
		clicks(clicks() + 1)
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
				Padding = UDim.new(0, 16),
			}),

			CartoonButton({
				LayoutOrder = 1,
				Text = controls.Text,
				Icon = "Hud/gem",
				Enabled = controls.Enabled,
				OnActivated = click,
			}),
			CartoonButton({
				LayoutOrder = 2,
				Text = "Select",
				Tone = Theme.Tone.Cream,
				Enabled = controls.Enabled,
				OnActivated = click,
			}),
			CartoonButton({
				LayoutOrder = 3,
				Text = "Selected",
				Tone = Theme.Tone.Green,
				Size = UDim2.fromOffset(200, 48),
				Enabled = controls.Enabled,
				OnActivated = click,
			}),
			CartoonButton({
				LayoutOrder = 4,
				Name = "Close",
				Size = UDim2.fromOffset(44, 44),
				Tone = Theme.Tone.Teal,
				Text = "X",
				Padding = 0,
				Enabled = controls.Enabled,
				OnActivated = click,
			}),
			CartoonLabel({
				LayoutOrder = 5,
				Text = function()
					return `Clicks: {clicks()}`
				end,
				TextSize = 22,
			}),
		}),
	})
end)
