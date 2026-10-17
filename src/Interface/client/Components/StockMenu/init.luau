--!strict
-- StockMenu: the phone card of the restaurant restock (FEAT-050; design/restaurant-flow.md; TASK-389, minimum version).
-- There is no menu packet yet: a hold on the phone places the server's "quick order" (SupplyService Order.quick). This
-- card is what the player sees while aiming at / holding the phone: the boxes that order should bring (one cell per
-- package, icon + "x2"), its cost ("$22", red when the party cannot pay) and the hold hint; while a call is on the way it
-- reads "On the way 0:45" instead and the cells fade. The lines and cost are a client PREDICTION (same rule as the
-- server, from what this client sees); the server decides the real order and the money.
-- Pure: only props. HUD card sized in px at UI scale 1 (the owner ScreenGui applies Theme.ScaleOf). Not touchable.
-- Also exports Clock (seconds -> "0:45"), Chip (HUD status chip, Chip.luau) and Tag (world counter, Tag.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)
local Chip = require(script.Chip)
local Tag = require(script.Tag)

const create = Vide.create
const indexes = Vide.indexes
-- Vide 0.4.1 types `create` for 19 classes only; UIScale is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Line = {
	Package: string, -- Content.Packages key
	Name: string,
	Count: number, -- boxes of this package in the order
}

export type Props = {
	Visible: () -> boolean,
	Lines: () -> { Line },
	Cost: () -> number,
	CanPay: () -> boolean,
	-- seconds until the call on the way lands; 0 = none on the way
	SecondsLeft: () -> number,
	-- footer while idle ("Hold E to call")
	Hint: () -> string,
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Name: string?,
}

const WIDTH = 248
const HEIGHT = 118
const TITLE = 18
const CELL = 30
const CELL_TEXT = 16
const FOOTER = 15
const GAP = 6
const EMPTY_RECT: Icons.Rect = { Offset = Vector2.zero, Size = Vector2.zero }

-- 45 -> "0:45", 75 -> "1:15"
local function clock(seconds: number): string
	const whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function cell(line: () -> Line, order: number, dim: () -> boolean): Frame
	local function iconName(): string
		return `Item/{line().Package}`
	end
	local function rect(): Icons.Rect
		return Icons.Rect(iconName()) or EMPTY_RECT
	end
	return create("Frame")({
		Name = "Cell",
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(CELL + 26, CELL),
		create("ImageLabel")({
			Name = "Icon",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(CELL, CELL),
			Image = function()
				return Icons.ImageOf(iconName())
			end,
			ImageRectOffset = function()
				return rect().Offset
			end,
			ImageRectSize = function()
				return rect().Size
			end,
			ImageTransparency = function()
				return if dim() then 0.55 else 0
			end,
		}),
		CartoonLabel({
			Name = "Count",
			Position = UDim2.fromOffset(CELL + 2, 0),
			Box = UDim2.fromOffset(24, CELL),
			TextSize = CELL_TEXT,
			XAlignment = Enum.TextXAlignment.Left,
			Text = function()
				return `x{line().Count}`
			end,
			Transparency = function()
				return if dim() then 0.45 else 0
			end,
		}),
	})
end

local function StockMenu(props: Props): Frame
	local function onTheWay(): boolean
		return props.SecondsLeft() > 0
	end
	local function empty(): boolean
		return #props.Lines() == 0
	end
	const scale = Motion.Pop(props.Visible)

	return CartoonPanel({
		Name = props.Name or "StockMenu",
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0),
		Position = props.Position or UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		Tone = Theme.Tone.Ink,
		Transparency = Theme.Transparency.Panel,
		Radius = Theme.Radius.Card,
		Padding = { Top = 6, Bottom = 6, Left = 10, Right = 10 },
		Visible = function()
			return scale() > 0.01
		end,
		Decor = {
			createRaw("UIScale")({ Scale = scale }),
		},
		Children = {
			-- title row: phone icon, "Quick order" / "Delivery", cost
			create("ImageLabel")({
				Name = "Phone",
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(24, 24),
				Image = Icons.ImageOf("Hud/phone"),
				ImageRectOffset = (Icons.Rect("Hud/phone") or EMPTY_RECT).Offset,
				ImageRectSize = (Icons.Rect("Hud/phone") or EMPTY_RECT).Size,
			}),
			CartoonLabel({
				Name = "Title",
				Position = UDim2.fromOffset(30, 0),
				Box = UDim2.new(1, -100, 0, 24),
				TextSize = TITLE,
				XAlignment = Enum.TextXAlignment.Left,
				Text = function()
					return if onTheWay() then "Delivery" else "Quick order"
				end,
			}),
			CartoonLabel({
				Name = "Cost",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Box = UDim2.fromOffset(70, 24),
				TextSize = TITLE,
				XAlignment = Enum.TextXAlignment.Right,
				Color = function()
					return if props.CanPay() then Theme.Color.Mustard else Theme.Color.NoCash
				end,
				Text = function()
					return `${props.Cost()}`
				end,
				Visible = function()
					return not onTheWay() and not empty()
				end,
			}),

			-- the boxes of the order
			create("Frame")({
				Name = "Lines",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, 24 + GAP),
				Size = UDim2.new(1, 0, 0, CELL),
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 0),
				}),
				indexes(props.Lines, function(line: () -> Line, index: number)
					return cell(line, index, onTheWay)
				end),
			}),
			CartoonLabel({
				Name = "Empty",
				Position = UDim2.fromOffset(0, 24 + GAP),
				Box = UDim2.new(1, 0, 0, CELL),
				TextSize = CELL_TEXT,
				XAlignment = Enum.TextXAlignment.Left,
				Text = "Nothing to order",
				Visible = function()
					return empty() and not onTheWay()
				end,
			}),

			-- footer: countdown or the hold hint
			CartoonLabel({
				Name = "Footer",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Box = UDim2.new(1, 0, 0, 22),
				TextSize = FOOTER,
				XAlignment = Enum.TextXAlignment.Left,
				Color = function()
					return if onTheWay() then Theme.Color.Mustard else Theme.Color.Text
				end,
				Text = function()
					return if onTheWay() then `On the way {clock(props.SecondsLeft())}` else props.Hint()
				end,
			}),
		},
	})
end

return table.freeze({
	new = StockMenu,
	Clock = clock,
	Chip = Chip,
	Tag = Tag,
})
