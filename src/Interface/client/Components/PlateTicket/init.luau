--!strict
-- PlateTicket: the order paper over a plate slot of the assembly table (FEAT-044, DEC-271; tech/restaurant-flow.md rev. 2
-- §3.3; TASK-383). Same reading and kit as the HUD note (HudOrder, DEC-234 art): white CartoonPanel card, the number on a
-- small tab over the top-left corner, the order as icons in a row, the border is the patience ring that drains.
--   Icons      bun, sausage, then the toppings (ToppingKeys order, max 3). Faded = still missing on the plate, full = done
--   "#12"      Mustard tab; the oldest ticket of the table pulses (scale), so the eye finds it first
--   Ring       patience of the customer: Cream -> Mustard -> Ink (never red, style guide §2.4); under UrgentAt it also
--              blinks and a Mustard diamond "!" sits on the top-right corner (shape, not only colour: grey-scale test)
--   Orphan     the customer left (FEAT-044): Slate card and tab, "?" instead of the number, no ring
--   Empty      blank customer (ANM-001): the card with no icon, one cell wide
-- Fixed pixel size (not studs), like BrewTag: readable on a phone at any distance; MaxDistance 40, LightInfluence 0, never
-- AlwaysOnTop, never Active (nothing to tap: the 1st-person centre stays free, README). Hidden while a cinematic owns
-- the screen. Pure: only props; build it inside a Vide root.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Cinematic = require(script.Parent.Parent.Cinematic)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
const indexes = Vide.indexes
const source = Vide.source
const effect = Vide.effect
const cleanup = Vide.cleanup
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke, UIGradient and UIScale are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Adornee: Instance?,
	Visible: () -> boolean,
	-- #n of the order (Customers.Number); nil = unknown yet (the tab shows "#")
	Number: () -> number?,
	-- Content.Ingredients topping keys of the order, display order (max 3, DEC-071). Empty = plain hot dog (K = 0).
	Toppings: () -> { string },
	-- What is already on the plate: "bun", "sausage" and topping keys
	Done: () -> { [string]: boolean },
	-- Patience left, 0..1. Negative = no ring.
	Patience: () -> number,
	-- Below this fraction: Ink ring, blink and "!" (Content.Restaurant.Rules.UrgentAt). Default 0.25.
	UrgentAt: number?,
	-- Between UrgentAt and this fraction the ring is Mustard. Default 0.5.
	WarnAt: number?,
	-- The customer left (grey "?"). Default false.
	Orphan: (() -> boolean)?,
	-- Oldest open ticket of the table (the tab pulses). Default false.
	Oldest: (() -> boolean)?,
	-- Blank customer (ANM-001): no icon. Default false.
	Empty: (() -> boolean)?,
	StudsOffset: Vector3?,
	MaxDistance: number?,
	Name: string?,
}

const CELL = 30
const GAP = 4
const PAD = 7
const LIP = 4
const RING = 4
const CARD_HEIGHT = CELL + PAD * 2 + LIP
const TAB_HEIGHT = 24
const TAB_OVERLAP = 7 -- the tab sits over the card edge
const TAB_TEXT = 17
const LABEL_SIZE = 14 -- letter chip (>= Theme.MinTextSize)
const INSET = 4 -- room for the outlines and the pulse inside the BillboardGui
const BADGE = 22 -- urgent diamond
const MAX_TOPPINGS = 3
const MISSING_TRANSPARENCY = 0.62 -- faded icon = not on the plate yet
const PULSE_PERIOD = 1.1 -- s, oldest ticket tab
const PULSE_SCALE = 0.12
const BLINK_PERIOD = 0.5 -- s, urgent ring on / off

const WHITE = Color3.fromHex("#FFFFFF")
const RING_CALM = Theme.Tone.Cream.Lip -- Cream family, dark enough to read on the white card
const BASE_KEYS: { string } = { "bun", "sausage" }

-- Letter chip for a key with no cell in the sheet (same colours as HudOrder / OrderBubble).
const CHIP: { [string]: { Color: Color3, Label: string } } = {
	bun = { Color = Color3.fromHex("#E8B36B"), Label = "B" },
	sausage = { Color = Color3.fromHex("#C8553D"), Label = "D" },
	ketchup = { Color = Color3.fromHex("#E2402E"), Label = "K" },
	mustard = { Color = Color3.fromHex("#F6C12B"), Label = "M" },
	cheese = { Color = Color3.fromHex("#F39C2B"), Label = "Ch" },
	bacon = { Color = Color3.fromHex("#A8432F"), Label = "Ba" },
	potato_sticks = { Color = Color3.fromHex("#D9A55B"), Label = "PS" },
	cream_cheese = { Color = Theme.Color.Cream, Label = "CC" },
}

