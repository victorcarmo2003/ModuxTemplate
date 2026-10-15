--!strict
-- NightLostScreen: the cover while a lost night restarts (TASK-338; owner request 2026-10-15, Provisional). Shown over
-- the whole NightLost phase so the frozen bodies and the held clock never read as a hang: an Ink fade over the screen,
-- the title ("Everyone fainted…"), a Cream tag with what comes next ("Restarting the night") and a Mustard bar that
-- fills until the restart, with the whole seconds left on its right. Mustard and Ink, never red, no shake.
-- The card pops in once (Motion.Pop); the fade follows Motion.Reveal (instant with reduced motion).
-- Status only: nothing clickable (Active = false everywhere). Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke and UIScale are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Shown: () -> boolean,
	Title: () -> string,
	Line: () -> string,
	-- 0..1 of the wait done (the bar fill)
	Progress: () -> number,
	-- whole seconds left (< 0 = no number)
	Seconds: () -> number,
	-- Theme.ScaleOf(viewport); default 1
	Scale: (() -> number)?,
	Name: string?,
}

const COVER = 0.12 -- background transparency at full fade (the world stays faintly visible)
const WIDTH = 360
const TITLE_SIZE = 40
const LINE_SIZE = 18
const BAR_HEIGHT = 26
const BAR_INSET = 5
const COUNT_WIDTH = 44

local function bar(progress: () -> number, seconds: () -> number): Frame
	return create("Frame")({
		Name = "Wait",
		LayoutOrder = 3,
		Size = UDim2.fromOffset(WIDTH - 40, BAR_HEIGHT),
		BackgroundTransparency = 1,

		CartoonPanel({
			Name = "Track",
			Size = UDim2.new(1, -COUNT_WIDTH, 1, 0),
			Tone = Theme.Tone.Ink,
			Outline = Theme.Outline.Thick,
			Radius = Theme.Radius.Pill,
			Lip = 3,
			Children = {
				create("Frame")({
					Name = "Fill",
					Position = UDim2.fromOffset(BAR_INSET - 2, BAR_INSET - 2),
					Size = function()
						const alpha = math.clamp(progress(), 0, 1)
						return UDim2.new(alpha, -(BAR_INSET - 2) * 2 * alpha, 1, -(BAR_INSET - 2) * 2)
					end,
					BackgroundColor3 = Theme.Color.Mustard,
					BorderSizePixel = 0,
					Visible = function()
						return progress() > 0.01
					end,
					create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
					createRaw("UIGradient")({
						Rotation = 90,
						Color = ColorSequence.new(Theme.Tone.Mustard.Top, Theme.Tone.Mustard.Bottom),
					}),
				}),
			},
		}),

		CartoonLabel({
			Name = "Count",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Box = UDim2.fromOffset(COUNT_WIDTH - 6, BAR_HEIGHT + 6),
			TextSize = 26,
			Color = Theme.Color.Mustard,
			XAlignment = Enum.TextXAlignment.Right,
			Text = function()
				const left = seconds()
				return if left >= 0 then tostring(left) else ""
			end,
		}),
	}) :: Frame
end

return function(props: Props): Frame
	const fade = Motion.Reveal(props.Shown)
	const pop = Motion.Pop(props.Shown)

	return create("Frame")({
		Name = props.Name or "NightLostScreen",
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
		Active = false,
		BackgroundColor3 = Theme.Color.Ink,
		BackgroundTransparency = function()
			return 1 - (1 - COVER) * fade()
		end,
		Visible = function()
			return fade() > 0.01
		end,

		create("Frame")({
			Name = "Card",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromOffset(WIDTH, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,

			createRaw("UIScale")({
				Scale = function()
					const scale = if props.Scale then props.Scale() else 1
					return scale * pop()
				end,
			}),

			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 14),
			}),

			CartoonLabel({
				Name = "Title",
				LayoutOrder = 1,
				Box = UDim2.new(1, 0, 0, TITLE_SIZE + 10),
				Text = props.Title,
				TextSize = TITLE_SIZE,
				Stroke = 4,
			}),

			CartoonPanel({
				Name = "Line",
				LayoutOrder = 2,
				Size = UDim2.fromOffset(0, LINE_SIZE + 18),
				AutomaticSize = Enum.AutomaticSize.X,
				Rotation = -1.5,
				Tone = Theme.Tone.Cream,
				Lip = 3,
				Padding = { Left = 16, Right = 16 },
				Children = {
					CartoonLabel({
						Box = UDim2.new(0, 0, 1, 0),
						AutomaticSize = Enum.AutomaticSize.X,
						Text = props.Line,
						TextSize = LINE_SIZE,
						Color = Theme.Color.Dark,
						Stroke = 0,
					}),
				},
			}),

			bar(props.Progress, props.Seconds),
		}),
	}) :: Frame
end
