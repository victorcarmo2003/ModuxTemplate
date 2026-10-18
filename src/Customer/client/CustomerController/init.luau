--!strict
--[[
	CustomerController (TASK-034; FEAT-010, FEAT-011; DEC-071, DEC-152, DEC-162, DEC-187; network.md §3.6, §4.3, §5.3)

	Presents the customers from the server; decides nothing (CustomerService validates, pays and moves the mood).

	  - Customers set (record id = NpcId) -> one Vide source per customer.
	  - The rig is found by the `NpcId` attribute of the `AnimalRig`-tagged models (a pooled rig gets a new id on
	    every spawn, so the attribute is watched, not read once).
	  - Order bubble (Interface/Components/OrderBubble) over the head, seen by the whole party (DEC-071), only while
	    the customer is `Waiting` (that is, after "Take Order": Order is empty before it, FEAT-011). Base icon + the
	    ordered toppings (ToppingKeys order, max 3). At most MAX_BUBBLES on screen.
	  - Patience ring only with PatienceEndsAt > 0 (T41: 0 until "Take Order", K stays hidden). The span of the
	    ring is max(PatienceBase + PatiencePerK x K, time left when first seen): the Counter bonus is not on the wire
	    for this controller, so the ring starts full at "Take Order" and drains to 0 at PatienceEndsAt. Provisional.
	  - Face: Moods[Mood].Expression through RigController:SetExpression (local only; the mood also holds in the
	    low band, Provisional 2026-10-14). The face follows the server's Mood in every state; the client never derives a
	    mood from the patience (Annoyed is written by the server, network.md §3.6). Cleared when the record goes.
	  - Sale packet -> ReactionBubble over the rig for REACTION_TIME s (Reactions.luau); the order bubble of that
	    customer hides meanwhile. The "+$N" on the drawer is EconomyController's.
	  - Sound and one-shot animation (TASK-079; sound-list §5.4; architecture.md §19.20): "Take Order" (record goes
	    to Waiting) plays SFX-041 `order_take` on the rig; a Sale plays SFX-042 `serve` (when something was handed
	    over) and the reaction sound + clip of Reactions.Feedback through AudioController / AnimController. The coin
	    (SFX-043/044) is EconomyController's, on the drawer. Keys still missing from Content.Sounds are skipped
	    quietly (the row comes with the Content owner); clips with an empty id do not play (AnimController).

	Wave 3 (TASK-110; anomalies.md N1/N4/N5, architecture.md §19.3): the rig attribute `Variant` (NpcService,
	TASK-108: blank / mirror / raincoat; nil = ordinary customer) is read per customer into a Vide source
	(`self:VariantOf(id)`, reactive), re-read when the attribute changes (a pooled rig loses it). Applied locally:
	  - the face is RigController's (it reads the same attribute; the variant face beats the mood);
	  - blank: the order bubble shows no topping icon (the order is still on the wire, the server judges it). The
	    bubble's base icon stays until OrderBubble has an "empty" prop (Interface owner; ANM-001 `Coin_Blank` and the
	    missing breath are the TASK-112 effect's).
	Nothing here decides an anomaly: the verb, the payment and the result stay on the server.

	Order reading (user request after Play: the awning hid the bubble):
	  - the OrderBubble is AlwaysOnTop, lifted BUBBLE_LIFT px over the prompt pill on the customer's neck;
	  - HUD order card (Interface/Components/HudOrder, mounted by HudController): `Focus` = the customer the prompt
	    targets (PromptController.Target on a customer rig) when it is Waiting, else the Q1 customer (Slot 1) in
	    Waiting (the nearest one if more than one); 0 = no card. Read at TICK_RATE. The card reads CardShown /
	    CardToppings / CardEmpty / CardPatience (reactive). A blank customer = the card with no icon.

	Pairs (TASK-148; FEAT-038; network.md §14.2): the leader's record carries `Order2` (2nd hot dog still pending): the
	bubble and the HUD card draw 2 rows (OrderBubble/HudOrder `Toppings2`). The record always shows the pending items,
	so when one is resolved `Order2` goes nil: the resolved row is kept for DONE_TIME s with a veil + check (`Done`),
	then the bubble is back to 1 row. Which row went: `Order` unchanged = the 2nd, else the 1st. The partner (record
	with `Leader`) never mounts a bubble nor gets the card. The ring span counts K1 + K2 + Flow.Groups.PatienceBonus.

	Listeners in OnInit (before Lync.start, README "Rede"); the late joiner gets the current records through onAdded.
	Rigs are scanned in OnStart. No input: nothing here is clickable (FEAT-032).

	Restaurant note priority (TASK-384; FEAT-043; tech/restaurant-flow.md §1, §3.2), only with
	Content.Restaurant.Rules.Enabled (off = the trailer rule above, unchanged):
	  1. my talk at a tablet (TabletController:MyTalk()): the card grows item by item on the server clock. The card
	     methods return only what was said (bun -> the icon, then each topping; the 2nd row from its bun) and
	     CardReveal() gives the count for HudOrder `Reveal`. Sounds are TabletController's (ticket_pop, dialog_blip);
	  2. the `Ticket` (NpcId) of the hot_dog Tool in my hand, when that customer is Waiting;
	  3. the prompt target (Waiting);
	  4. the oldest head: the Waiting customer at the front of the pickup line (lowest `Pickup`), else Q1 as before.
	A blank customer (ANM-001) keeps the empty card in every case.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local OrderBubble = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.OrderBubble)
local PatienceBar = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.PatienceBar)
local ReactionBubble = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.ReactionBubble)
local Reactions = require(script.Reactions)
local NightWatch = require(script.NightWatch)