local function chipOf(key: string): { Color: Color3, Label: string }
	return CHIP[key] or { Color = Theme.Color.Teal, Label = string.upper(string.sub(key, 1, 1)) }
end

local function iconName(key: string): string
	return `Ingredient/{key}`
end

-- Opaque up to `fraction` of the border, transparent after it: the ring drains from its right end (as HudOrder).
local function ringTransparency(fraction: number): NumberSequence
	if fraction >= 0.999 then
		return NumberSequence.new(0)
	elseif fraction <= 0.001 then
		return NumberSequence.new(1)
	end
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(fraction, 0),
		NumberSequenceKeypoint.new(math.min(fraction + 0.001, 0.999), 1),
		NumberSequenceKeypoint.new(1, 1),
	})
end

-- One icon cell; `done` = already on the plate (full), else faded.
local function cell(key: () -> string, order: number, done: () -> boolean, orphan: () -> boolean): Frame
	local function hasArt(): boolean
		return Icons.Has(iconName(key()))
	end
	local function rect(): Icons.Rect
		return Icons.Rect(iconName(key())) or { Offset = Vector2.zero, Size = Vector2.zero }
	end
	local function fade(): number
		return if done() and not orphan() then 0 else MISSING_TRANSPARENCY
	end
	return create("Frame")({
		Name = "Cell",
		LayoutOrder = order,
		Size = UDim2.fromOffset(CELL, CELL),
		BackgroundColor3 = function()
			return chipOf(key()).Color
		end,
		BackgroundTransparency = function()
			return if hasArt() then 1 else fade()
		end,
		create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
		createRaw("UIStroke")({
			Color = Theme.Color.Ink,
			Thickness = Theme.Outline.Thin,
			Transparency = fade,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Enabled = function()
				return not hasArt()
			end,
		}),
		create("ImageLabel")({
			Name = "Icon",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Image = Icons.Image,
			ImageRectOffset = function()
				return rect().Offset
			end,
			ImageRectSize = function()
				return rect().Size
			end,
			ImageTransparency = fade,
			Visible = hasArt,
		}),
		CartoonLabel({
			Name = "Letter",
			Box = UDim2.fromScale(1, 1),
			TextSize = LABEL_SIZE,
			Text = function()
				return chipOf(key()).Label
			end,
			Transparency = fade,
			Visible = function()
				return not hasArt()
			end,
		}),
	})
end

