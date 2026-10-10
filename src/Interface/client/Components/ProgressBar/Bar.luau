--!strict
-- Bar: the 2D body of ProgressBar (track + fill + optional label). Fills its parent.
-- Kept apart from the BillboardGui so a story can preview it flat and so a screen HUD can reuse it.
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
	-- Overrides the cooking/ready colors (e.g. the thief bar uses Theme.Color.Violet).
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
			Size = UDim2.fromScale(0.96, 0.7),
			BackgroundTransparency = 1,

			create("Frame")({
				Name = "Fill",
				Size = fill,
				BackgroundColor3 = fillColor,
				Visible = function()
					return props.Progress() > 0
				end,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
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
				createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Stroke }),
			})
		)
	end

	return create("Frame")({
		Name = "Track",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.Ink,
		BackgroundTransparency = Theme.Transparency.Track,
		children,
	})
end
