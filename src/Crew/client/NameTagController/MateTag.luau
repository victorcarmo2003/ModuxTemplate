--!strict
-- The name tag card of a crewmate (cream card, a chip and a stroke in his CrewColor) and the low-quality test. Moved here from
-- the focused prep's Mates (TASK-581); numbers Provisional, as they were there.
local StarterPlayer = game:GetService("StarterPlayer")
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)

const TAG = { Width = 4.4, Height = 1.0, Lift = 1.1 } -- studs
const RANGE = 60 -- studs: the name tag fades out beyond it
const LOW_QUALITY = 3 -- SavedQualityLevel at or under which no Highlight is drawn

const MateTag = {}

-- The tag of a crewmate, `adornee` = what it floats over
function MateTag.Tag(text: string, color: Color3, adornee: Instance, parent: Instance): BillboardGui
	const gui = Instance.new("BillboardGui")
	gui.Name = "MateTag"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Active = false
	gui.Size = UDim2.fromScale(TAG.Width, TAG.Height) -- scale = studs
	gui.StudsOffsetWorldSpace = Vector3.new(0, TAG.Lift, 0)
	gui.MaxDistance = RANGE
	gui.Adornee = adornee
	const card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Theme.Color.Cream
	card.BorderSizePixel = 0
	card.Parent = gui
	const corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = card
	const stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 3
	stroke.Parent = card
	const chip = Instance.new("Frame")
	chip.Name = "Chip"
	chip.AnchorPoint = Vector2.new(0, 0.5)
	chip.Position = UDim2.fromScale(0.05, 0.5)
	chip.Size = UDim2.fromScale(0.16, 0.56)
	chip.SizeConstraint = Enum.SizeConstraint.RelativeYY
	chip.BackgroundColor3 = color
	chip.BorderSizePixel = 0
	chip.Parent = card
	const chipCorner = Instance.new("UICorner")
	chipCorner.CornerRadius = UDim.new(1, 0)
	chipCorner.Parent = chip
	const chipStroke = Instance.new("UIStroke")
	chipStroke.Color = Theme.Color.Ink
	chipStroke.Thickness = 2
	chipStroke.Parent = chip
	const label = Instance.new("TextLabel")
	label.Name = "Name"
	label.AnchorPoint = Vector2.new(1, 0.5)
	label.Position = UDim2.fromScale(0.96, 0.5)
	label.Size = UDim2.fromScale(0.68, 0.7)
	label.BackgroundTransparency = 1
	label.FontFace = Theme.Font.Title
	label.Text = text
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Theme.Color.Ink
	label.Parent = card
	gui.Parent = parent
	return gui
end

-- Graphics quality at or under LOW_QUALITY (no Highlight there)
function MateTag.LowQuality(): boolean
	const ok, saved = pcall(function(): any
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	if not ok then
		return false
	end
	const value = (saved :: Enum.SavedQualitySetting).Value
	return value ~= 0 and value <= LOW_QUALITY
end

return table.freeze(MateTag)
