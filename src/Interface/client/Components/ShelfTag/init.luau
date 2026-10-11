--!strict
-- ShelfTag: price tag over a Mart shelf (FEAT-008, DEC-015, DEC-180; style guide §7.3 "etiqueta Mustard").
-- Three looks:
--   Price       Mustard tag "$6"
--   NoCash      same tag in red: the party cannot pay it (FEAT-008); the server refuses the buy anyway
--   OutOfStock  Cream tag "Out of stock" and, under it, an optional sub line ("Day 3", Provisional, DEC-180)
-- Pure: only props. The caller parents the BillboardGui (PlayerGui, with Adornee = the shelf anchor) and decides
-- the texts. Sized in studs, so it shrinks with distance like a real tag; at the prompt radius (7 studs) on the
-- smallest phone the price is ~22 px and the sub line ~15 px (frontend rule: text >= 14 px).
-- Cartoon pass (AST-091): the tag is a CartoonPanel (Mustard / Ketchup / Cream) with a thin Ink outline (the tag is
-- sized in studs: a thick pixel outline would swallow it from far away), tilted a little like a hung price tag.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke, UIPadding and UITextSizeConstraint are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Mode = "Price" | "NoCash" | "OutOfStock"

export type Props = {
	Adornee: Instance?,
	Visible: () -> boolean,
	Mode: () -> Mode,
	-- "$6" or "Out of stock"
	Text: () -> string,
	-- Line under the tag ("Day 3"); "" hides it.
	SubText: () -> string,
	StudsOffset: Vector3?,
	MaxDistance: number?,
	Name: string?,
}

const WIDTH = 2.4 -- studs
const HEIGHT = 1.1
const TAG_HEIGHT = 0.6 -- fraction of HEIGHT
const PRICE_WIDTH = 0.5 -- fraction of WIDTH for a short "$6"
const MAX_TEXT = 64

const TONE: { [Mode]: Theme.Tone } = {
	Price = Theme.Tone.Mustard,
	NoCash = Theme.ToneOf(Theme.Color.NoCash),
	OutOfStock = Theme.Tone.Cream,
}

return function(props: Props): BillboardGui
	local function hasSub(): boolean
		return props.SubText() ~= ""
	end

	return create("BillboardGui")({
		Name = props.Name or "ShelfTag",
		Adornee = props.Adornee,
		Size = UDim2.fromScale(WIDTH, HEIGHT),
		StudsOffset = props.StudsOffset or Vector3.zero,
		MaxDistance = props.MaxDistance or 30,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Enabled = props.Visible,

		CartoonPanel({
			Name = "Tag",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.02),
			Size = function()
				return UDim2.fromScale(if props.Mode() == "OutOfStock" then 0.96 else PRICE_WIDTH, TAG_HEIGHT)
			end,
			Rotation = -3,
			Tone = function()
				return TONE[props.Mode()]
			end,
			Outline = Theme.Outline.Thin,
			Lip = 3,
			Radius = UDim.new(0.3, 0),
			Children = {
				CartoonLabel({
					Name = "Label",
					Box = UDim2.fromScale(1, 1),
					Scaled = true,
					MaxTextSize = MAX_TEXT,
					TextSize = 20,
					Color = function()
						return TONE[props.Mode()].Text
					end,
					Stroke = function()
						return if TONE[props.Mode()].Stroke then Theme.Outline.Thin else 0
					end,
					Text = props.Text,
					Children = {
						createRaw("UIPadding")({
							PaddingTop = UDim.new(0.1, 0),
							PaddingBottom = UDim.new(0.1, 0),
							PaddingLeft = UDim.new(0.06, 0),
							PaddingRight = UDim.new(0.06, 0),
						}),
					},
				}),
			},
		}),

		CartoonPanel({
			Name = "Sub",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromScale(0.6, 1 - TAG_HEIGHT - 0.04),
			Tone = Theme.Tone.Ink,
			Outline = Theme.Outline.Thin,
			Lip = 2,
			Gloss = false,
			Visible = function()
				return props.Mode() == "OutOfStock" and hasSub()
			end,
			Children = {
				CartoonLabel({
					Box = UDim2.fromScale(1, 1),
					Scaled = true,
					MaxTextSize = MAX_TEXT,
					TextSize = 16,
					Stroke = 0,
					Text = props.SubText,
					Children = {
						createRaw("UIPadding")({
							PaddingTop = UDim.new(0.08, 0),
							PaddingBottom = UDim.new(0.08, 0),
						}),
					},
				}),
			},
		}),
	})
end
