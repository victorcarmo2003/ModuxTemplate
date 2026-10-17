--!strict
-- OrderBoard: the kitchen order screen on the trailer's MenuStrip (owner request 2026-10-17, fast-food kitchen display):
-- every order being made or waiting, as big cards readable from across the kitchen in first person on a phone.
--   Board    Ink screen, a header column on the left ("ORDERS" + how many), the cards in a row, oldest on the left
--   Card     Cream card: "#12" big, the state chip (IN LINE Slate / COOKING Mustard / READY Green, never red), the
--            icons of the order (bun, sausage, each topping; a pair = 2 rows) and the patience bar at the bottom
--            (Green, Mustard under WarnAt, "!" under UrgentAt). An item not on the plate yet is drawn faded
--   Overflow cards shrink down to MinCardRatio x height; past that the last card is "+k" (more orders than fit)
-- Icons are the ones of the order note (HudOrder, AST-071 sheet `Ingredient/<key>`); a key with no cell gets the same
-- flat letter chip. Status only: nothing clickable (the board is far from the player, FEAT-032).
-- Sized in canvas px (SurfaceGui PixelsPerStud): every length is a fraction of the card height, text is Scaled.
-- Pure: only props. OrderBoardController builds the cards from the Customers set (+ Plates with the restaurant on).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Cinematic = require(script.Parent.Parent.Cinematic)
local Icons = require(script.Parent.Icons)
local Theme = require(script.Parent.Theme)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
const indexes = Vide.indexes
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke and UIPadding are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type CardState = "Queued" | "Preparing" | "Ready"

-- One icon of an order. Key = "bun", "sausage" or a Content.Ingredients topping key. Done: true = on the plate,
-- false = still missing (faded), nil = unknown (the trailer flow has no plate: drawn full).
export type Item = { Key: string, Done: boolean? }

export type Card = {
	Id: number, -- NpcId of the customer (stable key)
	Number: number, -- #n; 0 = not stamped yet (still at the tablet): "NEW"
	Rows: { { Item } }, -- 1 row, or 2 for a pair (FEAT-038)
	State: CardState,
	Patience: number, -- 0..1 left; negative = no bar
	Urgent: boolean?, -- patience <= UrgentAt: "!" on the card
}

export type Props = {
	-- Oldest first. More than fit = the last visible card becomes "+k".
	Cards: () -> { Card },
	-- Canvas size in px (part face in studs x PixelsPerStud).
	CanvasSize: () -> Vector2,
	Adornee: BasePart?,
	Face: Enum.NormalId?,
	PixelsPerStud: number?,
	MaxDistance: number?,
	-- Below this patience fraction the bar turns Mustard. Default 1/3.
	WarnAt: number?,
	-- false = the board is off. nil = on.
	Visible: (() -> boolean)?,
	Title: string?,
	Name: string?,
}

-- Layout, as fractions of the card height (the canvas is a strip: the height drives everything).
const PAD = 0.06 -- board padding (of the canvas height)
const GAP = 0.05 -- between cards
const MAX_CARD_RATIO = 1.15 -- widest card = 1.15 x its height
const MIN_CARD_RATIO = 0.62 -- narrowest before overflow
const HEADER_RATIO = 0.75 -- header column width = 0.75 x canvas height (capped at 22% of the width)
const NUMBER_BAND = 0.26
const STATE_BAND = 0.15
const BAR_BAND = 0.08
const CARD_PAD = 0.05
const ICON_GAP = 0.04
const MAX_ITEMS = 5 -- bun, sausage, 3 toppings (Content.OrderRules.MaxToppings)
const ICON_FADE = 0.65 -- transparency of an item still missing

const STATE_TEXT: { [CardState]: string } = {
	Queued = "IN LINE",
	Preparing = "COOKING",
	Ready = "READY",
}
const STATE_TONE: { [CardState]: Theme.Tone } = {
	Queued = Theme.Tone.Slate,
	Preparing = Theme.Tone.Mustard,
	Ready = Theme.Tone.Green,
}

-- Letter chip for a key with no cell in the sheet (same colors as the HudOrder / OrderBubble placeholders).
const CHIP: { [string]: { Color: Color3, Label: string } } = {
	bun = { Color = Color3.fromHex("#E8B36B"), Label = "B" },
	sausage = { Color = Color3.fromHex("#C4553A"), Label = "S" },
	ketchup = { Color = Color3.fromHex("#E2402E"), Label = "K" },
	mustard = { Color = Color3.fromHex("#F6C12B"), Label = "M" },
	cheese = { Color = Color3.fromHex("#F39C2B"), Label = "Ch" },
	bacon = { Color = Color3.fromHex("#A8432F"), Label = "Bc" },
	potato_sticks = { Color = Color3.fromHex("#D9A55B"), Label = "PS" },
	cream_cheese = { Color = Theme.Color.Cream, Label = "CC" },
}

