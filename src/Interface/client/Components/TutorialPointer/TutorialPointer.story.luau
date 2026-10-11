--!strict
-- TutorialPointer on a phone-sized frame: "Angle" turns the arrow; "X"/"Y" move the badge (px in the frame).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local TutorialPointer = require(script.Parent)

const create = Vide.create

type Controls = {
	Shown: () -> boolean,
	Angle: () -> number,
	X: () -> number,
	Y: () -> number,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Shown = true,
		Angle = UILabs.Slider(0, -180, 180, 5),
		X = UILabs.Slider(620, 0, 667, 1),
		Y = UILabs.Slider(190, 0, 375, 1),
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)

	return create("Frame")({
		Name = "Screen",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(667, 375),
		BackgroundColor3 = Color3.fromHex("#8FD3F4"),
		ClipsDescendants = true,

		TutorialPointer({
			Shown = controls.Shown,
			Position = function()
				return Vector2.new(controls.X(), controls.Y())
			end,
			Angle = controls.Angle,
		}),
	})
end)
