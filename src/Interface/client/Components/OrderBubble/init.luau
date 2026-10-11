--!strict
-- OrderBubble: the order over a customer's head (FEAT-010 step 5, DEC-071; style guide §7.3 "Balão de pedido": white
-- rounded bubble, base icon (bun + sausage) + up to 3 topping icons in a row, the border is a patience ring that
-- drains). Pure: only props. CustomerController (TASK-034) owns the data, mounts it and decides when it shows.
-- Fixed pixel size (not studs) so every icon stays a >= 44 px target and the text >= 14 px on a phone at any distance
-- it is drawn (MaxDistance).
-- Icons: `Icon` (rbxassetid) when the art exists; until Q-152 / AST-071 a flat placeholder chip drawn here (colored
-- circle + short letters). The base icon is always the drawn placeholder (no Ingredients row for it). Provisional.
-- Empty (TASK-112, ANM-001; style guide §7.3 "Vazio = ANM-001"): no base icon and no toppings, same white bubble
-- and patience ring at the one-cell width; the order is still on the wire (the server judges it).
-- Always on top (user request after Play: the awning covered the bubble): drawn over the world, so the customer's
-- order reads through roofs and awnings. `Lift` (px) raises it over the prompt pill on the customer's neck, so the two
-- billboards never overlap on screen at any distance.
-- Cartoon pass (AST-091 "Balão de pedido"): white CartoonPanel bubble (gradient, lip, thick Ink outline), the patience
-- ring just inside the outline, tail under it; icons from the AST-071 sheet when the topping has no own `Icon`
-- (`Ingredient/<key>`, base = `Item/hot_dog`), the drawn chips stay as the last fallback.
-- Pair order (FEAT-038, TASK-148): `Toppings2` returning a list draws a 2nd row (one row per hot dog, same icon order)
-- and the bubble grows to fit both; returning nil (or no prop) keeps the single row. `Done` (1 or 2) draws that row
-- resolved for a moment: white veil + green check over it (the controller keeps it ~1 s, then the row goes away).
-- Every existing prop keeps its meaning: a caller that never passes Toppings2 gets the same single-row bubble.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Cinematic = require(script.Parent.Parent.Cinematic)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
const indexes = Vide.indexes
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke and UIPadding are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Topping = {
	Key: string, -- Content.Ingredients key
	Icon: string, -- rbxassetid; "" = placeholder chip
}

export type Props = {
	Adornee: Instance?,
	Visible: () -> boolean,
	-- In the order's display order (max 3, DEC-071). Empty = plain hot dog (K = 0).
	Toppings: () -> { Topping },
	-- Pair (FEAT-038): toppings of the 2nd hot dog (2nd row). nil = one row. Default nil.
	Toppings2: (() -> { Topping }?)?,
	-- Row drawn as resolved (veil + check): 0 = none, 1 or 2. Default 0.
	Done: (() -> number)?,
	-- true = empty bubble (ANM-001 blank folks): no icon at all. Default false.
	Empty: (() -> boolean)?,
	-- Patience left, 0..1. Negative = no ring (patience unknown: PatienceEndsAt = 0, T41).
	Patience: () -> number,
	-- Below this fraction the ring turns Mustard (Content.Moods.Rules.AnnoyedAt). Default 1/3.
	WarnAt: number?,
	-- World-space offset over the adornee (studs).
	Offset: Vector3?,
	MaxDistance: number?,
	-- Empty pixels under the tail tip (clears the prompt pill under the bubble). Default 0.
	Lift: number?,
	-- Drawn over the world (roofs, awnings). Default true.
	AlwaysOnTop: boolean?,
	Name: string?,
}

const CELL = 44 -- icon size (min touch/readable size, Theme.MinTouch)
const GAP = 6
const PAD = 10
const LIP = 4
const BUBBLE_HEIGHT = CELL + PAD * 2 + LIP -- one row
const ROW_GAP = 8 -- between the two rows of a pair
const TAIL = 16 -- tail square side (rotated 45°)
const CHECK = 32 -- check badge over a resolved row
const RING = 4
const LABEL_SIZE = 16

const WHITE = Color3.fromHex("#FFFFFF")
-- Placeholder look per ingredient until Q-152 (colors from style guide §2.1 food palette where there is one).
const PLACEHOLDER: { [string]: { Color: Color3, Label: string } } = {
	ketchup = { Color = Color3.fromHex("#E2402E"), Label = "K" },
	mustard = { Color = Color3.fromHex("#F6C12B"), Label = "M" },
	cheese = { Color = Color3.fromHex("#F39C2B"), Label = "Ch" },
	bacon = { Color = Color3.fromHex("#A8432F"), Label = "B" },
	potato_sticks = { Color = Color3.fromHex("#D9A55B"), Label = "PS" },
	cream_cheese = { Color = Theme.Color.Cream, Label = "CC" },
}
const BUN = Color3.fromHex("#E8B36B")
const SAUSAGE = Color3.fromHex("#B5482E")

