--!strict
-- TutorialPanel on a phone-sized frame (iPhone SE landscape, 667 x 375) or the whole viewport. Move "Step" up to see
-- the jump; "Shown" pops it in/out; clear "Hint" or "Skip" to hide those lines. Skip clicks are counted.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local TutorialPanel = require(script.Parent)

const create = Vide.create
const source = Vide.source

type Controls = {
	Phone: () -> boolean,
	Scale: () -> number,
	Shown: () -> boolean,
	Step: () -> number,
	Total: () -> number,
	Text: () -> string,
	Hint: () -> string,
	Skip: () -> string,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Phone = true,
		Scale = UILabs.Slider(1, 1, 2, 0.05),
		Shown = true,
		Step = UILabs.Slider(1, 1, 7, 1),
		Total = UILabs.Slider(7, 0, 9, 1),
		Text = "Put a sausage on the grill",
		Hint = 'Walk to the cooler and press "Grill".',
		Skip = "Skip (Q)",
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)
	const skips = source(0)

	return create("Frame")({
		Name = "Screen",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = function()
			return if controls.Phone() then UDim2.fromOffset(667, 375) else UDim2.fromScale(1, 1)
		end,
		BackgroundColor3 = Color3.fromHex("#8FD3F4"),
		ClipsDescendants = true,

		TutorialPanel({
			Shown = controls.Shown,
			Step = controls.Step,
			Total = controls.Total,
			Text = controls.Text,
			Hint = controls.Hint,
			SkipText = controls.Skip,
			OnSkip = function()
				skips(skips() + 1)
			end,
			Scale = controls.Scale,
		}),

		create("TextLabel")({
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 12, 1, -12),
			Size = UDim2.fromOffset(200, 24),
			BackgroundTransparency = 1,
			FontFace = Theme.Font.Body,
			TextSize = 16,
			TextColor3 = Theme.Color.Ink,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = function()
				return `Skips: {skips()}`
			end,
		}),
	})
end)
