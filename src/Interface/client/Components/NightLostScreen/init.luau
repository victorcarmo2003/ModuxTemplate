--!strict
-- NightLostScreen: the cover while a lost night restarts (TASK-338; owner request 2026-10-15, Provisional). Shown over
-- the whole NightLost phase so the frozen bodies and the held clock never read as a hang: an Ink fade over the screen,
-- the title ("Everyone fainted…") and a DrainBar that empties until the restart with what comes next inside it
-- ("Restarting the night" / "No chances left"). Clean faint screen (TASK-485, DEC-294): no separate tag, no seconds.
-- Mustard and Ink, never red, no shake.
-- The card pops in once (Motion.Pop); the fade follows Motion.Reveal (instant with reduced motion).
-- Team life (DEC-317, design/faint-screen-flow.md §3 caso C): with `Lives`, a LifeHeart over the title shakes, then
-- breaks (`Broken`) and its number drops by one; the owner switches the title to LAST CHANCE (Mustard) at that moment.
-- Status only: nothing clickable (Active = false everywhere). Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Motion = require(script.Parent.Motion)
local DrainBar = require(script.Parent.DrainBar)
local CartoonLabel = require(script.Parent.CartoonLabel)
local LifeHeart = require(script.Parent.LifeHeart)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke and UIScale are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Shown: () -> boolean,
	Title: () -> string,
	Line: () -> string,
	-- Title colour. Default white.
	TitleColor: (() -> Color3)?,
	-- Team chances before this loss; nil = no heart.
	Lives: (() -> number)?,
	-- The heart broke (one chance spent).
	Broken: (() -> boolean)?,
	-- What got me and how to get past it (DEC-317 etapa D); nil value = no tip.
	Tip: (() -> { Title: string, Tip: string }?)?,
	TipLabel: string?,
	-- 0..1 of the wait done (the bar drains as it grows)
	Progress: () -> number,
	-- Theme.ScaleOf(viewport); default 1
	Scale: (() -> number)?,
	Name: string?,
}

const COVER = 0.12 -- background transparency at full fade (the world stays faintly visible)
const WIDTH = 360
const TITLE_SIZE = 40
const BAR_HEIGHT = 36
const BAR_TEXT = 19
const HEART = 110

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

			if props.Lives
				then create("Frame")({
					Name = "TeamLife",
					LayoutOrder = 0,
					Size = UDim2.fromOffset(HEART + 40, HEART + 20),
					BackgroundTransparency = 1,
					LifeHeart({
						Lives = function()
							const lives = (props.Lives :: () -> number)()
							return if props.Broken and props.Broken() then lives - 1 else lives
						end,
						Mode = function()
							return if props.Broken and props.Broken() then "Broken" else "Danger"
						end,
						Crack = function()
							return 1
						end,
						Size = HEART,
					}),
				})
				else nil,
			CartoonLabel({
				Name = "Title",
				LayoutOrder = 1,
				Box = UDim2.new(1, 0, 0, TITLE_SIZE + 10),
				Text = props.Title,
				TextSize = TITLE_SIZE,
				Color = props.TitleColor,
				Stroke = 4,
			}),

			-- DEC-318: with the team life heart the screen is only the heart and the title (no bar)
			if props.Lives == nil
				then DrainBar({
					Name = "Wait",
					LayoutOrder = 2,
					Left = function()
						return 1 - math.clamp(props.Progress(), 0, 1)
					end,
					Text = props.Line,
					Width = WIDTH - 20,
					Height = BAR_HEIGHT,
					TextSize = BAR_TEXT,
				})
				else nil,

			create("Frame")({
				Name = "Tip",
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Visible = function()
					return props.Tip ~= nil and props.Tip() ~= nil
				end,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 2),
				}),
				CartoonLabel({
					Name = "Label",
					LayoutOrder = 1,
					Text = props.TipLabel or "WHAT GOT YOU",
					TextSize = 13,
					Color = Theme.Color.Mustard,
				}),
				CartoonLabel({
					Name = "Cause",
					LayoutOrder = 2,
					Box = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					Wrapped = true,
					Text = function()
						const tip = if props.Tip then props.Tip() else nil
						return if tip then tip.Title else ""
					end,
					TextSize = 22,
				}),
				CartoonLabel({
					Name = "Advice",
					LayoutOrder = 3,
					Box = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					Wrapped = true,
					Text = function()
						const tip = if props.Tip then props.Tip() else nil
						return if tip then tip.Tip else ""
					end,
					TextSize = 16,
					Color = Theme.Color.Cream,
				}),
			}),
		}),
	}) :: Frame
end
