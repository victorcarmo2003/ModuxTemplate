--!strict
-- PromptBillboard: the custom interaction prompt in the world (port of AnimalPlane `PromptInterface`,
-- DEC-015, DEC-029, DEC-066). Three states:
--   Hidden    nothing drawn
--   Indicator small dot: "something here can be used"
--   Prompt    pill with the key chip (desktop/gamepad only) and the action text; fills while held
-- Pure: only props. PromptController (TASK-014) owns targeting, input and the hold timer; this only
-- draws `Holding` over `HoldDuration`. Taps on the pill reach OnPress/OnRelease only when the
-- BillboardGui is parented under PlayerGui.
-- Fixed pixel size (not studs) so the text keeps >= 14 px and the pill >= 44 px tall on a phone. Trimmed (user request
-- 2026-10-11: UI too big): a pill that takes taps (touch) stays TOUCH_HEIGHT (>= Theme.MinTouch); a pill that only
-- shows the key (desktop / gamepad) is PILL_HEIGHT.
-- Light pass (user request 2026-10-11: the Ink pill read as grey text on dark): Cream toy pill with a darker Cream lip,
-- thick Ink outline, Ink text without stroke, Mustard key chip with an Ink letter. The hold fill is a hard-edged
-- horizontal gradient on the face (Mustard up to the progress, Cream after), so the round corners stay intact
-- without a CanvasGroup (crisp text, cheap on a phone). The width is measured from the text (TextService), never
-- from AutomaticSize, so the pill cannot keep a stale size.
-- Completion pop (user request 2026-10-11): each time `Done` goes up (PromptController fired the Interact) the pill
-- bumps with an underdamped bounce (Motion.Bump), the face flashes white -> Green, the fill stays full for the pop and
-- a check icon (AST-091 `Ui/check`) jumps over the pill and fades. One-shot tweens on 2 instances: cheap on a phone.
-- The world sparkles and the `prompt_done` sound belong to PromptController (they are not UI).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local UseTween = require(script.Parent.UseTween)
local Motion = require(script.Parent.Motion)
local Icons = require(script.Parent.Icons)

const create = Vide.create
const source = Vide.source
const spring = Vide.spring
const untrack = Vide.untrack
const effect = Vide.effect
const cleanup = Vide.cleanup
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
	-- Completion counter: every increase plays the pop (the interaction was just sent). nil = never pops.
	Done: (() -> number)?,
	StudsOffset: Vector3?,
	Name: string?,
}

const PILL_HEIGHT = 40 -- face 36 + lip 4, desktop / gamepad (not tapped)
const TOUCH_HEIGHT = 48 -- face 44 + lip 4 (>= Theme.MinTouch): the pill takes taps
const LIP = Theme.Lip
const CHIP_SIZE = 28
const DOT_SIZE = 16
const TEXT_SIZE = 17
const PAD_LEFT = 6 -- before the chip
const PAD_TEXT = 14 -- before the text when there is no chip, and after the text
const GAP = 8 -- chip -> text
const RELEASE_TIME = 0.15
const GUI_WIDTH = 360
const GUI_HEIGHT = 68
-- Legacy enum of the cartoon font, for TextService:GetTextSize (same face as Theme.Font.Body)
const MEASURE_FONT = Enum.Font.FredokaOne

const FACE = Theme.Tone.Cream.Top
const LIP_COLOR = Theme.Tone.Cream.Lip
const FILL = Theme.Tone.Mustard.Bottom
const EDGE = 0.002 -- width of the fill edge in the gradient (keypoint times must increase)

-- Completion pop
const POP_TIME = 0.45 -- s the pop keeps the billboard on and the fill full
const POP_SCALE = 1.16 -- pill bump peak
const FLASH_FROM = Color3.new(1, 1, 1)
const FLASH_TO = Theme.Tone.Green.Top
const FLASH_START = 0.15 -- transparency of the flash at the trigger
const FLASH_TIME = 0.3
const CHECK_SIZE = 36
const CHECK_RISE = 28 -- px the check jumps above its start
const CHECK_IN = 0.18 -- s of the scale-in (Back overshoot)
const CHECK_UP = 0.45 -- s of the rise
const CHECK_FADE_DELAY = 0.22
const CHECK_FADE = 0.23
const CHECK_ICON = if Icons.Has("Ui/check") then "Ui/check" else "Reaction/star"
const CHECK_RECT = Icons.Rect(CHECK_ICON)

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
	const bounds = TextService:GetTextSize(text, TEXT_SIZE, MEASURE_FONT, Vector2.new(GUI_WIDTH, TOUCH_HEIGHT))
	return math.ceil(bounds.X)
