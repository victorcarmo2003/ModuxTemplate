--!strict
-- StockPlate: the ingredient plate on the front of a topping bowl (`Label_<Ing>`, DEC-156; FEAT-007 counter).
-- SurfaceGui on one face of the plate: ingredient icon + "7/12" (red at Low). Until the icons exist (Q-152) the
-- icon is a placeholder: the ingredient name on a swatch of its palette color (style guide §2.1).
-- Lit by the scene (LightInfluence 1) so the plate darkens at night like the bowl it is glued to.
-- Pure: only props. The caller picks the face that looks at the operator and parents the SurfaceGui.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke and UIPadding are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Adornee: BasePart?,
	Face: Enum.NormalId,
	Icon: () -> string, -- rbxassetid; "" = placeholder (Q-152)
	Label: string, -- ingredient name, shown by the placeholder
	Color: Color3, -- placeholder swatch
	Text: () -> string, -- "7/12"
	Low: () -> boolean,
	ShowCount: () -> boolean,
	-- Icon above the count (tall plate) instead of beside it (wide plate). Default: beside.
	Vertical: boolean?,
	PixelsPerStud: number?,
	MaxDistance: number?,
	Name: string?,
}

-- Ink or white text, whichever reads on the swatch.
local function textOn(color: Color3): Color3
	const luminance = 0.2126 * color.R + 0.7152 * color.G + 0.0722 * color.B
	return if luminance > 0.6 then Theme.Color.Ink else Theme.Color.Text
end

return function(props: Props): SurfaceGui
	const vertical = props.Vertical == true
	const hasIcon = function(): boolean
		return props.Icon() ~= ""
	end
	-- Icon cell is a square on the short side; the count takes the rest.
	const iconSize = if vertical then UDim2.new(1, 0, 0.58, 0) else UDim2.new(0.42, 0, 1, 0)
	const countSize = if vertical then UDim2.new(1, 0, 0.4, 0) else UDim2.new(0.56, 0, 1, 0)

	return create("SurfaceGui")({
		Name = props.Name or "StockPlate",
		Adornee = props.Adornee,
		Face = props.Face,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = props.PixelsPerStud or 200,
		LightInfluence = 1,
		AlwaysOnTop = false,
		MaxDistance = props.MaxDistance or 60,
		ResetOnSpawn = false,
		ClipsDescendants = true,

		create("Frame")({
			Name = "Plate",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Color.Cream,

			createRaw("UIPadding")({
				PaddingTop = UDim.new(0.08, 0),
				PaddingBottom = UDim.new(0.08, 0),
				PaddingLeft = UDim.new(0.05, 0),
				PaddingRight = UDim.new(0.05, 0),
			}),
			create("UIListLayout")({
				FillDirection = if vertical then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0.02, 0),
			}),

			create("Frame")({
				Name = "IconCell",
				LayoutOrder = 1,
				Size = iconSize,
				BackgroundTransparency = 1,

				create("ImageLabel")({
					Name = "Icon",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					ScaleType = Enum.ScaleType.Fit,
					Image = props.Icon,
					Visible = hasIcon,
				}),

				create("Frame")({
					Name = "Placeholder",
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = props.Color,
					Visible = function()
						return not hasIcon()
					end,
					create("UICorner")({ CornerRadius = UDim.new(0.2, 0) }),
					create("TextLabel")({
						Size = UDim2.fromScale(0.92, 0.9),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Theme.Font.Body,
						TextScaled = true,
						TextWrapped = true,
						TextColor3 = textOn(props.Color),
						Text = props.Label,
					}),
				}),
			}),

			create("TextLabel")({
				Name = "Count",
				LayoutOrder = 2,
				Size = countSize,
				BackgroundTransparency = 1,
				FontFace = Theme.Font.Title,
				TextScaled = true,
				TextColor3 = function()
					return if props.Low() then Theme.Color.Low else Theme.Color.Ink
				end,
				Text = props.Text,
				Visible = props.ShowCount,
			}),
		}),
	})
end