local function chipOf(key: string): { Color: Color3, Label: string }
	return CHIP[key] or { Color = Theme.Color.Teal, Label = string.upper(string.sub(key, 1, 1)) }
end

local function iconName(key: string): string
	return `Ingredient/{key}`
end

export type Layout = {
	Height: number, -- card height (px)
	Width: number, -- card width (px)
	Gap: number,
	Pad: number,
	Header: number, -- header column width (px)
	Shown: number, -- cards drawn (the last one is "+k" when Hidden > 0)
	Hidden: number,
}

-- Card sizes for a canvas and a number of cards.
local function layoutOf(canvas: Vector2, count: number): Layout
	const pad = math.max(canvas.Y * PAD, 2)
	const height = math.max(canvas.Y - pad * 2, 1)
	const header = math.min(canvas.Y * HEADER_RATIO, canvas.X * 0.22)
	const gap = height * GAP
	const room = math.max(canvas.X - header - pad * 3, 1)
	const minWidth = height * MIN_CARD_RATIO
	const fit = math.max(math.floor((room + gap) / (minWidth + gap)), 1)
	const shown = math.min(count, fit)
	const hidden = count - shown
	-- with an overflow the last slot is the "+k" card, so one order less is drawn
	const width = if shown > 0
		then math.clamp((room - gap * (shown - 1)) / shown, minWidth, height * MAX_CARD_RATIO)
		else height * MAX_CARD_RATIO
	const value: Layout = {
		Height = height,
		Width = width,
		Gap = gap,
		Pad = pad,
		Header = header,
		Shown = shown,
		Hidden = if hidden > 0 then hidden + 1 else 0,
	}
	return value
end

-- One icon: the AST-071 cell, or the letter chip; faded while the item is missing from the plate.
local function icon(item: () -> Item?, side: () -> number, order: number): Frame
	const key = function(): string
		const value = item()
		return if value ~= nil then value.Key else ""
	end
	const hasArt = function(): boolean
		return Icons.Has(iconName(key()))
	end
	const rect = function(): Icons.Rect
		return Icons.Rect(iconName(key())) or { Offset = Vector2.zero, Size = Vector2.zero }
	end
	const fade = function(): number
		const value = item()
		return if value ~= nil and value.Done == false then ICON_FADE else 0
	end
	return create("Frame")({
		Name = "Icon",
		LayoutOrder = order,
		Size = function()
			return UDim2.fromOffset(side(), side())
		end,
		BackgroundColor3 = function()
			return chipOf(key()).Color
		end,
		BackgroundTransparency = function()
			return if hasArt() then 1 else fade()
		end,
		Visible = function()
			return key() ~= ""
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
			Name = "Art",
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
			Scaled = true,
			Text = function()
				return chipOf(key()).Label
			end,
			Transparency = fade,
			Visible = function()
				return not hasArt()
			end,
		}),
	}) :: Frame
end

