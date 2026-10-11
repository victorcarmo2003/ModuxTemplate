--!strict
-- TableSign: the price plate over the next Pad table for sale (FEAT-037, UPG-008; TASK-147; style guide §7.3
-- "etiqueta Mustard"). A small Ink plate with the name ("Patio Table") and, hung under it, the price tag:
--   Buy     Mustard tag "$30"
--   NoCash  same tag in red: the party cannot pay it (FEAT-008); the server refuses the buy anyway
-- Pure: only props. SeatingController owns the data, parents the BillboardGui and decides every text.
-- Sized in studs (user request 2026-10-11 on the sale sign: a pixel plate stays huge from far away): it shrinks with
-- distance like a real sign, MaxDistance short (45 studs by default). At the prompt radius (7 studs) the price is
-- ~30 px and the name ~20 px on the smallest phone; from 15 studs the price still reads at ~15 px.
-- Cartoon pass (AST-091): Ink CartoonPanel plate with studs, the tag a tone CartoonPanel tilted like a hung tag, thin
-- outlines (studs-sized tags keep a light outline from far away, like ShelfTag / SaleSign).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Cinematic = require(script.Parent.Parent.Cinematic)
local Theme = require(script.Parent.Theme)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIPadding is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Mode = "Buy" | "NoCash"

export type Props = {
	Adornee: Instance?,
	Visible: () -> boolean,
	Mode: () -> Mode,
	-- "Patio Table"
	Title: () -> string,
	-- "$30"
	Price: () -> string,
	-- World-space offset over the adornee (studs, world up stays up).
	Offset: Vector3?,
	MaxDistance: number?,
	Name: string?,
}

const WIDTH = 3.0 -- studs
const HEIGHT = 1.75
const TITLE_HEIGHT = 0.42 -- fraction of HEIGHT
const TAG_WIDTH = 0.62 -- fraction of WIDTH
const TAG_HEIGHT = 0.52
const MAX_TEXT = 64
const DEFAULT_DISTANCE = 45

const TAG_TONE: { [Mode]: Theme.Tone } = {
	Buy = Theme.Tone.Mustard,
	NoCash = Theme.ToneOf(Theme.Color.NoCash),
}

local function padded(vertical: number, horizontal: number): Instance
	return createRaw("UIPadding")({
		PaddingTop = UDim.new(vertical, 0),
		PaddingBottom = UDim.new(vertical, 0),
		PaddingLeft = UDim.new(horizontal, 0),
		PaddingRight = UDim.new(horizontal, 0),
	})
end

return function(props: Props): BillboardGui
	return create("BillboardGui")({
		Name = props.Name or "TableSign",
		Adornee = props.Adornee,
		Size = UDim2.fromScale(WIDTH, HEIGHT),
		StudsOffsetWorldSpace = props.Offset or Vector3.zero,
		MaxDistance = props.MaxDistance or DEFAULT_DISTANCE,
		AlwaysOnTop = false,
		LightInfluence = 0,
		ResetOnSpawn = false,
		-- Off while a cinematic owns the screen (Interface/Cinematic).
		Enabled = function()
			return props.Visible() and not Cinematic.Active()
		end,

		CartoonPanel({
			Name = "Plate",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromScale(0.96, TITLE_HEIGHT),
			Tone = Theme.Tone.Ink,
			Outline = Theme.Outline.Thin,
			Lip = 3,
			Radius = UDim.new(0.3, 0),
			Studs = true,
			Gloss = false,
			Children = {
				CartoonLabel({
					Name = "Title",
					Box = UDim2.fromScale(1, 1),
					Scaled = true,
					MaxTextSize = MAX_TEXT,
					TextSize = 18,
					Stroke = Theme.Outline.Thin,
					Text = props.Title,
					Children = { padded(0.12, 0.06) },
				}),
			},
		}),

		CartoonPanel({
			Name = "Tag",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 0.98),
			Size = UDim2.fromScale(TAG_WIDTH, TAG_HEIGHT),
			Rotation = -4,
			Tone = function()
				return TAG_TONE[props.Mode()]
			end,
			Outline = Theme.Outline.Thin,
			Lip = 3,
			Radius = UDim.new(0.3, 0),
			Children = {
				CartoonLabel({
					Name = "Price",
					Box = UDim2.fromScale(1, 1),
					Scaled = true,
					MaxTextSize = MAX_TEXT,
					TextSize = 24,
					Color = function()
						return TAG_TONE[props.Mode()].Text
					end,
					Stroke = function()
						return if TAG_TONE[props.Mode()].Stroke then Theme.Outline.Thin else 0
					end,
					Text = props.Price,
					Children = { padded(0.1, 0.08) },
				}),
			},
		}),
	})
end
