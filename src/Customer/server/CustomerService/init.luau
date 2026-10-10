--!strict
-- Customer flow, counter queue and life cycle (FEAT-009; DEC-045, DEC-046, DEC-185; MAP-01 §9.1; architecture.md
-- §3.1, §18.13; network.md §3.6, T41; TASK-032). Run place only. Single writer of the Customers set (id = NpcId).
--
-- Flow (day): mean interval = BaseInterval / (growth(Day) x PartyMult[connected] x DayFlowBonus), each interval
-- jittered by +-Jitter, all from Content.Flow / UpgradeService. Spawns only in Selling phases. One attempt per
-- interval; a full counter (customers queued or walking to it >= QueueSize) or the NPC cap skips it (FEAT-009: the
-- skipped one is never born and never counts). Every attempt fires SpawnAttempted(outcome) (R5, TASK-045).
-- Draws (type, species, outfit, spawn point, intervals, exit) use a Random seeded per shift from the run seed
-- (architecture.md §4 rule 6).
--
-- Life cycle: Arriving (spawn point -> Q5) -> Queued (walks up slot by slot as the queue moves) -> Ordering (reached
-- Q1) -> Waiting (written by TASK-033 on "Take Order") -> Leaving (Q1 -> EX-E / D1) -> removed and despawned.
-- The customer at Q1 keeps the slot until it leaves (Ordering and Waiting). PatienceEndsAt stays 0 here: TASK-033
-- writes it together with Order and Waiting (T41, K hidden). Prompts stay disabled here (TASK-033 owns them).
-- Shift end: Summary sends every customer still around away; a new shift (and a snapshot restore) starts empty
-- (data.md: customers are not in the snapshot). Closing ends as soon as nobody is at or walking to the counter
-- (RoundService:SetCounterProbe).
--
-- Orders (TASK-033; FEAT-010, FEAT-011; DEC-071, DEC-072; Orders.luau, OrderRoll.luau): the order is drawn when the
-- customer reaches the queue (K hidden, server-only Ticket) and patience runs from there. "Take Order" (Q1, Ordering)
-- writes Order + PatienceEndsAt + Waiting in one set write (T41), opens the tip window of the taker and turns the
-- customer prompt into "Serve". "Serve" checks the held hot dog against the order and pays into the drawer; "Refuse"
-- and patience running out send the customer away with $0. Every outcome: EconomyService:CountResult + Sale packet.
-- Mood (PROVISIONAL, Q-164): visual only — Annoyed at MoodRules.AnnoyedAt, Happy on Complete/Perfect, Complaining on
-- Wrong/Refuse/gave up; never touches DEC-072 pay.
--
-- Wave 2 (TASK-053; architecture.md §19.3, §19.26 A4; FEAT-009): customers spawn in every phase with
-- Content.Shift[phase].Selling (Open, Night). Night flow: mean interval = Nights[k].Customers.BaseInterval (fallback
-- Flow.NightInterval) / PartyMult[connected], no day growth and no Trailer Lights; cap Nights[k].Customers.Max (never
-- above Flow.MaxCustomersNight). The drawer side follows EconomyService:IsDrawerOpen() (selling phase or Closing):
-- the queue is still served in the day Closing. Leaving a selling phase for anything but the day Closing sends every
-- customer away (NightEnd/NightLost, the 6 AM Closing, Summary...), so the night Closing finds the counter empty.
-- Acted(id, action, player, result) fires after take_order, serve, refuse and give_up (patience, no player) for the
-- anomaly rules (§19.13). "Take Order" outside the drawer phases sends the D-04 notice shop_closed to that player.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Orders = require(script.Orders)
local Queue = require(script.Queue)
local Modux = require(ServerScriptService.server.Modux)

export type State = "Arriving" | "Queued" | "Ordering" | "Waiting" | "Leaving"

-- Outcome of one spawn attempt (board TASK-032 v1.1, R5)
export type Outcome = "spawned" | "skipped_queue_full" | "skipped_npc_cap"

-- Why a customer left (Left signal). "service" = sent away by Leave() (TASK-033: served, refused, gave up).
export type LeaveReason = "service" | "shift_end"

export type Customer = {
	Id: number, -- NpcId
	State: State,
	Slot: number, -- 0 = out of the queue; 1..5 = Q1..Q5 (target slot while walking up)
	Order: { [string]: boolean }, -- Customers.Order bitfield; empty until "Take Order" (TASK-033)
	PatienceEndsAt: number, -- 0 until "Take Order" (T41)
	Mood: string, -- Content.Moods key
	SpawnedAt: number, -- server time
	JoinedAt: number, -- server time it reached the queue (0 = still arriving); patience base for TASK-033
	LeftAt: number, -- server time it started leaving (0 = not leaving)
	Move: number, -- walk order counter: a newer order cancels the callback of the older one
}

-- Fields TASK-033 may write (Leaving goes through Leave)
export type Patch = {
	State: State?,
	Order: { [string]: boolean }?,
	PatienceEndsAt: number?,
	Mood: string?,
}

