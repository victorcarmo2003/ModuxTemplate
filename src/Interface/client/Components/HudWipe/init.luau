--!strict
-- HudWipe: the 10 s window when nobody is on their feet (FEAT-026, DEC-094; ui-text.md §12.3; style guide §7.2).
-- "Everyone's out!" over a Mustard ring of `Total` dots that go out one per second, the number in the middle and
-- "Lights out in {n}" under it. Mustard, never red, no alarming tick (no bump, no shake).
-- The owner computes the whole seconds left from `Shift.WipeEndsAt`; `Seconds < 0` hides it.
-- Status only: nothing clickable (FEAT-032). Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)

const create = Vide.create
const spring = Vide.spring
const source = Vide.source
const effect = Vide.effect
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke is not among them.
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

const RING = 120
const DOT = 14
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
			return if seconds() >= index then Theme.Color.Mustard else Theme.Color.Ink
		end,
		BackgroundTransparency = function()
			return if seconds() >= index then 0 else Theme.Transparency.Track
		end,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Stroke }),
	})
end

local function text(name: string, order: number, size: number, value: () -> string): TextLabel
	return create("TextLabel")({
		Name = name,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, size + 8),
		BackgroundTransparency = 1,
		FontFace = Theme.Font.Title,
		TextSize = size,
		TextColor3 = Theme.Color.Text,
		Text = value,
		createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Stroke }),
	})
end

return function(props: Props): CanvasGroup
	const total = props.Total or 10
	const shown = function(): boolean
		return props.Seconds() >= 0
	end
	-- Last value shown, so the card fades out with its number after the window closes.
	const last = source(math.max(props.Seconds(), 0))
	effect(function()
		const seconds = props.Seconds()
		if seconds >= 0 then
			last(seconds)
		end
	end)
	const alpha = spring(function()
		return if shown() then 0 else 1
	end, 0.2, 1)

	const dots: { Instance } = {}
	for index = 1, total do
		table.insert(dots, dot(index, total, last))
	end

	return create("CanvasGroup")({
		Name = props.Name or "HudWipe",
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		Position = props.Position or UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		GroupTransparency = alpha,
		Visible = function()
			return shown() or alpha() < 0.99
		end,

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),

		text("Title", 1, TITLE_SIZE, function()
			return "Everyone's out!"
		end),

		create("Frame")({
			Name = "Ring",
			LayoutOrder = 2,
			Size = UDim2.fromOffset(RING + DOT + 4, RING + DOT + 4),
			BackgroundTransparency = 1,

			create("Frame")({
				Name = "Disc",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(RING - DOT - 6, RING - DOT - 6),
				BackgroundColor3 = Theme.Color.Ink,
				BackgroundTransparency = Theme.Transparency.Panel,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				createRaw("UIStroke")({ Color = Theme.Color.Mustard, Thickness = 3 }),
				create("TextLabel")({
					Name = "Number",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					FontFace = Theme.Font.Title,
					TextSize = NUMBER_SIZE,
					TextColor3 = Theme.Color.Mustard,
					Text = function()
						return tostring(last())
					end,
					createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 3 }),
				}),
			}),

			dots,
		}),

		text("Line", 3, LINE_SIZE, function()
			return `Lights out in {last()}`
		end),
	})
end
