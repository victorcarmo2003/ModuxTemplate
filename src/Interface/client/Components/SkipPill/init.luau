--!strict
-- SkipPill: the cutscene skip vote (DEC-078, DEC-194; style guide §7.2 "Skip da cutscene": bottom right, only in a
-- cutscene, pill "Skip (1/2)" with the vote count; ui-text.md §7: "Hold to skip" · "Skip {votes}/{needed}" ·
-- "Skipping...").
-- ONE fixed-size pill (no AutomaticSize, no layout on the root: a size driven by its content grew to a tall block on
-- desktop, owner screenshot 2026-10-12), visible from the first second of the scene:
--   idle     key chip (desktop/gamepad; none on touch) + "Hold to skip" on a translucent Ink pill with an outline
--   holding  a Mustard fill grows from the left (hold progress); "Skip (votes/needed)"; stays full once the own vote is in
--   server   "Skipping..." when the count reaches the threshold
-- Sits left of the mobile jump button and right of the call strip, so it never covers either on a phone. The pill is
-- the pointer control (>= 44 px tall; mouse hold, touch hold): press/release go to OnPress/OnRelease; the owner times
-- the hold and binds keyboard/gamepad.
-- Cartoon pass (AST-091): Ink CartoonPanel pill with a Mustard hold fill, Cream key chip, squash on press.
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
const PILL_WIDTH = 176 -- fixed (px at UI scale 1): chip 28 + "Hold to skip" at 17 px + padding
const TEXT_SIZE = 17 -- >= Theme.MinTextSize on the smallest phone
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
		if not (pressed() or props.Voted() or props.Votes() > 0 or props.Progress() > 0) then
			return HINT
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
		-- anchored at its centre (bottom-right corner where it always sat): pop and press scale from the middle
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -(props.Right or 112) - PILL_WIDTH / 2, 1, -(props.Bottom or 24) - PILL_HEIGHT / 2),
		Size = UDim2.fromOffset(PILL_WIDTH, PILL_HEIGHT),
		BackgroundTransparency = 1,
		Visible = function()
			return props.Visible() or pop() > 0.02
		end,

		createRaw("UIScale")({
			Scale = function()
				return pop() * press()
			end,
		}),

		create("TextButton")({
			Name = "Pill",
			Size = UDim2.fromOffset(PILL_WIDTH, PILL_HEIGHT),
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
				Size = UDim2.fromOffset(PILL_WIDTH, PILL_HEIGHT),
				Tone = Theme.Tone.Ink,
				Transparency = Theme.Transparency.Panel,
				Outline = Theme.Outline.Thick,
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
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						ZIndex = 1,
						createRaw("UIPadding")({
							PaddingLeft = UDim.new(0, 8),
							PaddingRight = UDim.new(0, 12),
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
