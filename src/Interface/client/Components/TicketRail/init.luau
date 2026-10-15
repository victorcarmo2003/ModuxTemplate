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
local RunService = game:GetService("RunService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)
local OrderStack = require(script.Parent.OrderStack)
local Sprites = require(script.Parent.OrderStack.Sprites)

const create = Vide.create
const source = Vide.source
const effect = Vide.effect
const cleanup = Vide.cleanup
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

export type Props = {
	Ticket: () -> Ticket?,
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
-- Patience colour: Teal from half up, Mustard from a quarter down, a blend between (never red)
const CALM = 0.5
const ALERT = 0.25
-- Tilt of the paper (degrees): a ticket pinned by hand is never quite straight
const TILT_CARD = -1.2
const TILT_STRIP = 0.6

local function initial(name: string): string
	return if name == "" then "?" else string.upper(string.sub(name, 1, 1))
end

local function patienceColor(value: number): Color3
	const t = math.clamp((value - ALERT) / (CALM - ALERT), 0, 1)
	return Theme.Tone.Mustard.Bottom:Lerp(Theme.Tone.Teal.Bottom, t)
end

-- The patience bar: a thin rounded level with a knob on its tip, Teal turning Mustard as it runs out; it pulses when it is almost
-- gone. Nothing at all when there is no patience to show (Patience 0).
local function patienceBar(patience: () -> number, pulse: () -> number, height: number): Frame
	return create("Frame")({
		Name = "Patience",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -3),
		Size = UDim2.new(1, -16, 0, height + 6),
		BackgroundTransparency = 1,
		Visible = function(): boolean
			return patience() > 0
		end,
		create("Frame")({
			Name = "Track",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.new(1, 0, 0, height),
			BackgroundColor3 = Theme.Tone.Cream.Bottom,
			ClipsDescendants = true,
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
					return patienceColor(patience()):Lerp(Color3.new(1, 1, 1), pulse() * 0.4)
				end,
				BorderSizePixel = 0,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			}),
		}),
		-- the knob on the tip of the level (a drop of the same colour in a Cream ring)
		create("Frame")({
			Name = "Knob",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = function(): UDim2
				return UDim2.new(math.clamp(patience(), 0.04, 0.98), 0, 0.5, 0)
			end,
			Size = function(): UDim2
				const side = (height + 5) * (1 + 0.3 * pulse())
				return UDim2.fromOffset(side, side)
			end,
			BackgroundColor3 = function(): Color3
				return patienceColor(patience())
			end,
			ZIndex = 3,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		}),
	})
end

