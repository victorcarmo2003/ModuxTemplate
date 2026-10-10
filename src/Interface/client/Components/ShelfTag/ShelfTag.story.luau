--!strict
-- The tag is a BillboardGui, so it is previewed in the 3D viewport: a temporary part 6 studs in front of the
-- Studio camera (removed when the story closes). Drive the three looks from the controls.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local ShelfTag = require(script.Parent)

const create = Vide.create
const cleanup = Vide.cleanup

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Mode = UILabs.Choose({ "Price", "NoCash", "OutOfStock" }),
		Price = UILabs.Slider(6, 1, 99, 1),
		UnlockDay = UILabs.Slider(3, 0, 10, 1),
	},
}, function(props)
	const controls = props.controls

	const camera = workspace.CurrentCamera
	const anchor = Instance.new("Part")
	anchor.Name = "__ShelfTagStory"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Size = Vector3.new(2, 0.2, 1)
	anchor.Color = Theme.Color.Teal
	anchor.CFrame = camera.CFrame * CFrame.new(0, -1, -6)
	anchor.Parent = workspace
	cleanup(anchor)

	local function mode(): ShelfTag.Mode
		return controls.Mode() :: ShelfTag.Mode
	end

	const billboard = ShelfTag({
		Adornee = anchor,
		Visible = function()
			return true
		end,
		Mode = mode,
		Text = function()
			return if mode() == "OutOfStock" then "Out of stock" else `${controls.Price()}`
		end,
		SubText = function()
			const day = controls.UnlockDay()
			return if day > 0 then `Day {day}` else ""
		end,
		StudsOffset = Vector3.new(0, 0.8, 0),
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
		Text = "ShelfTag: look at the part in front of the camera",
	})
end)
