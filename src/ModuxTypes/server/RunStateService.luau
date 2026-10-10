--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Charm = require(ReplicatedStorage.Packages.Charm)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Snapshots = require(ServerScriptService.server.Run.RunStateService.Snapshots)

export type LifeState = "Active" | "Down" | "Reviving" | "Spectator" | "Away"
export type RestoreMode = Snapshots.Mode
export type StashEntry = { Kind: string, Count: number, Extra: string? }
export type Member = {
	UserId: number,
	Class: string,
	State: LifeState,
	StateBeforeAway: LifeState?,
	Stash: { StashEntry },
	EverJoined: boolean,
}
export type Target = Player | "all"

export type Public = {
	Chances: Charm.Atom<number>,
	Counters: Charm.Atom<{ [string]: number }>,
	Endless: Charm.Atom<boolean>,
	LifeChanged: SignalLib.Signal<number, LifeState, LifeState>,
	MemberAway: SignalLib.Signal<Player, Member>,
	MemberJoined: SignalLib.Signal<Player, Member>,
	Members: Charm.Atom<{ [number]: Member }>,
	PriceParty: Charm.Atom<number>,
	Registry: Snapshots.Registry,
	Roster: Charm.Atom<{ number }>,
	RunId: string,
	Seed: Charm.Atom<number>,
	StartedAt: number,
	Setup: (self: Public) -> (),
	GetMember: (self: Public, player: Player) -> Member?,
	IsMember: (self: Public, player: Player) -> boolean,
	IsActive: (self: Public, player: Player) -> boolean,
	EmitLifeChanges: (self: Public, before: { [number]: Member }, after: { [number]: Member }) -> (),
	SetMember: (self: Public, userId: number, member: Member) -> (),
	SetLifeState: (self: Public, userId: number, state: LifeState) -> boolean,
	SetStash: (self: Public, userId: number, entries: { StashEntry }) -> boolean,
	Seat: (self: Public, userId: number) -> boolean,
	Admit: (self: Public, player: Player, class: string) -> (),
	Leave: (self: Public, player: Player) -> (),
	FixPriceParty: (self: Public) -> (),
	SpendChance: (self: Public) -> boolean,
	SetEndless: (self: Public, on: boolean) -> (),
	ResetDev: (self: Public) -> boolean,
	Notify: (self: Public, target: Target, key: string, value: number?) -> (),
	RegisterSnapshot: (self: Public, name: string, capture: Snapshots.Capture, restore: Snapshots.Restore) -> (),
	Capture: (self: Public) -> Snapshots.Snapshot,
	Restore: (self: Public, mode: RestoreMode) -> boolean,
	LastSnapshot: (self: Public) -> Snapshots.Snapshot?,
	CaptureRun: (self: Public) -> { [string]: any },
	RestoreRun: (self: Public, data: { [string]: any }, mode: RestoreMode) -> (),
	CaptureMembers: (self: Public) -> { [string]: any },
	RestoreMembers: (self: Public, data: { [string]: any }, mode: RestoreMode) -> (),
	Record: (self: Public) -> { PriceParty: number, RosterSize: number, Endless: boolean },
}

return {}
