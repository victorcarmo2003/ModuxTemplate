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
-- The customer at Q1 keeps the slot until it leaves (Ordering and Waiting). PatienceEndsAt stays 0 until Q1 (Q-192):
-- OnFronted starts the Queue clock, "Take Order" swaps it for the Order clock. Prompts stay disabled here (TASK-033).
-- Shift end: Summary sends every customer still around away; a new shift (and a snapshot restore) starts empty
-- (data.md: customers are not in the snapshot). Closing ends as soon as nobody is at or walking to the counter and
-- nobody waits or eats at a table (RoundService:SetCounterProbe). On a day shift the Closing is the LAST CALL (DEC-240,
-- 2026-10-13): nobody new arrives, the queue and the tables are served without a rush (the patience clocks still run) and
-- the safety cap is Content.Shift Closing.Duration (120 s).
-- Queue size (DEC-241, 2026-10-13): the counter holds ONE customer by default (Counter L1) and grows to 5 with the Counter
-- upgrade (UpgradeService QueueSize). An attempt skipped by a full counter tries again after Flow.FullRetry (~3.5 s)
-- instead of waiting the whole interval.
--
-- Orders (TASK-033; FEAT-010, FEAT-011; DEC-071, DEC-072; Orders.luau, OrderRoll.luau): the order is drawn when the
-- customer reaches the queue (K hidden, server-only Ticket). Patience has two clocks (Q-192, Provisional): Queue (from
-- Q1 until "Take Order"; out = "Left", never attended) and Order (from "Take Order" until served; out = "Slow", the
-- food took too long). "Take Order" (Q1, Ordering) writes Order + Phase + PatienceEndsAt + PatienceSpan + Waiting in
-- one set write (T41), opens the tip window of the taker and turns the
-- customer prompt into "Serve". "Serve" checks the held hot dog against the order and pays into the drawer; closing the
-- service window (SendLineAway, the refusal since TASK-354) and patience running out send the customer away with $0. Every outcome: EconomyService:CountResult + Sale packet.
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
--
-- Wave 3 (TASK-108; architecture.md §19.3, §19.13; DEC-051): SpawnActor(spec) brings a customer anomaly (NpcService
-- Role "Actor", Variant blank / mirror / raincoat). It takes a counter slot and counts in every cap like a customer,
-- walks, orders and acts the same, but never touches the shift ledger: no CountArrival on joining, no CountResult on
-- its outcome (the anomaly module counts Arrival + Wrong only on a failure). The Sale packet still goes out.
-- AddServeRule(fn) lets a system override the verdict of "Serve" (any customer): the first rule that returns a result
-- wins (Complete/Perfect pay as Complete, Incomplete as Incomplete, anything else = Wrong: $0, the hot dog stays in
-- the server's hand).
--
-- Pairs (TASK-146; FEAT-038; Content.Flow.Groups; Group.luau; Q-182 A): an attempt may bring a leader + partner. Both
-- are records of the Customers set (they count 2 in every cap and 2 on the grade) but only the leader is in the
-- queue (1 slot), has prompts and orders: one ticket with 2 lines (leader's and partner's hot dog, K drawn apart),
-- Order clock by K1+K2 + Counter + Groups.PatienceBonus, tip window by K1+K2. "Serve" answers one line at a time
-- (Orders.Match), pays per line and settles per line (Sale.Npc = the line's owner); the pair leaves when no line is
-- pending. The partner never pathfinds: StepPairs moves it towards Group.Spot of the leader at TICK_RATE (Leader on
-- the wire, State Arriving / Queued / Leaving only, no balloon). No room for 2 = a lone customer ("spawned").
-- The interval after a pair is x Groups.IntervalMult.
-- Tables (TASK-145/146; FEAT-037; Q-209 flow, user request 2026-10-12, Provisional): SetSeater({ Offer, Left }) lets
-- SeatingService seat a customer (or pair) RIGHT AFTER "Take Order": Offer(party) true = a free table of the active
-- vehicle was reserved; the customer leaves the counter queue (Slot 0, the queue moves up, it no longer counts as a
-- counter occupant) and walks to the table with State Waiting, its balloon and its Order clock still running (AtTable =
-- true). It is served AT the table (action serve_table, SeatingService anchor -> ServeTable, same verdict / pay / tip /
-- Sale as the counter "Serve"); no table = it waits at Q1 as before. Once every line is answered a good result sends
-- it to eat (Leaving on the wire with Dining = true: no exit walk, no leave timeout) until SeatingService calls
-- Dismiss(id); a bad one, patience out or a shift end stand it up with no meal (Left(id, ate)).
--
-- Tutorial customer (user request 2026-10-11, Provisional; shared.Tutorial.Rules): RequestTutorial() (TutorialService,
-- when a rookie answered Walt's call) spawns one customer in a day Prep/Open as soon as the counter and the NPC pool
-- have room. Its rig carries the attribute Rules.Attribute = true (the client guides the rookie through it). It orders
-- Rules.Order, never runs out of patience (no ring: PatienceEndsAt 0 on the wire), never counts on the shift ledger
-- (no CountArrival / CountResult), gets no anomaly rule (no AddServeRule, no Acted, never copied by a mirror), cannot
-- be refused and never sits. "Take Order" works on it even in Prep (the drawer is closed there); "Serve" still needs
-- the drawer open (the rookie opens the shop first). The regular flow waits while it is at the counter.
-- EndTutorial() (nobody has the tutorial pending any more) sends an unserved one away with no outcome.
--
-- Prep quality (TASK-171; prep-mode.md §2; Q-219 B, Provisional): SellLine reads ItemService:QualityOf(tool) (Tool
-- attribute Quality, nil = quick mode) and applies Grade.Effect(Content.Prep, band): Perfect = tip $2 and a tip window
-- +4 s, Messy = no tip and the mood one band worse (Conclude), Good = as before. The price and the verdicts of
-- DEC-072 are untouched. TakeOrderFor / ServeFor are the same paths as the world prompt (same checks, same pay) for the
-- prep mode tabs (PrepService), which have no customer anchor.
-- World kitchen (TASK-569; kitchen-world.md §4; DEC-305): a hot dog that was a plate (PlateId) is graded at the sale by
-- Grade.Assembly against the line it answers: exact toppings and ready within Grade.PerfectTime of the order (party size) or
-- with a sausage flipped in the window (attribute Flipped) = Perfect, exact = Good, anything else = Messy. Grade.SaleEffect:
-- Perfect = base tip + Grades.Effects.Perfect.TipExtra, Good = base, Messy = no base tip and a mood band worse. All of it
-- inside the tip window, on a Complete sale only (Incomplete never looks at the grade). Any other hot dog keeps its Quality
-- attribute (nil = no grade, the base tip).
--
-- TASK-354 (owner request 2026-10-17, Provisional): no "Refuse" prompt or button any more. Refusing = closing the
-- service window (VehicleService.ShutterChanged -> SendLineAway: Refused, Acted "refuse" with who closed); anomaly
-- actors read the same Shutter event in Anomaly/Kit/CustomerActor.
--
-- Restaurant (TASK-380, R1-C; tech/restaurant-flow.md rev. 2 §2.1, §3.1; design FEAT-043/FEAT-046; DEC-280; Provisional).
-- Everything below is off unless Content.Restaurant.Rules.Enabled: with the flag off (or the map without PU-1) the flow
-- above is untouched. The tablet queue is still Queue.luau (Q1..Q5, unchanged).
--   Tablet mode (IsTabletMode: flag on + a Model tagged Binding.TabletTag with TabletIndex 1 in the Workspace): the rig's
--     "Take Order" prompt stays off and is refused; the order is taken by TabletService through TakeOrderFor at the end of
--     the talk. PausePatience(id, on) freezes the running clock during the talk (no give up, no Annoyed).
--   Pickup mode (IsPickupMode: flag on + MapPoint PU-1): after "Take Order" the customer gets its #n (Customers.Number,
--     1..Rules.OrderNumberMax per shift, wraps), leaves Q1 (the tablet queue moves up), joins the back of the pickup line
--     (Pickup.luau, Customers.Pickup = k) and walks to PU-k with its Order clock running; out of patience = Slow, out of
--     the line, the ones behind move up. Size = min(Rules.PickupSlots[party], PU-k points of the map); full = "Take
--     Order" refused with pickup_full and the customer stays at the tablet. No table at the order in this mode.
--     Hand-over: pickup_serve on the PICKUP prompt, or serve on the rig of a PU-n customer, -> ServeAtPickup (Pickup.choose:
--     plate Ticket exact > oldest exact > ticket owner > the served rig > PU-1). Verdict, pay, tip and Sale are the ones of
--     ServeCustomer (DEC-072: Wrong = $0, the hot dog stays in the hand, the customer leaves complaining).
--     Served (no Wrong/Left/Refused line): the rigs get the attribute Carrying = true (the client puts the plate in the
--     hand); with Content.Seating.SitAt = "Served" the Seater is offered the party AT THE SALE (Seater.Offer before
--     Leave(dining = true): SeatingService walks it from PU-n to the table, eats, Dismiss); no table (or SitAt "Order")
--     = takeaway: it walks out carrying the plate (Rules.TakeawayWhenNoTable). The plate is THE hot dog handed over (owner
--     2026-10-19): SellLine keeps the Tool's Toppings, Sauce, Altered and Dish (KeepLook) and SetCarrying writes them as the
--     rig attributes CarryToppings / CarrySauce / CarryAltered / CarryDish before Carrying.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Lync = require(ReplicatedStorage.Packages.Lync)
local Grade = require(ReplicatedStorage.shared.Prep.Grade)
local PlateTool = require(ReplicatedStorage.shared.Plate.PlateTool)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local TutorialRules = require(ReplicatedStorage.shared.Tutorial.Rules)
local Adopt = require(script.Adopt)
local Group = require(script.Group)
local Orders = require(script.Orders)
local Pickup = require(script.Pickup)
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
	PatienceEndsAt: number, -- deadline of the running patience phase; 0 = no clock (Q-192)
	Phase: Orders.Phase, -- Queue (Q1 until "Take Order"), Order ("Take Order" until served), None
	PatienceSpan: number, -- whole seconds of the running phase (0 = none)
	Mood: string, -- Content.Moods key
	SpawnedAt: number, -- server time
	JoinedAt: number, -- server time it reached the queue (0 = still arriving); patience base for TASK-033
	LeftAt: number, -- server time it started leaving (0 = not leaving)
	Move: number, -- walk order counter: a newer order cancels the callback of the older one
	Variant: Variant?, -- customer anomaly (SpawnActor); nil = ordinary customer
	-- Pairs (TASK-146)
	Order2: { [string]: boolean }?, -- leader: the 2nd pending hot dog on the wire (nil = none)
	Partner: number?, -- leader: NpcId of its partner
	Leader: number?, -- partner: NpcId of its leader
	Couple: boolean, -- pair walks and sits side by side (Flow.Groups.Pairs[].Couple)
	Held: boolean, -- partner: moved by SeatingService, StepPairs leaves it alone
	FollowTarget: Vector3?, -- partner: last MoveTo target
	FollowAt: number, -- partner: server time of that MoveTo
	Faced: boolean, -- partner: already turned like its standing leader
	-- Tables (TASK-145/146)
	Dining: boolean, -- handed to SeatingService: no exit walk, no leave timeout until Dismiss
	AtTable: boolean, -- Q-209: seated (or walking to its table) waiting for its food; out of the counter queue
	-- Tutorial customer (RequestTutorial): fixed order, endless patience, out of the ledger
	Tutorial: boolean,
	Model: Model?, -- tutorial customer: rig carrying TutorialRules.Attribute (cleared when the record goes)
	-- Restaurant (TASK-380)
	Pickup: number, -- 0 = not in the pickup line; k = PU-k (target spot while walking there); leaders only
	Number: number?, -- #n of the order (pickup mode), nil = none
	PausedAt: number?, -- PausePatience: server time the running clock was frozen; nil = running
	CarryModel: Model?, -- rig carrying the attribute Carrying (served at the pickup; cleared when the record goes)
	-- look of the hot dog it was handed (SellLine, before the Tool goes): the rig's Carry* attributes at SetCarrying
	CarryLook: { Toppings: string?, Sauce: string?, Altered: boolean, Dish: boolean }?,
	-- Drive-thru (TASK-574): lane spot 1..Drive.Lanes of its car (1 = at the window), 0 = a walking customer
	Drive: number,
}

-- DriveThruService hooks (SetDriver, TASK-574). Try(party): one spawn attempt may become a car; the NpcId when a car
-- spawned (it called Create with its lane spot), nil = an ordinary attempt. Left(id): a drive customer started leaving (its car drives
-- off; DriveThruService removes the record). Neither may yield.
export type Driver = {
	Try: (party: number) -> number?,
	Left: (id: number) -> (),
}

-- What SeatingService gets when a customer or pair takes its order (Seater.Offer). Leader = the customer with the ticket.
export type SeatParty = {
	Leader: number,
	Partner: number?,
	Couple: boolean,
	CustomerType: string, -- leader's type (SitChance)
}

-- SeatingService hooks (SetSeater). Offer: true = a table was reserved, the party is SeatingService's until Dismiss;
-- false = it stays at the counter. Left(leader, ate): an AtTable party is leaving (ate = served well: it eats first;
-- else it stands up at once). Neither may yield.
export type Seater = {
	Offer: (party: SeatParty) -> boolean,
	Left: (leader: number, ate: boolean) -> (),
}

-- Fields TASK-033 may write (Leaving goes through Leave)
export type Patch = {
	State: State?,
	Order: { [string]: boolean }?,
	PatienceEndsAt: number?,
	Phase: Orders.Phase?,
	PatienceSpan: number?,
	Mood: string?,
}

-- Customers set record (network.md §3.6, §14.2)
export type Wire = {
	State: State,
	Slot: number,
	Order: { [string]: boolean },
	PatienceEndsAt: number,
	Phase: Orders.Phase,
	PatienceSpan: number,
	Mood: string,
	Order2: { [string]: boolean }?,
	Leader: number?,
	Pickup: number?,
	Number: number?,
	Drive: number?,
}

-- Sale.Result (network.md §4.3) = EconomyService SaleResult
export type SaleResult = "Perfect" | "Complete" | "Incomplete" | "Wrong" | "Left" | "Refused" | "Slow"

-- Customer-anomaly variant (= NpcService.Variant; rig attribute "Variant", read by the client)
export type Variant = "blank" | "mirror" | "raincoat" | "shake" | "neck" | "eyes" | "bighead" | "float" | "stare"

-- SpawnActor request (architecture.md §19.13 Context.Spawn). Look fields force the draw (must be valid for the type);
-- CopyOf (mirror only) copies the type, species and outfit of a live, non-actor customer that is not leaving.
export type CustomerActorSpec = {
	Variant: Variant,
	CustomerType: string?,
	Species: string?,
	Outfit: string?,
	CopyOf: number?,
	From: string?,
}

-- Acted.action (TASK-053): the three customer actions, plus give_up when patience ran out (no player)
export type ActedAction = "take_order" | "serve" | "refuse" | "give_up"

-- Serve override (AddServeRule): nil = no opinion, the order check decides
export type ServeRule = (customer: Customer, tool: Tool, player: Player) -> SaleResult?

type Weighted = { Point: string, Weight: number }

const TICK_RATE = 10 -- Hz
const SEED_MAX = 2147483646
const SEED_DOMAIN = "customers"
const ORDER_SEED_DOMAIN = "orders" -- own stream: order draws never shift the spawn draws
const ACTOR_SEED_DOMAIN = "actors" -- own stream: anomaly actors never shift the customer draws
const MIRROR = "mirror"
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
const SERVE_HOLD_HINT = "serve_hold_hot_dog" -- Content.Notices keys (owner request 2026-10-12, Provisional)
const SERVE_EMPTY_HINT = "serve_nothing"
const HOT_DOG = "hot_dog"
const HAPPY = "Happy"
const ANNOYED = "Annoyed"
const COMPLAINING = "Complaining"
const LEAVE_TIMEOUT = 45 -- s; a leaving customer that never reaches its exit is despawned anyway
const NEUTRAL = "Neutral" -- arrival mood (Content.Moods)
-- Mood ladder, best first (Q-219 B: Messy = one band down; Content.Moods has no order of its own yet)
const MOOD_LADDER = { HAPPY, NEUTRAL, ANNOYED, COMPLAINING }
-- day phases where the tutorial customer may spawn (the tutorial runs in Prep and Open)
const TUTORIAL_PHASES: { [string]: boolean } = { Prep = true, Open = true }
-- Restaurant (TASK-380)
const PICKUP_SERVE = "pickup_serve" -- Content.Actions key (PICKUP Prompt_Serve)
const PICKUP_FULL = "pickup_full" -- Content.Notices key
const CARRYING = "Carrying" -- rig attribute: the customer carries its plate (Seating client, R1-J)
-- rig attributes: the look of THE hot dog it was handed (owner 2026-10-19; Seating client Meal draws it on its dish)
const CARRY_LOOK = { Toppings = "CarryToppings", Sauce = "CarrySauce", Altered = "CarryAltered", Dish = "CarryDish" }
const TICKET = "Ticket" -- hot_dog Tool attribute written by PlateService (NpcId of the plate's order)
-- hot_dog Tool attributes of a plate (shared/Plate/PlateTool): the sausage was flipped in the window; the plate's id
const FLIPPED = "Flipped"
const PLATE_ID = "PlateId"
const SERVED_SEAT_MODE = "Served" -- Content.Seating.SitAt: the Seater is offered the party at the sale
const NUMBER_MAX = 255 -- Net Customers.Number wire range
-- Exit split by shift: Content.Flow.Spawns.Exits (MAP-01 §9.8, Provisional; EX-E 60 / D1 40).

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
		"VehicleService",
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
	-- Actor look draws (TASK-108), reseeded at every ShiftStarted
	self.ActorRng = Random.new() :: Random
	-- Serve overrides (AddServeRule), in registration order
	self.ServeRules = {} :: { ServeRule }
	-- Server-only order of each customer in the queue, by NpcId (TASK-033)
	self.Tickets = {} :: { [number]: Orders.Ticket }
	-- Connected members, locked when the shop opens (DEC-185)
	self.Party = 1 :: number
	-- 0 = no spawn scheduled
	self.NextSpawnAt = 0 :: number
	-- night pacing (owner 2026-10-18): the counter freed, the next customer waits until CounterFreeAt (Flow.CounterGap)
	self.CounterFreeAt = 0 :: number
	self.CounterWasFull = false :: boolean
	-- restaurant nights: customers since the last quiet stretch (Restaurant.Flow.LullEvery)
	self.LullCount = 0 :: number
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
	-- serve: the SaleResult (Wrong included); refuse: "Refused"; give_up: player nil, "Left" (Queue clock) or "Slow" (Order clock, Q-192).
	self.Acted = self.Libs.Signal.new() :: SignalLib.Signal<number, ActedAction, Player?, SaleResult?>
	-- Last time each notice went to each player (FEAT-005 anti-spam)
	self.NoticeAt = {} :: { [Player]: { [string]: number } }
	-- SeatingService hook (SetSeater, TASK-145); nil = nobody sits
	self.Seater = nil :: Seater?
	-- The last attempt brought a pair: the next interval is x Groups.IntervalMult (FEAT-038)
	self.LastWasPair = false :: boolean
	-- Guarantee (Flow.Guarantee, Q-202): server time the counter became empty (0 = not empty / not counting) and the
	-- limit drawn for this gap. Own Random: it never shifts the seeded customer draws
	self.EmptySince = 0 :: number
	self.EmptyLimit = 0 :: number
	self.GuaranteeRng = Random.new() :: Random
	-- Dev: force the next attempt to be this pair (DevSpawnPair)
	self.ForcedPair = nil :: Group.Pair?
	-- Dev: topping lists of the next pair's two hot dogs (DevSpawnPair `orders`), consumed by its OpenTicket
	self.ForcedOrders = nil :: { { string } }?
	-- TutorialService hook (SetSpawnHold): the regular flow waits while it answers true
	self.SpawnHold = nil :: (() -> boolean)?
	-- HoldSpawns reasons (anomalies): no new customer arrives while any is set
	self.SpawnHolds = {} :: { [string]: boolean }
	-- dev only (owner 2026-10-16): ordinary arrivals off to test anomalies; anomaly actors (SpawnActor) still come
	self.DevNoArrivals = false :: boolean
	-- Tutorial customer asked (RequestTutorial) and not spawned yet; server time of the next try
	self.TutorialWanted = false :: boolean
	self.TutorialTryAt = 0 :: number
	-- look draws of the tutorial customer: never shifts the seeded customer draws
	self.TutorialRng = Random.new() :: Random
	-- Restaurant (TASK-380): pickup line PU-1..n and the last #n given this shift (0 = none yet)
	self.PickupLine = Pickup.new() :: Pickup.Pickup
	self.OrderNumber = 0 :: number
	-- Ordered(id, player): an order was taken (every customer, the tutorial one included; Acted skips it). Fired after
	-- the record moved to the pickup line (pickup mode) or to its table (Q-209). PlateService / TabletService may listen.
	self.Ordered = self.Libs.Signal.new() :: SignalLib.Signal<number, Player>
	-- DriveThruService hook (SetDriver, TASK-574); nil = no car ever
	self.Driver = nil :: Driver?
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

-- Counter slots taken: customers at or walking to the counter (everyone but Leaving, the ones already at a table and the
-- ones in the pickup line). A pair takes 1 (the partner is not counted, FEAT-038).
function CustomerService:Occupants(): number
	local count = 0
	for _, customer in self.Customers do
		if
			customer.State ~= "Leaving"
			and customer.Leader == nil
			and not customer.AtTable
			and customer.Pickup == 0
			and customer.Drive == 0 -- a car never takes a counter slot (TASK-574)
		then
			count += 1
		end
	end
	return count
end

-- A customer anomaly (SpawnActor) is alive (FEAT-037 tension: nobody sits meanwhile).
function CustomerService:HasActor(): boolean
	for _, customer in self.Customers do
		if customer.Variant ~= nil then
			return true
		end
	end
	return false
end

-- PedestrianService (TASK-163): passers-by that may become customers (Adopt.luau). Returns the dev controls.
function CustomerService:SetAdopter(adopter: Adopt.Adopter?): Adopt.Controls
	return Adopt.Set(self, adopter)
end

-- SeatingService (TASK-145; Q-209): called when a customer or pair takes its order and may sit. One seater.
function CustomerService:SetSeater(seater: Seater?)
	self.Seater = seater
end

-- Nobody at the counter, nobody waiting at a table for the food and nobody still eating there (the day Last call waits
-- for them, patience ends it, and the 120 s cap of the Closing row is the last resort).
function CustomerService:IsCounterEmpty(): boolean
	if self:Occupants() > 0 then
		return false
	end
	for _, customer in self.Customers do
		if (customer.AtTable or customer.Pickup > 0 or customer.Drive > 0) and customer.State ~= "Leaving" then
			return false -- waiting at a table, in the pickup line (TASK-380) or in the drive-thru lane (TASK-574)
		end
		-- Last call only: at night the Closing sends everybody away, the diners included
		if customer.Dining and customer.State == "Leaving" and not self:IsNightShift() then
			return false
		end
	end
	return true
end

-- Active queue slots now (Counter level, UPG-003). Read live: a Counter bought mid-shift opens Q4 at once.
-- At night Flow.NightQueueSize (TASK-287): one NPC at the counter, customer or anomaly actor, never two.
function CustomerService:QueueSize(): number
	if self:IsNightShift() then
		return Queue.size(Content.Flow.NightQueueSize)
	end
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

-- The trailer switch is on "Closed" (user request 2026-10-12, Provisional): no new customer arrives, the ones already
-- in the queue are served.
function CustomerService:IsPaused(): boolean
	return self.Dependencies.RoundService:IsPaused() or self:SpawnHeld()
end

-- TutorialService: "no regular customer arrives now" (user decision 2026-10-12, Provisional: Day 1 customers wait until
-- the tutorial is over, so the bun purchase and the restock never race a queue). Only the regular flow, the adoptions,
-- the guarantee and anomaly actors wait; the tutorial customer is not held. Last registration wins.
function CustomerService:SetSpawnHold(hold: () -> boolean)
	if type(hold) ~= "function" then
		error("[CustomerService] SetSpawnHold needs a function", 2)
	end
	self.SpawnHold = hold
end

-- Anomaly hold (ANM-004 "the copy knocks", DEC-247 Provisional): no regular customer, adoption, guarantee or actor
-- arrives while any reason is held. Independent of the tutorial hook above (that one has a single owner).
function CustomerService:HoldSpawns(reason: string, on: boolean)
	self.SpawnHolds[reason] = if on then true else nil
end

-- Dev: ordinary customers stop (on = false) or come back (on = true); anomaly actors are untouched. Studio dev only.
function CustomerService:DevSetArrivals(on: boolean)
	assert(self.Dependencies.PlaceService:IsDev(), "dev mode only")
	self.DevNoArrivals = not on
end

function CustomerService:SpawnHeld(): boolean
	if next(self.SpawnHolds) ~= nil then
		return true
	end
	const hold = self.SpawnHold
	if hold == nil then
		return false
	end
	const ok, result = pcall(hold)
	if not ok then
		warn(`[CustomerService] spawn hold errored: {result}`)
		return false
	end
	return result == true
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
		local base = if row ~= nil then row.Customers.BaseInterval else flow.NightInterval
		-- restaurant (owner 2026-10-18): its own, slower night cadence
		const restaurant = Content.Restaurant
		const list = restaurant.Flow.NightInterval
		base = list[math.clamp(round:Info().Night, 1, #list)] or base
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
	local interval = mean * (1 + Content.Flow.Jitter * (2 * self.Rng:NextNumber() - 1))
	-- restaurant nights: a quiet stretch after every LullEvery customers
	const restaurant = Content.Restaurant
	if self:IsNightShift() then
		const every = restaurant.Flow.LullEvery
		self.LullCount += 1
		if every > 0 and self.LullCount >= every then
			self.LullCount = 0
			interval += restaurant.Flow.LullSeconds
		end
	end
	return interval
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

-- Restaurant reads (TASK-380) ---------------------------------------------------------------------------------------

-- PU-k MapPoints the map binds, counted from PU-1 up to the first missing one (0 = no pickup line in the map).
function CustomerService:PickupPoints(): number
	const format = Content.Restaurant.Binding.PickupPoint
	local count = 0
	for spot = 1, Pickup.MaxSpots do
		const ok, point = pcall(MapIndex.FindPoint, Pickup.point(spot, format))
		if not ok or point == nil then
			break
		end
		count = spot
	end
	return count
end

-- Pickup line on: PU-1 in the map. Off = the trailer flow (served at Q1).
function CustomerService:IsPickupMode(): boolean
	return self:PickupPoints() > 0
end

-- Orders are taken at the tablet: TAB-1 (Model tagged Binding.TabletTag with
-- Binding.TabletIndex = 1) in the Workspace. The rig's "Take Order" prompt is off then (TabletService calls TakeOrderFor).
function CustomerService:IsTabletMode(): boolean
	const binding = Content.Restaurant.Binding
	for _, instance in CollectionService:GetTagged(binding.TabletTag) do
		if instance:GetAttribute(binding.TabletIndex) == 1 and instance:IsDescendantOf(workspace) then
			return true
		end
	end
	return false
end

-- Spots of the pickup line now: Rules.PickupSlots[party] (party locked when the shop opened, DEC-185), never more than
-- the PU-k points of the map. 0 = no pickup line.
function CustomerService:PickupSize(): number
	if not self:IsPickupMode() then
		return 0
	end
	const slots = Content.Restaurant.Rules.PickupSlots
	return Pickup.size(slots[math.clamp(self.Party, 1, #slots)], self:PickupPoints())
end

-- Customers (leaders) in the pickup line, PU-1 first (a copy).
function CustomerService:PickupIds(): { number }
	return table.clone(self.PickupLine.Order)
end

-- The pickup line has no free spot: "Take Order" is refused (pickup_full). false when pickup mode is off.
function CustomerService:IsPickupFull(): boolean
	return self:IsPickupMode() and Pickup.isFull(self.PickupLine, self:PickupSize())
end

-- Drive-thru (TASK-574; tech/restaurant-flow.md §3.4) ------------------------------------------------------------------
-- The car is DriveThruService's; the customer is an ordinary record with Drive = lane spot and a hidden, anchored rig
-- (plan B of §3.4: one NPC slot per car). It never takes a counter slot nor the pickup line: the order is taken at DT-PC
-- (TabletService, tablet Rules.DrivePcIndex) and served at DT-WIN (ServeFor); its clocks are Drive.OrderPatience (at the
-- window, before the order) and Drive.PrepBase + PrepPerK x K (after it).

-- DriveThruService (one): Try / Left hooks, nil = off.
function CustomerService:SetDriver(driver: Driver?)
	self.Driver = driver
end

-- The car reached its lane spot for the first time: the customer is in line (arrival counted, ticket drawn).
function CustomerService:JoinDrive(id: number)
	const customer = self.Customers[id]
	if customer == nil or customer.Drive == 0 or customer.State ~= "Arriving" then
		return
	end
	customer.State = "Queued"
	customer.JoinedAt = now()
	self:Publish(customer, false)
	self.Dependencies.EconomyService:CountArrival()
	self.Joined:Fire(id)
end

-- Lane spot of a car (DriveThruService moved it up). 1 = at the window.
function CustomerService:SetDriveSpot(id: number, spot: number)
	const customer = self.Customers[id]
	if customer == nil or customer.Drive == 0 or customer.Drive == spot then
		return
	end
	customer.Drive = spot
	self:Publish(customer, false)
end

-- The car stopped at the window: Ordering, and the Queue clock runs with Drive.OrderPatience; the Order clock that
-- follows the order is Drive.PrepBase + PrepPerK x K (+ the PatienceBonus upgrade). false = not a car at the window
-- in line, or no ticket.
function CustomerService:FrontDrive(id: number): boolean
	const customer = self.Customers[id]
	const ticket = self.Tickets[id]
	if customer == nil or ticket == nil or customer.Drive ~= 1 or customer.State ~= "Queued" then
		return false
	end
	const drive = Content.Restaurant.Drive
	const bonus = math.max(self.Dependencies.UpgradeService:GetEffect("PatienceBonus"), 0)
	ticket.QueueSpan = drive.OrderPatience + bonus
	ticket.OrderSpan = drive.PrepBase + drive.PrepPerK * ticket.K + bonus
	Orders.BeginQueue(ticket, now())
	customer.State = "Ordering"
	return self:Update(id, {
		PatienceEndsAt = ticket.PatienceEndsAt,
		Phase = "Queue",
		PatienceSpan = Orders.WireSpan(ticket),
	})
end

-- The customer in the car at the window (lane spot 1, not leaving), or nil.
function CustomerService:DriveFront(): number?
	for id, customer in self.Customers do
		if customer.Drive == 1 and customer.State ~= "Leaving" then
			return id
		end
	end
	return nil
end

-- Network ---------------------------------------------------------------------------------------------------------

function CustomerService:Record(customer: Customer): Wire
	return {
		State = customer.State,
		Slot = customer.Slot,
		Order = customer.Order,
		PatienceEndsAt = customer.PatienceEndsAt,
		Phase = customer.Phase,
		PatienceSpan = customer.PatienceSpan,
		Mood = customer.Mood,
		Order2 = customer.Order2,
		Leader = customer.Leader,
		Pickup = if customer.Pickup > 0 then customer.Pickup else nil,
		Number = customer.Number,
		Drive = if customer.Drive > 0 then customer.Drive else nil,
	}
end

function CustomerService:Publish(customer: Customer, added: boolean)
	if not self.Dependencies.NetService:IsRunning() then
		return
	end
	if added then
		self.Libs.Net.Customers:add(customer.Id, self:Record(customer))
	else
		-- A nil field is skipped by Lync's update (the old value would stay on the wire): clearing needs Lync.none.
		-- Order2 goes nil when one hot dog of a pair is resolved; without this the client kept the old Order2 next to
		-- the new Order = the remaining order drawn twice.
		const record = self:Record(customer) :: any
		if record.Order2 == nil then
			record.Order2 = Lync.none
		end
		if record.Leader == nil then
			record.Leader = Lync.none
		end
		if record.Pickup == nil then
			record.Pickup = Lync.none
		end
		if record.Number == nil then
			record.Number = Lync.none
		end
		if record.Drive == nil then
			record.Drive = Lync.none
		end
		self.Libs.Net.Customers:update(customer.Id, record)
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

-- Pickup line (TASK-380): sends everyone in it to the PU-k of their position (PU-1 = at the counter) and turns the
-- PICKUP prompt on while somebody waits. Called after every join and leave of the pickup line.
function CustomerService:RefreshPickup()
	const points = self:PickupPoints()
	const format = Content.Restaurant.Binding.PickupPoint
	for spot, id in self.PickupLine.Order do
		const customer = self.Customers[id]
		if customer == nil or customer.Pickup == spot then
			continue
		end
		customer.Pickup = spot
		self:Publish(customer, false)
		if points > 0 then
			-- AvoidQueue: the walk from Q1 never steps through the tablet queue slots
			self:Walk(customer, Pickup.point(math.min(spot, points), format), true, function() end)
		end
	end
	self:SetPickupPrompt(#self.PickupLine.Order > 0)
end

-- PICKUP Prompt_Serve anchors (Model tagged Binding.PickupTag) on or off.
function CustomerService:SetPickupPrompt(enabled: boolean)
	const binding = Content.Restaurant.Binding
	for _, model in CollectionService:GetTagged(binding.PickupTag) do
		if not model:IsDescendantOf(workspace) then
			continue
		end
		const anchor = model:FindFirstChild(binding.PickupPrompt, true)
		if anchor ~= nil and anchor:GetAttribute("PromptAction") == PICKUP_SERVE then
			self.Dependencies.InteractionService:SetPrompt(anchor, enabled)
		end
	end
end

-- The prompt anchor is the PICKUP's Prompt_Serve (inside a Model tagged Binding.PickupTag in the Workspace).
function CustomerService:IsPickupAnchor(anchor: Instance): boolean
	const binding = Content.Restaurant.Binding
	if anchor.Name ~= binding.PickupPrompt or not anchor:IsDescendantOf(workspace) then
		return false
	end
	local parent = anchor.Parent
	while parent ~= nil and parent ~= workspace do
		if CollectionService:HasTag(parent, binding.PickupTag) then
			return true
		end
		parent = parent.Parent
	end
	return false
end

-- The customer just had its order taken (pickup mode): out of the tablet queue (the queue moves up), to the back of the
-- pickup line; its rig keeps the "Serve" prompt (serve on a PU-n rig = ServeAtPickup). Actors and the tutorial customer
-- too (same flow); partners follow their leader (StepPairs).
function CustomerService:EnterPickup(customer: Customer)
	if customer.Leader ~= nil or customer.AtTable or customer.Pickup > 0 then
		return
	end
	customer.Slot = 0
	const wasQueued = Queue.leave(self.Line, customer.Id)
	Pickup.join(self.PickupLine, customer.Id)
	self:SetPrompts(customer.Id, true)
	self:RefreshPickup()
	if wasQueued then
		self:Refresh()
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
	if customer.Variant == nil and not customer.Tutorial then
		-- FEAT-014 denominator; skipped spawns never get here. Actors (DEC-051) and the tutorial customer are excluded
		self.Dependencies.EconomyService:CountArrival()
	end
	-- The partner joins with its leader: no slot of its own, but it counts as an arrival (a pair = 2, FEAT-038)
	const partner = if customer.Partner then self.Customers[customer.Partner] else nil
	if partner ~= nil and partner.State == "Arriving" then
		partner.State = "Queued"
		partner.JoinedAt = customer.JoinedAt
		self:Publish(partner, false)
		self.Dependencies.EconomyService:CountArrival()
	end
	self.Joined:Fire(customer.Id)
	self:Refresh()
end

-- Spawn -----------------------------------------------------------------------------------------------------------

-- One spawn attempt (FEAT-009). Returns the outcome; the NpcId too when it spawned (the leader of a pair).
-- FEAT-038: the attempt may bring a pair (Group.Roll); without room for 2 (customer cap, NPC cap) a lone customer
-- spawns and the attempt is still "spawned".
function CustomerService:Attempt(): (Outcome, number?)
	local outcome: Outcome = "spawned"
	local id: number? = nil
	self.LastWasPair = false
	const npc = self.Dependencies.NpcService
	-- TASK-574: a share of the attempts becomes a car at the drive-thru (DriveThruService draws it and checks its lanes);
	-- a car does not need a counter slot, only room in the customer and NPC caps
	const driver = self.Driver
	if driver ~= nil and self:Count() < self:MaxCustomers() and npc:Count() < npc:Capacity() then
		const ok, driven = pcall(driver.Try, self.Party)
		if not ok then
			self:WarnOnce("driver", `drive-thru spawn failed: {driven}`)
		elseif driven ~= nil then
			self.SpawnAttempted:Fire(outcome)
			return outcome, driven
		end
	end
	if Queue.isFull(self:Occupants(), self:QueueSize()) then
		outcome = "skipped_queue_full"
	elseif self:Count() >= self:MaxCustomers() or npc:Count() >= npc:Capacity() then
		outcome = "skipped_npc_cap"
	else
		local pair = self:RollPair()
		if pair ~= nil and (self:Count() + 2 > self:MaxCustomers() or npc:Count() + 2 > npc:Capacity()) then
			pair = nil -- no room for 2: one customer (FEAT-038)
		end
		if pair ~= nil then
			id = self:SpawnPair(pair)
		else
			id = Adopt.Spawn(self) or npc:Spawn({ Rng = self.Rng }) -- passer-by noticed (Adopt.luau, TASK-163)
			if id ~= nil then
				self:Create(id)
			end
		end
		if id == nil then
			-- Pool full, or no binding / no type unlocked (NpcService warns once): counted as the cap
			outcome = "skipped_npc_cap"
		end
	end
	self.SpawnAttempted:Fire(outcome)
	return outcome, id
end

-- Pair draw of this attempt (FEAT-038), or nil. Uses the shift Random; DevSpawnPair forces one.
function CustomerService:RollPair(): Group.Pair?
	const forced = self.ForcedPair
	if forced ~= nil then
		self.ForcedPair = nil
		return forced
	end
	const info = self.Dependencies.RoundService:Info()
	return Group.Roll(info.Day, info.Night, self:IsNightShift(), self.Rng)
end

-- Spawns a leader and its partner on the same spawn point. A partner that cannot spawn (no valid look, pool) leaves
-- the leader alone. Returns the leader's NpcId, or nil.
function CustomerService:SpawnPair(pair: Group.Pair): number?
	const npc = self.Dependencies.NpcService
	const id = npc:Spawn({ CustomerType = pair.Leader, Rng = self.Rng })
	if id == nil then
		return nil
	end
	self:Create(id)
	const leaderNpc = npc:Get(id)
	if leaderNpc == nil then
		return id
	end
	const look = Group.PartnerLook(pair.Partner, leaderNpc.Species, leaderNpc.Outfit, self:IsNightShift(), self.Rng)
	if look == nil then
		self:WarnOnce(`pairlook:{pair.Leader}+{pair.Partner}`, `no valid partner look for {pair.Leader}+{pair.Partner}`)
		return id
	end
	const partnerId = npc:Spawn({
		CustomerType = pair.Partner,
		Species = look.Species,
		Outfit = look.Outfit,
		From = npc:GetNode(id),
		Rng = self.Rng,
	})
	if partnerId == nil then
		return id
	end
	const leader = self.Customers[id]
	if leader == nil then
		npc:Despawn(partnerId)
		return id
	end
	-- Together: the leader walks at the slower pace, the partner a bit faster so it keeps up (FEAT-038)
	const types = Content.CustomerTypes.ByKey
	const pace = math.min(types[pair.Leader].WalkSpeed, types[pair.Partner].WalkSpeed)
	npc:SetWalkSpeed(id, pace)
	npc:SetWalkSpeed(partnerId, pace * Content.Flow.Groups.PartnerSpeedMult)
	leader.Partner = partnerId
	leader.Couple = pair.Couple
	self:Create(partnerId, nil, id)
	const partner = self.Customers[partnerId]
	if partner ~= nil then
		partner.Couple = pair.Couple
	end
	self.LastWasPair = true
	return id
end

-- New record. `leader` = this is the partner of that leader: no walk of its own (StepPairs moves it). `tutorial` =
-- the tutorial customer (RequestTutorial). `drive` = lane spot of a drive-thru car (TASK-574): no walk either, the car
-- is DriveThruService's (JoinDrive when it reaches its spot).
function CustomerService:Create(id: number, variant: Variant?, leader: number?, tutorial: boolean?, drive: number?)
	const customer: Customer = {
		Id = id,
		State = "Arriving",
		Slot = 0,
		Order = {},
		PatienceEndsAt = 0,
		Phase = "None",
		PatienceSpan = 0,
		Mood = NEUTRAL,
		SpawnedAt = now(),
		JoinedAt = 0,
		LeftAt = 0,
		Move = 0,
		Variant = variant,
		Order2 = nil,
		Partner = nil,
		Leader = leader,
		Couple = false,
		Held = false,
		FollowTarget = nil,
		FollowAt = 0,
		Faced = false,
		Dining = false,
		AtTable = false,
		Tutorial = tutorial == true,
		Model = nil,
		Pickup = 0,
		Number = nil,
		PausedAt = nil,
		CarryModel = nil,
		CarryLook = nil,
		Drive = drive or 0,
	}
	if customer.Tutorial then
		-- before the first replication of the record: the client knows it is the tutorial customer from the start
		const model = self.Dependencies.NpcService:GetModel(id)
		if model ~= nil then
			model:SetAttribute(TutorialRules.Attribute, true)
			customer.Model = model
		end
	end
	self.Customers[id] = customer
	self:SetPrompts(id, false)
	self:Publish(customer, true)
	if leader ~= nil or customer.Drive > 0 then
		return
	end
	-- Arrival routes end at Q5 and never cross the queue (AvoidQueue, MAP-01 §9.1)
	self:Walk(customer, Queue.entry(), true, function(ok: boolean)
		if ok then
			self:Join(customer)
		else
			self:Remove(id) -- no route (binding broken): nothing to queue
		end
	end)
end

-- Customer anomaly (TASK-108; architecture.md §19.13). Spawns now and walks to the queue like a customer. Needs a
-- selling phase, a free counter slot and room in the NPC cap; nil otherwise (the anomaly schedule retries later).
function CustomerService:SpawnActor(spec: CustomerActorSpec): number?
	if not self.Enabled or not self:IsSelling() or self:IsPaused() then
		return nil
	end
	const npc = self.Dependencies.NpcService
	if Queue.isFull(self:Occupants(), self:QueueSize()) or npc:Count() >= npc:Capacity() then
		return nil
	end
	local customerType = spec.CustomerType
	local species = spec.Species
	local outfit = spec.Outfit
	if spec.CopyOf ~= nil then
		if spec.Variant ~= MIRROR then
			warn(`[CustomerService] SpawnActor: CopyOf is for the mirror variant only ({spec.Variant})`)
			return nil
		end
		const original = self.Customers[spec.CopyOf]
		const source = npc:Get(spec.CopyOf)
		if
			original == nil
			or original.Variant ~= nil
			or original.Tutorial
			or original.State == "Leaving"
			or source == nil
		then
			return nil
		end
		customerType = source.CustomerType
		species = source.Species
		outfit = source.Outfit
	end
	const id = npc:Spawn({
		Role = "Actor",
		Variant = spec.Variant,
		CustomerType = customerType,
		Species = species,
		Outfit = outfit,
		From = spec.From,
		Rng = self.ActorRng,
	})
	if id == nil then
		return nil
	end
	self:Create(id, spec.Variant)
	return id
end

-- Registers a Serve override (architecture.md §19.13, T42). Returns the function that removes it.
function CustomerService:AddServeRule(rule: ServeRule): () -> ()
	table.insert(self.ServeRules, rule)
	return function()
		const index = table.find(self.ServeRules, rule)
		if index ~= nil then
			table.remove(self.ServeRules, index)
		end
	end
end

-- First non-nil result of the Serve rules, or nil. A rule that errors is skipped (warned).
function CustomerService:ServeOverride(customer: Customer, tool: Tool, player: Player): SaleResult?
	if customer.Tutorial then
		return nil -- no anomaly rule on the tutorial customer
	end
	for _, rule in table.clone(self.ServeRules) do
		const ok, result = pcall(rule, customer, tool, player)
		if not ok then
			warn(`[CustomerService] serve rule failed: {result}`)
		elseif result ~= nil then
			return result
		end
	end
	return nil
end

-- Leave / remove --------------------------------------------------------------------------------------------------

function CustomerService:SetPrompts(id: number, enabled: boolean)
	const customer = self.Customers[id]
	if customer ~= nil and customer.Drive > 0 then
		enabled = false -- TASK-574: the driver's rig is hidden; the drive-thru is served at DT-PC / DT-WIN
	end
	const customerAnchor = self.Dependencies.NpcService:Anchors(id)
	if customerAnchor ~= nil then
		self.Dependencies.InteractionService:SetPrompt(customerAnchor, enabled)
	end
end

-- Exit for a customer standing on `node`. From Q2..Q5 the route must go along the queue (Q nodes as steps);
-- from Q1 or the street, never through it. Falls back to the other exit when the drawn one has no route.
function CustomerService:ExitRoute(node: string): (string?, boolean)
	const slot = Queue.slotOfNode(node)
	const avoidQueue = slot == nil or slot == 1
	const exits = Content.Flow.Spawns.Exits
	const list: { Weighted } = if self:IsNightShift() then exits.Night else exits.Day
	const first = pick(list, self.Rng)
	if hasPath(node, first, avoidQueue) then
		return first, avoidQueue
	end
	for _, entry in list do
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
-- moves up. `mood` = new Content.Moods key (optional). false = unknown id or already leaving. A partner goes with
-- its leader (a call on the partner is a call on the leader). `dining` = SeatingService took the party (SetSeater):
-- no exit walk until Dismiss.
function CustomerService:Leave(id: number, mood: string?, reason: LeaveReason?, dining: boolean?): boolean
	local customer = self.Customers[id]
	if customer ~= nil and customer.Leader ~= nil and self.Customers[customer.Leader] ~= nil then
		id = customer.Leader
		customer = self.Customers[id]
	end
	if customer == nil or customer.State == "Leaving" then
		return false
	end
	if mood ~= nil and Content.Moods.ByKey[mood] == nil then
		warn(`[CustomerService] Leave: unknown mood {mood}`)
		mood = nil
	end
	const wasQueued = Queue.leave(self.Line, id)
	const wasPicking = Pickup.leave(self.PickupLine, id)
	const members: { Customer } = { customer }
	const partner = if customer.Partner then self.Customers[customer.Partner] else nil
	if partner ~= nil then
		table.insert(members, partner)
	end
	-- Q-209: a customer at a table is SeatingService's until Dismiss; `dining` = it ate (served well), else it just stands up
	const atTable = customer.AtTable
	const ate = atTable and dining == true
	if atTable then
		dining = true
	end
	for _, member in members do
		member.State = "Leaving"
		member.Slot = 0
		member.LeftAt = now()
		member.Dining = dining == true
		member.Pickup = 0
		member.Number = nil -- the #n over the head goes with the plate (FEAT-043)
		member.PausedAt = nil
		if mood ~= nil then
			member.Mood = mood
		end
		self:SetPrompts(member.Id, false)
		self:Publish(member, false)
	end
	self.Left:Fire(id, reason or "service")
	if partner ~= nil then
		self.Left:Fire(partner.Id, reason or "service")
	end
	if wasQueued then
		self:Refresh()
	end
	if wasPicking then
		self:RefreshPickup()
	end
	if customer.Drive > 0 then
		-- TASK-574: the car drives off; DriveThruService removes the record when it is gone
		const driver = self.Driver
		if driver ~= nil then
			const ok, err = pcall(driver.Left, id)
			if not ok then
				warn(`[CustomerService] driver Left failed: {err}`)
			end
		end
		return true
	end
	if atTable then
		const seater = self.Seater
		if seater ~= nil then
			const ok, err = pcall(seater.Left, id, ate)
			if not ok then
				warn(`[CustomerService] seater Left failed: {err}`)
			end
		end
		return true -- SeatingService walks the party now (Dismiss)
	end
	if dining then
		return true -- SeatingService walks the party now (Dismiss)
	end
	self:WalkOut(customer)
	return true
end

-- Exit walk from the node the NPC stands on; removed at the exit (the partner with its leader).
function CustomerService:WalkOut(customer: Customer)
	const id = customer.Id
	const node = self.Dependencies.NpcService:GetNode(id)
	const exit, avoidQueue = self:ExitRoute(node or "")
	if exit == nil then
		self:Remove(id)
		return
	end
	self:Walk(customer, exit, avoidQueue, function()
		self:Remove(id)
	end)
end

-- SeatingService is done with a diner party (stood up, or the table walk failed): the exit walk starts from the node
-- the leader stands on (SeatingService puts it back on the graph first). false = not a diner.
function CustomerService:Dismiss(id: number): boolean
	const customer = self.Customers[id]
	if customer == nil or not customer.Dining then
		return false
	end
	const t = now()
	customer.Dining = false
	customer.AtTable = false
	customer.LeftAt = t
	const partner = if customer.Partner then self.Customers[customer.Partner] else nil
	if partner ~= nil then
		partner.Dining = false
		partner.AtTable = false
		partner.Held = false
		partner.LeftAt = t
	end
	self:WalkOut(customer)
	return true
end

-- Partner moved by SeatingService (walk to the seat, sitting): StepPairs leaves it alone while held.
function CustomerService:SetHeld(id: number, held: boolean)
	const customer = self.Customers[id]
	if customer ~= nil then
		customer.Held = held
		customer.FollowTarget = nil
	end
end

-- Drops the record and returns the NPC to the pool. Safe to call twice.
function CustomerService:Remove(id: number)
	if not self:Forget(id) then
		return
	end
	self.Dependencies.NpcService:Despawn(id)
end

-- Record gone (set removed, queue moved up); the NPC is the caller's business. false = unknown id. A leader takes
-- its partner along (record and NPC); a partner gone alone just unlinks from its leader.
function CustomerService:Forget(id: number): boolean
	const customer = self.Customers[id]
	if customer == nil then
		return false
	end
	customer.Move += 1
	self.Customers[id] = nil
	const model = customer.Model
	if model ~= nil then
		-- the rig goes back to the pool: the next customer on it is not the tutorial one
		model:SetAttribute(TutorialRules.Attribute, nil)
		customer.Model = nil
	end
	const carried = customer.CarryModel
	if carried ~= nil then
		-- the rig goes back to the pool empty-handed (TASK-380)
		carried:SetAttribute(CARRYING, nil)
		for _, attribute in { CARRY_LOOK.Toppings, CARRY_LOOK.Sauce, CARRY_LOOK.Altered, CARRY_LOOK.Dish } do
			carried:SetAttribute(attribute, nil)
		end
		customer.CarryModel = nil
	end
	const wasPicking = Pickup.leave(self.PickupLine, id)
	const wasQueued = Queue.leave(self.Line, id)
	if self.Dependencies.NetService:IsRunning() then
		self.Libs.Net.Customers:remove(id)
	end
	self.Removed:Fire(id)
	if customer.Leader ~= nil then
		const leader = self.Customers[customer.Leader]
		if leader ~= nil and leader.Partner == id then
			leader.Partner = nil
		end
	end
	if customer.Partner ~= nil and self.Customers[customer.Partner] ~= nil then
		self:Remove(customer.Partner)
	end
	if wasQueued then
		self:Refresh()
	end
	if wasPicking then
		self:RefreshPickup()
	end
	return true
end

-- Every customer away now (shift end): they walk off instead of vanishing. Partners go with their leader; diners
-- are SeatingService's (it stands them up on the phase change).
function CustomerService:SendAllAway()
	const ids: { number } = {}
	for id, customer in self.Customers do
		if customer.State ~= "Leaving" and customer.Leader == nil then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	for _, id in ids do
		self:Leave(id, nil, "shift_end")
	end
end

-- The service window shut (TASK-284, owner request 2026-10-14; Content.ShopWindow, Provisional Q-270): everyone in line,
-- ordering or waiting for food walks off angry (ShopWindow.LeaveMood). Each pending hot dog is settled as
-- ShopWindow.LeaveResult (Refused: $0, same ledger and stats as a refusal; Acted "refuse" with the player who closed,
-- nil = automatic). Still walking to the line (no ticket yet): leaves angry, no outcome. Stay: the tutorial customer,
-- anomaly actors (their module decides) and diners whose food came.
function CustomerService:SendLineAway(player: Player?)
	const rules = Content.ShopWindow
	const result = rules.LeaveResult :: SaleResult
	const ids: { number } = {}
	for id, customer in self.Customers do
		if customer.State == "Leaving" or customer.Leader ~= nil or customer.Variant ~= nil or customer.Tutorial then
			continue
		end
		const ticket = self.Tickets[id]
		if ticket ~= nil and #Orders.Pending(ticket) == 0 then
			continue
		end
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		const customer = self.Customers[id]
		if customer == nil or customer.State == "Leaving" then
			continue
		end
		const ticket = self.Tickets[id]
		if ticket ~= nil then
			self:SettlePending(customer, ticket, result)
			self.Acted:Fire(id, REFUSE, player, result)
		end
		self:Leave(id, rules.LeaveMood)
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
	Pickup.clear(self.PickupLine)
	self:SetPickupPrompt(false)
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
	const span = patch.PatienceSpan
	if span ~= nil and (span ~= span or span < 0 or span > Content.OrderRules.WireSpanMax) then
		warn("[CustomerService] Update: PatienceSpan must be 0..WireSpanMax")
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
	if patch.Phase ~= nil then
		customer.Phase = patch.Phase
	end
	if span ~= nil then
		customer.PatienceSpan = math.floor(span)
	end
	if patch.Mood ~= nil then
		customer.Mood = patch.Mood
		-- the partner wears its leader's mood (FEAT-038)
		const partner = if customer.Partner then self.Customers[customer.Partner] else nil
		if partner ~= nil and partner.State ~= "Leaving" and partner.Mood ~= patch.Mood then
			partner.Mood = patch.Mood
			self:Publish(partner, false)
		end
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
	if customer.Tutorial then
		-- fixed order, patience that never runs out (no draw: the seeded order stream stays the same)
		const ticket = Orders.Ticket({ table.clone(TutorialRules.Order) }, now(), 0, 0, nil)
		ticket.PatienceEndsAt = math.huge
		self.Tickets[id] = ticket
		return
	end
	const round = self.Dependencies.RoundService
	local lines = { Orders.Roll(round:GetDay(), npc.CustomerType, self.OrderRng, round:IsNight()) }
	const bonus = self.Dependencies.UpgradeService:GetEffect("PatienceBonus")
	local pairBonus = 0
	-- Pair (FEAT-038): the partner's hot dog is drawn apart with its own type; Order clock by K1 + K2 + pair bonus
	const partner = if customer.Partner then self.Dependencies.NpcService:Get(customer.Partner) else nil
	if partner ~= nil then
		table.insert(lines, Orders.Roll(round:GetDay(), partner.CustomerType, self.OrderRng, round:IsNight()))
		const forced = self.ForcedOrders
		if forced ~= nil then
			-- dev (`/dev customer pair`): known orders for both hot dogs; the draws above still ran (stream unchanged)
			self.ForcedOrders = nil
			lines = { table.clone(forced[1]), table.clone(forced[2]) }
		end
		pairBonus = Content.Flow.Groups.PatienceBonus
	end
	const arrivedAt = if customer.JoinedAt > 0 then customer.JoinedAt else now()
	const typeRow = Content.CustomerTypes.ByKey[npc.CustomerType]
	self.Tickets[id] = Orders.Ticket(lines, arrivedAt, bonus, pairBonus, if typeRow then typeRow.PatienceMult else nil)
end

-- NpcId that owns line `index` of a leader's ticket: line 2 = the partner (while alive), else the leader.
function CustomerService:LineOwner(customer: Customer, index: number): number
	if index == 2 and customer.Partner ~= nil and self.Customers[customer.Partner] ~= nil then
		return customer.Partner
	end
	return customer.Id
end

-- Wire order of the pending lines: Order = 1st pending, Order2 = 2nd pending (nil = none).
function CustomerService:ShowPending(customer: Customer, ticket: Orders.Ticket)
	const pending = Orders.Pending(ticket)
	customer.Order = if pending[1] then Orders.Set(ticket.Lines[pending[1]].Toppings) else {}
	customer.Order2 = if pending[2] then Orders.Set(ticket.Lines[pending[2]].Toppings) else nil
end

-- Reached Q1: "Take Order" comes on (the client still hides them by state, network.md §3.6). The Queue
-- patience clock starts here (Q-192); the tutorial customer has no clock.
function CustomerService:OnFronted(id: number)
	const queued = self.Customers[id]
	const queuedTicket = self.Tickets[id]
	if queued ~= nil and queuedTicket ~= nil and not queued.Tutorial then
		Orders.BeginQueue(queuedTicket, now())
		self:Update(id, {
			PatienceEndsAt = queuedTicket.PatienceEndsAt,
			Phase = "Queue",
			PatienceSpan = Orders.WireSpan(queuedTicket),
		})
	end
	const customerAnchor = self.Dependencies.NpcService:Anchors(id)
	if customerAnchor ~= nil then
		customerAnchor:SetAttribute("PromptAction", TAKE_ORDER)
	end
	-- TAB-1 in the map (TASK-380): the order is taken at the tablet, the rig shows no "Take Order"
	self:SetPrompts(id, not self:IsTabletMode())
end

-- TabletService (TASK-381): freezes (on = true) or resumes the running patience clock of a customer during the talk at
-- the tablet. While frozen nothing times it out and it does not turn Annoyed; resuming moves the deadline by the time it
-- was frozen (one set write). "Take Order" clears a freeze. false = unknown customer, no clock running, already in that
-- state, or leaving.
function CustomerService:PausePatience(id: number, on: boolean): boolean
	const customer = self.Customers[id]
	const ticket = self.Tickets[id]
	if customer == nil or ticket == nil or customer.State == "Leaving" or customer.Tutorial or ticket.Phase == "None" then
		return false
	end
	if on then
		if customer.PausedAt ~= nil then
			return false
		end
		customer.PausedAt = now()
		return true
	end
	const since = customer.PausedAt
	if since == nil then
		return false
	end
	customer.PausedAt = nil
	-- the whole phase moves: same span on the wire, same Annoyed fraction
	const frozen = math.max(now() - since, 0)
	ticket.PhaseStartedAt += frozen
	ticket.PatienceEndsAt += frozen
	return self:Update(id, { PatienceEndsAt = ticket.PatienceEndsAt })
end

-- The patience clock of `id` is frozen (PausePatience).
function CustomerService:IsPatiencePaused(id: number): boolean
	const customer = self.Customers[id]
	return customer ~= nil and customer.PausedAt ~= nil
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
	const id = self:TicketAt(anchor)
	return self:CanActOn(player, id, state)
end

-- Same gate by NpcId (the prep mode tabs have no anchor): ticket open, customer not leaving and on Q1.
function CustomerService:CanActOn(player: Player, id: number?, state: State?): boolean
	if id == nil or not self.Dependencies.RunStateService:IsActive(player) then
		return false
	end
	const customer = self.Customers[id]
	if customer == nil or self.Tickets[id] == nil or customer.State == "Leaving" then
		return false
	end
	-- on Q1, or (TASK-380) anywhere in the pickup line: every #n there can be served
	const inPickup = customer.Pickup > 0 and Pickup.spotOf(self.PickupLine, id) ~= nil
	-- (TASK-574) or the car at the drive-thru window
	const atWindow = customer.Drive == 1
	if not inPickup and not atWindow and (self:Front() ~= id or customer.Slot ~= 1) then
		return false
	end
	-- the tutorial customer's order can be taken before the shop opens (Prep); serving it still needs the drawer
	const early = customer.Tutorial and state == "Ordering"
	if not early and not self.Dependencies.EconomyService:IsDrawerOpen() then
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
-- Actors stay out of the ledger (DEC-051): their module counts a failure itself.
function CustomerService:Settle(id: number, result: SaleResult, amount: number)
	const customer = self.Customers[id]
	if customer == nil or (customer.Variant == nil and not customer.Tutorial) then
		self.Dependencies.EconomyService:CountResult(result)
	end
	const net = self.Dependencies.NetService
	if net:IsRunning() then
		self.Libs.Net.Sale:fireClient(net.Audience, {
			Npc = id,
			Result = result,
			Amount = math.clamp(math.floor(amount), 0, SALE_MAX),
		})
	end
end

-- "Take Order" (FEAT-011): order, real patience and Waiting in one write (T41); tip window of the taker. A pair
-- shows both hot dogs (Order + Order2); the tip window runs on K1 + K2 (FEAT-038).
function CustomerService:TakeOrder(player: Player, anchor: Instance)
	const id, customer, ticket = self:TicketAt(anchor)
	if id == nil or customer == nil or ticket == nil then
		return
	end
	if self:RefusePickupFull(player, customer) then
		return
	end
	self:OpenOrder(player, id, customer, ticket)
end

-- Pickup mode (TASK-380): no free spot in the pickup line = the order is not taken, the player gets pickup_full and the
-- customer stays at the tablet (its Queue clock keeps running). The tutorial customer is never refused. true = refused.
function CustomerService:RefusePickupFull(player: Player, customer: Customer): boolean
	if customer.Tutorial or customer.Drive > 0 or not self:IsPickupFull() then
		return false
	end
	self:NotifyThrottled(player, PICKUP_FULL)
	return true
end

-- "Take Order" from the prep mode Order tab (PrepService; prep-mode.md §2) and from the tablet at the end of the talk
-- (TabletService, TASK-381): the customer at the counter in Ordering (`id` nil = the one on Q1), same gate and same write
-- as the world prompt. Pickup mode: refused with pickup_full when the pickup line is full; taken = #n, out of Q1, to the
-- back of the pickup line. Returns true when the order was taken.
function CustomerService:TakeOrderFor(player: Player, id: number?): boolean
	const target = if id ~= nil then id else self:Front()
	if target == nil or not self:CanActOn(player, target, "Ordering") then
		return false
	end
	const customer = self.Customers[target]
	const ticket = self.Tickets[target]
	if customer == nil or ticket == nil then
		return false
	end
	if self:RefusePickupFull(player, customer) then
		return false
	end
	self:OpenOrder(player, target, customer, ticket)
	return customer.State == "Waiting"
end

function CustomerService:OpenOrder(player: Player, id: number, customer: Customer, ticket: Orders.Ticket)
	const class = self.Dependencies.ClassService
	const at = now()
	ticket.Taker = player
	ticket.TakenAt = at
	ticket.TipEndsAt = at + Orders.TipWindow(ticket.K, class:GetModifier(player, "TipWindow"))
	ticket.TipAmount = class:GetModifier(player, "TipAmount")
	-- the Queue clock ends, the Order clock starts (Q-192); the tutorial customer keeps no clock
	if not customer.Tutorial then
		Orders.BeginOrder(ticket, at)
	end
	const second = ticket.Lines[2]
	customer.Order2 = if second then Orders.Set(second.Toppings) else nil
	customer.PausedAt = nil -- the talk is over: the Order clock starts fresh
	-- pickup mode (TASK-380): the #n goes out in the same write (FEAT-043, 1..OrderNumberMax per shift, wraps)
	const pickup = self:IsPickupMode() and customer.Leader == nil
	if pickup then
		self.OrderNumber = self.OrderNumber % math.clamp(Content.Restaurant.Rules.OrderNumberMax, 1, NUMBER_MAX) + 1
		customer.Number = self.OrderNumber
	end
	const written = self:Update(id, {
		State = "Waiting",
		Order = Orders.Set(ticket.Lines[1].Toppings),
		-- the tutorial customer has no time limit: no ring on the wire
		PatienceEndsAt = if customer.Tutorial then 0 else ticket.PatienceEndsAt,
		Phase = if customer.Tutorial then "None" else "Order",
		PatienceSpan = if customer.Tutorial then 0 else Orders.WireSpan(ticket),
		Mood = if customer.Tutorial then nil else NEUTRAL, -- the queue's annoyance does not carry over
	})
	if not written then
		return
	end
	const customerAnchor = self.Dependencies.NpcService:Anchors(id)
	if customerAnchor ~= nil then
		customerAnchor:SetAttribute("PromptAction", SERVE)
	end
	if self:IsTabletMode() then
		self:SetPrompts(id, true) -- the rig had no "Take Order" prompt (TASK-380); "Serve" comes on now
	end
	if not customer.Tutorial then
		self.Acted:Fire(id, TAKE_ORDER, player, nil)
	end
	if self.Customers[id] == customer and customer.State == "Waiting" and customer.Drive == 0 then
		-- a car (TASK-574) waits at the window: no pickup line, no table
		if pickup then
			-- TASK-380: to the pickup line; it sits (if at all) after the sale
			self:EnterPickup(customer)
		else
			-- Q-209: a free table of the active vehicle takes the customer now; the food is served there
			self:SeatAtOrder(customer)
		end
	end
	if self.Customers[id] == customer and customer.State == "Waiting" then
		self.Ordered:Fire(id, player)
	end
end

-- Asks SeatingService for a table (Seater.Offer). Taken: the customer (and its partner) leaves the counter queue, its
-- prompts go off (the table has the "Serve" prompt) and the queue moves up. Actors, the tutorial customer and partners
-- never sit.
function CustomerService:SeatAtOrder(customer: Customer)
	if customer.Variant ~= nil or customer.Tutorial or customer.Leader ~= nil or customer.AtTable then
		return
	end
	if not self:OfferSeat(customer) then
		return
	end
	const partner = if customer.Partner then self.Customers[customer.Partner] else nil
	customer.AtTable = true
	customer.Move += 1 -- the queue walk of the counter no longer applies
	if partner ~= nil then
		partner.AtTable = true
		partner.Move += 1
	end
	customer.Slot = 0
	const wasQueued = Queue.leave(self.Line, customer.Id)
	self:SetPrompts(customer.Id, false)
	self:Publish(customer, false)
	if wasQueued then
		self:Refresh()
	end
end

-- Hot dogs a customer at a table still waits for, one topping-key list per pending line (display order). Empty = none.
function CustomerService:PendingToppings(id: number): { { string } }
	const out: { { string } } = {}
	const ticket = self.Tickets[id]
	if ticket ~= nil then
		for _, index in Orders.Pending(ticket) do
			table.insert(out, table.clone(ticket.Lines[index].Toppings))
		end
	end
	return out
end

-- The customer is at its table (or on the way), waiting for its food, and can be served there.
function CustomerService:IsWaitingAtTable(id: number): boolean
	const customer = self.Customers[id]
	const ticket = self.Tickets[id]
	return customer ~= nil
		and ticket ~= nil
		and customer.AtTable
		and customer.State == "Waiting"
		and ticket.TakenAt > 0
		and #Orders.Pending(ticket) > 0
end

-- "Serve" (FEAT-011, DEC-072): validates the held hot dog against the order and pays into the drawer. A pair
-- (FEAT-038): the hot dog answers one pending line (Orders.Match), paid and settled per line; the pair stays until
-- no line is pending. Both hands (FEAT-038, DEC-071 hotbar of 2): when the held hot dog is exact (Complete) for one
-- line and ANOTHER hot dog of the hotbar is exact for the other pending line, one interaction takes both: each line
-- is paid, tipped and settled on its own (same rules as two serves), the patience clock of the Order phase covers both.
function CustomerService:Serve(player: Player, anchor: Instance)
	const id, customer, ticket = self:TicketAt(anchor)
	if id == nil or customer == nil or ticket == nil then
		return
	end
	if customer.Pickup > 0 then
		-- TASK-380: serve on a PU-n rig (or the drag of DeliveryController) = hand-over at the pickup, this rig as target
		self:ServeAtPickup(player, id)
		return
	end
	self:ServeCustomer(player, id, customer, ticket)
end

-- Hand-over at the pickup (TASK-380; tech §3.1; FEAT-046): pickup_serve on the PICKUP prompt (`target` nil) or serve on
-- the rig of a PU-n customer (`target` = that leader). The hot dog is the one in the hand, else the first hot dog of the
-- hotbar (equipped); none = hint. The customer is chosen by Pickup.choose: the plate's Ticket (Tool attribute, NpcId)
-- if the hot dog is exact for it, else the oldest one it is exact for, else the ticket owner, else the target, else PU-1.
-- Verdict, pay, tip, quality, Sale, Acted and the pair's second hand are ServeCustomer's (DEC-072: Wrong = $0, the hot dog
-- stays in the hand, the customer leaves). Returns the SaleResult of the first line served and the NpcId; nil = nothing
-- served (pickup mode off, not an active member, drawer closed, nobody waiting, no hot dog).
function CustomerService:ServeAtPickup(player: Player, target: number?): (SaleResult?, number?)
	if not self:IsPickupMode() or not self.Dependencies.RunStateService:IsActive(player) then
		return nil, nil
	end
	if not self.Dependencies.EconomyService:IsDrawerOpen() then
		return nil, nil
	end
	if #self.PickupLine.Order == 0 then
		return nil, nil
	end
	const items = self.Dependencies.ItemService
	local tool = items:Holding(player, HOT_DOG)
	if tool == nil then
		for _, candidate in items:Tools(player) do
			if items:ItemOf(candidate) == HOT_DOG then
				tool = candidate
				break
			end
		end
		if tool == nil then
			self:NotifyThrottled(player, SERVE_EMPTY_HINT)
			return nil, nil
		end
		self:Equip(player, tool)
	end
	const served = tool :: Tool
	const toppings = items:Toppings(served)
	const id = Pickup.choose(self.PickupLine, self:TicketOwner(served), target, function(candidate: number): Pickup.Fit
		const ticket = self.Tickets[candidate]
		if ticket == nil then
			return "Other"
		end
		const _, verdict = Orders.Match(ticket, toppings)
		return if verdict == "Complete" then "Exact" else "Other"
	end)
	if id == nil then
		return nil, nil
	end
	const customer = self.Customers[id]
	const ticket = self.Tickets[id]
	if
		customer == nil
		or ticket == nil
		or customer.State ~= "Waiting"
		or ticket.TakenAt <= 0
		or #Orders.Pending(ticket) == 0
	then
		return nil, nil
	end
	return self:ServeCustomer(player, id, customer, ticket, served), id
end

-- Leader NpcId of the plate's order on a hot dog Tool (attribute Ticket, PlateService), nil = none / unknown customer.
function CustomerService:TicketOwner(tool: Tool): number?
	const value = tool:GetAttribute(TICKET)
	if typeof(value) ~= "number" then
		return nil
	end
	const customer = self.Customers[value]
	if customer == nil then
		return nil
	end
	if customer.Leader ~= nil and self.Customers[customer.Leader] ~= nil then
		return customer.Leader
	end
	return value
end

-- "Serve" at the table (serve_table, SeatingService anchor; Q-209): same check, pay, tip and Sale as the counter; the
-- customer is `id` (the leader of a pair). false = nothing to serve (not at a table, drawer closed). The hand is not
-- checked: ServeCustomer uses the exact hot dog of the hotbar, or sends a hint.
function CustomerService:CanServeTable(player: Player, id: number): boolean
	return self.Dependencies.RunStateService:IsActive(player)
		and self.Dependencies.EconomyService:IsDrawerOpen()
		and self:IsWaitingAtTable(id)
end

function CustomerService:ServeTable(player: Player, id: number)
	const customer = self.Customers[id]
	const ticket = self.Tickets[id]
	if customer == nil or ticket == nil or not self:IsWaitingAtTable(id) then
		return
	end
	self:ServeCustomer(player, id, customer, ticket, nil)
end

-- "Serve" from the prep mode Serve tab (PrepService; prep-mode.md §2): `target` = NpcId of the customer at the counter
-- (Waiting, on Q1) or at a table (its leader's id; a partner id is mapped to its leader). `tool` = the hot dog the player
-- picked (must be a hot dog of theirs in play); nil = ServeCustomer picks the exact one of the hotbar (PickServeTool).
-- Same verdict, pay, tip, quality effect and Sale as the world "Serve" / "Serve Table". Returns the SaleResult of the
-- first line served, nil = nothing served.
function CustomerService:ServeFor(player: Player, tool: Tool?, target: number): SaleResult?
	local id = target
	const named = self.Customers[id]
	if named ~= nil and named.Leader ~= nil and self.Customers[named.Leader] ~= nil then
		id = named.Leader
	end
	const customer = self.Customers[id]
	const ticket = self.Tickets[id]
	if customer == nil or ticket == nil then
		return nil
	end
	if customer.AtTable then
		if not self:CanServeTable(player, id) then
			return nil
		end
	elseif not self:CanActOn(player, id, "Waiting") or ticket.TakenAt <= 0 then
		return nil
	end
	if tool ~= nil then
		const items = self.Dependencies.ItemService
		if items:ItemOf(tool) ~= HOT_DOG or not table.find(items:Tools(player), tool) then
			return nil
		end
	end
	return self:ServeCustomer(player, id, customer, ticket, tool)
end

-- `picked` = the hot dog chosen by the caller (ServeFor), nil = the one PickServeTool finds. Returns the first line's result.
function CustomerService:ServeCustomer(
	player: Player,
	id: number,
	customer: Customer,
	ticket: Orders.Ticket,
	picked: Tool?
): SaleResult?
	const tool = if picked ~= nil then picked else self:PickServeTool(player, ticket)
	if tool == nil then
		return nil
	end
	const at = now()
	-- AddServeRule (TASK-108): an override replaces the order check (on the first pending line)
	const override = self:ServeOverride(customer, tool, player)
	if self.Customers[id] ~= customer or customer.State == "Leaving" then
		return nil -- a rule sent the customer away
	end
	const index, verdict = self:Judge(ticket, tool, override)
	if index == nil then
		return nil
	end
	const first = self:SellLine(id, customer, ticket, player, tool, index, verdict, at)
	if override == nil and (first == "Complete" or first == "Perfect") then
		-- the other hot dog of the hotbar, exact for the line still pending
		const rest = Orders.Pending(ticket)
		const other = if override == nil and #rest == 1 then self:OtherHotDog(player, tool, ticket.Lines[rest[1]].Toppings) else nil
		if other ~= nil then
			self:SellLine(id, customer, ticket, player, other, rest[1], "Complete", at)
		end
	end
	if #Orders.Pending(ticket) > 0 then
		self:ShowPending(customer, ticket) -- pair: the other hot dog is still on the balloon
		self:Publish(customer, false)
		return first
	end
	self:Conclude(customer, ticket)
	return first
end

-- Another hot dog Tool of the player's inventory (not `except`) that is EXACT (Complete) for `order`, nil when none.
function CustomerService:OtherHotDog(player: Player, except: Tool, order: { string }): Tool?
	const items = self.Dependencies.ItemService
	for _, candidate in items:Tools(player) do
		if
			candidate ~= except
			and items:ItemOf(candidate) == HOT_DOG
			and Orders.Evaluate(order, items:Toppings(candidate)) == "Complete"
		then
			return candidate
		end
	end
	return nil
end

-- Hot dog a Serve uses (owner request 2026-10-12). Server-authoritative:
--   1. the hand holds a hot dog that is exact for a pending line -> it;
--   2. else an inventory hot dog (hotbar / backpack) that is exact for a pending line -> equipped and used (auto);
--   3. else a hot dog in hand (wrong / incomplete) -> it, with the existing Errado / Incompleto consequence;
--   4. else nothing is served and the player gets a hint (hold a hot dog / nothing to serve yet).
function CustomerService:PickServeTool(player: Player, ticket: Orders.Ticket): Tool?
	const items = self.Dependencies.ItemService
	const held = items:Holding(player, HOT_DOG)
	const pending = Orders.Pending(ticket)
	local function exact(tool: Tool): boolean
		const toppings = items:Toppings(tool)
		for _, index in pending do
			if Orders.Evaluate(ticket.Lines[index].Toppings, toppings) == "Complete" then
				return true
			end
		end
		return false
	end
	if held ~= nil and exact(held) then
		return held
	end
	local anyHotDog = held ~= nil
	for _, candidate in items:Tools(player) do
		if candidate ~= held and items:ItemOf(candidate) == HOT_DOG then
			anyHotDog = true
			if exact(candidate) then
				self:Equip(player, candidate)
				return candidate
			end
		end
	end
	if held ~= nil then
		return held
	end
	self:NotifyThrottled(player, if anyHotDog then SERVE_HOLD_HINT else SERVE_EMPTY_HINT)
	return nil
end

-- Puts a backpack Tool in the player's hand (the server's Humanoid:EquipTool replaces the Tool held now).
function CustomerService:Equip(player: Player, tool: Tool)
	const character = player.Character
	const humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid ~= nil and humanoid.Health > 0 then
		humanoid:EquipTool(tool)
	end
end

-- Pays one served hot dog against line `index` of the ticket: consumes it (not on Wrong: it stays in the hand),
-- price straight into Cash (DEC-238) + tip into the tip jar (DEC-239), line result, Sale packet and Acted. Returns the
-- SaleResult of the line.
function CustomerService:SellLine(
	id: number,
	customer: Customer,
	ticket: Orders.Ticket,
	player: Player,
	tool: Tool,
	index: number,
	verdict: Orders.Verdict,
	at: number
): SaleResult
	const items = self.Dependencies.ItemService
	const economy = self.Dependencies.EconomyService
	const line = ticket.Lines[index]
	local result: SaleResult = verdict
	local amount = 0
	if verdict ~= "Wrong" then
		-- Grade (TASK-569; kitchen-world.md §4): read before the Tool goes away. Only tip and mood, never the price (Q-219 B)
		const band = self:GradeOf(tool, line, ticket, at)
		const effect = Grade.SaleEffect(Content.Prep, band :: any)
		-- Incomplete does not look at the grade (FEAT-045 rev. 3, DEC-072)
		line.Mood = if effect ~= nil and verdict == "Complete" then effect.Mood else nil
		self:KeepLook(customer, index, tool)
		-- Wrong: $0; the hot dog stays in the server's hand (FEAT-011 "Errado devolvido")
		items:Consume(player, tool)
		amount += economy:AddSale(Orders.Pay(verdict, line.Price), "Sale")
		if verdict == "Complete" then
			const tip = Orders.TipFor(ticket, at, effect)
			if tip > 0 then
				amount += economy:AddTip(tip)
				result = "Perfect"
			end
		end
	end
	line.Result = result
	self:Settle(self:LineOwner(customer, index), result, amount)
	if not customer.Tutorial then
		self.Acted:Fire(id, SERVE, player, result)
	end
	return result
end

-- The look of the served hot dog (owner 2026-10-19): kept on the line's owner, read before the Tool is consumed, so the rig
-- carries THE hot dog the player made (toppings, drawn sauce, dish) and not a generic one.
function CustomerService:KeepLook(customer: Customer, index: number, tool: Tool)
	const owner = self.Customers[self:LineOwner(customer, index)]
	if owner == nil then
		return
	end
	const toppings = tool:GetAttribute("Toppings")
	const sauce = tool:GetAttribute("Sauce")
	owner.CarryLook = {
		Toppings = if type(toppings) == "string" then toppings else "", -- "" = plain (the client still knows it was served)
		Sauce = if type(sauce) == "string" then sauce else nil,
		Altered = tool:GetAttribute("Altered") == true,
		Dish = tool:FindFirstChild("Dish") ~= nil,
	}
end

-- Band of a served hot dog (kitchen-world.md §4): a plate's hot dog (PlateId) by Grade.Assembly against the line, from the time
-- the order was taken (the ticket's TakenAt) to `at`, with the party size; any other hot dog = its Quality attribute (nil = none).
function CustomerService:GradeOf(tool: Tool, line: Orders.Line, ticket: Orders.Ticket, at: number): string?
	const items = self.Dependencies.ItemService
	const id = tool:GetAttribute(PLATE_ID)
	if type(id) ~= "number" or id <= 0 then
		return items:QualityOf(tool)
	end
	const seconds = if ticket.TakenAt > 0 then at - ticket.TakenAt else -1
	const plate: Grade.Plate = {
		Toppings = items:Toppings(tool),
		Flipped = tool:GetAttribute(FLIPPED) == true,
		Scores = PlateTool.Scores(tool),
	}
	return Grade.Assembly(Content.Prep, line.Toppings, plate, seconds, self.Party)
end

-- Line a served hot dog answers and its verdict: the order check (Orders.Match), or an AddServeRule override on the
-- first pending line (Complete/Perfect pay as Complete, Incomplete as Incomplete, anything else = Wrong).
function CustomerService:Judge(ticket: Orders.Ticket, tool: Tool, override: SaleResult?): (number?, Orders.Verdict)
	if override == nil then
		return Orders.Match(ticket, self.Dependencies.ItemService:Toppings(tool))
	end
	const first = Orders.Pending(ticket)[1]
	if override == "Complete" or override == "Perfect" then
		return first, "Complete"
	elseif override == "Incomplete" then
		return first, "Incomplete"
	end
	return first, "Wrong"
end

-- Every line answered: mood, and the table or the exit. A customer at a table eats there only after a lone
-- Complete/Perfect or a pair with >= 1 Complete and no Wrong/Left/Refused (FEAT-037, FEAT-038, Q-209).
function CustomerService:Conclude(customer: Customer, ticket: Orders.Ticket)
	local complete = 0
	local bad = false
	for _, line in ticket.Lines do
		if line.Result == "Complete" or line.Result == "Perfect" then
			complete += 1
		elseif line.Result ~= "Incomplete" then
			bad = true
		end
	end
	local mood: string? = if bad then COMPLAINING elseif complete == #ticket.Lines then HAPPY else nil
	-- prep quality (Q-219 B): the mood moves by the sum of the served hot dogs' bands (Messy = -1 = one band worse)
	local shift = 0
	for _, line in ticket.Lines do
		shift += line.Mood or 0
	end
	if shift ~= 0 and not bad then
		const from = table.find(MOOD_LADDER, mood or customer.Mood)
		if from ~= nil then
			mood = MOOD_LADDER[math.clamp(from - shift, 1, #MOOD_LADDER)]
		end
	end
	-- pickup line (TASK-380): served without a Wrong line = it takes the plate, then a table or takeaway
	if customer.Pickup > 0 and not bad then
		self:LeaveServed(customer, mood)
		return
	end
	-- at a table (Q-209): a good result = it eats there first; the others stand up and go
	const eats = customer.AtTable and complete >= 1 and not bad
	self:Leave(customer.Id, mood, "service", eats)
end

-- Served at the pickup (TASK-380; tech §3.1 "Depois de servido"): the rigs carry the plate (attribute Carrying, client
-- R1-J); with Seating.SitAt = "Served" the Seater is offered the party now (Offer before Leave: taken = SeatingService
-- walks it PU-n -> table, it eats and Dismiss sends it out); else, or with no table, takeaway: it walks out carrying the
-- plate (Rules.TakeawayWhenNoTable; false = it leaves without the plate in hand). Actors and the tutorial customer never sit.
function CustomerService:LeaveServed(customer: Customer, mood: string?)
	const sits = Content.Seating.SitAt == SERVED_SEAT_MODE
		and customer.Variant == nil
		and not customer.Tutorial
		and self:OfferSeat(customer)
	if sits or Content.Restaurant.Rules.TakeawayWhenNoTable then
		self:SetCarrying(customer)
		const partner = if customer.Partner then self.Customers[customer.Partner] else nil
		if partner ~= nil then
			self:SetCarrying(partner)
		end
	end
	self:Leave(customer.Id, mood, "service", sits)
end

-- Rig attribute Carrying = true, after the Carry* look of the hot dog it was handed (none = the client draws its order);
-- all cleared when the record goes and the rig returns to the pool.
function CustomerService:SetCarrying(customer: Customer)
	const model = self.Dependencies.NpcService:GetModel(customer.Id)
	if model ~= nil then
		const look = customer.CarryLook
		model:SetAttribute(CARRY_LOOK.Toppings, if look then look.Toppings else nil)
		model:SetAttribute(CARRY_LOOK.Sauce, if look then look.Sauce else nil)
		model:SetAttribute(CARRY_LOOK.Altered, if look and look.Altered then true else nil)
		model:SetAttribute(CARRY_LOOK.Dish, if look and look.Dish then true else nil)
		model:SetAttribute(CARRYING, true)
		customer.CarryModel = model
	end
end

-- Asks SeatingService to take the party at "Take Order" (Seater.Offer). false = no seater, refused, or it errored (warned).
function CustomerService:OfferSeat(customer: Customer): boolean
	const seater = self.Seater
	const npc = self.Dependencies.NpcService:Get(customer.Id)
	if seater == nil or npc == nil then
		return false
	end
	const partner = if customer.Partner and self.Customers[customer.Partner] then customer.Partner else nil
	const ok, taken = pcall(seater.Offer, {
		Leader = customer.Id,
		Partner = partner,
		Couple = customer.Couple,
		CustomerType = npc.CustomerType,
	})
	if not ok then
		warn(`[CustomerService] seater failed: {taken}`)
		return false
	end
	return taken == true
end

-- Settles every pending line of a ticket with `result` ($0), per owner (a pair counts 2).
function CustomerService:SettlePending(customer: Customer, ticket: Orders.Ticket, result: SaleResult)
	for _, index in Orders.Pending(ticket) do
		ticket.Lines[index].Result = result
		self:Settle(self:LineOwner(customer, index), result, 0)
	end
end

-- Patience ran out (FEAT-011 "Desistiu"): $0, unsatisfied; every pending line of a pair gave up. Two kinds (Q-192):
-- the Queue clock = "Left" (never attended); the Order clock = "Slow" (the food took too long).
function CustomerService:GiveUp(id: number)
	const ticket = self.Tickets[id]
	const customer = self.Customers[id]
	if ticket == nil or customer == nil then
		return
	end
	const result: SaleResult = if ticket.Phase == "Order" then "Slow" else "Left"
	self:SettlePending(customer, ticket, result)
	self.Acted:Fire(id, GIVE_UP, nil, result)
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
		if ticket == nil or customer == nil or customer.State == "Leaving" or customer.Tutorial then
			continue
		end
		if ticket.Phase == "None" then
			continue -- behind Q1: no clock yet (Q-192)
		end
		if customer.PausedAt ~= nil then
			continue -- talking at the tablet (PausePatience, TASK-380)
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
			-- TAB-1 in the map (TASK-380): the order is taken at the tablet only (TabletService -> TakeOrderFor)
			return not self:IsTabletMode() and self:CanAct(player, anchor, "Ordering")
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
			-- no hand rule here: ServeCustomer picks the exact hot dog of the hotbar or answers with a hint
			return ticket ~= nil and ticket.TakenAt > 0
		end,
		Run = function(player: Player, anchor: Instance)
			self:Serve(player, anchor)
		end,
	})
	-- TASK-380: "Hand Over" on the PICKUP prompt; range and rate are InteractionService's (Actions.pickup_serve)
	interaction:RegisterAction(PICKUP_SERVE, {
		Validate = function(player: Player, anchor: Instance): boolean
			return self:IsPickupMode()
				and self:IsPickupAnchor(anchor)
				and self.Dependencies.RunStateService:IsActive(player)
				and self.Dependencies.EconomyService:IsDrawerOpen()
				and #self.PickupLine.Order > 0
		end,
		Run = function(player: Player)
			self:ServeAtPickup(player, nil)
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
	self.ActorRng = Random.new(hash(base .. ACTOR_SEED_DOMAIN) % SEED_MAX + 1)
end

function CustomerService:OnPhase(phase: string)
	self.EmptySince = 0
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
		-- Last call (DEC-240): the line stays; tell the crew nobody else is coming
		self.Dependencies.RunStateService:Notify("all", "last_call", 0)
		return
	end
	self:SendAllAway()
end

-- A customer is in the queue or on the way to it (not leaving, not at a table).
function CustomerService:HasLiveCustomer(): boolean
	for _, customer in self.Customers do
		if customer.State ~= "Leaving" then
			return true
		end
	end
	return false
end

-- Never an empty counter for long (user playtest 2026-10-11, Q-202; Flow.Guarantee): on a day shift, when nobody is
-- in the queue nor walking to it for the limit of this gap (Day 1 shorter, plus a random spread), the next attempt
-- is due now. The ordinary attempt still applies every cap (NPC pool, queue, customer cap) and the tutorial customer
-- keeps the flow waiting.
function CustomerService:StepGuarantee(t: number)
	if
		self.NextSpawnAt <= 0
		or not self:IsSelling()
		or self:IsPaused()
		or self.DevNoArrivals
		or self:IsNightShift()
		or self.TutorialWanted
		or self:HasTutorial()
		or self:HasLiveCustomer()
	then
		self.EmptySince = 0
		return
	end
	const guarantee = Content.Flow.Guarantee
	if self.EmptySince <= 0 then
		self.EmptySince = t
		const base = if self.Dependencies.RoundService:GetDay() <= 1 then guarantee.MaxEmptyDay1 else guarantee.MaxEmpty
		self.EmptyLimit = base + self.GuaranteeRng:NextNumber() * guarantee.Spread
		return
	end
	if t - self.EmptySince >= self.EmptyLimit then
		self.EmptySince = 0 -- a new gap (and a new limit) starts if the attempt is skipped
		if self.NextSpawnAt > t then
			self.NextSpawnAt = t
		end
	end
end

function CustomerService:Step()
	const t = now()
	self:StepTutorial(t)
	self:StepGuarantee(t)
	-- the regular flow waits while the tutorial customer is at (or walking to) the counter: the next attempt comes
	-- right after it was served
	-- night pacing (owner 2026-10-18): no arrival while a world anomaly with Tension runs (the street is empty, the
	-- scene owns the screen), and a random Flow.CounterGap after the counter frees before the next one may come
	const night = self:IsNightShift()
	const full = Queue.isFull(self:Occupants(), self:QueueSize())
	if night and full then
		self.CounterWasFull = true
	elseif night and self.CounterWasFull then
		self.CounterWasFull = false
		const gap = Content.Flow.CounterGap
		-- the leaving customer walks out of the shop area first (CounterLeave), then the random gap counts
		self.CounterFreeAt = t + Content.Flow.CounterLeave + gap[1] + self.Rng:NextNumber() * (gap[2] - gap[1])
	end
	const resting = night and (t < self.CounterFreeAt or self.Dependencies.NpcService:IsTension())
	if
		self.NextSpawnAt > 0
		and t >= self.NextSpawnAt
		and not resting
		and self:IsSelling()
		and not self:IsPaused()
		and not self.DevNoArrivals
		and not self:HasTutorial()
		and not self.TutorialWanted
	then
		const outcome = self:Attempt()
		local interval = self:NextInterval()
		if interval ~= nil and self.LastWasPair then
			interval *= Content.Flow.Groups.IntervalMult -- FEAT-038: the flow stays almost the same
		end
		if interval == nil then
			self.NextSpawnAt = 0
		elseif outcome == "skipped_queue_full" then
			-- DEC-241: the counter holds few customers; do not wait a whole interval, ask again soon
			self.NextSpawnAt = t + Content.Flow.FullRetry
		else
			-- From the scheduled time (no drift); a long stall does not burst several spawns at once
			self.NextSpawnAt = math.max(self.NextSpawnAt + interval, t + interval * 0.5)
		end
	end
	self:StepOrders(t)
	self:StepPairs(t)
	-- Safety net: a leaving customer that never reaches its exit still frees its NPC (a partner goes with its
	-- leader; a diner is SeatingService's until Dismiss)
	for id, customer in self.Customers do
		if
			customer.State == "Leaving"
			and not customer.Dining
			and (customer.Leader == nil or self.Customers[customer.Leader] == nil)
			and t - customer.LeftAt > LEAVE_TIMEOUT
		then
			self:Remove(id)
		end
	end
end

-- Partners follow their leader (FEAT-038): MoveTo towards Group.Spot, never their own pathfinding. Re-aimed when the
-- spot moved > RETARGET or every REAIM s; snapped back past Flow.Groups.Leash; turned like a standing leader.
const RETARGET = 0.5 -- studs
const REAIM = 1 -- s
const NEAR = 0.75 -- studs: on its spot
const MOVING = 1 -- studs/s of the leader's root: walking
function CustomerService:StepPairs(t: number)
	const npc = self.Dependencies.NpcService
	for id, customer in self.Customers do
		const leaderId = customer.Leader
		if leaderId == nil or customer.Held then
			continue
		end
		const leader = self.Customers[leaderId]
		const leaderRig = npc:GetRig(leaderId)
		const rig = npc:GetRig(id)
		if leader == nil or leaderRig == nil or rig == nil or not leaderRig.Root:IsDescendantOf(workspace) then
			continue
		end
		if (leader.Dining or leader.AtTable) and leaderRig.Root.Anchored then
			continue -- seated: SeatingService holds both
		end
		const velocity = leaderRig.Root.AssemblyLinearVelocity
		const moving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > MOVING
		const spot = Group.Spot(leaderRig.Root.CFrame, moving, customer.Couple)
		const offset = rig.Root.Position - spot
		const distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
		if moving then
			customer.Faced = false
		end
		if distance > Content.Flow.Groups.Leash then
			npc:Teleport(id, spot)
			customer.FollowTarget = nil
		elseif distance > NEAR then
			const last = customer.FollowTarget
			if last == nil or (last - spot).Magnitude > RETARGET or t - customer.FollowAt > REAIM then
				npc:MoveToward(id, spot)
				customer.FollowTarget = spot
				customer.FollowAt = t
			end
		elseif not moving and not customer.Faced then
			npc:Face(id, leaderRig.Root.CFrame.LookVector)
			customer.Faced = true
			customer.FollowTarget = nil
		end
	end
end

-- Tutorial customer (user request 2026-10-11, Provisional) ---------------------------------------------------------

-- The tutorial customer still at or walking to the counter (not leaving), or nil.
function CustomerService:TutorialCustomer(): Customer?
	for _, customer in self.Customers do
		if customer.Tutorial and customer.State ~= "Leaving" then
			return customer
		end
	end
	return nil
end

function CustomerService:HasTutorial(): boolean
	return self:TutorialCustomer() ~= nil
end

-- TutorialService: a rookie started the tutorial. One tutorial customer spawns as soon as there is room
-- (StepTutorial); nothing new while one is around or already asked. false = not in a run.
function CustomerService:RequestTutorial(): boolean
	if not self.Enabled then
		return false
	end
	if self.TutorialWanted or self:HasTutorial() then
		return true
	end
	self.TutorialWanted = true
	self.TutorialTryAt = 0
	return true
end

-- TutorialService: nobody has the tutorial pending any more (finished, skipped, left). An unserved tutorial customer
-- walks off with no outcome; a request not spawned yet is dropped.
function CustomerService:EndTutorial()
	self.TutorialWanted = false
	const customer = self:TutorialCustomer()
	if customer ~= nil then
		self:Leave(customer.Id, nil, "service")
	end
end

-- Spawns the asked tutorial customer in a day Prep/Open with a free counter slot and room in the NPC pool (tried
-- again every TutorialRules.Retry s). It walks to the queue like any customer.
function CustomerService:StepTutorial(t: number)
	if not self.TutorialWanted or t < self.TutorialTryAt then
		return
	end
	self.TutorialTryAt = t + TutorialRules.Retry
	const round = self.Dependencies.RoundService
	if not round:IsStarted() or self:IsNightShift() or not TUTORIAL_PHASES[round:GetPhase()] then
		return
	end
	const npc = self.Dependencies.NpcService
	if Queue.isFull(self:Occupants(), self:QueueSize()) or npc:Count() >= npc:Capacity() then
		return
	end
	const id = npc:Spawn({ Rng = self.TutorialRng })
	if id == nil then
		return
	end
	self.TutorialWanted = false
	self:Create(id, nil, nil, true)
end

-- Dev hook (Command Bar; R5 counter is TASK-045) ------------------------------------------------------------------

-- Pair now (dev /customer group, TASK-146): `leader` / `partner` = CustomerTypes keys of a Flow.Groups.Pairs row
-- of the current shift (nil = weighted draw). Ignores the chance; caps and queue still apply. Returns the outcome.
function CustomerService:DevSpawnPair(leader: string?, partner: string?, orders: { { string } }?): (Outcome, number?)
	if not self.Dependencies.PlaceService:IsDev() then
		error("[CustomerService] DevSpawnPair is dev mode only", 2)
	end
	const info = self.Dependencies.RoundService:Info()
	local chosen: Group.Pair? = nil
	if leader == nil then
		chosen = Group.Pick(info.Day, info.Night, self:IsNightShift(), self.Rng)
	else
		for _, pair in Content.Flow.Groups.Pairs do
			if pair.Leader == leader and pair.Partner == partner then
				chosen = pair
				break
			end
		end
	end
	if chosen == nil then
		error(`[CustomerService] no pair {leader or "?"}+{partner or "?"} for this shift`, 2)
	end
	self.ForcedPair = chosen
	self.ForcedOrders = orders
	const outcome, id = self:Attempt()
	self.ForcedPair = nil
	if id == nil then
		self.ForcedOrders = nil
	end
	return outcome, id
end

-- One spawn attempt now, whatever the phase. Returns the outcome and the NpcId.
function CustomerService:DevSpawn(): (Outcome, number?)
	if not self.Dependencies.PlaceService:IsDev() then
		error("[CustomerService] DevSpawn is dev mode only", 2)
	end
	return self:Attempt()
end

-- Dev (/dev pickup, TASK-380): pickup line readout. Studio dev only.
function CustomerService:DevPickupState(): string
	assert(self.Dependencies.PlaceService:IsDev(), "dev mode only")
	const lines: { string } = {
		`restaurant {"on"} | pickup mode {self:IsPickupMode()} | tablet mode {self:IsTabletMode()}`,
		`PU points {self:PickupPoints()} | size {self:PickupSize()} | in line {#self.PickupLine.Order} | full {self:IsPickupFull()} | last #n {self.OrderNumber}`,
	}
	const t = now()
	for spot, id in self.PickupLine.Order do
		const customer = self.Customers[id]
		const ticket = self.Tickets[id]
		if customer == nil then
			table.insert(lines, `PU-{spot}: {id} (no record)`)
			continue
		end
		const pending: { string } = {}
		for _, toppings in self:PendingToppings(id) do
			table.insert(pending, if #toppings > 0 then table.concat(toppings, "+") else "plain")
		end
		const left = if ticket then math.max(math.floor(ticket.PatienceEndsAt - t), 0) else 0
		table.insert(
			lines,
			`PU-{spot}: npc {id} #{customer.Number or "-"} {customer.State} wire Pickup {customer.Pickup} | {table.concat(pending, " | ")} | {left} s{if customer.PausedAt then " (paused)" else ""}`
		)
	end
	const front = self:Front()
	if front ~= nil then
		const customer = self.Customers[front]
		table.insert(lines, `Q1: npc {front} {if customer then customer.State else "?"}`)
	end
	return table.concat(lines, "\n")
end

-- Dev: the pure table tests of Pickup.luau. Returns the failures (empty = passed).
function CustomerService:DevPickupTest(): { string }
	assert(self.Dependencies.PlaceService:IsDev(), "dev mode only")
	return Pickup.Test()
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
		self.OrderNumber = 0 -- #n starts at 1 every shift (FEAT-043)
	end)
	round.PhaseChanged:Connect(function(phase)
		self:OnPhase(phase)
	end)
	-- The window is the shop (TASK-284): closing it sends the line away. VehicleService (620) made the signal in its OnInit
	self.Dependencies.VehicleService.ShutterChanged:Connect(function(closed: boolean, player: Player?)
		if closed then
			self:SendLineAway(player)
		end
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
	Adopt.Init(self) -- passers-by turning customers + first attempt sooner (TASK-163); after the PhaseChanged above
end)

CustomerService:OnTick(function(self)
	if self.Enabled then
		self:Step()
	end
end, TICK_RATE)

return CustomerService
