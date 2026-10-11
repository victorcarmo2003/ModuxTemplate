--!strict
-- The arrow is a BillboardGui, so it is previewed in the 3D viewport: a temporary part 8 studs in front of the Studio
-- camera (removed when the story closes). "Shown" pops it in/out; "Target" off clears the adornee (hides it too);
-- "Scale" = Theme.Scale; "Strong" = the no-progress pulse.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local TutorialArrow = require(script.Parent)

const create = Vide.create
const cleanup = Vide.cleanup

type Controls = {
	Shown: () -> boolean,
	Target: () -> boolean,
	Scale: () -> number,
	Strong: () -> boolean,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Shown = true,
		Target = true,
		Scale = UILabs.Slider(1, 0.86, 1.6, 0.02),
		Strong = false,
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)

	const camera = workspace.CurrentCamera
	const anchor = Instance.new("Part")
	anchor.Name = "__TutorialArrowStory"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Size = Vector3.new(2, 1, 2)
	anchor.Color = Theme.Color.Teal
	anchor.CFrame = camera.CFrame * CFrame.new(0, -2, -8)
	anchor.Parent = workspace
	cleanup(anchor)

	const billboard = TutorialArrow({
		Adornee = function(): Instance?
			return if controls.Target() then anchor else nil
		end,
		Shown = controls.Shown,
		Scale = controls.Scale,
		Strong = controls.Strong,
	})
	billboard.Parent = anchor

	return create("TextLabel")({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(420, 28),
		BackgroundTransparency = 1,
		FontFace = Theme.Font.Body,
		TextSize = 16,
		TextColor3 = Theme.Color.Text,
		Text = "TutorialArrow: see the 3D viewport (part in front of the camera)",
	})
end)
