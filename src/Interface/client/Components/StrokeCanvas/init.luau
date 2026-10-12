--!strict
-- StrokeCanvas: draws the zig-zag of a sauce in the focused prep mode (docs/art/prep-ui-spec.md §5.3; Good Pizza style
-- "trace over the bun with a meter"). It only DRAWS: the pointer and the gesture maths belong to the PrepController
-- (Gestures.Trace); this takes the points the gesture already normalised.
--   Points   the stroke so far, 0..1 on both axes of the canvas, at most Content.Prep.Gestures.trace.MaxPoints (64). The
--            segments are a fixed pool of Frames reused every update (no allocation while drawing)
--   Guide    optional target path (same space), drawn as faint dots
--   Meter    optional bar under the stroke while it is traced: how much sauce is on the bun (Fill 0..1) against the target
--            window (Target = centre, Window = width, both 0..1); the window is a bracket with notches (a shape, not just
--            a colour)
-- Pure: only props, no input, no network. Build it inside a Vide root.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(script.Parent.Theme)

const create = Vide.create
const source = Vide.source
const effect = Vide.effect
const cleanup = Vide.cleanup
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Meter = {
	Fill: number,
	Target: number,
	Window: number,
}

export type Props = {
	Points: () -> { Vector2 },
	Guide: (() -> { Vector2 })?,
	Color: (() -> Color3)?,
	-- Stroke thickness in px (UI scale 1).
	Thickness: number?,
	Meter: (() -> Meter?)?,
	-- Where the meter bar sits (anchored at its bottom centre). Default: 8 px above the bottom of the canvas.
	MeterPosition: UDim2?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Visible: (() -> boolean)?,
	Name: string?,
}

const POOL = Content.Prep.Gestures.ByKey.trace.MaxPoints
const METER_W, METER_H = 160, 10

return function(props: Props): Frame
	const thickness = props.Thickness or 10
	const canvas = create("Frame")({
		Name = props.Name or "StrokeCanvas",
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Position = props.Position or UDim2.new(),
		Size = props.Size or UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = if props.Visible ~= nil then props.Visible else true,
	})
	const area = source(Vector2.zero)
	const connection = canvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		area(canvas.AbsoluteSize)
	end)
	cleanup(function()
		connection:Disconnect()
	end)

	-- fixed pools: POOL - 1 segments, POOL joints, POOL guide dots
	const segments: { Frame } = {}
	const joints: { Frame } = {}
	const dots: { Frame } = {}
	for index = 1, POOL do
		const joint = create("Frame")({
			Name = `Joint{index}`,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(thickness, thickness),
			BackgroundColor3 = Theme.Tone.Mustard.Bottom,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 2,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		}) :: Frame
		joint.Parent = canvas
		joints[index] = joint
		const dot = create("Frame")({
			Name = `GuideDot{index}`,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(6, 6),
			BackgroundColor3 = Theme.Color.Ink,
			BackgroundTransparency = 0.65,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 1,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		}) :: Frame
		dot.Parent = canvas
		dots[index] = dot
		if index < POOL then
			const segment = create("Frame")({
				Name = `Segment{index}`,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(0, thickness),
				BackgroundColor3 = Theme.Tone.Mustard.Bottom,
				BorderSizePixel = 0,
				Visible = false,
				ZIndex = 2,
			}) :: Frame
			segment.Parent = canvas
			segments[index] = segment
		end
	end

	effect(function()
		const color = if props.Color ~= nil then props.Color() else Theme.Tone.Mustard.Bottom
		const size = area()
		const points = props.Points()
		const count = math.min(#points, POOL)
		for index = 1, POOL do
			const joint = joints[index]
			if index <= count then
				const point = points[index]
				joint.Position = UDim2.fromOffset(point.X * size.X, point.Y * size.Y)
				joint.BackgroundColor3 = color
				joint.Visible = true
			else
				joint.Visible = false
			end
			if index < POOL then
				const segment = segments[index]
				if index < count then
					const from, to = points[index], points[index + 1]
					const a = Vector2.new(from.X * size.X, from.Y * size.Y)
					const b = Vector2.new(to.X * size.X, to.Y * size.Y)
					const delta = b - a
					segment.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
					segment.Size = UDim2.fromOffset(delta.Magnitude, thickness)
					segment.Rotation = math.deg(math.atan2(delta.Y, delta.X))
					segment.BackgroundColor3 = color
					segment.Visible = true
				else
					segment.Visible = false
				end
			end
		end
	end)

	if props.Guide ~= nil then
		const guide = props.Guide
		effect(function()
			const size = area()
			const points = guide()
			for index = 1, POOL do
				const dot = dots[index]
				const point = points[index]
				if point ~= nil then
					dot.Position = UDim2.fromOffset(point.X * size.X, point.Y * size.Y)
					dot.Visible = true
				else
					dot.Visible = false
				end
			end
		end)
	end

	if props.Meter ~= nil then
		const meter = props.Meter
		-- window bracket: two notches and a lighter band; fill: Green up to the target window, Mustard past it
		const fill = create("Frame")({
			Name = "Fill",
			Size = function()
				const value = meter()
				return UDim2.fromScale(if value ~= nil then math.clamp(value.Fill, 0, 1) else 0, 1)
			end,
			BackgroundColor3 = function()
				const value = meter()
				if value ~= nil and value.Fill > value.Target + value.Window / 2 then
					return Theme.Tone.Mustard.Bottom
				end
				return Theme.Tone.Green.Bottom
			end,
			BorderSizePixel = 0,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		})
		const notch = function(side: number): Frame
			return create("Frame")({
				Name = "Notch",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = function()
					const value = meter()
					const centre = if value ~= nil then value.Target else 0.5
					const half = if value ~= nil then value.Window / 2 else 0.1
					return UDim2.fromScale(centre + side * half, 0.5)
				end,
				Size = UDim2.fromOffset(4, METER_H + 8),
				BackgroundColor3 = Theme.Color.Ink,
				BorderSizePixel = 0,
				ZIndex = 3,
			}) :: Frame
		end
		const bar = create("Frame")({
			Name = "Meter",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = props.MeterPosition or UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.fromOffset(METER_W, METER_H),
			BackgroundColor3 = Theme.Tone.Cream.Bottom,
			Visible = function()
				return meter() ~= nil
			end,
			ZIndex = 3,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			createRaw("UIStroke")({
				Color = Theme.Color.Ink,
				Thickness = 2,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			fill,
			notch(-1),
			notch(1),
		}) :: Frame
		bar.Parent = canvas
	end

	return canvas
end
