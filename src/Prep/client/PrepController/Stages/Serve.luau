--!strict
-- Stage Serve (tab Serve; TASK-179, docs/tech/prep-mode.md §2 (d) and DT-6, docs/art/prep-ui-spec.md §5.4, §7): the finished
-- plate with its grade seal (Perfect / Good / Messy, shape + colour + word) on the left, the customers who ordered (counter and
-- tables) as cards on the right. The card that matches the plate lifts and gets a check; matching only highlights, serving the
-- wrong one is allowed (DEC-072). A tap picks a card, the Serve button confirms (two taps, never one by accident) and sends
-- PrepOrder Serve: the SERVER judges (CustomerService:ServeFor picks the exact hot dog of the hotbar) and the verdict
-- (Complete / Incomplete / Wrong, +$ on a tip) comes back with the Sale packet as a seal on the card. A served plate (not a
-- Wrong one, which stays in hand) clears the board and goes back to the Order tab.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Cards = require(script.Parent.Parent.Cards)
local Feed = require(script.Parent.Parent.Feed)
local Parts = require(script.Parent.Parent.Parts)
local Stage = require(script.Parent.Parent.Stage)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; ScrollingFrame is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

const prep = Content.Prep

const PLATE_SHARE = 0.4 -- of the board width
const GAP = 8
const SCROLL_BAR = 6
const HOLD = 1.2 -- s the seal stays before the board clears (the Feed keeps the card for 1.4 s)

-- The toppings of the plate in hand as a list of keys (reactive).
local function plateKeys(controller: any): { string }
	const keys: { string } = {}
	for _, topping in controller.View.Toppings() do
		table.insert(keys, topping.Key)
	end
	return keys
end

local function sealed(controller: any): boolean
	return controller.View.Seal() ~= false and controller.View.Bun() ~= "None"
end

-- The same toppings (order free): the card is what the plate was made for. Only a highlight, the server judges.
local function matches(controller: any, keys: { string }): boolean
	if not sealed(controller) then
		return false
	end
	const plate = plateKeys(controller)
	if #plate ~= #keys then
		return false
	end
	for _, key in keys do
		if table.find(plate, key) == nil then
			return false
		end
	end
	return true
end

-- The customers to show: the ones waiting for food, and (for a moment) the one just served, oldest first.
local function listed(): { number }
	const out: { number } = {}
	const stamps = Feed.Stamps()
	for _, id in Feed.Ids() do
		if Feed.CardOf(id)().Status == "Taken" or stamps[id] ~= nil then
			table.insert(out, id)
		end
	end
	for id in stamps do
		if table.find(out, id) == nil then
			table.insert(out, id)
		end
	end
	table.sort(out)
	return out
end

-- Picks the card the ticket points at when it matches (else the first match), so a clean plate is one tap from Serve.
local function preselect(controller: any)
	local first = 0
	local ready = false
	local picked = 0
	local pinned = 0
	Vide.untrack(function()
		picked = Feed.Selected()
		pinned = Feed.Pinned()
		ready = sealed(controller)
		return nil
	end)
	if picked ~= 0 or not ready then
		return
	end
	Vide.untrack(function()
		for _, id in listed() do
			const card = Feed.CardOf(id)()
			if card.Status == "Taken" and matches(controller, card.Toppings) then
				if id == pinned then
					first = id
					break
				elseif first == 0 then
					first = id
				end
			end
		end
		return nil
	end)
	if first ~= 0 then
		Feed.Selected(first)
	end
end

-- The verdict came back: a line of text and, unless the hot dog stayed in hand (Wrong), the board starts over.
Feed.OnServed = function(controller: any, stamp: Feed.Stamp, _npc: number)
	controller:Toast(Feed.ServeText(stamp.Result, stamp.Amount), if stamp.Result == "Wrong" then "Alert" else "Good")
	Feed.Selected(0)
	if stamp.Result == "Wrong" then
		return
	end
	task.delay(HOLD, function()
		-- only a plate that is still the finished one is cleared (a new plate in the making has no seal yet)
		local plateSealed = false
		Vide.untrack(function()
			plateSealed = controller.View.Seal() ~= false
			return nil
		end)
		if controller.InMode and not controller.Leaving and plateSealed then
			controller:ResetPlate()
			controller:SetStage("grill")
			controller:SetTab("Order")
		end
	end)
end

const Serve: Stage.Stage = {
	Tab = "Serve",
	HasPanel = false,
	Board = function(controller: any): any
		const line = createRaw("ScrollingFrame")({
			Name = "Customers",
			Position = UDim2.new(PLATE_SHARE, GAP, 0, 0),
			Size = UDim2.new(1 - PLATE_SHARE, -GAP, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollingDirection = Enum.ScrollingDirection.X,
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			CanvasSize = UDim2.new(),
			ScrollBarThickness = SCROLL_BAR,
			ElasticBehavior = Enum.ElasticBehavior.Never,
			Visible = function(): boolean
				return #listed() > 0
			end,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, GAP),
			}),
			Vide.values(listed, function(id: number): Frame
				return Cards.Serve(controller, id, function(keys: { string }): boolean
					return matches(controller, keys)
				end)
			end),
		})
		const empty = Cards.Empty(function(): string
			return "Nobody is waiting"
		end, function(): boolean
			return #listed() == 0
		end)
		empty.Position = UDim2.new(PLATE_SHARE, GAP, 0, 0)
		empty.Size = UDim2.new(1 - PLATE_SHARE, -GAP, 1, 0)
		return create("Frame")({
			Name = "ServeBoard",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			create("Frame")({
				Name = "Plate",
				Size = UDim2.fromScale(PLATE_SHARE, 1),
				BackgroundTransparency = 1,
				Parts.Plate(controller, nil, nil),
			}),
			line,
			empty,
		})
	end,
	Hint = function(controller: any): string
		if not sealed(controller) then
			return "Nothing to serve"
		elseif Feed.Sending() then
			return "Serving..."
		elseif Feed.Selected() == 0 then
			return prep.Steps.ByKey.serve.Hint
		end
		return "Press Serve to hand it over"
	end,
	Next = function(controller: any): Stage.Next
		const ready = sealed(controller) and Feed.Selected() ~= 0 and not Feed.Sending()
		return { Label = prep.Texts.Serve, Enabled = ready, Pulse = ready }
	end,
	OnEnter = function(controller: any)
		Feed.Start(controller)
		if controller.View.Bun() == "None" then
			controller.View.Message("Nothing to serve")
		end
		preselect(controller)
	end,
	OnNext = function(controller: any)
		local target = 0
		Vide.untrack(function()
			target = Feed.Selected()
			return nil
		end)
		if target ~= 0 and not Feed.Serve(controller, target) then
			controller:Toast("One at a time", "Info")
		end
	end,
}

return Serve
