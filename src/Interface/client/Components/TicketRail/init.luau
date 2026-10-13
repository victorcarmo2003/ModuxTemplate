--!strict
-- TicketRail: the ticket that is always at hand in the focused prep mode (docs/art/prep-ui-spec.md §6.2): the order the
-- player works on, with the line of tickets behind it ("+N" is the queue; no bubbles in the world while focused).
--   Card (phone / desktop, left column)   a tall paper (Cream, a Teal pin): the customer's face and "#12" on top (fixed widths, nothing
--                                         invades another), the order as an OrderStack (bun, sausage and the toppings as layers that
--                                         alternate Cream / light Mustard), the line the customer said (one line, two on a desktop), and
--                                         a thin patience bar at the bottom (hidden when Patience is 0)
--   Strip (portrait)                      the same in two rows, one wide band, the layers side by side
--   Empty                                 "No ticket yet" in a slim pill
--   Served                                a Green "Done" stamp over the paper
--   Urgent                                Mustard outline and a diamond "!" by the pin (shape, never red)
-- Tap = OnCycle (next ticket). The patience bar is a level, Teal, Mustard under 40 %. The face is a round placeholder with the
-- first letter until the animal portraits exist (AST-117).
-- Pure: only props. Build it inside a Vide root.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)
local OrderStack = require(script.Parent.OrderStack)
local Sprites = require(script.Parent.OrderStack.Sprites)
local CartoonButton = require(script.Parent.CartoonButton)

const create = Vide.create
const untrack = Vide.untrack
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

-- The Take button of the customer at the counter (TASK-206): shown while someone waits to be taken; a bar at the bottom of the
-- card. Its tap never cycles the ticket.
export type Take = {
	Visible: () -> boolean,
	Text: () -> string,
	OnPress: () -> (),
}

