--!strict
-- HudBanner: big title on a ribbon + one small line on a tag under it, upper middle of the screen (ui-text.md §12.2):
--   start of the night   "Night {n}" · "Stay open till 6:00 AM."
--   repeated night       "Night {n}" · "Same night. Same rules."  (never talks about chances, DEC-053)
--   6:00 AM (NightEnd)   "6:00 AM" · "You made it!"
-- Cartoon pass (AST-091): Violet ribbon (CartoonPanel) with two darker tails folded behind its ends, white title
-- with a heavy Ink stroke, the line on a Cream tag. Pops in with overshoot (Motion.Pop), shrinks away with the last text.
-- The owner sets `Banner` and clears it with false. Status only: nothing clickable (FEAT-032). Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
const source = Vide.source
const effect = Vide.effect
const untrack = Vide.untrack
-- Vide 0.4.1 types `create` for 19 classes only; UIScale and UIStroke are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Banner = { Title: string, Line: string }

-- false = hidden (a Source of an optional type is ambiguous to call under the new solver)
export type Shown = Banner | false

export type Props = {
	Banner: () -> Shown,
	Name: string?,
	AnchorPoint: Vector2?,
	Position: UDim2?,
}

const TITLE_SIZE = 36
const LINE_SIZE = 16
const RIBBON = 52 -- ribbon height
const TAIL = 32 -- tail width
const WIDTH = 360
const HEIGHT = RIBBON + 12 + LINE_SIZE + 22

-- One folded tail behind a ribbon end: darker Violet, lower than the ribbon, with an Ink outline. The list layout of
-- the ribbon overlaps it with the band (negative padding) and the band draws over it (ZIndex).
local function tail(order: number): Frame
	const tone = Theme.Tone.Violet
	return create("Frame")({
		Name = if order < 2 then "TailLeft" else "TailRight",
		LayoutOrder = order,
		Size = UDim2.fromOffset(TAIL, RIBBON + 10),
		BackgroundTransparency = 1,
		ZIndex = 0,
		create("Frame")({
			Name = "Tail",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, RIBBON - 16),
			BackgroundColor3 = tone.Lip,
			create("UICorner")({ CornerRadius = Theme.Radius.Small }),
			createRaw("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Theme.Color.Ink,
				Thickness = Theme.Outline.Normal,
			}),
		}),
	})
end

return function(props: Props): Frame
	const last = source(untrack(props.Banner))
	effect(function()
		const banner = props.Banner()
		if banner then
			last(banner)
		end
	end)
	const scale = Motion.Pop(function()
		return props.Banner() ~= false
	end)

	const text = function(field: "Title" | "Line"): () -> string
		return function()
			const banner = last()
			if not banner then
				return ""
			end
			return if field == "Title" then banner.Title else banner.Line
		end
	end

	return create("Frame")({
		Name = props.Name or "HudBanner",
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		Position = props.Position or UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundTransparency = 1,
		Visible = function()
			return last() ~= false and scale() > 0.02
		end,

		createRaw("UIScale")({ Scale = scale }),

		-- Ribbon, as wide as the title, centred
		create("Frame")({
			Name = "Ribbon",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(0, RIBBON + 10),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,

			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, -18),
			}),
			tail(1),
			tail(3),

			CartoonPanel({
				Name = "Band",
				LayoutOrder = 2,
				Size = UDim2.fromOffset(0, RIBBON),
				AutomaticSize = Enum.AutomaticSize.X,
				Tone = Theme.Tone.Violet,
				Outline = Theme.Outline.Thick,
				Radius = Theme.Radius.Chip,
				Lip = 6,
				Padding = { Left = 28, Right = 28 },
				ZIndex = 1,
				Children = {
					CartoonLabel({
						Box = UDim2.new(0, 0, 1, 0),
						AutomaticSize = Enum.AutomaticSize.X,
						Text = text("Title"),
						TextSize = TITLE_SIZE,
						Stroke = 4,
					}),
				},
			}),
		}),

		-- Line on a Cream tag under the ribbon
		CartoonPanel({
			Name = "Line",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, RIBBON + 12),
			Size = UDim2.fromOffset(0, LINE_SIZE + 18),
			AutomaticSize = Enum.AutomaticSize.X,
			Rotation = -1.5,
			Tone = Theme.Tone.Cream,
			Outline = Theme.Outline.Normal,
			Lip = 3,
			Padding = { Left = 14, Right = 14 },
			Visible = function()
				return text("Line")() ~= ""
			end,
			Children = {
				CartoonLabel({
					Box = UDim2.new(0, 0, 1, 0),
					AutomaticSize = Enum.AutomaticSize.X,
					Text = text("Line"),
					TextSize = LINE_SIZE,
					Color = Theme.Color.Dark,
					Stroke = 0,
				}),
			},
		}),
	})
end
