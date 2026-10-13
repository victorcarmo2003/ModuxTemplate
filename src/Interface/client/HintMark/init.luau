--!strict
-- HintMark: THE marker of the world UI (user request 2026-10-12: the grill had two green bars over the sausage, a dark progress bar and
-- three more kinds of marker, none of them sitting on the asset). One BillboardGui per mark, in studs, with four looks:
--   Ring    a pulsing ring (Mustard on an Ink rim): "this one", "tap here" (the aim point, the beacon over a station)
--   Arrow   a bobbing arrow pointing down at the point (the beacon, the tutorial)
--   Check   a Green disc with a check (a ready sausage, a done step)
--   Arc     a light progress arc (Cream on an Ink rim, 0..1) that fills clockwise from the top
-- How it stays exactly on the asset at any resolution: the gui is `Adornee`d to an Attachment parented to Terrain that is moved to the
-- world point each frame, its Size is in STUDS (UDim2 scale), AlwaysOnTop (seen through the awning), LightInfluence 0, parented to
-- PlayerGui. Nothing is sized in pixels but the rim thickness (a stroke is a line, it stays 2..4 px at any distance).
-- Pure Roblox instances, no Modux, no Vide, no network. One Heartbeat for all marks while any is visible. Create with `HintMark.new()`,
-- call `Show` every frame you want it (cheap: only changed values are written), `Hide` when not, `Destroy` at the end.
-- Reduced motion: no pulse, no bob, no pop (the mark appears whole).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Icons = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Icons)
local Motion = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Motion)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)

export type Kind = "Ring" | "Arrow" | "Check" | "Arc"

export type Mark = {
	-- Puts the mark on a world point with this look; `side` = its width in studs (default per look). Cheap to call every frame.
	Show: (self: Mark, kind: Kind, position: Vector3, side: number?) -> (),
	-- 0..1 of the Arc look.
	SetProgress: (self: Mark, value: number) -> (),
	-- Colour of the Ring (default Mustard) and of the Arc fill (default Cream).
	SetColor: (self: Mark, color: Color3) -> (),
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
	RingStroke: UIStroke,
	ArcRight: UIGradient,
	ArcLeft: UIGradient,
	ArcStrokes: { UIStroke },
	Check: GuiObject,
	Arrow: GuiObject,
	Shown: boolean,
	Kind: Kind,
	ShownAt: number,
	Side: number,
	Position: Vector3,
	Progress: number,
	Color: Color3?,
	Seed: number,
}

const HintMark = {}

const SIDE: { [string]: number } = { Ring = 0.8, Arrow = 0.9, Check = 0.7, Arc = 0.8 }
const RIM = 7 -- px of the Ink rim, 4 px of colour on top
const LINE = 4
const POP_TIME = 0.22
const PULSE_SPEED = 4 -- rad/s
const BOB_SPEED = 5
const ARROW_ICON = "Ui/arrow_right"
const CHECK_ICON = "Ui/check"

local live: { Live } = {}
local connection: RBXScriptConnection? = nil
local reduced = false
local folder: Folder? = nil

local function circle(name: string, thickness: number, color: Color3, transparency: number, inner: boolean?): Frame
	const frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	const corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	const stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	if inner == true then
		stroke.BorderStrokePosition = Enum.BorderStrokePosition.Inner
	end
	stroke.Parent = frame
	return frame
end

-- One half of the arc: a clipped half-frame with a full circle of stroke in it, a hard-edged gradient on the stroke turns with the progress.
local function half(name: string, right: boolean, color: Color3): (Frame, UIGradient, UIStroke)
	const holder = Instance.new("Frame")
	holder.Name = name
	holder.BackgroundTransparency = 1
	holder.ClipsDescendants = true
	holder.Size = UDim2.fromScale(0.5, 1)
	holder.Position = UDim2.fromScale(if right then 0.5 else 0, 0)
	const ring = circle("Ring", LINE, color, 0, true)
	ring.AnchorPoint = Vector2.zero
	ring.Size = UDim2.fromScale(2, 1)
	ring.Position = UDim2.fromScale(if right then -1 else 0, 0)
	ring.Parent = holder
	const gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.501, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	const stroke = ring:FindFirstChildOfClass("UIStroke") :: UIStroke
	gradient.Parent = stroke
	return holder, gradient, stroke
end

local function applyProgress(mark: Live)
	const turn = math.clamp(mark.Progress, 0, 1) * 360
	mark.ArcRight.Rotation = math.clamp(turn, 0, 180)
	mark.ArcLeft.Rotation = math.clamp(turn, 180, 360)
end

local function applyColor(mark: Live)
	const color = mark.Color
	mark.RingStroke.Color = color or Theme.Color.Mustard
	for _, stroke in mark.ArcStrokes do
		stroke.Color = color or Theme.Color.Cream
	end
end

-- Ease with a small overshoot, 0..1 -> 0..1.x
local function pop(t: number): number
	if t >= 1 then
		return 1
	end
	const c = 1.70158
	const x = t - 1
	return 1 + (c + 1) * x * x * x + c * x * x
end

