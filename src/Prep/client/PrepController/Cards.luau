--!strict
-- Cards: the customer cards of the Order and Serve tabs (docs/art/prep-ui-spec.md §5.1, §5.4, §7; TASK-177, TASK-179). Pure
-- presentation over the Feed (one source per customer): no rule, no packet except the taps handed in as callbacks. Flat
-- Frames in the house palette until the portraits exist (AST-117): a round face with the first letter, the patience as a ring
-- that drains (Teal, Mustard under 40 %, a diamond under 15 %), the toppings as chips, a state by shape AND text (never red).
-- Build them inside the Vide scope of a Board (the shell calls those inside its root); effects here live in that root.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Components = StarterPlayer.StarterPlayerScripts.client.Interface.Components
local CartoonButton = require(Components.CartoonButton)
local CartoonLabel = require(Components.CartoonLabel)
local CartoonPanel = require(Components.CartoonPanel)
local Chip = require(Components.IngredientPanel.Chip)
local Motion = require(Components.Motion)
local Theme = require(Components.Theme)
local Feed = require(script.Parent.Feed)

const create = Vide.create
const source = Vide.source
const untrack = Vide.untrack
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke, UIPadding and UIGradient are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

const prep = Content.Prep

const LOW = 0.4
const SHAKE_PX = 3
const SHAKE_STEP = 0.03 -- s per swing, 6 swings (spec §3.3: 180 ms)
const LIFT = 6 -- px the matching card rises (spec §5.4)

const Cards = {}

Cards.OrderSize = Vector2.new(116, 168)
Cards.ServeSize = Vector2.new(104, 150)

-- Small pieces -----------------------------------------------------------------------------------------------------------

local function ordered(instance: any, order: number): any
	instance.LayoutOrder = order
	return instance
end

local function face(size: number, name: () -> string): Frame
	return create("Frame")({
		Name = "Face",
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Theme.Tone.Teal.Bottom,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		CartoonLabel({
			Text = function(): string
				const value = name()
				return if value == "" then "?" else string.upper(string.sub(value, 1, 1))
			end,
			TextSize = Theme.MinTextSize,
			Color = Theme.Color.Ink,
			Stroke = 0,
			Box = UDim2.fromScale(1, 1),
		}),
	})
end

-- The patience ring: a disc that drains from the top, Teal then Mustard.
local function ring(size: number, patience: () -> number): Frame
	return create("Frame")({
		Name = "Patience",
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Theme.Tone.Cream.Top,
		ClipsDescendants = true,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		create("Frame")({
			Name = "Level",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = function(): UDim2
				return UDim2.fromScale(1, math.clamp(patience(), 0, 1))
			end,
			BackgroundColor3 = function(): Color3
				return if patience() > LOW then Theme.Tone.Teal.Bottom else Theme.Tone.Mustard.Bottom
			end,
			BorderSizePixel = 0,
		}),
	})
end

-- Diamond "!" (urgent): a shape the colour blind can read.
local function diamond(visible: () -> boolean): Frame
	return create("Frame")({
		Name = "Urgent",
		Size = UDim2.fromOffset(18, 18),
		Rotation = 45,
		BackgroundColor3 = Theme.Color.Mustard,
		Visible = visible,
		create("UICorner")({ CornerRadius = UDim.new(0, 3) }),
		createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		CartoonLabel({
			Text = "!",
			TextSize = Theme.MinTextSize,
			Color = Theme.Color.Ink,
			Stroke = 0,
			Box = UDim2.fromScale(1, 1),
			Rotation = -45,
		}),
	})
end

-- A check mark from two bars, in a square of `size` px.
local function checkMark(size: number): { Frame }
	const thick = math.max(2, math.floor(size * 0.12))
	local function bar(ax: number, ay: number, bx: number, by: number): Frame
		const dx, dy = bx - ax, by - ay
		const length = math.sqrt(dx * dx + dy * dy)
		return create("Frame")({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale((ax + bx) / 2, (ay + by) / 2),
			Size = UDim2.fromOffset(thick, length * size + thick),
			Rotation = math.deg(math.atan2(-dx, dy)),
			BackgroundColor3 = Theme.Color.Ink,
			BorderSizePixel = 0,
			ZIndex = 4,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		})
	end
	return { bar(0.3, 0.52, 0.44, 0.67), bar(0.44, 0.67, 0.72, 0.33) }
end

