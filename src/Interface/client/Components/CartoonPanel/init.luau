--!strict
-- CartoonPanel: the one surface of the cartoon UI kit (AST-091; Theme tokens). Pills, cards, chips, bubbles, tags and
-- buttons are all this, so the whole UI reads as one toy set:
--   Body     Lip colour (the darker "drop" band, Theme.Lip px tall at the bottom), round corners, thick Ink outline
--   Face     two-tone vertical gradient of the Tone (light top -> base), same corners, over the lip, with a thin
--            white inner rim (UIStroke BorderStrokePosition Inner: the "toy plastic" edge, never over the outline)
--   Gloss    soft white band on the upper part of the face (plastic shine)
--   Studs    tiled studs texture over the face (only when `Studs` and the texture id exists, Icons.Ids.Studs)
--   Content  the children, inside the face area (padding and layouts go here)
-- Native only (Frames, UICorner, UIStroke, UIGradient): crisp at any UI scale, no CanvasGroup (cheap on a phone).
-- AutomaticSize works on any axis: the content drives the size, the lip and the outline are added around it.
-- The body itself never uses Roblox AutomaticSize: the full-size Face would feed its last size back into the bounds
-- and the panel only ever grows (sticky after a pop or a re-wrap). Only Content auto-sizes; the body copies its
-- measured size (AbsoluteSize over the UIScale above it, read from a 100 px probe) on the auto axes.
-- Pure: only props. Reactive props accept a value or a source (`Value<T>`).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)

const create = Vide.create
const source = Vide.source
const cleanup = Vide.cleanup
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke, UIPadding and UIGradient are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Value<T> = T | () -> T

export type Padding = number | { Top: number?, Bottom: number?, Left: number?, Right: number? }

export type Props = {
	-- Surface colours (Theme.Tone.*). Default Theme.Tone.Ink (HUD pill).
	Tone: Value<Theme.Tone>?,
	-- Outline px (Theme.Outline.*). 0 = no outline. Default Theme.Outline.Normal.
	Outline: Value<number>?,
	OutlineColor: Value<Color3>?,
	Radius: UDim?,
	-- Lip px under the face. 0 = flat. Default Theme.Lip.
	Lip: number?,
	-- Gloss band on the upper face. Default true.
	Gloss: boolean?,
	-- White inner rim on the face. Default true.
	Rim: boolean?,
	-- Studs texture over the face. Default false.
	Studs: boolean?,
	-- Surface transparency (face and lip). Default 0.
	Transparency: Value<number>?,
	-- Content padding in px (number = all sides).
	Padding: Padding?,
	-- Children of the content area (labels, icons, layouts).
	Children: { any }?,
	-- Children of the body itself (UIScale, UISizeConstraint, UIAspectRatioConstraint).
	Decor: { any }?,
	Name: string?,
	LayoutOrder: Value<number>?,
	AnchorPoint: Vector2?,
	Position: Value<UDim2>?,
	Size: Value<UDim2>?,
	AutomaticSize: Enum.AutomaticSize?,
	Rotation: Value<number>?,
	Visible: Value<boolean>?,
	ZIndex: number?,
}

-- Current value of a Value<T> (reads, so it tracks inside a reactive binding). One per type: a generic reader
-- would bind T to the whole `T | () -> T` union under the new solver.
local function call(value: any): any
	if type(value) == "function" then
		const getter = value :: () -> any
		return getter()
	end
	return value
end
local function readNumber(value: Value<number>): number
	return call(value)
end
local function readTone(value: Value<Theme.Tone>): Theme.Tone
	return call(value)
end

local function padding(value: Padding?): Instance
	local top, bottom, left, right = 0, 0, 0, 0
	if type(value) == "number" then
		top, bottom, left, right = value, value, value, value
	elseif type(value) == "table" then
		top, bottom, left, right = value.Top or 0, value.Bottom or 0, value.Left or 0, value.Right or 0
	end
	return createRaw("UIPadding")({
		PaddingTop = UDim.new(0, top),
		PaddingBottom = UDim.new(0, bottom),
		PaddingLeft = UDim.new(0, left),
		PaddingRight = UDim.new(0, right),
	})
end

const PROBE = 100
-- Under this UI scale a measure is skipped: in a pop-in / pop-out the text keeps its minimum size while the scale
-- nears 0, so content / scale blew the panel up to the screen width (owner 2026-10-20, the lobby gem pill on a phone).
const MIN_MEASURE_SCALE = 0.25

-- Content size: the face area on the axes the body does not size by itself, auto (0) on the axes it does.
local function contentSize(autoX: boolean, autoY: boolean, lip: number): UDim2
	return UDim2.new(if autoX then 0 else 1, 0, if autoY then 0 else 1, if autoY then 0 else -lip)
end

