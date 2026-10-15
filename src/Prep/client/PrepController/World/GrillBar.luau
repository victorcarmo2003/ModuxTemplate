--!strict
-- World/GrillBar: the bars over a roller of the 3D grill and the badge of a flip (TASK-280, owner request 2026-10-14: "the bar of
-- the minigame in the style of the settings panel"). Same toy set as the SettingsPanel / CartoonPanel: round corners, thick Ink
-- outline, the darker lip under every surface, two-tone vertical gradients with the white inner rim, Fredoka One, springs.
--   Cook     the cooking bar (TASK-257): an Ink pill with a sunk channel, a Green fill (0..1, SetProgress) and a Mustard pip at
--            the flip point (SetMark)
--   Timing   the flip window (TASK-257): the same pill, a Good band (Mustard), a Perfect band (Cream) and a Cream knob (the
--            cursor, like the knob of the settings slider) that swings end to end (SetWindow, SetCursor)
--   Badge    the answer of a flip (TASK-261): a tilted pill with the word ("Perfect!" Mustard, "Nice!" Cream, "Oops!" Slate) that
--            pops in, rises a little and pops out; an Ink chip with the Perfect run ("x3") on its corner
-- Bars are BillboardGuis sized in STUDS (they sit on the roller at any resolution); badges are sized in px x the global UI scale
-- (Theme.ScaleOf, readable like the HUD). Never red. Reduced motion (Motion.Reduced): no overshoot, no kick, no rise, no tilt.
-- Only presentation: what is drawn comes from the stage (the server's state and grade). Pure Roblox instances, no Modux, no Vide,
-- no network. One Heartbeat for every bar and badge while any is alive. `Clear` drops the badges (end of a visit).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local TextService = game:GetService("TextService")
local Motion = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Motion)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local HintMark = require(StarterPlayer.StarterPlayerScripts.client.Interface.HintMark)

export type Kind = "Cook" | "Timing"

export type Bar = {
	-- Puts the bar on a world point; `width` / `height` in studs. Pops in when it was hidden. Cheap to call every frame.
	Show: (self: Bar, kind: Kind, position: Vector3, width: number, height: number) -> (),
	-- Cook: 0..1 of the Green fill.
	SetProgress: (self: Bar, value: number) -> (),
	-- Cook: the Mustard pip at 0..1 of the bar (nil = none).
	SetMark: (self: Bar, value: number?) -> (),
	-- Timing: the window, all in 0..1 of the bar: `center` and the full widths of the Good and Perfect bands.
	SetWindow: (self: Bar, center: number, good: number, perfect: number) -> (),
	-- Timing: the knob at 0..1 of the bar (nil = no knob).
	SetCursor: (self: Bar, value: number?) -> (),
	-- Punches the spring (a small knock that settles): `amount` ~ 4..9.
	Kick: (self: Bar, amount: number?) -> (),
	Hide: (self: Bar) -> (),
	Destroy: (self: Bar) -> (),
}

type Surface = { Body: Frame, Face: Frame, Gradient: UIGradient }

type Live = {
	Gui: BillboardGui,
	Anchor: Attachment,
	Scale: UIScale,
	Fill: Frame,
	Pip: Frame,
	Good: Frame,
	Perfect: Frame,
	Knob: Frame,
	Shown: boolean,
	Kind: Kind,
	Width: number,
	Height: number,
	Position: Vector3,
	Progress: number,
	Mark: number?,
	Window: { number },
	Cursor: number?,
	Pop: HintMark.Spring,
}

type Badge = {
	Gui: BillboardGui,
	Anchor: Attachment,
	Scale: UIScale,
	From: Vector3,
	T: number,
	Time: number,
	Rise: number,
	Pop: HintMark.Spring,
}

const GrillBar = {}

const CHANNEL_INSET = 3 -- px between the Ink pill and its sunk channel
const BAR_LIP = 3 -- px of the lip under a bar (Theme.Lip is for HUD sized surfaces; a bar in studs is thinner)
const KNOB = 1.5 -- knob diameter in bar heights
const PIP_WIDTH = 0.045 -- share of the bar
const PIP_TALL = 1.35 -- bar heights
const POP_OMEGA, POP_ZETA = 26, 0.55 -- in: ~12% overshoot (the HintMark spring)
const OUT_OMEGA, OUT_ZETA = 30, 0.9 -- out: shrinks fast, no bounce
const GONE = 0.03
-- the badge of a flip, px at UI scale 1
const BADGE_TEXT: { [string]: number } = { Perfect = 26, Good = 22, Messy = 22 }
const BADGE_PAD_X = 16
const BADGE_HEIGHT = 40
const BADGE_TILT = 4 -- degrees, alternating
const BADGE_HOLD = 0.72 -- share of the time before it pops out
const CHIP_TEXT = 16

local bars: { Live } = {}
local badges: { Badge } = {}
local connection: RBXScriptConnection? = nil
local reduced = false
local folder: Folder? = nil
local tilt = 1

local function holder(): Folder
	local found = folder
	if found == nil or found.Parent == nil then
		found = Instance.new("Folder")
		found.Name = "GrillBars"
		found.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		folder = found
	end
	return found :: Folder
end

local function corner(parent: Instance, radius: UDim)
	const rounding = Instance.new("UICorner")
	rounding.CornerRadius = radius
	rounding.Parent = parent
end

local function stroke(parent: Instance, thickness: number, color: Color3, inner: boolean?): UIStroke
	const line = Instance.new("UIStroke")
	line.Color = color
	line.Thickness = thickness
	line.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	line.LineJoinMode = Enum.LineJoinMode.Round
	if inner then
		line.BorderStrokePosition = Enum.BorderStrokePosition.Inner
	end
	line.Parent = parent
	return line
end

local function frame(name: string, color: Color3, z: number): Frame
	const box = Instance.new("Frame")
	box.Name = name
	box.BackgroundColor3 = color
	box.BorderSizePixel = 0
	box.ZIndex = z
	return box
end

-- The cartoon surface (CartoonPanel in plain instances): the body is the Lip colour with the Ink outline, the face over it is the
-- two-tone gradient with the white inner rim, `lip` px shorter so the lip shows under it.
local function surface(name: string, tone: Theme.Tone, lip: number, outline: number, z: number, radius: UDim): Surface
	const body = frame(name, tone.Lip, z)
	corner(body, radius)
	if outline > 0 then
		stroke(body, outline, Theme.Color.Ink)
	end
	const face = frame("Face", Color3.new(1, 1, 1), z)
	face.Size = UDim2.new(1, 0, 1, -lip)
	corner(face, radius)
	const rim = stroke(face, Theme.Rim.Thickness, Color3.new(1, 1, 1), true)
	rim.Transparency = Theme.Rim.Transparency
	const gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = Theme.Gradient(tone)
	gradient.Parent = face
	face.Parent = body
	return { Body = body, Face = face, Gradient = gradient }
end

local function anchorAt(name: string): Attachment
	const anchor = Instance.new("Attachment")
	anchor.Name = name
	anchor.Parent = workspace.Terrain
	return anchor
end

local function billboard(name: string, anchor: Attachment): BillboardGui
	const gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Adornee = anchor
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.ClipsDescendants = false
	gui.MaxDistance = 0
	return gui
end

local function applyProgress(bar: Live)
	bar.Fill.Size = UDim2.fromScale(math.clamp(bar.Progress, 0, 1), 1)
	bar.Fill.Visible = bar.Kind == "Cook" and bar.Progress > 0.001
end

local function applyMark(bar: Live)
	const value = bar.Mark
	bar.Pip.Visible = bar.Kind == "Cook" and value ~= nil
	if value ~= nil then
		bar.Pip.Position = UDim2.fromScale(math.clamp(value, 0, 1), 0.5)
	end
end

local function applyWindow(bar: Live)
	const center, good, perfect = bar.Window[1], bar.Window[2], bar.Window[3]
	const timing = bar.Kind == "Timing"
	bar.Good.Visible = timing and good > 0
	bar.Good.Position = UDim2.fromScale(center, 0.5)
	bar.Good.Size = UDim2.fromScale(math.clamp(good, 0, 1), 1)
	bar.Perfect.Visible = timing and perfect > 0
	bar.Perfect.Position = UDim2.fromScale(center, 0.5)
	bar.Perfect.Size = UDim2.fromScale(math.clamp(perfect, 0, 1), 1)
end

local function applyCursor(bar: Live)
	const value = bar.Cursor
	bar.Knob.Visible = bar.Kind == "Timing" and value ~= nil
	if value ~= nil then
		bar.Knob.Position = UDim2.fromScale(math.clamp(value, 0, 1), 0.5)
	end
end

local function applyAll(bar: Live)
	applyProgress(bar)
	applyMark(bar)
	applyWindow(bar)
	applyCursor(bar)
end

local function step(dt: number)
	dt = math.min(dt, 0.1)
	for _, bar in bars do
		if not bar.Gui.Enabled then
			continue
		end
		if reduced then
			bar.Pop.X = if bar.Shown then 1 else 0
			bar.Pop.V = 0
		elseif bar.Shown then
			HintMark.Step(bar.Pop, 1, dt, POP_OMEGA, POP_ZETA)
		else
			HintMark.Step(bar.Pop, 0, dt, OUT_OMEGA, OUT_ZETA)
		end
		if not bar.Shown and bar.Pop.X < GONE then
			bar.Gui.Enabled = false
			bar.Pop.X = 0
			bar.Pop.V = 0
			continue
		end
		bar.Scale.Scale = math.max(bar.Pop.X, 0.01)
	end
	for index = #badges, 1, -1 do
		const badge = badges[index]
		badge.T += dt
		const t = math.clamp(badge.T / badge.Time, 0, 1)
		const leaving = t >= BADGE_HOLD
		if reduced then
			badge.Pop.X = if leaving then 0 else 1
			badge.Pop.V = 0
		elseif leaving then
			HintMark.Step(badge.Pop, 0, dt, OUT_OMEGA, OUT_ZETA)
		else
			HintMark.Step(badge.Pop, 1, dt, POP_OMEGA, POP_ZETA)
		end
		-- rises fast, then floats (ease out)
		badge.Anchor.WorldPosition = badge.From + Vector3.new(0, badge.Rise * (1 - (1 - t) * (1 - t)), 0)
		badge.Scale.Scale = math.max(badge.Pop.X, 0.01)
		if t >= 1 or (leaving and badge.Pop.X < GONE) then
			badge.Gui:Destroy()
			badge.Anchor:Destroy()
			table.remove(badges, index)
		end
	end
	if #badges == 0 then
		local any = false
		for _, bar in bars do
			if bar.Gui.Enabled then
				any = true
				break
			end
		end
		if not any and connection ~= nil then
			connection:Disconnect()
			connection = nil
		end
	end
end

local function wake()
	if connection == nil then
		reduced = Motion.Reduced()
		connection = RunService.Heartbeat:Connect(step)
	end
end

local function build(): Live
	const anchor = anchorAt("GrillBarAnchor")
	const gui = billboard("GrillBar", anchor)
	gui.Enabled = false

	const root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = gui
	const scale = Instance.new("UIScale")
	scale.Parent = root

	-- the Ink pill (a HUD pill of the kit) and its sunk channel, where the fill and the bands live
	const pill = surface("Pill", Theme.Tone.Ink, BAR_LIP, Theme.Outline.Normal, 1, Theme.Radius.Pill)
	pill.Body.AnchorPoint = Vector2.new(0.5, 0.5)
	pill.Body.Position = UDim2.fromScale(0.5, 0.5)
	pill.Body.Size = UDim2.fromScale(1, 1)
	pill.Body.Parent = root
	const channel = frame("Channel", Theme.Tone.Ink.Lip, 2)
	channel.AnchorPoint = Vector2.new(0.5, 0.5)
	channel.Position = UDim2.fromScale(0.5, 0.5)
	channel.Size = UDim2.new(1, -CHANNEL_INSET * 2, 1, -CHANNEL_INSET * 2)
	channel.ClipsDescendants = false
	corner(channel, Theme.Radius.Pill)
	channel.Parent = pill.Face

	-- Cook: the Green fill from the left (its own lip and rim: the fill is a surface too)
	const fill = surface("Fill", Theme.Tone.Green, 2, 0, 3, Theme.Radius.Pill)
	fill.Body.AnchorPoint = Vector2.new(0, 0.5)
	fill.Body.Position = UDim2.fromScale(0, 0.5)
	fill.Body.Size = UDim2.fromScale(0, 1)
	fill.Body.Visible = false
	fill.Body.Parent = channel

	-- Cook: the Mustard pip where the flip comes, standing out of the pill
	const pip = surface("Pip", Theme.Tone.Mustard, 2, Theme.Outline.Thin, 5, Theme.Radius.Pill)
	pip.Body.AnchorPoint = Vector2.new(0.5, 0.5)
	pip.Body.Size = UDim2.fromScale(PIP_WIDTH, PIP_TALL)
	pip.Body.Visible = false
	pip.Body.Parent = channel

	-- Timing: the Good band (Mustard) and the Perfect band (Cream, an Ink line around it) in the middle
	const good = surface("Good", Theme.Tone.Mustard, 2, 0, 3, Theme.Radius.Pill)
	good.Body.AnchorPoint = Vector2.new(0.5, 0.5)
	good.Body.Visible = false
	good.Body.Parent = channel
	const perfect = surface("Perfect", Theme.Tone.Cream, 2, Theme.Outline.Thin, 4, Theme.Radius.Pill)
	perfect.Body.AnchorPoint = Vector2.new(0.5, 0.5)
	perfect.Body.Visible = false
	perfect.Body.Parent = channel

	-- Timing: the knob of the settings slider (Cream, round, Ink outline), a bit taller than the bar
	const knob = surface("Knob", Theme.Tone.White, 2, Theme.Outline.Normal, 6, UDim.new(0.5, 0))
	knob.Body.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Body.Size = UDim2.fromScale(0, KNOB)
	knob.Body.Visible = false
	const round = Instance.new("UIAspectRatioConstraint")
	round.AspectRatio = 1
	round.AspectType = Enum.AspectType.ScaleWithParentSize
	round.DominantAxis = Enum.DominantAxis.Height
	round.Parent = knob.Body
	knob.Body.Parent = channel

	gui.Parent = holder()
	const bar: Live = {
		Gui = gui,
		Anchor = anchor,
		Scale = scale,
		Fill = fill.Body,
		Pip = pip.Body,
		Good = good.Body,
		Perfect = perfect.Body,
		Knob = knob.Body,
		Shown = false,
		Kind = "Cook",
		Width = 0,
		Height = 0,
		Position = Vector3.zero,
		Progress = 0,
		Mark = nil,
		Window = { 0.5, 0, 0 },
		Cursor = nil,
		Pop = { X = 0, V = 0 },
	}
	table.insert(bars, bar)
	return bar
end

function GrillBar.new(): Bar
	const state = build()
	const self = {} :: any

	function self.Show(_: any, kind: Kind, position: Vector3, width: number, height: number)
		if kind ~= state.Kind then
			state.Kind = kind
			applyAll(state)
			if state.Shown and not reduced then
				state.Pop.V += 5
			end
		end
		if width ~= state.Width or height ~= state.Height then
			state.Width, state.Height = width, height
			state.Gui.Size = UDim2.fromScale(width, height)
		end
		if position ~= state.Position then
			state.Position = position
			state.Anchor.WorldPosition = position
		end
		if not state.Shown then
			state.Shown = true
			if not state.Gui.Enabled then
				state.Pop.X = 0
				state.Pop.V = 0
				state.Scale.Scale = 0.01
				applyAll(state)
				state.Gui.Enabled = true
			end
			wake()
		end
	end

	function self.SetProgress(_: any, value: number)
		if value ~= state.Progress then
			state.Progress = value
			applyProgress(state)
		end
	end

	function self.SetMark(_: any, value: number?)
		if value ~= state.Mark then
			state.Mark = value
			applyMark(state)
		end
	end

	function self.SetWindow(_: any, center: number, good: number, perfect: number)
		const window = state.Window
		if window[1] ~= center or window[2] ~= good or window[3] ~= perfect then
			window[1], window[2], window[3] = center, good, perfect
			applyWindow(state)
		end
	end

	function self.SetCursor(_: any, value: number?)
		if value ~= state.Cursor then
			state.Cursor = value
			applyCursor(state)
		end
	end

	function self.Kick(_: any, amount: number?)
		if not reduced and state.Shown then
			state.Pop.V += amount or 5
		end
	end

	function self.Hide(_: any)
		if state.Shown then
			state.Shown = false
			if reduced or not state.Gui.Enabled then
				state.Gui.Enabled = false
			else
				wake()
			end
		end
	end

	function self.Destroy(_: any)
		state.Shown = false
		const index = table.find(bars, state)
		if index ~= nil then
			table.remove(bars, index)
		end
		state.Gui:Destroy()
		state.Anchor:Destroy()
	end

	return self :: Bar
end

local function textWidth(text: string, size: number): number
	const ok, bounds = pcall(function(): Vector2
		return TextService:GetTextSize(text, size, Enum.Font.FredokaOne, Vector2.new(1000, 200))
	end)
	return if ok then bounds.X else #text * size * 0.6
end

local function word(name: string, text: string, size: number, tone: Theme.Tone, z: number): TextLabel
	const label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = Theme.Font.Title
	label.TextSize = size
	label.Text = text
	label.TextColor3 = tone.Text
	label.ZIndex = z
	if tone.Stroke then
		const line = Instance.new("UIStroke")
		line.Color = Theme.Color.Ink
		line.Thickness = Theme.TextStroke(size)
		line.LineJoinMode = Enum.LineJoinMode.Round
		line.Parent = label
	end
	return label
end

-- The answer of a flip over the sausage: `band` = Perfect | Good | Messy (the server's), `text` = the word, `run` = Perfects in a
-- row to show on the corner chip (nil = none), `rise` / `time` = studs and seconds (Content PrepWorld Juice.Float).
function GrillBar.Badge(band: string, text: string, at: Vector3, run: string?, rise: number, time: number)
	wake()
	const tone = if band == "Perfect" then Theme.Tone.Mustard elseif band == "Good" then Theme.Tone.Cream else Theme.Tone.Slate
	-- the px layout follows the global UI scale, like the HUD (the UIScale only carries the pop)
	const camera = workspace.CurrentCamera
	const ui = Theme.ScaleOf(if camera ~= nil then camera.ViewportSize else Vector2.new(1920, 1080), nil)
	const size = math.floor((BADGE_TEXT[band] or BADGE_TEXT.Good) * ui + 0.5)
	const width = textWidth(text, size) + BADGE_PAD_X * 2 * ui
	const height = (BADGE_HEIGHT + (if band == "Perfect" then 4 else 0)) * ui

	const anchor = anchorAt("GrillBadgeAnchor")
	anchor.WorldPosition = at
	const gui = billboard("GrillBadge", anchor)
	-- room for the overshoot, the tilt and the chip
	gui.Size = UDim2.fromOffset((width + 48 * ui) * 1.3, (height + 32 * ui) * 1.3)

	const root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(width, height)
	root.BackgroundTransparency = 1
	root.Rotation = if reduced then 0 else BADGE_TILT * tilt
	root.Parent = gui
	tilt = -tilt
	const scale = Instance.new("UIScale")
	scale.Scale = if reduced then 1 else 0.01
	scale.Parent = root

	const pill = surface("Pill", tone, Theme.Lip, Theme.Outline.Thick, 1, Theme.Radius.Pill)
	pill.Body.Size = UDim2.fromScale(1, 1)
	pill.Body.Parent = root
	word("Word", text, size, tone, 2).Parent = pill.Face

	if run ~= nil then
		const chipText = math.floor(CHIP_TEXT * ui + 0.5)
		const chip = surface("Run", Theme.Tone.Ink, 2, Theme.Outline.Normal, 3, Theme.Radius.Pill)
		chip.Body.AnchorPoint = Vector2.new(0.5, 0.5)
		chip.Body.Position = UDim2.new(1, -4 * ui, 0, 2 * ui)
		chip.Body.Size = UDim2.fromOffset(textWidth(run, chipText) + 16 * ui, 26 * ui)
		chip.Body.Rotation = 8
		const label = word("Run", run, chipText, Theme.Tone.Ink, 4)
		label.TextColor3 = Theme.Color.Mustard
		label.Parent = chip.Face
		chip.Body.Parent = root
	end

	gui.Parent = holder()
	table.insert(badges, {
		Gui = gui,
		Anchor = anchor,
		Scale = scale,
		From = at,
		T = 0,
		Time = time,
		Rise = if reduced then 0 else rise,
		Pop = { X = if reduced then 1 else 0, V = 0 },
	})
end

-- Drops every badge still flying (the end of a visit); bars go with their own Destroy.
function GrillBar.Clear()
	for _, badge in badges do
		badge.Gui:Destroy()
		badge.Anchor:Destroy()
	end
	table.clear(badges)
end

return table.freeze(GrillBar)
