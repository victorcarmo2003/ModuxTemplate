--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Motion = require(ReplicatedStorage.shared.Traffic.Motion)
local Paths = require(ServerScriptService.server.Traffic.TrafficService.Paths)

type Route = typeof(Content.Traffic.Routes.List[1])
export type Record = {
	Route: number,
	Look: number,
	AnchorAt: number,
	AnchorDist: number,
	StopDist: number,
	HeldUntil: number,
}
type Car = {
	Id: number,
	Route: Route,
	RouteIndex: number,
	Geo: Paths.Geo,
	Look: number,
	Record: Record,
	Cursor: Motion.Cursor,
	Dist: number,
	Speed: number,
	-- route has a PARE: Juniper arm (not preferential)
	Juniper: boolean,
	-- PARE lines already served
	PareDone: { [string]: boolean },
	-- server time the car parked on its current stop (nil = not parked)
	ParkedAt: number?,
	-- pending pull away of a parked follower (FollowDelay)
	ReleaseAt: number?,
	-- StopDist that failed the in-place check for the current record (retried only when it changes)
	Refused: number?,
	-- UserIds this car already hit (1 hit per car per player, §8.2 d)
	Hits: { [number]: boolean },
}
type Reservation = {
	Npc: number,
	GrantedAt: number,
	ExpiresAt: number,
}
type BoxHold = {
	Car: number,
	From: number,
	To: number,
}

export type Public = {
	BoxHolds: { BoxHold },
	Cars: { [number]: Car },
	Enabled: boolean,
	GeoRetryAt: { [string]: number },
	Geos: { [string]: Paths.Geo },
	Holds: { [string]: boolean },
	Immune: { [number]: number },
	LaneLast: { [string]: number },
	LastHit: { [number]: number },
	LastRelease: { [string]: number },
	NextSpawn: { [string]: number },
	Reservations: { [string]: Reservation },
	Rng: Random,
	Warned: { [string]: boolean },
	Setup: (self: Public) -> (),
	WarnOnce: (self: Public, key: string, message: string) -> (),
	IsHeld: (self: Public) -> boolean,
	Count: (self: Public) -> number,
	IsReserved: (self: Public, cw: string) -> boolean,
	GeoOf: (self: Public, route: Route) -> Paths.Geo?,
	RawStop: (self: Public, car: Car) -> (number?, string?),
	DesiredStop: (self: Public, car: Car) -> number,
	Publish: (self: Public, car: Car, added: boolean) -> (),
	SetRecord: (self: Public, car: Car, record: Record, t: number) -> (),
	PullAway: (self: Public, car: Car, stop: number, t: number) -> (),
	Restop: (self: Public, car: Car, stop: number, t: number) -> boolean,
	BoxFree: (self: Public, from: number, to: number, t: number, except: Car?) -> boolean,
	TryPare: (self: Public, car: Car, line: string, t: number) -> boolean,
	ReserveCrossing: (self: Public, cw: string, npcId: number) -> boolean,
	ReleaseCrossing: (self: Public, cw: string, npcId: number) -> (),
	EndReservation: (self: Public, key: string, t: number) -> (),
	Hold: (self: Public, reason: string, on: boolean) -> (),
	FreeSlot: (self: Public) -> number?,
	Remove: (self: Public, car: Car) -> (),
	CanSpawn: (self: Public, route: Route, geo: Paths.Geo, t: number) -> boolean,
	Spawn: (self: Public, route: Route, t: number) -> Car?,
	PickRoute: (self: Public, group: string, night: boolean, t: number) -> Route?,
	SpawnPhaseOk: (self: Public) -> boolean,
	TrySpawn: (self: Public, t: number) -> (),
	Reconcile: (self: Public, t: number) -> (),
	Step: (self: Public) -> (),
	OnCarHit: (self: Public, player: Player, id: number) -> (),
	ApplyHit: (self: Public, player: Player, car: Car?, impulse: Vector3) -> boolean,
	Status: (self: Public) -> string,
	DevSpawn: (self: Public, routeKey: string?) -> string,
	DevClear: (self: Public) -> number,
	DevHit: (self: Public, player: Player) -> boolean,
}

return {}
