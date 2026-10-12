--!strict
-- TicketRail: the ticket that is always at hand in the focused prep mode (docs/art/prep-ui-spec.md §6.2): the order the
-- player works on, with the line of tickets behind it ("+N" is the queue; no bubbles in the world while focused).
--   Card (phone / desktop, left column)   paper Cream with a pin, the customer's face + "#12" + the patience level ring,
--                                         the toppings that leave the default (bun and sausage are implicit), the line the
--                                         customer said (15 px, two lines at most)
--   Strip (portrait)                      the same in two rows, one wide band
--   Empty                                 "No ticket yet" in a dashed card
--   Served                                a Green "Done" stamp over the paper
--   Urgent                                Mustard outline and a diamond "!" next to the ring (shape, never red)
-- Tap = OnCycle (next ticket). The patience ring is a level (a circle that drains), Teal, Mustard under 40 %, and the
-- diamond under 15 %. The face is a round placeholder with the first letter until the animal portraits exist (AST-117).
-- Pure: only props. Build it inside a Vide root.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)
local Chip = require(script.Parent.IngredientPanel.Chip)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke and UIListLayout children are fine, UIPadding is not.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type State = "Active" | "Served" | "Urgent"

export type Ticket = {
	Id: number,
	Name: string,
	-- What the customer said ("The usual, please.")
	Say: string,
	-- Ingredient keys that leave the default (bun + sausage are implicit); more than 3 are cut.
	Toppings: { string },
	-- 0..1 left of the patience.
	Patience: number,
	State: State,
}

export type Props = {
	Ticket: () -> Ticket?,
	-- Tickets waiting behind this one.
	Queue: () -> number,
	-- One wide row (portrait) instead of the card.
	Strip: () -> boolean,
	OnCycle: (() -> ())?,
	-- Text of the empty card (Content.Prep text).
	EmptyText: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Name: string?,
}

const LOW = 0.4
const CRITICAL = 0.15
const MAX_TOPPINGS = 3

-- Sets the LayoutOrder of a piece built by a helper (a UIListLayout row keeps them in this order).
local function ordered(instance: any, order: number): any
	instance.LayoutOrder = order
	return instance
end

local function initial(name: string): string
	return if name == "" then "?" else string.upper(string.sub(name, 1, 1))
end