const MAX_BUBBLES = 8 -- TASK-034 acceptance; <= 8 customers by day (network.md §3.6)
const REACTION_TIME = 3 -- s
const TICK_RATE = 10 -- Hz, patience ring clock (only while a bubble is mounted)
const HEAD_GAP = 0.6 -- studs between the top of the head and the tip of the bubble
const MAX_DISTANCE = 60
const ORDER_RULES = Content.OrderRules
const WARN_AT = Content.Moods.Rules.AnnoyedAt
const VARIANT_ATTRIBUTE = "Variant" -- rig attribute (NpcService, TASK-108)
const BLANK = "blank" -- ANM-001: no icons in the bubble
-- px under the bubble's tail: clears the prompt pill (48 px tall, centred on the neck anchor) at any distance
const BUBBLE_LIFT = 28
const FRONT_SLOT = 1 -- Q1
const DONE_TIME = 1.2 -- s a resolved row of a pair stays on the bubble (veil + check)
-- px a bubble takes over BUBBLE_LIFT (tail included), so the patience bar floats above it (OrderBubble: 1 row 68, 2 rows 110)
const BUBBLE_ONE_ROW = 68
const BUBBLE_TWO_ROWS = 110
const BAR_GAP = 4
const RESTAURANT = Content.Restaurant
const TICKET = "Ticket" -- hot_dog Tool attribute (PlateService, TASK-379): NpcId of the plate's order
const TALK_BASE = "bun" -- 1st item of each hot dog in the talk order (TabletController)

export type Record = {
	State: string,
	Slot: number,
	Order: { [string]: boolean },
	PatienceEndsAt: number, -- deadline of the running patience phase; 0 = none (Q-192)
	Phase: string, -- "None" | "Queue" (Q1 until "Take Order") | "Order" ("Take Order" until served)
	PatienceSpan: number, -- whole seconds of the running phase
	Mood: string,
	Order2: { [string]: boolean }?, -- pair leader: 2nd pending hot dog (network.md §14.2)
	Leader: number?, -- pair partner: NpcId of its leader (no bubble)
	Pickup: number?, -- restaurant: place in the pickup line PU-1..n (nil = not in it)
}

-- What the card reads during my talk at a tablet (TabletController:MyTalk(), TASK-383)
type Talk = { Npc: number, Items: { string }, Reveal: number }

-- Resolved row of a pair while it is shown (DONE_TIME): row 1 or 2 and its toppings.
type Done = { Row: number, Toppings: { OrderBubble.Topping } }

type Entry = {
	Id: number,
	Record: Vide.Source<Record | false>,
	Reacting: Vide.Source<boolean>,
	EndsAt: number, -- last PatienceEndsAt seen (> 0)
	Total: number, -- span of the patience ring (s); 0 = unknown
	Model: Model?, -- rig the bubble and the face are on
	Unmount: (() -> ())?,
	Gui: Instance?,
	BarUnmount: (() -> ())?, -- patience bar over the bubble (Q-192)
	BarGui: Instance?,
	Face: string?,
	Variant: Vide.Source<string | false>, -- rig attribute Variant (TASK-110); false = ordinary customer
	Done: Vide.Source<Done | false>, -- pair row just resolved (TASK-148)
	DoneTimer: thread?,
}

