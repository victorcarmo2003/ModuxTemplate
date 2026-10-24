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
-- the queue is still served in the Closing last call (day, and the 6 AM one since owner 2026-10-21). Leaving a selling
-- phase for anything else sends every customer away (NightLost, Summary, Finale...); NightEnd keeps the line for the 6 AM
-- last call.
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
-- Owner 2026-10-22 (Provisional; design/anomalies-after-accept-proposal.md §9): no ACCEPT / REFUSE any more. The tablet
-- takes EVERY order at the end of the talk (TakeOrderFor), anomaly actors included: "take_order" on an actor is no error,
-- its order goes to the delivery line like anyone's and its module runs a condition (Anomaly/Kit/CustomerActor).
-- AddActorJudge(fn): asked before the sale of a serve on an actor, with the hot dog's toppings: "Return" = the plate comes
-- back (ANM-011: a topping on the shaker's plain order; the hot dog is lost, $0, nothing settled, Acted "return", it keeps
-- waiting with its clock running); "Wrong" = the condition's error ($0 as a serve rule's Wrong; the module scares).
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
-- Rules.Orders (in turn), never runs out of patience (no ring: PatienceEndsAt 0 on the wire), never counts on the shift ledger
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
-- TASK-354 (owner request 2026-10-17, Provisional): no "Refuse" prompt or button any more. Owner 2026-10-23: closing the
-- service window sends only the customer anomalies away (Anomaly/Kit/CustomerActor reads the Shutter event); the ordinary
-- line stays (OnShutter).
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
	-- owner 2026-10-22 (Provisional): patience clocks (Queue and Order) x this, on top of the type's PatienceMult (nil = 1)
	PatienceScale: number?,
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
	-- Pickup arc (owner 2026-10-20): reached the arc once (later moves go straight), and the counter slot it walks to for its
	-- plate (1..PickupArc.Slots, 0 = not collecting; Display = its plate on the counter)
	Arc: boolean,
	CounterSlot: number,
	Display: Model?,
}

-- DriveThruService hooks (SetDriver, TASK-574). Try(party): one spawn attempt may become a car; the NpcId when a car
-- spawned (it called Create with its lane spot), nil = an ordinary attempt. Left(id): a drive customer started leaving (its car drives
-- off; DriveThruService removes the record). Neither may yield.
-- `counter` = customers at / walking to the counter now (Occupants), for the counter / drive-thru balance (owner 2026-10-20).
-- TryTutorial(): the tutorial customer as a car (owner 2026-10-20: the 2nd tutorial customer comes to the drive-thru), any
-- night, no share draw; the NpcId, nil = no room on the lane / in the pool (CustomerService tries again later).
export type Driver = {
	Try: (party: number, counter: number) -> number?,
	TryTutorial: () -> number?,
	Left: (id: number) -> (),
}

-- TabletService hook (SetTalker): the car's "Take Order" runs the tablet talk (TabletDialog, lines, sounds) on the DT-PC
-- record instead of taking the order at once. Start = talk started; Talking = that car's talk is running.
export type Talker = {
	Start: (player: Player, id: number) -> boolean,
	Talking: (id: number) -> boolean,
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
	Bread: boolean?,
}

-- Sale.Result (network.md §4.3) = EconomyService SaleResult
export type SaleResult = "Perfect" | "Complete" | "Incomplete" | "Wrong" | "Left" | "Refused" | "Slow"

-- Customer-anomaly variant (= NpcService.Variant; rig attribute "Variant", read by the client)
export type Variant = "blank" | "mirror" | "raincoat" | "shake" | "neck" | "eyes" | "bighead" | "float" | "stare" | "banger" | "oncam"

-- SpawnActor request (architecture.md §19.13 Context.Spawn). Look fields force the draw (must be valid for the type);
-- CopyOf (mirror only) copies the type, species and outfit of a live, non-actor customer that is not leaving.
export type CustomerActorSpec = {
	Variant: Variant,
	CustomerType: string?,
	Species: string?,
	Outfit: string?,
	CopyOf: number?,
	From: string?,
	-- owner 2026-10-22 (Provisional): scale (0, 1] of both patience clocks (Content.OrderRules.UnservablePatienceScale,
	-- sent by the anomalies the player must not serve); nil = 1
	PatienceScale: number?,
}

