--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local TutorialRules = require(ReplicatedStorage.shared.Tutorial.Rules)
local Adopt = require(ServerScriptService.server.Customer.CustomerService.Adopt)
local Group = require(ServerScriptService.server.Customer.CustomerService.Group)
local Orders = require(ServerScriptService.server.Customer.CustomerService.Orders)
local Pickup = require(ServerScriptService.server.Customer.CustomerService.Pickup)
local Queue = require(ServerScriptService.server.Customer.CustomerService.Queue)

export type State = "Arriving" | "Queued" | "Ordering" | "Waiting" | "Leaving"
export type Outcome = "spawned" | "skipped_queue_full" | "skipped_npc_cap"
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
	-- Pickup arc (owner 2026-10-20): reached the arc once (later moves go straight), and the counter slot it walks to for its
	-- plate (1..PickupArc.Slots, 0 = not collecting; Display = its plate on the counter)
	Arc: boolean,
	CounterSlot: number,
	Display: Model?,
}
export type Driver = {
	Try: (party: number, counter: number) -> number?,
	TryTutorial: () -> number?,
	Left: (id: number) -> (),
}
export type Seater = {
	Offer: (party: SeatParty) -> boolean,
	Left: (leader: number, ate: boolean) -> (),
}
export type Patch = {
	State: State?,
	Order: { [string]: boolean }?,
	PatienceEndsAt: number?,
	Phase: Orders.Phase?,
	PatienceSpan: number?,
	Mood: string?,
}
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
export type SaleResult = "Perfect" | "Complete" | "Incomplete" | "Wrong" | "Left" | "Refused" | "Slow"
export type Variant = "blank" | "mirror" | "raincoat" | "shake" | "neck" | "eyes" | "bighead" | "float" | "stare" | "banger"
export type CustomerActorSpec = {
	Variant: Variant,
	CustomerType: string?,
	Species: string?,
	Outfit: string?,
	CopyOf: number?,
	From: string?,
}
export type ActedAction = "take_order" | "serve" | "refuse" | "give_up"
export type ServeRule = (customer: Customer, tool: Tool, player: Player) -> SaleResult?
export type SeatParty = {
	Leader: number,
	Partner: number?,
	Couple: boolean,
	CustomerType: string, -- leader's type (SitChance)
}