type Reaction = {
	Id: number,
	Unmount: () -> (),
	Gui: Instance,
	Timer: thread,
}

type Tracked = {
	Id: number?,
	Connections: { RBXScriptConnection },
}

const CustomerController = Modux.Controller(
	"CustomerController",
	{
		Require = { "RigController", "AudioController", "AnimController", "PromptController", "TabletController" },
		Priority = 670,
	}
)

function CustomerController:Setup()
	self.Entries = {} :: { [number]: Entry }
	-- NpcId -> rig
	self.Models = {} :: { [number]: Model }
	self.Tracked = {} :: { [Model]: Tracked }
	self.Reactions = {} :: { [Model]: Reaction }
	self.Mounted = 0 :: number
	self.Now = Vide.source(workspace:GetServerTimeNow()) :: Vide.Source<number>
	self.Gui = nil :: Instance?
	self.Random = Random.new() :: Random
	-- NpcId of the customer on the HUD order card; 0 = none
	self.Focus = Vide.source(0) :: Vide.Source<number>
end

-- Reactive read of a customer record (nil = no such customer). For other controllers and debugging.
function CustomerController:RecordOf(id: number): Record?
	const entry = self.Entries[id]
	return if entry then entry.Record() or nil else nil
end

-- Reactive customer-anomaly variant (nil = ordinary, or no such customer / rig yet). TASK-110.
function CustomerController:VariantOf(id: number): string?
	const entry = self.Entries[id]
	const value = if entry then entry.Variant() else false
	return if typeof(value) == "string" then value else nil
end

-- Topping keys of an order, in display order (ToppingKeys order), max 3 (DEC-071).
function CustomerController:ToppingsOf(record: Record): { OrderBubble.Topping }
	return self:ToppingsOfOrder(record.Order)
end

-- Same for any bitfield of the order (Order or Order2).
function CustomerController:ToppingsOfOrder(order: { [string]: boolean }): { OrderBubble.Topping }
	const list: { OrderBubble.Topping } = {}
	for _, key in Content.Ingredients.ToppingKeys do
		if order[key] then
			table.insert(list, { Key = key, Icon = Content.Ingredients.ByKey[key].Icon })
			if #list >= ORDER_RULES.MaxToppings then
				break
			end
		end
	end
	return list
end

-- Patience left (0..1) for the ring; -1 = no ring.
function CustomerController:PatienceOf(entry: Entry): number
	const record = entry.Record()
	if record == false or record.PatienceEndsAt <= 0 or entry.Total <= 0 then
		return -1
	end
	return math.clamp((record.PatienceEndsAt - self.Now()) / entry.Total, 0, 1)
end

function CustomerController:NewEntry(id: number): Entry
	const entry: Entry = {
		Id = id,
		Record = Vide.source(false :: Record | false) :: Vide.Source<Record | false>,
		Reacting = Vide.source(false) :: Vide.Source<boolean>,
		EndsAt = 0,
		Total = 0,
		Model = nil,
		Unmount = nil,
		Gui = nil,
		BarUnmount = nil,
		BarGui = nil,
		Face = nil,
		Variant = Vide.source(false :: string | false) :: Vide.Source<string | false>,
		Done = Vide.source(false :: Done | false) :: Vide.Source<Done | false>,
		DoneTimer = nil,
	}
	self.Entries[id] = entry
	return entry
end

local function sameOrder(a: { [string]: boolean }, b: { [string]: boolean }): boolean
	for key, on in a do
		if on and not b[key] then
			return false
		end
	end
	for key, on in b do
		if on and not a[key] then
			return false
		end
	end
	return true
end

