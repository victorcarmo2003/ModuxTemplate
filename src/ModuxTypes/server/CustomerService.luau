--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
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
}
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
}
export type SaleResult = "Perfect" | "Complete" | "Incomplete" | "Wrong" | "Left" | "Refused"
export type ActedAction = "take_order" | "serve" | "refuse" | "give_up"

export type Public = {
	Acted: SignalLib.Signal<number, ActedAction, Player?, SaleResult?>,
	Customers: { [number]: Customer },
	Enabled: boolean,
	Fronted: SignalLib.Signal<number>,
	Joined: SignalLib.Signal<number>,
	Left: SignalLib.Signal<number, LeaveReason>,
	Line: Queue.Queue,
	NextSpawnAt: number,
	NoticeAt: { [Player]: { [string]: number } },
	OrderRng: Random,
	Party: number,
	Removed: SignalLib.Signal<number>,
	Rng: Random,
	SpawnAttempted: SignalLib.Signal<Outcome>,
	Tickets: { [number]: Orders.Ticket },
	Warned: { [string]: boolean },
	Setup: (self: Public) -> (),
	WarnOnce: (self: Public, key: string, message: string) -> (),
	Get: (self: Public, id: number) -> Customer?,
	IdOf: (self: Public, instance: Instance) -> number?,
	Front: (self: Public) -> number?,
	Count: (self: Public) -> number,
	Occupants: (self: Public) -> number,
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
	Create: (self: Public, id: number) -> (),
	SetPrompts: (self: Public, id: number, enabled: boolean) -> (),
	ExitRoute: (self: Public, node: string) -> (string?, boolean),
	Leave: (self: Public, id: number, mood: string?, reason: LeaveReason?) -> boolean,
	Remove: (self: Public, id: number) -> (),
	Forget: (self: Public, id: number) -> boolean,
	SendAllAway: (self: Public) -> (),
	RemoveAll: (self: Public) -> (),
	Update: (self: Public, id: number, patch: Patch) -> boolean,
	GetTicket: (self: Public, id: number) -> Orders.Ticket?,
	OpenTicket: (self: Public, id: number) -> (),
	OnFronted: (self: Public, id: number) -> (),
	TicketAt: (self: Public, anchor: Instance) -> (number?, Customer?, Orders.Ticket?),
	CanAct: (self: Public, player: Player, anchor: Instance, state: State?) -> boolean,
	NotifyThrottled: (self: Public, player: Player, key: string) -> (),
	NoticeShopClosed: (self: Public, player: Player, anchor: Instance) -> (),
	Settle: (self: Public, id: number, result: SaleResult, amount: number) -> (),
	TakeOrder: (self: Public, player: Player, anchor: Instance) -> (),
	Serve: (self: Public, player: Player, anchor: Instance) -> (),
	Refuse: (self: Public, player: Player, anchor: Instance) -> (),
	GiveUp: (self: Public, id: number) -> (),
	StepOrders: (self: Public, t: number) -> (),
	RegisterOrders: (self: Public) -> (),
	Reseed: (self: Public) -> (),
	OnPhase: (self: Public, phase: string) -> (),
	Step: (self: Public) -> (),
	DevSpawn: (self: Public) -> (Outcome, number?),
}

return {}
