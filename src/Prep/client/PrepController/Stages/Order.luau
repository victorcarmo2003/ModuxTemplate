--!strict
-- Stage Order (tab Order; TASK-177, docs/tech/prep-mode.md §2, docs/art/prep-ui-spec.md §5.1): the line of customers as cards
-- (oldest first), Take on the one at the counter, Pin on a taken one (the ticket rail shows the pinned one on every tab). Take
-- goes through PrepOrder, the same path as the world prompt (CustomerService:TakeOrderFor): only the customer on Q1 can be
-- taken, the server refuses the rest and the card shakes. The pin is a guide (PrepTab.Ticket), never a lock. Next goes to the
-- grill once a ticket is pinned. This stage also starts the Feed (the shared picture of the line and the grill) and is the one
-- that receives the broadcast events (PrepResult, Sale, Cycle) for it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Cards = require(script.Parent.Parent.Cards)
local Feed = require(script.Parent.Parent.Feed)
local Stage = require(script.Parent.Parent.Stage)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; ScrollingFrame is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

const prep = Content.Prep

const SCROLL_BAR = 6
const GAP = 8

const Order: Stage.Stage = {
	Tab = "Order",
	HasPanel = false,
	Board = function(controller: any): any
		const line = createRaw("ScrollingFrame")({
			Name = "Line",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollingDirection = Enum.ScrollingDirection.X,
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			CanvasSize = UDim2.new(),
			ScrollBarThickness = SCROLL_BAR,
			ElasticBehavior = Enum.ElasticBehavior.Never,
			Visible = function(): boolean
				return #Feed.Ids() > 0
			end,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, GAP),
			}),
			Vide.values(function(): { number }
				return Feed.Ids()
			end, function(id: number): Frame
				return Cards.Order(controller, id)
			end),
		})
		return create("Frame")({
			Name = "OrderBoard",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			line,
			Cards.Empty(function(): string
				return "No customers yet"
			end, function(): boolean
				return #Feed.Ids() == 0
			end),
		})
	end,
	Hint = function(_controller: any): string
		if #Feed.Ids() == 0 then
			return "No customers yet"
		elseif Feed.Pinned() ~= 0 then
			return "Ticket pinned. Next: the grill."
		end
		return prep.Tabs.ByKey.Order.Hint
	end,
	Next = function(_controller: any): Stage.Next
		const ready = Feed.Pinned() ~= 0
		return { Label = prep.Texts.Next, Enabled = ready, Pulse = ready }
	end,
	OnEnter = function(controller: any)
		-- the Order tab is the first one at Enter: this is where the Feed starts (and starts over on a new session)
		Feed.Start(controller)
	end,
	OnNext = function(controller: any)
		controller:SetStage("grill")
	end,
	OnEvent = function(controller: any, event: any)
		Feed.Event(controller, event)
	end,
}

return Order