-- Copies: the set may reuse its record table between frames, and Vide needs a new value to notice a change.
function CustomerController:WriteRecord(id: number, record: Record?)
	if record == nil then
		self:Drop(id)
		return
	end
	const entry = self.Entries[id] or self:NewEntry(id)
	const copy: Record = {
		State = record.State,
		Slot = record.Slot,
		Order = table.clone(record.Order),
		PatienceEndsAt = record.PatienceEndsAt,
		Phase = record.Phase,
		PatienceSpan = record.PatienceSpan,
		Mood = record.Mood,
		Order2 = if record.Order2 then table.clone(record.Order2) else nil,
		Leader = record.Leader,
		Pickup = record.Pickup,
	}
	const old = Vide.untrack(entry.Record)
	if old ~= false and old.State ~= "Waiting" and copy.State == "Waiting" then
		self:Cue(id, "order_take")
	end
	const oldSecond = if old ~= false then old.Order2 else nil
	if old ~= false and oldSecond ~= nil and copy.Order2 == nil and copy.State == "Waiting" then
		-- one hot dog of the pair resolved: Order unchanged = the 2nd row went, else the 1st
		const row = if sameOrder(old.Order, copy.Order) then 2 else 1
		self:MarkDone(entry, row, self:ToppingsOfOrder(if row == 2 then oldSecond else old.Order))
	end
	const now = workspace:GetServerTimeNow()
	-- the server sends the length of the running phase (Q-192): nothing to derive here
	if copy.PatienceEndsAt <= 0 or copy.Phase == "None" then
		entry.EndsAt = 0
		entry.Total = 0
	else
		entry.EndsAt = copy.PatienceEndsAt
		entry.Total = math.max(copy.PatienceSpan, copy.PatienceEndsAt - now)
	end
	self.Now(now)
	const source: Vide.Source<Record | false> = entry.Record
	source(copy)
	self:Sync(id)
end

-- Keep the resolved row of a pair on the bubble for DONE_TIME s.
function CustomerController:MarkDone(entry: Entry, row: number, toppings: { OrderBubble.Topping })
	self:ClearDone(entry)
	entry.Done({ Row = row, Toppings = toppings })
	entry.DoneTimer = task.delay(DONE_TIME, function()
		entry.DoneTimer = nil
		entry.Done(false)
	end)
end

function CustomerController:ClearDone(entry: Entry)
	const timer = entry.DoneTimer
	entry.DoneTimer = nil
	if timer ~= nil and coroutine.running() ~= timer and coroutine.status(timer) == "suspended" then
		task.cancel(timer)
	end
	if Vide.untrack(entry.Done) ~= false then
		entry.Done(false)
	end
end

-- Reactive rows of the bubble: row 1, row 2 (nil = single row) and the resolved row (0 = none).
function CustomerController:RowsOf(entry: Entry): ({ OrderBubble.Topping }, { OrderBubble.Topping }?, number)
	const record = entry.Record()
	if record == false then
		return {}, nil, 0
	end
	const current = self:ToppingsOf(record)
	const done = entry.Done()
	const second = record.Order2
	if done ~= false and second == nil then
		if done.Row == 1 then
			return done.Toppings, current, 1
		end
		return current, done.Toppings, 2
	end
	return current, if second ~= nil then self:ToppingsOfOrder(second) else nil, 0
end

-- The customer left the set: bubble and face go with it.
function CustomerController:Drop(id: number)
	const entry = self.Entries[id]
	if entry == nil then
		return
	end
	self.Entries[id] = nil
	self:ClearDone(entry)
	self:Detach(entry)
	self:Fill()
	if Vide.untrack(self.Focus) == id then
		self:UpdateFocus()
	end
end

-- Unmount the bubble and give the rig its neutral face back.
function CustomerController:Detach(entry: Entry)
	self:Unmount(entry)
	const model = entry.Model
	if model ~= nil and entry.Face ~= nil then
		self.Dependencies.RigController:SetExpression(model, nil)
	end
	entry.Model = nil
	entry.Face = nil
	entry.Variant(false)
end

function CustomerController:Unmount(entry: Entry)
	const barUnmount = entry.BarUnmount
	if barUnmount then
		entry.BarUnmount = nil
		barUnmount()
	end
	const barGui = entry.BarGui
	if barGui then
		entry.BarGui = nil
		barGui:Destroy()
	end
	const unmount = entry.Unmount
	if unmount then
		entry.Unmount = nil
		self.Mounted -= 1
		unmount()
	end
	const gui = entry.Gui
	if gui then
		entry.Gui = nil
		gui:Destroy()
	end
end