export type Props = {
	Ticket: () -> Ticket?,
	Take: Take?,
	-- Tickets waiting behind this one.
	Queue: () -> number,
	-- One wide row (portrait) instead of the card.
	Strip: () -> boolean,
	-- A desktop-sized paper: bigger layers, the line in two rows (nil = false).
	Roomy: (() -> boolean)?,
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

-- Sets the LayoutOrder of a piece built by a helper (a UIListLayout row keeps them in this order).
local function ordered(instance: any, order: number): any
	instance.LayoutOrder = order
	return instance
end

local function initial(name: string): string
	return if name == "" then "?" else string.upper(string.sub(name, 1, 1))
end

-- The patience bar: a thin level, Teal, Mustard under 40 %; nothing at all when there is no patience to show (Patience 0).
local function patienceBar(patience: () -> number, position: UDim2, width: UDim2): Frame
	return create("Frame")({
		Name = "Patience",
		AnchorPoint = Vector2.new(0, 1),
		Position = position,
		Size = width + UDim2.fromOffset(0, 8),
		BackgroundColor3 = Theme.Tone.Cream.Bottom,
		ClipsDescendants = true,
		Visible = function(): boolean
			return patience() > 0
		end,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		createRaw("UIStroke")({
			Color = Theme.Color.Ink,
			Thickness = 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		create("Frame")({
			Name = "Level",
			Size = function(): UDim2
				return UDim2.fromScale(math.clamp(patience(), 0, 1), 1)
			end,
			BackgroundColor3 = function(): Color3
				return if patience() > LOW then Theme.Tone.Teal.Bottom else Theme.Tone.Mustard.Bottom
			end,
			BorderSizePixel = 0,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
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
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Tone = Theme.Tone.White,
		Radius = Theme.Radius.Small,
		Lip = 2,
		Outline = 2,
		Gloss = false,
		Size = UDim2.fromOffset(30, 22),
		ZIndex = 3,
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
		return ticket ~= nil and (ticket.State == "Urgent" or (ticket.Patience > 0 and ticket.Patience <= CRITICAL))
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
		-- nothing to read: a slim pill, not a blank card (the Take bar comes right under it)
		Size = UDim2.new(1, 0, 0, 40),
		Visible = function()
			return not has()
		end,
		Children = {
			CartoonLabel({
				Text = props.EmptyText or "No ticket yet",
				TextSize = Theme.MinTextSize,
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
		-- the sprite of the pin over the flat disc (the disc is what shows until the image is through moderation)
		create("ImageLabel")({
			Name = "Sprite",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(28, 28),
			BackgroundTransparency = 1,
			Image = Sprites.Pin,
			ScaleType = Enum.ScaleType.Fit,
		}),
	})

	const roomy = props.Roomy
	const isRoomy = function(): boolean
		return roomy ~= nil and roomy()
	end
	-- the layers of the order: the same stack for both shapes (the band is fixed when the ticket is built)
	const toppingsOf = function(): { string }
		const ticket = props.Ticket()
		return if ticket ~= nil then ticket.Toppings else {}
	end

	-- face and number: fixed widths (nothing grows into its neighbour); the queue chip is pinned to the right edge
	local function who(faceSize: number, numberW: number, numberSize: number): Frame
		return create("Frame")({
			Name = "Who",
			Size = UDim2.new(0, faceSize + 3 + numberW, 1, 0),
			BackgroundTransparency = 1,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 3),
			}),
			ordered(face(faceSize, name), 1),
			CartoonLabel({
				LayoutOrder = 2,
				Name = "Number",
				Text = number,
				TextSize = numberSize,
				Color = Theme.Color.Ink,
				Stroke = 0,
				Truncate = true,
				Box = UDim2.fromOffset(numberW, faceSize),
				XAlignment = Enum.TextXAlignment.Left,
				YAlignment = Enum.TextYAlignment.Center,
			}),
		})
	end

	-- the diamond "!" of an urgent ticket, by the pin
	const warn = alert(urgent)
	warn.AnchorPoint = Vector2.new(0.5, 0.5)
	warn.Position = UDim2.new(0.5, 24, 0, 6)
	warn.ZIndex = 5

	-- card (left column): header, the stack, the line, the patience bar
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
		Padding = { Left = 6, Right = 6, Top = 10, Bottom = 2 },
		Children = {
			create("Frame")({
				Name = "Header",
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundTransparency = 1,
				who(28, 32, 15),
				queueChip(props.Queue),
			}),
			create("Frame")({
				Name = "Body",
				Position = UDim2.fromOffset(0, 32),
				Size = UDim2.new(1, 0, 1, -32 - 12),
				BackgroundTransparency = 1,
				create("UIListLayout")({
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),
				OrderStack({
					Name = "Stack",
					Toppings = toppingsOf,
					Direction = "Vertical",
					Band = if untrack(isRoomy) then 26 else 22,
				}),
				CartoonLabel({
					LayoutOrder = 2,
					Name = "Say",
					Text = say,
					TextSize = 15,
					Color = Theme.Color.Ink,
					Stroke = 0,
					Box = function(): UDim2
						return UDim2.new(1, 0, 0, if isRoomy() then 36 else 18)
					end,
					Wrapped = true,
					Truncate = true,
					XAlignment = Enum.TextXAlignment.Left,
					YAlignment = Enum.TextYAlignment.Top,
				}),
			}),
			patienceBar(patience, UDim2.new(0, 0, 1, -2), UDim2.fromScale(1, 0)),
		},
	})

	-- strip (portrait): row 1 face, number, the layers side by side, +N; row 2 the line; the patience bar under it
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
		Padding = { Left = 8, Right = 8, Top = 8, Bottom = 2 },
		Children = {
			create("Frame")({
				Name = "Row1",
				Size = UDim2.new(1, 0, 0, 38),
				BackgroundTransparency = 1,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 8),
				}),
				ordered(who(34, 40, 16), 1),
				OrderStack({
					Name = "Stack",
					LayoutOrder = 2,
					Toppings = toppingsOf,
					Direction = "Horizontal",
					Band = 36,
				}),
			}),
			create("Frame")({
				Name = "QueueRow",
				Size = UDim2.new(1, 0, 0, 38),
				BackgroundTransparency = 1,
				queueChip(props.Queue),
			}),
			CartoonLabel({
				Name = "Say",
				Position = UDim2.fromOffset(0, 40),
				Box = UDim2.new(1, 0, 0, 20),
				Text = say,
				TextSize = 15,
				Color = Theme.Color.Ink,
				Stroke = 0,
				Truncate = true,
				XAlignment = Enum.TextXAlignment.Left,
				YAlignment = Enum.TextYAlignment.Center,
			}),
			patienceBar(patience, UDim2.new(0, 0, 1, -2), UDim2.fromScale(1, 0)),
		},
	})

	-- Take (the customer at the counter): a bar over the bottom of the card
	local take: any = nil
	const takeProps = props.Take
	if takeProps ~= nil then
		take = CartoonButton({
			Name = "Take",
			Text = takeProps.Text,
			TextSize = 16,
			Visible = takeProps.Visible,
			AnchorPoint = Vector2.new(0.5, 0),
			-- under the card (bottom edge) with a ticket, right under the slim pill without one
			Position = function(): UDim2
				return if has() then UDim2.new(0.5, 0, 1, -48) else UDim2.new(0.5, 0, 0, 46)
			end,
			Size = UDim2.new(1, 0, 0, 48),
			OnActivated = takeProps.OnPress,
		})
		take.ZIndex = 6
	end

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
		warn,
		stamp,
		take,
	}) :: any
end
