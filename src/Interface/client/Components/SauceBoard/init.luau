--!strict
-- SauceBoard: the 2D drawing board of a sauce at the condiment table (owner 2026-10-19: "ao invés de fazer 3D, faz 2D"). A Cream
-- CartoonPanel card in the middle of the screen with a big top-down hot dog (the bun, the sausage on it) where the player squeezes
-- the sauce:
--   Guide    white arrows (the AST-091 `Ui/arrow_right`, an Ink chevron while the sheet is missing) along the pattern, each turned
--            the way to draw
--   Strokes  the line drawn so far and the sauces already on the hot dog, thick, in their sauce colour with an Ink edge
--   Bottle   the plastic squeeze bottle under the pointer: an opaque body in the sauce colour leaning up to the right, squeezed
--            thinner as it empties, a ridged cream cap, the cone nozzle tip on the pointer
-- Everything is in the bun space (x 0..1 along the hot dog, left to right; y 0..1 across it, top to bottom), the caller maps the
-- pointer with OnArea's frame. Status only: the pointer is the caller's. Pure: only props; build it inside a Vide root. Px at UI
-- scale 1.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
const indexes = Vide.indexes
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke and UIScale are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Segment = { A: Vector2, B: Vector2, Color: Color3 }

export type Props = {
	Visible: () -> boolean,
	Title: () -> string,
	-- the pattern to follow (bun space), drawn as arrows
	Guide: { { X: number, Y: number } },
	-- the segments on the hot dog (bun space): the sauces already on it and the line being drawn
	Segments: () -> { Segment },
	-- the pointer (bun space), nil = not over the board: the bottle hides
	Cursor: () -> Vector2?,
	Color: () -> Color3,
	-- share of the bottle left, 0..1
	Ink: () -> number,
	Scale: (() -> number)?,
	-- the frame of the hot dog area: the caller maps the pointer with its AbsolutePosition / AbsoluteSize
	OnArea: (area: Frame) -> (),
}

const AREA = Vector2.new(560, 224) -- px of the hot dog area (aspect = Content.Prep.Build.Aspect, 2.5)
const PAD = 26
const LINE = 18 -- px of the drawn sauce
const ARROW = 30
const ARROW_EVERY = 0.07 -- bun-space length between two guide arrows (x scaled by the aspect)
const BUN = Color3.fromHex("#E8B36B")
const BUN_LIGHT = Color3.fromHex("#F4CE8E")
const SAUSAGE = Color3.fromHex("#B5482E")
const SAUSAGE_DARK = Color3.fromHex("#8E3420")
const BOTTLE = Vector2.new(70, 150) -- px of the bottle body
const CAP = 18
const NOZZLE = Vector2.new(18, 46)
const LEAN = 35 -- degrees: the bottle leans up to the right (owner sketch)

local function px(point: Vector2): Vector2
	return Vector2.new(point.X * AREA.X, point.Y * AREA.Y)
end

-- One thick rounded line along a segment (bun space), `grow` px wider than LINE; its colour = `color` or the segment's
local function bar(segment: () -> Segment, grow: number, color: Color3?, z: number): Frame
	return create("Frame")({
		Name = if color then "Edge" else "Sauce",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = function(): UDim2
			const now = segment()
			const middle = (px(now.A) + px(now.B)) / 2
			return UDim2.fromOffset(middle.X, middle.Y)
		end,
		Size = function(): UDim2
			const now = segment()
			return UDim2.fromOffset((px(now.B) - px(now.A)).Magnitude + LINE + grow, LINE + grow)
		end,
		Rotation = function(): number
			const now = segment()
			const delta = px(now.B) - px(now.A)
			return math.deg(math.atan2(delta.Y, delta.X))
		end,
		BackgroundColor3 = function(): Color3
			return color or segment().Color
		end,
		BorderSizePixel = 0,
		ZIndex = z,
		create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
	}) :: Frame
end

