--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Diner = require(ServerScriptService.server.Seating.SeatingService.Diner)
local Tables = require(ServerScriptService.server.Seating.SeatingService.Tables)

export type State = Tables.State
export type Record = { State: State, Price: number, Npc1: number, Npc2: number, Tip: number }
export type Spot = {
	Index: number,
	Model: Model?, -- nil = not in the binding (record still published: the client ignores it)
	Seats: { [number]: BasePart },
	Buy: Instance?, -- anchor of buy_in_place
	Clean: Instance?, -- anchor of clean_table (same instance as Buy when both are the runtime anchor)
	Node: string?, -- graph node next to the table (TBL-n, or the nearest node)
	Collide: { [BasePart]: boolean }, -- authored CanCollide of every part
	State: State,
	Price: number,
	Tip: number,
	Party: number?, -- leader NpcId of the party using it
}
export type Party = {
	Leader: number,
	Members: { Member },
	Couple: boolean,
	Table: number,
	Phase: Phase,
	StartedAt: number,
	Until: number, -- Seated: server time it stands up
	EatTime: number,
	Height: number, -- root Y while standing (approach / stand point)
	Token: number, -- bumped to cancel the walk thread
}
export type SeatParty = { Leader: number, Partner: number?, Couple: boolean, CustomerType: string }
export type Member = { Id: number, Seat: number, Rig: Diner.Rig? }
export type Phase = "Walking" | "Seated" | "Leaving"

export type Public = {
	ByMember: { [number]: number },
	Enabled: boolean,
	ForceSit: boolean,
	Live: boolean,
	Parties: { [number]: Party },
	PlaceAnchors: { Instance },
	Rng: Random,
	Spots: { Spot },
	Warned: { [string]: boolean },
	Setup: (self: Public) -> (),
	WarnOnce: (self: Public, key: string, message: string) -> (),
	Get: (self: Public, index: number) -> Spot?,
	Owned: (self: Public) -> number,
	IsUnlocked: (self: Public) -> boolean,
	IsNight: (self: Public) -> boolean,
	Diners: (self: Public) -> number,
	IsTense: (self: Public) -> boolean,
	InSitPhase: (self: Public) -> boolean,
	Record: (self: Public, spot: Spot) -> Record,
	Publish: (self: Public, spot: Spot, added: boolean?) -> (),
	FindModels: (self: Public) -> { [number]: Model },
	BuildSpot: (self: Public, index: number, model: Model?) -> Spot,
	FindPlaceAnchors: (self: Public) -> (),
	ApplyCollision: (self: Public, spot: Spot) -> (),
	ApplyPrompts: (self: Public, spot: Spot) -> (),
	Refresh: (self: Public) -> (),
	RefreshPlaceAnchors: (self: Public) -> (),
	SetState: (self: Public, spot: Spot, state: State) -> (),
	ResetTables: (self: Public) -> (),
	TrySeat: (self: Public, party: SeatParty) -> boolean,
	Reserve: (self: Public, index: number, party: SeatParty, seats: { number }, isNight: boolean) -> (),
	WalkIn: (self: Public, party: Party) -> (),
	SitDown: (self: Public, party: Party) -> (),
	StandUp: (self: Public, party: Party) -> (),
	Release: (self: Public, party: Party) -> (),
	OnRemoved: (self: Public, id: number) -> (),
	StandAll: (self: Public) -> (),
	Step: (self: Public) -> (),
	CanBuyAt: (self: Public, anchor: Instance) -> boolean,
	BuyAt: (self: Public, player: Player, anchor: Instance) -> (),
	CanClean: (self: Public, anchor: Instance) -> boolean,
	Clean: (self: Public, anchor: Instance) -> (),
	RegisterActions: (self: Public) -> (),
	Reseed: (self: Public) -> (),
	OnPhase: (self: Public, phase: string) -> (),
	DevCheck: (self: Public) -> (),
	DevBuy: (self: Public) -> number,
	DevForceSit: (self: Public) -> (),
	DevDirty: (self: Public, index: number, tip: number?) -> (),
	DevClean: (self: Public, index: number) -> (),
	DevList: (self: Public) -> string,
}

return {}
