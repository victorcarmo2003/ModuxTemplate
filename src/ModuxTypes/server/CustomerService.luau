--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local TutorialRules = require(ReplicatedStorage.shared.Tutorial.Rules)
local Adopt = require(ServerScriptService.server.Customer.CustomerService.Adopt)
local Group = require(ServerScriptService.server.Customer.CustomerService.Group)
local Orders = require(ServerScriptService.server.Customer.CustomerService.Orders)
local Queue = require(ServerScriptService.server.Customer.CustomerService.Queue)

export type State = "Arriving" | "Queued" | "Ordering" | "Waiting" | "Leaving"
export type Outcome = "spawned" | "skipped_queue_full" | "skipped_npc_cap"
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
	-- Tutorial customer (RequestTutorial): fixed order, endless patience, out of the ledger
	Tutorial: boolean,
	Model: Model?, -- tutorial customer: rig carrying TutorialRules.Attribute (cleared when the record goes)
}
export type Seater = (party: SeatParty) -> boolean
export type Patch = {
	State: State?,
	Order: { [string]: boolean }?,
	PatienceEndsAt: number?,
	Mood: string?,
}
export type Wire = {
	State: State,
	Slot: number,
	Order: { [string]: boolean },
	PatienceEndsAt: number,
	Mood: string,
	Order2: { [string]: boolean }?,
	Leader: number?,
}
export type SaleResult = "Perfect" | "Complete" | "Incomplete" | "Wrong" | "Left" | "Refused"
export type Variant = "blank" | "mirror" | "raincoat"
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
	Customers: { [number]: Customer },
	Enabled: boolean,
	ForcedPair: Group.Pair?,
	Fronted: SignalLib.Signal<number>,
	Joined: SignalLib.Signal<number>,
	LastWasPair: boolean,
	Left: SignalLib.Signal<number, LeaveReason>,
	Line: Queue.Queue,
	NextSpawnAt: number,
	NoticeAt: { [Player]: { [string]: number } },
	OrderRng: Random,
	Party: number,
	Removed: SignalLib.Signal<number>,
	Rng: Random,
	Seater: Seater?,
	ServeRules: { ServeRule },
	SpawnAttempted: SignalLib.Signal<Outcome>,
	Tickets: { [number]: Orders.Ticket },
	TutorialRng: Random,
	TutorialTryAt: number,
	TutorialWanted: boolean,
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
	IsNightShift: (self: Public) -> boolean,
	NightRow: (self: Public) -> Content.Night?,
	MaxCustomers: (self: Public) -> number,
	ConnectedMembers: (self: Public) -> number,
	MeanInterval: (self: Public) -> number?,
	NextInterval: (self: Public) -> number?,
	Flow: (self: Public) -> { Party: number, MeanInterval: number, QueueSize: number, NextSpawnAt: number },
	Record: (self: Public, customer: Customer) -> Wire,
	Publish: (self: Public, customer: Customer, added: boolean) -> (),
	Walk: (self: Public, customer: Customer, node: string, avoidQueue: boolean, done: (ok: boolean) -> ()) -> (),
	Refresh: (self: Public) -> (),
	Reached: (self: Public, customer: Customer, slot: number) -> (),
	Join: (self: Public, customer: Customer) -> (),
	Attempt: (self: Public) -> (Outcome, number?),
	RollPair: (self: Public) -> Group.Pair?,
	SpawnPair: (self: Public, pair: Group.Pair) -> number?,
	Create: (self: Public, id: number, variant: Variant?, leader: number?, tutorial: boolean?) -> (),
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
	RemoveAll: (self: Public) -> (),
	Update: (self: Public, id: number, patch: Patch) -> boolean,
	GetTicket: (self: Public, id: number) -> Orders.Ticket?,
	OpenTicket: (self: Public, id: number) -> (),
	LineOwner: (self: Public, customer: Customer, index: number) -> number,
	ShowPending: (self: Public, customer: Customer, ticket: Orders.Ticket) -> (),
	OnFronted: (self: Public, id: number) -> (),
	TicketAt: (self: Public, anchor: Instance) -> (number?, Customer?, Orders.Ticket?),
	CanAct: (self: Public, player: Player, anchor: Instance, state: State?) -> boolean,
	NotifyThrottled: (self: Public, player: Player, key: string) -> (),
	NoticeShopClosed: (self: Public, player: Player, anchor: Instance) -> (),
	Settle: (self: Public, id: number, result: SaleResult, amount: number) -> (),
	TakeOrder: (self: Public, player: Player, anchor: Instance) -> (),
	Serve: (self: Public, player: Player, anchor: Instance) -> (),
	Judge: (self: Public, ticket: Orders.Ticket, tool: Tool, override: SaleResult?) -> (number?, Orders.Verdict),
	Conclude: (self: Public, customer: Customer, ticket: Orders.Ticket) -> (),
	OfferSeat: (self: Public, customer: Customer) -> boolean,
	SettlePending: (self: Public, customer: Customer, ticket: Orders.Ticket, result: SaleResult) -> (),
	Refuse: (self: Public, player: Player, anchor: Instance) -> (),
	GiveUp: (self: Public, id: number) -> (),
	StepOrders: (self: Public, t: number) -> (),
	RegisterOrders: (self: Public) -> (),
	Reseed: (self: Public) -> (),
	OnPhase: (self: Public, phase: string) -> (),
	Step: (self: Public) -> (),
	StepPairs: (self: Public, t: number) -> (),
	TutorialCustomer: (self: Public) -> Customer?,
	HasTutorial: (self: Public) -> boolean,
	RequestTutorial: (self: Public) -> boolean,
	EndTutorial: (self: Public) -> (),
	StepTutorial: (self: Public, t: number) -> (),
	DevSpawnPair: (self: Public, leader: string?, partner: string?) -> (Outcome, number?),
	DevSpawn: (self: Public) -> (Outcome, number?),
}

return {}