-- The ring: a circle that drains from the top, colour by level.
local function ring(size: number, patience: () -> number): Frame
	return create("Frame")({
		Name = "Ring",
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Theme.Tone.Cream.Top,
		ClipsDescendants = true,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		createRaw("UIStroke")({
			Color = Theme.Color.Ink,
			Thickness = 3,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		create("Frame")({
			Name = "Level",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = function()
				return UDim2.fromScale(1, math.clamp(patience(), 0, 1))
			end,
			BackgroundColor3 = function()
				return if patience() > LOW then Theme.Tone.Teal.Bottom else Theme.Tone.Mustard.Bottom
			end,
			BorderSizePixel = 0,
		}),
	})
end

local function face(size: number, name: () -> string): Frame
	return create("Frame")({
		Name = "Face",
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Theme.Tone.Teal.Bottom,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		createRaw("UIStroke")({
			Color = Theme.Color.Ink,
			Thickness = 3,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		CartoonLabel({
			Text = function()
				return initial(name())
			end,
			TextSize = 16,
			Color = Theme.Color.Ink,
			Stroke = 0,
			Box = UDim2.fromScale(1, 1),
			XAlignment = Enum.TextXAlignment.Center,
			YAlignment = Enum.TextYAlignment.Center,
		}),
	})
end

-- Diamond "!" (urgent): a shape the colour blind can read.
local function alert(visible: () -> boolean): Frame
	return create("Frame")({
		Name = "Urgent",
		Size = UDim2.fromOffset(18, 18),
		Rotation = 45,
		BackgroundColor3 = Theme.Color.Mustard,
		Visible = visible,
		create("UICorner")({ CornerRadius = UDim.new(0, 3) }),
		createRaw("UIStroke")({
			Color = Theme.Color.Ink,
			Thickness = 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		CartoonLabel({
			Text = "!",
			TextSize = Theme.MinTextSize,
			Color = Theme.Color.Ink,
			Stroke = 0,
			Box = UDim2.fromScale(1, 1),
			XAlignment = Enum.TextXAlignment.Center,
			YAlignment = Enum.TextYAlignment.Center,
			Rotation = -45,
		}),
	})
end

local function queueChip(queue: () -> number): Frame
	return CartoonPanel({
		Name = "Queue",
		Tone = Theme.Tone.White,
		Radius = Theme.Radius.Small,
		Lip = 2,
		Outline = 2,
		Gloss = false,
		Size = UDim2.fromOffset(30, 22),
		Visible = function()
			return queue() > 0
		end,
		Children = {
			CartoonLabel({
				Text = function()
					return `+{queue()}`
				end,
				TextSize = Theme.MinTextSize,
				Color = Theme.Color.Ink,
				Stroke = 0,
				Box = UDim2.fromScale(1, 1),
				XAlignment = Enum.TextXAlignment.Center,
				YAlignment = Enum.TextYAlignment.Center,
			}),
		},
	})
end

-- Row of up to three topping chips.
local function toppings(props: Props, side: number): Frame
	const row: { any } = {
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
	}
	for index = 1, MAX_TOPPINGS do
		const slot = index
		-- a chip per slot, rebuilt by key: Chip is static, so a holder swaps it
		const holder = create("Frame")({
			Name = `Slot{index}`,
			LayoutOrder = index,
			Size = UDim2.fromOffset(side, side),
			BackgroundTransparency = 1,
			Visible = function()
				const ticket = props.Ticket()
				return ticket ~= nil and ticket.Toppings[slot] ~= nil
			end,
		})
		const shown = Vide.source("")
		local destroyChip: (() -> ())? = nil
		Vide.effect(function()
			const ticket = props.Ticket()
			const key = if ticket ~= nil then ticket.Toppings[slot] or "" else ""
			if key == Vide.untrack(shown) then
				return
			end
			Vide.untrack(function()
				shown(key)
				if destroyChip ~= nil then
					destroyChip()
					destroyChip = nil
				end
				holder:ClearAllChildren()
				if key ~= "" then
					const destroy, view = Vide.root(function(): Frame
						return Chip({ Key = key, Size = side })
					end)
					destroyChip = destroy
					view.Parent = holder
				end
				return nil
			end)
		end)
		Vide.cleanup(function()
			if destroyChip ~= nil then
				destroyChip()
			end
		end)
		table.insert(row, holder)
	end
	return create("Frame")({
		Name = "Toppings",
		Size = UDim2.new(1, 0, 0, side),
		BackgroundTransparency = 1,
		row,
	})
end

return function(props: Props): Frame
	const name = function(): string
		const ticket = props.Ticket()
		return if ticket ~= nil then ticket.Name else ""
	end
	const number = function(): string
		const ticket = props.Ticket()
		return if ticket ~= nil then `#{ticket.Id}` else ""
	end
	const patience = function(): number
		const ticket = props.Ticket()
		return if ticket ~= nil then ticket.Patience else 0
	end
	const urgent = function(): boolean
		const ticket = props.Ticket()
		return ticket ~= nil and (ticket.State == "Urgent" or ticket.Patience <= CRITICAL)
	end
	const has = function(): boolean
		return props.Ticket() ~= nil
	end
	const say = function(): string
		const ticket = props.Ticket()
		return if ticket ~= nil then `"{ticket.Say}"` else ""
	end
	const outlineColor = function(): Color3
		return if urgent() then Theme.Color.Mustard else Theme.Color.Ink
	end
	const outline = function(): number
		return if urgent() then Theme.Outline.Thick else Theme.Outline.Normal
	end
	const strip = props.Strip

	-- empty state, shared by both shapes
	const empty = CartoonPanel({
		Name = "Empty",
		Tone = Theme.Tone.Cream,
		Radius = Theme.Radius.Card,
		Size = UDim2.fromScale(1, 1),
		Visible = function()
			return not has()
		end,
		Children = {
			CartoonLabel({
				Text = props.EmptyText or "No ticket yet",
				TextSize = 16,
				Color = Theme.Color.Ink,
				Stroke = 0,
				Box = UDim2.fromScale(1, 1),
				XAlignment = Enum.TextXAlignment.Center,
				YAlignment = Enum.TextYAlignment.Center,
				Wrapped = true,
			}),
		},
	})

	-- the stamp of a served ticket
	const stamp = create("Frame")({
		Name = "Served",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(86, 34),
		Rotation = -10,
		BackgroundColor3 = Theme.Tone.Green.Bottom,
		ZIndex = 5,
		Visible = function()
			const ticket = props.Ticket()
			return ticket ~= nil and ticket.State == "Served"
		end,
		create("UICorner")({ CornerRadius = Theme.Radius.Chip }),
		createRaw("UIStroke")({
			Color = Theme.Color.Ink,
			Thickness = 3,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		CartoonLabel({
			Text = "Done",
			TextSize = 20,
			Color = Theme.Color.Ink,
			Stroke = 0,
			Box = UDim2.fromScale(1, 1),
			XAlignment = Enum.TextXAlignment.Center,
			YAlignment = Enum.TextYAlignment.Center,
		}),
	})

	-- the pin: Teal, the sign of "fixed"
	const pin = create("Frame")({
		Name = "Pin",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Theme.Tone.Teal.Bottom,
		ZIndex = 4,
		Visible = has,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		createRaw("UIStroke")({
			Color = Theme.Color.Ink,
			Thickness = 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})

	-- card (left column): header, toppings, the line
	const card = CartoonPanel({
		Name = "Card",
		Tone = Theme.Tone.Cream,
		Radius = Theme.Radius.Card,
		Outline = outline,
		OutlineColor = outlineColor,
		Size = UDim2.fromScale(1, 1),
		Visible = function()
			return has() and not strip()
		end,
		Padding = { Left = 8, Right = 8, Top = 12, Bottom = 4 },
		Children = {
			create("Frame")({
				Name = "Header",
				Size = UDim2.new(1, 0, 0, 32),
				BackgroundTransparency = 1,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),
				ordered(face(32, name), 1),
				CartoonLabel({
					LayoutOrder = 2,
					Text = number,
					TextSize = 16,
					Color = Theme.Color.Ink,
					Stroke = 0,
				}),
				ordered(ring(26, patience), 3),
				ordered(alert(urgent), 4),
				ordered(queueChip(props.Queue), 9),
			}),
			create("Frame")({
				Name = "Body",
				Position = UDim2.fromOffset(0, 38),
				Size = UDim2.new(1, 0, 1, -38),
				BackgroundTransparency = 1,
				create("UIListLayout")({
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),
				toppings(props, 36),
				CartoonLabel({
					LayoutOrder = 2,
					Name = "Say",
					Text = say,
					TextSize = 15,
					Color = Theme.Color.Ink,
					Stroke = 0,
					Box = UDim2.new(1, 0, 0, 40),
					Wrapped = true,
					Truncate = true,
					XAlignment = Enum.TextXAlignment.Left,
					YAlignment = Enum.TextYAlignment.Top,
				}),
			}),
		},
	})

	-- strip (portrait): row 1 face, number, ring, toppings, +N; row 2 the line
	const band = CartoonPanel({
		Name = "Strip",
		Tone = Theme.Tone.Cream,
		Radius = Theme.Radius.Card,
		Outline = outline,
		OutlineColor = outlineColor,
		Size = UDim2.fromScale(1, 1),
		Visible = function()
			return has() and strip()
		end,
		Padding = { Left = 8, Right = 8, Top = 6, Bottom = 2 },
		Children = {
			create("Frame")({
				Name = "Row1",
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundTransparency = 1,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 6),
				}),
				ordered(face(36, name), 1),
				CartoonLabel({ LayoutOrder = 2, Text = number, TextSize = 16, Color = Theme.Color.Ink, Stroke = 0 }),
				ordered(ring(30, patience), 3),
				ordered(alert(urgent), 4),
				ordered(toppings(props, 32), 5),
				ordered(queueChip(props.Queue), 9),
			}),
			CartoonLabel({
				Name = "Say",
				Position = UDim2.fromOffset(0, 42),
				Box = UDim2.new(1, 0, 0, 22),
				Text = say,
				TextSize = 15,
				Color = Theme.Color.Ink,
				Stroke = 0,
				Truncate = true,
				XAlignment = Enum.TextXAlignment.Left,
				YAlignment = Enum.TextYAlignment.Center,
			}),
		},
	})

	-- the whole thing is one touch target (cycle to the next ticket)
	return create("TextButton")({
		Name = props.Name or "TicketRail",
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Position = props.Position or UDim2.new(),
		Size = props.Size or UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Activated = function()
			if props.OnCycle ~= nil then
				props.OnCycle()
			end
		end,
		empty,
		card,
		band,
		pin,
		stamp,
	}) :: any
end
