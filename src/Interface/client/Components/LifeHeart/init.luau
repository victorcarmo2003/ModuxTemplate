--!strict
-- LifeHeart: the team life of the fall screens (DEC-317; design/faint-screen-flow.md §2). A heart with the number of
-- team chances (Shift.Chances) in it, drawn from the AST-165 heart (white, tinted here; Icons "Life/heart"), a round
-- pink disc while that image is not uploaded.
--   Calm     whole, a slow soft beat (someone is still standing: the life is not at stake yet)
--   Danger   beats fast and trembles; `Crack` (0..1) draws the crack down the middle (nobody standing: the 10 s window)
--   Broken   the two halves split apart and turn grey (the night is lost); the number shows the life left after it
-- The number pops when it changes. Never red (style guide §7.4): pink heart, Ink outline, white number.
-- Pure: only props. Build it inside a Vide root (it uses springs and a Heartbeat).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
const source = Vide.source
const spring = Vide.spring
const cleanup = Vide.cleanup
const untrack = Vide.untrack
-- Vide 0.4.1 types `create` for 19 classes only; CanvasGroup, UIScale and UICorner variants are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Mode = "Calm" | "Danger" | "Broken"

export type Props = {
	Lives: () -> number,
	Mode: () -> Mode,
	-- Danger: share of the crack drawn (0..1). nil = none.
	Crack: (() -> number)?,
	-- px (square). Default 96.
	Size: number?,
	Name: string?,
	LayoutOrder: number?,
	AnchorPoint: Vector2?,
	Position: UDim2?,
}

const IMAGE = "Life/heart"
const PINK = Color3.fromHex("#F2708C")
const GREY = Theme.Tone.Slate.Top
const CALM_RATE = 2 * math.pi / 1.1 -- rad/s: one beat per 1.1 s
const DANGER_RATE = 2 * math.pi / 0.45
const SPLIT_ANGLE = 9 -- degrees each half turns when broken (tops apart, like a heart snapped in two)
const SPLIT_GAP = 0.09 -- share of the size each half moves away

-- One beat: a quick double bump then rest (lub-dub), 0..1.
local function beat(phase: number): number
	const p = phase % (2 * math.pi) / (2 * math.pi)
	if p < 0.12 then
		return math.sin(p / 0.12 * math.pi)
	elseif p < 0.3 then
		return 0.6 * math.sin((p - 0.12) / 0.18 * math.pi)
	end
	return 0
end

return function(props: Props): Frame
	const size = props.Size or 96
	const has = Icons.Has(IMAGE)
	const rect = Icons.Rect(IMAGE)

	-- per-frame motion (beat + tremble); parked while broken
	const pulse = source(0)
	const shake = source(0)
	local phase = 0
	const connection = RunService.Heartbeat:Connect(function(dt: number)
		const mode = untrack(props.Mode)
		if mode == "Broken" or Motion.Reduced() then
			if untrack(pulse) ~= 0 then
				pulse(0)
				shake(0)
			end
			return
		end
		phase += dt * (if mode == "Danger" then DANGER_RATE else CALM_RATE)
		pulse(beat(phase) * (if mode == "Danger" then 1 else 0.5))
		shake(if mode == "Danger" then math.sin(os.clock() * 47) * 3 else 0)
	end)
	cleanup(function()
		connection:Disconnect()
	end)

	const split = spring(function(): number
		return if props.Mode() == "Broken" then 1 else 0
	end, 0.35, 0.6)
	const crack = function(): number
		if props.Mode() == "Broken" then
			return 1
		end
		return if props.Crack then math.clamp(props.Crack(), 0, 1) else 0
	end
	const tint = function(): Color3
		return PINK:Lerp(GREY, math.clamp(split(), 0, 1))
	end
	const bump = Motion.Bump(props.Lives, 1.35, 0.25)

	-- one half of the heart: a CanvasGroup that clips the full image to its side
	local function half(side: number): Instance
		return createRaw("CanvasGroup")({
			Name = if side < 0 then "Left" else "Right",
			AnchorPoint = Vector2.new(if side < 0 then 1 else 0, 0.5),
			Position = function()
				return UDim2.new(0.5, side * size * SPLIT_GAP * split(), 0.5, size * 0.06 * split())
			end,
			Size = UDim2.fromScale(0.5, 1),
			BackgroundTransparency = 1,
			Rotation = function()
				return side * SPLIT_ANGLE * split()
			end,
			if has and rect
				then create("ImageLabel")({
					Name = "Heart",
					Position = UDim2.fromScale(if side < 0 then 0 else -1, 0),
					Size = UDim2.fromScale(2, 1),
					BackgroundTransparency = 1,
					Image = Icons.ImageOf(IMAGE),
					ImageRectOffset = rect.Offset,
					ImageRectSize = rect.Size,
					ImageColor3 = tint,
				})
				else create("Frame")({
					Name = "Heart",
					Position = UDim2.fromScale(if side < 0 then 0.1 else -0.9, 0.1),
					Size = UDim2.fromScale(1.8, 0.8),
					BackgroundColor3 = tint,
					create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 3 }),
				}),
		})
	end

	-- crack: three Ink segments zig-zagging down the middle, each grows with its share of `crack`
	const SEGMENTS = {
		{ Y = 0.22, Angle = 24 },
		{ Y = 0.4, Angle = -28 },
		{ Y = 0.58, Angle = 22 },
	}
	const crackParts = {}
	for index, segment in SEGMENTS do
		table.insert(
			crackParts,
			create("Frame")({
				Name = `Crack{index}`,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, segment.Y),
				Size = function()
					const share = math.clamp(crack() * #SEGMENTS - (index - 1), 0, 1)
					return UDim2.new(0, math.max(2, size * 0.05), 0.2 * share, 0)
				end,
				Rotation = segment.Angle,
				BackgroundColor3 = Theme.Color.Ink,
				BorderSizePixel = 0,
				Visible = function()
					return crack() * #SEGMENTS > index - 1 and split() < 0.2
				end,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			})
		)
	end

	return create("Frame")({
		Name = props.Name or "LifeHeart",
		LayoutOrder = props.LayoutOrder or 0,
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		Position = props.Position or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Rotation = shake,

		createRaw("UIScale")({
			Scale = function()
				return 1 + 0.1 * pulse()
			end,
		}),

		half(-1),
		half(1),
		create("Frame")({
			Name = "Crack",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 2,
			crackParts,
		}),

		CartoonLabel({
			Name = "Lives",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.56), -- the visual middle of the heart sits low (owner 2026-10-20)
			Box = UDim2.fromScale(0.5, 0.42),
			Scaled = true,
			MaxTextSize = math.floor(size * 0.42),
			TextSize = math.floor(size * 0.42),
			Stroke = math.max(2, math.floor(size / 32)),
			ZIndex = 3,
			Text = function()
				return tostring(math.max(props.Lives(), 0))
			end,
			Children = {
				createRaw("UIScale")({ Scale = bump }),
			},
		}),
	}) :: Frame
end
