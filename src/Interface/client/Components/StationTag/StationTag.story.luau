--!strict
-- StationTag is a BillboardGui, so it is previewed in the 3D viewport: a temporary part 14 studs in front of the Studio camera
-- (removed when the story closes). "Who" empty = the station is free (Slate); change the tab to see the second line; "Shown"
-- fades it in and out; move the camera away to check it from 30+ studs (MaxDistance 40).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local StationTag = require(script.Parent)

const cleanup = Vide.cleanup

type Controls = {
	Who: () -> string,
	Tab: () -> string,
	Station: () -> number,
	Shown: () -> boolean,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Who = "Ana",
		Tab = UILabs.Choose({ "Order", "Grill", "Build", "Serve" }),
		Station = UILabs.Slider(2, 1, 4, 1),
		Shown = true,
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)

	const camera = workspace.CurrentCamera
	const anchor = Instance.new("Part")
	anchor.Name = "__StationTagStory"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Size = Vector3.new(4, 0.4, 3)
	anchor.Color = Theme.Color.Cream
	anchor.CFrame = camera.CFrame * CFrame.new(0, -3, -14)
	anchor.Parent = workspace
	cleanup(anchor)

	-- the station number is fixed per tag: rebuilt when the control changes
	const billboard = StationTag({
		Adornee = anchor,
		Visible = controls.Shown,
		Station = controls.Station(),
		Who = controls.Who,
		Tab = controls.Tab,
		Offset = Vector3.new(0, 2, 0),
	})
	billboard.Parent = anchor
	cleanup(billboard)

	return Vide.create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	})
end)
