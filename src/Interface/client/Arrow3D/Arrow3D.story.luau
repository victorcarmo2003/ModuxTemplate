--!strict
-- Arrow3D: the 3D guide arrow is made of world parts, so it is previewed in the 3D viewport: a temporary Part 14 studs in
-- front of the Studio camera with the arrow over it (removed when the story closes). "Shown" pops it in/out; "Grow" is the
-- distance factor of the Beacon (1 = own size, up to 10); "Urged" = the no-progress bob.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Components.Theme)
local Arrow3D = require(script.Parent)

const create = Vide.create
const cleanup = Vide.cleanup

type Controls = {
	Shown: () -> boolean,
	Grow: () -> number,
	Urged: () -> boolean,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Shown = true,
		Grow = UILabs.Slider(1, 1, 10, 0.1),
		Urged = false,
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)

	const camera = workspace.CurrentCamera
	const anchor = Instance.new("Part")
	anchor.Name = "__Arrow3DStory"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Size = Vector3.new(2, 1, 2)
	anchor.Color = Theme.Color.Teal
	anchor.CFrame = camera.CFrame * CFrame.new(0, -2, -14)
	anchor.Parent = workspace
	cleanup(anchor)

	const arrow = Arrow3D.new()
	cleanup(function()
		arrow.Destroy()
	end)
	const connection = RunService.Heartbeat:Connect(function()
		const wanted = controls.Shown()
		if wanted and not arrow.On() then
			arrow.Show(workspace)
		elseif not wanted and arrow.On() then
			arrow.Hide()
		end
		arrow.Step(anchor.Position + Vector3.new(0, 0.5 + 1.2 * controls.Grow(), 0), controls.Grow(), controls.Urged())
	end)
	cleanup(connection)

	return create("TextLabel")({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(420, 28),
		BackgroundTransparency = 1,
		FontFace = Theme.Font.Body,
		TextSize = 16,
		TextColor3 = Theme.Color.Text,
		Text = "Arrow3D: see the 3D viewport (part in front of the camera)",
	})
end)
