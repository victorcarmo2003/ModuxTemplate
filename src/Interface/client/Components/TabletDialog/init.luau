--!strict
-- TabletDialog: the mini-dialogue at the tablet, on the screen of the player taking the order only (FEAT-043, DEC-270 /
-- DEC-280; tech/restaurant-flow.md rev. 2 §3.2; TASK-383). The other players see the customer's line in a SpeechBalloon over
-- the rig (TabletController); nobody gets anything in the middle of the screen (AGENT-BRIEF §4, README "UI no centro").
--   Speaker tab   "You" (Teal) on the greeting, "Customer" (Mustard) on the customer's lines, over the top-left corner
--   Line          the line being said (one or two lines, 16 px Ink on a Cream card)
--   Items         the order said so far: one icon per item (bun, sausage, each topping; a pair = both hot dogs), each new
--                 one pops in (Motion.Pop, 0 -> 1.15 -> 1) when Reveal reaches it. Same AST-071 icons as the HUD note
-- Status only while talking: the talk speeds up with the interact key, not here. Owner 2026-10-21 (DEC-353): when Choice() is
-- true two buttons show under the line - SERVE (Green, the order is taken) and REFUSE (Ketchup, only that customer leaves);
-- the keys are TabletController's (E / Q, gamepad A / B).
-- Sized in px at UI scale 1 (smallest phone, 667 x 375): 250 px wide, text >= 14 px; the caller gives the UIScale and the
-- spot (default: lower left, over the joystick zone, clear of the hotbar and of the interact button on the right).
-- Pure: only props; build it inside a Vide root.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)
local CartoonButton = require(script.Parent.CartoonButton)

const create = Vide.create
const indexes = Vide.indexes
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke and UIScale are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Speaker = "Player" | "Customer"

