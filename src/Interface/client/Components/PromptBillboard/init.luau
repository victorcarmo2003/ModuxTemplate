--!strict
-- PromptBillboard: the custom interaction prompt in the world (port of AnimalPlane `PromptInterface`,
-- DEC-015, DEC-029, DEC-066). Three states:
--   Hidden    nothing drawn
--   Indicator small dot: "something here can be used"
--   Prompt    pill with the key chip (desktop/gamepad only) and the action text; fills while held
-- Pure: only props. PromptController (TASK-014) owns targeting, input and the hold timer; this only
-- draws `Holding` over `HoldDuration`. Taps on the pill reach OnPress/OnRelease only when the
-- BillboardGui is parented under PlayerGui.
-- Fixed pixel size (not studs) so the text keeps >= 14 px and the pill >= 44 px tall on a phone.
-- Light pass (user request 2026-10-11: the Ink pill read as grey text on dark): Cream toy pill with a darker Cream lip,
-- thick Ink outline, Ink text without stroke, Mustard key chip with an Ink letter. The hold fill is a hard-edged
-- horizontal gradient on the face (Mustard up to the progress, Cream after), so the round corners stay intact
-- without a CanvasGroup (crisp text, cheap on a phone). The width is measured from the text (TextService), never
-- from AutomaticSize, so the pill cannot keep a stale size.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local UseTween = require(script.Parent.UseTween)

const create = Vide.create
const source = Vide.source
const spring = Vide.spring
const untrack = Vide.untrack
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke, UIPadding and UIScale are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type State = "Hidden" | "Indicator" | "Prompt"

export type Props = {
	Adornee: Instance?,
	State: () -> State,
	-- Action text from the target's `PromptText` (e.g. "Grill", "Take Order").
	Text: () -> string,
	-- Key shown in the chip ("E", "X"). Empty string hides the chip (mobile uses the fixed button).
	KeyLabel: () -> string,
	Holding: () -> boolean,
	-- Seconds the action must be held; 0 = tap.
	HoldDuration: () -> number,
	OnPress: (() -> ())?,
	OnRelease: (() -> ())?,
	-- The pill takes taps/clicks (touch only). An Active button under the locked first-person cursor sinks
	-- MouseMovement and the stock camera stops turning, so desktop/gamepad keep it off. nil = has OnPress.
	Tappable: (() -> boolean)?,
	StudsOffset: Vector3?,
	Name: string?,
}

const PILL_HEIGHT = 50 -- face 46 + lip 4 (>= Theme.MinTouch)
const LIP = Theme.Lip
const CHIP_SIZE = 34
const DOT_SIZE = 20
const TEXT_SIZE = 20
const PAD_LEFT = 8 -- before the chip
const PAD_TEXT = 18 -- before the text when there is no chip, and after the text
const GAP = 10 -- chip -> text
const RELEASE_TIME = 0.15
const GUI_WIDTH = 420
const GUI_HEIGHT = 76
-- Legacy enum of the cartoon font, for TextService:GetTextSize (same face as Theme.Font.Body)
const MEASURE_FONT = Enum.Font.FredokaOne

const FACE = Theme.Tone.Cream.Top
const LIP_COLOR = Theme.Tone.Cream.Lip
const FILL = Theme.Tone.Mustard.Bottom
const EDGE = 0.002 -- width of the fill edge in the gradient (keypoint times must increase)

-- Face colour along the pill: Mustard up to `fill` (0..1), Cream after it.
local function fillSequence(fill: number): ColorSequence
	if fill <= EDGE then
		return ColorSequence.new(FACE)
	elseif fill >= 1 - EDGE then
		return ColorSequence.new(FILL)
	end
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, FILL),
		ColorSequenceKeypoint.new(fill, FILL),
		ColorSequenceKeypoint.new(fill + EDGE, FACE),
		ColorSequenceKeypoint.new(1, FACE),
	})
end

local function textWidth(text: string): number
	const bounds = TextService:GetTextSize(text, TEXT_SIZE, MEASURE_FONT, Vector2.new(GUI_WIDTH, PILL_HEIGHT))
	return math.ceil(bounds.X)
end

