--!strict
-- StockCounter: "7/12" pill over a stock station in the world (FEAT-007 "Indicador", style guide §7.1 pill).
-- Ink pill with white text; turns Low (red) when the station is about to run out. Fixed pixel size (not studs),
-- so the text keeps >= 14 px on a phone at any distance. Not AlwaysOnTop: walls and the cart hide it.
-- Pure: only props. The caller parents the returned BillboardGui (the adornee itself is fine: no input here).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)

const create = Vide.create
const spring = Vide.spring
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke and UIScale are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Adornee: Instance?,
	Text: () -> string, -- "7/12"
	Low: () -> boolean,
	Visible: (() -> boolean)?,
	StudsOffset: Vector3?,
	MaxDistance: number?,
	Name: string?,
}

const WIDTH = 76
const HEIGHT = 30
const TEXT_SIZE = 20

return function(props: Props): BillboardGui
	const visible = props.Visible or function(): boolean
		return true
	end

	-- Small pop when the counter crosses into Low, so the change is noticed without a sound.
	const scale = spring(function()
		return if props.Low() then 1.12 else 1
	end, 0.25, 0.45)

	return create("BillboardGui")({
		Name = props.Name or "StockCounter",
		Adornee = props.Adornee,
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		StudsOffset = props.StudsOffset or Vector3.zero,
		MaxDistance = props.MaxDistance or 40,
		AlwaysOnTop = false,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Enabled = visible,

		create("Frame")({
			Name = "Pill",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = function()
				return if props.Low() then Theme.Color.Low else Theme.Color.Ink
			end,
			BackgroundTransparency = function()
				return if props.Low() then 0.05 else Theme.Transparency.Panel
			end,

			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			createRaw("UIScale")({ Scale = scale }),

			create("TextLabel")({
				Name = "Count",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				FontFace = Theme.Font.Title,
				TextSize = TEXT_SIZE,
				TextColor3 = Theme.Color.Text,
				Text = props.Text,
				createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Stroke }),
			}),
		}),
	})
end
