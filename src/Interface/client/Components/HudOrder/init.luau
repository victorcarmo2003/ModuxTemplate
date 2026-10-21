--!strict
-- HudOrder: the order card on the HUD (user request after Play: the awning hid the world bubble). Same reading as
-- the OrderBubble (style guide §7.3): white rounded card, one hot dog icon + up to 3 toppings in a row, the border is the
-- patience ring that drains (Green, Mustard under WarnAt). Icons from the AST-071 sheet (Interface/Components/Icons,
-- `Ingredient/<key>`); a key without a cell gets a flat letter chip. Empty (ANM-001 blank folks) = the card with no
-- icon at all, one cell wide.
-- Status only (FEAT-032): Frames, labels and images, nothing clickable. Pure: only props. CustomerController picks
-- the customer (prompt target, else the Q1 customer in Waiting) and HudController mounts it on the top-left column,
-- under the Roblox bar and the sanity meter (2026-10-12): clear of the joystick, hotbar and interact button (style guide §7.2).
-- Pixel sizes at UI scale 1 (smallest phone): icons 44 px, title 16 px.
-- Cartoon pass (AST-091): white CartoonPanel bubble (gradient, lip, thick Ink outline), the patience ring drawn just
-- inside the outline, the title on a small Ink tab over the top-left corner.
-- Pair order (FEAT-038, TASK-148): `Toppings2` returning a list adds a 2nd row (bun + sausage + its toppings) under
-- the first; nil (or no prop) keeps the single-row card. Existing callers are unchanged.
-- Progressive reveal (Content.HudReveal): `Revealed` pops the card in (Motion.RevealPop) the first time the order
-- card is released; nil = always. Position (HudController): top-left, under the sanity meter when that is on screen.
-- Talk reveal (FEAT-043, TASK-384): `Reveal` = items said so far at the tablet, in the talk order (bun, sausage, the
-- toppings of row 1, then bun, sausage, toppings of row 2; TabletController:MyTalk().Reveal). The hot dog icon shows from
-- the bun on, topping i from item 2 + i; the 2nd row from its bun. Each new cell pops in (0.25 s, Motion.Reveal; reduced
-- motion = no animation) and the card grows with it. nil (no prop) = every item, no pop: the card as before.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Icons = require(script.Parent.Icons)
local Theme = require(script.Parent.Theme)
local Motion = require(script.Parent.Motion)
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
	-- Progressive reveal: scales in when true, away when false. nil = always.
	Revealed: (() -> boolean)?,
	-- Talk reveal: items said so far (0..#items, talk order, see the header). nil = all, no pop. Default nil.
	Reveal: (() -> number)?,
	Position: (UDim2 | () -> UDim2)?,
	AnchorPoint: Vector2?,
	Name: string?,
}

const CELL = 36
const GAP = 6
const PAD = 8
const LIP = 4
const CARD_HEIGHT = CELL + PAD * 2 + LIP -- one row
const ROW_GAP = 6 -- between the two rows of a pair
const TITLE_HEIGHT = 22
const TITLE_GAP = -6 -- the tab overlaps the card edge
const RING = 4
const TITLE_SIZE = 14
const LABEL_SIZE = 14
const MAX_TOPPINGS = 3
-- Same base as the OrderBubble: ONE hot dog icon (bun + sausage), then the toppings in the same order.
const BASE_KEY = "__base"
const BASE: { string } = { BASE_KEY }

const WHITE = Color3.fromHex("#FFFFFF")
-- Letter chip for a key with no cell in the sheet (same colors as the OrderBubble placeholders).
const CHIP: { [string]: { Color: Color3, Label: string } } = {
	__base = { Color = Color3.fromHex("#E8B36B"), Label = "HD" },
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
	if key == BASE_KEY then
		return "Item/hot_dog"
	end
	return `Ingredient/{key}`
end

-- `pop` = the cell scales in when created (talk reveal); false = static, as before.
local function cell(key: () -> string, order: number, pop: boolean): Frame
	local scale: (() -> number)? = nil
	if pop then
		const born = Vide.source(false)
		const thread = task.defer(function()
			born(true)
		end)
		Vide.cleanup(function()
			if coroutine.status(thread) == "suspended" then
				task.cancel(thread)
			end
		end)
		scale = Motion.Reveal(born)
	end
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
		if scale ~= nil then createRaw("UIScale")({ Scale = scale }) else nil,
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
	const reveal = Motion.RevealPop(function()
		return props.Revealed == nil or props.Revealed()
	end)

	const revealProp = props.Reveal
	const popCells = revealProp ~= nil
	-- Items said so far; no prop = every item.
	local function said(): number
		return if revealProp ~= nil then revealProp() else math.huge
	end

	-- Keys drawn in a row: bun, sausage, then the toppings; nothing for a blank customer. `before` = talk items said
	-- before this row (row 1: 0; row 2: the 2 + K of row 1): the icon needs the bun, topping i needs item 2 + i.
	local function rowKeys(toppings: { string }, before: number): { string }
		if empty() then
			return {}
		end
		const heard = said() - before
		if heard < 1 then
			return {}
		end
		const list = table.clone(BASE)
		for index, key in toppings do
			if index > MAX_TOPPINGS or heard < 2 + index then
				break
			end
			table.insert(list, key)
		end
		return list
	end

	local function keys(): { string }
		return rowKeys(props.Toppings(), 0)
	end

	-- 2nd row (pair): nil = none (or its bun not said yet); never on a blank customer
	local function keys2(): { string }?
		const read = props.Toppings2
		if empty() or read == nil then
			return nil
		end
		const second = read()
		if second == nil then
			return nil
		end
		const before = 2 + math.min(#props.Toppings(), MAX_TOPPINGS)
		if said() < before + 1 then
			return nil
		end
		return rowKeys(second, before)
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
			indexes(list, function(key: () -> string, order: number): Frame
				return cell(key, order, popCells)
			end),
		})
	end

	return create("Frame")({
		Name = props.Name or "HudOrder",
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Position = props.Position or UDim2.fromOffset(10, 88),
		Size = function()
			return UDim2.fromOffset(width(), TITLE_HEIGHT + TITLE_GAP + cardHeight())
		end,
		BackgroundTransparency = 1,
		Visible = function()
			return props.Shown() and reveal() > 0.02
		end,
		createRaw("UIScale")({ Scale = reveal }),

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