return function(props: Props): Frame
	const tone: Value<Theme.Tone> = props.Tone or Theme.Tone.Ink
	const lip = props.Lip or Theme.Lip
	const radius = props.Radius or Theme.Radius.Pill
	const auto = props.AutomaticSize or Enum.AutomaticSize.None
	const autoX = auto == Enum.AutomaticSize.X or auto == Enum.AutomaticSize.XY
	const autoY = auto == Enum.AutomaticSize.Y or auto == Enum.AutomaticSize.XY
	const transparency: Value<number> = props.Transparency or 0
	const outline: Value<number> = props.Outline or Theme.Outline.Normal

	const face: { any } = {
		create("UICorner")({ CornerRadius = radius }),
		createRaw("UIStroke")({
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
			Color = Color3.new(1, 1, 1),
			Thickness = Theme.Rim.Thickness,
			Transparency = function()
				return Theme.Rim.Transparency + readNumber(transparency) * (1 - Theme.Rim.Transparency)
			end,
			Enabled = props.Rim ~= false,
		}),
		createRaw("UIGradient")({
			Rotation = 90,
			Color = function()
				return Theme.Gradient(readTone(tone))
			end,
		}),
	}

	if props.Gloss ~= false then
		table.insert(
			face,
			create("Frame")({
				Name = "Gloss",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 3),
				Size = UDim2.new(1, -10, 0.42, -3),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = function()
					return 0.78 + readNumber(transparency) * 0.22
				end,
				create("UICorner")({ CornerRadius = radius }),
			})
		)
	end

	const studs = Icons.Ids.Studs
	if props.Studs and studs ~= "" then
		table.insert(
			face,
			create("ImageLabel")({
				Name = "Studs",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = studs,
				ScaleType = Enum.ScaleType.Tile,
				TileSize = UDim2.fromOffset(Theme.StudsTile, Theme.StudsTile),
				ImageTransparency = function()
					return Theme.Transparency.Studs + readNumber(transparency) * (1 - Theme.Transparency.Studs)
				end,
				create("UICorner")({ CornerRadius = radius }),
			})
		)
	end

	-- Without `Padding` the caller may put its own UIPadding in Children (one UIPadding per frame).
	const content: { any } = if props.Padding ~= nil then { padding(props.Padding) } else {}
	if props.Children then
		table.insert(content, props.Children)
	end

	-- Measured content size in offset px (UIScale undone), for the auto axes.
	const measured = source(Vector2.zero)
	const probe = create("Frame")({
		Name = "ScaleProbe",
		Size = UDim2.fromOffset(PROBE, PROBE),
		BackgroundTransparency = 1,
		Visible = false,
	})
	const contentFrame = create("Frame")({
		Name = "Content",
		Size = contentSize(autoX, autoY, lip),
		AutomaticSize = auto,
		BackgroundTransparency = 1,
		ZIndex = 1,
		content,
	})
	if autoX or autoY then
		local function measure()
			const scale = probe.AbsoluteSize.X / PROBE
			if scale >= MIN_MEASURE_SCALE then
				measured(contentFrame.AbsoluteSize / scale)
			end
		end
		const a = contentFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)
		const b = probe:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)
		cleanup(function()
			a:Disconnect()
			b:Disconnect()
		end)
	end

	-- Size on the auto axes: the given offset is a minimum, like Roblox AutomaticSize.
	const size = if autoX or autoY
		then function(): UDim2
			const base: UDim2 = call(props.Size) or UDim2.new()
			const m = measured()
			return UDim2.new(
				if autoX then UDim.new(0, math.max(base.X.Offset, math.ceil(m.X))) else base.X,
				if autoY then UDim.new(0, math.max(base.Y.Offset, math.ceil(m.Y) + lip)) else base.Y
			)
		end
		else props.Size or UDim2.new()

	return create("Frame")({
		Name = props.Name or "CartoonPanel",
		LayoutOrder = props.LayoutOrder or 0,
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Position = props.Position or UDim2.new(),
		Size = size,
		Rotation = props.Rotation or 0,
		Visible = if props.Visible == nil then true else props.Visible,
		ZIndex = props.ZIndex or 1,
		BackgroundColor3 = function()
			return readTone(tone).Lip
		end,
		BackgroundTransparency = transparency,

		create("UICorner")({ CornerRadius = radius }),
		createRaw("UIStroke")({
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			LineJoinMode = Enum.LineJoinMode.Round,
			Color = props.OutlineColor or Theme.Color.Ink,
			Thickness = outline,
			Enabled = function()
				return readNumber(outline) > 0
			end,
			Transparency = transparency,
		}),
		props.Decor or {},
		probe,

		create("Frame")({
			Name = "Face",
			-- The lip shows under the face.
			Size = UDim2.new(1, 0, 1, -lip),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = transparency,
			ZIndex = 0,
			face,
		}),

		contentFrame,
	})
end
