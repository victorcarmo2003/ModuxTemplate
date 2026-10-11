--!strict
-- StockCounter: "7/12" pill over a stock station in the world (FEAT-007 "Indicador", style guide §7.1 pill).
-- Ink pill with white text; turns Low (red) when the station is about to run out. Fixed pixel size (not studs),
-- so the text keeps >= 14 px on a phone at any distance. Not AlwaysOnTop: walls and the cart hide it.
-- Pure: only props. The caller parents the returned BillboardGui (the adornee itself is fine: no input here).
-- Cartoon pass (AST-091): Ink CartoonPanel pill (Ketchup when Low) with a heavy-stroke number.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Cinematic = require(script.Parent.Parent.Cinematic)
local Theme = require(script.Parent.Theme)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

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

const WIDTH = 84
const HEIGHT = 36
const LOW = Theme.ToneOf(Theme.Color.Low)
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
		-- Off while a cinematic owns the screen (Interface/Cinematic).
		Enabled = function()
			return visible() and not Cinematic.Active()
		end,

		CartoonPanel({
			Name = "Pill",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -6, 1, -6),
			Tone = function()
				return if props.Low() then LOW else Theme.Tone.Ink
			end,
			Transparency = function()
				return if props.Low() then 0 else Theme.Transparency.Panel
			end,
			Decor = {
				createRaw("UIScale")({ Scale = scale }),
			},
			Children = {
				CartoonLabel({
					Name = "Count",
					Box = UDim2.fromScale(1, 1),
					TextSize = TEXT_SIZE,
					Text = props.Text,
				}),
			},
		}),
	})
end
