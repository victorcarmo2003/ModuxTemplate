--!strict
--[[
	Feed (TASK-177, TASK-179; docs/tech/prep-mode.md §2 Order / (a) Grill / (d) Serve): what the Order, Grill and Serve stages
	show and send. One shared, reactive picture of the line of customers and of the grill, built from what the server already
	replicates (CustomerController records, KitchenController Stations / Stock records), plus the five acts the stages send.
	The server decides everything: this module predicts nothing about money, stock or sales, it only presents and sends.

	  Customers   `Ids` (ordered, oldest first) and one source per customer (`CardOf`), written at 4 Hz and only on change
	  Grill       `Slots[1..8]` (state, progress, flip grade), `SlotCount`, `Rail`, `Stock`
	  Ticket      `Pinned` (a guide, the server only reads it on PrepTab) mirrored into controller.View.Ticket / Queue / Needs /
	              Badges so the ticket rail and the tab badges are right on every tab
	  Acts        Take, Pin, Place, Flip, Collect, Serve (+ Cycle). PrepOrder / PrepGrill, rates are the server's
	  Events      `Feed.Event(controller, event)`: PrepResult and Sale go in; the hook `OnServed` tells the Serve stage

	The flip of a sausage is stamped by the server clock (KitchenService); its grade comes back in PrepResult and is kept here
	by slot (the set `Stations` does not carry it). A seat that re-enters mid-plate does not know the flips: Collect still works.

	The mock (`/dev prep ui`) runs the very same pipeline over FeedMock instead of the controllers.
	Started by the Order stage at Enter (the loop ends when the mode ends). No Vide effect lives here: sources only.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local GradeMath = require(ReplicatedStorage.shared.Prep.Grade)
local Motion = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Motion)
local FeedMock = require(script.Parent.FeedMock)
local Flips = require(script.Parent.Flips)

const source = Vide.source
const untrack = Vide.untrack

const prep = Content.Prep

export type Grade = "Perfect" | "Good" | "Messy"

export type Card = {
	Id: number,
	Name: string,
	-- what the customer says (the toppings, spoken)
	Say: string,
	-- keys that leave the default, at most Content.OrderRules.MaxToppings
	Toppings: { string },
	-- 0..1 left of the running patience, 1 when no clock runs
	Patience: number,
	Urgent: boolean,
	-- Coming: on its way or in the line; Ready: at the counter, can be taken; Taken: ordered, waits for the food
	Status: "Coming" | "Ready" | "Taken",
	Place: "Counter" | "Table" | "Line",
}

export type SlotState = "Empty" | "Cooking" | "Window" | "Late" | "Flipped" | "Ready"

export type Slot = {
	Exists: boolean,
	State: SlotState,
	Progress: number,
	Flipped: Grade | false,
}

export type Stamp = { Result: string, Amount: number, Until: number }
export type Flash = { Grade: Grade, Until: number }
export type Shake = { Kind: string, Id: number, N: number }

type Pending = { Kind: string, Act: string, Slot: number, Npc: number, At: number }

type Session = {
	Gui: Instance?,
	Alive: boolean,
	World: FeedMock.World?,
	Flipped: { [number]: Grade },
	Spans: { [number]: { Phase: string, Span: number } },
	Cards: { [number]: Card },
	Sigs: { [number]: string },
	IdsSig: string,
	SlotSigs: { [number]: string },
	TicketSig: string,
	BadgeSig: string,
	PinSent: number,
	Grace: number,
	GraceUntil: number,
	Serving: { Npc: number, At: number }?,
	GrillStation: Instance?,
	RailStation: Instance?,
	LookAt: number,
}

const MAX_SLOTS = 8
const TICK = 0.066 -- s, about 15 Hz: the grill bars move smoothly, the cards are written only when they change
const FIND_EVERY = 1 -- s between two searches of the grill / rail station
const PENDING_TTL = 5 -- s a sent act waits for its PrepResult
const MAX_PENDING = 3 -- sent acts of one kind not answered yet (the server takes 4 to 6 per second)
const STAMP_TIME = 1.4 -- s the delivery seal stays on the card
const FLASH_TIME = 0.9 -- s the mini seal of a flip / collect stays on the slot
const SALE_WAIT = 1.5 -- s after an accepted Serve before the Sale packet is given up on
const GRACE = 1.5 -- s a freshly taken ticket keeps its pin while the record catches up
const URGENT = 0.15
const NAMES = { "Bella", "Max", "Pip", "Coco", "Otto", "Juno", "Milo", "Nina" } -- Provisional placeholders until the portraits (AST-117)
const NOT_READY_TEXT = "Not ready yet" -- Provisional, reasons without a Notice
const SERVE_RESULT_TEXT: { [string]: string } = {
	Perfect = "Perfect!",
	Complete = "Served!",
	Incomplete = "Not quite",
	Wrong = "Wrong order",
}

const Feed = {}

-- Reactive state ----------------------------------------------------------------------------------------------------------

Feed.Ids = source({} :: { number })
Feed.Pinned = source(0)
-- the card picked on the Serve tab (a second tap on Serve confirms)
Feed.Selected = source(0)
Feed.Stamps = source({} :: { [number]: Stamp })
Feed.SlotCount = source(0)
Feed.Rail = source(0)
-- sausages left in the stock, -1 = unknown
Feed.Stock = source(-1)
-- the grill was found in the trailer
Feed.HasGrill = source(false)
-- 0..1 breathing of the "flip now" ring (1 = steady with reduced motion)
Feed.Pulse = source(1)
Feed.Flash = source({} :: { [number]: Flash })
Feed.Shake = source({ Kind = "", Id = 0, N = 0 } :: Shake)
-- called by the Serve stage: a Sale came back for the card that was served
Feed.OnServed = nil :: ((controller: any, stamp: Stamp, npc: number) -> ())?

const EMPTY_SLOT: Slot = { Exists = false, State = "Empty", Progress = 0, Flipped = false }
Feed.Slots = {} :: { Vide.Source<Slot> }
for index = 1, MAX_SLOTS do
	Feed.Slots[index] = source(EMPTY_SLOT)
end

const EMPTY_CARD: Card = { Id = 0, Name = "", Say = "", Toppings = {}, Patience = 1, Urgent = false, Status = "Coming", Place = "Line" }
local cards: { [number]: Vide.Source<Card> } = {}

-- The source of one customer's card (created on first ask; stays small: a few customers a day).
function Feed.CardOf(id: number): Vide.Source<Card>
	local card = cards[id]
	if card == nil then
		card = source(EMPTY_CARD)
		cards[id] = card
	end
	return card
end

local session: Session? = nil
local pending: { Pending } = {}

-- A Serve is on its way (sent, verdict not back yet): the Serve button waits.
Feed.Sending = source(false)

local function setServing(current: Session, value: { Npc: number, At: number }?)
	current.Serving = value
	Feed.Sending(value ~= nil)
end

-- Reading ----------------------------------------------------------------------------------------------------------------

local function sayOf(keys: { string }, blank: boolean): string
	if blank then
		return "..."
	end
	if #keys == 0 then
		return "Plain, please."
	end
	const names: { string } = {}
	for _, key in keys do
		const row = Content.Ingredients.ByKey[key]
		table.insert(names, string.lower(if row ~= nil then row.Name else key))
	end
	if #names == 1 then
		return `With {names[1]}.`
	end
	return `With {table.concat(names, ", ", 1, #names - 1)} and {names[#names]}.`
end

local function findStation(controller: any, kind: string): Instance?
	const kitchen = controller.Dependencies.KitchenController
	for _, station in CollectionService:GetTagged("Station") do
		if station:GetAttribute("StationKind") == kind and station:IsDescendantOf(workspace) and kitchen:IsCurrent(station) then
			return station
		end
	end
	return nil
end

local function stationId(station: Instance?): number?
	if station == nil then
		return nil
	end
	const value = station:GetAttribute("StationId")
	return if type(value) == "number" then value else nil
end

-- The raw picture from the controllers: Customers records, the grill slots, the rail, the sausage stock.
local function readReal(controller: any, current: Session, now: number): FeedMock.Snapshot
	const customers = controller.Dependencies.CustomerController :: any
	const kitchen = controller.Dependencies.KitchenController :: any
	const out: { FeedMock.RawCustomer } = {}
	for id, entry in customers.Entries :: { [number]: any } do
		const record: any = (entry :: any).Record()
		if record == false or record.State == "Leaving" or record.Leader ~= nil then
			continue
		end
		const order: { string } = {}
		for _, key in Content.Ingredients.ToppingKeys do
			if record.Order[key] then
				table.insert(order, key)
				if #order >= Content.OrderRules.MaxToppings then
					break
				end
			end
		end
		table.insert(out, {
			Id = id,
			State = record.State,
			Slot = record.Slot,
			Order = order,
			PatienceEndsAt = record.PatienceEndsAt,
			PatienceSpan = record.PatienceSpan,
			Phase = record.Phase,
			Blank = customers:VariantOf(id) == "blank",
		})
	end

	-- the stations of the trailer (searched again when they are not there yet)
	if (current.GrillStation == nil or not current.GrillStation:IsDescendantOf(workspace)) and now - current.LookAt >= FIND_EVERY then
		current.LookAt = now
		current.GrillStation = findStation(controller, "grill")
		current.RailStation = findStation(controller, "rail")
	end
	const slots: { FeedMock.RawSlot } = {}
	const grillId = stationId(current.GrillStation)
	for index = 1, MAX_SLOTS do
		const record: any = if grillId ~= nil then kitchen:SlotOf(grillId * 100 + index) else nil
		if record ~= nil and record.Kind == "grill" then
			-- the flip stamp of THIS sausage only (a leftover of the previous one on the slot reads 0; see Flips)
			const flip = Flips.Stamp((grillId :: number) * 100 + index, record, now)
			table.insert(slots, { Exists = true, State = record.State, StartedAt = record.StartedAt, Duration = record.Duration, Flip = flip })
		else
			table.insert(slots, { Exists = false, State = "Empty", StartedAt = 0, Duration = 0 })
		end
	end
	const railId = stationId(current.RailStation)
	const rail: any = if railId ~= nil then kitchen:SlotOf(railId * 100) else nil
	const stock: any = kitchen:StockOf("sausage")
	return {
		Customers = out,
		Slots = slots,
		Rail = if rail ~= nil and rail.Kind == "rail" then rail.Count else 0,
		Stock = if stock ~= nil then stock.Amount else -1,
	}
end

-- Customers -------------------------------------------------------------------------------------------------------------

local function toCard(raw: FeedMock.RawCustomer, current: Session, now: number): Card
	local patience = 1
	local clock = false
	if raw.PatienceEndsAt > 0 and raw.Phase ~= "None" then
		const left = raw.PatienceEndsAt - now
		const known = current.Spans[raw.Id]
		local span = if known ~= nil then known.Span else 1
		if known == nil or known.Phase ~= raw.Phase then
			span = math.max(raw.PatienceSpan, left, 1)
			current.Spans[raw.Id] = { Phase = raw.Phase, Span = span }
		end
		patience = math.clamp(left / span, 0, 1)
		clock = true
	end
	local status: "Coming" | "Ready" | "Taken" = "Coming"
	local place: "Counter" | "Table" | "Line" = "Line"
	if raw.State == "Waiting" then
		status = "Taken"
		place = if raw.Slot > 0 then "Counter" else "Table"
	elseif raw.State == "Ordering" and raw.Slot == 1 then
		status = "Ready"
		place = "Counter"
	end
	return {
		Id = raw.Id,
		Name = NAMES[(raw.Id % #NAMES) + 1],
		Say = sayOf(raw.Order, raw.Blank),
		Toppings = if raw.Blank then {} else raw.Order,
		Patience = patience,
		Urgent = clock and patience <= URGENT,
		Status = status,
		Place = place,
	}
end

local function cardSignature(card: Card): string
	return `{card.Status}|{card.Place}|{math.floor(card.Patience * 50)}|{card.Urgent}|{table.concat(card.Toppings, ",")}|{card.Say}`
end

local function applyCustomers(current: Session, snapshot: FeedMock.Snapshot, now: number)
	const sorted = table.clone(snapshot.Customers)
	table.sort(sorted, function(a: FeedMock.RawCustomer, b: FeedMock.RawCustomer): boolean
		return a.Id < b.Id
	end)
	const ids: { number } = {}
	table.clear(current.Cards)
	for _, raw in sorted do
		const card = toCard(raw, current, now)
		table.insert(ids, raw.Id)
		current.Cards[raw.Id] = card
		const signature = cardSignature(card)
		if current.Sigs[raw.Id] ~= signature then
			current.Sigs[raw.Id] = signature
			Feed.CardOf(raw.Id)(card)
		end
	end
	for id in current.Sigs do
		if current.Cards[id] == nil then
			current.Sigs[id] = nil
			current.Spans[id] = nil
		end
	end
	const idsSig = table.concat(ids, ",")
	if idsSig ~= current.IdsSig then
		current.IdsSig = idsSig
		Feed.Ids(ids)
	end
end

-- Grill -----------------------------------------------------------------------------------------------------------------

local function applyGrill(current: Session, snapshot: FeedMock.Snapshot, now: number)
	const window = prep.Rules.Grill
	local count = 0
	for index = 1, MAX_SLOTS do
		const raw = snapshot.Slots[index]
		local slot: Slot = EMPTY_SLOT
		if raw ~= nil and raw.Exists then
			count = index
			if raw.State == "Empty" then
				current.Flipped[index] = nil
				slot = { Exists = true, State = "Empty", Progress = 0, Flipped = false }
			elseif raw.State == "Ready" then
				slot = { Exists = true, State = "Ready", Progress = 1, Flipped = current.Flipped[index] or false }
			else
				-- a grade kept from the sausage that was here before (it left while the feed did not look) is not this one's
				if current.Flipped[index] ~= nil and (raw.Flip or 0) <= 0 and now - raw.StartedAt < GradeMath.FirstSide(prep, raw.Duration) - 0.25 then
					current.Flipped[index] = nil
				end
				const flipped = current.Flipped[index]
				-- the first side runs, the sausage WAITS in the window for the flip, the second side runs (Grade.CookProgress)
				const progress = GradeMath.CookProgress(prep, raw.StartedAt, raw.Duration, now, flipped ~= nil or (raw.Flip or 0) > 0)
				local state: SlotState = "Cooking"
				if flipped ~= nil or (raw.Flip or 0) > 0 then
					state = "Flipped"
				elseif progress >= window.Target - 1e-4 then
					state = "Window"
				end
				slot = { Exists = true, State = state, Progress = progress, Flipped = flipped or false }
			end
		end
		const signature = `{slot.Exists}|{slot.State}|{math.floor(slot.Progress * 100)}|{slot.Flipped}`
		if current.SlotSigs[index] ~= signature then
			current.SlotSigs[index] = signature
			Feed.Slots[index](slot)
		end
	end
	if untrack(Feed.SlotCount) ~= count then
		Feed.SlotCount(count)
	end
	if untrack(Feed.Rail) ~= snapshot.Rail then
		Feed.Rail(snapshot.Rail)
	end
	if untrack(Feed.Stock) ~= snapshot.Stock then
		Feed.Stock(snapshot.Stock)
	end
	const found = current.World ~= nil or current.GrillStation ~= nil
	if untrack(Feed.HasGrill) ~= found then
		Feed.HasGrill(found)
	end
end

-- Publishing to the controller ------------------------------------------------------------------------------------------

local function ticketOf(card: Card, stamped: boolean): any
	return {
		Id = card.Id,
		Name = card.Name,
		Say = card.Say,
		Toppings = card.Toppings,
		Patience = card.Patience,
		State = if stamped then "Served" elseif card.Urgent then "Urgent" else "Active",
	}
end

local function publish(controller: any, current: Session, now: number)
	-- the pinned ticket: kept while it is a taken one (a freshly taken one for a moment), else the oldest taken one
	local pinned = untrack(Feed.Pinned)
	const pinCard = current.Cards[pinned]
	const keep = pinned ~= 0 and ((pinCard ~= nil and pinCard.Status == "Taken") or (pinned == current.Grace and now < current.GraceUntil))
	if not keep then
		pinned = 0
		for id, card in current.Cards do
			if card.Status == "Taken" and (pinned == 0 or id < pinned) then
				pinned = id
			end
		end
	end
	if untrack(Feed.Pinned) ~= pinned then
		Feed.Pinned(pinned)
	end

	-- selection of the Serve tab must still be a taken customer
	const selected = untrack(Feed.Selected)
	const selectedCard = current.Cards[selected]
	if selected ~= 0 and (selectedCard == nil or selectedCard.Status ~= "Taken") then
		Feed.Selected(0)
	end

	-- stamps and flashes age out
	const stamps = untrack(Feed.Stamps)
	for id, stamp in stamps do
		if now > stamp.Until then
			const copy = table.clone(stamps)
			copy[id] = nil
			Feed.Stamps(copy)
			break
		end
	end
	const flashes = untrack(Feed.Flash)
	for slot, flash in flashes do
		if now > flash.Until then
			const copy = table.clone(flashes)
			copy[slot] = nil
			Feed.Flash(copy)
			break
		end
	end

	-- the ticket rail
	const card = if pinned ~= 0 then current.Cards[pinned] else nil
	const view = controller.View
	local queue = 0
	for id, other in current.Cards do
		if other.Status == "Taken" and id ~= pinned then
			queue += 1
		end
	end
	const signature = if card ~= nil
		then `{cardSignature(card)}|{pinned}|{queue}|{stamps[pinned] ~= nil}`
		else `none|{queue}`
	if signature ~= current.TicketSig then
		current.TicketSig = signature
		view.Ticket(if card ~= nil then ticketOf(card, stamps[pinned] ~= nil) else false)
		view.Queue(queue)
	end
	controller:Need("TicketPicked", pinned ~= 0)
	if pinned ~= current.PinSent then
		current.PinSent = pinned
		controller:SendTab()
	end

	-- badges: Order = customers not taken yet, Grill = sausages ready, Serve = a plate waits (the seal is on)
	local waiting, ready = 0, 0
	for _, other in current.Cards do
		if other.Status ~= "Taken" then
			waiting += 1
		end
	end
	for index = 1, MAX_SLOTS do
		if untrack(Feed.Slots[index]).State == "Ready" then
			ready += 1
		end
	end
	const plates = if view.Seal() ~= false then 1 else 0
	const badgeSig = `{waiting}|{ready}|{plates}`
	if badgeSig ~= current.BadgeSig then
		current.BadgeSig = badgeSig
		controller.Badges({ Order = waiting, Grill = ready, Serve = plates })
	end

	Feed.Pulse(if Motion.Reduced() then 1 else 0.5 + 0.5 * math.sin(os.clock() * 5))
end

-- Loop -----------------------------------------------------------------------------------------------------------------------

local function step(controller: any, current: Session)
	const now = workspace:GetServerTimeNow()
	const snapshot = if current.World ~= nil then FeedMock.Snapshot(current.World, now) else readReal(controller, current, now)
	applyCustomers(current, snapshot, now)
	applyGrill(current, snapshot, now)
	publish(controller, current, now)
	-- an accepted Serve whose Sale never came: the card was served anyway
	const serving = current.Serving
	if serving ~= nil and os.clock() - serving.At > SALE_WAIT + 1 then
		setServing(current, nil)
	end
end

local function reset()
	untrack(function()
		Feed.Ids({})
		Feed.Pinned(0)
		Feed.Selected(0)
		Feed.Stamps({})
		Feed.SlotCount(0)
		Feed.Rail(0)
		Feed.Stock(-1)
		Feed.HasGrill(false)
		Feed.Flash({})
		for index = 1, MAX_SLOTS do
			Feed.Slots[index](EMPTY_SLOT)
		end
		for _, card in cards do
			card(EMPTY_CARD)
		end
		return nil
	end)
	table.clear(pending)
end

-- Starts the loop of the mode in front of `controller` (idempotent: the Order stage calls it at every Enter and tab change).
function Feed.Start(controller: any)
	const gui = controller.Gui
	if session ~= nil and session.Alive and session.Gui == gui then
		return
	end
	if session ~= nil then
		session.Alive = false
	end
	const mock = controller.Mock == true
	const current: Session = {
		Gui = gui,
		Alive = true,
		World = if mock then FeedMock.new(workspace:GetServerTimeNow()) else nil,
		Flipped = {},
		Spans = {},
		Cards = {},
		Sigs = {},
		IdsSig = "",
		SlotSigs = {},
		TicketSig = "",
		BadgeSig = "",
		PinSent = 0,
		Grace = 0,
		GraceUntil = 0,
		Serving = nil,
		GrillStation = nil,
		RailStation = nil,
		LookAt = -FIND_EVERY,
	}
	session = current
	reset()
	task.spawn(function()
		while current.Alive and controller.InMode and controller.Gui == gui do
			const ok, problem = pcall(step, controller, current)
			if not ok then
				warn(`[PrepController] Feed: {problem}`)
			end
			task.wait(TICK)
		end
		current.Alive = false
	end)
end

-- Sending ----------------------------------------------------------------------------------------------------------------

local function countPending(kind: string): number
	const now = os.clock()
	local count = 0
	for index = #pending, 1, -1 do
		if now - pending[index].At > PENDING_TTL then
			table.remove(pending, index)
		elseif pending[index].Kind == kind then
			count += 1
		end
	end
	return count
end

local function popPending(kind: string): Pending?
	countPending(kind) -- drops the expired ones
	for index, entry in pending do
		if entry.Kind == kind then
			table.remove(pending, index)
			return entry
		end
	end
	return nil
end

local function shake(kind: string, id: number)
	const last = untrack(Feed.Shake)
	Feed.Shake({ Kind = kind, Id = id, N = last.N + 1 })
end

-- One act: sent to the server (PrepGrill / PrepOrder) or answered by the mock. false = not sent (too many in flight).
local function send(controller: any, kind: string, act: string, slot: number, npc: number): boolean
	const current = session
	if current == nil or countPending(kind) >= MAX_PENDING then
		return false
	end
	table.insert(pending, { Kind = kind, Act = act, Slot = slot, Npc = npc, At = os.clock() })
	const world = current.World
	if world == nil then
		if kind == "Grill" then
			controller.Libs.Net.PrepGrill:fireServer({ Act = act, Slot = math.clamp(slot, 0, 8) })
		else
			controller.Libs.Net.PrepOrder:fireServer({ Act = act, Npc = math.clamp(npc, 1, 65535) })
		end
		return true
	end
	task.delay(0.12, function()
		if not current.Alive then
			return
		end
		const now = workspace:GetServerTimeNow()
		local result: FeedMock.Outcome
		local sale: { Npc: number, Result: string, Amount: number }? = nil
		if kind == "Grill" then
			result = FeedMock.Grill(world, act, slot, now)
		elseif act == "Serve" then
			const plate: { string } = {}
			for _, topping in controller.View.Toppings() :: { { Key: string } } do
				table.insert(plate, topping.Key)
			end
			const band: any = controller.View.Seal()
			result, sale = FeedMock.Serve(world, npc, plate, if band ~= false then band else "Good")
		else
			result = FeedMock.Order(world, act, npc, now)
		end
		Feed.Result(controller, { Act = kind, Ok = result.Ok, Reason = result.Reason, Grade = result.Grade, Value = result.Value })
		const verdict = sale
		if verdict ~= nil then
			task.delay(0.15, function()
				if current.Alive then
					Feed.Sale(controller, verdict)
				end
			end)
		end
	end)
	return true
end

function Feed.Take(controller: any, id: number)
	send(controller, "Order", "Take", 0, id)
end

-- The customer at the counter (Q1) that waits to be taken, 0 = none. Reactive when read inside a binding (the Take button of the
-- ticket rail, the Take target of the Window view; TASK-206).
function Feed.Front(): number
	for _, id in Feed.Ids() do
		const card = Feed.CardOf(id)()
		if card.Status == "Ready" and card.Place == "Counter" then
			return id
		end
	end
	return 0
end

-- `slot` = the roller the sausage was dropped on (prep-3d.md N1); 0 / nil = the server picks. false = not sent (too many in flight).
function Feed.Place(controller: any, slot: number?): boolean
	return send(controller, "Grill", "Place", slot or 0, 0)
end

function Feed.Flip(controller: any, slot: number): boolean
	return send(controller, "Grill", "Flip", slot, 0)
end

function Feed.Collect(controller: any, slot: number): boolean
	return send(controller, "Grill", "Collect", slot, 0)
end

-- A card to the Serve selection / the ticket rail (only a taken customer can be pinned).
function Feed.Pin(controller: any, id: number)
	const current = session
	const card = if current ~= nil then current.Cards[id] else nil
	if current == nil or card == nil or card.Status ~= "Taken" then
		return
	end
	Feed.Pinned(id)
	current.Grace = id
	current.GraceUntil = workspace:GetServerTimeNow() + GRACE
end

-- The next taken ticket after the pinned one (the ticket rail tap, D-pad).
function Feed.Cycle(controller: any)
	const current = session
	if current == nil then
		return
	end
	const taken: { number } = {}
	for id, card in current.Cards do
		if card.Status == "Taken" then
			table.insert(taken, id)
		end
	end
	if #taken == 0 then
		return
	end
	table.sort(taken)
	const at = table.find(taken, untrack(Feed.Pinned))
	Feed.Pin(controller, taken[if at == nil then 1 else (at % #taken) + 1])
end

-- Serves the plate to a customer (the Serve button after a card was picked). false = one is already on its way.
function Feed.Serve(controller: any, id: number): boolean
	const current = session
	if current == nil or current.Serving ~= nil then
		return false
	end
	setServing(current, { Npc = id, At = os.clock() })
	if not send(controller, "Order", "Serve", 0, id) then
		setServing(current, nil)
		return false
	end
	return true
end

-- Answers ----------------------------------------------------------------------------------------------------------------

local function gradeOf(value: any): Grade
	return if value == "Perfect" or value == "Messy" then value else "Good"
end

-- A PrepResult of a Grill / Order act (the Order stage hands every PrepResult over).
function Feed.Result(controller: any, result: any)
	const current = session
	if current == nil then
		return
	end
	const kind = if result.Act == "Grill" then "Grill" elseif result.Act == "Order" then "Order" else nil
	if kind == nil then
		return
	end
	const entry = popPending(kind)
	if entry == nil then
		return
	end
	const row = prep.Reasons.ByKey[result.Reason]
	const silent = row == nil or row.Notice == nil
	if not result.Ok then
		if entry.Act == "Serve" then
			setServing(current, nil)
		end
		if kind == "Grill" then
			shake("slot", if entry.Slot > 0 then entry.Slot else 0)
		else
			shake("card", entry.Npc)
		end
		if silent and result.Reason ~= "None" then
			controller:Toast(NOT_READY_TEXT, "Alert")
		end
		return
	end
	if kind == "Grill" then
		const slot = if result.Value > 0 then result.Value else entry.Slot
		if entry.Act == "Flip" then
			current.Flipped[slot] = gradeOf(result.Grade)
		elseif entry.Act == "Collect" then
			current.Flipped[slot] = nil
		end
		if entry.Act ~= "Place" and slot > 0 then
			const flashes = table.clone(untrack(Feed.Flash))
			flashes[slot] = { Grade = gradeOf(result.Grade), Until = workspace:GetServerTimeNow() + FLASH_TIME }
			Feed.Flash(flashes)
		end
		return
	end
	if entry.Act == "Take" then
		Feed.Pinned(entry.Npc)
		current.Grace = entry.Npc
		current.GraceUntil = workspace:GetServerTimeNow() + GRACE
		controller:Toast("Order taken", "Good")
	elseif entry.Act == "Serve" then
		-- accepted: the verdict (Complete / Incomplete / Wrong) arrives with the Sale packet; give up on it after SALE_WAIT
		const serving = current.Serving
		if serving ~= nil then
			const npc = serving.Npc
			task.delay(SALE_WAIT, function()
				if current.Serving ~= nil and current.Serving.Npc == npc then
					Feed.Sale(controller, { Npc = npc, Result = "Complete", Amount = 0 })
				end
			end)
		end
	end
end

-- The Sale packet of a serve of ours (the verdict of the server, DEC-072): the seal on the card, then the Serve stage moves on.
function Feed.Sale(controller: any, sale: { Npc: number, Result: string, Amount: number })
	const current = session
	if current == nil or current.Serving == nil then
		return
	end
	if sale.Result ~= "Perfect" and sale.Result ~= "Complete" and sale.Result ~= "Incomplete" and sale.Result ~= "Wrong" then
		return
	end
	const serving = current.Serving
	setServing(current, nil)
	-- a partner's Sale carries the leader's id: the card the player picked gets the seal
	const npc = serving.Npc
	const stamp: Stamp = { Result = sale.Result, Amount = sale.Amount, Until = workspace:GetServerTimeNow() + STAMP_TIME }
	const stamps = table.clone(untrack(Feed.Stamps))
	stamps[npc] = stamp
	Feed.Stamps(stamps)
	const hook = Feed.OnServed
	if hook ~= nil then
		hook(controller, stamp, npc)
	end
end

function Feed.ServeText(result: string, amount: number): string
	const text = SERVE_RESULT_TEXT[result] or "Served!"
	if result == "Perfect" and amount > 0 then
		return `{text} +${amount}`
	end
	return text
end

-- The events the controller broadcasts (the Order stage forwards them here; nobody else does).
function Feed.Event(controller: any, event: any)
	if event.Kind == "Result" then
		Feed.Result(controller, event.Result)
	elseif event.Kind == "Sale" then
		Feed.Sale(controller, event)
	elseif event.Kind == "Cycle" then
		Feed.Cycle(controller)
	end
end

-- Dev preview: `/dev prep ui <station> <tab>`. The Serve tab gets a finished plate so the cards have something to match.
function Feed.Preview(controller: any, tab: string)
	local target: string? = nil
	for _, row in prep.Tabs.List do
		if string.lower(row.Key) == string.lower(tab) then
			target = row.Key
		end
	end
	if target == nil then
		return
	end
	if target == "Serve" then
		const view = controller.View
		Vide.batch(function()
			view.Bun("Closed")
			view.Sausage({ X = 0.5, Y = 0.5, State = "Ready" })
			view.Toppings({ { Key = "ketchup", Amount = 1 }, { Key = "mustard", Amount = 1 }, { Key = "cheese", Amount = 1 } })
			view.Seal("Perfect")
		end)
		controller:Need("PlateBuilt", true)
		controller:SetStage("serve")
		return
	end
	controller:SetTab(target)
end

return Feed
