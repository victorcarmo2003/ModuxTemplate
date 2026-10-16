--!strict
--[[
	Whispers on screen (TASK-339, owner request 2026-10-15): the sign of the SILENT family B monster. Dozens of
	"hide" / "hide..." / "HIDE" words in a creepy font pop in along two arcs at the lower corners of the screen, drip
	slowly down and fade out (~0.5-1 s each). No sound: the screen is the only warning.

	Play(seconds) spawns them for `seconds` (one ScreenGui, destroyed at the end). Reduced motion (Motion.Reduced):
	no pop and no drip, the words only fade in and out where they appear.
	Colours from the house palette (cream with an ink stroke, a few mustard): never alert red (style-guide).
]]
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Motion = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Motion)

-- owner request 2026-10-16: more words, more often; "hide" stays the most common (listed several times)
const WORDS = {
	"hide",
	"hide",
	"hide...",
	"hide…",
	"HIDE",
	"HIDE",
	"hide!",
	"hide now",
	"get behind it",
	"behind the trailer",
	"it's coming",
	"it sees you",
	"don't let it see you",
	"go. go.",
	"shhh",
	"out back",
}
const FONT = Enum.Font.Creepster
const CREAM = Color3.fromHex("#FFF1D6")
const MUSTARD = Color3.fromHex("#F6C12B")
const INK = Color3.fromHex("#2B2233")
const RATE = 16 -- words per second (was 9; owner 2026-10-16)
const LIFE = { 0.5, 1 } -- s each word stays
const SIZE = { 20, 46 } -- px text size
const DRIP = { 18, 46 } -- px it slides down over its life
const TILT = 14 -- degrees of random rotation
-- arc of each lower corner: centre at the corner, radius in screen-height share, angles from the vertical
const ARC_RADIUS = { 0.18, 0.34 }
const ARC_ANGLE = { 8, 82 } -- degrees: 0 = straight up from the corner, 90 = along the bottom edge
const POP = 0.14 -- s of the pop

const Whispers = {}

local function between(rng: Random, range: { number }): number
	return range[1] + (range[2] - range[1]) * rng:NextNumber()
end

local function spawnWord(gui: ScreenGui, rng: Random, reduced: boolean)
	const viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	const left = rng:NextNumber() < 0.5
	const radius = between(rng, ARC_RADIUS) * viewport.Y
	const angle = math.rad(between(rng, ARC_ANGLE))
	-- from the corner: up by cos, inwards by sin
	const x = math.sin(angle) * radius
	const y = math.cos(angle) * radius
	const px = if left then x else viewport.X - x
	const py = viewport.Y - y
	const size = math.floor(between(rng, SIZE))
	const life = between(rng, LIFE)
	const label = Instance.new("TextLabel")
	label.Name = "Whisper"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromOffset(px, py)
	const word = WORDS[rng:NextInteger(1, #WORDS)]
	label.Size = UDim2.fromOffset(math.ceil(size * math.max(5, #word * 0.62)), size + 8) -- long phrases fit
	label.Font = FONT
	label.Text = word
	label.TextSize = size
	label.TextColor3 = if rng:NextNumber() < 0.2 then MUSTARD else CREAM
	label.TextStrokeColor3 = INK
	label.TextStrokeTransparency = 0.25
	label.TextTransparency = 1
	label.Rotation = (rng:NextNumber() * 2 - 1) * TILT
	const scale = Instance.new("UIScale")
	scale.Scale = if reduced then 1 else 0.2
	scale.Parent = label
	label.Parent = gui
	const fadeIn = TweenInfo.new(if reduced then life * 0.3 else POP, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(label, fadeIn, { TextTransparency = 0.1, TextStrokeTransparency = 0.25 }):Play()
	if not reduced then
		TweenService:Create(scale, TweenInfo.new(POP, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService
			:Create(label, TweenInfo.new(life, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
				Position = UDim2.fromOffset(px, py + between(rng, DRIP)),
			})
			:Play()
	end
	task.delay(life * 0.55, function()
		if label.Parent == nil then
			return
		end
		TweenService:Create(label, TweenInfo.new(life * 0.45), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	task.delay(life + 0.05, function()
		label:Destroy()
	end)
end

-- Words for `seconds` (yields until done).
function Whispers.Play(seconds: number)
	const playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil or seconds <= 0 then
		return
	end
	const gui = Instance.new("ScreenGui")
	gui.Name = "HideWhispers"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 45
	gui.Parent = playerGui
	const rng = Random.new()
	const reduced = Motion.Reduced()
	const untilAt = os.clock() + seconds
	-- a slow start, thicker towards the end
	while os.clock() < untilAt and gui.Parent ~= nil do
		const t = 1 - (untilAt - os.clock()) / seconds
		spawnWord(gui, rng, reduced)
		task.wait(1 / (RATE * (0.5 + t)))
	end
	task.wait(LIFE[2] + 0.1)
	gui:Destroy()
end

return table.freeze(Whispers)
