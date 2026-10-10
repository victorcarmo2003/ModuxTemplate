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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Icons = require(script.Parent.Icons)
local Theme = require(script.Parent.Theme)

const create = Vide.create
const indexes = Vide.indexes
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Shown: () -> boolean,
	-- Content.Ingredients topping keys in display order (max 3, DEC-071). Empty = plain hot dog (K = 0).
	Toppings: () -> { string },
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
const CARD_HEIGHT = CELL + PAD * 2
const TITLE_HEIGHT = 20
const TITLE_GAP = 2
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
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		createRaw("UIStroke")({
			Color = Theme.Color.Ink,
			Thickness = Theme.Stroke,
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
		create("TextLabel")({
			Name = "Letter",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			FontFace = Theme.Font.Title,
			TextSize = LABEL_SIZE,
			TextColor3 = Theme.Color.Text,
			Text = function()
				return chipOf(key()).Label
			end,
			Visible = function()
				return not hasArt()
			end,
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Stroke }),
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

	-- Keys drawn in the row: bun, sausage, then the toppings; nothing for a blank customer.
	local function keys(): { string }
		if empty() then
			return {}
		end
		const list = table.clone(BASE)
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

	return create("Frame")({
		Name = props.Name or "HudOrder",
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Position = props.Position or UDim2.fromOffset(12, 114),
		Size = function()
			return UDim2.fromOffset(width(), TITLE_HEIGHT + TITLE_GAP + CARD_HEIGHT)
		end,
		BackgroundTransparency = 1,
		Visible = props.Shown,

		create("TextLabel")({
			Name = "Title",
			Position = UDim2.fromOffset(PAD, 0),
			Size = UDim2.new(1, -PAD, 0, TITLE_HEIGHT),
			BackgroundTransparency = 1,
			FontFace = Theme.Font.Title,
			TextSize = TITLE_SIZE,
			TextColor3 = Theme.Color.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = props.Title or "Order",
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Stroke }),
		}),

		create("Frame")({
			Name = "Card",
			Position = UDim2.fromOffset(0, TITLE_HEIGHT + TITLE_GAP),
			Size = UDim2.new(1, 0, 0, CARD_HEIGHT),
			BackgroundColor3 = WHITE,

			create("UICorner")({ CornerRadius = UDim.new(0, CARD_HEIGHT / 2) }),
			createRaw("UIStroke")({
				Color = Theme.Color.Ink,
				Thickness = Theme.Stroke,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),

			create("Frame")({
				Name = "Ring",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 2,
				create("UICorner")({ CornerRadius = UDim.new(0, CARD_HEIGHT / 2) }),
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
				ZIndex = 3,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, GAP),
				}),
				indexes(keys, cell),
			}),
		}),
	})
end
