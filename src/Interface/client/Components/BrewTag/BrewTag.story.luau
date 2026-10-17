--!strict
-- BrewTag is a BillboardGui, so it is previewed in the 3D viewport: a temporary part 14 studs in front of the Studio camera
-- (removed when the story closes). Pick the mode, drag the progress and the seconds; "Shown" fades it in and out.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local BrewTag = require(script.Parent)

const cleanup = Vide.cleanup

type Controls = {
	Mode: () -> string,
	Progress: () -> number,
	Seconds: () -> number,
	Shown: () -> boolean,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Mode = UILabs.Choose({ "Brewing", "Cooldown", "Ready" }),
		Progress = UILabs.Slider(0.4, 0, 1, 0.01),
		Seconds = UILabs.Slider(42, 0, 120, 1),
		Shown = true,
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)

	const camera = workspace.CurrentCamera
	const anchor = Instance.new("Part")
	anchor.Name = "__BrewTagStory"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Size = Vector3.new(2, 2, 1.2)
	anchor.Color = Theme.Color.Green
	anchor.CFrame = camera.CFrame * CFrame.new(0, -3, -14)
	anchor.Parent = workspace
	cleanup(anchor)

	const tag = BrewTag({
		Adornee = anchor,
		Visible = controls.Shown,
		Mode = function(): BrewTag.Mode
			return controls.Mode() :: any
		end,
		Progress = controls.Progress,
		Seconds = controls.Seconds,
		StudsOffset = Vector3.new(0, 2, 0),
	})
	tag.Parent = anchor
	cleanup(tag)

	return Vide.create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	})
end)
