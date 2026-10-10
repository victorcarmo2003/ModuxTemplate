--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Charm = require(ReplicatedStorage.Packages.Charm)
local Content = require(ReplicatedStorage.shared.Content)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Snapshots = require(ServerScriptService.server.Run.RunStateService.Snapshots)

export type RestoreMode = Snapshots.Mode
export type Member = {
	UserId: number,
	Class: string, -- key of Content.Classes, locked when the member is first admitted
	State: LifeState,
	StateBeforeAway: LifeState?,
	Sanity: number,
	Stash: { StashEntry },
	CoffeeReadyAt: number,
	SeenAnomalies: { [string]: boolean },
	RevivesTonight: number,
	EverJoined: boolean,
}
export type Target = Player | "all"
export type LifeState = "Active" | "Down" | "Reviving" | "Spectator" | "Away"
export type StashEntry = { Kind: string, Count: number, Extra: string? }

export type Public = {
	Chances: Charm.Atom<number>,
	Counters: Charm.Atom<{ [string]: number }>,
	Endless: Charm.Atom<boolean>,
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
	SetMember: (self: Public, userId: number, member: Member) -> (),
	Seat: (self: Public, userId: number) -> boolean,
	Admit: (self: Public, player: Player, class: string) -> (),
	Leave: (self: Public, player: Player) -> (),
	FixPriceParty: (self: Public) -> (),
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