-- One order card. `card` is nil while the slot is the "+k" overflow card.
local function orderCard(
	card: () -> Card?,
	extra: () -> number,
	layout: () -> Layout,
	warnAt: number,
	order: number
): Frame
	const height = function(): number
		return layout().Height
	end
	const inner = function(): number
		return height() * CARD_PAD
	end
	const rows = function(): { { Item } }
		const value = card()
		return if value ~= nil then value.Rows else {}
	end
	-- icon side: the icon area split in rows, the widest row split in columns
	const iconSide = function(): number
		const count = math.max(#rows(), 1)
		local columns = 1
		for _, row in rows() do
			columns = math.max(columns, math.min(#row, MAX_ITEMS))
		end
		const area = height() * (1 - NUMBER_BAND - STATE_BAND - BAR_BAND) - inner() * 3
		const across = layout().Width - inner() * 2
		const gap = height() * ICON_GAP
		const byHeight = (area - gap * (count - 1)) / count
		const byWidth = (across - gap * (columns - 1)) / columns
		return math.max(math.floor(math.min(byHeight, byWidth)), 1)
	end
	const state = function(): CardState
		const value = card()
		return if value ~= nil then value.State else "Queued"
	end
	const patience = function(): number
		const value = card()
		return if value ~= nil then value.Patience else -1
	end
	const isExtra = function(): boolean
		return card() == nil and extra() > 0
	end

	local function iconRow(index: number): Frame
		const list = function(): { Item }
			const row = rows()[index]
			if row == nil then
				return {}
			end
			if #row <= MAX_ITEMS then
				return row
			end
			return table.move(row, 1, MAX_ITEMS, 1, {})
		end
		return create("Frame")({
			Name = `Row{index}`,
			LayoutOrder = index,
			BackgroundTransparency = 1,
			Size = function()
				return UDim2.new(1, 0, 0, iconSide())
			end,
			Visible = function()
				return rows()[index] ~= nil
			end,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = function()
					return UDim.new(0, height() * ICON_GAP)
				end,
			}),
			indexes(list, function(item: () -> Item, at: number)
				return icon(item, iconSide, at)
			end),
		}) :: Frame
	end

	return create("Frame")({
		Name = `Card{order}`,
		LayoutOrder = order,
		BackgroundColor3 = Color3.new(1, 1, 1), -- the gradient gives the Cream
		Size = function()
			return UDim2.fromOffset(layout().Width, height())
		end,
		Visible = function()
			return card() ~= nil or isExtra()
		end,
		create("UICorner")({
			CornerRadius = function()
				return UDim.new(0, height() * 0.08)
			end,
		}),
		createRaw("UIStroke")({
			Color = Theme.Color.Ink,
			Thickness = function()
				return math.max(height() * 0.025, 2)
			end,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		create("UIGradient")({ Rotation = 90, Color = Theme.Gradient(Theme.Tone.Cream) }),

		-- "+k": more orders than fit on the board
		CartoonLabel({
			Name = "More",
			Box = UDim2.fromScale(1, 1),
			Scaled = true,
			Color = Theme.Color.Dark,
			Stroke = 0,
			Text = function()
				return `+{extra()}`
			end,
			Visible = isExtra,
			Children = {
				createRaw("UIPadding")({
					PaddingTop = UDim.new(0.3, 0),
					PaddingBottom = UDim.new(0.3, 0),
				}),
			},
		}),

		create("Frame")({
			Name = "Body",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Visible = function()
				return card() ~= nil
			end,
			createRaw("UIPadding")({
				PaddingTop = function()
					return UDim.new(0, inner())
				end,
				PaddingBottom = function()
					return UDim.new(0, inner())
				end,
				PaddingLeft = function()
					return UDim.new(0, inner())
				end,
				PaddingRight = function()
					return UDim.new(0, inner())
				end,
			}),

			-- #n, big, Ink on Cream
			CartoonLabel({
				Name = "Number",
				Box = function()
					return UDim2.new(1, 0, 0, height() * NUMBER_BAND)
				end,
				Scaled = true,
				Color = Theme.Color.Dark,
				Stroke = 0,
				XAlignment = Enum.TextXAlignment.Left,
				Text = function()
					const value = card()
					if value == nil then
						return ""
					end
					return if value.Number > 0 then `#{value.Number}` else "NEW"
				end,
			}),
			-- "!" when the patience is almost gone (FEAT-044 UrgentAt): shape, not only colour
			CartoonLabel({
				Name = "Urgent",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Box = function()
					return UDim2.fromOffset(height() * NUMBER_BAND * 0.7, height() * NUMBER_BAND)
				end,
				Scaled = true,
				Color = Theme.Color.Mustard,
				Text = "!",
				Visible = function()
					const value = card()
					return value ~= nil and value.Urgent == true
				end,
			}),

			-- state chip
			create("Frame")({
				Name = "State",
				Position = function()
					return UDim2.fromOffset(0, height() * NUMBER_BAND)
				end,
				Size = function()
					return UDim2.new(1, 0, 0, height() * STATE_BAND)
				end,
				BackgroundColor3 = function()
					return STATE_TONE[state()].Bottom
				end,
				create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
				createRaw("UIStroke")({
					Color = Theme.Color.Ink,
					Thickness = function()
						return math.max(height() * 0.015, 1.5)
					end,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
				CartoonLabel({
					Name = "Label",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Box = UDim2.fromScale(0.86, 0.78),
					Scaled = true,
					Color = function()
						return STATE_TONE[state()].Text
					end,
					Stroke = function()
						return if STATE_TONE[state()].Stroke then 2 else 0
					end,
					Text = function()
						return STATE_TEXT[state()]
					end,
				}),
			}),

			-- icons of the order (1 row, 2 for a pair)
			create("Frame")({
				Name = "Items",
				BackgroundTransparency = 1,
				Position = function()
					return UDim2.fromOffset(0, height() * (NUMBER_BAND + STATE_BAND) + inner())
				end,
				Size = function()
					return UDim2.new(1, 0, 0, height() * (1 - NUMBER_BAND - STATE_BAND - BAR_BAND) - inner() * 3)
				end,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = function()
						return UDim.new(0, height() * ICON_GAP)
					end,
				}),
				iconRow(1),
				iconRow(2),
			}),

			-- patience bar: track + fill that drains from the right
			create("Frame")({
				Name = "Patience",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = function()
					return UDim2.new(1, 0, 0, height() * BAR_BAND)
				end,
				BackgroundColor3 = Theme.Color.Ink,
				BackgroundTransparency = Theme.Transparency.Track,
				Visible = function()
					return patience() >= 0
				end,
				create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
				create("Frame")({
					Name = "Fill",
					Size = function()
						return UDim2.fromScale(math.clamp(patience(), 0, 1), 1)
					end,
					BackgroundColor3 = function()
						return if patience() > warnAt then Theme.Color.Green else Theme.Color.Mustard
					end,
					create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
				}),
			}),
		}),
	}) :: Frame
end

local function OrderBoard(props: Props): SurfaceGui
	const warnAt = props.WarnAt or 1 / 3
	const count = function(): number
		return #props.Cards()
	end
	const layout = function(): Layout
		return layoutOf(props.CanvasSize(), count())
	end
	-- the cards drawn: the first Shown (Shown - 1 with an overflow, the last slot is "+k")
	const visible = function(): { Card | false }
		const all = props.Cards()
		const shape = layout()
		const drawn = if shape.Hidden > 0 then shape.Shown - 1 else shape.Shown
		const list: { Card | false } = {}
		for index = 1, drawn do
			list[index] = all[index]
		end
		if shape.Hidden > 0 then
			const more: Card | false = false
			table.insert(list, more)
		end
		return list
	end

	return create("SurfaceGui")({
		Name = props.Name or "OrderBoard",
		Adornee = props.Adornee,
		Face = props.Face or Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = props.PixelsPerStud or 100,
		-- a screen: it glows at night like a menu board
		LightInfluence = 0,
		Brightness = 1.2,
		AlwaysOnTop = false,
		MaxDistance = props.MaxDistance or 90,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = function()
			return not Cinematic.Active() and (props.Visible == nil or props.Visible())
		end,
		ClipsDescendants = true,

		create("Frame")({
			Name = "Board",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1), -- the gradient gives the Ink
			create("UIGradient")({ Rotation = 90, Color = Theme.Gradient(Theme.Tone.Ink) }),

			-- header column: "ORDERS" over the count
			create("Frame")({
				Name = "Header",
				BackgroundTransparency = 1,
				Position = function()
					const shape = layout()
					return UDim2.fromOffset(shape.Pad, shape.Pad)
				end,
				Size = function()
					const shape = layout()
					return UDim2.fromOffset(shape.Header, shape.Height)
				end,
				CartoonLabel({
					Name = "Title",
					Box = UDim2.fromScale(1, 0.3),
					Scaled = true,
					Color = Theme.Color.Mustard,
					Text = props.Title or "ORDERS",
				}),
				CartoonLabel({
					Name = "Count",
					Position = UDim2.fromScale(0, 0.32),
					Box = UDim2.fromScale(1, 0.62),
					Scaled = true,
					Text = function()
						return tostring(count())
					end,
				}),
			}),

			-- the cards, oldest on the left
			create("Frame")({
				Name = "Cards",
				BackgroundTransparency = 1,
				Position = function()
					const shape = layout()
					return UDim2.fromOffset(shape.Pad * 2 + shape.Header, shape.Pad)
				end,
				Size = function()
					const shape = layout()
					return UDim2.new(1, -(shape.Pad * 3 + shape.Header), 0, shape.Height)
				end,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = function()
						return UDim.new(0, layout().Gap)
					end,
				}),
				indexes(visible, function(entry: () -> Card | false, index: number)
					return orderCard(function(): Card?
						const value = entry()
						return if value then value else nil
					end, function(): number
						return if entry() == false then layout().Hidden else 0
					end, layout, warnAt, index)
				end),
				-- nothing to make
				CartoonLabel({
					Name = "Empty",
					Box = UDim2.fromScale(1, 0.4),
					Scaled = true,
					Color = Theme.Color.Slate,
					Stroke = 0,
					XAlignment = Enum.TextXAlignment.Left,
					Text = "No orders yet",
					Visible = function()
						return count() == 0
					end,
				}),
			}),
		}),
	}) :: SurfaceGui
end

return OrderBoard