export type Public = {
	Acted: SignalLib.Signal<number, ActedAction, Player?, SaleResult?>,
	ActorRng: Random,
	CounterFreeAt: number,
	CounterSlots: { [number]: number },
	CounterWasFull: boolean,
	Customers: { [number]: Customer },
	DevNoArrivals: boolean,
	DisplayFolder: Folder?,
	Driver: Driver?,
	EmptyLimit: number,
	EmptySince: number,
	Enabled: boolean,
	ForcedOrders: { { string } }?,
	ForcedPair: Group.Pair?,
	Fronted: SignalLib.Signal<number>,
	GuaranteeRng: Random,
	Joined: SignalLib.Signal<number>,
	LastComplaint: number,
	LastWasPair: boolean,
	Left: SignalLib.Signal<number, LeaveReason>,
	Line: Queue.Queue,
	LullCount: number,
	NextSpawnAt: number,
	NoticeAt: { [Player]: { [string]: number } },
	OrderNumber: number,
	OrderRng: Random,
	Ordered: SignalLib.Signal<number, Player>,
	Party: number,
	PendingDisplay: Model?,
	PickupLine: Pickup.Pickup,
	Removed: SignalLib.Signal<number>,
	ReopenUntil: number,
	Rng: Random,
	Seater: Seater?,
	ServeRules: { ServeRule },
	ShutThread: thread?,
	SpawnAttempted: SignalLib.Signal<Outcome>,
	SpawnHold: (() -> boolean)?,
	SpawnHolds: { [string]: boolean },
	Tickets: { [number]: Orders.Ticket },
	TutorialRng: Random,
	TutorialServed: number,
	TutorialTryAt: number,
	TutorialWanted: boolean,
	WaitShutThread: thread?,
	Warned: { [string]: boolean },
	Setup: (self: Public) -> (),
	WarnOnce: (self: Public, key: string, message: string) -> (),
	Get: (self: Public, id: number) -> Customer?,
	IdOf: (self: Public, instance: Instance) -> number?,
	Front: (self: Public) -> number?,
	Count: (self: Public) -> number,
	Occupants: (self: Public) -> number,
	HasActor: (self: Public) -> boolean,
	SetAdopter: (self: Public, adopter: Adopt.Adopter?) -> Adopt.Controls,
	SetSeater: (self: Public, seater: Seater?) -> (),
	IsCounterEmpty: (self: Public) -> boolean,
	QueueSize: (self: Public) -> number,
	PhaseRow: (self: Public) -> Content.Phase?,
	IsSelling: (self: Public) -> boolean,
	IsPaused: (self: Public) -> boolean,
	SetSpawnHold: (self: Public, hold: () -> boolean) -> (),
	HoldSpawns: (self: Public, reason: string, on: boolean) -> (),
	DevSetArrivals: (self: Public, on: boolean) -> (),
	SpawnHeld: (self: Public) -> boolean,
	IsNightShift: (self: Public) -> boolean,
	NightRow: (self: Public) -> Content.Night?,
	MaxCustomers: (self: Public) -> number,
	ConnectedMembers: (self: Public) -> number,
	MeanInterval: (self: Public) -> number?,
	NextInterval: (self: Public) -> number?,
	Flow: (self: Public) -> { Party: number, MeanInterval: number, QueueSize: number, NextSpawnAt: number },
	PickupPoints: (self: Public) -> number,
	IsPickupMode: (self: Public) -> boolean,
	IsTabletMode: (self: Public) -> boolean,
	PickupSize: (self: Public) -> number,
	PickupIds: (self: Public) -> { number },
	IsPickupFull: (self: Public) -> boolean,
	SetDriver: (self: Public, driver: Driver?) -> (),
	JoinDrive: (self: Public, id: number) -> (),
	SetDriveSpot: (self: Public, id: number, spot: number) -> (),
	FrontDrive: (self: Public, id: number) -> boolean,
	DriveFront: (self: Public) -> number?,
	Record: (self: Public, customer: Customer) -> Wire,
	Publish: (self: Public, customer: Customer, added: boolean) -> (),
	Walk: (self: Public, customer: Customer, node: string, avoidQueue: boolean, done: (ok: boolean) -> ()) -> (),
	Refresh: (self: Public) -> (),
	RefreshPickup: (self: Public) -> (),
	SetPickupPrompt: (self: Public, enabled: boolean) -> (),
	IsPickupAnchor: (self: Public, anchor: Instance) -> boolean,
	EnterPickup: (self: Public, customer: Customer) -> (),
	Reached: (self: Public, customer: Customer, slot: number) -> (),
	Join: (self: Public, customer: Customer) -> (),
	Attempt: (self: Public) -> (Outcome, number?),
	RollPair: (self: Public) -> Group.Pair?,
	SpawnPair: (self: Public, pair: Group.Pair) -> number?,
	Create: (self: Public, id: number, variant: Variant?, leader: number?, tutorial: boolean?, drive: number?) -> (),
	SpawnActor: (self: Public, spec: CustomerActorSpec) -> number?,
	AddServeRule: (self: Public, rule: ServeRule) -> () -> (),
	ServeOverride: (self: Public, customer: Customer, tool: Tool, player: Player) -> SaleResult?,
	SetPrompts: (self: Public, id: number, enabled: boolean) -> (),
	ExitRoute: (self: Public, node: string) -> (string?, boolean),
	Leave: (self: Public, id: number, mood: string?, reason: LeaveReason?, dining: boolean?) -> boolean,
	WalkOut: (self: Public, customer: Customer) -> (),
	Dismiss: (self: Public, id: number) -> boolean,
	SetHeld: (self: Public, id: number, held: boolean) -> (),
	Remove: (self: Public, id: number) -> (),
	Forget: (self: Public, id: number) -> boolean,
	SendAllAway: (self: Public) -> (),
	LineAwayIds: (self: Public, waiting: boolean?) -> { number },
	ComplainLineAway: (self: Public, player: Player?, waiting: boolean?) -> (),
	OnShutter: (self: Public, closed: boolean, player: Player?) -> (),
	CancelShutWait: (self: Public) -> (),
	SendLineAway: (self: Public, player: Player?, waiting: boolean?) -> (),
	RemoveAll: (self: Public) -> (),
	Update: (self: Public, id: number, patch: Patch) -> boolean,
	GetTicket: (self: Public, id: number) -> Orders.Ticket?,
	OpenTicket: (self: Public, id: number) -> (),
	LineOwner: (self: Public, customer: Customer, index: number) -> number,
	ShowPending: (self: Public, customer: Customer, ticket: Orders.Ticket) -> (),
	OnFronted: (self: Public, id: number) -> (),
	PausePatience: (self: Public, id: number, on: boolean) -> boolean,
	IsPatiencePaused: (self: Public, id: number) -> boolean,
	TicketAt: (self: Public, anchor: Instance) -> (number?, Customer?, Orders.Ticket?),
	CanAct: (self: Public, player: Player, anchor: Instance, state: State?) -> boolean,
	CanActOn: (self: Public, player: Player, id: number?, state: State?) -> boolean,
	NotifyThrottled: (self: Public, player: Player, key: string) -> (),
	NoticeShopClosed: (self: Public, player: Player, anchor: Instance) -> (),
	Settle: (self: Public, id: number, result: SaleResult, amount: number) -> (),
	TakeOrder: (self: Public, player: Player, anchor: Instance) -> (),
	RefusePickupFull: (self: Public, player: Player, customer: Customer) -> boolean,
	TakeOrderFor: (self: Public, player: Player, id: number?) -> boolean,
	OpenOrder: (self: Public, player: Player, id: number, customer: Customer, ticket: Orders.Ticket) -> (),
	SeatAtOrder: (self: Public, customer: Customer) -> (),
	PendingToppings: (self: Public, id: number) -> { { string } },
	IsWaitingAtTable: (self: Public, id: number) -> boolean,
	Serve: (self: Public, player: Player, anchor: Instance) -> (),
	ServeAtPickup: (self: Public, player: Player, target: number?) -> (SaleResult?, number?),
	TicketOwner: (self: Public, tool: Tool) -> number?,
	CanServeTable: (self: Public, player: Player, id: number) -> boolean,
	ServeTable: (self: Public, player: Player, id: number) -> (),
	ServeFor: (self: Public, player: Player, tool: Tool?, target: number) -> SaleResult?,
	ServeCustomer: (self: Public, player: Player, id: number, customer: Customer, ticket: Orders.Ticket, picked: Tool?) -> SaleResult?,
	OtherHotDog: (self: Public, player: Player, except: Tool, order: { string }) -> Tool?,
	PickServeTool: (self: Public, player: Player, ticket: Orders.Ticket) -> Tool?,
	Equip: (self: Public, player: Player, tool: Tool) -> (),
	SellLine: (self: Public, id: number, customer: Customer, ticket: Orders.Ticket, player: Player, tool: Tool, index: number, verdict: Orders.Verdict, at: number) -> SaleResult,
	KeepLook: (self: Public, customer: Customer, index: number, tool: Tool) -> (),
	GradeOf: (self: Public, tool: Tool, line: Orders.Line, ticket: Orders.Ticket, at: number) -> string?,
	Judge: (self: Public, ticket: Orders.Ticket, tool: Tool, override: SaleResult?) -> (number?, Orders.Verdict),
	Conclude: (self: Public, customer: Customer, ticket: Orders.Ticket) -> (),
	LeaveServed: (self: Public, customer: Customer, mood: string?) -> (),
	SetCarrying: (self: Public, customer: Customer) -> (),
	IsArcMode: (self: Public) -> boolean,
	ArcFrame: (self: Public) -> (Vector3?, Vector3, Vector3),
	ArcSpot: (self: Public, spot: number) -> Vector3?,
	WalkArc: (self: Public, customer: Customer) -> (),
	CounterSpot: (self: Public, slot: number) -> (Vector3?, Vector3?),
	MakeDisplay: (self: Public, tool: Tool) -> Model?,
	Collect: (self: Public, customer: Customer, mood: string?) -> (),
	ClearCollect: (self: Public, customer: Customer) -> (),
	OfferSeat: (self: Public, customer: Customer) -> boolean,
	SettlePending: (self: Public, customer: Customer, ticket: Orders.Ticket, result: SaleResult) -> (),
	GiveUp: (self: Public, id: number) -> (),
	StepOrders: (self: Public, t: number) -> (),
	RegisterOrders: (self: Public) -> (),
	Reseed: (self: Public) -> (),
	OnPhase: (self: Public, phase: string) -> (),
	HasLiveCustomer: (self: Public) -> boolean,
	StepGuarantee: (self: Public, t: number) -> (),
	Step: (self: Public) -> (),
	StepPairs: (self: Public, t: number) -> (),
	TutorialCustomer: (self: Public) -> Customer?,
	HasTutorial: (self: Public) -> boolean,
	RequestTutorial: (self: Public) -> boolean,
	EndTutorial: (self: Public) -> (),
	StepTutorial: (self: Public, t: number) -> (),
	DevSpawnPair: (self: Public, leader: string?, partner: string?, orders: { { string } }?) -> (Outcome, number?),
	DevSpawn: (self: Public) -> (Outcome, number?),
	DevPickupState: (self: Public) -> string,
	DevPickupTest: (self: Public) -> { string },
}

return {}
