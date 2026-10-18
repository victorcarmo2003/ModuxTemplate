--!strict
-- HudSpectate: "Mode" Down (fainted) / Out (spectator) / None. "Card" toggles the Out top card; "Focus" the Down centre
-- title (the first seconds after a fall, TASK-485); "Wipe" swaps its line to the nobody-standing one; "Target" empty
-- shows "Watching the trailer"; "Device" picks the switch hint. Phone = 667 x 375.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local HudSpectate = require(script.Parent)

const create = Vide.create

type Controls = {
	Phone: () -> boolean,
	Mode: () -> string,
	Card: () -> boolean,
	Focus: () -> boolean,
	Wipe: () -> boolean,
	Target: () -> string,
	Device: () -> string,
}

const HINT: { [string]: string } = {
	Touch = "Tap to switch",
	KeyboardMouse = "Press E to switch",
	Gamepad = "Press X to switch",
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Phone = true,
		Mode = UILabs.Choose({ "Down", "Out", "None" }),
		Card = true,
		Focus = true,
		Wipe = false,
		Target = "Pickles",
		Device = UILabs.Choose({ "Touch", "KeyboardMouse", "Gamepad" }),
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)

	return create("Frame")({
		Name = "Screen",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = function()
			return if controls.Phone() then UDim2.fromOffset(667, 375) else UDim2.fromScale(1, 1)
		end,
		BackgroundColor3 = Theme.Color.Teal,
		BackgroundTransparency = 0.6,
		ClipsDescendants = true,

		HudSpectate({
			Mode = function(): HudSpectate.Mode
				return controls.Mode() :: HudSpectate.Mode
			end,
			Card = controls.Card,
			Focus = controls.Focus,
			Line = function()
				return if controls.Wipe() then "Revive before the lights go out!" else "Your crew's still on shift."
			end,
			Target = controls.Target,
			Hint = function()
				return if controls.Target() == "" then "" else HINT[controls.Device()] or ""
			end,
		}),
	})
end)
