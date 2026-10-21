--!strict
-- GearTag: name, effect and price of one Gear Stand pedestal, floating ABOVE its miniature (user feedback 2026-10-11:
-- the BenchCard behind the glass was unreadable; FEAT-015 v2; MAP-01 §18.4; Q-203 Provisional).
--   Buy      Cream card, Ink text, Mustard price pill "$50"
--   NoCash   same card, price pill in Ketchup (the party cannot pay it; the server refuses anyway)
--   SoldOut  Slate card (grey), pill "Back next shift" (cooldown after a purchase, UpgradeService)
--   Maxed    Cream card, Green pill "MAX"
--   Locked   Cream card, Teal pill "Trailer only"
--   Empty    one centred line ("Nothing special today", S1)
-- Fixed pixel size like PatienceBar / OrderBubble (BillboardGui: the global ScreenGui UI scale does not reach it),
-- bottom of the card at the adornee (it floats above the glass, Mart.Plate.Lift). NOT AlwaysOnTop (TASK-595, owner Play
-- 2026-10-19: the plates showed through the walls into the shop): walls hide it; the caller shows one plate at a time.
-- Text >= 14 px.
-- Pure: only props; the caller parents the BillboardGui and decides every text.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Cinematic = require(script.Parent.Parent.Cinematic)
local Theme = require(script.Parent.Theme)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)
local WorldScale = require(script.Parent.WorldScale)

const create = Vide.create
const effect = Vide.effect
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Mode = "Buy" | "NoCash" | "SoldOut" | "Maxed" | "Locked" | "Empty"

export type Props = {
	Adornee: Instance?,
	Visible: () -> boolean,
	Mode: () -> Mode,
	Title: () -> string,
	Detail: () -> string,
	-- "$50", "MAX", "Trailer only", "Back next shift"; the Empty line also comes here.
	Tag: () -> string,
	Width: number?, -- px
	Offset: Vector3?, -- world studs, when the adornee is not already above the miniature
	MaxDistance: number?,
	Name: string?,
}

const WIDTH = 190
const PADDING = 6
const TITLE_H = 22
const DETAIL_H = 18
const PILL_H = 26
const GAP = 3
const HEIGHT = PADDING * 2 + TITLE_H + DETAIL_H + PILL_H + GAP * 2 + 4 -- + the lip of the card
const EMPTY_HEIGHT = 48

const PILL_TONE: { [Mode]: Theme.Tone } = {
	Buy = Theme.Tone.Mustard,
	NoCash = Theme.ToneOf(Theme.Color.NoCash),
	SoldOut = Theme.Tone.Ink,
	Maxed = Theme.Tone.Green,
	Locked = Theme.Tone.Teal,
	Empty = Theme.Tone.Ink,
}

return function(props: Props): BillboardGui
	local function empty(): boolean
		return props.Mode() == "Empty"
	end
	local function soldOut(): boolean
		return props.Mode() == "SoldOut"
	end

	-- dark text on the Cream card, white text with the Ink stroke on the grey one
	local function textColor(): Color3
		return if soldOut() then Theme.Color.Text else Theme.Color.Dark
	end
	local function textStroke(): number
		return if soldOut() then Theme.Outline.Thin else 0
	end

	local function line(name: string, order: number, height: number, size: number, text: () -> string, visible: () -> boolean)
		return CartoonLabel({
			Name = name,
			LayoutOrder = order,
			Box = UDim2.new(1, 0, 0, height),
			TextSize = size,
			Color = textColor,
			Stroke = textStroke,
			Truncate = true,
			Text = text,
			Visible = visible,
		})
	end

	local function filled(): boolean
		return not empty()
	end

	const width = props.Width or WIDTH
	const gui = create("BillboardGui")({
		Name = props.Name or "GearTag",
		Adornee = props.Adornee,
		-- WorldScale owns the Size from here (design px x the distance scale)
		Size = UDim2.fromOffset(width, HEIGHT),
		SizeOffset = Vector2.new(0, 0.5),
		AlwaysOnTop = false,
		StudsOffsetWorldSpace = props.Offset or Vector3.zero,
		MaxDistance = props.MaxDistance or 45,
		LightInfluence = 0,
		ResetOnSpawn = false,
		-- Off while a cinematic owns the screen (Interface/Cinematic).
		Enabled = function()
			return props.Visible() and not Cinematic.Active()
		end,

		CartoonPanel({
			Name = "Card",
			Size = UDim2.fromScale(1, 1),
			Tone = function()
				return if soldOut() then Theme.Tone.Slate else Theme.Tone.Cream
			end,
			Outline = Theme.Outline.Normal,
			OutlineColor = Theme.Color.Ink,
			Radius = Theme.Radius.Card,
			Lip = 3,
			Padding = PADDING,
			Children = {
				createRaw("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, GAP),
				}),
				line("Title", 1, TITLE_H, 20, props.Title, filled),
				line("Detail", 2, DETAIL_H, 16, props.Detail, filled),
				CartoonPanel({
					Name = "Pill",
					LayoutOrder = 3,
					Size = function()
						return UDim2.fromOffset(math.clamp(20 + #props.Tag() * 9, 64, 166), PILL_H)
					end,
					Tone = function()
						return PILL_TONE[props.Mode()]
					end,
					Outline = Theme.Outline.Thin,
					Lip = 2,
					Radius = Theme.Radius.Pill,
					Visible = filled,
					Children = {
						CartoonLabel({
							Name = "Label",
							Box = UDim2.fromScale(1, 1),
							TextSize = 18,
							Color = function()
								return PILL_TONE[props.Mode()].Text
							end,
							Stroke = function()
								return if PILL_TONE[props.Mode()].Stroke then Theme.Outline.Thin else 0
							end,
							Text = props.Tag,
						}),
					},
				}),
				CartoonLabel({
					Name = "EmptyLine",
					LayoutOrder = 4,
					Box = UDim2.new(1, 0, 0, TITLE_H + 6),
					TextSize = 17,
					Color = Theme.Color.Dark,
					Stroke = 0,
					Text = props.Tag,
					Visible = empty,
				}),
			},
		}),
	}) :: BillboardGui
	-- shrinks with distance like the pedestal under it: a px card stayed the same size on screen, so from the aisle it
	-- outgrew the stand and the shelves in front cut it (owner 2026-10-20)
	WorldScale.Track(gui, width, HEIGHT)
	effect(function()
		WorldScale.Resize(gui, width, if empty() then EMPTY_HEIGHT else HEIGHT)
	end)
	return gui
end