-- The guide arrows along the path, every ARROW_EVERY of its length
local function arrows(path: { { X: number, Y: number } }): { Frame }
	const out: { Frame } = {}
	const icon = Icons.Has("Ui/arrow_right")
	const rect = Icons.Rect("Ui/arrow_right")
	local carry = 0
	for index = 2, #path do
		const a = px(Vector2.new(path[index - 1].X, path[index - 1].Y))
		const b = px(Vector2.new(path[index].X, path[index].Y))
		const length = (b - a).Magnitude
		const angle = math.deg(math.atan2(b.Y - a.Y, b.X - a.X))
		local at = carry
		while at < length do
			const point = a:Lerp(b, at / length)
			if icon and rect ~= nil then
				table.insert(
					out,
					create("ImageLabel")({
						Name = "Arrow",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromOffset(point.X, point.Y),
						Size = UDim2.fromOffset(ARROW, ARROW),
						Rotation = angle,
						BackgroundTransparency = 1,
						Image = Icons.ImageOf("Ui/arrow_right"),
						ImageRectOffset = rect.Offset,
						ImageRectSize = rect.Size,
						ImageColor3 = Color3.new(1, 1, 1),
						ZIndex = 6,
					}) :: any
				)
			else
				table.insert(
					out,
					CartoonLabel({
						Name = "Arrow",
						Text = "›",
						TextSize = 30,
						Position = UDim2.fromOffset(point.X - ARROW / 2, point.Y - ARROW / 2),
						Box = UDim2.fromOffset(ARROW, ARROW),
						XAlignment = Enum.TextXAlignment.Center,
						YAlignment = Enum.TextYAlignment.Center,
						ZIndex = 6,
					}) :: any
				)
			end
			at += ARROW_EVERY * AREA.Y * 2.5
		end
		carry = at - length
	end
	return out
end

-- The squeeze bottle (owner 2026-10-19: plastic, a "bisnaga", not glass), its nozzle tip at the frame's anchor (bottom middle),
-- leaning LEAN degrees: an opaque soft-plastic body in the sauce colour with a cream label band and a glossy streak, a ridged
-- cream cap and a cone nozzle. As it empties the body gets squeezed thinner and the air at the top (the bottom of the bottle,
-- held upside down) shows as a paler, cloudy plastic
local function bottle(color: () -> Color3, ink: () -> number): Frame
	const height = BOTTLE.Y + CAP + NOZZLE.Y
	const left = function(): number
		return math.clamp(ink(), 0, 1)
	end
	return create("Frame")({
		Name = "Bottle",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(BOTTLE.X, height),
		BackgroundTransparency = 1,
		Rotation = LEAN,
		ZIndex = 20,
		-- the cone nozzle (bottom): a narrow tip under a wider base
		create("Frame")({
			Name = "Nozzle",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromOffset(NOZZLE.X * 0.55, NOZZLE.Y),
			BackgroundColor3 = Color3.fromHex("#FFF8EA"),
			BorderSizePixel = 0,
			ZIndex = 21,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 3 }),
			-- the sauce at the tip
			create("Frame")({
				Name = "Drop",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, 0),
				Size = UDim2.new(1, 0, 0, 8),
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				ZIndex = 22,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			}),
		}),
		create("Frame")({
			Name = "NozzleBase",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -NOZZLE.Y * 0.55),
			Size = UDim2.fromOffset(NOZZLE.X * 1.3, NOZZLE.Y * 0.5),
			BackgroundColor3 = Color3.fromHex("#FFF8EA"),
			BorderSizePixel = 0,
			ZIndex = 22,
			create("UICorner")({ CornerRadius = UDim.new(0, 6) }),
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 3 }),
		}),
		-- the ridged screw cap
		create("Frame")({
			Name = "Cap",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -NOZZLE.Y + 4),
			Size = UDim2.fromOffset(BOTTLE.X * 0.78, CAP + 4),
			BackgroundColor3 = Color3.fromHex("#FFF8EA"),
			BorderSizePixel = 0,
			ZIndex = 23,
			create("UICorner")({ CornerRadius = UDim.new(0, 5) }),
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 3 }),
			createRaw("UIGradient")({
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHex("#FFF8EA")),
					ColorSequenceKeypoint.new(0.25, Color3.fromHex("#E9D9B8")),
					ColorSequenceKeypoint.new(0.5, Color3.fromHex("#FFF8EA")),
					ColorSequenceKeypoint.new(0.75, Color3.fromHex("#E9D9B8")),
					ColorSequenceKeypoint.new(1, Color3.fromHex("#FFF8EA")),
				}),
			}),
		}),
		-- the soft plastic body: squeezed thinner as it empties
		create("Frame")({
			Name = "Body",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = function(): UDim2
				return UDim2.fromOffset(math.floor(BOTTLE.X * (0.74 + 0.26 * left())), BOTTLE.Y + 6)
			end,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 21,
			create("UICorner")({ CornerRadius = UDim.new(0, 22) }),
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			-- matte plastic: a soft shade across the body
			createRaw("UIGradient")({
				Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHex("#C9C2CF")),
				Rotation = 0,
			}),
			-- the air at the top (the bottle is held upside down): pale cloudy plastic
			create("Frame")({
				Name = "Air",
				Size = function(): UDim2
					return UDim2.new(1, 0, (1 - left()) * 0.9, 0)
				end,
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.3,
				BorderSizePixel = 0,
				ZIndex = 22,
			}),
			-- the label band
			create("Frame")({
				Name = "Label",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.58),
				Size = UDim2.new(1, 0, 0.22, 0),
				BackgroundColor3 = Color3.fromHex("#FFF8EA"),
				BackgroundTransparency = 0.1,
				BorderSizePixel = 0,
				ZIndex = 23,
				createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2 }),
			}),
			-- the glossy streak of the plastic
			create("Frame")({
				Name = "Shine",
				Position = UDim2.new(0.16, 0, 0.07, 0),
				Size = UDim2.new(0.13, 0, 0.36, 0),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.25,
				BorderSizePixel = 0,
				ZIndex = 24,
				create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
			}),
		}),
	}) :: Frame
