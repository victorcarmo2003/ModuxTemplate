--!strict
-- HintMark: THE marker of the world UI. One BillboardGui per mark, in studs, with three RECTANGULAR looks (user request 2026-10-12: no
-- circles or rings to say "click here" / "go here"; boxes with a spring that pops in, breathes and pops out):
--   Rect    a rounded frame (Mustard on an Ink rim) around the target: "this one", "tap here" (aim point, beacon, tutorial target).
--           `Fit` sizes it to a world box (the bounding box of the asset projected on the screen plane).
--   Check   a Green rounded square with a check (a ready sausage, a done step)
--   Bar     a short rectangular bar: a Cream fill (0..1, SetProgress) and/or a window with a Good band (Mustard), a Perfect band (Cream)
--           and a cursor (SetWindow, SetCursor): the flip window of the grill
-- Spring: every mark has a scale spring (under-damped, ~12% overshoot). Show pops it IN (grows past 1 and settles), Hide pops it OUT
-- (shrinks to nothing, then the gui is disabled), re-showing in the middle of a pop-out turns around from where it is. Rect and Check
-- breathe in a short loop (a second spring chasing a 1.0 / 1.07 square wave: a mechanical wobble). `Kick` punches the spring.
-- `HintMark.Step` is the same spring as a pure helper for other presentation code (the 3D guide arrow, Interface/Arrow3D; the 2D "Arrow" kind went 2026-10-14).
-- Reduced motion (Motion.Reduced): no overshoot, no breath, no pop (appears and disappears whole).
-- How it stays exactly on the asset at any resolution: the gui is `Adornee`d to an Attachment parented to Terrain that is moved to the
-- world point, its Size is in STUDS (UDim2 scale), AlwaysOnTop (seen through the awning), LightInfluence 0, parented to PlayerGui.
-- Nothing is sized in pixels but the rim thickness (a stroke is a line). One Heartbeat for all marks while any is visible.
-- Pure Roblox instances, no Modux, no Vide, no network. Create with `HintMark.new()`, call `Show` every frame you want it (cheap: only
-- changed values are written), `Hide` when not, `Destroy` at the end.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Icons = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Icons)
local Motion = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Motion)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)

export type Kind = "Rect" | "Check" | "Bar"

export type Spring = { X: number, V: number }

export type Mark = {
	-- Puts the mark on a world point with this look; `side` = its width in studs (default per look), `height` = its height (default:
	-- the width, or the bar height for Bar). Pops in when it was hidden. Cheap to call every frame.
	Show: (self: Mark, kind: Kind, position: Vector3, side: number?, height: number?) -> (),
	-- A Rect around a world box: the box (its CFrame and size) projected on the screen plane, plus `pad` studs all around.
	Fit: (self: Mark, box: CFrame, size: Vector3, pad: number?) -> (),
	-- Bar: 0..1 of the Cream fill.
	SetProgress: (self: Mark, value: number) -> (),
	-- Bar: the window, all in 0..1 of the bar width: `center` and the full widths of the Good and Perfect bands (0 = no band).
	SetWindow: (self: Mark, center: number, good: number, perfect: number) -> (),
	-- Bar: the cursor at 0..1 of the bar width (nil = no cursor).
	SetCursor: (self: Mark, value: number?) -> (),
	-- Colour of the Rect (default Mustard) and of the Bar fill (default Cream).
	SetColor: (self: Mark, color: Color3) -> (),
	-- Bar: colour and transparency of the track under the fill (default Ink, 0.2)
	SetTrack: (self: Mark, color: Color3, transparency: number) -> (),
	-- Pops in (true) or out (false) without moving it; Show / Hide are the usual way.
	Pop: (self: Mark, on: boolean) -> (),
	-- Punches the spring (a small knock that settles): `amount` ~ 4..8.
	Kick: (self: Mark, amount: number?) -> (),
	Hide: (self: Mark) -> (),
	IsShown: (self: Mark) -> boolean,
	Destroy: (self: Mark) -> (),
}

type Live = {
	Gui: BillboardGui,
	Anchor: Attachment,
	Body: Frame,
	Scale: UIScale,
	Kinds: { [string]: GuiObject },
	RectStroke: UIStroke,
	RectFill: Frame,
	BarFill: Frame,
	BarTrack: Frame,
	BarGood: Frame,
	BarPerfect: Frame,
	BarCursor: Frame,
	Shown: boolean, -- wanted
	Kind: Kind,
	Width: number,
	Height: number,
	Position: Vector3,
	Progress: number,
	Window: { number },
	Cursor: number?,
	Color: Color3?,
	Seed: number,
	Pop: Spring, -- the pop in / out
	Breath: Spring, -- the loop
}

const HintMark = {}