-- A cross from two bars (the Wrong seal).
local function crossMark(size: number): { Frame }
	const thick = math.max(2, math.floor(size * 0.12))
	local function bar(turn: number): Frame
		return create("Frame")({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(thick, size * 0.6),
			Rotation = turn,
			BackgroundColor3 = Theme.Color.Ink,
			BorderSizePixel = 0,
			ZIndex = 4,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		})
	end
	return { bar(45), bar(-45) }
end

-- The toppings as chips, in display order (bun and sausage are implicit).
local function chips(card: () -> Feed.Card, side: number): Frame
	return create("Frame")({
		Name = "Toppings",
		Size = UDim2.new(1, 0, 0, side),
		BackgroundTransparency = 1,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 3),
		}),
		Vide.values(function(): { string }
			return card().Toppings
		end, function(key: string): Frame
			return Chip({ Key = key, Size = side, LayoutOrder = table.find(untrack(card).Toppings, key) or 1 })
		end),
	})
end

-- Offset in px of a short shake when the Feed says this card (or slot) refused (spec §3.3 "Erro": 3 x 6 px, 180 ms).
function Cards.Shaker(kind: string, id: number): () -> number
	const offset = source(0)
	local last = untrack(Feed.Shake).N
	Vide.effect(function()
		const value = Feed.Shake()
		if value.N == last then
			return
		end
		last = value.N
		if value.Kind ~= kind or value.Id ~= id or Motion.Reduced() then
			return
		end
		task.spawn(function()
			for swing = 1, 6 do
				offset(if swing % 2 == 1 then SHAKE_PX else -SHAKE_PX)
				task.wait(SHAKE_STEP)
			end
			offset(0)
		end)
	end)
	return offset
end

-- A text chip (state of a card): a CartoonPanel pill, 14 px Ink text.
local function stateChip(text: () -> string, tone: Theme.Tone, visible: () -> boolean, mark: boolean): Frame
	return CartoonPanel({
		Name = "State",
		Tone = tone,
		Radius = Theme.Radius.Pill,
		Size = UDim2.new(1, 0, 0, 36),
		Position = UDim2.fromOffset(0, 4),
		Lip = 3,
		Outline = 2,
		Gloss = false,
		Visible = visible,
		Children = {
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),
			ordered(
				create("Frame")({
					Name = "Check",
					Size = UDim2.fromOffset(18, 18),
					BackgroundTransparency = 1,
					Visible = mark,
					checkMark(18),
				}),
				1
			),
			CartoonLabel({ LayoutOrder = 2, Text = text, TextSize = Theme.MinTextSize, Color = Theme.Color.Ink, Stroke = 0 }),
		},
	})
end

-- Order card -------------------------------------------------------------------------------------------------------------