end

return function(props: Props): Frame
	const pop = Motion.Pop(props.Visible)
	const tip = function(): UDim2
		const at = props.Cursor()
		if at == nil then
			return UDim2.fromOffset(-1000, -1000)
		end
		const point = px(at)
		return UDim2.fromOffset(point.X, point.Y)
	end
	const area = create("Frame")({
		Name = "HotDog",
		Size = UDim2.fromOffset(AREA.X, AREA.Y),
		BackgroundTransparency = 1,
		-- the bun
		create("Frame")({
			Name = "Bun",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = BUN,
			BorderSizePixel = 0,
			ZIndex = 2,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			create("Frame")({
				Name = "Crumb",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.94, 0.78),
				BackgroundColor3 = BUN_LIGHT,
				BorderSizePixel = 0,
				ZIndex = 3,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			}),
		}),
		-- the sausage
		create("Frame")({
			Name = "Sausage",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1.04, 0.5),
			BackgroundColor3 = SAUSAGE,
			BorderSizePixel = 0,
			ZIndex = 4,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			createRaw("UIGradient")({
				Color = ColorSequence.new(SAUSAGE, SAUSAGE_DARK),
				Rotation = 90,
			}),
		}),
		-- the guide
		create("Frame")({
			Name = "Guide",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 6,
			arrows(props.Guide),
		}),
		-- the sauces
		create("Frame")({
			Name = "Sauces",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 8,
			-- every Ink edge under every sauce, so a line's edge never cuts across the line before it
			indexes(props.Segments, function(segment: () -> Segment, _index: number): Frame
				return bar(segment, 6, Theme.Color.Ink, 8)
			end),
			indexes(props.Segments, function(segment: () -> Segment, _index: number): Frame
				return bar(segment, 0, nil, 9)
			end),
		}),
		-- the bottle under the pointer
		create("Frame")({
			Name = "Pointer",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 20,
			(function(): Frame
				const made = bottle(props.Color, props.Ink)
				Vide.effect(function()
					made.Position = tip()
				end)
				return made
			end)(),
		}),
	}) :: Frame
	props.OnArea(area)

	return create("Frame")({
		Name = "SauceBoard",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Visible = function(): boolean
			return props.Visible() or pop() > 0.02
		end,
		createRaw("UIScale")({
			Scale = function(): number
				return math.max(pop(), 0.01) * (if props.Scale then props.Scale() else 1)
			end,
		}),
		CartoonPanel({
			Name = "Card",
			Tone = Theme.Tone.Cream,
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			Padding = { Top = PAD + 10, Bottom = PAD, Left = PAD, Right = PAD },
			Children = { area },
		}),
		-- the title tab
		CartoonPanel({
			Name = "Title",
			Tone = Theme.Tone.Mustard,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, -16),
			Size = UDim2.fromOffset(0, 34),
			AutomaticSize = Enum.AutomaticSize.X,
			Lip = 3,
			Padding = { Left = 16, Right = 16 },
			ZIndex = 30,
			Children = {
				CartoonLabel({
					Name = "Text",
					Text = props.Title,
					TextSize = 20,
					Box = UDim2.new(0, 0, 0, 30),
					AutomaticSize = Enum.AutomaticSize.X,
					YAlignment = Enum.TextYAlignment.Center,
					ZIndex = 31,
				}),
			},
		}),
	}) :: Frame
end