const SIDE: { [string]: number } = { Rect = 0.8, Check = 0.7, Bar = 1.2 }
const BAR_HEIGHT = 0.24 -- studs
const RIM = 6 -- px of the Ink rim of a Rect, 4 px of colour on top
const LINE = 4
const BAR_LINE = 2
const POP_OMEGA, POP_ZETA = 26, 0.55 -- in: ~12% overshoot
const OUT_OMEGA, OUT_ZETA = 30, 0.9 -- out: shrinks fast, no bounce
const BREATH_OMEGA, BREATH_ZETA = 18, 0.35
const BREATH_AMOUNT = 0.07
const BREATH_HZ = 0.9
const CHECK_ICON = "Ui/check"
const GONE = 0.03 -- the pop-out is over under this scale

local live: { Live } = {}
local connection: RBXScriptConnection? = nil
local reduced = false
local folder: Folder? = nil

-- One step of an under-damped spring (omega = rad/s, zeta = damping ratio), in small steps so any frame time is stable.
function HintMark.Step(spring: Spring, target: number, dt: number, omega: number, zeta: number)
	const steps = math.max(1, math.ceil(dt / 0.008))
	const h = dt / steps
	for _ = 1, steps do
		const acceleration = omega * omega * (target - spring.X) - 2 * zeta * omega * spring.V
		spring.V += acceleration * h
		spring.X += spring.V * h
	end
end

local function box(name: string, color: Color3, transparency: number, z: number): Frame
	const frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency
	frame.BorderSizePixel = 0
	frame.ZIndex = z
	return frame
end

local function corner(parent: Instance, scale: number)
	const rounding = Instance.new("UICorner")
	rounding.CornerRadius = UDim.new(scale, 0)
	rounding.Parent = parent
end

local function stroke(parent: Instance, thickness: number, color: Color3): UIStroke
	const line = Instance.new("UIStroke")
	line.Color = color
	line.Thickness = thickness
	line.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	line.Parent = parent
	return line
end

-- A hollow rounded rectangle: an empty frame with a stroke.
local function frame(name: string, thickness: number, color: Color3, radius: number): Frame
	const holder = Instance.new("Frame")
	holder.Name = name
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	corner(holder, radius)
	stroke(holder, thickness, color)
	return holder
end

local function applyColor(mark: Live)
	mark.RectStroke.Color = mark.Color or Theme.Color.Mustard
	mark.RectFill.BackgroundColor3 = mark.Color or Theme.Color.Mustard
	mark.BarFill.BackgroundColor3 = mark.Color or Theme.Color.Cream
end

local function applyProgress(mark: Live)
	mark.BarFill.Size = UDim2.fromScale(math.clamp(mark.Progress, 0, 1), 1)
	mark.BarFill.Visible = mark.Progress > 0.001
end

local function applyWindow(mark: Live)
	const center, good, perfect = mark.Window[1], mark.Window[2], mark.Window[3]
	mark.BarGood.Visible = good > 0
	mark.BarGood.Position = UDim2.fromScale(center, 0.5)
	mark.BarGood.Size = UDim2.fromScale(math.clamp(good, 0, 1), 1)
	mark.BarPerfect.Visible = perfect > 0
	mark.BarPerfect.Position = UDim2.fromScale(center, 0.5)
	mark.BarPerfect.Size = UDim2.fromScale(math.clamp(perfect, 0, 1), 1)
end

local function applyCursor(mark: Live)
	const value = mark.Cursor
	mark.BarCursor.Visible = value ~= nil
	if value ~= nil then
		mark.BarCursor.Position = UDim2.fromScale(math.clamp(value, 0, 1), 0.5)
	end
end

local function step(dt: number)
	dt = math.min(dt, 0.1)
	const clock = os.clock()
	local any = false
	for _, mark in live do
		if not mark.Gui.Enabled then
			continue
		end
		any = true
		local scale = 1
		if reduced then
			mark.Pop.X = if mark.Shown then 1 else 0
			mark.Pop.V = 0
		else
			if mark.Shown then
				HintMark.Step(mark.Pop, 1, dt, POP_OMEGA, POP_ZETA)
			else
				HintMark.Step(mark.Pop, 0, dt, OUT_OMEGA, OUT_ZETA)
			end
			-- the breath: a square wave 1.0 / 1.07 chased by a bouncy spring
			if mark.Kind == "Rect" or mark.Kind == "Check" then
				const high = math.sin((clock * BREATH_HZ + mark.Seed) * math.pi * 2) > 0
				HintMark.Step(mark.Breath, if high then 1 + BREATH_AMOUNT else 1, dt, BREATH_OMEGA, BREATH_ZETA)
				scale = mark.Breath.X
			end
		end
		if not mark.Shown and mark.Pop.X < GONE then
			mark.Gui.Enabled = false
			mark.Pop.X = 0
			mark.Pop.V = 0
			continue
		end
		mark.Scale.Scale = math.max(scale * mark.Pop.X, 0.01)
	end
	if not any and connection ~= nil then
		connection:Disconnect()
		connection = nil
	end
