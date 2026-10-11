--!strict
-- Spotlight over a phone-sized mock HUD: a money pill top-left is the target. "Shown" fades the dim in/out, "Target"
-- off dims everything, "X" moves the pill (the hole follows it), "Scale" scales the mock HUD like Theme.Scale (the
-- hole must still match the pill exactly).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local CartoonPanel = require(script.Parent.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.Parent.CartoonLabel)
local Spotlight = require(script.Parent)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIScale is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

type Controls = {
	Shown: () -> boolean,
	Target: () -> boolean,
	X: () -> number,
	Scale: () -> number,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Shown = true,
		Target = true,
		X = UILabs.Slider(12, 0, 500, 1),
		Scale = UILabs.Slider(1, 0.86, 1.6, 0.02),
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)

	const pill = CartoonPanel({
		Name = "Cash",
		Position = function()
			return UDim2.fromOffset(controls.X(), 6)
		end,
		Size = UDim2.fromOffset(130, 48),
		Tone = Theme.Tone.Ink,
		Children = {
			CartoonLabel({
				Box = UDim2.fromScale(1, 1),
				TextSize = 24,
				Text = "$30",
			}),
		},
	})

	return create("Frame")({
		Name = "Screen",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(667, 375),
		BackgroundColor3 = Color3.fromHex("#8FD3F4"),
		ClipsDescendants = true,

		-- mock HUD layer scaled like HudScreen (frame shrunk by the same factor)
		create("Frame")({
			Name = "Hud",
			Size = function()
				return UDim2.fromScale(1 / controls.Scale(), 1 / controls.Scale())
			end,
			BackgroundTransparency = 1,
			createRaw("UIScale")({ Scale = controls.Scale }),
			pill,
		}),
		Spotlight({
			Shown = controls.Shown,
			Target = function(): GuiObject?
				return if controls.Target() then pill else nil
			end,
		}),
	})
end)