-- Mount bubbles that were skipped by the MAX_BUBBLES cap or by a missing gui.
function CustomerController:Fill()
	for id, entry in self.Entries do
		if entry.Unmount == nil and self.Models[id] ~= nil then
			self:Sync(id)
		end
	end
end

local function headOf(model: Model): BasePart?
	const head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head
	end
	return model.PrimaryPart
end

-- Bring one customer's bubble and face in line with its record and rig.
function CustomerController:Sync(id: number)
	const entry = self.Entries[id]
	if entry == nil then
		return
	end
	const model = self.Models[id]
	if entry.Model ~= nil and entry.Model ~= model then
		self:Detach(entry)
	end
	const record = Vide.untrack(entry.Record)
	if model == nil or record == false then
		return
	end
	entry.Model = model

	const value = model:GetAttribute(VARIANT_ATTRIBUTE)
	const variant: string | false = if typeof(value) == "string" and value ~= "" then value else false
	if Vide.untrack(entry.Variant) ~= variant then
		entry.Variant(variant)
	end

	const mood = Content.Moods.ByKey[record.Mood]
	const face = if mood then mood.Expression else nil
	if face ~= entry.Face then
		entry.Face = face
		self.Dependencies.RigController:SetExpression(model, face)
	end

	-- a pair partner never has a bubble (FEAT-038): the leader's shows both hot dogs
	if entry.Unmount == nil and record.Leader == nil then
		self:Mount(entry, model)
	end
end

function CustomerController:Mount(entry: Entry, model: Model)
	const gui = self.Gui
	const head = headOf(model)
	if gui == nil or head == nil or self.Mounted >= MAX_BUBBLES then
		return
	end
	const unmount, billboard = Vide.root(function()
		return OrderBubble({
			Name = `OrderBubble_{entry.Id}`,
			Adornee = head,
			Empty = function()
				return entry.Variant() == BLANK
			end,
			Visible = function()
				const record = entry.Record()
				-- Slot 0 + Waiting = seated (or walking to its table): the table's own bubble (SeatingController) shows the
				-- order there, so this one would be a duplicate
				return record ~= false
					and record.State == "Waiting"
					and record.Slot ~= 0
					and record.Leader == nil
					and not entry.Reacting()
			end,
			Toppings = function()
				if entry.Variant() == BLANK then
					return {}
				end
				const first = self:RowsOf(entry)
				return first
			end,
			-- pair (TASK-148): 2nd hot dog, and the row just resolved
			Toppings2 = function()
				const _, second = self:RowsOf(entry)
				return second
			end,
			Done = function()
				const _, _, done = self:RowsOf(entry)
				return done
			end,
			-- the ring is gone: the PatienceBar above carries both clocks (Q-192)
			Patience = function()
				return -1
			end,
			WarnAt = WARN_AT,
			Offset = Vector3.new(0, head.Size.Y / 2 + HEAD_GAP, 0),
			MaxDistance = MAX_DISTANCE,
			Lift = BUBBLE_LIFT,
			AlwaysOnTop = true,
		})
	end)
	billboard.Parent = gui
	entry.Unmount = unmount
	entry.Gui = billboard

	-- Patience bar (Q-192): Queue clock while Ordering, Order clock while Waiting; floats over the bubble when there is one
	const barUnmount, bar = Vide.root(function()
		return PatienceBar({
			Name = `PatienceBar_{entry.Id}`,
			Adornee = head,
			Visible = function()
				const record = entry.Record()
				return record ~= false
					and record.Leader == nil
					and record.Phase ~= "None"
					and (record.State == "Ordering" or record.State == "Waiting")
					and not entry.Reacting()
			end,
			Phase = function(): PatienceBar.Phase
				const record = entry.Record()
				return if record ~= false and record.Phase == "Order" then "Order" else "Queue"
			end,
			Fraction = function()
				return math.max(self:PatienceOf(entry), 0)
			end,
			Lift = function()
				const record = entry.Record()
				if record ~= false and record.State == "Waiting" and record.Slot ~= 0 then
					return BUBBLE_LIFT + BAR_GAP + (if record.Order2 ~= nil then BUBBLE_TWO_ROWS else BUBBLE_ONE_ROW)
				end
				return BUBBLE_LIFT
			end,
			WarnAt = WARN_AT,
			Offset = Vector3.new(0, head.Size.Y / 2 + HEAD_GAP, 0),
			MaxDistance = MAX_DISTANCE,
		})
	end)
	bar.Parent = gui
	entry.BarUnmount = barUnmount
	entry.BarGui = bar
	self.Mounted += 1
