--!strict
-- ShelfTag: price tag over a Mart shelf (FEAT-008, DEC-015, DEC-180; style guide §7.3 "etiqueta Mustard").
-- Three looks:
--   Price       Mustard tag "$6"
--   NoCash      same tag in red: the party cannot pay it (FEAT-008); the server refuses the buy anyway
--   OutOfStock  Cream tag "Out of stock" and, under it, an optional sub line ("Day 3", Provisional, DEC-180)
-- Pure: only props. The caller parents the BillboardGui (PlayerGui, with Adornee = the shelf anchor) and decides
-- the texts. Sized in studs, so it shrinks with distance like a real tag; at the prompt radius (7 studs) on the
-- smallest phone the price is ~22 px and the sub line ~15 px (frontend rule: text >= 14 px).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)

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

const BACKGROUND: { [Mode]: Color3 } = {
	Price = Theme.Color.Mustard,
	NoCash = Theme.Color.NoCash,
	OutOfStock = Theme.Color.Cream,
}

const FOREGROUND: { [Mode]: Color3 } = {
	Price = Theme.Color.Ink,
	NoCash = Theme.Color.Text,
	OutOfStock = Theme.Color.Ink,
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

		create("Frame")({
			Name = "Tag",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = function()
				return UDim2.fromScale(if props.Mode() == "OutOfStock" then 1 else PRICE_WIDTH, TAG_HEIGHT)
			end,
			BackgroundColor3 = function()
				return BACKGROUND[props.Mode()]
			end,

			create("UICorner")({ CornerRadius = UDim.new(0.3, 0) }),
			createRaw("UIStroke")({
				Color = Theme.Color.Ink,
				Thickness = Theme.Stroke,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),

			create("TextLabel")({
				Name = "Label",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				FontFace = Theme.Font.Title,
				TextScaled = true,
				TextColor3 = function()
					return FOREGROUND[props.Mode()]
				end,
				Text = props.Text,
				createRaw("UIPadding")({
					PaddingTop = UDim.new(0.1, 0),
					PaddingBottom = UDim.new(0.1, 0),
					PaddingLeft = UDim.new(0.06, 0),
					PaddingRight = UDim.new(0.06, 0),
				}),
				createRaw("UITextSizeConstraint")({ MaxTextSize = MAX_TEXT }),
			}),
		}),

		create("TextLabel")({
			Name = "Sub",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromScale(0.6, 1 - TAG_HEIGHT - 0.04),
			BackgroundColor3 = Theme.Color.Ink,
			BackgroundTransparency = Theme.Transparency.Panel,
			FontFace = Theme.Font.Body,
			TextScaled = true,
			TextColor3 = Theme.Color.Text,
			Text = props.SubText,
			Visible = function()
				return props.Mode() == "OutOfStock" and hasSub()
			end,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			createRaw("UIPadding")({
				PaddingTop = UDim.new(0.08, 0),
				PaddingBottom = UDim.new(0.08, 0),
			}),
			createRaw("UITextSizeConstraint")({ MaxTextSize = MAX_TEXT }),
		}),
	})
end
