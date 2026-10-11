--!strict
-- HudOrder: the order card on the HUD (user request after Play: the awning hid the world bubble). Same reading as
-- the OrderBubble (style guide §7.3): white rounded card, bun + sausage + up to 3 toppings in a row, the border is the
-- patience ring that drains (Green, Mustard under WarnAt). Icons from the AST-071 sheet (Interface/Components/Icons,
-- `Ingredient/<key>`); a key without a cell gets a flat letter chip. Empty (ANM-001 blank folks) = the card with no
-- icon at all, one cell wide.
-- Status only (FEAT-032): Frames, labels and images, nothing clickable. Pure: only props. CustomerController picks
-- the customer (prompt target, else the Q1 customer in Waiting) and HudController mounts it on the top-left column,
-- under the money and day pills: clear of the joystick, hotbar and interact button (style guide §7.2).
-- Pixel sizes at UI scale 1 (smallest phone): icons 44 px, title 16 px.
-- Cartoon pass (AST-091): white CartoonPanel bubble (gradient, lip, thick Ink outline), the patience ring drawn just
-- inside the outline, the title on a small Ink tab over the top-left corner.
-- Pair order (FEAT-038, TASK-148): `Toppings2` returning a list adds a 2nd row (bun + sausage + its toppings) under
-- the first; nil (or no prop) keeps the single-row card. Existing callers are unchanged.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Icons = require(script.Parent.Icons)
local Theme = require(script.Parent.Theme)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
const indexes = Vide.indexes
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Shown: () -> boolean,
	-- Content.Ingredients topping keys in display order (max 3, DEC-071). Empty = plain hot dog (K = 0).
	Toppings: () -> { string },
	-- Pair (FEAT-038): topping keys of the 2nd hot dog (2nd row). nil = one row. Default nil.
	Toppings2: (() -> { string }?)?,
	-- true = blank customer (ANM-001): no icon. Default false.
	Empty: (() -> boolean)?,
	-- Patience left, 0..1. Negative = no ring.
	Patience: () -> number,
	-- Below this fraction the ring turns Mustard (Content.Moods.Rules.AnnoyedAt). Default 1/3.
	WarnAt: number?,
	-- Title over the card (ui-text.md, Provisional). Default "Order".
	Title: string?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Name: string?,
}

const CELL = 44
const GAP = 6
const PAD = 8
const LIP = 4
const CARD_HEIGHT = CELL + PAD * 2 + LIP -- one row
const ROW_GAP = 6 -- between the two rows of a pair
const TITLE_HEIGHT = 24
const TITLE_GAP = -6 -- the tab overlaps the card edge
const RING = 4
const TITLE_SIZE = 16
const LABEL_SIZE = 16
const MAX_TOPPINGS = 3
const BASE: { string } = { "bun", "sausage" }

const WHITE = Color3.fromHex("#FFFFFF")
-- Letter chip for a key with no cell in the sheet (same colors as the OrderBubble placeholders).
const CHIP: { [string]: { Color: Color3, Label: string } } = {
	bun = { Color = Color3.fromHex("#E8B36B"), Label = "B" },
	sausage = { Color = Color3.fromHex("#B5482E"), Label = "S" },
	ketchup = { Color = Color3.fromHex("#E2402E"), Label = "K" },
	mustard = { Color = Color3.fromHex("#F6C12B"), Label = "M" },
	cheese = { Color = Color3.fromHex("#F39C2B"), Label = "Ch" },
	bacon = { Color = Color3.fromHex("#A8432F"), Label = "B" },
	potato_sticks = { Color = Color3.fromHex("#D9A55B"), Label = "PS" },
	cream_cheese = { Color = Theme.Color.Cream, Label = "CC" },
}

local function chipOf(key: string): { Color: Color3, Label: string }
	return CHIP[key] or { Color = Theme.Color.Teal, Label = string.upper(string.sub(key, 1, 1)) }
end

local function iconName(key: string): string
	return `Ingredient/{key}`
end