end

-- Sale packet: reaction bubble over the rig (presentation only; the drawer comes from the Economy set).
function CustomerController:React(id: number, result: string)
	const model = self.Models[id]
	const gui = self.Gui
	if model == nil or gui == nil then
		return
	end
	const head = headOf(model)
	if head == nil then
		return
	end
	self:ClearReaction(model)

	const kind, line = Reactions.For(result, self.Random)
	const unmount, billboard = Vide.root(function()
		return ReactionBubble({
			Name = `ReactionBubble_{id}`,
			Adornee = head,
			Kind = function()
				return kind
			end,
			Text = function()
				return line
			end,
			Offset = Vector3.new(0, head.Size.Y / 2 + HEAD_GAP, 0),
			MaxDistance = MAX_DISTANCE,
		})
	end)
	billboard.Parent = gui

	const entry = self.Entries[id]
	if entry then
		entry.Reacting(true)
	end
	self.Reactions[model] = {
		Id = id,
		Unmount = unmount,
		Gui = billboard,
		Timer = task.delay(REACTION_TIME, function()
			self:ClearReaction(model)
		end),
	}
end

function CustomerController:ClearReaction(model: Model)
	const reaction = self.Reactions[model]
	if reaction == nil then
		return
	end
	self.Reactions[model] = nil
	if coroutine.running() ~= reaction.Timer and coroutine.status(reaction.Timer) == "suspended" then
		task.cancel(reaction.Timer)
	end
	reaction.Unmount()
	reaction.Gui:Destroy()
	const entry = self.Entries[reaction.Id]
	if entry then
		entry.Reacting(false)
	end
end

-- One-shot sound on the customer's head (nothing without a rig). Missing key = silent (row not in Content yet).
function CustomerController:Cue(id: number, key: string)
	const model = self.Models[id]
	if model == nil or Content.Sounds.ByKey[key] == nil then
		return
	end
	self.Dependencies.AudioController:Play(key, headOf(model) or model)
end

-- Sale packet: serve + reaction sound on the rig, reaction clip (npc_happy / npc_complain / npc_refuse_leave).
function CustomerController:Feedback(id: number, result: string)
	const feedback = Reactions.Feedback(result)
	if feedback.Served then
		self:Cue(id, "serve")
	end
	if feedback.Sound ~= "" then
		self:Cue(id, feedback.Sound)
	end
	const model = self.Models[id]
	if model ~= nil and feedback.Clip ~= "" then
		self.Dependencies.AnimController:Play(model, feedback.Clip)
	end
end

-- HUD order card ----------------------------------------------------------------------------------------------------

local function isWaiting(entry: Entry?): boolean
	if entry == nil then
		return false
	end
	const record = Vide.untrack(entry.Record)
	return record ~= false and record.State == "Waiting"
end

-- NpcId on the Ticket of the hot_dog Tool in my hand (restaurant), when that customer is Waiting; 0 = none.
function CustomerController:TicketFocus(): number
	const character = Players.LocalPlayer.Character
	const tool = if character then character:FindFirstChildOfClass("Tool") else nil
	const value = if tool then tool:GetAttribute(TICKET) else nil
	if typeof(value) == "number" and isWaiting(self.Entries[value]) then
		return value
	end
	return 0
end

-- Oldest head (restaurant): the Waiting customer at the front of the pickup line; 0 = nobody in it.
function CustomerController:PickupFocus(): number
	local best, bestPlace = 0, math.huge
	for id, entry in self.Entries do
		const record = Vide.untrack(entry.Record)
		if record == false or record.State ~= "Waiting" or record.Leader ~= nil or record.Pickup == nil then
			continue
		end
		if record.Pickup < bestPlace then
			best, bestPlace = id, record.Pickup
		end
	end
	return best
end

