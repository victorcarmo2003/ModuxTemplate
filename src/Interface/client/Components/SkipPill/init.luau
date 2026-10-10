--!strict
-- SkipPill: the cutscene skip vote (DEC-078, DEC-194; style guide §7.2 "Skip da cutscene": bottom right, only in a
-- cutscene, pill "Skip (1/2)" with the vote count; ui-text.md §7: "Hold to skip" · "Skip {votes}/{needed}" ·
-- "Skipping...").
--   hint   "Hold to skip" above the pill while the own vote is not in
--   pill   key chip (desktop/gamepad; none on touch) + "Skip (votes/needed)"; fills Mustard while held, stays full
--          once the own vote is in; "Skipping..." when the server count reaches the threshold
-- Sits left of the mobile jump button and right of the call strip, so it never covers either on a phone. The pill is
-- the mobile control (>= 44 px tall): press/release go to OnPress/OnRelease; the owner times the hold.
-- Pure: only props. Votes and Needed come from the server (`Cutscene` set); nothing is counted here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)

const create = Vide.create
const spring = Vide.spring
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
const PILL_HEIGHT = 48 -- >= Theme.MinTouch
const MIN_WIDTH = 150
const TEXT_SIZE = 20 -- >= Theme.MinTextSize on the smallest phone
const HINT_SIZE = 16
const CHIP_SIZE = 32
const FILL_TRANSPARENCY = 0.15

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

	const scale = spring(function()
		if not props.Visible() then
			return 0.6
		end
		return if pressed() then 0.95 else 1
	end, 0.18, 0.7)
	const alpha = spring(function()
		return if props.Visible() then 0 else 1
	end, 0.18, 1)

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
			return props.Visible() or alpha() < 0.99
		end,

		createRaw("UIScale")({ Scale = scale }),
		createRaw("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),

		create("TextLabel")({
			Name = "Hint",
			LayoutOrder = 1,
			Size = UDim2.fromOffset(MIN_WIDTH, HINT_SIZE + 6),
			BackgroundTransparency = 1,
			FontFace = Theme.Font.Body,
			TextSize = HINT_SIZE,
			TextColor3 = Theme.Color.Cream,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextTransparency = alpha,
			Text = HINT,
			Visible = function()
				return not props.Voted() and not skipping()
			end,
			createRaw("UIStroke")({
				Color = Theme.Color.Ink,
				Thickness = Theme.Stroke,
				Transparency = alpha,
			}),
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

			create("CanvasGroup")({
				Name = "Body",
				Size = UDim2.fromOffset(0, PILL_HEIGHT),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = Theme.Color.Ink,
				BackgroundTransparency = Theme.Transparency.Panel,
				GroupTransparency = alpha,

				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				createRaw("UISizeConstraint")({ MinSize = Vector2.new(MIN_WIDTH, PILL_HEIGHT) }),

				-- Hold fill, under the content
				create("Frame")({
					Name = "Fill",
					Size = function()
						return UDim2.fromScale(fill(), 1)
					end,
					BackgroundColor3 = Theme.Color.Mustard,
					BackgroundTransparency = FILL_TRANSPARENCY,
					BorderSizePixel = 0,
					ZIndex = 0,
					Visible = function()
						return fill() > 0
					end,
				}),

				create("Frame")({
					Name = "Content",
					Size = UDim2.fromOffset(0, PILL_HEIGHT),
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

					create("Frame")({
						Name = "Chip",
						LayoutOrder = 1,
						Size = UDim2.fromOffset(CHIP_SIZE, CHIP_SIZE),
						BackgroundColor3 = Theme.Color.Text,
						Visible = function()
							return props.KeyLabel() ~= ""
						end,
						create("UICorner")({ CornerRadius = UDim.new(0, 8) }),
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
						Name = "Label",
						LayoutOrder = 2,
						Size = UDim2.fromOffset(0, PILL_HEIGHT),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						FontFace = Theme.Font.Title,
						TextSize = TEXT_SIZE,
						TextColor3 = function()
							return if full() then Theme.Color.Ink else Theme.Color.Text
						end,
						Text = label,
						ZIndex = 2,
						createRaw("UIStroke")({
							Color = Theme.Color.Ink,
							Thickness = Theme.Stroke,
							Enabled = function()
								return not full()
							end,
						}),
					}),
				}),
			}),
		}),
	})
end
