--!strict
-- TutorialPanel: the instruction card of the first-hot-dog tutorial (user request 2026-10-11; texts Provisional until
-- ui-text.md). Top centre, under the clock row, narrow (50% of the width, 260..440 px) so it never covers the
-- crosshair, the hotbar or the thumb controls on a phone.
--   Cream CartoonPanel card, thick Ink outline (reading surface: light, high contrast)
--   Mustard step chip "2/7" on the left; it turns Green with a check while `Done` is true (step just completed)
--   optional "STEP 2 OF 7" label (14 px), the instruction (17 px Ink, starts with the verb) and an optional hint line
--   (14 px, Ink top tone) that wraps instead of shrinking
--   Cream "Skip" tag hanging off the bottom-right corner (>= 44 px tall touch target), with the key of the device
-- Urgent (the player made no progress for a while): the card turns Mustard and pulses until the step changes; the owner
-- swaps the hint for the short reminder.
-- Pops in/out (Motion.Pop) and jumps each time the step number goes up (Motion.Bump).
-- Pure: only props. TutorialController owns the step, the texts, the skip bind and when it shows.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)
local CartoonButton = require(script.Parent.CartoonButton)
local Icons = require(script.Parent.Icons)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIScale, UIPadding, UIListLayout and UISizeConstraint are not among
-- them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Shown: () -> boolean,
	-- Step number (1-based) and how many steps there are; Total 0 hides the chip.
	Step: () -> number,
	Total: () -> number,
	Text: () -> string,
	-- Small line over the instruction ("STEP 2 OF 7"); nil or "" hides it.
	Label: (() -> string)?,
	-- The step was just completed: Green chip with a check. Default false.
	Done: (() -> boolean)?,
	-- Line under the instruction; "" hides it.
	Hint: () -> string,
	-- Skip tag text ("Skip (Q)"); "" hides the tag.
	SkipText: () -> string,
	OnSkip: (() -> ())?,
	-- No progress for a while: Mustard card that pulses. Default false.
	Urgent: (() -> boolean)?,
	-- UI scale of the owner (1 on the smallest phone).
	Scale: (() -> number)?,
	-- Reactive so the owner can follow its UI scale. Default: top centre, 50 px down.
	Position: (() -> UDim2)?,
	Name: string?,
}

const TEXT_SIZE = 17
const HINT_SIZE = 14
const CHIP = 36 -- round step chip (not touchable)
const CHIP_WIDE = 52 -- chip width for a two-digit count ("10/13" at 14 px)
const WIDTH_SCALE = 0.5
const HEAD_TAG = 92 -- px reserved on the right of the title row for the "STEP n OF N" tag
const MIN_WIDTH = 260
const MAX_WIDTH = 440
const GAP = 8
const SKIP_SIZE = 15
const LABEL_SIZE = 14
const CHECK = "Ui/check"
const CHECK_SIZE = 24
const URGE_PULSE = 0.05 -- extra size at the peak of the urgent pulse
const URGE_SPEED = 6 -- rad/s

