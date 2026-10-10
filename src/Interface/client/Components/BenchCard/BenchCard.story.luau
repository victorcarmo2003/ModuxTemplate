--!strict
-- The card is a BillboardGui, so it is previewed in the 3D viewport: a temporary wall part 5 studs in front of the
-- Studio camera (removed when the story closes). Every mode of a GEAR WALL position is driven by the controls.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local BenchCard = require(script.Parent)

const create = Vide.create
const cleanup = Vide.cleanup

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Mode = UILabs.Choose({ "Buy", "NoCash", "Maxed", "Locked", "Empty" }),
		Title = "Double Grill",
		Detail = "3 spots · 10 s",
		Price = UILabs.Slider(60, 0, 500, 5),
		Icon = "",
		Special = false,
	},
}, function(props)
	const controls = props.controls

	const camera = workspace.CurrentCamera
	const anchor = Instance.new("Part")
	anchor.Name = "__BenchCardStory"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Size = Vector3.new(3, 0.2, 1)
	anchor.Color = Theme.Color.Teal
	anchor.CFrame = camera.CFrame * CFrame.new(0, -2, -5)
	anchor.Parent = workspace
	cleanup(anchor)

	local function mode(): BenchCard.Mode
		return controls.Mode() :: BenchCard.Mode
	end

	const billboard = BenchCard({
		Adornee = anchor,
		Visible = function()
			return true
		end,
		Mode = mode,
		Icon = function()
			return controls.Icon()
		end,
		Badge = function()
			return "G"
		end,
		Title = function()
			return if mode() == "Locked" then "Trailer Lights" else controls.Title()
		end,
		Detail = function()
			return controls.Detail()
		end,
		Tag = function()
			const m = mode()
			if m == "Maxed" then
				return "Maxed"
			elseif m == "Locked" then
				return "Trailer only"
			elseif m == "Empty" then
				return "Nothing special today"
			end
			return `${controls.Price()}`
		end,
		Special = function()
			return controls.Special()
		end,
		StudsOffset = Vector3.new(0, 1.9, 0),
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
		Text = "BenchCard: look at the part in front of the camera",
	})
end)
