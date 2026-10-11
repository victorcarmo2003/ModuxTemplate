--!strict
-- Toast: small notification card (style guide §7.2, "Notificação": top right, closes by itself; DEC-063).
-- Cartoon pass (AST-091): a Cream "tag" (CartoonPanel) leaning a little (alternating with its slot, Theme.Motion
-- TagTilt), a coloured tab with the kind icon on its left (Info Teal, Good Green, Alert Mustard; never red), Ink text.
-- Pops in from the right with overshoot, stays `Duration` seconds (clamped to 3..6), shrinks away, then calls OnDone
-- so the owner can drop it from its list. Pure: only props. Toast/Stack.luau places several in the top-right corner.
-- Fixed size: the card is measured once (TextService, unscaled) instead of AutomaticSize, so the pop (UIScale)
-- cannot re-wrap the text mid-animation and scale children cannot inflate the card.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
const source = Vide.source
const spring = Vide.spring
const cleanup = Vide.cleanup
-- Vide 0.4.1 types `create` for 19 classes only; UIScale and UIPadding are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Kind = "Info" | "Good" | "Alert"

export type Props = {
	Text: () -> string,
	Kind: (() -> Kind)?,
	-- Seconds on screen, clamped to 3..6. Default 4.
	Duration: number?,
	OnDone: (() -> ())?,
	LayoutOrder: (() -> number)?,
}

const WIDTH = 260
const TEXT_SIZE = 17
const TAB = 40
const ICON = 28
const PAD_X = 10
const PAD_Y = 8
-- Spare width kept out of the measure so the rounded text size under UIScale never re-wraps.
const WRAP_SLACK = 8
const MIN_DURATION = 3
const MAX_DURATION = 6
const OUT_TIME = 0.35
const SLIDE = 60

-- No red in the UI (style guide §7.4): Alert is Mustard.
const TONE: { [Kind]: Theme.Tone } = {
	Info = Theme.Tone.Teal,
	Good = Theme.Tone.Green,
	Alert = Theme.Tone.Mustard,
}

const ICON_NAME: { [Kind]: string } = {
	Info = "Ui/info",
	Good = "Ui/check",
	Alert = "Ui/warning",
}

-- Drawn glyph on the tab while the UI sheet is not uploaded.
const GLYPH: { [Kind]: string } = {
	Info = "i",
	Good = "+",
	Alert = "!",
}

local function cancel(thread: thread)
	if coroutine.status(thread) == "suspended" then
		task.cancel(thread)
	end
end

return function(props: Props): Frame
	const duration = math.clamp(props.Duration or 4, MIN_DURATION, MAX_DURATION)
	const shown = source(false)

	const enter = task.defer(function()
		shown(true)
	end)
	const leave = task.delay(duration, function()
		shown(false)
	end)
	const done = task.delay(duration + OUT_TIME, function()
		if props.OnDone then
			props.OnDone()
		end
	end)
	cleanup(function()
		cancel(enter)
		cancel(leave)
		cancel(done)
	end)

	const scale = Motion.Pop(shown)
	const offset = spring(function()
		return if shown() then 0 else SLIDE
	end, 0.25, 0.7)

	local function kind(): Kind
		return if props.Kind then props.Kind() else "Info"
	end
	local function order(): number
		return if props.LayoutOrder then props.LayoutOrder() else 0
	end
	local function iconName(): string
		return ICON_NAME[kind()]
	end
	-- Card height for the text at the fixed width (lip under it, never below a touch target).
	local function cardHeight(): number
		const width = WIDTH - TAB - PAD_X * 2 - WRAP_SLACK
		const bounds = TextService:GetTextSize(props.Text(), TEXT_SIZE, Enum.Font.FredokaOne, Vector2.new(width, math.huge))
		return math.max(Theme.MinTouch, math.ceil(bounds.Y) + PAD_Y * 2) + Theme.Lip
	end
	local function rect(): Icons.Rect
		return Icons.Rect(iconName()) or { Offset = Vector2.zero, Size = Vector2.zero }
	end

	return create("Frame")({
		Name = "Toast",
		Size = function()
			return UDim2.fromOffset(WIDTH, cardHeight())
		end,
		BackgroundTransparency = 1,
		LayoutOrder = order,

		CartoonPanel({
			Name = "Card",
			Position = function()
				return UDim2.fromOffset(offset(), 0)
			end,
			Size = UDim2.fromScale(1, 1),
			-- Tags lean, alternating with their slot.
			Rotation = function()
				return if order() % 2 == 0 then Theme.Motion.TagTilt else -Theme.Motion.TagTilt
			end,
			Tone = Theme.Tone.Cream,
			Outline = Theme.Outline.Normal,
			Radius = Theme.Radius.Chip,
			Gloss = false,
			Decor = {
				createRaw("UIScale")({ Scale = scale }),
			},
			Children = {
				-- Coloured tab with the kind icon
				CartoonPanel({
					Name = "Tab",
					Size = UDim2.new(0, TAB, 1, 0),
					Tone = function()
						return TONE[kind()]
					end,
					Outline = 0,
					Lip = 0,
					Radius = Theme.Radius.Chip,
					Children = {
						create("ImageLabel")({
							Name = "Icon",
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromOffset(ICON, ICON),
							BackgroundTransparency = 1,
							Image = function()
								return Icons.ImageOf(iconName())
							end,
							ImageRectOffset = function()
								return rect().Offset
							end,
							ImageRectSize = function()
								return rect().Size
							end,
							Visible = function()
								return Icons.Has(iconName())
							end,
						}),
						CartoonLabel({
							Name = "Glyph",
							Box = UDim2.fromScale(1, 1),
							TextSize = 26,
							Text = function()
								return GLYPH[kind()]
							end,
							Visible = function()
								return not Icons.Has(iconName())
							end,
						}),
					},
				}),

				CartoonLabel({
					Name = "Message",
					Position = UDim2.fromOffset(TAB, 0),
					Box = UDim2.new(1, -TAB, 1, 0),
					TextSize = TEXT_SIZE,
					Color = Theme.Color.Dark,
					Stroke = 0,
					Wrapped = true,
					XAlignment = Enum.TextXAlignment.Left,
					Text = props.Text,
					Children = {
						createRaw("UIPadding")({
							PaddingLeft = UDim.new(0, PAD_X),
							PaddingRight = UDim.new(0, PAD_X),
							PaddingTop = UDim.new(0, PAD_Y),
							PaddingBottom = UDim.new(0, PAD_Y),
						}),
					},
				}),
			},
		}),
	})
end