return function(props: Props): BillboardGui
	const hovered = source(false)

	local function tappable(): boolean
		const prop = props.Tappable
		return if prop then prop() else props.OnPress ~= nil
	end

	local function isPrompt(): boolean
		return props.State() == "Prompt"
	end

	local function hasKey(): boolean
		return props.KeyLabel() ~= ""
	end

	-- Hold fill: linear over HoldDuration while held, quick drain from wherever it stopped on release.
	const fill = UseTween(function()
		return if props.Holding() and isPrompt() then UDim2.fromScale(1, 1) else UDim2.fromScale(0, 1)
	end, function()
		return if untrack(props.Holding) then untrack(props.HoldDuration) else RELEASE_TIME
	end, Enum.EasingStyle.Linear)

	const pillScale = spring(function()
		if not isPrompt() then
			return 0
		elseif props.Holding() then
			return 0.95
		elseif hovered() then
			return 1.05
		end
		return 1
	end, 0.2, 1)

	const dotSize = spring(function()
		return if props.State() == "Indicator" then DOT_SIZE else 0
	end, 0.15, 1)

	const labelWidth = function(): number
		return textWidth(props.Text())
	end
	const pillWidth = function(): number
		const lead = if hasKey() then PAD_LEFT + CHIP_SIZE + GAP else PAD_TEXT
		return math.min(lead + labelWidth() + PAD_TEXT, GUI_WIDTH - 8)
	end

	return create("BillboardGui")({
		Name = props.Name or "PromptBillboard",
		Adornee = props.Adornee,
		Size = UDim2.fromOffset(GUI_WIDTH, GUI_HEIGHT),
		StudsOffset = props.StudsOffset or Vector3.zero,
		AlwaysOnTop = true,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Active = tappable,
		ClipsDescendants = false,
		Enabled = function()
			return props.State() ~= "Hidden" or pillScale() > 0.01 or dotSize() > 0.5
		end,

		create("Frame")({
			Name = "Indicator",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = function()
				const size = dotSize()
				return UDim2.fromOffset(size, size)
			end,
			Visible = function()
				return dotSize() > 0.5
			end,
			BackgroundColor3 = Color3.new(1, 1, 1),
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Outline.Normal }),
			createRaw("UIGradient")({ Rotation = 90, Color = Theme.Gradient(Theme.Tone.Mustard) }),
		}),

		-- Body = the lip colour; the face sits on it, LIP px shorter, so the darker band shows under it.
		create("Frame")({
			Name = "Pill",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = function()
				return UDim2.fromOffset(pillWidth(), PILL_HEIGHT)
			end,
			BackgroundColor3 = LIP_COLOR,
			Visible = function()
				return pillScale() > 0.01
			end,

			create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
			createRaw("UIScale")({ Scale = pillScale }),
			createRaw("UIStroke")({
				Color = Theme.Color.Ink,
				Thickness = Theme.Outline.Thick,
				LineJoinMode = Enum.LineJoinMode.Round,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),

			create("Frame")({
				Name = "Face",
				Size = UDim2.new(1, 0, 1, -LIP),
				BackgroundColor3 = Color3.new(1, 1, 1),
				ZIndex = 1,
				create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
				createRaw("UIGradient")({
					Rotation = 0,
					Color = function()
						return fillSequence(fill().X.Scale)
					end,
				}),
				-- "toy plastic" inner rim
				createRaw("UIStroke")({
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					BorderStrokePosition = Enum.BorderStrokePosition.Inner,
					Color = Color3.new(1, 1, 1),
					Thickness = Theme.Rim.Thickness,
					Transparency = Theme.Rim.Transparency,
				}),
			}),

			create("Frame")({
				Name = "Gloss",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 3),
				Size = UDim2.new(1, -16, 0.38, -3),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.55,
				ZIndex = 2,
				create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
			}),

			create("Frame")({
				Name = "Content",
				Size = UDim2.new(1, 0, 1, -LIP),
				BackgroundTransparency = 1,
				ZIndex = 3,

				createRaw("UIPadding")({
					PaddingLeft = function()
						return UDim.new(0, if hasKey() then PAD_LEFT else PAD_TEXT)
					end,
				}),
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, GAP),
				}),

				-- Mustard key chip, Ink letter (Mustard = "interactive" accent, style guide §7.1)
				create("Frame")({
					Name = "KeyChip",
					LayoutOrder = 1,
					Size = UDim2.fromOffset(CHIP_SIZE, CHIP_SIZE),
					BackgroundColor3 = Color3.new(1, 1, 1),
					Visible = hasKey,
					create("UICorner")({ CornerRadius = UDim.new(0.3, 0) }),
					createRaw("UIStroke")({
						Color = Theme.Color.Ink,
						Thickness = Theme.Outline.Normal,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						BorderStrokePosition = Enum.BorderStrokePosition.Inner,
					}),
					createRaw("UIGradient")({ Rotation = 90, Color = Theme.Gradient(Theme.Tone.Mustard) }),

					create("TextLabel")({
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						FontFace = Theme.Font.Title,
						TextSize = TEXT_SIZE,
						TextColor3 = Theme.Color.Ink,
						Text = props.KeyLabel,
					}),
				}),

				create("TextLabel")({
					Name = "Action",
					LayoutOrder = 2,
					Size = function()
						return UDim2.fromOffset(labelWidth(), PILL_HEIGHT - LIP)
					end,
					BackgroundTransparency = 1,
					FontFace = Theme.Font.Body,
					TextSize = TEXT_SIZE,
					TextColor3 = Theme.Color.Ink,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Text = props.Text,
				}),
			}),

			-- Touch/mouse target over the whole pill (>= 44 px tall).
			create("TextButton")({
				Name = "Hit",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 4,
				Active = true,
				Visible = tappable,
				MouseEnter = function()
					hovered(true)
				end,
				MouseLeave = function()
					hovered(false)
				end,
				MouseButton1Down = function()
					if props.OnPress then
						props.OnPress()
					end
				end,
				MouseButton1Up = function()
					if props.OnRelease then
						props.OnRelease()
					end
				end,
			}),
		}),
	})
end