end

local function wake()
	if connection == nil then
		reduced = Motion.Reduced()
		connection = RunService.Heartbeat:Connect(step)
	end
end

local function build(): Live
	const player = Players.LocalPlayer
	const playerGui = player:WaitForChild("PlayerGui")
	local holder = folder
	if holder == nil or holder.Parent == nil then
		holder = Instance.new("Folder")
		holder.Name = "HintMarks"
		holder.Parent = playerGui
		folder = holder
	end

	const anchor = Instance.new("Attachment")
	anchor.Name = "HintMarkAnchor"
	anchor.Parent = workspace.Terrain

	const gui = Instance.new("BillboardGui")
	gui.Name = "HintMark"
	gui.Adornee = anchor
	gui.Size = UDim2.fromScale(SIDE.Rect, SIDE.Rect)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.ClipsDescendants = false
	gui.MaxDistance = 0

	const body = Instance.new("Frame")
	body.Name = "Body"
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.5)
	body.Size = UDim2.fromScale(1, 1)
	body.BackgroundTransparency = 1
	body.Parent = gui
	const scale = Instance.new("UIScale")
	scale.Parent = body

	const kinds: { [string]: GuiObject } = {}

	-- Rect: a faint Mustard fill, an Ink rim under a Mustard line, rounded corners
	const rect = Instance.new("Frame")
	rect.Name = "Rect"
	rect.Size = UDim2.fromScale(1, 1)
	rect.BackgroundTransparency = 1
	rect.Visible = false
	const rectFill = box("Fill", Theme.Color.Mustard, 0.86, 1)
	rectFill.Position = UDim2.fromScale(0.5, 0.5)
	rectFill.Size = UDim2.fromScale(1, 1)
	corner(rectFill, 0.16)
	rectFill.Parent = rect
	frame("Rim", RIM, Theme.Color.Ink, 0.16).Parent = rect
	const rectColor = frame("Color", LINE, Theme.Color.Mustard, 0.16)
	rectColor.ZIndex = 2
	rectColor.Parent = rect
	rect.Parent = body
	kinds.Rect = rect

	-- Bar: an Ink track, the Cream fill, the Good band (Mustard), the Perfect band (Cream) and the cursor (Ink with a Cream line)
	const bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.fromScale(1, 1)
	bar.BackgroundTransparency = 1
	bar.Visible = false
	const track = box("Track", Theme.Color.Ink, 0.2, 1)
	track.Position = UDim2.fromScale(0.5, 0.5)
	track.Size = UDim2.fromScale(1, 1)
	corner(track, 0.22)
	stroke(track, BAR_LINE, Theme.Color.Ink)
	track.Parent = bar
	const barFill = box("Fill", Theme.Color.Cream, 0, 2)
	barFill.AnchorPoint = Vector2.new(0, 0.5)
	barFill.Position = UDim2.fromScale(0, 0.5)
	barFill.Size = UDim2.fromScale(0, 1)
	corner(barFill, 0.22)
	barFill.Visible = false
	barFill.Parent = bar
	const barGood = box("Good", Theme.Color.Mustard, 0, 3)
	barGood.Visible = false
	corner(barGood, 0.15)
	barGood.Parent = bar
	const barPerfect = box("Perfect", Theme.Color.Cream, 0, 4)
	barPerfect.Visible = false
	stroke(barPerfect, BAR_LINE, Theme.Color.Ink)
	barPerfect.Parent = bar
	const barCursor = box("Cursor", Theme.Color.Ink, 0, 6)
	barCursor.Size = UDim2.new(0, 0, 1.7, 0)
	barCursor.Visible = false
	const cursorWidth = Instance.new("UIAspectRatioConstraint")
	cursorWidth.AspectRatio = 0.34
	cursorWidth.AspectType = Enum.AspectType.ScaleWithParentSize
	cursorWidth.DominantAxis = Enum.DominantAxis.Height
	cursorWidth.Parent = barCursor
	corner(barCursor, 0.2)
	stroke(barCursor, BAR_LINE, Theme.Color.Cream)
	barCursor.Parent = bar
	bar.Parent = body
	kinds.Bar = bar

	-- Check: a Green rounded square with the check of the UI sheet (a "V" glyph while the sheet is missing)
	const check = Instance.new("Frame")
	check.Name = "Check"
	check.Size = UDim2.fromScale(1, 1)
	check.BackgroundColor3 = Theme.Tone.Green.Bottom
	check.Visible = false
	corner(check, 0.22)
	stroke(check, 3, Theme.Color.Ink)
	const checkRect = Icons.Rect(CHECK_ICON)
	if checkRect ~= nil then
		const image = Instance.new("ImageLabel")
		image.Name = "Glyph"
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.Size = UDim2.fromScale(0.72, 0.72)
		image.BackgroundTransparency = 1
		image.Image = Icons.ImageOf(CHECK_ICON)
		image.ImageRectOffset = checkRect.Offset
		image.ImageRectSize = checkRect.Size
		image.Parent = check
	end
	check.Parent = body
	kinds.Check = check

	gui.Parent = holder
	const mark: Live = {
		Gui = gui,
		Anchor = anchor,
		Body = body,
		Scale = scale,
		Kinds = kinds,
		RectStroke = rectColor:FindFirstChildOfClass("UIStroke") :: UIStroke,
		RectFill = rectFill,
		BarFill = barFill,
		BarTrack = track,
		BarGood = barGood,
		BarPerfect = barPerfect,
		BarCursor = barCursor,
		Shown = false,
		Kind = "Rect",
		Width = SIDE.Rect,
		Height = SIDE.Rect,
		Position = Vector3.zero,
		Progress = 0,
		Window = { 0.5, 0, 0 },
		Cursor = nil,
		Color = nil,
		Seed = math.random(),
		Pop = { X = 0, V = 0 },
		Breath = { X = 1, V = 0 },
	}
	table.insert(live, mark)
	return mark
