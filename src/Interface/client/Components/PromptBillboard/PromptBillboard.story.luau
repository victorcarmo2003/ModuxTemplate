--!strict
-- The prompt is a BillboardGui, so it is previewed in the 3D viewport: a temporary part 6 studs in
-- front of the Studio camera (removed when the story closes). Drive every state from the controls;
-- clicks on the pill only reach OnPress/OnRelease in a play test (BillboardGui under PlayerGui).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local PromptBillboard = require(script.Parent)

const create = Vide.create
const cleanup = Vide.cleanup

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		State = UILabs.Choose({ "Prompt", "Indicator", "Hidden" }),
		Text = "Take Order",
		KeyLabel = UILabs.Choose({ "E", "X", "" }),
		Holding = false,
		HoldDuration = UILabs.Slider(0.6, 0, 3, 0.05),
	},
}, function(props)
	const controls = props.controls

	const camera = workspace.CurrentCamera
	const anchor = Instance.new("Part")
	anchor.Name = "__PromptBillboardStory"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Color = Theme.Color.Mustard
	anchor.CFrame = camera.CFrame * CFrame.new(0, -1, -6)
	anchor.Parent = workspace
	cleanup(anchor)

	const billboard = PromptBillboard({
		Adornee = anchor,
		State = function()
			return controls.State()
		end,
		Text = function()
			return controls.Text()
		end,
		KeyLabel = function()
			return controls.KeyLabel()
		end,
		Holding = function()
			return controls.Holding()
		end,
		HoldDuration = function()
			return controls.HoldDuration()
		end,
		StudsOffset = Vector3.new(0, 1.2, 0),
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
		Text = "PromptBillboard: see the 3D viewport (part in front of the camera)",
	})
end)
