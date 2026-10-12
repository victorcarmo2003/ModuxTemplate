--!strict
-- PadTag is a BillboardGui, so it is previewed in the 3D viewport: a temporary pad 14 studs in front of the Studio camera
-- (removed when the story closes). "State" / "Count" / "Max" / "Status" / "Leader" / "Badge" drive the sign; change
-- Count or State to see the pill pop; "Shown" fades the sign in and out; move the camera away to check it from 60+ studs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local PadTag = require(script.Parent)

const create = Vide.create
const cleanup = Vide.cleanup

type Controls = {
	State: () -> string,
	Count: () -> number,
	Max: () -> number,
	Status: () -> string,
	Leader: () -> string,
	Badge: () -> string,
	Shown: () -> boolean,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		State = UILabs.Choose({ "Free", "Configuring", "Open", "Closed", "Starting" }),
		Count = UILabs.Slider(1, 0, 4, 1),
		Max = UILabs.Slider(2, 0, 4, 1),
		Status = "FULL",
		Leader = "Ana the Long-Named",
		Badge = "D1",
		Shown = true,
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)

	const camera = workspace.CurrentCamera
	const anchor = Instance.new("Part")
	anchor.Name = "__PadTagStory"
	anchor.Shape = Enum.PartType.Cylinder
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Size = Vector3.new(0.4, 12, 12)
	anchor.Color = Theme.Color.Cream
	anchor.CFrame = camera.CFrame * CFrame.new(0, -4, -14) * CFrame.Angles(0, 0, math.rad(90))
	anchor.Parent = workspace
	cleanup(anchor)

	const billboard = PadTag({
		Adornee = anchor,
		Visible = controls.Shown,
		Badge = controls.Badge(),
		Leader = controls.Leader,
		Count = controls.Count,
		Max = controls.Max,
		State = function(): PadTag.State
			return controls.State() :: PadTag.State
		end,
		Status = controls.Status,
		Offset = Vector3.new(0, 9, 0),
	})
	billboard.Parent = anchor

	return create("TextLabel")({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(380, 28),
		BackgroundTransparency = 1,
		FontFace = Theme.Font.Body,
		TextSize = 16,
		TextColor3 = Theme.Color.Text,
		Text = "PadTag: look at the pad in front of the camera",
	})
end)
