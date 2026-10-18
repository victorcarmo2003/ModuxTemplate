--!strict
-- DrainBar: a screen bar that empties as a wait runs out, with its status text INSIDE it (TASK-485, DEC-294: "barra que
-- se esvai com o texto dentro, sem número de segundos"). Ink pill track, Mustard fill anchored left that shrinks from
-- `Left` 1 (full) to 0 (empty), Cream text centred over both. Never a number, never red, no shake. Used by HudWipe
-- (nobody standing) and NightLostScreen (the lost night), so both waits read the same.
-- Status only: nothing clickable. Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIGradient is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	-- 0..1 of the wait still left (the fill).
	Left: () -> number,
	Text: () -> string,
	-- px at UI scale 1. Defaults 300 x 34, text 18.
	Width: number?,
	Height: number?,
	TextSize: number?,
	Name: string?,
	LayoutOrder: number?,
	AnchorPoint: Vector2?,
	Position: UDim2?,
}

const INSET = 3 -- px between the track outline and the fill

return function(props: Props): Frame
	const width = props.Width or 300
	const height = props.Height or 34
	const textSize = props.TextSize or 18

	return create("Frame")({
		Name = props.Name or "DrainBar",
		LayoutOrder = props.LayoutOrder or 0,
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Position = props.Position or UDim2.new(),
		Size = UDim2.fromOffset(width, height),
		BackgroundTransparency = 1,

		CartoonPanel({
			Name = "Track",
			Size = UDim2.fromScale(1, 1),
			Tone = Theme.Tone.Ink,
			Outline = Theme.Outline.Thick,
			Radius = Theme.Radius.Pill,
			Lip = 3,
			Children = {
				create("Frame")({
					Name = "Fill",
					Position = UDim2.fromOffset(INSET, INSET),
					Size = function()
						const alpha = math.clamp(props.Left(), 0, 1)
						return UDim2.new(alpha, -INSET * 2 * alpha, 1, -INSET * 2)
					end,
					BackgroundColor3 = Theme.Color.Mustard,
					BorderSizePixel = 0,
					Visible = function()
						return props.Left() > 0.01
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
			Name = "Text",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Box = UDim2.new(1, -16, 1, 0),
			TextSize = textSize,
			Color = Theme.Color.Cream,
			Stroke = Theme.TextStroke(textSize),
			XAlignment = Enum.TextXAlignment.Center,
			ZIndex = 3,
			Text = props.Text,
		}),
	}) :: Frame
end
