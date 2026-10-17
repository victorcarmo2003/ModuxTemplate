--!strict
-- GemCollect: the "you collected gems" moment over the Anomaly Tablet (owner request 2026-10-17, Provisional). A burst of
-- gem icons (AST-071 `Hud/gem`) pops out of the page in the middle of the screen, hangs for a beat and flies one by one
-- into a "+N" gem pill at the top; every gem that lands bumps the pill and rolls its number, the last one settles it on
-- the full amount. Then the pill holds and fades. Reduced motion (Motion.Reduced): no burst, the pill pops with the total.
-- Pure Roblox instances, no Modux, no Vide, no network (tweens, like PurchaseFxController): JournalController calls
-- Play with the amount and plays the sounds from the callbacks.
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local Motion = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Motion)
local Icons = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Icons)

export type Options = {
	Amount: number,
	-- each gem that reaches the pill (index 1..count)
	OnLand: ((index: number, count: number) -> ())?,
	-- the last gem landed (the pill shows the full amount)
	OnDone: (() -> ())?,
}

const GEM = "Hud/gem"
const COUNT = 10 -- gems in the burst
const DISPLAY_ORDER = 25 -- over the tablet window (20)
const BURST = 0.38 -- s of the pop out of the page
const HANG = 0.25 -- s the burst floats before the first gem flies
const STAGGER = 0.07 -- s between two gems leaving
const FLY = 0.42 -- s of one gem's flight
const HOLD = 1.3 -- s the pill stays after the last gem
const FADE = 0.4
const PILL_Y = 0.14 -- scale of the screen height (top, under the HUD clock)

local function tween(instance: Instance, time: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	const made = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	made:Play()
	return made
end

local function gemImage(parent: Instance, size: number): ImageLabel
	const image = Instance.new("ImageLabel")
	image.Name = "Gem"
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Size = UDim2.fromOffset(size, size)
	image.BackgroundTransparency = 1
	image.Image = Icons.ImageOf(GEM)
	const rect = Icons.Rect(GEM)
	if rect then
		image.ImageRectOffset = rect.Offset
		image.ImageRectSize = rect.Size
	end
	image.Parent = parent
	return image
end

-- The "+N" pill: Ink rounded plate, Mustard outline, gem icon + white number.
local function pill(parent: Instance, unit: number): (Frame, TextLabel, UIScale)
	const frame = Instance.new("Frame")
	frame.Name = "Pill"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, PILL_Y)
	frame.Size = UDim2.fromOffset(unit * 3.6, unit * 1.3)
	frame.BackgroundColor3 = Theme.Tone.Ink.Bottom
	frame.Parent = parent
	const corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	const stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Color.Mustard
	stroke.Thickness = math.max(2, unit * 0.09)
	stroke.Parent = frame
	const scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = frame

	const icon = gemImage(frame, unit * 1.15)
	icon.Position = UDim2.new(0, unit * 0.75, 0.5, 0)

	const label = Instance.new("TextLabel")
	label.Name = "Amount"
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, unit * 1.45, 0.5, 0)
	label.Size = UDim2.new(1, -unit * 1.65, 0.8, 0)
	label.BackgroundTransparency = 1
	label.FontFace = Theme.Font.Title
	label.TextScaled = true
	label.TextColor3 = Theme.Color.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = "+0"
	label.Parent = frame
	const textStroke = Instance.new("UIStroke")
	textStroke.Color = Theme.Color.Ink
	textStroke.Thickness = math.max(2, unit * 0.07)
	textStroke.Parent = label
	return frame, label, scale
end

const GemCollect = {}

-- Plays the collect once; the ScreenGui destroys itself at the end.
function GemCollect.Play(options: Options)
	const playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	const camera = workspace.CurrentCamera
	if playerGui == nil or camera == nil then
		return
	end
	const viewport = camera.ViewportSize
	const unit = math.clamp(math.min(viewport.X, viewport.Y) * 0.06, 28, 64) -- px of one gem
	const reduced = Motion.Reduced()
	const amount = options.Amount

	const gui = Instance.new("ScreenGui")
	gui.Name = "GemCollect"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = DISPLAY_ORDER
	gui.Parent = playerGui

	const frame, label, scale = pill(gui, unit)
	tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)

	local function finish()
		label.Text = `+{amount}`
		if options.OnDone then
			options.OnDone()
		end
		task.delay(HOLD, function()
			tween(scale, FADE, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			task.delay(FADE + 0.1, function()
				gui:Destroy()
			end)
		end)
	end

	if reduced then
		task.delay(0.3, finish)
		return
	end

	const target = Vector2.new(viewport.X * 0.5 - frame.Size.X.Offset * 0.5 + unit * 0.75, viewport.Y * PILL_Y)
	const center = viewport * 0.5
	local landed = 0
	for index = 1, COUNT do
		const gem = gemImage(gui, unit)
		gem.Position = UDim2.fromOffset(center.X, center.Y)
		gem.Rotation = math.random(-25, 25)
		const gemScale = Instance.new("UIScale")
		gemScale.Scale = 0.2
		gemScale.Parent = gem

		-- pop out of the page: a ring with some jitter
		const angle = (index / COUNT) * math.pi * 2 + math.random() * 0.5
		const radius = unit * (2 + math.random() * 1.6)
		const out = center + Vector2.new(math.cos(angle), math.sin(angle)) * radius
		tween(gem, BURST, { Position = UDim2.fromOffset(out.X, out.Y), Rotation = math.random(-15, 15) }, Enum.EasingStyle.Back)
		tween(gemScale, BURST, { Scale = 1 }, Enum.EasingStyle.Back)

		-- then into the pill, one after the other
		task.delay(BURST + HANG + (index - 1) * STAGGER, function()
			tween(gem, FLY, { Position = UDim2.fromOffset(target.X, target.Y), Rotation = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween(gemScale, FLY, { Scale = 0.55 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(FLY, function()
				gem:Destroy()
				landed += 1
				label.Text = `+{math.floor(amount * landed / COUNT)}`
				scale.Scale = 1.18
				tween(scale, 0.18, { Scale = 1 })
				if options.OnLand then
					options.OnLand(landed, COUNT)
				end
				if landed == COUNT then
					finish()
				end
			end)
		end)
	end
end

return table.freeze(GemCollect)
