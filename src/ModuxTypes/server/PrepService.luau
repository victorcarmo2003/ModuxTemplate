--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Charm = require(ReplicatedStorage.Packages.Charm)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Session = require(ServerScriptService.server.Prep.PrepService.Session)
local Validate = require(ServerScriptService.server.Prep.PrepService.Validate)

export type SeatRecord = { User: number, Step: string, Ticket: number, Since: number, Plate: number }

export type Public = {
	Active: boolean,
	Buckets: { [Player]: Session.Buckets },
	BySeat: { [number]: Session.Seat },
	Count: number,
	Entered: SignalLib.Signal<Player, number>,
	Left: SignalLib.Signal<Player, number, string>,
	LockedUntil: { [Player]: number },
	Published: { [number]: boolean },
	Seats: Charm.Atom<{ [number]: SeatRecord }>,
	Sessions: { [Player]: Session.Seat },
	Warned: { [string]: boolean },
	Setup: (self: Public) -> (),
	SeatOf: (self: Public, player: Player) -> number?,
	IsSeated: (self: Public, player: Player) -> boolean,
	UserAt: (self: Public, station: number) -> Player?,
	StationCount: (self: Public) -> number,
	WantedCount: (self: Public) -> number,
	WriteSeat: (self: Public, station: number, record: SeatRecord?) -> (),
	PublishSeat: (self: Public, seat: Session.Seat) -> (),
	ClearMask: (self: Public, seat: Session.Seat) -> (),
	Grow: (self: Public) -> (),
	Recount: (self: Public) -> (),
	PushSeats: (self: Public) -> (),
	StationModel: (self: Public, station: number) -> Instance?,
	StationOfAnchor: (self: Public, anchor: Instance) -> (Instance?, number?),
	StandOf: (self: Public, station: number, step: string?) -> CFrame?,
	WorkDistance: (self: Public, position: Vector3) -> number?,
	NextSeat: (self: Public) -> number?,
	StepOfAnchor: (self: Public, anchor: Instance) -> string,
	Reply: (self: Public, player: Player, act: string, ok: boolean, reason: string, grade: string?, value: number?) -> (),
	Allow: (self: Public, player: Player, kind: string) -> boolean,
	Seated: (self: Public, player: Player, act: string) -> Session.Seat?,
	CheckEnter: (self: Public, player: Player, station: number, skipReach: boolean?, step: string?) -> (string, CFrame?),
	Enter: (self: Public, player: Player, station: number, skipReach: boolean?, step: string?) -> (boolean, string),
	Release: (self: Public, player: Player, reason: string, silent: boolean?) -> boolean,
	ForceExit: (self: Public, player: Player, reason: string) -> boolean,
	ForceExitAll: (self: Public, reason: string) -> number,
	Begin: (self: Public, player: Player, seat: Session.Seat) -> (boolean, string, number),
	Finish: (self: Public, player: Player, seat: Session.Seat, summary: Validate.Summary) -> (boolean, string, string, number),
	DropPlate: (self: Public, player: Player, seat: Session.Seat) -> (),
	Trash: (self: Public, player: Player, seat: Session.Seat) -> (boolean, string),
	AcceptMask: (self: Public, seat: Session.Seat, mask: number) -> (),
	OnTab: (self: Public, player: Player, step: string, ticket: number, plate: number?) -> (),
	OnGrill: (self: Public, player: Player, act: string, slot: number) -> (),
	OnFinish: (self: Public, player: Player, summary: Validate.Summary) -> (),
	OnOrder: (self: Public, player: Player, act: string, npc: number) -> (),
	ConnectPackets: (self: Public) -> (),
	RegisterWork: (self: Public) -> (),
	Sweep: (self: Public) -> (),
	DevGuard: (self: Public) -> (),
	DevSeats: (self: Public) -> string,
	DevEnter: (self: Public, player: Player, station: number, step: string?) -> string,
	DevWhy: (self: Public, player: Player, station: number, reason: string) -> string,
	DevPlate: (self: Public, player: Player) -> string,
	DevLeave: (self: Public, player: Player) -> string,
	DevFinish: (self: Public, player: Player, keys: { string }, force: boolean) -> string,
}

return {}
