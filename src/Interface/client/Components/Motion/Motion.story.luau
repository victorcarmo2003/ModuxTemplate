--!strict
-- Motion: move "Value" up to see the bump and the count-up (the HUD money); toggle "Shown" for the pop with overshoot;
-- hold the mouse on the square to see the press squash.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local Motion = require(script.Parent)
local CartoonPanel = require(script.Parent.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.Parent.CartoonLabel)

const create = Vide.create
const source = Vide.source
-- Vide 0.4.1 types `create` for 19 classes only; UIScale is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

type Controls = {
	Value: () -> number,
	Shown: () -> boolean,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Value = UILabs.Slider(120, 0, 5000, 1),
		Shown = true,
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)
	const bump = Motion.Bump(controls.Value)
	const rolled = Motion.Count(controls.Value)
	const pop = Motion.Pop(controls.Shown)
	const pressed = source(false)
	const press = Motion.Press(pressed)

	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromHex("#8FD3F4"),

		CartoonPanel({
			Name = "Bump",
			Position = UDim2.fromOffset(40, 40),
			Size = UDim2.fromOffset(0, 48),
			AutomaticSize = Enum.AutomaticSize.X,
			Padding = { Left = 16, Right = 16 },
			Decor = { createRaw("UIScale")({ Scale = bump }) },
			Children = {
				CartoonLabel({
					Box = UDim2.new(0, 0, 1, 0),
					AutomaticSize = Enum.AutomaticSize.X,
					TextSize = 24,
					Text = function()
						return `${math.floor(rolled() + 0.5)}`
					end,
				}),
			},
		}),

		CartoonPanel({
			Name = "Pop",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(320, 180),
			Size = UDim2.fromOffset(200, 100),
			Tone = Theme.Tone.Cream,
			Radius = Theme.Radius.Card,
			Outline = Theme.Outline.Thick,
			Decor = { createRaw("UIScale")({ Scale = pop }) },
			Children = {
				CartoonLabel({
					Box = UDim2.fromScale(1, 1),
					Text = "Pop!",
					TextSize = 28,
					Color = Theme.Color.Dark,
					Stroke = 0,
				}),
			},
		}),

		create("TextButton")({
			Name = "Press",
			Position = UDim2.fromOffset(40, 260),
			Size = UDim2.fromOffset(88, 88),
			BackgroundTransparency = 1,
			Text = "",
			MouseButton1Down = function()
				pressed(true)
			end,
			MouseButton1Up = function()
				pressed(false)
			end,
			MouseLeave = function()
				pressed(false)
			end,
			createRaw("UIScale")({ Scale = press }),
			CartoonPanel({
				Size = UDim2.fromScale(1, 1),
				Tone = Theme.Tone.Mustard,
				Radius = Theme.Radius.Card,
				Outline = Theme.Outline.Thick,
			}),
		}),
	})
end)