-- The portrait of the customer: a Cream frame with an Ink edge around a Teal disc with the first letter (a round placeholder until
-- the animal portraits exist, AST-117).
local function portrait(side: number, name: () -> string): Frame
	return create("Frame")({
		Name = "Portrait",
		Size = UDim2.fromOffset(side, side),
		BackgroundColor3 = Theme.Tone.White.Top,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		createRaw("UIStroke")({
			Color = Theme.Color.Ink,
			Thickness = 3,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		create("Frame")({
			Name = "Disc",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -7, 1, -7),
			BackgroundColor3 = Theme.Tone.Teal.Bottom,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			CartoonLabel({
				Text = function()
					return initial(name())
				end,
				TextSize = if side >= 34 then 18 else 16,
				Color = Theme.Color.Cream,
				Stroke = 2,
				Box = UDim2.fromScale(1, 1),
				XAlignment = Enum.TextXAlignment.Center,
				YAlignment = Enum.TextYAlignment.Center,
			}),
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

local function queueChip(queue: () -> number, position: UDim2): Frame
	return CartoonPanel({
		Name = "Queue",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = position,
		Tone = Theme.Tone.White,
		Radius = Theme.Radius.Small,
		Lip = 2,
		Outline = 2,
		Gloss = false,
		Size = UDim2.fromOffset(32, 22),
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

-- What the customer said: a small label with quotes, on its own bubble.
local function bubble(text: () -> string, wrapped: boolean, position: UDim2, size: any, anchor: Vector2): Frame
	return CartoonPanel({
		Name = "Say",
		AnchorPoint = anchor,
		Position = position,
		Size = size,
		Tone = Theme.Tone.White,
		Radius = UDim.new(0, 9),
		Lip = 0,
		Outline = 2,
		Gloss = false,
		Rim = false,
		Padding = { Left = 6, Right = 6 },
		Children = {
			CartoonLabel({
				Name = "Text",
				Text = text,
				TextSize = Theme.MinTextSize,
				Color = Theme.Color.Ink,
				Stroke = 0,
				Wrapped = wrapped,
				Truncate = true,
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
	const roomy = props.Roomy
	const isRoomy = function(): boolean
		return roomy ~= nil and roomy()
	end
	const toppingsOf = function(): { string }
		const ticket = props.Ticket()
		return if ticket ~= nil then ticket.Toppings else {}
	end

	-- the little motions of the paper: it slides in with a spring when a ticket comes, the pin swings, the bar pulses when the
	-- customer is about to leave. One Heartbeat that does nothing while everything is at rest (and nothing at all with reduced motion).
	const reduced = Motion.Reduced()
	const slide = source(0)
	const sway = source(0)
	const pulse = source(0)
	local lastId = 0
	local slideX, slideV, swayA, swayV = 0, 0, 0, 0
	effect(function()
		const ticket = props.Ticket()
		const id = if ticket ~= nil then ticket.Id else 0
		untrack(function()
			if id ~= lastId then
				lastId = id
				if id ~= 0 and not reduced then
					slideX, slideV, swayV = 1, 0, 300
				end
			end
			return nil
		end)
	end)
	const beat = RunService.Heartbeat:Connect(function(dt: number)
		const step = math.min(dt, 0.05)
		if slideX ~= 0 or slideV ~= 0 then
			slideV += (-slideX * 230 - slideV * 17) * step
			slideX += slideV * step
			if math.abs(slideX) < 0.002 and math.abs(slideV) < 0.02 then
				slideX, slideV = 0, 0
			end
			slide(slideX)
		end
		if swayA ~= 0 or swayV ~= 0 then
			swayV += (-swayA * 150 - swayV * 3.4) * step
			swayA += swayV * step
			if math.abs(swayA) < 0.05 and math.abs(swayV) < 0.5 then
				swayA, swayV = 0, 0
			end
			sway(swayA)
		end
		const ticket = props.Ticket()
		const alarm = ticket ~= nil and ticket.Patience > 0 and ticket.Patience <= ALERT and not reduced
		if alarm then
			pulse(0.5 + 0.5 * math.sin(os.clock() * 7))
		elseif untrack(pulse) ~= 0 then
			pulse(0)
		end
	end)
	cleanup(function()
		beat:Disconnect()
	end)
	-- the paper comes from the left (px), the pin swings (degrees)
	const slidePosition = function(): UDim2
		return UDim2.fromOffset(-60 * slide(), 0)
	end

	-- empty state, shared by both shapes
	const empty = CartoonPanel({
		Name = "Empty",
		Tone = Theme.Tone.Cream,
		Radius = Theme.Radius.Card,
		-- nothing to read: a slim pill, not a blank card
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
		ZIndex = 12,
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

	-- the pin: a big Teal head on the top edge of the paper, it swings when the ticket comes
	local function pin(): Frame
		return create("Frame")({
			Name = "Pin",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 3),
			Size = UDim2.fromOffset(30, 30),
			BackgroundTransparency = 1,
			ZIndex = 10,
			Rotation = function(): number
				return sway()
			end,
			-- the flat disc is what shows until the sprite is through moderation
			create("Frame")({
				Name = "Disc",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(20, 20),
				BackgroundColor3 = Theme.Tone.Teal.Bottom,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			}),
			create("ImageLabel")({
				Name = "Sprite",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = Sprites.Pin,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 11,
			}),
		})
	end

	-- the diamond "!" of an urgent ticket, by the pin
	const warn = alert(urgent)
	warn.AnchorPoint = Vector2.new(0.5, 0.5)
	warn.Position = UDim2.new(0.5, 26, 0, 8)
	warn.ZIndex = 10

	-- soft shadow under a paper (a flat Ink shape, offset, see-through)
	local function shadow(visible: () -> boolean, tilt: number): Frame
		return create("Frame")({
			Name = "Shadow",
			Position = function(): UDim2
				const slideOffset = slidePosition()
				return UDim2.new(0, slideOffset.X.Offset + 2, 0, 5)
			end,
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Color.Ink,
			BackgroundTransparency = 0.72,
			Rotation = tilt,
			Visible = visible,
			create("UICorner")({ CornerRadius = Theme.Radius.Card }),
		})
	end
	const cardVisible = function(): boolean
		return has() and not strip()
	end
	const stripVisible = function(): boolean
		return has() and strip()
	end

	-- card (left column): pin, the customer, the layers, what was said, the patience
	const cardPitch = if untrack(isRoomy) then 24 else 18
	const cardSprite = if untrack(isRoomy) then 34 else 26
	const cardMedal = if untrack(isRoomy) then 28 else 22
	const card = CartoonPanel({
		Name = "Card",
		Tone = Theme.Tone.Cream,
		Radius = Theme.Radius.Card,
		Lip = 3,
		Outline = outline,
		OutlineColor = outlineColor,
		Size = UDim2.fromScale(1, 1),
		Position = slidePosition,
		Rotation = TILT_CARD,
		Visible = cardVisible,
		Children = {
			create("Frame")({
				Name = "Portrait",
				Position = UDim2.fromOffset(8, 13),
				Size = UDim2.fromOffset(32, 32),
				BackgroundTransparency = 1,
				portrait(32, name),
			}),
			CartoonLabel({
				Name = "Name",
				Text = name,
				TextSize = 17,
				Color = Theme.Color.Ink,
				Stroke = 0,
				Truncate = true,
				Position = UDim2.fromOffset(46, 12),
				Box = UDim2.new(1, -46 - 40, 0, 20),
				XAlignment = Enum.TextXAlignment.Left,
				YAlignment = Enum.TextYAlignment.Center,
			}),
			CartoonLabel({
				Name = "Number",
				Text = number,
				TextSize = Theme.MinTextSize,
				Color = Theme.Tone.Ink.Top,
				Stroke = 0,
				Truncate = true,
				Position = UDim2.fromOffset(46, 30),
				Box = UDim2.new(1, -46 - 40, 0, 16),
				XAlignment = Enum.TextXAlignment.Left,
				YAlignment = Enum.TextYAlignment.Center,
			}),
			queueChip(props.Queue, UDim2.new(1, -6, 0, 29)),
			create("Frame")({
				Name = "StackHolder",
				Position = UDim2.fromOffset(6, 50),
				Size = UDim2.new(1, -12, 0, 140),
				BackgroundTransparency = 1,
				OrderStack({
					Name = "Stack",
					Toppings = toppingsOf,
					Direction = "Vertical",
					Pitch = cardPitch,
					Sprite = cardSprite,
					Medallion = cardMedal,
				}),
			}),
			bubble(
				say,
				true,
				UDim2.new(0, 6, 1, if untrack(isRoomy) then -18 else -17),
				function(): UDim2
					return UDim2.new(1, -12, 0, if isRoomy() then 38 else 22)
				end,
				Vector2.new(0, 1)
			),
			patienceBar(patience, pulse, 8),
			pin(),
		},
	})

	-- strip (portrait): the customer, the layers side by side, what was said and the patience under them
	const band = CartoonPanel({
		Name = "Strip",
		Tone = Theme.Tone.Cream,
		Radius = Theme.Radius.Card,
		Lip = 3,
		Outline = outline,
		OutlineColor = outlineColor,
		Size = UDim2.fromScale(1, 1),
		Position = slidePosition,
		Rotation = TILT_STRIP,
		Visible = stripVisible,
		Children = {
			create("Frame")({
				Name = "Portrait",
				Position = UDim2.fromOffset(10, 14),
				Size = UDim2.fromOffset(34, 34),
				BackgroundTransparency = 1,
				portrait(34, name),
			}),
			CartoonLabel({
				Name = "Name",
				Text = name,
				TextSize = 17,
				Color = Theme.Color.Ink,
				Stroke = 0,
				Truncate = true,
				Position = UDim2.fromOffset(50, 12),
				Box = UDim2.fromOffset(86, 20),
				XAlignment = Enum.TextXAlignment.Left,
				YAlignment = Enum.TextYAlignment.Center,
			}),
			CartoonLabel({
				Name = "Number",
				Text = number,
				TextSize = Theme.MinTextSize,
				Color = Theme.Tone.Ink.Top,
				Stroke = 0,
				Truncate = true,
				Position = UDim2.fromOffset(50, 31),
				Box = UDim2.fromOffset(40, 16),
				XAlignment = Enum.TextXAlignment.Left,
				YAlignment = Enum.TextYAlignment.Center,
			}),
			queueChip(props.Queue, UDim2.fromOffset(138, 40)),
			create("Frame")({
				Name = "StackHolder",
				Position = UDim2.fromOffset(146, 8),
				Size = UDim2.new(1, -152, 0, 44),
				BackgroundTransparency = 1,
				OrderStack({
					Name = "Stack",
					Toppings = toppingsOf,
					Direction = "Horizontal",
					Pitch = 34,
					Sprite = 30,
				}),
			}),
			bubble(say, false, UDim2.new(0, 8, 1, -16), UDim2.new(1, -16, 0, 22), Vector2.new(0, 1)),
			patienceBar(patience, pulse, 6),
			pin(),
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
		shadow(cardVisible, TILT_CARD),
		shadow(stripVisible, TILT_STRIP),
		card,
		band,
		warn,
		stamp,
	}) :: any
end