end

function HintMark.new(): Mark
	const state = build()
	const self = {} :: any

	local function setSize(width: number, height: number)
		if width ~= state.Width or height ~= state.Height then
			state.Width = width
			state.Height = height
			state.Gui.Size = UDim2.fromScale(width, height)
		end
	end

	local function popIn()
		if not state.Shown then
			state.Shown = true
			if not state.Gui.Enabled then
				state.Pop.X = 0
				state.Pop.V = 0
				state.Gui.Enabled = true
				state.Scale.Scale = 0.01
			end
			wake()
		end
	end

	function self.Show(_: any, kind: Kind, position: Vector3, side: number?, height: number?)
		const width = side or SIDE[kind]
		const tall = height or (if kind == "Bar" then math.min(BAR_HEIGHT, width) else width)
		if state.Kind ~= kind or not state.Kinds[kind].Visible then
			const changed = state.Kind ~= kind
			state.Kind = kind
			for name, object in state.Kinds do
				object.Visible = name == kind
			end
			-- a look that changes under a visible mark is a small knock, not a new pop
			if state.Shown and changed then
				state.Pop.V += 5
			end
		end
		setSize(width, tall)
		if position ~= state.Position then
			state.Position = position
			state.Anchor.WorldPosition = position
		end
		const fresh = not state.Shown
		popIn()
		if fresh then
			applyColor(state)
			applyProgress(state)
			applyWindow(state)
			applyCursor(state)
		end
	end

	function self.Fit(_: any, boxFrame: CFrame, size: Vector3, pad: number?)
		const camera = workspace.CurrentCamera
		local width, height = size.X, size.Y
		if camera ~= nil then
			const right, up = camera.CFrame.RightVector, camera.CFrame.UpVector
			const ax, ay, az = boxFrame.RightVector * size.X, boxFrame.UpVector * size.Y, boxFrame.LookVector * size.Z
			width = math.abs(right:Dot(ax)) + math.abs(right:Dot(ay)) + math.abs(right:Dot(az))
			height = math.abs(up:Dot(ax)) + math.abs(up:Dot(ay)) + math.abs(up:Dot(az))
		end
		const margin = (pad or 0.12) * 2
		self:Show("Rect", boxFrame.Position, math.max(width + margin, 0.5), math.max(height + margin, 0.5))
	end

	function self.SetProgress(_: any, value: number)
		if value ~= state.Progress then
			state.Progress = value
			applyProgress(state)
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

	function self.SetColor(_: any, color: Color3)
		if state.Color ~= color then
			state.Color = color
			applyColor(state)
		end
	end

	function self.SetTrack(_: any, color: Color3, transparency: number)
		state.BarTrack.BackgroundColor3 = color
		state.BarTrack.BackgroundTransparency = transparency
	end

	function self.Pop(_: any, on: boolean)
		if on then
			popIn()
		else
			self:Hide()
		end
	end

	function self.Kick(_: any, amount: number?)
		state.Pop.V += amount or 5
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

	function self.IsShown(_: any): boolean
		return state.Shown
	end

	function self.Destroy(_: any)
		state.Shown = false
		const index = table.find(live, state)
		if index ~= nil then
			table.remove(live, index)
		end
		state.Gui:Destroy()
		state.Anchor:Destroy()
	end

	return self :: Mark
end

return table.freeze(HintMark)
