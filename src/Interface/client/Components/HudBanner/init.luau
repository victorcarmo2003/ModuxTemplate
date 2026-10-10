--!strict
-- HudBanner: big title + one small line in the upper middle of the screen, fades in and out (ui-text.md §12.2):
--   start of the night   "Night {n}" · "Stay open till 6:00 AM."
--   repeated night       "Night {n}" · "Same night. Same rules."  (never talks about chances, DEC-053)
--   6:00 AM (NightEnd)   "6:00 AM" · "You made it!"
-- The owner sets `Banner` and clears it with false. Status only: nothing clickable (FEAT-032). Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)

const create = Vide.create
const source = Vide.source
const spring = Vide.spring
const effect = Vide.effect
const untrack = Vide.untrack
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke is not among them.
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

const TITLE_SIZE = 48
const LINE_SIZE = 20
const WIDTH = 420

return function(props: Props): CanvasGroup
	const last = source(untrack(props.Banner))
	effect(function()
		const banner = props.Banner()
		if banner then
			last(banner)
		end
	end)
	const alpha = spring(function()
		return if props.Banner() then 0 else 1
	end, 0.35, 1)

	const text = function(field: "Title" | "Line"): () -> string
		return function()
			const banner = last()
			if not banner then
				return ""
			end
			return if field == "Title" then banner.Title else banner.Line
		end
	end

	return create("CanvasGroup")({
		Name = props.Name or "HudBanner",
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		Position = props.Position or UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(WIDTH, TITLE_SIZE + LINE_SIZE + 24),
		BackgroundTransparency = 1,
		GroupTransparency = alpha,
		Visible = function()
			return last() ~= false and (props.Banner() ~= false or alpha() < 0.99)
		end,

		create("TextLabel")({
			Name = "Title",
			Size = UDim2.new(1, 0, 0, TITLE_SIZE + 4),
			BackgroundTransparency = 1,
			FontFace = Theme.Font.Title,
			TextSize = TITLE_SIZE,
			TextColor3 = Theme.Color.Text,
			Text = text("Title"),
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 3 }),
		}),
		create("TextLabel")({
			Name = "Line",
			Position = UDim2.fromOffset(0, TITLE_SIZE + 8),
			Size = UDim2.new(1, 0, 0, LINE_SIZE + 8),
			BackgroundTransparency = 1,
			FontFace = Theme.Font.Body,
			TextSize = LINE_SIZE,
			TextColor3 = Theme.Color.Cream,
			Text = text("Line"),
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Stroke }),
		}),
	})
end