local function placeholder(key: string): { Color: Color3, Label: string }
	return PLACEHOLDER[key] or { Color = Theme.Color.Teal, Label = string.upper(string.sub(key, 1, 1)) }
end

-- Readable label on any chip color: white text with the Ink outline (style guide §7.1).
local function label(text: string | () -> string): TextLabel
	return CartoonLabel({
		Name = "Label",
		Box = UDim2.fromScale(1, 1),
		TextSize = LABEL_SIZE,
		Text = text,
	})
end

-- Sheet image for a name, or nil (keeps the drawn fallback).
local function sheet(name: string): (string, Icons.Rect?)
	return Icons.ImageOf(name), Icons.Rect(name)
end

local function baseIcon(empty: () -> boolean): GuiObject
	const image, rect = sheet("Item/hot_dog")
	if rect then
		return create("ImageLabel")({
			Name = "Base",
			LayoutOrder = 0,
			Size = UDim2.fromOffset(CELL, CELL),
			BackgroundTransparency = 1,
			Image = image,
			ImageRectOffset = rect.Offset,
			ImageRectSize = rect.Size,
			Visible = function()
				return not empty()
			end,
		})
	end
	return create("Frame")({
		Name = "Base",
		LayoutOrder = 0,
		Size = UDim2.fromOffset(CELL, CELL),
		BackgroundTransparency = 1,
		Visible = function()
			return not empty()
		end,

		create("Frame")({
			Name = "Bun",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(CELL, CELL * 0.55),
			BackgroundColor3 = BUN,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			createRaw("UIStroke")({
				Color = Theme.Color.Ink,
				Thickness = Theme.Outline.Normal,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		}),
		create("Frame")({
			Name = "Sausage",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromOffset(CELL * 0.86, CELL * 0.24),
			BackgroundColor3 = SAUSAGE,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			createRaw("UIStroke")({
				Color = Theme.Color.Ink,
				Thickness = Theme.Stroke,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		}),
	})
end

local function toppingIcon(topping: () -> Topping, index: number): Frame
	local function sheetName(): string
		return `Ingredient/{topping().Key}`
	end
	local function hasArt(): boolean
		return topping().Icon ~= "" or Icons.Has(sheetName())
	end
	local function rect(): Icons.Rect
		if topping().Icon ~= "" then
			return { Offset = Vector2.zero, Size = Vector2.zero }
		end
		return Icons.Rect(sheetName()) or { Offset = Vector2.zero, Size = Vector2.zero }
	end
	return create("Frame")({
		Name = "Topping",
		LayoutOrder = index,
		Size = UDim2.fromOffset(CELL, CELL),
		BackgroundColor3 = function()
			return placeholder(topping().Key).Color
		end,
		BackgroundTransparency = function()
			return if hasArt() then 1 else 0
		end,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
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
			Image = function()
				const own = topping().Icon
				return if own ~= "" then own else Icons.ImageOf(sheetName())
			end,
			ImageRectOffset = function()
				return rect().Offset
			end,
			ImageRectSize = function()
				return rect().Size
			end,
			Visible = hasArt,
		}),
		create("Frame")({
			Name = "Placeholder",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = function()
				return not hasArt()
			end,
			label(function()
				return placeholder(topping().Key).Label
			end),
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

-- First 3 toppings of a list (DEC-071).
local function firstThree(list: { Topping }): { Topping }
	if #list <= 3 then
		return list
	end
	return { list[1], list[2], list[3] }
end

-- One hot dog: base icon + toppings in a row; `resolved` lays the veil and the check over it.
local function row(props: {
	Name: string,
	Order: number,
	Toppings: () -> { Topping },
	Empty: () -> boolean,
	Visible: () -> boolean,
	Resolved: () -> boolean,
}): Frame
	return create("Frame")({
		Name = props.Name,
		LayoutOrder = props.Order,
		Size = UDim2.new(1, 0, 0, CELL),
		BackgroundTransparency = 1,
		Visible = props.Visible,

		create("Frame")({
			Name = "Icons",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, GAP),
			}),
			baseIcon(props.Empty),
			indexes(function()
				return firstThree(props.Toppings())
			end, toppingIcon),
		}),

		-- Resolved: white veil over the icons and a green check in the middle
		create("Frame")({
			Name = "Veil",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 4, 1, 4),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.3,
			ZIndex = 3,
			Visible = props.Resolved,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			CartoonPanel({
				Name = "Check",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(CHECK, CHECK),
				Tone = Theme.Tone.Green,
				Outline = Theme.Outline.Normal,
				Radius = UDim.new(0.5, 0),
				Lip = 2,
				ZIndex = 4,
				Children = {
					create("ImageLabel")({
						Name = "Icon",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.8, 0.8),
						BackgroundTransparency = 1,
						ScaleType = Enum.ScaleType.Fit,
						Image = Icons.ImageOf("Ui/check"),
						ImageRectOffset = (Icons.Rect("Ui/check") or { Offset = Vector2.zero, Size = Vector2.zero }).Offset,
						ImageRectSize = (Icons.Rect("Ui/check") or { Offset = Vector2.zero, Size = Vector2.zero }).Size,
						ZIndex = 5,
					}),
				},
			}),
		}),
	})
end

return function(props: Props): BillboardGui
	const warnAt = props.WarnAt or 1 / 3
	const lift = math.max(props.Lift or 0, 0)
	const empty = props.Empty or function(): boolean
		return false
	end
	const done = props.Done or function(): number
		return 0
	end

	-- shown toppings: none in an empty bubble
	local function toppings(): { Topping }
		if empty() then
			return {}
		end
		return props.Toppings()
	end

	-- 2nd row (pair, FEAT-038): never in an empty bubble
	local function toppings2(): { Topping }?
		const second = props.Toppings2
		if empty() or second == nil then
			return nil
		end
		return second()
	end

	local function rows(): number
		return if toppings2() ~= nil then 2 else 1
	end

	local function width(): number
		local most = #toppings()
		const second = toppings2()
		if second ~= nil then
			most = math.max(most, #second)
		end
		const cells = 1 + math.min(most, 3)
		return PAD * 2 + cells * CELL + (cells - 1) * GAP
	end

	local function bubbleHeight(): number
		return BUBBLE_HEIGHT + (rows() - 1) * (CELL + ROW_GAP)
	end

	return create("BillboardGui")({
		Name = props.Name or "OrderBubble",
		Adornee = props.Adornee,
		Size = function()
			return UDim2.fromOffset(width(), bubbleHeight() + TAIL + lift)
		end,
		-- bottom of the gui (tail tip + lift) sits on the offset point
		SizeOffset = Vector2.new(0, 0.5),
		AlwaysOnTop = if props.AlwaysOnTop == nil then true else props.AlwaysOnTop,
		StudsOffsetWorldSpace = props.Offset or Vector3.new(0, 1.5, 0),
		MaxDistance = props.MaxDistance or 60,
		LightInfluence = 0,
		ResetOnSpawn = false,
		-- Off while a cinematic owns the screen (Interface/Cinematic).
		Enabled = function()
			return props.Visible() and not Cinematic.Active()
		end,

		create("Frame")({
			Name = "Tail",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = function()
				return UDim2.new(0.5, 0, 0, bubbleHeight() - 3)
			end,
			Size = UDim2.fromOffset(TAIL, TAIL),
			Rotation = 45,
			BackgroundColor3 = Theme.Tone.White.Lip,
			createRaw("UIStroke")({
				Color = Theme.Color.Ink,
				Thickness = Theme.Outline.Normal,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		}),

		CartoonPanel({
			Name = "Bubble",
			Size = function()
				return UDim2.new(1, 0, 0, bubbleHeight())
			end,
			Tone = Theme.Tone.White,
			Outline = Theme.Outline.Thick,
			Radius = UDim.new(0, (BUBBLE_HEIGHT - LIP) / 2),
			Lip = LIP,
			ZIndex = 2,
			Children = {
				-- Patience ring, just inside the Ink outline
				create("Frame")({
					Name = "Ring",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(1, -RING * 2, 1, -RING * 2),
					BackgroundTransparency = 1,
					create("UICorner")({ CornerRadius = UDim.new(0, (BUBBLE_HEIGHT - LIP) / 2 - RING) }),
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
					Name = "Rows",
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
					row({
						Name = "Row1",
						Order = 1,
						Toppings = toppings,
						Empty = empty,
						Visible = function()
							return true
						end,
						Resolved = function()
							return done() == 1 and rows() == 2
						end,
					}),
					row({
						Name = "Row2",
						Order = 2,
						Toppings = function()
							return toppings2() or {}
						end,
						Empty = empty,
						Visible = function()
							return rows() == 2
						end,
						Resolved = function()
							return done() == 2 and rows() == 2
						end,
					}),
				}),
			},
		}),
	})
end