local function step()
	const clock = os.clock()
	local any = false
	for _, mark in live do
		if not mark.Shown then
			continue
		end
		any = true
		local scale = 1
		local bob = 0
		if not reduced then
			const age = clock - mark.ShownAt
			if mark.Kind == "Ring" then
				scale = 1 + 0.1 * math.sin(clock * PULSE_SPEED + mark.Seed)
			elseif mark.Kind == "Arrow" then
				bob = math.sin(clock * BOB_SPEED + mark.Seed) * 0.12
			end
			scale *= pop(math.clamp(age / POP_TIME, 0, 1))
		end
		mark.Scale.Scale = math.max(scale, 0.01)
		mark.Body.Position = UDim2.fromScale(0.5, 0.5 + bob)
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
	gui.Size = UDim2.fromScale(SIDE.Ring, SIDE.Ring)
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

	-- Ring: Ink rim under a Mustard line
	const ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.Size = UDim2.fromScale(1, 1)
	ring.BackgroundTransparency = 1
	ring.Visible = false
	const rim = circle("Rim", RIM, Theme.Color.Ink, 0, false)
	rim.Parent = ring
	const ringColor = circle("Color", LINE, Theme.Color.Mustard, 0, false)
	ringColor.ZIndex = 2
	ringColor.Parent = ring
	ring.Parent = body
	kinds.Ring = ring

	-- Arc: a dim Ink rim, then the two halves of the light fill
	const arc = Instance.new("Frame")
	arc.Name = "Arc"
	arc.Size = UDim2.fromScale(1, 1)
	arc.BackgroundTransparency = 1
	arc.Visible = false
	const arcRim = circle("Rim", RIM, Theme.Color.Ink, 0.35, false)
	arcRim.Parent = arc
	const rightHolder, rightGradient, rightRing = half("Right", true, Theme.Color.Cream)
	const leftHolder, leftGradient, leftRing = half("Left", false, Theme.Color.Cream)
	rightHolder.ZIndex = 2
	leftHolder.ZIndex = 2
	rightHolder.Parent = arc
	leftHolder.Parent = arc
	arc.Parent = body
	kinds.Arc = arc

	-- Check: a Green disc with the check of the UI sheet (a "V" glyph while the sheet is missing)
	const check = Instance.new("Frame")
	check.Name = "Check"
	check.Size = UDim2.fromScale(1, 1)
	check.BackgroundColor3 = Theme.Tone.Green.Bottom
	check.Visible = false
	const checkCorner = Instance.new("UICorner")
	checkCorner.CornerRadius = UDim.new(0.5, 0)
	checkCorner.Parent = check
	const checkStroke = Instance.new("UIStroke")
	checkStroke.Color = Theme.Color.Ink
	checkStroke.Thickness = 3
	checkStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	checkStroke.Parent = check
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

	-- Arrow: the arrow of the UI sheet turned to point down
	const arrow = Instance.new("Frame")
	arrow.Name = "Arrow"
	arrow.Size = UDim2.fromScale(1, 1)
	arrow.BackgroundTransparency = 1
	arrow.Visible = false
	const arrowRect = Icons.Rect(ARROW_ICON)
	if arrowRect ~= nil then
		const image = Instance.new("ImageLabel")
		image.Name = "Glyph"
		image.Size = UDim2.fromScale(1, 1)
		image.BackgroundTransparency = 1
		image.Image = Icons.ImageOf(ARROW_ICON)
		image.ImageRectOffset = arrowRect.Offset
		image.ImageRectSize = arrowRect.Size
		image.Rotation = 90
		image.Parent = arrow
	else
		-- no sheet: a Mustard disc with an Ink rim (a shape is enough to say "here")
		circle("Disc", 3, Theme.Color.Ink, 0, false).Parent = arrow
	end
	arrow.Parent = body
	kinds.Arrow = arrow

	gui.Parent = holder
	const mark: Live = {
		Gui = gui,
		Anchor = anchor,
		Body = body,
		Scale = scale,
		Kinds = kinds,
		RingStroke = ringColor:FindFirstChildOfClass("UIStroke") :: UIStroke,
		ArcRight = rightGradient,
		ArcLeft = leftGradient,
		ArcStrokes = { rightRing, leftRing },
		Check = check,
		Arrow = arrow,
		Shown = false,
		Kind = "Ring",
		ShownAt = 0,
		Side = SIDE.Ring,
		Position = Vector3.zero,
		Progress = 0,
		Color = nil,
		Seed = math.random() * 6.28,
	}
	table.insert(live, mark)
	return mark
end

function HintMark.new(): Mark
	const state = build()
	const self = {} :: any

	function self.Show(_: any, kind: Kind, position: Vector3, side: number?)
		const width = side or SIDE[kind]
		if not state.Shown or state.Kind ~= kind then
			if state.Kind ~= kind or not state.Shown then
				state.ShownAt = os.clock()
			end
			for name, object in state.Kinds do
				object.Visible = name == kind
			end
			state.Kind = kind
		end
		if width ~= state.Side then
			state.Side = width
			state.Gui.Size = UDim2.fromScale(width, width)
		end
		if position ~= state.Position then
			state.Position = position
			state.Anchor.WorldPosition = position
		end
		if not state.Shown then
			state.Shown = true
			state.Gui.Enabled = true
			applyColor(state)
			applyProgress(state)
			wake()
		end
	end

	function self.SetProgress(_: any, value: number)
		if value ~= state.Progress then
			state.Progress = value
			applyProgress(state)
		end
	end

	function self.SetColor(_: any, color: Color3)
		state.Color = color
		applyColor(state)
	end

	function self.Hide(_: any)
		if state.Shown then
			state.Shown = false
			state.Gui.Enabled = false
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