local function cell(key: () -> string, order: number): Frame
	local function hasArt(): boolean
		return Icons.Has(iconName(key()))
	end
	local function rect(): Icons.Rect
		return Icons.Rect(iconName(key())) or { Offset = Vector2.zero, Size = Vector2.zero }
	end
	return create("Frame")({
		Name = "Cell",
		LayoutOrder = order,
		Size = UDim2.fromOffset(CELL, CELL),
		BackgroundColor3 = function()
			return chipOf(key()).Color
		end,
		BackgroundTransparency = function()
			return if hasArt() then 1 else 0
		end,
		create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
		createRaw("UIStroke")({
			Color = Theme.Color.Ink,
			Thickness = Theme.Outline.Normal,
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
			Visible = hasArt,
		}),
		CartoonLabel({
			Name = "Letter",
			Box = UDim2.fromScale(1, 1),
			TextSize = LABEL_SIZE,
			Text = function()
				return chipOf(key()).Label
			end,
			Visible = function()
				return not hasArt()
			end,
		}),
	})
end

-- Opaque up to `fraction` of the border, transparent after it: the ring drains from its right end.
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

return function(props: Props): Frame
	const warnAt = props.WarnAt or 1 / 3
	const empty = props.Empty or function(): boolean
		return false
	end

	-- Keys drawn in a row: bun, sausage, then the toppings; nothing for a blank customer.
	local function rowKeys(toppings: { string }): { string }
		if empty() then
			return {}
		end
		const list = table.clone(BASE)
		for index, key in toppings do
			if index > MAX_TOPPINGS then
				break
			end
			table.insert(list, key)
		end
		return list
	end

	local function keys(): { string }
		return rowKeys(props.Toppings())
	end

	-- 2nd row (pair): nil = none; never on a blank customer
	local function keys2(): { string }?
		const read = props.Toppings2
		if empty() or read == nil then
			return nil
		end
		const second = read()
		return if second ~= nil then rowKeys(second) else nil
	end

	local function rows(): number
		return if keys2() ~= nil then 2 else 1
	end

	local function width(): number
		local cells = math.max(#keys(), 1)
		const second = keys2()
		if second ~= nil then
			cells = math.max(cells, #second)
		end
		return PAD * 2 + cells * CELL + (cells - 1) * GAP
	end

	local function cardHeight(): number
		return CARD_HEIGHT + (rows() - 1) * (CELL + ROW_GAP)
	end

	local function iconRow(name: string, order: number, list: () -> { string }, visible: () -> boolean): Frame
		return create("Frame")({
			Name = name,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, CELL),
			BackgroundTransparency = 1,
			Visible = visible,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, GAP),
			}),
			indexes(list, cell),
		})
	end

	return create("Frame")({
		Name = props.Name or "HudOrder",
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Position = props.Position or UDim2.fromOffset(12, 114),
		Size = function()
			return UDim2.fromOffset(width(), TITLE_HEIGHT + TITLE_GAP + cardHeight())
		end,
		BackgroundTransparency = 1,
		Visible = props.Shown,

		CartoonPanel({
			Name = "Card",
			Position = UDim2.fromOffset(0, TITLE_HEIGHT + TITLE_GAP),
			Size = function()
				return UDim2.new(1, 0, 0, cardHeight())
			end,
			Tone = Theme.Tone.White,
			Outline = Theme.Outline.Thick,
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
						Color = WHITE, -- the gradient below gives the color
						Enabled = function()
							return props.Patience() >= 0
						end,
						create("UIGradient")({
							Color = function()
								const color = if props.Patience() > warnAt then Theme.Color.Green else Theme.Color.Mustard
								return ColorSequence.new(color)
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
						FillDirection = Enum.FillDirection.Vertical,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, ROW_GAP),
					}),
					iconRow("Row1", 1, keys, function()
						return true
					end),
					iconRow("Row2", 2, function()
						return keys2() or {}
					end, function()
						return rows() == 2
					end),
				}),
			},
		}),

		-- Title tab over the top-left corner of the card
		CartoonPanel({
			Name = "Title",
			Position = UDim2.fromOffset(PAD, 0),
			Size = UDim2.fromOffset(0, TITLE_HEIGHT),
			AutomaticSize = Enum.AutomaticSize.X,
			Rotation = -3,
			Tone = Theme.Tone.Mustard,
			Outline = Theme.Outline.Normal,
			Lip = 3,
			Padding = { Left = 8, Right = 8 },
			ZIndex = 2,
			Children = {
				CartoonLabel({
					Box = UDim2.new(0, 0, 1, 0),
					AutomaticSize = Enum.AutomaticSize.X,
					TextSize = TITLE_SIZE,
					Text = props.Title or "Order",
					Color = Theme.Color.Dark,
					Stroke = 0,
				}),
			},
		}),
	})
end
