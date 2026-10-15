--!strict
-- DeliverMark: the drop zone over a customer while a hot dog can be delivered. Owner playtest 2026-10-14 (TASK-259, Provisional):
-- only a subtle rounded rectangle OUTLINE around the customer, Green with a faint Ink shadow line under it; no text, no stripes,
-- no fill. Same springs as HintMark: it pops in with a small overshoot, breathes softly while shown (scale and line alpha), punches
-- (Kick); while a hot dog is dragged over it (`SetHot`) the line gets thicker and brighter. Sized in STUDS (a BillboardGui adorned
-- to an Attachment under Terrain), AlwaysOnTop, never Active (README: no clickable UI under the first-person cursor).
-- Reduced motion (Motion.Reduced): no overshoot, no breath, no pop.
-- Pure Roblox instances, no Modux, no Vide, no network: DeliveryController (world) and the prep Toppings view use it.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local HintMark = require(StarterPlayer.StarterPlayerScripts.client.Interface.HintMark)
local Motion = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Motion)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)

export type Mark = {
	-- Shows the mark centred on `position` (world), `width` studs wide; `height` studs tall (default width * ASPECT; a taller one
	-- is the delivery AREA over a customer's body, TASK-253). Cheap every frame.
	Show: (self: Mark, position: Vector3, width: number?, height: number?) -> (),
	-- A hot dog is held over the zone: a thicker, brighter line and a bigger breath
	SetHot: (self: Mark, hot: boolean) -> (),
	Kick: (self: Mark, amount: number?) -> (),
	Hide: (self: Mark) -> (),
	IsShown: (self: Mark) -> boolean,
	Destroy: (self: Mark) -> (),
}

const WIDTH = 2.6 -- studs
const ASPECT = 0.42 -- height / width
const RADIUS = 0.18 -- corner, of the short side
const LINE = 2.5 -- px Green line
const LINE_HOT = 4.5
const SHADOW = 2 -- px of faint Ink under the Green line (reads on bright backgrounds)
const ALPHA = 0.3 -- line transparency at rest (it breathes from here to ALPHA_LOW)
const ALPHA_LOW = 0.5
const ALPHA_HOT = 0
const SHADOW_ALPHA = 0.75
const POP_OMEGA, POP_ZETA = 26, 0.55
const OUT_OMEGA, OUT_ZETA = 30, 0.9
const BREATH_OMEGA, BREATH_ZETA = 18, 0.6
const BREATH_AMOUNT = 0.02
const HOT_AMOUNT = 0.05
const BREATH_HZ = 0.8
const GONE = 0.03

type Live = {
	Gui: BillboardGui,
	Anchor: Attachment,
	Scale: UIScale,
	Line: UIStroke,
	Shadow: UIStroke,
	Shown: boolean,
	Hot: boolean,
	Width: number,
	Height: number,
	Position: Vector3,
	Pop: HintMark.Spring,
	Breath: HintMark.Spring,
}

const DeliverMark = {}

local live: { Live } = {}
local connection: RBXScriptConnection? = nil
local reduced = false
local folder: Folder? = nil

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
		-- 0..1 of the breath: the line fades a little on the low side (never at rest under reduced motion)
		local wave = 0
		if reduced then
			mark.Pop.X = if mark.Shown then 1 else 0
			mark.Pop.V = 0
		else
			HintMark.Step(mark.Pop, if mark.Shown then 1 else 0, dt, if mark.Shown then POP_OMEGA else OUT_OMEGA, if mark.Shown then POP_ZETA else OUT_ZETA)
			const amount = if mark.Hot then HOT_AMOUNT else BREATH_AMOUNT
			const high = math.sin(clock * BREATH_HZ * math.pi * 2) > 0
			HintMark.Step(mark.Breath, if high then 1 + amount else 1, dt, BREATH_OMEGA, BREATH_ZETA)
			scale = mark.Breath.X
			wave = (math.sin(clock * BREATH_HZ * math.pi * 2) + 1) / 2
		end
		if not mark.Shown and mark.Pop.X < GONE then
			mark.Gui.Enabled = false
			mark.Pop.X = 0
			mark.Pop.V = 0
			continue
		end
		mark.Scale.Scale = math.max(scale * mark.Pop.X, 0.01)
		mark.Line.Transparency = if mark.Hot then ALPHA_HOT else ALPHA + (ALPHA_LOW - ALPHA) * wave
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

-- the corner follows the short side: a UICorner in scale is of the SHORT side already, so one value fits any aspect
local function corner(parent: Instance)
	const rounding = Instance.new("UICorner")
	rounding.CornerRadius = UDim.new(RADIUS, 0)
	rounding.Parent = parent
end

local function stroke(parent: Instance, thickness: number, color: Color3, transparency: number): UIStroke
	const line = Instance.new("UIStroke")
	line.Color = color
	line.Thickness = thickness
	line.Transparency = transparency
	line.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	line.LineJoinMode = Enum.LineJoinMode.Round
	line.Parent = parent
	return line
end

-- the line of the hot / cold state (the breath only moves the transparency of the cold one, in `step`)
local function paint(mark: Live)
	const hot = mark.Hot
	mark.Line.Color = if hot then Theme.Tone.Green.Top else Theme.Tone.Green.Bottom
	mark.Line.Thickness = if hot then LINE_HOT else LINE
	mark.Line.Transparency = if hot then ALPHA_HOT else ALPHA
	mark.Shadow.Transparency = if hot then SHADOW_ALPHA - 0.25 else SHADOW_ALPHA
end

local function build(): Live
	const playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local holder = folder
	if holder == nil or holder.Parent == nil then
		holder = Instance.new("Folder")
		holder.Name = "DeliverMarks"
		holder.Parent = playerGui
		folder = holder
	end

	const anchor = Instance.new("Attachment")
	anchor.Name = "DeliverMarkAnchor"
	anchor.Parent = workspace.Terrain

	const gui = Instance.new("BillboardGui")
	gui.Name = "DeliverMark"
	gui.Adornee = anchor
	gui.Size = UDim2.fromScale(WIDTH, WIDTH * ASPECT)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Active = false
	gui.Enabled = false
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

	-- a faint Ink line just outside, the Green line on top of it: an empty rounded rectangle, nothing inside
	const shadowFrame = Instance.new("Frame")
	shadowFrame.Name = "Shadow"
	shadowFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	shadowFrame.Position = UDim2.fromScale(0.5, 0.5)
	shadowFrame.Size = UDim2.new(1, LINE * 2, 1, LINE * 2)
	shadowFrame.BackgroundTransparency = 1
	corner(shadowFrame)
	const shadow = stroke(shadowFrame, SHADOW, Theme.Color.Ink, SHADOW_ALPHA)
	shadowFrame.Parent = body

	const outline = Instance.new("Frame")
	outline.Name = "Outline"
	outline.AnchorPoint = Vector2.new(0.5, 0.5)
	outline.Position = UDim2.fromScale(0.5, 0.5)
	outline.Size = UDim2.fromScale(1, 1)
	outline.BackgroundTransparency = 1
	outline.ZIndex = 2
	corner(outline)
	const line = stroke(outline, LINE, Theme.Tone.Green.Bottom, ALPHA)
	outline.Parent = body

	gui.Parent = holder
	return {
		Gui = gui,
		Anchor = anchor,
		Scale = scale,
		Line = line,
		Shadow = shadow,
		Shown = false,
		Hot = false,
		Width = WIDTH,
		Height = WIDTH * ASPECT,
		Position = Vector3.zero,
		Pop = { X = 0, V = 0 },
		Breath = { X = 1, V = 0 },
	}
end

function DeliverMark.new(): Mark
	local state: Live? = nil
	local function get(): Live
		const existing = state
		if existing ~= nil then
			return existing
		end
		const made = build()
		state = made
		table.insert(live, made)
		return made
	end

	const mark = {}

	function mark.Show(_self: Mark, position: Vector3, width: number?, height: number?)
		const current = get()
		const size = width or WIDTH
		const tall = height or size * ASPECT
		if size ~= current.Width or tall ~= current.Height then
			current.Width = size
			current.Height = tall
			current.Gui.Size = UDim2.fromScale(size, tall)
		end
		if position ~= current.Position then
			current.Position = position
			current.Anchor.WorldPosition = position
		end
		if not current.Shown then
			current.Shown = true
			current.Gui.Enabled = true
			wake()
		end
	end

	function mark.SetHot(_self: Mark, hot: boolean)
		const current = get()
		if current.Hot == hot then
			return
		end
		current.Hot = hot
		paint(current)
		if hot and not reduced then
			current.Pop.V += 5
		end
	end

	function mark.Kick(_self: Mark, amount: number?)
		const current = state
		if current ~= nil and current.Shown and not reduced then
			current.Pop.V += amount or 6
			wake()
		end
	end

	function mark.Hide(_self: Mark)
		const current = state
		if current ~= nil and current.Shown then
			current.Shown = false
			current.Hot = false
			paint(current)
			wake()
		end
	end

	function mark.IsShown(_self: Mark): boolean
		return state ~= nil and (state :: Live).Shown
	end

	function mark.Destroy(_self: Mark)
		const current = state
		if current == nil then
			return
		end
		state = nil
		const index = table.find(live, current)
		if index then
			table.remove(live, index)
		end
		current.Gui:Destroy()
		current.Anchor:Destroy()
	end

	return (mark :: any) :: Mark
end

return table.freeze(DeliverMark)
