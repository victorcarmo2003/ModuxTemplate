--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Queue = require(ServerScriptService.server.Customer.CustomerService.Queue)

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
export type State = "Arriving" | "Queued" | "Ordering" | "Waiting" | "Leaving"

export type Public = {
	Customers: { [number]: Customer },
	Enabled: boolean,
	Fronted: SignalLib.Signal<number>,
	Joined: SignalLib.Signal<number>,
	Left: SignalLib.Signal<number, LeaveReason>,
	Line: Queue.Queue,
	NextSpawnAt: number,
	Party: number,
	Removed: SignalLib.Signal<number>,
	Rng: Random,
	SpawnAttempted: SignalLib.Signal<Outcome>,
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
	Reseed: (self: Public) -> (),
	OnPhase: (self: Public, phase: string) -> (),
	Step: (self: Public) -> (),
	DevSpawn: (self: Public) -> (Outcome, number?),
}

return {}
