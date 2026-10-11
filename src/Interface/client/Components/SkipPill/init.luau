--!strict
-- SkipPill: the cutscene skip vote (DEC-078, DEC-194; style guide §7.2 "Skip da cutscene": bottom right, only in a
-- cutscene, pill "Skip (1/2)" with the vote count; ui-text.md §7: "Hold to skip" · "Skip {votes}/{needed}" ·
-- "Skipping...").
--   hint   "Hold to skip" above the pill while the own vote is not in
--   pill   key chip (desktop/gamepad; none on touch) + "Skip (votes/needed)"; fills Mustard while held, stays full
--          once the own vote is in; "Skipping..." when the server count reaches the threshold
-- Sits left of the mobile jump button and right of the call strip, so it never covers either on a phone. The pill is
-- the mobile control (>= 44 px tall): press/release go to OnPress/OnRelease; the owner times the hold.
-- Cartoon pass (AST-091): Ink CartoonPanel pill with a Mustard hold fill (pill shaped, grows from the left), Cream
-- key chip, squash on press (Motion.Press).
-- Pure: only props. Votes and Needed come from the server (`Cutscene` set); nothing is counted here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
const source = Vide.source
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke, UIPadding, UIScale and UIListLayout are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Visible: () -> boolean,
	Votes: () -> number,
	Needed: () -> number,
	-- The own vote is in (from the owner; the server count is Votes)
	Voted: () -> boolean,
	-- 0..1 hold progress of the own press
	Progress: () -> number,
	-- Key chip ("E", "X"); "" hides it (touch)
	KeyLabel: () -> string,
	OnPress: (() -> ())?,
	OnRelease: (() -> ())?,
	-- Distance from the right edge in px (left of the jump button). Default 112.
	Right: number?,
	-- Distance from the bottom edge in px. Default 24.
	Bottom: number?,
	Name: string?,
}

const HINT = "Hold to skip"
const SKIPPING = "Skipping..."
const PILL_HEIGHT = 44 -- >= Theme.MinTouch
const MIN_WIDTH = 130
const TEXT_SIZE = 17 -- >= Theme.MinTextSize on the smallest phone
const HINT_SIZE = 14
const CHIP_SIZE = 28

local function isPointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

return function(props: Props): Frame
	const pressed = source(false)

	const skipping = function(): boolean
		const needed = props.Needed()
		return needed > 0 and props.Votes() >= needed
	end
	const label = function(): string
		if skipping() then
			return SKIPPING
		end
		return `Skip ({props.Votes()}/{math.max(props.Needed(), 1)})`
	end
	const fill = function(): number
		if props.Voted() or skipping() then
			return 1
		end
		return math.clamp(props.Progress(), 0, 1)
	end
	const full = function(): boolean
		return fill() >= 1
	end

	const press = Motion.Press(pressed)
	const pop = Motion.Pop(props.Visible)

	local function release()
		if not pressed() then
			return
		end
		pressed(false)
		if props.OnRelease then
			props.OnRelease()
		end
	end

	return create("Frame")({
		Name = props.Name or "SkipPill",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -(props.Right or 112), 1, -(props.Bottom or 24)),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Visible = function()
			return props.Visible() or pop() > 0.02
		end,

		createRaw("UIScale")({
			Scale = function()
				return pop() * press()
			end,
		}),
		createRaw("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),

		CartoonLabel({
			Name = "Hint",
			LayoutOrder = 1,
			Box = UDim2.fromOffset(MIN_WIDTH, HINT_SIZE + 6),
			TextSize = HINT_SIZE,
			Color = Theme.Color.Cream,
			XAlignment = Enum.TextXAlignment.Right,
			Text = HINT,
			Visible = function()
				return not props.Voted() and not skipping()
			end,
		}),

		create("TextButton")({
			Name = "Pill",
			LayoutOrder = 2,
			Size = UDim2.fromOffset(0, PILL_HEIGHT),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			Active = props.Visible,
			Selectable = false,
			InputBegan = function(input: InputObject)
				if not isPointer(input) or not props.Visible() or pressed() then
					return
				end
				pressed(true)
				if props.OnPress then
					props.OnPress()
				end
			end,
			InputEnded = function(input: InputObject)
				if isPointer(input) then
					release()
				end
			end,
			MouseLeave = release,

			CartoonPanel({
				Name = "Body",
				Size = UDim2.fromOffset(0, PILL_HEIGHT),
				AutomaticSize = Enum.AutomaticSize.X,
				Tone = Theme.Tone.Ink,
				Transparency = Theme.Transparency.Panel,
				Outline = Theme.Outline.Thick,
				Decor = {
					createRaw("UISizeConstraint")({ MinSize = Vector2.new(MIN_WIDTH, PILL_HEIGHT) }),
				},
				Children = {
					-- Hold fill, under the content: a Mustard pill growing from the left
					create("Frame")({
						Name = "Fill",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 3, 0.5, 0),
						Size = function()
							return UDim2.new(fill(), -6 * fill(), 1, -6)
						end,
						BackgroundColor3 = Theme.Color.Mustard,
						ZIndex = 0,
						Visible = function()
							return fill() > 0
						end,
						create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
						createRaw("UIGradient")({
							Rotation = 90,
							Color = Theme.Gradient(Theme.Tone.Mustard),
						}),
					}),

					create("Frame")({
						Name = "Content",
						Size = UDim2.new(0, 0, 1, 0),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						ZIndex = 1,
						createRaw("UIPadding")({
							PaddingLeft = UDim.new(0, 8),
							PaddingRight = UDim.new(0, 18),
						}),
						createRaw("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, 8),
						}),

						CartoonPanel({
							Name = "Chip",
							LayoutOrder = 1,
							Size = UDim2.fromOffset(CHIP_SIZE, CHIP_SIZE),
							Tone = Theme.Tone.Cream,
							Radius = Theme.Radius.Small,
							Lip = 3,
							Visible = function()
								return props.KeyLabel() ~= ""
							end,
							Children = {
								CartoonLabel({
									Box = UDim2.fromScale(1, 1),
									TextSize = TEXT_SIZE,
									Color = Theme.Color.Dark,
									Stroke = 0,
									Text = props.KeyLabel,
								}),
							},
						}),

						CartoonLabel({
							Name = "Label",
							LayoutOrder = 2,
							TextSize = TEXT_SIZE,
							Color = function()
								return if full() then Theme.Color.Ink else Theme.Color.Text
							end,
							Stroke = function()
								return if full() then 0 else Theme.TextStroke(TEXT_SIZE)
							end,
							Text = label,
						}),
					}),
				},
			}),
		}),
	})
end