-- Acted.action (TASK-053): the three customer actions, plus give_up when patience ran out (no player) and return (an
-- actor's condition sent the plate back, AddActorJudge; result nil)
export type ActedAction = "take_order" | "serve" | "refuse" | "give_up" | "return"

-- Serve override (AddServeRule): nil = no opinion, the order check decides
export type ServeRule = (customer: Customer, tool: Tool, player: Player) -> SaleResult?

-- Customer anomaly in the delivery queue (AddActorJudge; owner 2026-10-22, Provisional): asked before the sale of a serve
-- on an actor, with the served hot dog's toppings. "Return" = the plate comes back; "Wrong" = the error; nil = a sale
export type ActorVerdict = "Return" | "Wrong"
-- `bread` = what was handed over is a plate with the bun alone (IsBreadPlate), not a hot dog
export type ActorJudge = (id: number, toppings: { string }, player: Player, bread: boolean) -> ActorVerdict?

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
const RETURN = "return"
const CLOSING = "Closing"
const NIGHT_END = "NightEnd"
-- the 6 AM Closing is a last call (Content.Shift Closing Night.LastCall, owner 2026-10-21): NightEnd keeps the line for it
const NIGHT_LAST_CALL = (Content.Shift.ByKey.Closing.Night ~= nil and Content.Shift.ByKey.Closing.Night.LastCall) == true
const SHOP_CLOSED = "shop_closed" -- Content.Notices key (D-04 #10)
-- Same notice to the same player at most once per this many seconds (FEAT-005 anti-spam). PROVISIONAL constant:
-- no Content field holds it yet.
const NOTICE_GAP = 2
const SERVE_HOLD_HINT = "serve_hold_hot_dog" -- Content.Notices keys (owner request 2026-10-12, Provisional)
const SERVE_EMPTY_HINT = "serve_nothing"
const HOT_DOG = "hot_dog"
-- a plate with the bun alone serves a bread-only order (Content.OrderRules.BreadOnly)
const PLATE = PlateTool.Plate
const PLATE_BUN = PlateTool.Attr.Bun
const PLATE_SAUSAGE = PlateTool.Attr.Sausage
const HAPPY = "Happy"
const ANNOYED = "Annoyed"
const COMPLAINING = "Complaining"
const LEAVE_TIMEOUT = 45 -- s; a leaving customer that never reaches its exit is despawned anyway
const NEUTRAL = "Neutral" -- arrival mood (Content.Moods)
-- Mood ladder, best first (Q-219 B: Messy = one band down; Content.Moods has no order of its own yet)
const MOOD_LADDER = { HAPPY, NEUTRAL, ANNOYED, COMPLAINING }
-- phases where the tutorial customer may spawn: the first night's Prep and shop (DEC-311; DEC-360: the run always
-- starts at night, there is no day Open any more)
const TUTORIAL_PHASES: { [string]: boolean } = { Prep = true, Night = true }
-- Restaurant (TASK-380)
const PICKUP_SERVE = "pickup_serve" -- Content.Actions key (PICKUP Prompt_Serve)
const PICKUP_FULL = "pickup_full" -- Content.Notices key
const CARRYING = "Carrying" -- rig attribute: the customer carries its plate (Seating client, R1-J)
-- rig attributes: the look of THE hot dog it was handed (owner 2026-10-19; Seating client Meal draws it on its dish)
const CARRY_LOOK = { Toppings = "CarryToppings", Sauce = "CarrySauce", Altered = "CarryAltered", Dish = "CarryDish" }
const TOPPING_ANCHOR = "Att_Topping1" -- HotDogVisual: the up axis of the stack (the counter plate lies on it)
const ARC_SIGHT_RADIUS = 1 -- studs: half a customer's width, the straight way to the arc spot must be this clear
const ARC_SIGHT_HITS = 8 -- rigs skipped on that way before it counts as blocked
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
	-- ShutGrace wait of the player-closed window (the line), the WaitShutGrace wait (customers whose order was taken), and the
	-- last ShutLines index shown (no repeat in a row)
	self.ShutThread = nil :: thread?
	self.WaitShutThread = nil :: thread?
	self.LastComplaint = 0 :: number
	self.Line = Queue.new() :: Queue.Queue
	-- Reseeded at every ShiftStarted
	self.Rng = Random.new() :: Random
	-- Order draws (TASK-033), reseeded at every ShiftStarted
	self.OrderRng = Random.new() :: Random
	-- Actor look draws (TASK-108), reseeded at every ShiftStarted
	self.ActorRng = Random.new() :: Random
	-- Serve overrides (AddServeRule), in registration order
	self.ServeRules = {} :: { ServeRule }
	-- Customer anomaly judges (AddActorJudge, AnomalyService conditions), in registration order
	self.ActorJudges = {} :: { ActorJudge }
	-- Server-only order of each customer in the queue, by NpcId (TASK-033)
	self.Tickets = {} :: { [number]: Orders.Ticket }
	-- Connected members, locked when the shop opens (DEC-185)
	self.Party = 1 :: number
	-- 0 = no spawn scheduled
	self.NextSpawnAt = 0 :: number
	-- night pacing (owner 2026-10-18): the counter freed, the next customer waits until CounterFreeAt (Flow.CounterGap)
	self.CounterFreeAt = 0 :: number
	-- server time until which nobody new arrives after the window reopened (Flow.ReopenPause, owner 2026-10-20)
	self.ReopenUntil = 0 :: number
	-- Pickup arc (owner 2026-10-20): the counter copy of the hot dog being handed over (ServeAtPickup -> LeaveServed), the
	-- counter slots in use (slot -> customer id) and the folder of the counter plates
	self.PendingDisplay = nil :: Model?
	self.CounterSlots = {} :: { [number]: number }
	self.DisplayFolder = nil :: Folder?
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
	-- tutorial customers served in this server (DEC-311: the next one gets TutorialRules.Orders[served + 1])
	self.TutorialServed = 0 :: number
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
	-- TabletService hook (SetTalker); nil = the car's order is taken at once
	self.Talker = nil :: Talker?
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
-- At night Flow.NightQueueByParty (DEC-320, Q-413; was Flow.NightQueueSize = 1, TASK-287): one NPC at the counter
-- for 1-2 players, two with 3+ (party locked when the selling phase started).
function CustomerService:QueueSize(): number
	if self:IsNightShift() then
		const byParty = Content.Flow.NightQueueByParty
		return Queue.size(byParty[math.clamp(self.Party, 1, #byParty)] or Content.Flow.NightQueueSize)
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

-- TutorialService: "no regular customer arrives now" (user decision 2026-10-12, Provisional: Night 1 customers wait until
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
	-- DEC-320 (Q-413): the night cap follows the crew size, Restaurant.Flow.MaxCustomers (5 / 7 / 9 / 9), party locked
	-- when the selling phase started; a night row may only lower it
	const byParty = Content.Restaurant.Flow.MaxCustomers
	const cap = byParty[math.clamp(self.Party, 1, #byParty)] or flow.MaxCustomersNight
	const row = self:NightRow()
	return if row ~= nil and row.Customers.Max < flow.MaxCustomersNight then math.min(row.Customers.Max, cap) else cap
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
	local party = flow.PartyMult[math.clamp(self.Party, 1, #flow.PartyMult)]
	if self:IsNightShift() then
		-- DEC-320 (Q-413): the restaurant's own crew multiplier at night (1 / 1.8 / 2.5 / 3.1)
		const restaurantMult = Content.Restaurant.Flow.PartyMult
		party = restaurantMult[math.clamp(self.Party, 1, #restaurantMult)] or party
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

-- TabletService (one): the talk for the car's "Take Order", nil = off.
function CustomerService:SetTalker(talker: Talker?)
	self.Talker = talker
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
	if not customer.Tutorial then
		self.Dependencies.EconomyService:CountArrival()
	end
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
	local written = true
	if customer.Tutorial then
		-- the tutorial car never runs out of patience (no clock on the wire)
		customer.State = "Ordering"
		self:Publish(customer, false)
	else
		const drive = Content.Restaurant.Drive
		const bonus = math.max(self.Dependencies.UpgradeService:GetEffect("PatienceBonus"), 0)
		ticket.QueueSpan = drive.OrderPatience + bonus
		ticket.OrderSpan = drive.PrepBase + drive.PrepPerK * ticket.K + bonus
		Orders.BeginQueue(ticket, now())
		customer.State = "Ordering"
		written = self:Update(id, {
			PatienceEndsAt = ticket.PatienceEndsAt,
			Phase = "Queue",
			PatienceSpan = Orders.WireSpan(ticket),
		})
	end
	-- owner 2026-10-20 (Provisional): the order is taken on the car itself ("Take Order" on the driver's rig), no tablet
	const customerAnchor = self.Dependencies.NpcService:Anchors(id)
	if customerAnchor ~= nil then
		customerAnchor:SetAttribute("PromptAction", TAKE_ORDER)
	end
	self:SetPrompts(id, true)
	return written
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
		Bread = if self:IsBread(customer) then true else nil,
	}
end

-- The order is a bun alone, no sausage (Content.OrderRules.BreadOnly; ANM-011 the shaker, owner 2026-10-22)
function CustomerService:IsBread(customer: Customer): boolean
	return customer.Variant ~= nil and Content.OrderRules.BreadOnly[customer.Variant] == true
end

-- A plate Tool with the bun alone on it: no sausage, no topping (what a bread-only order is served with)
function CustomerService:IsBreadPlate(tool: Tool): boolean
	const items = self.Dependencies.ItemService
	return items:ItemOf(tool) == PLATE
		and tool:GetAttribute(PLATE_BUN) == true
		and tool:GetAttribute(PLATE_SAUSAGE) ~= true
		and #items:Toppings(tool) == 0
end

-- The bread plate of the player: the one in the hand, else the first one of the hotbar; nil = none
function CustomerService:BreadPlateOf(player: Player): Tool?
	const items = self.Dependencies.ItemService
	const held = items:GetHeld(player)
	if held ~= nil and self:IsBreadPlate(held) then
		return held
	end
	for _, candidate in items:Tools(player) do
		if self:IsBreadPlate(candidate) then
			return candidate
		end
	end
	return nil
end

-- The bread-only customer of the pickup line a bread plate goes to: `target` when it wants bread, else the plate's
-- ticket owner when it does, else the first waiting one in line order. nil = none waiting
function CustomerService:BreadTarget(tool: Tool, target: number?): number?
	local function wants(id: number?): boolean
		const customer = if id ~= nil then self.Customers[id] else nil
		const ticket = if id ~= nil then self.Tickets[id] else nil
		return customer ~= nil
			and ticket ~= nil
			and customer.State == "Waiting"
			and customer.Pickup > 0
			and ticket.TakenAt > 0
			and #Orders.Pending(ticket) > 0
			and self:IsBread(customer)
	end
	if wants(target) then
		return target
	end
	const owner = self:TicketOwner(tool)
	if wants(owner) then
		return owner
	end
	for _, id in self.PickupLine.Order do
		if wants(id) then
			return id
		end
	end
	return nil
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
		-- AvoidQueue: the way in passes only the free slots behind its own (owner 2026-10-21, Q1's west way in; Graph.behind)
		self:Walk(customer, Queue.point(slot), true, function(ok: boolean)
			if ok then
				self:Reached(customer, slot)
			end
		end)
	end
end

-- Nothing solid between `model` and `target` at its waist (rigs and players walk aside, so they do not count): it can
-- walk there straight. Plain function, not a method: no generated type change (ModuxTypes)
local function inSight(model: Model?, target: Vector3?): boolean
	const root = if model ~= nil then model.PrimaryPart else nil
	if root == nil or target == nil then
		return false
	end
	const ignore: { Instance } = { model :: Model }
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	const from = root.Position
	const way = Vector3.new(target.X, from.Y, target.Z) - from
	for _ = 1, ARC_SIGHT_HITS do
		params.FilterDescendantsInstances = ignore
		const hit = workspace:Spherecast(from, ARC_SIGHT_RADIUS, way, params)
		if hit == nil then
			return true
		end
		const body = hit.Instance:FindFirstAncestorWhichIsA("Model")
		if body == nil or body:FindFirstChildWhichIsA("Humanoid") == nil then
			return false
		end
		table.insert(ignore, body)
	end
	return false
end

-- Pickup line (TASK-380): sends everyone in it to the PU-k of their position (PU-1 = at the counter) and turns the
-- PICKUP prompt on while somebody waits. Called after every join and leave of the pickup line.
function CustomerService:RefreshPickup()
	const points = self:PickupPoints()
	const format = Content.Restaurant.Binding.PickupPoint
	const arc = self:IsArcMode()
	for spot, id in self.PickupLine.Order do
		const customer = self.Customers[id]
		if customer == nil or customer.Pickup == spot or customer.CounterSlot > 0 then
			continue
		end
		customer.Pickup = spot
		self:Publish(customer, false)
		if arc and points > 0 then
			-- owner 2026-10-20: to PU-1 by the graph once, then straight to its place on the arc. Owner 2026-10-21 ("ele vai
			-- até o prato de pickup e depois para a posição em arco"): straight to the arc when nothing stands in the way
			if not customer.Arc and inSight(self.Dependencies.NpcService:GetModel(id), self:ArcSpot(spot)) then
				customer.Arc = true
			end
			if customer.Arc then
				self:WalkArc(customer)
			else
				self:Walk(customer, Pickup.point(1, format), true, function(ok: boolean)
					if ok then
						customer.Arc = true
						self:WalkArc(customer)
					end
				end)
			end
		elseif points > 0 then
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
		const ok, driven = pcall(driver.Try, self.Party, self:Occupants())
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
function CustomerService:Create(
	id: number,
	variant: Variant?,
	leader: number?,
	tutorial: boolean?,
	drive: number?,
	patienceScale: number?
)
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
		PatienceScale = patienceScale,
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
		Arc = false,
		CounterSlot = 0,
		Display = nil,
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
	-- (a bad scale is ignored: only (0, 1] shortens the clocks)
	const scale = spec.PatienceScale
	self:Create(id, spec.Variant, nil, nil, nil, if type(scale) == "number" and scale > 0 and scale <= 1 then scale else nil)
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

-- Registers a customer anomaly judge (owner 2026-10-22, Provisional; Anomaly/Kit/CustomerActor, the conditions of the
-- delivery queue). Returns the function that removes it.
function CustomerService:AddActorJudge(judge: ActorJudge): () -> ()
	table.insert(self.ActorJudges, judge)
	return function()
		const index = table.find(self.ActorJudges, judge)
		if index ~= nil then
			table.remove(self.ActorJudges, index)
		end
	end
end

-- First non-nil verdict of the actor judges on a serve of actor `id` (nil = an ordinary sale). A judge that errors is
-- skipped (warned). Never asked for an ordinary customer or the tutorial one.
function CustomerService:JudgeActor(customer: Customer, tool: Tool, player: Player): ActorVerdict?
	if customer.Variant == nil or customer.Tutorial then
		return nil
	end
	const toppings = self.Dependencies.ItemService:Toppings(tool)
	const bread = self:IsBreadPlate(tool)
	for _, judge in table.clone(self.ActorJudges) do
		const ok, verdict = pcall(judge, customer.Id, toppings, player, bread)
		if not ok then
			warn(`[CustomerService] actor judge failed: {verdict}`)
		elseif verdict == "Return" or verdict == "Wrong" then
			return verdict
		end
	end
	return nil
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
	if customer ~= nil and customer.Drive > 1 then
		-- owner 2026-10-20 (Provisional): no DT-PC tablet nor DT-WIN any more; the car AT THE WINDOW (spot 1) carries the
		-- prompt itself ("Take Order", then "Serve" on the driver's rig). The cars behind it have none.
		enabled = false
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
	self:ClearCollect(customer)
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
	self:CancelShutWait()
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

-- Customers a closing window sends away (sorted ids): not leaving, not a partner, not an actor, not the tutorial one, and
-- not a diner whose food already came (a ticket with nothing pending). `waiting` (owner 2026-10-20, Provisional): true =
-- only the ones whose order was taken (State Waiting), false = only the line (not ordered yet), nil = both.
function CustomerService:LineAwayIds(waiting: boolean?): { number }
	const ids: { number } = {}
	for id, customer in self.Customers do
		if customer.State == "Leaving" or customer.Leader ~= nil or customer.Variant ~= nil or customer.Tutorial then
			continue
		end
		if waiting ~= nil and (customer.State == "Waiting") ~= waiting then
			continue
		end
		const ticket = self.Tickets[id]
		if ticket ~= nil and #Orders.Pending(ticket) == 0 then
			continue
		end
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

-- The service window shut by a player (Content.ShopWindow.ShutGrace): the line complains first and leaves after.
-- The window stayed shut ShutGrace s; each customer shows a short line over its head (CustomerComplain), is Complaining
-- with the prompts off and its patience frozen, and walks off ComplainTime (+ jitter) s later exactly as SendLineAway
-- does (reopening in between does not call it back).
function CustomerService:ComplainLineAway(player: Player?, waiting: boolean?)
	const rules = Content.ShopWindow
	const result = rules.LeaveResult :: SaleResult
	const lines = #rules.ShutLines
	const net = self.Dependencies.NetService
	for _, id in self:LineAwayIds(waiting) do
		const customer = self.Customers[id]
		if customer == nil or customer.State == "Leaving" then
			continue
		end
		self:PausePatience(id, true)
		self:SetPrompts(id, false)
		self:Update(id, { Mood = rules.LeaveMood })
		-- never the same line twice in a row
		-- (math.random: the shift Rng stream stays deterministic for spawns and orders)
		local line = math.random(1, lines)
		if lines > 1 and line == self.LastComplaint then
			line = line % lines + 1
		end
		self.LastComplaint = line
		if net:IsRunning() then
			self.Libs.Net.CustomerComplain:fireClient(net.Audience, { Npc = id, Line = line })
		end
		task.delay(rules.ComplainTime + math.random() * rules.LeaveJitter, function()
			-- gone, or a new customer on the id, or it left by itself meanwhile
			if self.Customers[id] ~= customer or customer.State == "Leaving" then
				return
			end
			const ticket = self.Tickets[id]
			if ticket ~= nil then
				self:SettlePending(customer, ticket, result)
				self.Acted:Fire(id, REFUSE, player, result)
			end
			self:Leave(id, rules.LeaveMood)
		end)
	end
end

-- REFUSE at the end of the order talk (owner 2026-10-21, DEC-353; TabletService): only this customer goes. An anomaly
-- customer is answered by its module (Kit/CustomerActor reads Acted "refuse": the right verb resolves it, the wrong one
-- scares). An ordinary one walks off at once (it must not stay at the tablet to be talked to again) saying one of
-- ShopWindow.ShutLines: the sale is lost (LeaveResult), no scare. true = refused.
function CustomerService:RefuseOne(player: Player, id: number): boolean
	const customer = self.Customers[id]
	if customer == nil or customer.State == "Leaving" then
		return false
	end
	if customer.Variant ~= nil then
		self.Acted:Fire(id, REFUSE, player, nil)
		return true
	end
	const rules = Content.ShopWindow
	const result = rules.LeaveResult :: SaleResult
	const lines = #rules.ShutLines
	local line = math.random(1, math.max(lines, 1))
	if lines > 1 and line == self.LastComplaint then
		line = line % lines + 1
	end
	self.LastComplaint = line
	const net = self.Dependencies.NetService
	if lines > 0 and net:IsRunning() then
		self.Libs.Net.CustomerComplain:fireClient(net.Audience, { Npc = id, Line = line })
	end
	const ticket = self.Tickets[id]
	if ticket ~= nil then
		self:SettlePending(customer, ticket, result)
		self.Acted:Fire(id, REFUSE, player, result)
	end
	self:Leave(id, rules.LeaveMood)
	return true
end

-- Owner 2026-10-23 (Provisional): closing the window no longer sends the ordinary customers away; they keep their place
-- (the shop is paused, no new arrival) and only the customer anomalies go (Anomaly/Kit/CustomerActor). SendLineAway and
-- ComplainLineAway stay for other callers.
function CustomerService:OnShutter(_closed: boolean, _player: Player?)
	self:CancelShutWait()
end

-- Stops the pending ShutGrace / WaitShutGrace waits (reopened, new shift, shift end)
function CustomerService:CancelShutWait()
	if self.ShutThread ~= nil then
		task.cancel(self.ShutThread)
		self.ShutThread = nil
	end
	if self.WaitShutThread ~= nil then
		task.cancel(self.WaitShutThread)
		self.WaitShutThread = nil
	end
end

-- The service window shut (TASK-284, owner request 2026-10-14; Content.ShopWindow, Provisional Q-270): everyone in line,
-- ordering or waiting for food walks off angry (ShopWindow.LeaveMood). Each pending hot dog is settled as
-- ShopWindow.LeaveResult (Refused: $0, same ledger and stats as a refusal; Acted "refuse" with the player who closed,
-- nil = automatic). Still walking to the line (no ticket yet): leaves angry, no outcome. Stay: the tutorial customer,
-- anomaly actors (their module decides) and diners whose food came.
function CustomerService:SendLineAway(player: Player?, waiting: boolean?)
	const rules = Content.ShopWindow
	const result = rules.LeaveResult :: SaleResult
	for _, id in self:LineAwayIds(waiting) do
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
	self:CancelShutWait()
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
		-- fixed order (the next of TutorialRules.Orders, DEC-311), patience that never runs out (no draw: the seeded order stream
		-- stays the same)
		const orders = TutorialRules.Orders
		const ticket = Orders.Ticket({ table.clone(orders[math.clamp(self.TutorialServed + 1, 1, #orders)]) }, now(), 0, 0, nil)
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
	if self:IsBread(customer) then
		-- ANM-011 (owner 2026-10-22): the shaker wants a bun alone; no topping on the ticket (no sausage either: IsBread),
		-- the draw above still ran (stream unchanged)
		lines = { {} }
	end
	const arrivedAt = if customer.JoinedAt > 0 then customer.JoinedAt else now()
	const typeRow = Content.CustomerTypes.ByKey[npc.CustomerType]
	local mult = if typeRow then typeRow.PatienceMult else nil
	-- owner 2026-10-22 (Provisional): an actor the player must not serve waits a fraction of the time (both clocks)
	const variantMult = customer.PatienceScale
	if variantMult ~= nil then
		mult = {
			Queue = (if mult then mult.Queue else 1) * variantMult,
			Order = (if mult then mult.Order else 1) * variantMult,
		}
	end
	self.Tickets[id] = Orders.Ticket(lines, arrivedAt, bonus, pairBonus, mult)
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
	-- owner 2026-10-22: a plate with the bun alone goes to a bread-only order (ANM-011) waiting in the line; a hot dog in the
	-- hand still goes first (handed to him, he throws it: the condition Plain)
	local breadId: number? = nil
	if tool == nil then
		const plate = self:BreadPlateOf(player)
		breadId = if plate ~= nil then self:BreadTarget(plate, target) else nil
		if breadId ~= nil then
			tool = plate
		end
	end
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
	end
	const served = tool :: Tool
	if items:GetHeld(player) ~= served then
		self:Equip(player, served)
	end
	const toppings = items:Toppings(served)
	const id = if breadId ~= nil
		then breadId
		else Pickup.choose(self.PickupLine, self:TicketOwner(served), target, function(candidate: number): Pickup.Fit
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
	-- Pickup arc (owner 2026-10-20): a copy of the plate goes on the counter if the sale lets the customer take it (LeaveServed)
	self.PendingDisplay = if self:IsArcMode() and customer.Drive == 0 then self:MakeDisplay(served) else nil
	const result = self:ServeCustomer(player, id, customer, ticket, served)
	const unused = self.PendingDisplay
	self.PendingDisplay = nil
	if unused ~= nil then
		unused:Destroy()
	end
	return result, id
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
	const tool = if picked ~= nil then picked else self:PickServeTool(player, ticket, self:IsBread(customer))
	if tool == nil then
		return nil
	end
	const at = now()
	-- customer anomaly in the delivery queue (AddActorJudge, owner 2026-10-22): its condition may send the plate back (the
	-- hot dog is lost, nothing is paid or settled, it keeps waiting) or make this serve the error (Wrong, as a serve rule)
	const judged = self:JudgeActor(customer, tool, player)
	if judged == "Return" then
		self.Dependencies.ItemService:Consume(player, tool)
		self.Acted:Fire(id, RETURN, player, nil)
		return nil
	end
	-- AddServeRule (TASK-108): an override replaces the order check (on the first pending line)
	const override: SaleResult? = if judged == "Wrong" then "Wrong" else self:ServeOverride(customer, tool, player)
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
-- `bread` = a bread-only order (owner 2026-10-22): a plate with the bun alone goes when no hot dog is in the hand.
function CustomerService:PickServeTool(player: Player, ticket: Orders.Ticket, bread: boolean?): Tool?
	const items = self.Dependencies.ItemService
	const held = items:Holding(player, HOT_DOG)
	if bread and held == nil then
		const plate = self:BreadPlateOf(player)
		if plate ~= nil then
			if items:GetHeld(player) ~= plate then
				self:Equip(player, plate)
			end
			return plate
		end
	end
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
	else
		-- DEC-311: the next tutorial customer (if any) comes with the next order
		self.TutorialServed += 1
		if self.TutorialServed < #TutorialRules.Orders then
			-- not RequestTutorial: this one is still around (it walks off with the plate); StepTutorial spawns the next
			self.TutorialWanted = true
			self.TutorialTryAt = 0
		end
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
	if self:IsBreadPlate(tool) then
		return nil -- a bun alone: nothing was cooked to grade
	end
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
	if self:IsArcMode() and customer.Drive == 0 and customer.CounterSlot == 0 then
		self:Collect(customer, mood)
		return
	end
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

-- Pickup arc (owner 2026-10-20, Provisional; Content.Restaurant.PickupArc) ---------------------------------------------
-- The customers whose order was taken wait on an arc outside the PICKUP counter instead of the PU-2..n line. "Hand Over"
-- still decides the sale at once (same verdict, pay and tip); a good one puts a copy of the plate on a counter slot, the
-- customer walks from the arc to that slot, takes it (Carrying) and goes on as LeaveServed did (table or takeaway).

function CustomerService:IsArcMode(): boolean
	return Content.Restaurant.PickupArc.Enabled and self:IsPickupMode()
end

-- PU-1 (in front of the counter), the outward direction (counter -> street) and the counter axis (towards +X / +Z)
function CustomerService:ArcFrame(): (Vector3?, Vector3, Vector3)
	const point = MapIndex.FindPoint(Pickup.point(1, Content.Restaurant.Binding.PickupPoint))
	if point == nil then
		return nil, Vector3.zAxis, Vector3.xAxis
	end
	const base = point.Position
	local outward = Vector3.zAxis
	for _, model in CollectionService:GetTagged(Content.Restaurant.Binding.PickupTag) do
		if model:IsA("Model") and model:IsDescendantOf(workspace) then
			const flat = (base - model:GetPivot().Position) * Vector3.new(1, 0, 1)
			if flat.Magnitude > 0.1 then
				outward = flat.Unit
			end
			break
		end
	end
	local along = outward:Cross(Vector3.yAxis)
	if along.X + along.Z < 0 then
		along = -along
	end
	return base, outward, along
end

-- World position of arc spot `spot` among PickupSize() spots. Spots never stand closer than Spacing: a ring holds what
-- fits at that radius, the rest go to the next ring (Spacing farther out); the first ring fills first.
function CustomerService:ArcSpot(spot: number): Vector3?
	const rules = Content.Restaurant.PickupArc
	const base, outward, along = self:ArcFrame()
	if base == nil then
		return nil
	end
	const count = math.max(self:PickupSize(), 1)
	local index = math.clamp(spot, 1, count)
	local left = count
	local radius = rules.Radius
	const spread = math.rad(rules.Spread)
	while true do
		const step = 2 * math.asin(math.min(rules.Spacing / (2 * radius), 1))
		const fits = math.max(math.floor(2 * spread / step) + 1, 1)
		if index <= fits or left <= fits then
			const inRing = math.min(left, fits)
			const t = if inRing > 1 then (index - 1) / (inRing - 1) else 0.5
			const angle = -spread + 2 * spread * t
			const centre = base + along * rules.Shift
			return centre + (outward * math.cos(angle) + along * math.sin(angle)) * radius
		end
		index -= fits
		left -= fits
		radius += rules.Spacing
	end
end

-- Straight to its arc spot, then faces the counter
function CustomerService:WalkArc(customer: Customer)
	const target = self:ArcSpot(customer.Pickup)
	if target == nil then
		return
	end
	customer.Move += 1
	const order = customer.Move
	const npc = self.Dependencies.NpcService
	task.spawn(function()
		npc:WalkToPosition(customer.Id, target, 10)
		if self.Customers[customer.Id] == customer and customer.Move == order then
			const base = self:ArcFrame()
			if base ~= nil then
				npc:Face(customer.Id, base - target)
			end
		end
	end)
end

-- Counter slot `slot`: where the plate stands (on the counter top) and where the customer stands to take it
function CustomerService:CounterSpot(slot: number): (Vector3?, Vector3?)
	const rules = Content.Restaurant.PickupArc
	const base, _, along = self:ArcFrame()
	if base == nil then
		return nil, nil
	end
	const centred = slot - (rules.Slots + 1) / 2
	const offset = along * (centred * rules.Gap)
	local plate: Vector3? = nil
	for _, model in CollectionService:GetTagged(Content.Restaurant.Binding.PickupTag) do
		if model:IsA("Model") and model:IsDescendantOf(workspace) then
			const pivot = model:GetPivot().Position + offset
			const params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { model }
			const hit = workspace:Raycast(pivot + Vector3.new(0, 6, 0), Vector3.new(0, -12, 0), params)
			plate = if hit then hit.Position + Vector3.new(0, 0.15, 0) else pivot
			break
		end
	end
	return plate, base + along * (centred * rules.StandGap)
end

-- A still copy of the hot dog Tool for the counter (no physics, no queries, no scripts); nil = nothing to copy
function CustomerService:MakeDisplay(tool: Tool): Model?
	const handle = tool:FindFirstChild("Handle")
	if handle == nil or not handle:IsA("BasePart") then
		return nil
	end
	const copy = tool:Clone()
	const model = Instance.new("Model")
	model.Name = "PickupPlate"
	for _, child in copy:GetChildren() do
		child.Parent = model
	end
	copy:Destroy()
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
		elseif item:IsA("LuaSourceContainer") then
			item:Destroy()
		end
	end
	const primary = model:FindFirstChild("Handle")
	if primary ~= nil and primary:IsA("BasePart") then
		model.PrimaryPart = primary
	end
	return model
end

-- Pivot of the counter plate `display` lying on `top`: the Handle (its pivot) is turned against the stack axis on the
-- kit hot dog, so an unrotated pivot stood the plate on its edge (same rule as Seating Meal's lay)
local function layOnCounter(display: Model, top: Vector3): CFrame
	const handle = display.PrimaryPart
	if handle == nil then
		return CFrame.new(top)
	end
	const anchor = handle:FindFirstChild(TOPPING_ANCHOR)
	const turn = if anchor ~= nil and anchor:IsA("Attachment") then anchor.CFrame.Rotation else CFrame.identity
	const up = turn.UpVector -- handle space
	const size = handle.Size
	const half = 0.5 * (math.abs(up.X) * size.X + math.abs(up.Y) * size.Y + math.abs(up.Z) * size.Z)
	-- the frame of the HANDLE, turned into the model's pivot: the kit hot dog's Handle.PivotOffset is turned (90 deg X,
	-- 180 deg Z), so a pivot laid flat stood the plate on its edge (owner print 2026-10-22; Seating Meal placeHandle)
	const at = CFrame.new(top + Vector3.new(0, half, 0)) * turn:Inverse()
	return at * handle.CFrame:ToObjectSpace(display:GetPivot())
end

-- Served at the pickup in arc mode: the plate on a counter slot, the walk arc -> counter, then LeaveServed goes on
function CustomerService:Collect(customer: Customer, mood: string?)
	const rules = Content.Restaurant.PickupArc
	local slot = 1
	for index = 1, rules.Slots do
		if self.CounterSlots[index] == nil then
			slot = index
			break
		end
	end
	self.CounterSlots[slot] = customer.Id
	customer.CounterSlot = slot
	const plateAt, standAt = self:CounterSpot(slot)
	const display = self.PendingDisplay
	self.PendingDisplay = nil
	if display ~= nil and plateAt ~= nil then
		local folder = self.DisplayFolder
		if folder == nil or folder.Parent == nil then
			const made = Instance.new("Folder")
			made.Name = "PickupPlates"
			made.Parent = workspace
			folder = made
			self.DisplayFolder = made
		end
		display:PivotTo(layOnCounter(display, plateAt :: Vector3))
		display.Parent = folder
		customer.Display = display
	elseif display ~= nil then
		display:Destroy()
	end
	customer.Move += 1
	const order = customer.Move
	const npc = self.Dependencies.NpcService
	task.spawn(function()
		if standAt ~= nil then
			npc:WalkToPosition(customer.Id, standAt, rules.CollectTimeout)
		end
		if self.Customers[customer.Id] ~= customer or customer.State == "Leaving" or customer.Move ~= order then
			self:ClearCollect(customer)
			return
		end
		if plateAt ~= nil and standAt ~= nil then
			npc:Face(customer.Id, (plateAt :: Vector3) - (standAt :: Vector3))
		end
		self:ClearCollect(customer)
		self:LeaveServed(customer, mood)
	end)
end

-- The counter plate and slot of a collecting customer go (taken, sent away, removed). CounterSlot stays > 0 so LeaveServed
-- does not collect twice; the record goes with it.
function CustomerService:ClearCollect(customer: Customer)
	const display = customer.Display
	customer.Display = nil
	if display ~= nil then
		display:Destroy()
	end
	const slot = customer.CounterSlot
	if slot > 0 and self.CounterSlots[slot] == customer.Id then
		self.CounterSlots[slot] = nil
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
			-- TAB-1 in the map (TASK-380): the order is taken at the tablet only (TabletService -> TakeOrderFor); a drive-thru
			-- car at the window takes it on its own prompt (owner 2026-10-20)
			if not self:CanAct(player, anchor, "Ordering") then
				return false
			end
			const id, customer = self:TicketAt(anchor)
			const talker = self.Talker
			if id ~= nil and talker ~= nil and talker.Talking(id) then
				return false -- its talk is running
			end
			return not self:IsTabletMode() or (customer ~= nil and customer.Drive == 1)
		end,
		Run = function(player: Player, anchor: Instance)
			-- the car at the window talks first (TabletDialog), like TAB-1; the order is taken at the end of the talk
			const id, customer = self:TicketAt(anchor)
			const talker = self.Talker
			if id ~= nil and customer ~= nil and customer.Drive == 1 and talker ~= nil and talker.Start(player, id) then
				return
			end
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
	-- The Closing last call still serves the queue (DEC-048, DEC-240; the 6 AM one too since owner 2026-10-21). Any other
	-- phase after selling (NightLost, Summary, Finale, RunEnd) empties the counter: everyone still around walks off with
	-- no outcome. The 6 AM beat (NightEnd) keeps the line for the night's last call right after it.
	const round = self.Dependencies.RoundService
	if phase == CLOSING and round:IsLastCall() then
		-- Last call: the line stays; tell the crew nobody else is coming
		self.Dependencies.RunStateService:Notify("all", "last_call", 0)
		return
	end
	if phase == NIGHT_END and NIGHT_LAST_CALL then
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
	const resting = (night and (t < self.CounterFreeAt or self.Dependencies.NpcService:IsTension())) or t < self.ReopenUntil
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
	-- the night too (DEC-311: the run starts at night); TUTORIAL_PHASES says when
	if not round:IsStarted() or not TUTORIAL_PHASES[round:GetPhase()] then
		return
	end
	const npc = self.Dependencies.NpcService
	-- owner 2026-10-20 (Provisional): from the 2nd tutorial customer on, a car at the drive-thru (the counter one when the
	-- map has no drive-thru)
	const driver = self.Driver
	if self.TutorialServed >= 1 and driver ~= nil then
		const ok, driven = pcall(driver.TryTutorial)
		if not ok then
			self:WarnOnce("driver_tutorial", `drive-thru tutorial spawn failed: {driven}`)
		elseif driven ~= nil then
			self.TutorialWanted = false
		end
		return
	end
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
		self:OnShutter(closed, player)
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