return function(props: Props): Frame
	const pop = Motion.Pop(props.Shown)
	const bump = Motion.Bump(props.Step, 1.08)
	const checkRect = Icons.Rect(CHECK)

	local function hasChip(): boolean
		return props.Total() > 0
	end

	-- "10/13" does not fit the round chip: it stretches into a pill
	local function chipWidth(): number
		return if props.Total() >= 10 then CHIP_WIDE else CHIP
	end

	local function done(): boolean
		return if props.Done then props.Done() else false
	end

	local function urgent(): boolean
		return if props.Urgent then props.Urgent() else false
	end

	const pulse = Vide.source(0)
	const connection = RunService.Heartbeat:Connect(function()
		const value = if Vide.untrack(urgent) and Vide.untrack(props.Shown)
			then math.abs(math.sin(os.clock() * URGE_SPEED)) * URGE_PULSE
			else 0
		if value ~= Vide.untrack(pulse) then
			pulse(value)
		end
	end)
	Vide.cleanup(function()
		connection:Disconnect()
	end)

	local function label(): string
		return if props.Label then props.Label() else ""
	end

	return create("Frame")({
		Name = props.Name or "TutorialPanel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = props.Position or UDim2.new(0.5, 0, 0, 50),
		Size = UDim2.fromScale(WIDTH_SCALE, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = function()
			return props.Shown() or pop() > 0.02
		end,

		createRaw("UISizeConstraint")({ MinSize = Vector2.new(MIN_WIDTH, 0), MaxSize = Vector2.new(MAX_WIDTH, 10000) }),
		createRaw("UIScale")({
			Scale = function()
				return (if props.Scale then props.Scale() else 1) * pop() * bump() * (1 + pulse())
			end,
		}),

		CartoonPanel({
			Name = "Card",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Tone = function()
				return if urgent() then Theme.Tone.Mustard else Theme.Tone.Cream
			end,
			Outline = Theme.Outline.Thick,
			Radius = Theme.Radius.Card,
			Decor = {
				createRaw("UISizeConstraint")({ MinSize = Vector2.new(0, CHIP + 12 + Theme.Lip) }),
			},
			Padding = { Left = 8, Right = 12, Top = 6, Bottom = 12 },
			Children = {
				createRaw("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, GAP),
				}),

				-- Step chip "2/7"
				CartoonPanel({
					Name = "Chip",
					LayoutOrder = 1,
					Size = function()
						return UDim2.fromOffset(chipWidth(), CHIP)
					end,
					Tone = function()
						return if done() then Theme.Tone.Green else Theme.Tone.Mustard
					end,
					Outline = Theme.Outline.Normal,
					Lip = 3,
					Visible = hasChip,
					Children = {
						CartoonLabel({
							Box = UDim2.fromScale(1, 1),
							TextSize = 14,
							Color = Theme.Color.Dark,
							Stroke = 0,
							Visible = function()
								return not done()
							end,
							Text = function()
								return `{props.Step()}/{props.Total()}`
							end,
						}),
						-- check of a completed step (the "V" glyph while the UI sheet is missing)
						if checkRect
							then create("ImageLabel")({
								Name = "Check",
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromOffset(CHECK_SIZE, CHECK_SIZE),
								BackgroundTransparency = 1,
								Image = Icons.ImageOf(CHECK),
								ImageRectOffset = checkRect.Offset,
								ImageRectSize = checkRect.Size,
								Visible = done,
							})
							else CartoonLabel({
								Name = "Check",
								Box = UDim2.fromScale(1, 1),
								TextSize = 18,
								Color = Theme.Color.Text,
								Text = "V",
								Visible = done,
							}),
					},
				}),

				-- Instruction + hint
				create("Frame")({
					Name = "Lines",
					LayoutOrder = 2,
					Size = function()
						return UDim2.new(1, if hasChip() then -(chipWidth() + GAP) else 0, 0, 0)
					end,
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					createRaw("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 2),
					}),
					-- Head row: title on the left, the small "STEP n OF N" tag on the right of the same line (two lines in total)
					create("Frame")({
						Name = "Head",
						LayoutOrder = 0,
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						CartoonLabel({
							Name = "Text",
							Box = UDim2.new(1, -HEAD_TAG, 0, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							TextSize = TEXT_SIZE,
							Color = Theme.Color.Dark,
							Stroke = 0,
							Wrapped = true,
							XAlignment = Enum.TextXAlignment.Left,
							Text = props.Text,
						}),
						CartoonLabel({
							Name = "Label",
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.fromScale(1, 0),
							Box = UDim2.fromOffset(HEAD_TAG, LABEL_SIZE + 4),
							TextSize = LABEL_SIZE,
							Color = Theme.Tone.Ink.Top,
							Stroke = 0,
							XAlignment = Enum.TextXAlignment.Right,
							Text = label,
							Visible = function()
								return label() ~= ""
							end,
						}),
					}),
					CartoonLabel({
						Name = "Hint",
						LayoutOrder = 1,
						Box = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						TextSize = HINT_SIZE,
						Color = Theme.Tone.Ink.Top,
						Stroke = 0,
						Wrapped = true,
						XAlignment = Enum.TextXAlignment.Left,
						Text = props.Hint,
						Visible = function()
							return props.Hint() ~= ""
						end,
					}),
				}),
			},
		}),

		-- Skip tag hanging off the bottom-right corner (outside the measured card)
		CartoonButton({
			Name = "Skip",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 1, -2),
			Text = props.SkipText,
			TextSize = SKIP_SIZE,
			Tone = Theme.Tone.White,
			Padding = 10,
			Selectable = false,
			Visible = function()
				return props.SkipText() ~= ""
			end,
			OnActivated = function()
				if props.OnSkip then
					props.OnSkip()
				end
			end,
		}),
	})
end
