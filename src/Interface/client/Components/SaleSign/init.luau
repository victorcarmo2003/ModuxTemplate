--!strict
-- SaleSign: the text of the trailer sale sign in the lot (SIGN-T; FEAT-016, DEC-047; ui-text.md §13; style guide §3
-- "placa 'Available on Day 5' Mustard"). Mustard plate, Ink text: "Available on Day 5" before BuyFromDay,
-- "FOR SALE" from then until the purchase; the caller hides it after the purchase.
-- Pure: only props. VehicleController (TASK-058) owns the state and parents the BillboardGui.
-- Sized in studs (user request 2026-10-11: the pixel-sized plate stayed huge from the far end of the street and covered
-- the whole trailer): a small hung plate that shrinks with distance like the real sign, MaxDistance short (40 studs by
-- default), text scaled to the plate (~20 px at 12 studs on the smallest phone). Off while a cinematic owns the
-- screen (Interface/Cinematic).
-- Cartoon pass (AST-091): Mustard CartoonPanel plate with studs, a slight tilt, Ink text, thin outline (studs-sized
-- tags keep a light outline from far away, like ShelfTag).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Cinematic = require(script.Parent.Parent.Cinematic)
local Theme = require(script.Parent.Theme)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIPadding is not among them.
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

const WIDTH = 4.2 -- studs
const HEIGHT = 1.1
const MAX_TEXT = 48
const DEFAULT_DISTANCE = 40

return function(props: Props): BillboardGui
	return create("BillboardGui")({
		Name = props.Name or "SaleSign",
		Adornee = props.Adornee,
		Size = UDim2.fromScale(WIDTH, HEIGHT),
		StudsOffsetWorldSpace = props.Offset or Vector3.zero,
		MaxDistance = props.MaxDistance or DEFAULT_DISTANCE,
		AlwaysOnTop = false,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Enabled = function()
			return props.Visible() and not Cinematic.Active()
		end,

		CartoonPanel({
			Name = "Plate",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.96, 0.9),
			Rotation = -2,
			Tone = Theme.Tone.Mustard,
			Outline = Theme.Outline.Thin,
			Lip = 3,
			Radius = UDim.new(0.25, 0),
			Studs = true,
			Children = {
				CartoonLabel({
					Name = "Label",
					Box = UDim2.fromScale(1, 1),
					Scaled = true,
					MaxTextSize = MAX_TEXT,
					TextSize = 20,
					Color = Theme.Color.Dark,
					Stroke = 0,
					Text = props.Text,
					Children = {
						createRaw("UIPadding")({
							PaddingTop = UDim.new(0.14, 0),
							PaddingBottom = UDim.new(0.14, 0),
							PaddingLeft = UDim.new(0.05, 0),
							PaddingRight = UDim.new(0.05, 0),
						}),
					},
				}),
			},
		}),
	})
end