-- One card of the Order tab (116 x 168): face, number, patience, toppings, what the customer said, and the one action.
-- Ready = Take (Mustard), Taken = Pin, pinned = Mine, Coming = Waiting (no button).
function Cards.Order(controller: any, id: number): Frame
	const card = Feed.CardOf(id)
	const pinned = function(): boolean
		return Feed.Pinned() == id
	end
	const offset = Cards.Shaker("card", id)
	const status = function(): string
		return card().Status
	end

	const header = create("Frame")({
		Name = "Header",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 3),
		}),
		ordered(
			face(26, function(): string
				return card().Name
			end),
			1
		),
		CartoonLabel({
			LayoutOrder = 2,
			Text = function(): string
				return `#{id}`
			end,
			TextSize = 16,
			Color = Theme.Color.Ink,
			Stroke = 0,
		}),
		ordered(
			ring(20, function(): number
				return card().Patience
			end),
			3
		),
		ordered(
			diamond(function(): boolean
				return card().Urgent
			end),
			4
		),
	})

	const action = create("Frame")({
		Name = "Action",
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, Theme.MinTouch),
		BackgroundTransparency = 1,
		CartoonButton({
			Name = "Take",
			Text = prep.Texts.Take,
			TextSize = 18,
			Tone = Theme.Tone.Mustard,
			Size = UDim2.new(1, 0, 0, Theme.MinTouch),
			Visible = function(): boolean
				return status() == "Ready"
			end,
			OnActivated = function()
				Feed.Take(controller, id)
			end,
		}),
		CartoonButton({
			Name = "Pin",
			Text = "Pin",
			TextSize = 18,
			Tone = Theme.Tone.Cream,
			Size = UDim2.new(1, 0, 0, Theme.MinTouch),
			Visible = function(): boolean
				return status() == "Taken" and not pinned()
			end,
			OnActivated = function()
				Feed.Pin(controller, id)
			end,
		}),
		stateChip(function(): string
			return "Mine"
		end, Theme.Tone.White, pinned, true),
		stateChip(function(): string
			return "Waiting"
		end, Theme.Tone.Cream, function(): boolean
			return status() == "Coming"
		end, false),
	})

	-- the pin: Teal, the sign of "fixed" (same as the ticket rail)
	const pin = create("Frame")({
		Name = "Pin",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Theme.Tone.Teal.Bottom,
		ZIndex = 4,
		Visible = pinned,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})

	return create("Frame")({
		Name = `Card_{id}`,
		LayoutOrder = id,
		Size = UDim2.fromOffset(Cards.OrderSize.X, Cards.OrderSize.Y),
		BackgroundTransparency = 1,
		CartoonPanel({
			Name = "Body",
			Tone = function(): Theme.Tone
				return if pinned() then Theme.Tone.Mustard else Theme.Tone.Cream
			end,
			Radius = Theme.Radius.Card,
			Outline = function(): number
				return if pinned() then Theme.Outline.Thick else Theme.Outline.Normal
			end,
			Size = UDim2.fromScale(1, 1),
			Position = function(): UDim2
				return UDim2.fromOffset(offset(), 0)
			end,
			Padding = { Left = 6, Right = 6, Top = 6, Bottom = 2 },
			Children = {
				create("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }),
				header,
				ordered(chips(card, 28), 2),
				CartoonLabel({
					LayoutOrder = 3,
					Name = "Say",
					Text = function(): string
						return card().Say
					end,
					TextSize = Theme.MinTextSize,
					Color = Theme.Color.Ink,
					Stroke = 0,
					Box = UDim2.new(1, 0, 0, 34),
					Wrapped = true,
					Truncate = true,
					XAlignment = Enum.TextXAlignment.Left,
					YAlignment = Enum.TextYAlignment.Top,
				}),
				action,
			},
		}),
		pin,
	})
end

-- Serve card ---------------------------------------------------------------------------------------------------------------

-- The delivery seal of the server's verdict (DEC-072), a different silhouette from the grade seals: Complete = Green circle
-- with a check, Incomplete = Mustard circle half filled, Wrong = Slate square with a cross. Written under it, with "+$N" on a tip.
local function stamp(id: number): Frame
	const side = 44
	local function current(): Feed.Stamp?
		return Feed.Stamps()[id]
	end
	local function shown(result: string): () -> boolean
		return function(): boolean
			const value = current()
			return value ~= nil and (value.Result == result or (result == "Complete" and value.Result == "Perfect"))
		end
	end
	local function disc(name: string, color: Color3, square: boolean, children: { any }): Frame
		return create("Frame")({
			Name = name,
			Size = UDim2.fromOffset(side, side),
			BackgroundColor3 = color,
			Visible = shown(name),
			create("UICorner")({ CornerRadius = if square then UDim.new(0, 8) else UDim.new(0.5, 0) }),
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			children,
		})
	end
	-- half Cream, half Mustard: a hard stop in the gradient
	const halfFill = createRaw("UIGradient")({
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Theme.Tone.Cream.Top),
			ColorSequenceKeypoint.new(0.5, Theme.Tone.Cream.Top),
			ColorSequenceKeypoint.new(0.501, Theme.Tone.Mustard.Bottom),
			ColorSequenceKeypoint.new(1, Theme.Tone.Mustard.Bottom),
		}),
	})
	return create("Frame")({
		Name = "Stamp",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(side + 24, side + 22),
		BackgroundTransparency = 1,
		ZIndex = 8,
		Visible = function(): boolean
			return current() ~= nil
		end,
		disc("Complete", Theme.Tone.Green.Bottom, false, checkMark(side)),
		disc("Incomplete", Color3.new(1, 1, 1), false, { halfFill }),
		disc("Wrong", Theme.Tone.Slate.Bottom, true, crossMark(side)),
		CartoonLabel({
			Name = "Word",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Box = UDim2.new(1, 0, 0, 20),
			Text = function(): string
				const value = current()
				return if value ~= nil then Feed.ServeText(value.Result, value.Amount) else ""
			end,
			TextSize = Theme.MinTextSize,
			Color = Theme.Color.Ink,
			StrokeColor = Theme.Color.Cream,
			Stroke = 3,
		}),
	})
