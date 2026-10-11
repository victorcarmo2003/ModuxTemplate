--!strict
-- HudWipe: the 10 s window when nobody is on their feet (FEAT-026, DEC-094; ui-text.md §12.3; style guide §7.2).
-- "Everyone's out!" over a Mustard ring of `Total` dots that go out one per second, the number in the middle and
-- "Lights out in {n}" under it. Mustard, never red, no alarming tick (no bump, no shake).
-- The owner computes the whole seconds left from `Shift.WipeEndsAt`; `Seconds < 0` hides it.
-- Cartoon pass (AST-091): the number on an Ink CartoonPanel disc, dots with a thick Ink outline and a lip shade, the
-- line on a Cream tag; the whole card pops in once (Motion.Pop) and shrinks away. No per-second bump on purpose.
-- Status only: nothing clickable (FEAT-032). Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
const source = Vide.source
const effect = Vide.effect
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke and UIScale are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	-- Whole seconds left (0..Total); < 0 = no window.
	Seconds: () -> number,
	-- Length of the window (Content.Revive.WipeWindow). Default 10.
	Total: number?,
	Name: string?,
	AnchorPoint: Vector2?,
	Position: UDim2?,
}

const RING = 128
const DOT = 18
const NUMBER_SIZE = 56
const TITLE_SIZE = 28
const LINE_SIZE = 18
const WIDTH = 300

local function dot(index: number, total: number, seconds: () -> number): Frame
	-- Clockwise from 12 o'clock; dot `index` is lit while more than index - 1 seconds are left.
	const angle = (index - 1) / total * 2 * math.pi
	const radius = RING / 2
	return create("Frame")({
		Name = `Dot{index}`,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, math.sin(angle) * radius, 0.5, -math.cos(angle) * radius),
		Size = UDim2.fromOffset(DOT, DOT),
		BackgroundColor3 = function()
			return if seconds() >= index then Theme.Color.Mustard else Theme.Tone.Ink.Top
		end,
		create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
		createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Outline.Normal }),
		createRaw("UIGradient")({
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 190, 170)),
		}),
	})
end

local function title(value: string): TextLabel
	return CartoonLabel({
		Name = "Title",
		LayoutOrder = 1,
		Box = UDim2.new(1, 0, 0, TITLE_SIZE + 8),
		Text = value,
		TextSize = TITLE_SIZE,
	})
end

local function line(value: () -> string): Frame
	return CartoonPanel({
		Name = "Line",
		LayoutOrder = 3,
		Size = UDim2.fromOffset(0, LINE_SIZE + 18),
		AutomaticSize = Enum.AutomaticSize.X,
		Rotation = -1.5,
		Tone = Theme.Tone.Cream,
		Lip = 3,
		Padding = { Left = 14, Right = 14 },
		Children = {
			CartoonLabel({
				Box = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				Text = value,
				TextSize = LINE_SIZE,
				Color = Theme.Color.Dark,
				Stroke = 0,
			}),
		},
	})
end

return function(props: Props): Frame
	const total = props.Total or 10
	const shown = function(): boolean
		return props.Seconds() >= 0
	end
	-- Last value shown, so the card shrinks away with its number after the window closes.
	const last = source(math.max(props.Seconds(), 0))
	effect(function()
		const seconds = props.Seconds()
		if seconds >= 0 then
			last(seconds)
		end
	end)
	const scale = Motion.Pop(shown)

	const dots: { Instance } = {}
	for index = 1, total do
		table.insert(dots, dot(index, total, last))
	end

	return create("Frame")({
		Name = props.Name or "HudWipe",
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		Position = props.Position or UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = function()
			return scale() > 0.02
		end,

		createRaw("UIScale")({ Scale = scale }),

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),

		title("Everyone's out!"),

		create("Frame")({
			Name = "Ring",
			LayoutOrder = 2,
			Size = UDim2.fromOffset(RING + DOT + 4, RING + DOT + 4),
			BackgroundTransparency = 1,

			CartoonPanel({
				Name = "Disc",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(RING - DOT - 8, RING - DOT - 8),
				Tone = Theme.Tone.Ink,
				Outline = Theme.Outline.Thick,
				Children = {
					CartoonLabel({
						Name = "Number",
						Box = UDim2.fromScale(1, 1),
						TextSize = NUMBER_SIZE,
						Color = Theme.Color.Mustard,
						Stroke = 4,
						Text = function()
							return tostring(last())
						end,
					}),
				},
			}),

			dots,
		}),

		line(function()
			return `Lights out in {last()}`
		end),
	})
end