end

return function(props: Props): BillboardGui
	const hovered = source(false)

	local function tappable(): boolean
		const prop = props.Tappable
		return if prop then prop() else props.OnPress ~= nil
	end

	-- Pill height: touch target size only when the pill takes taps
	local function pillHeight(): number
		return if tappable() then TOUCH_HEIGHT else PILL_HEIGHT
	end
	-- Start of the check jump: just over the top edge of the pill
	local function checkStart(): UDim2
		return UDim2.new(0.5, 0, 0.5, -untrack(pillHeight) // 2 - 4)
	end

	local function isPrompt(): boolean
		return props.State() == "Prompt"
	end

	local function hasKey(): boolean
		return props.KeyLabel() ~= ""
	end

	-- Completion pop: `popping` is on for POP_TIME after each increase of Done.
	const done = props.Done or function(): number
		return 0
	end
	const popping = source(false)
	const checkScale = createRaw("UIScale")({ Scale = 0 }) :: UIScale
	const flash = create("Frame")({
		Name = "Flash",
		Size = UDim2.new(1, 0, 1, -LIP),
		BackgroundColor3 = FLASH_FROM,
		BackgroundTransparency = 1,
		ZIndex = 3,
		create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
	})
	const check = create("ImageLabel")({
		Name = "Check",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = checkStart(),
		Size = UDim2.fromOffset(CHECK_SIZE, CHECK_SIZE),
		BackgroundTransparency = 1,
		Image = Icons.ImageOf(CHECK_ICON),
		ImageRectOffset = if CHECK_RECT then CHECK_RECT.Offset else Vector2.zero,
		ImageRectSize = if CHECK_RECT then CHECK_RECT.Size else Vector2.zero,
		ImageTransparency = 1,
		ZIndex = 6,
		checkScale,
	})

	local popThread: thread? = nil
	local lastDone = untrack(done)
	local function pop()
		flash.BackgroundColor3 = FLASH_FROM
		flash.BackgroundTransparency = FLASH_START
		TweenService:Create(flash, TweenInfo.new(FLASH_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = FLASH_TO,
			BackgroundTransparency = 1,
		}):Play()

		const start = checkStart()
		check.Position = start
		check.ImageTransparency = 0
		checkScale.Scale = 0
		TweenService:Create(checkScale, TweenInfo.new(CHECK_IN, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
		TweenService
			:Create(check, TweenInfo.new(CHECK_UP, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = start - UDim2.fromOffset(0, CHECK_RISE),
			})
			:Play()
		TweenService
			:Create(check, TweenInfo.new(CHECK_FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, CHECK_FADE_DELAY), {
				ImageTransparency = 1,
			})
			:Play()

		if popThread and coroutine.status(popThread) == "suspended" then
			task.cancel(popThread)
		end
		popping(true)
		popThread = task.delay(POP_TIME, function()
			popThread = nil
			popping(false)
		end)
	end
	effect(function()
		const now = done()
		if now > lastDone then
			untrack(pop)
		end
		lastDone = now
	end)
	cleanup(function()
		if popThread and coroutine.status(popThread) == "suspended" then
			task.cancel(popThread)
		end
	end)
	const bump = Motion.Bump(done, POP_SCALE)

	-- Hold fill: linear over HoldDuration while held, quick drain from wherever it stopped on release. Full during
	-- the pop (a tap fills in RELEASE_TIME).
	const fill = UseTween(function()
		return if (props.Holding() or popping()) and isPrompt() then UDim2.fromScale(1, 1) else UDim2.fromScale(0, 1)
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
	const pillSize = function(): number
		return pillScale() * bump()
	end

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
			return props.State() ~= "Hidden" or pillScale() > 0.01 or dotSize() > 0.5 or popping()
		end,

		check,

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
				return UDim2.fromOffset(pillWidth(), pillHeight())
			end,
			BackgroundColor3 = LIP_COLOR,
			Visible = function()
				return pillScale() > 0.01
			end,

			create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
			createRaw("UIScale")({ Scale = pillSize }),
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

			flash,

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
				ZIndex = 4,

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
						return UDim2.fromOffset(labelWidth(), pillHeight() - LIP)
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
				ZIndex = 5,
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