-- Customer of the card: (restaurant: the Ticket in my hand,) the prompt target's rig when it is Waiting, else
-- (restaurant: the front of the pickup line, else) the Q1 customer in Waiting. My talk is read by the card methods.
function CustomerController:PickFocus(): number
	const restaurant = RESTAURANT.Rules.Enabled
	if restaurant then
		const ticket = self:TicketFocus()
		if ticket ~= 0 then
			return ticket
		end
	end
	const target = self.Dependencies.PromptController.Target
	const rig = if target then target.Rig else nil
	const value = if rig then rig:GetAttribute("NpcId") else nil
	if typeof(value) == "number" and isWaiting(self.Entries[value]) then
		return value
	end
	if restaurant then
		const front = self:PickupFocus()
		if front ~= 0 then
			return front
		end
	end

	const character = Players.LocalPlayer.Character
	const origin = if character then character:GetPivot().Position else nil
	local best, bestDistance = 0, math.huge
	for id, entry in self.Entries do
		const record = Vide.untrack(entry.Record)
		if record == false or record.State ~= "Waiting" or record.Slot ~= FRONT_SLOT then
			continue
		end
		const model = self.Models[id]
		const distance = if origin and model then (model:GetPivot().Position - origin).Magnitude else 1e9 -- no rig yet: still a candidate
		if distance < bestDistance then
			best, bestDistance = id, distance
		end
	end
	return best
end

function CustomerController:UpdateFocus()
	const id = self:PickFocus()
	if Vide.untrack(self.Focus) ~= id then
		self.Focus(id)
		self.Now(workspace:GetServerTimeNow())
	end
end

-- Reactive: entry and record of the card customer (nil = no card).
function CustomerController:FocusEntry(): (Entry?, Record?)
	const id = self.Focus()
	const entry = if id ~= 0 then self.Entries[id] else nil
	if entry == nil then
		return nil, nil
	end
	const record = entry.Record()
	if record == false or record.State ~= "Waiting" or record.Leader ~= nil then
		return nil, nil
	end
	return entry, record
end

-- Reactive: my talk at a tablet (restaurant), the top priority of the card; nil = none.
function CustomerController:CardTalk(): Talk?
	if not RESTAURANT.Rules.Enabled then
		return nil
	end
	const talk = self.Dependencies.TabletController:MyTalk()
	if talk == nil then
		return nil
	end
	return { Npc = talk.Npc, Items = talk.Items, Reveal = talk.Reveal }
end