return function(props: Props): BillboardGui
	const urgentAt = props.UrgentAt or 0.25
	const warnAt = props.WarnAt or 0.5
	const orphan = props.Orphan or function(): boolean
		return false
	end
	const oldest = props.Oldest or function(): boolean
		return false
	end
	const empty = props.Empty or function(): boolean
		return false
	end

	local function urgent(): boolean
		const patience = props.Patience()
		return not orphan() and patience >= 0 and patience <= urgentAt
	end

	-- Clock for the pulse and the blink: a Heartbeat only while one of them runs (8 tickets at most on the table)
	const clock = source(0)
	effect(function()
		if not (props.Visible() and (oldest() or urgent())) or Motion.Reduced() then
			return
		end
		const connection = RunService.Heartbeat:Connect(function()
			clock(os.clock())
		end)
		cleanup(connection)
	end)

	local function keys(): { string }
		if empty() then
			return {}
		end
		const list = table.clone(BASE_KEYS)
		for index, key in props.Toppings() do
			if index > MAX_TOPPINGS then
				break
			end
			table.insert(list, key)
		end
		return list
	end

	local function width(): number
		const cells = math.max(#keys(), 1)
		return PAD * 2 + cells * CELL + (cells - 1) * GAP
	end

	local function ringColor(): Color3
		const patience = props.Patience()
		if patience <= urgentAt then
			return Theme.Color.Ink
		elseif patience <= warnAt then
			return Theme.Color.Mustard
		end
		return RING_CALM
	end

	local function ringShown(): boolean
		if orphan() or props.Patience() < 0 then
			return false
		end
		-- urgent: the ring blinks (shape cue on top of the colour)
		if urgent() and not Motion.Reduced() then
			return (clock() // BLINK_PERIOD) % 2 == 0
		end
		return true
	end

	local function tabScale(): number
		if not oldest() or orphan() or Motion.Reduced() then
			return 1
		end
		const phase = (clock() % PULSE_PERIOD) / PULSE_PERIOD
		return 1 + PULSE_SCALE * (0.5 - 0.5 * math.cos(phase * math.pi * 2))
	end

	local function tabText(): string
		if orphan() then
			return "?"
		end
		const number = props.Number()
		return if number ~= nil then `#{number}` else "#"
	end

	return create("BillboardGui")({
		Name = props.Name or "PlateTicket",
		Adornee = props.Adornee,
		Size = function()
			return UDim2.fromOffset(width() + INSET * 2, TAB_HEIGHT - TAB_OVERLAP + CARD_HEIGHT + INSET * 2)
		end,
		StudsOffset = props.StudsOffset or Vector3.zero,
		MaxDistance = props.MaxDistance or 40,
		AlwaysOnTop = false,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Active = false,
		Enabled = function()
			return props.Visible() and not Cinematic.Active()
		end,

		create("Frame")({
			Name = "Root",
			Position = UDim2.fromOffset(INSET, INSET),
			Size = UDim2.new(1, -INSET * 2, 1, -INSET * 2),
			BackgroundTransparency = 1,

			CartoonPanel({
				Name = "Card",
				Position = UDim2.fromOffset(0, TAB_HEIGHT - TAB_OVERLAP),
				Size = UDim2.new(1, 0, 0, CARD_HEIGHT),
				Tone = function()
					return if orphan() then Theme.Tone.Slate else Theme.Tone.White
				end,
				Outline = Theme.Outline.Normal,
				Radius = UDim.new(0, (CARD_HEIGHT - LIP) / 2),
				Lip = LIP,
				Children = {
					-- Patience ring, just inside the Ink outline
					create("Frame")({
						Name = "Ring",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.new(1, -RING * 2, 1, -RING * 2),
						BackgroundTransparency = 1,
						create("UICorner")({ CornerRadius = UDim.new(0, (CARD_HEIGHT - LIP) / 2 - RING) }),
						createRaw("UIStroke")({
							Thickness = RING,
							ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
							Color = WHITE, -- the gradient below gives the colour
							Enabled = ringShown,
							create("UIGradient")({
								Color = function()
									return ColorSequence.new(ringColor())
								end,
								Transparency = function()
									return ringTransparency(math.clamp(props.Patience(), 0, 1))
								end,
							}),
						}),
					}),

					create("Frame")({
						Name = "Icons",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						ZIndex = 2,
						create("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, GAP),
						}),
						indexes(keys, function(key: () -> string, order: number)
							return cell(key, order, function()
								return props.Done()[key()] == true
							end, orphan)
						end),
					}),
				},
			}),

			-- "#12" tab over the top-left corner of the card
			CartoonPanel({
				Name = "Number",
				Position = UDim2.fromOffset(PAD - 2, 0),
				Size = UDim2.fromOffset(0, TAB_HEIGHT),
				AutomaticSize = Enum.AutomaticSize.X,
				Rotation = -3,
				Tone = function()
					return if orphan() then Theme.Tone.Slate else Theme.Tone.Mustard
				end,
				Outline = Theme.Outline.Normal,
				Lip = 3,
				Padding = { Left = 7, Right = 7 },
				ZIndex = 3,
				Decor = {
					createRaw("UIScale")({ Scale = tabScale }),
				},
				Children = {
					CartoonLabel({
						Box = UDim2.new(0, 0, 1, 0),
						AutomaticSize = Enum.AutomaticSize.X,
						TextSize = TAB_TEXT,
						Text = tabText,
						Color = function()
							return if orphan() then Theme.Color.Text else Theme.Color.Dark
						end,
						Stroke = function()
							return if orphan() then Theme.Stroke else 0
						end,
					}),
				},
			}),

			-- Urgent: Mustard diamond "!" on the top-right corner (one rotated Frame; the text stays upright)
			create("Frame")({
				Name = "Urgent",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -BADGE / 2, 0, TAB_HEIGHT - TAB_OVERLAP + 2),
				Size = UDim2.fromOffset(BADGE, BADGE),
				BackgroundTransparency = 1,
				ZIndex = 4,
				Visible = urgent,
				create("Frame")({
					Name = "Diamond",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(BADGE * 0.72, BADGE * 0.72),
					Rotation = 45,
					BackgroundColor3 = Theme.Color.Mustard,
					ZIndex = 4,
					create("UICorner")({ CornerRadius = UDim.new(0, 3) }),
					createRaw("UIStroke")({
						Color = Theme.Color.Ink,
						Thickness = 2.5,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
				}),
				CartoonLabel({
					Name = "Mark",
					Box = UDim2.fromScale(1, 1),
					TextSize = 16,
					Text = "!",
					Color = Theme.Color.Dark,
					Stroke = 0,
					ZIndex = 5,
				}),
			}),
		}),
	})
end