end

-- One card of the Serve tab (104 x 150): the customer and, over it, whether the plate in hand matches. A tap picks it (the
-- Serve button confirms: two taps, never one by accident); a match lifts 6 px and gets a Green check (spec §5.4).
function Cards.Serve(controller: any, id: number, matches: (keys: { string }) -> boolean): Frame
	const card = Feed.CardOf(id)
	const offset = Cards.Shaker("card", id)
	const matching = function(): boolean
		return matches(card().Toppings)
	end
	const selected = function(): boolean
		return Feed.Selected() == id
	end
	const placeText = function(): string
		const value = card().Place
		return if value == "Table" then "Table" elseif value == "Counter" then "Counter" else "Line"
	end

	const badge = create("Frame")({
		Name = "Match",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -2, 0, 2),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = Theme.Tone.Green.Bottom,
		ZIndex = 5,
		Visible = matching,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		checkMark(24),
	})

	-- the rows live in their own list: the match badge and the delivery seal float over the card, outside the layout
	const rows: { any } = {
		create("UIListLayout")({
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 3),
		}),
		create("Frame")({
			Name = "Header",
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundTransparency = 1,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),
			ordered(
				face(26, function(): string
					return card().Name
				end),
				1
			),
			ordered(
				ring(22, function(): number
					return card().Patience
				end),
				2
			),
			ordered(
				diamond(function(): boolean
					return card().Urgent
				end),
				3
			),
		}),
		ordered(chips(card, 28), 2),
		CartoonLabel({
			LayoutOrder = 3,
			Name = "Say",
			Text = function(): string
				return card().Say
			end,
			TextSize = Theme.MinTextSize,
			Color = Theme.Color.Ink,
			Stroke = 0,
			Box = UDim2.new(1, 0, 0, 34),
			Wrapped = true,
			Truncate = true,
			XAlignment = Enum.TextXAlignment.Left,
			YAlignment = Enum.TextYAlignment.Top,
		}),
		CartoonLabel({
			LayoutOrder = 4,
			Name = "Place",
			Text = placeText,
			TextSize = Theme.MinTextSize,
			Color = Theme.Color.Ink,
			Stroke = 0,
			Box = UDim2.new(1, 0, 0, 20),
			XAlignment = Enum.TextXAlignment.Left,
		}),
	}
	const content: { any } = {
		create("Frame")({ Name = "Rows", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, rows }),
		badge,
		stamp(id),
	}

	return create("Frame")({
		Name = `Card_{id}`,
		LayoutOrder = id,
		Size = UDim2.fromOffset(Cards.ServeSize.X, Cards.ServeSize.Y + LIFT),
		BackgroundTransparency = 1,
		CartoonButton({
			Name = "Pick",
			Tone = function(): Theme.Tone
				return if selected() then Theme.Tone.Mustard else Theme.Tone.Cream
			end,
			Radius = Theme.Radius.Card,
			Outline = function(): number
				return if selected() or matching() then Theme.Outline.Thick else Theme.Outline.Normal
			end,
			AnchorPoint = Vector2.new(0, 1),
			Size = UDim2.fromOffset(Cards.ServeSize.X, Cards.ServeSize.Y),
			Position = function(): UDim2
				return UDim2.new(0, offset(), 1, if matching() then -LIFT else 0)
			end,
			Padding = 6,
			Children = content,
			OnActivated = function()
				Feed.Selected(if untrack(Feed.Selected) == id then 0 else id)
			end,
		}),
	})
end

-- Empty / waiting line in the board (the one pattern of spec §6.9): a Cream panel and one line of text.
function Cards.Empty(text: () -> string, visible: () -> boolean): Frame
	return CartoonPanel({
		Name = "Empty",
		Tone = Theme.Tone.Cream,
		Radius = Theme.Radius.Card,
		Outline = 2,
		Gloss = false,
		Size = UDim2.fromScale(1, 1),
		Visible = visible,
		Children = {
			CartoonLabel({
				Text = text,
				TextSize = 16,
				Color = Theme.Color.Ink,
				Stroke = 0,
				Box = UDim2.fromScale(1, 1),
				Wrapped = true,
			}),
		},
	})
end

Cards.CheckMark = checkMark

return Cards
