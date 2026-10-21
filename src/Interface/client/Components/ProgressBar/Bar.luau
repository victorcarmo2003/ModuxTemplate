--!strict
-- Bar: the 2D body of ProgressBar (track + fill + optional label). Fills its parent.
-- Kept apart from the BillboardGui so a story can preview it flat and so a screen HUD can reuse it.
-- Cartoon pass (AST-091 "Barras no mundo"): solid Ink track that is its own outline (proportional, so it stays light
-- from far away where a pixel UIStroke would not), a darker channel, and a two-tone fill with a gloss band.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local UseTween = require(script.Parent.Parent.UseTween)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke and UITextSizeConstraint are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	-- 0..1. Values above 1 read as "ready".
	Progress: () -> number,
	-- Overrides the cooking/ready colors (e.g. Theme.Color.Violet).
	FillColor: (() -> Color3)?,
	Text: (() -> string)?,
}

return function(props: Props): Frame
	const fill = UseTween(function()
		return UDim2.fromScale(math.clamp(props.Progress(), 0, 1), 1)
	end, 0.15, Enum.EasingStyle.Linear)

	const fillColor = props.FillColor
		or function(): Color3
			return if props.Progress() >= 1 then Theme.Color.Ready else Theme.Color.Cooking
		end

	const children: { Instance } = {
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),

		create("Frame")({
			Name = "Inner",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0.97, 0, 0.62, 0),
			BackgroundColor3 = Theme.Tone.Ink.Top,
			BackgroundTransparency = 0,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),

			create("Frame")({
				Name = "Fill",
				Size = fill,
				BackgroundColor3 = fillColor,
				Visible = function()
					return props.Progress() > 0
				end,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				create("UIGradient")({
					Rotation = 90,
					Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)),
				}),
				create("Frame")({
					Name = "Gloss",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0.12),
					Size = UDim2.fromScale(0.94, 0.3),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 0.5,
					create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				}),
			}),
		}),
	}

	const text = props.Text
	if text then
		table.insert(
			children,
			create("TextLabel")({
				Name = "Label",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 0.8),
				BackgroundTransparency = 1,
				FontFace = Theme.Font.Title,
				TextScaled = true,
				TextColor3 = Theme.Color.Text,
				Text = text,
				ZIndex = 2,
				createRaw("UIStroke")({
					Color = Theme.Color.Ink,
					Thickness = Theme.Stroke,
					LineJoinMode = Enum.LineJoinMode.Round,
				}),
			})
		)
	end

	return create("Frame")({
		Name = "Track",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.Ink,
		BackgroundTransparency = 0,
		children,
	})
end
