--!strict
-- The balloon is a BillboardGui, so it is previewed in the 3D viewport: a temporary part 8 studs in front of the
-- Studio camera (the Opal talk radius; removed when the story closes). Toggle Visible to see the pop-in.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local SpeechBalloon = require(script.Parent)

const create = Vide.create
const cleanup = Vide.cleanup

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Text = "Back wall's got gear. Who stocks it? I don't ask.",
		Visible = true,
	},
}, function(props)
	const controls = props.controls

	const camera = workspace.CurrentCamera
	const anchor = Instance.new("Part")
	anchor.Name = "__SpeechBalloonStory"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Size = Vector3.new(1.5, 1.5, 1.5)
	anchor.Color = Theme.Color.Teal
	anchor.CFrame = camera.CFrame * CFrame.new(0, -2, -8)
	anchor.Parent = workspace
	cleanup(anchor)

	const billboard = SpeechBalloon({
		Adornee = anchor,
		Visible = function()
			return controls.Visible()
		end,
		Text = function()
			return controls.Text()
		end,
		StudsOffset = Vector3.new(0, 2, 0),
	})
	billboard.Parent = anchor

	return create("TextLabel")({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(360, 40),
		BackgroundTransparency = 1,
		FontFace = Theme.Font.Body,
		TextSize = 16,
		TextColor3 = Theme.Color.Text,
		Text = "SpeechBalloon: look at the part in front of the camera",
	})
end)
