--!strict
-- BenchCard: one position of the Mart GEAR WALL (FEAT-015, DEC-015, DEC-106; AST-049; style guide §7.3).
-- Shows in the world, never on screen: miniature of the next level, level name, effect in one line and a tag.
--   Buy     tag Mustard "$60"
--   NoCash  same tag in red (FEAT-008/015: the party cannot pay; the server refuses anyway)
--   Maxed   tag Green "Maxed" (the server hides the prompt)
--   Locked  tag Teal "Trailer only" (B5 while on the cart, DEC-055)
--   Empty   no miniature, no tag: one centred line ("Nothing special today", S1)
-- `Special` draws the Mustard frame of the rare slot (DEC-144). Pure: only props; the caller parents the
-- BillboardGui and decides every text. Sized in studs: the player stands ~4 studs from the wall (MAP-01 §7.4),
-- where the smallest phone shows the effect line at >= 14 px.
-- Cartoon pass (AST-091): Ink CartoonPanel card with studs (Mustard outline on the rare slot), white miniature tile,
-- the tag as a tone CartoonPanel; thin pixel outlines because the card is sized in studs.
-- `Plate` (Mart v2 Gear Stand, TASK-140): the miniature is a 3D model floating over the pedestal, so the card drops
-- the miniature tile and shrinks to a price plate (PLATE_WIDTH x PLATE_HEIGHT) hung under `Price_Anchor_<Slot>`.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Cinematic = require(script.Parent.Parent.Cinematic)
local Theme = require(script.Parent.Theme)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke, UIPadding and UITextSizeConstraint are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Mode = "Buy" | "NoCash" | "Maxed" | "Locked" | "Empty"

export type Props = {
	Adornee: Instance?,
	Visible: () -> boolean,
	Mode: () -> Mode,
	-- rbxassetid of the next level render (AST-071); "" = placeholder tile with `Badge`.
	Icon: () -> string,
	Badge: () -> string,
	Title: () -> string,
	Detail: () -> string,
	-- "$60", "Maxed", "Trailer only"; the Empty line ("Nothing special today") also comes here.
	Tag: () -> string,
	Special: (() -> boolean)?,
	Plate: boolean?, -- Gear Stand plate: no miniature tile, smaller card
	StudsOffset: Vector3?,
	MaxDistance: number?,
	Name: string?,
}

const WIDTH = 2.8 -- studs; one GEAR WALL module is 3 wide (AST-049)
const HEIGHT = 3.4
-- Gear Stand plate: a pedestal is 1.6 wide and its neighbours 3 apart (MAP-01 §18.4); the player reads it from
-- 1.5-2.5 studs, where the effect line stays >= 14 px on the smallest phone.
const PLATE_WIDTH = 2.6
const PLATE_HEIGHT = 1.9
const MAX_TEXT = 64

const TAG_TONE: { [Mode]: Theme.Tone } = {
	Buy = Theme.Tone.Mustard,
	NoCash = Theme.ToneOf(Theme.Color.NoCash),
	Maxed = Theme.Tone.Green,
	Locked = Theme.Tone.Teal,
	Empty = Theme.Tone.Ink,
}

local function label(props: {
	Name: string,
	Position: UDim2,
	Size: UDim2,
	Text: () -> string,
	Wrapped: boolean?,
	Visible: (() -> boolean)?,
}): TextLabel
	return CartoonLabel({
		Name = props.Name,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = props.Position,
		Box = props.Size,
		Scaled = true,
		MaxTextSize = MAX_TEXT,
		TextSize = 20,
		Wrapped = props.Wrapped,
		Stroke = Theme.Outline.Thin,
		Text = props.Text,
		Visible = props.Visible or true,
	})
end

-- Vertical layout (scale of the card height): Title, Detail, Tag; the plate has no miniature tile above them.
type Layout = { Title: number, TitleH: number, Detail: number, DetailH: number, Tag: number, TagH: number }
const CARD_LAYOUT: Layout = { Title = 0.43, TitleH = 0.2, Detail = 0.63, DetailH = 0.12, Tag = 0.78, TagH = 0.18 }
const PLATE_LAYOUT: Layout = { Title = 0.06, TitleH = 0.3, Detail = 0.38, DetailH = 0.2, Tag = 0.62, TagH = 0.32 }

