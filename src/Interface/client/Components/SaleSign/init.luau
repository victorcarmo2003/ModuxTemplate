--!strict
-- SaleSign: the text of the trailer sale sign in the lot (SIGN-T; FEAT-016, DEC-047; ui-text.md §13; style guide §3
-- "placa 'Available on Day 5' Mustard"). Mustard plate, Ink text: "Available on Day 5" before BuyFromDay,
-- "FOR SALE" from then until the purchase; the caller hides it after the purchase.
-- Pure: only props. VehicleController (TASK-058) owns the state and parents the BillboardGui.
-- Fixed pixel size (not studs) so the text stays >= 14 px on a phone at any distance it is drawn (Theme.MinTextSize).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke and UIPadding are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Adornee: Instance?,
	Visible: () -> boolean,
	Text: () -> string,
	-- World-space offset over the adornee (studs).
	Offset: Vector3?,
	MaxDistance: number?,
	Name: string?,
}

const WIDTH = 240
const HEIGHT = 56
const TEXT_SIZE = 24 -- px; above Theme.MinTextSize on the smallest phone

return function(props: Props): BillboardGui
	return create("BillboardGui")({
		Name = props.Name or "SaleSign",
		Adornee = props.Adornee,
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		StudsOffsetWorldSpace = props.Offset or Vector3.zero,
		MaxDistance = props.MaxDistance or 90,
		AlwaysOnTop = false,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Enabled = props.Visible,

		create("Frame")({
			Name = "Plate",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(0, HEIGHT - 8),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Theme.Color.Mustard,

			create("UICorner")({ CornerRadius = UDim.new(0.25, 0) }),
			createRaw("UIStroke")({
				Color = Theme.Color.Ink,
				Thickness = Theme.Stroke,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			createRaw("UIPadding")({
				PaddingLeft = UDim.new(0, 14),
				PaddingRight = UDim.new(0, 14),
			}),

			create("TextLabel")({
				Name = "Label",
				Size = UDim2.fromScale(0, 1),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				FontFace = Theme.Font.Title,
				TextSize = TEXT_SIZE,
				TextColor3 = Theme.Color.Ink,
				Text = props.Text,
			}),
		}),
	})
end