-- Toppings of hot dog `row` (1 or 2) said so far in a talk; nil = that hot dog not started (its bun not said).
local function talkRow(talk: Talk, row: number): { string }?
	local start = 0
	local seen = 0
	for index, key in talk.Items do
		if key == TALK_BASE then
			seen += 1
			if seen == row then
				start = index
				break
			end
		end
	end
	if start == 0 or talk.Reveal < start then
		return nil
	end
	const keys: { string } = {}
	for index = start + 2, math.min(#talk.Items, talk.Reveal) do
		const key = talk.Items[index]
		if key == TALK_BASE then
			break
		end
		table.insert(keys, key)
	end
	return keys
end

function CustomerController:TalkBlank(talk: Talk): boolean
	const entry = self.Entries[talk.Npc]
	return entry ~= nil and entry.Variant() == BLANK
end

-- Items said so far in my talk (HudOrder `Reveal`); nil = no talk (the card shows the whole order).
function CustomerController:CardReveal(): number?
	const talk = self:CardTalk()
	return if talk then talk.Reveal else nil
end

function CustomerController:CardShown(): boolean
	if self:CardTalk() ~= nil then
		return true
	end
	const entry = self:FocusEntry()
	return entry ~= nil
end

function CustomerController:CardEmpty(): boolean
	const talk = self:CardTalk()
	if talk ~= nil then
		return self:TalkBlank(talk)
	end
	const entry = self:FocusEntry()
	return entry ~= nil and entry.Variant() == BLANK
end

-- Topping keys of the card order (display order, max 3); none for a blank customer.
function CustomerController:CardToppings(): { string }
	const talk = self:CardTalk()
	if talk ~= nil then
		return if self:TalkBlank(talk) then {} else talkRow(talk, 1) or {}
	end
	const entry, record = self:FocusEntry()
	const keys: { string } = {}
	if entry == nil or record == nil or entry.Variant() == BLANK then
		return keys
	end
	for _, topping in self:ToppingsOf(record) do
		table.insert(keys, topping.Key)
	end
	return keys
end

-- Topping keys of the 2nd hot dog of a pair on the card (TASK-148); nil = single row.
function CustomerController:CardToppings2(): { string }?
	const talk = self:CardTalk()
	if talk ~= nil then
		return if self:TalkBlank(talk) then nil else talkRow(talk, 2)
	end
	const entry, record = self:FocusEntry()
	const second = if record ~= nil then record.Order2 else nil
	if entry == nil or second == nil or entry.Variant() == BLANK then
		return nil
	end
	const keys: { string } = {}
	for _, topping in self:ToppingsOfOrder(second) do
		table.insert(keys, topping.Key)
	end
	return keys
end

function CustomerController:CardPatience(): number
	const talk = self:CardTalk()
	if talk ~= nil then
		const talker = self.Entries[talk.Npc]
		return if talker then self:PatienceOf(talker) else -1
	end
	const entry = self:FocusEntry()
	return if entry then self:PatienceOf(entry) else -1
end

-- Rig tracking: NpcId attribute -> model, re-read on change (pool reuse = new id).
function CustomerController:Bind(model: Model)
	const tracked = self.Tracked[model]
	if tracked == nil then
		return
	end
	const value = model:GetAttribute("NpcId")
	const id = if typeof(value) == "number" and model:IsDescendantOf(workspace) then value else nil
	const old = tracked.Id
	if old == id then
		return
	end
	tracked.Id = id
	if old ~= nil then
		self:ClearReaction(model)
		if self.Models[old] == model then
			self.Models[old] = nil
			self:Sync(old)
		end
	end
	if id ~= nil then
		self.Models[id] = model
		self:Sync(id)
	end
end

function CustomerController:Track(instance: Instance)
	if not instance:IsA("Model") or self.Tracked[instance] ~= nil then
		return
	end
	const model = instance
	const tracked: Tracked = { Id = nil, Connections = {} }
	self.Tracked[model] = tracked
	local function bind()
		self:Bind(model)
	end
	table.insert(tracked.Connections, model:GetAttributeChangedSignal("NpcId"):Connect(bind))
	table.insert(
		tracked.Connections,
		model:GetAttributeChangedSignal(VARIANT_ATTRIBUTE):Connect(function()
			const id = tracked.Id
			if id ~= nil and self.Models[id] == model then
				self:Sync(id)
			end
		end)
	)
	table.insert(tracked.Connections, model.AncestryChanged:Connect(bind))
	table.insert(
		tracked.Connections,
		model.Destroying:Connect(function()
			self:Untrack(model)
		end)
	)
	bind()
end

function CustomerController:Untrack(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	const tracked = self.Tracked[instance]
	if tracked == nil then
		return
	end
	self.Tracked[instance] = nil
	for _, connection in tracked.Connections do
		connection:Disconnect()
	end
	self:ClearReaction(instance)
	const id = tracked.Id
	if id ~= nil and self.Models[id] == instance then
		self.Models[id] = nil
		self:Sync(id)
		self:Fill()
	end
end

function CustomerController:Watch(gui: Instance)
	self.Gui = gui
	CollectionService:GetInstanceAddedSignal(CrewRig.Tag):Connect(function(instance)
		self:Track(instance)
	end)
	CollectionService:GetInstanceRemovedSignal(CrewRig.Tag):Connect(function(instance)
		self:Untrack(instance)
	end)
	for _, instance in CollectionService:GetTagged(CrewRig.Tag) do
		self:Track(instance)
	end
	self:Fill()
end

CustomerController:OnInit(function(self)
	self:Setup()

	const net = self.Libs.Net
	net.Customers:onAdded(function(id, record)
		self:WriteRecord(id, record)
	end)
	net.Customers:onChanged(function(id, record)
		self:WriteRecord(id, record)
	end)
	net.Customers:onRemoved(function(id)
		self:WriteRecord(id, nil)
	end)

	net.Sale:onClient(function(sale)
		self:React(sale.Npc, sale.Result)
		self:Feedback(sale.Npc, sale.Result)
	end)
end)

CustomerController:OnStart(function(self)
	-- Night customers stare at this player while an anomaly with Tension runs (owner 2026-10-18)
	NightWatch()
	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self:Watch(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
end)

CustomerController:OnTick(function(self)
	self:UpdateFocus()
	if self.Mounted > 0 or Vide.untrack(self.Focus) ~= 0 then
		self.Now(workspace:GetServerTimeNow())
	end
end, TICK_RATE)

return CustomerController