return function(props: Props): BillboardGui
	const plate = props.Plate == true
	const layout = if plate then PLATE_LAYOUT else CARD_LAYOUT
	local function filled(): boolean
		return props.Mode() ~= "Empty"
	end

	local function empty(): boolean
		return props.Mode() == "Empty"
	end

	local function special(): boolean
		return if props.Special then props.Special() else false
	end

	local function hasIcon(): boolean
		return props.Icon() ~= ""
	end

	return create("BillboardGui")({
		Name = props.Name or "BenchCard",
		Adornee = props.Adornee,
		Size = if plate then UDim2.fromScale(PLATE_WIDTH, PLATE_HEIGHT) else UDim2.fromScale(WIDTH, HEIGHT),
		StudsOffset = props.StudsOffset or Vector3.zero,
		MaxDistance = props.MaxDistance or 40,
		LightInfluence = 0,
		ResetOnSpawn = false,
		-- Off while a cinematic owns the screen (Interface/Cinematic).
		Enabled = function()
			return props.Visible() and not Cinematic.Active()
		end,

		CartoonPanel({
			Name = "Panel",
			Size = UDim2.fromScale(1, 1),
			Tone = Theme.Tone.Ink,
			Transparency = Theme.Transparency.Panel,
			Outline = function()
				return if special() then Theme.Outline.Normal + 1 else Theme.Outline.Thin
			end,
			OutlineColor = function()
				return if special() then Theme.Color.Mustard else Theme.Color.Ink
			end,
			Radius = UDim.new(0.08, 0),
			Lip = 3,
			Studs = true,
			Gloss = false,
			Children = {
				-- Miniature of the next level (render from AST-071) or a placeholder tile until it exists (Q-152).
				CartoonPanel({
					Name = "Miniature",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0.05),
					Size = UDim2.fromScale(0.5, 0.36),
					Tone = Theme.Tone.White,
					Outline = Theme.Outline.Thin,
					Lip = 2,
					Radius = UDim.new(0.2, 0),
					Gloss = false,
					Visible = function()
						return filled() and not plate
					end,
					Decor = {
						create("UIAspectRatioConstraint")({ AspectRatio = 1 }),
					},
					Children = {
						create("ImageLabel")({
							Name = "Icon",
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							ScaleType = Enum.ScaleType.Fit,
							Image = props.Icon,
							Visible = hasIcon,
						}),
						CartoonLabel({
							Name = "Badge",
							Box = UDim2.fromScale(1, 1),
							Scaled = true,
							MaxTextSize = MAX_TEXT,
							TextSize = 24,
							Color = Theme.Color.Dark,
							Stroke = 0,
							Text = props.Badge,
							Visible = function()
								return not hasIcon()
							end,
							Children = {
								createRaw("UIPadding")({
									PaddingTop = UDim.new(0.15, 0),
									PaddingBottom = UDim.new(0.15, 0),
								}),
							},
						}),
					},
				}),

				label({
					Name = "Title",
					Position = UDim2.fromScale(0.5, layout.Title),
					Size = UDim2.fromScale(0.92, layout.TitleH),
					Text = props.Title,
					Wrapped = true,
					Visible = filled,
				}),

				label({
					Name = "Detail",
					Position = UDim2.fromScale(0.5, layout.Detail),
					Size = UDim2.fromScale(0.92, layout.DetailH),
					Text = props.Detail,
					Visible = filled,
				}),

				CartoonPanel({
					Name = "Tag",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, layout.Tag),
					Size = UDim2.fromScale(0.78, layout.TagH),
					Rotation = -2,
					Tone = function()
						return TAG_TONE[props.Mode()]
					end,
					Outline = Theme.Outline.Thin,
					Lip = 3,
					Radius = UDim.new(0.3, 0),
					Visible = filled,
					Children = {
						CartoonLabel({
							Name = "Label",
							Box = UDim2.fromScale(1, 1),
							Scaled = true,
							MaxTextSize = MAX_TEXT,
							TextSize = 20,
							Color = function()
								return TAG_TONE[props.Mode()].Text
							end,
							Stroke = function()
								return if TAG_TONE[props.Mode()].Stroke then Theme.Outline.Thin else 0
							end,
							Text = props.Tag,
							Children = {
								createRaw("UIPadding")({
									PaddingTop = UDim.new(0.12, 0),
									PaddingBottom = UDim.new(0.12, 0),
									PaddingLeft = UDim.new(0.05, 0),
									PaddingRight = UDim.new(0.05, 0),
								}),
							},
						}),
					},
				}),

				label({
					Name = "EmptyLine",
					Position = UDim2.fromScale(0.5, 0.3),
					Size = UDim2.fromScale(0.86, 0.4),
					Text = props.Tag,
					Wrapped = true,
					Visible = empty,
				}),
			},
		}),
	})
end