-- Customers set record (network.md §3.6)
export type Wire = {
	State: State,
	Slot: number,
	Order: { [string]: boolean },
	PatienceEndsAt: number,
	Mood: string,
}

-- Sale.Result (network.md §4.3) = EconomyService SaleResult
export type SaleResult = "Perfect" | "Complete" | "Incomplete" | "Wrong" | "Left" | "Refused"

-- Acted.action (TASK-053): the three customer actions, plus give_up when patience ran out (no player)
export type ActedAction = "take_order" | "serve" | "refuse" | "give_up"

type Weighted = { Point: string, Weight: number }

const TICK_RATE = 10 -- Hz
const SEED_MAX = 2147483646
const SEED_DOMAIN = "customers"
const ORDER_SEED_DOMAIN = "orders" -- own stream: order draws never shift the spawn draws
const SALE_MAX = 1000 -- Sale.Amount wire range
const TAKE_ORDER = "take_order"
const SERVE = "serve"
const REFUSE = "refuse"
const GIVE_UP = "give_up"
const CLOSING = "Closing"
const SHOP_CLOSED = "shop_closed" -- Content.Notices key (D-04 #10)
-- Same notice to the same player at most once per this many seconds (FEAT-005 anti-spam). PROVISIONAL constant:
-- no Content field holds it yet.
const NOTICE_GAP = 2
const HOT_DOG = "hot_dog"
const HAPPY = "Happy"
const ANNOYED = "Annoyed"
const COMPLAINING = "Complaining"
const LEAVE_TIMEOUT = 45 -- s; a leaving customer that never reaches its exit is despawned anyway
const NEUTRAL = "Neutral" -- arrival mood (Content.Moods)
-- Exit split (MAP-01 §9.1: Q1 -> EX-E 60% or D1 40%). PROVISIONAL constant: no Content table holds it yet.
const EXITS: { Weighted } = { { Point = "EX-E", Weight = 60 }, { Point = "D1", Weight = 40 } }

-- djb2 over a string, exact in doubles (h x 33 + byte < 2^38). Run seed hash, architecture.md §4 rule 6.
local function hash(text: string): number
	local h = 5381
	for index = 1, #text do
		h = (h * 33 + string.byte(text, index)) % 4294967296
	end
	return h
end

local function pick(list: { Weighted }, rng: Random): string
	local total = 0
	for _, entry in list do
		total += entry.Weight
	end
	local roll = rng:NextNumber() * total
	for _, entry in list do
		roll -= entry.Weight
		if roll < 0 then
			return entry.Point
		end
	end
	return list[#list].Point
end

local function hasPath(from: string, to: string, avoidQueue: boolean): boolean
	const ok, found = pcall(function(): boolean
		return MapIndex.Path(from, to, { AvoidQueue = avoidQueue }) ~= nil
	end)
	return ok and found
end

local function now(): number
	return workspace:GetServerTimeNow()
end

const CustomerService = Modux.Service("CustomerService", {
	Require = {
		"PlaceService",
		"NetService",
		"RunStateService",
		"RoundService",
		"EconomyService",
		"InteractionService",
		"UpgradeService",
		"NpcService",
		"ItemService",
		"ClassService",
	},
	Priority = 590,
})

function CustomerService:Setup()
	self.Enabled = false :: boolean
	self.Customers = {} :: { [number]: Customer }
	self.Line = Queue.new() :: Queue.Queue
	-- Reseeded at every ShiftStarted
	self.Rng = Random.new() :: Random
	-- Order draws (TASK-033), reseeded at every ShiftStarted
	self.OrderRng = Random.new() :: Random
	-- Server-only order of each customer in the queue, by NpcId (TASK-033)
	self.Tickets = {} :: { [number]: Orders.Ticket }
	-- Connected members, locked when the shop opens (DEC-185)
	self.Party = 1 :: number
	-- 0 = no spawn scheduled
	self.NextSpawnAt = 0 :: number
	self.Warned = {} :: { [string]: boolean }
	-- Created here so lower-priority services (Anomaly 570, TASK-033 handlers) connect in their OnInit.
	-- SpawnAttempted(outcome): every attempt. Joined(id): reached the queue (counted as arrival).
	-- Fronted(id): reached Q1, now Ordering. Left(id, reason): started leaving. Removed(id): record gone, NPC pooled.
	self.SpawnAttempted = self.Libs.Signal.new() :: SignalLib.Signal<Outcome>
	self.Joined = self.Libs.Signal.new() :: SignalLib.Signal<number>
	self.Fronted = self.Libs.Signal.new() :: SignalLib.Signal<number>
	self.Left = self.Libs.Signal.new() :: SignalLib.Signal<number, LeaveReason>
	self.Removed = self.Libs.Signal.new() :: SignalLib.Signal<number>
	-- Acted(id, action, player, result): a customer action finished (TASK-053). take_order: result nil;
	-- serve: the SaleResult (Wrong included); refuse: "Refused"; give_up: player nil, "Left".
	self.Acted = self.Libs.Signal.new() :: SignalLib.Signal<number, ActedAction, Player?, SaleResult?>
	-- Last time each notice went to each player (FEAT-005 anti-spam)
	self.NoticeAt = {} :: { [Player]: { [string]: number } }
end

function CustomerService:WarnOnce(key: string, message: string)
	if self.Warned[key] then
		return
	end
	self.Warned[key] = true
	warn(`[CustomerService] {message}`)
end

-- Reads -----------------------------------------------------------------------------------------------------------

function CustomerService:Get(id: number): Customer?
	return self.Customers[id]
end

-- NpcId of the customer whose rig contains `instance` (prompt anchor, body part), or nil.
function CustomerService:IdOf(instance: Instance): number?
	const id = self.Dependencies.NpcService:IdOf(instance)
	return if id ~= nil and self.Customers[id] ~= nil then id else nil
end

-- Customer on Q1 (Ordering or Waiting once it got there), or nil.
function CustomerService:Front(): number?
	return Queue.front(self.Line)
end

-- Customers alive (arriving, in the queue and leaving: FEAT-009 counts them until they vanish).
function CustomerService:Count(): number
	local count = 0
	for _ in self.Customers do
		count += 1
	end
	return count
end

-- Customers at or walking to the counter (everyone but Leaving).
function CustomerService:Occupants(): number
	local count = 0
	for _, customer in self.Customers do
		if customer.State ~= "Leaving" then
			count += 1
		end
	end
	return count
end

function CustomerService:IsCounterEmpty(): boolean
	return self:Occupants() == 0
end

-- Active queue slots now (Counter level, UPG-003). Read live: a Counter bought mid-shift opens Q4 at once.
function CustomerService:QueueSize(): number
	return Queue.size(self.Dependencies.UpgradeService:GetEffect("QueueSize"))
end

-- Content.Shift row of the current phase (nil = unknown key: treated as not selling).
function CustomerService:PhaseRow(): Content.Phase?
	return Content.Shift.ByKey[self.Dependencies.RoundService:GetPhase()]
end

-- Customers spawn now (Content.Shift[phase].Selling: Open, Night). Read from the table, not from a phase list.
function CustomerService:IsSelling(): boolean
	const round = self.Dependencies.RoundService
	const row = self:PhaseRow()
	return round:IsStarted() and row ~= nil and row.Selling
end

-- Night shift (or a night-only phase while RoundService still reports days, wave 1).
function CustomerService:IsNightShift(): boolean
	const row = self:PhaseRow()
	return self.Dependencies.RoundService:IsNight() or (row ~= nil and row.Kind == "Night")
end

-- Content.Nights row of the current night, or nil (day, or a night index without a row).
function CustomerService:NightRow(): Content.Night?
	const night = self.Dependencies.RoundService:Info().Night
	return Content.Nights.ByKey[`night_{night}`]
end

function CustomerService:MaxCustomers(): number
	const flow = Content.Flow
	if not self:IsNightShift() then
		return flow.MaxCustomersDay
	end
	const row = self:NightRow()
	return if row ~= nil then math.min(row.Customers.Max, flow.MaxCustomersNight) else flow.MaxCustomersNight
end

-- Run members connected to this server, 1..#PartyMult (DEC-185: connected players).
function CustomerService:ConnectedMembers(): number
	const runState = self.Dependencies.RunStateService
	local count = 0
	for _, player in Players:GetPlayers() do
		if runState:IsMember(player) then
			count += 1
		end
	end
	return math.clamp(count, 1, #Content.Flow.PartyMult)
end

-- Mean seconds between spawns now, or nil when there is no flow.
-- Day: BaseInterval / (growth(Day) x PartyMult x DayFlowBonus). Night (FEAT-009): Nights[k].Customers.BaseInterval
-- (fallback Flow.NightInterval) / PartyMult; no growth, no Trailer Lights.
function CustomerService:MeanInterval(): number?
	const round = self.Dependencies.RoundService
	const flow = Content.Flow
	const party = flow.PartyMult[math.clamp(self.Party, 1, #flow.PartyMult)]
	if self:IsNightShift() then
		const row = self:NightRow()
		if row == nil then
			self:WarnOnce("night", `no Nights row for night {round:Info().Night}: using Flow.NightInterval`)
		end
		const base = if row ~= nil then row.Customers.BaseInterval else flow.NightInterval
		if base <= 0 or party <= 0 then
			return nil
		end
		return base / party
	end
	const day = round:GetDay()
	const growth = math.min(1 + flow.GrowthPerDay * (day - 1), 1 + flow.GrowthCap)
	const bonus = self.Dependencies.UpgradeService:GetEffect("DayFlowBonus") -- Trailer Lights (DEC-055)
	const rate = growth * party * bonus / flow.BaseInterval
	if rate <= 0 then
		return nil
	end
	return 1 / rate
end

-- Next interval: mean +-Jitter, from the shift Random.
function CustomerService:NextInterval(): number?
	const mean = self:MeanInterval()
	if mean == nil then
		return nil
	end
	return mean * (1 + Content.Flow.Jitter * (2 * self.Rng:NextNumber() - 1))
end

-- Flow numbers now (dev / QA): connected members locked at Open, mean interval and active slots.
function CustomerService:Flow(): { Party: number, MeanInterval: number, QueueSize: number, NextSpawnAt: number }
	return {
		Party = self.Party,
		MeanInterval = self:MeanInterval() or 0,
		QueueSize = self:QueueSize(),
		NextSpawnAt = self.NextSpawnAt,
	}
end

-- Network ---------------------------------------------------------------------------------------------------------

function CustomerService:Record(customer: Customer): Wire
	return {
		State = customer.State,
		Slot = customer.Slot,
		Order = customer.Order,
		PatienceEndsAt = customer.PatienceEndsAt,
		Mood = customer.Mood,
	}
end

function CustomerService:Publish(customer: Customer, added: boolean)
	if not self.Dependencies.NetService:IsRunning() then
		return
	end
	if added then
		self.Libs.Net.Customers:add(customer.Id, self:Record(customer))
	else
		self.Libs.Net.Customers:update(customer.Id, self:Record(customer))
	end
end

-- Movement --------------------------------------------------------------------------------------------------------

-- Walks the customer's NPC to `node` in its own thread. `done(ok)` runs only if this is still the customer's latest
-- order when the walk ends (a newer Walk or a removal silences it).
function CustomerService:Walk(customer: Customer, node: string, avoidQueue: boolean, done: (ok: boolean) -> ())
	customer.Move += 1
	const order = customer.Move
	task.spawn(function()
		const ok = self.Dependencies.NpcService:WalkTo(customer.Id, node, { AvoidQueue = avoidQueue })
		if self.Customers[customer.Id] == customer and customer.Move == order then
			done(ok)
		end
	end)
end

-- Sends everyone in the queue to the slot of their position (Q1 = front). Called after every join and leave.
function CustomerService:Refresh()
	for slot, id in self.Line.Order do
		const customer = self.Customers[id]
		if customer == nil or customer.Slot == slot then
			continue
		end
		customer.Slot = slot
		self:Publish(customer, false)
		self:Walk(customer, Queue.point(slot), false, function(ok: boolean)
			if ok then
				self:Reached(customer, slot)
			end
		end)
	end
end

-- The customer stands on its slot. Q1 = the ordering spot.
function CustomerService:Reached(customer: Customer, slot: number)
	if slot ~= 1 or customer.Slot ~= 1 or customer.State ~= "Queued" then
		return
	end
	customer.State = "Ordering"
	self:Publish(customer, false)
	self.Fronted:Fire(customer.Id)
end

-- Arrived at the queue entry (Q5): takes the next slot behind the last customer.
function CustomerService:Join(customer: Customer)
	if customer.State ~= "Arriving" then
		return
	end
	customer.State = "Queued"
	customer.JoinedAt = now()
	Queue.join(self.Line, customer.Id)
	self:Publish(customer, false)
	self.Dependencies.EconomyService:CountArrival() -- FEAT-014 denominator; skipped spawns never get here
	self.Joined:Fire(customer.Id)
	self:Refresh()
end

-- Spawn -----------------------------------------------------------------------------------------------------------

-- One spawn attempt (FEAT-009). Returns the outcome; the NpcId too when it spawned.
function CustomerService:Attempt(): (Outcome, number?)
	local outcome: Outcome = "spawned"
	local id: number? = nil
	const npc = self.Dependencies.NpcService
	if Queue.isFull(self:Occupants(), self:QueueSize()) then
		outcome = "skipped_queue_full"
	elseif self:Count() >= self:MaxCustomers() or npc:Count() >= npc:Capacity() then
		outcome = "skipped_npc_cap"
	else
		id = npc:Spawn({ Rng = self.Rng })
		if id == nil then
			-- Pool full, or no binding / no type unlocked (NpcService warns once): counted as the cap
			outcome = "skipped_npc_cap"
		end
	end
	if id ~= nil then
		self:Create(id)
	end
	self.SpawnAttempted:Fire(outcome)
	return outcome, id
end

function CustomerService:Create(id: number)
	const customer: Customer = {
		Id = id,
		State = "Arriving",
		Slot = 0,
		Order = {},
		PatienceEndsAt = 0,
		Mood = NEUTRAL,
		SpawnedAt = now(),
		JoinedAt = 0,
		LeftAt = 0,
		Move = 0,
	}
	self.Customers[id] = customer
	self:SetPrompts(id, false)
	self:Publish(customer, true)
	-- Arrival routes end at Q5 and never cross the queue (AvoidQueue, MAP-01 §9.1)
	self:Walk(customer, Queue.entry(), true, function(ok: boolean)
		if ok then
			self:Join(customer)
		else
			self:Remove(id) -- no route (binding broken): nothing to queue
		end
	end)
end

-- Leave / remove --------------------------------------------------------------------------------------------------

function CustomerService:SetPrompts(id: number, enabled: boolean)
	const customerAnchor, refuseAnchor = self.Dependencies.NpcService:Anchors(id)
	const interaction = self.Dependencies.InteractionService
	if customerAnchor ~= nil then
		interaction:SetPrompt(customerAnchor, enabled)
	end
	if refuseAnchor ~= nil then
		interaction:SetPrompt(refuseAnchor, enabled)
	end
end

-- Exit for a customer standing on `node`. From Q2..Q5 the route must go along the queue (Q nodes as steps);
-- from Q1 or the street, never through it. Falls back to the other exit when the drawn one has no route.
function CustomerService:ExitRoute(node: string): (string?, boolean)
	const slot = Queue.slotOfNode(node)
	const avoidQueue = slot == nil or slot == 1
	const first = pick(EXITS, self.Rng)
	if hasPath(node, first, avoidQueue) then
		return first, avoidQueue
	end
	for _, entry in EXITS do
		if entry.Point ~= first then
			if hasPath(node, entry.Point, avoidQueue) then
				return entry.Point, avoidQueue
			end
			if hasPath(node, entry.Point, false) then
				return entry.Point, false
			end
		end
	end
	if hasPath(node, first, false) then
		return first, false
	end
	return nil, false
end

-- Sends the customer away (served, refused, gave up: TASK-033; shift end). Frees its slot at once: the queue
-- moves up. `mood` = new Content.Moods key (optional). false = unknown id or already leaving.
function CustomerService:Leave(id: number, mood: string?, reason: LeaveReason?): boolean
	const customer = self.Customers[id]
	if customer == nil or customer.State == "Leaving" then
		return false
	end
	if mood ~= nil and Content.Moods.ByKey[mood] == nil then
		warn(`[CustomerService] Leave: unknown mood {mood}`)
		mood = nil
	end
	const wasQueued = Queue.leave(self.Line, id)
	customer.State = "Leaving"
	customer.Slot = 0
	customer.LeftAt = now()
	if mood ~= nil then
		customer.Mood = mood
	end
	self:SetPrompts(id, false)
	self:Publish(customer, false)
	self.Left:Fire(id, reason or "service")
	if wasQueued then
		self:Refresh()
	end

	const node = self.Dependencies.NpcService:GetNode(id)
	const exit, avoidQueue = self:ExitRoute(node or "")
	if exit == nil then
		self:Remove(id)
		return true
	end
	self:Walk(customer, exit, avoidQueue, function()
		self:Remove(id)
	end)
	return true
end

-- Drops the record and returns the NPC to the pool. Safe to call twice.
function CustomerService:Remove(id: number)
	if not self:Forget(id) then
		return
	end
	self.Dependencies.NpcService:Despawn(id)
end

-- Record gone (set removed, queue moved up); the NPC is the caller's business. false = unknown id.
function CustomerService:Forget(id: number): boolean
	const customer = self.Customers[id]
	if customer == nil then
		return false
	end
	customer.Move += 1
	self.Customers[id] = nil
	const wasQueued = Queue.leave(self.Line, id)
	if self.Dependencies.NetService:IsRunning() then
		self.Libs.Net.Customers:remove(id)
	end
	self.Removed:Fire(id)
	if wasQueued then
		self:Refresh()
	end
	return true
end

-- Every customer away now (shift end): they walk off instead of vanishing.
function CustomerService:SendAllAway()
	const ids: { number } = {}
	for id, customer in self.Customers do
		if customer.State ~= "Leaving" then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	for _, id in ids do
		self:Leave(id, nil, "shift_end")
	end
end

-- Every customer gone at once (new shift, snapshot restore: the shift starts empty, data.md).
function CustomerService:RemoveAll()
	const ids: { number } = {}
	for id in self.Customers do
		table.insert(ids, id)
	end
	for _, id in ids do
		self:Remove(id)
	end
	Queue.clear(self.Line)
end

-- Writes for TASK-033 -----------------------------------------------------------------------------------------------

-- Updates the fields TASK-033 owns (Order, PatienceEndsAt, Mood, State Ordering/Waiting) in one set write.
-- false = unknown id, already leaving or an invalid patch (nothing written).
function CustomerService:Update(id: number, patch: Patch): boolean
	const customer = self.Customers[id]
	if customer == nil or customer.State == "Leaving" then
		return false
	end
	if patch.State ~= nil and patch.State ~= "Ordering" and patch.State ~= "Waiting" then
		warn(`[CustomerService] Update: state {patch.State} is not writable here (use Leave)`)
		return false
	end
	if patch.Mood ~= nil and Content.Moods.ByKey[patch.Mood] == nil then
		warn(`[CustomerService] Update: unknown mood {patch.Mood}`)
		return false
	end
	const ends = patch.PatienceEndsAt
	if ends ~= nil and (ends ~= ends or ends < 0 or ends == math.huge) then
		warn("[CustomerService] Update: PatienceEndsAt must be a finite number >= 0")
		return false
	end
	if patch.Order ~= nil then
		for key in patch.Order do
			if not table.find(Content.Ingredients.ToppingKeys, key) then
				warn(`[CustomerService] Update: {key} is not a topping key`)
				return false
			end
		end
		customer.Order = table.clone(patch.Order)
	end
	if patch.State ~= nil then
		customer.State = patch.State
	end
	if ends ~= nil then
		customer.PatienceEndsAt = ends
	end
	if patch.Mood ~= nil then
		customer.Mood = patch.Mood
	end
	self:Publish(customer, false)
	return true
end

-- Orders (TASK-033) -------------------------------------------------------------------------------------------------

-- Server-only order of a customer (dev / QA). nil = not in the queue yet, or gone.
function CustomerService:GetTicket(id: number): Orders.Ticket?
	return self.Tickets[id]
end

-- Reached the queue: the order is drawn now (K hidden) and patience starts (FEAT-011 "Chegada", DEC-072).
function CustomerService:OpenTicket(id: number)
	const customer = self.Customers[id]
	const npc = self.Dependencies.NpcService:Get(id)
	if customer == nil or npc == nil then
		return
	end
	const round = self.Dependencies.RoundService
	const toppings = Orders.Roll(round:GetDay(), npc.CustomerType, self.OrderRng, round:IsNight())
	const bonus = self.Dependencies.UpgradeService:GetEffect("PatienceBonus")
	const arrivedAt = if customer.JoinedAt > 0 then customer.JoinedAt else now()
	self.Tickets[id] = Orders.Ticket(toppings, arrivedAt, bonus)
end

-- Reached Q1: "Take Order" and "Refuse" come on (the client still hides them by state, network.md §3.6).
function CustomerService:OnFronted(id: number)
	const customerAnchor = self.Dependencies.NpcService:Anchors(id)
	if customerAnchor ~= nil then
		customerAnchor:SetAttribute("PromptAction", TAKE_ORDER)
	end
	self:SetPrompts(id, true)
end

-- Customer + ticket behind a prompt anchor, when the customer can still be served (not leaving).
function CustomerService:TicketAt(anchor: Instance): (number?, Customer?, Orders.Ticket?)
	const id = self:IdOf(anchor)
	if id == nil then
		return nil, nil, nil
	end
	const customer = self.Customers[id]
	const ticket = self.Tickets[id]
	if customer == nil or ticket == nil or customer.State == "Leaving" then
		return nil, nil, nil
	end
	return id, customer, ticket
end

-- Common gate of the three actions: active member, drawer open (selling phase or Closing: the queue is still
-- served, EconomyService:IsDrawerOpen), customer on Q1.
function CustomerService:CanAct(player: Player, anchor: Instance, state: State?): boolean
	if not self.Dependencies.RunStateService:IsActive(player) then
		return false
	end
	if not self.Dependencies.EconomyService:IsDrawerOpen() then
		return false
	end
	const id, customer = self:TicketAt(anchor)
	if id == nil or customer == nil or self:Front() ~= id or customer.Slot ~= 1 then
		return false
	end
	if state ~= nil and customer.State ~= state then
		return false
	end
	return customer.State == "Ordering" or customer.State == "Waiting"
end

-- Sends `key` to `player` unless the same key went to them less than NOTICE_GAP s ago (FEAT-005 anti-spam).
function CustomerService:NotifyThrottled(player: Player, key: string)
	const t = now()
	local sent = self.NoticeAt[player]
	if sent == nil then
		sent = {}
		self.NoticeAt[player] = sent
	end
	const last = sent[key]
	if last ~= nil and t - last < NOTICE_GAP then
		return
	end
	sent[key] = t
	self.Dependencies.RunStateService:Notify(player, key)
end

-- D-04 #10: "Take Order" on a customer of ours refused while the drawer is closed (the phase turned during the tap:
-- the customer is already leaving with its prompt off). Called from InteractionService.Rejected with reason "state",
-- which only comes after the target, gate and range checks: a forged packet never gets here with a valid anchor.
-- Only an active member gets it; an anchor that is not one of our customers stays silent (FEAT-005).
function CustomerService:NoticeShopClosed(player: Player, anchor: Instance)
	if self.Dependencies.EconomyService:IsDrawerOpen() then
		return
	end
	if not self.Dependencies.RunStateService:IsActive(player) or self:IdOf(anchor) == nil then
		return
	end
	self:NotifyThrottled(player, SHOP_CLOSED)
end

-- Outcome of a customer: shift ledger + Sale to the group. `amount` = what went into the drawer.
function CustomerService:Settle(id: number, result: SaleResult, amount: number)
	self.Dependencies.EconomyService:CountResult(result)
	const net = self.Dependencies.NetService
	if net:IsRunning() then
		self.Libs.Net.Sale:fireClient(net.Audience, {
			Npc = id,
			Result = result,
			Amount = math.clamp(math.floor(amount), 0, SALE_MAX),
		})
	end
end

-- "Take Order" (FEAT-011): order, real patience and Waiting in one write (T41); tip window of the taker.
function CustomerService:TakeOrder(player: Player, anchor: Instance)
	const id, _, ticket = self:TicketAt(anchor)
	if id == nil or ticket == nil then
		return
	end
	const class = self.Dependencies.ClassService
	const at = now()
	ticket.Taker = player
	ticket.TakenAt = at
	ticket.TipEndsAt = at + Orders.TipWindow(ticket.K, class:GetModifier(player, "TipWindow"))
	ticket.TipAmount = class:GetModifier(player, "TipAmount")
	const written = self:Update(id, {
		State = "Waiting",
		Order = Orders.Set(ticket.Toppings),
		PatienceEndsAt = ticket.PatienceEndsAt,
	})
	if not written then
		return
	end
	anchor:SetAttribute("PromptAction", SERVE)
	self.Acted:Fire(id, TAKE_ORDER, player, nil)
end

-- "Serve" (FEAT-011, DEC-072): validates the held hot dog against the order and pays into the drawer.
function CustomerService:Serve(player: Player, anchor: Instance)
	const id, _, ticket = self:TicketAt(anchor)
	const tool = self.Dependencies.ItemService:Holding(player, HOT_DOG)
	if id == nil or ticket == nil or tool == nil then
		return
	end
	const items = self.Dependencies.ItemService
	const economy = self.Dependencies.EconomyService
	const at = now()
	const verdict = Orders.Evaluate(ticket.Toppings, items:Toppings(tool))
	local result: SaleResult = verdict
	local amount = 0
	local mood: string? = nil
	if verdict == "Wrong" then
		-- $0; the hot dog stays in the server's hand (FEAT-011 "Errado devolvido")
		mood = COMPLAINING
	else
		items:Consume(player, tool)
		amount += economy:AddToDrawer(Orders.Pay(verdict, ticket.Price), "Sale")
		if verdict == "Complete" then
			mood = HAPPY
			const tip = Orders.Tip(ticket, at)
			if tip > 0 then
				amount += economy:AddToDrawer(tip, "Tip")
				result = "Perfect"
			end
		end
	end
	self:Settle(id, result, amount)
	self.Acted:Fire(id, SERVE, player, result)
	self:Leave(id, mood)
end

-- "Refuse" (FEAT-011, DEC-051): $0, unsatisfied.
function CustomerService:Refuse(player: Player, anchor: Instance)
	const id = self:TicketAt(anchor)
	if id == nil then
		return
	end
	self:Settle(id, "Refused", 0)
	self.Acted:Fire(id, REFUSE, player, "Refused")
	self:Leave(id, COMPLAINING)
end

-- Patience ran out (FEAT-011 "Desistiu"): $0, unsatisfied.
function CustomerService:GiveUp(id: number)
	if self.Tickets[id] == nil then
		return
	end
	self:Settle(id, "Left", 0)
	self.Acted:Fire(id, GIVE_UP, nil, "Left")
	self:Leave(id, COMPLAINING)
end

-- Patience and mood of every ticket (tick). Annoyed is written here; the client never derives it (network.md §3.6).
function CustomerService:StepOrders(t: number)
	const ids: { number } = {}
	for id in self.Tickets do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		const ticket = self.Tickets[id]
		const customer = self.Customers[id]
		if ticket == nil or customer == nil or customer.State == "Leaving" then
			continue
		end
		if t >= ticket.PatienceEndsAt then
			self:GiveUp(id)
		elseif customer.Mood == NEUTRAL and Orders.IsAnnoyed(ticket, t) then
			self:Update(id, { Mood = ANNOYED })
		end
	end
end

function CustomerService:RegisterOrders()
	const interaction = self.Dependencies.InteractionService
	interaction:RegisterAction(TAKE_ORDER, {
		Validate = function(player: Player, anchor: Instance): boolean
			return self:CanAct(player, anchor, "Ordering")
		end,
		Run = function(player: Player, anchor: Instance)
			self:TakeOrder(player, anchor)
		end,
	})
	interaction:RegisterAction(SERVE, {
		Validate = function(player: Player, anchor: Instance): boolean
			if not self:CanAct(player, anchor, "Waiting") then
				return false
			end
			const _, _, ticket = self:TicketAt(anchor)
			return ticket ~= nil
				and ticket.TakenAt > 0
				and self.Dependencies.ItemService:Holding(player, HOT_DOG) ~= nil
		end,
		Run = function(player: Player, anchor: Instance)
			self:Serve(player, anchor)
		end,
	})
	interaction:RegisterAction(REFUSE, {
		Validate = function(player: Player, anchor: Instance): boolean
			return self:CanAct(player, anchor, nil)
		end,
		Run = function(player: Player, anchor: Instance)
			self:Refuse(player, anchor)
		end,
	})
end

-- Shift -----------------------------------------------------------------------------------------------------------

-- New Random for the shift: hash(RunSeed, Day, IsNight, Attempt, domain) (architecture.md §4 rule 6).
function CustomerService:Reseed()
	const info = self.Dependencies.RoundService:Info()
	const seed = self.Dependencies.RunStateService.Seed()
	const base = `{seed}|{info.Day}|{if info.IsNight then 1 else 0}|{info.Attempt}|`
	self.Rng = Random.new(hash(base .. SEED_DOMAIN) % SEED_MAX + 1)
	self.OrderRng = Random.new(hash(base .. ORDER_SEED_DOMAIN) % SEED_MAX + 1)
end

function CustomerService:OnPhase(phase: string)
	if self:IsSelling() then
		-- PROVISIONAL (DEC-185 says "start of the shift"): locked when the selling phase starts (Open, Night), so a
		-- member who joins during the Prep counts on this shift. The first attempt is one drawn interval later.
		self.Party = self:ConnectedMembers()
		const interval = self:NextInterval()
		self.NextSpawnAt = if interval then now() + interval else 0
		return
	end
	self.NextSpawnAt = 0
	-- The day Closing still serves the queue (DEC-048). Any other phase after selling (NightEnd, NightLost, the 6 AM
	-- Closing, Summary, Finale, RunEnd) empties the counter: everyone still around walks off with no outcome.
	if phase == CLOSING and not self:IsNightShift() then
		return
	end
	self:SendAllAway()
end

function CustomerService:Step()
	const t = now()
	if self.NextSpawnAt > 0 and t >= self.NextSpawnAt and self:IsSelling() then
		self:Attempt()
		const interval = self:NextInterval()
		if interval == nil then
			self.NextSpawnAt = 0
		else
			-- From the scheduled time (no drift); a long stall does not burst several spawns at once
			self.NextSpawnAt = math.max(self.NextSpawnAt + interval, t + interval * 0.5)
		end
	end
	self:StepOrders(t)
	-- Safety net: a leaving customer that never reaches its exit still frees its NPC
	for id, customer in self.Customers do
		if customer.State == "Leaving" and t - customer.LeftAt > LEAVE_TIMEOUT then
			self:Remove(id)
		end
	end
end

-- Dev hook (Command Bar; R5 counter is TASK-045) ------------------------------------------------------------------

-- One spawn attempt now, whatever the phase. Returns the outcome and the NpcId.
function CustomerService:DevSpawn(): (Outcome, number?)
	if not self.Dependencies.PlaceService:IsDev() then
		error("[CustomerService] DevSpawn is dev mode only", 2)
	end
	return self:Attempt()
end

CustomerService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self.Enabled = true

	-- RoundService (750) and NpcService (610) created their signals in their own OnInit, before ours
	const round = self.Dependencies.RoundService
	round:SetCounterProbe(function(): boolean
		return self:IsCounterEmpty()
	end)
	round.ShiftStarted:Connect(function()
		self:RemoveAll()
		self:Reseed()
		self.NextSpawnAt = 0
	end)
	round.PhaseChanged:Connect(function(phase)
		self:OnPhase(phase)
	end)
	-- Someone else despawned one of ours (dev parade, anomaly in wave 2): drop the record
	self.Dependencies.NpcService.Despawned:Connect(function(id: number)
		self:Forget(id)
	end)

	-- Orders (TASK-033). Customers sent away at the shift end get no outcome: the shop is closed (Summary), they
	-- only count as arrived and not satisfied (PROVISIONAL, board TASK-032 note).
	self:RegisterOrders()
	self.Joined:Connect(function(id: number)
		self:OpenTicket(id)
	end)
	self.Fronted:Connect(function(id: number)
		self:OnFronted(id)
	end)
	-- D-04 (TASK-053): a refused "Take Order" while the drawer is closed gets the shop_closed toast
	self.Dependencies.InteractionService.Rejected:Connect(
		function(player: Player, anchorId: number, action: string, reason: string)
			if action ~= TAKE_ORDER or reason ~= "state" then
				return
			end
			const anchor = self.Dependencies.InteractionService:Get(anchorId)
			if anchor ~= nil then
				self:NoticeShopClosed(player, anchor)
			end
		end
	)
	Players.PlayerRemoving:Connect(function(player: Player)
		self.NoticeAt[player] = nil
	end)
	self.Left:Connect(function(id: number)
		self.Tickets[id] = nil
	end)
	self.Removed:Connect(function(id: number)
		self.Tickets[id] = nil
	end)
end)

CustomerService:OnTick(function(self)
	if self.Enabled then
		self:Step()
	end
end, TICK_RATE)

return CustomerService