export type Props = {
	Shown: () -> boolean,
	Speaker: () -> Speaker,
	-- The line being said (Content.Restaurant.Dialog)
	Text: () -> string,
	-- Ingredient keys of the order in the order they are said (bun, sausage, toppings; then the 2nd hot dog of a pair)
	Items: () -> { string },
	-- How many of Items were said already (0..#Items)
	Reveal: () -> number,
	-- Global UI scale (UiScale.Current). Default 1.
	Scale: (() -> number)?,
	Position: (UDim2 | () -> UDim2)?,
	AnchorPoint: Vector2?,
	-- Speaker tab texts (ui-text.md, Provisional). Defaults "You" / "Customer".
	PlayerLabel: string?,
	CustomerLabel: string?,
	Name: string?,
	-- owner 2026-10-21 (DEC-353): the SERVE / REFUSE pair under the line while this is true
	Choice: (() -> boolean)?,
	OnServe: (() -> ())?,
	OnRefuse: (() -> ())?,
	ServeLabel: string?,
	RefuseLabel: string?,
}

const WIDTH = 250
const PAD = 9
const CELL = 30
const GAP = 4
const TEXT_SIZE = 16
const TAB_HEIGHT = 22
const TAB_TEXT = 14
const TAB_OVERLAP = 7
const LABEL_SIZE = 14
const CHOICE_WIDTH = 92 -- px (UI scale 1; the talk card itself is scaled up on the left)
const CHOICE_HEIGHT = 32
const CHOICE_TEXT = 14
const CHOICE_GAP = 8 -- px between the card and the buttons

-- Letter chip for a key with no cell in the sheet (same colours as HudOrder / PlateTicket).
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

-- One said item; hidden (no room in the row) until revealed, then pops in.
local function item(key: () -> string, order: number, revealed: () -> boolean): Frame
	const pop = Motion.Pop(revealed)
	local function hasArt(): boolean
		return Icons.Has(iconName(key()))
	end
	local function rect(): Icons.Rect
		return Icons.Rect(iconName(key())) or { Offset = Vector2.zero, Size = Vector2.zero }
	end
	return create("Frame")({
		Name = "Item",
		LayoutOrder = order,
		Size = UDim2.fromOffset(CELL, CELL),
		BackgroundColor3 = function()
			return chipOf(key()).Color
		end,
		BackgroundTransparency = function()
			return if hasArt() then 1 else 0
		end,
		Visible = revealed,
		createRaw("UIScale")({ Scale = pop }),
		create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
		createRaw("UIStroke")({
			Color = Theme.Color.Ink,
			Thickness = Theme.Outline.Thin,
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

return function(props: Props): Frame
	const reveal = Motion.Reveal(props.Shown)
	const scale = props.Scale or function(): number
		return 1
	end

	local function isPlayer(): boolean
		return props.Speaker() == "Player"
	end

	local function anyItem(): boolean
		return props.Reveal() > 0 and #props.Items() > 0
	end

	local function choosing(): boolean
		return props.Choice ~= nil and props.Choice()
	end

	local function choice(name: string, text: string, tone: Theme.Tone, at: UDim2, anchor: Vector2, act: (() -> ())?): any
		return CartoonButton({
			Name = name,
			Text = text,
			TextSize = CHOICE_TEXT,
			Tone = tone,
			AnchorPoint = anchor,
			Position = at,
			Size = UDim2.fromOffset(CHOICE_WIDTH, CHOICE_HEIGHT),
			OnActivated = function()
				if act ~= nil and choosing() then
					act()
				end
			end,
		})
	end

	return create("Frame")({
		Name = props.Name or "TabletDialog",
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 1),
		Position = props.Position or UDim2.new(0, 12, 1, -150),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Active = false,
		Visible = function()
			return reveal() > 0.02
		end,
		createRaw("UIScale")({
			Scale = function()
				return scale() * reveal()
			end,
		}),
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, -TAB_OVERLAP),
		}),

		-- Speaker tab over the top-left corner of the card
		create("Frame")({
			Name = "TabRow",
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, TAB_HEIGHT),
			BackgroundTransparency = 1,
			ZIndex = 3,
			CartoonPanel({
				Name = "Speaker",
				Position = UDim2.fromOffset(PAD, 0),
				Size = UDim2.fromOffset(0, TAB_HEIGHT),
				AutomaticSize = Enum.AutomaticSize.X,
				Rotation = -3,
				Tone = function()
					return if isPlayer() then Theme.Tone.Teal else Theme.Tone.Mustard
				end,
				Outline = Theme.Outline.Normal,
				Lip = 3,
				Padding = { Left = 8, Right = 8 },
				ZIndex = 3,
				Children = {
					CartoonLabel({
						Box = UDim2.new(0, 0, 1, 0),
						AutomaticSize = Enum.AutomaticSize.X,
						TextSize = TAB_TEXT,
						Text = function()
							return if isPlayer() then props.PlayerLabel or "You" else props.CustomerLabel or "Customer"
						end,
						-- Ink on Teal and on Mustard (style guide §7.5: white on Teal is 2.8:1)
						Color = Theme.Color.Dark,
						Stroke = 0,
					}),
				},
			}),
		}),

		CartoonPanel({
			Name = "Card",
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Tone = Theme.Tone.Cream,
			Outline = Theme.Outline.Thick,
			Radius = Theme.Radius.Card,
			Padding = { Top = PAD + 4, Bottom = PAD, Left = PAD + 2, Right = PAD + 2 },
			Children = {
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 6),
				}),
				CartoonLabel({
					Name = "Line",
					LayoutOrder = 1,
					Box = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					TextSize = TEXT_SIZE,
					Wrapped = true,
					XAlignment = Enum.TextXAlignment.Left,
					Color = Theme.Color.Dark,
					Stroke = 0,
					Text = props.Text,
				}),
				create("Frame")({
					Name = "Items",
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y, -- a pair can wrap to a 2nd row
					BackgroundTransparency = 1,
					Visible = anyItem,
					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, GAP),
						Wraps = true,
					}),
					indexes(props.Items, function(key: () -> string, order: number)
						return item(key, order, function()
							return order <= props.Reveal()
						end)
					end),
				}),
			},
		}),

		-- owner 2026-10-21 (DEC-353; 2nd pass with the owner's sketch): the text card on top, two small buttons under it,
		-- one under each end (they were half the card wide and too tall)
		create("Frame")({
			Name = "Choice",
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, CHOICE_HEIGHT + CHOICE_GAP + TAB_OVERLAP),
			BackgroundTransparency = 1,
			Visible = choosing,
			choice("Serve", props.ServeLabel or "SERVE", Theme.Tone.Green, UDim2.fromOffset(PAD, CHOICE_GAP + TAB_OVERLAP), Vector2.zero, props.OnServe),
			choice("Refuse", props.RefuseLabel or "REFUSE", Theme.Tone.Ketchup, UDim2.new(1, -PAD, 0, CHOICE_GAP + TAB_OVERLAP), Vector2.new(1, 0), props.OnRefuse),
		}),
	})
end
