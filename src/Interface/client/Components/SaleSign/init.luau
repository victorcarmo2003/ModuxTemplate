--!strict
-- SaleSign: the text of the trailer sale sign in the lot (SIGN-T; FEAT-016, DEC-047; ui-text.md §13; style guide §3
-- "placa 'Available on Day 5' Mustard"). Mustard plate, Ink text: "Available on Day 5" before BuyFromDay,
-- "FOR SALE" from then until the purchase; the caller hides it after the purchase.
-- Pure: only props. VehicleController (TASK-058) owns the state and parents the BillboardGui.
-- Fixed pixel size (not studs) so the text stays >= 14 px on a phone at any distance it is drawn (Theme.MinTextSize).
-- Cartoon pass (AST-091): Mustard CartoonPanel plate with studs, a slight tilt, Ink text.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create

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

		CartoonPanel({
			Name = "Plate",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(0, HEIGHT - 8),
			AutomaticSize = Enum.AutomaticSize.X,
			Rotation = -2,
			Tone = Theme.Tone.Mustard,
			Outline = Theme.Outline.Thick,
			Radius = Theme.Radius.Chip,
			Studs = true,
			Padding = { Left = 14, Right = 14 },
			Children = {
				CartoonLabel({
					Name = "Label",
					Box = UDim2.fromScale(0, 1),
					AutomaticSize = Enum.AutomaticSize.X,
					TextSize = TEXT_SIZE,
					Color = Theme.Color.Dark,
					Stroke = 0,
					Text = props.Text,
				}),
			},
		}),
	})
end
