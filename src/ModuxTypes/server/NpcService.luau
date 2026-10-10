--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Look = require(ServerScriptService.server.Npc.NpcService.Look)
local Pool = require(ServerScriptService.server.Npc.NpcService.Pool)
local Walker = require(ServerScriptService.server.Npc.NpcService.Walker)

export type Role = "Customer" | "Thief" | "Actor"
export type Npc = {
	Id: number,
	Rig: Pool.Rig,
	Role: Role,
	CustomerType: string, -- "" for the thief
	Species: string,
	Outfit: string,
	Variant: Variant?, -- Role "Actor" only
	Node: string, -- last graph node reached (spawn point at first)
	Walk: number, -- walk order counter: a new order or a despawn cancels the running one
}
export type SpawnRequest = {
	Role: Role?, -- default "Customer". "Thief": Quick Quentin; CustomerType/Species/Outfit are ignored
	Variant: Variant?, -- required with Role "Actor", refused with any other role
	CustomerType: string?, -- default: weighted draw among the types unlocked this shift (Look.PickType)
	Species: string?, -- forced species (must belong to the type)
	Outfit: string?, -- forced civil outfit
	From: string?, -- spawn node/point id (default: SPAWN_POINTS)
	Rng: Random?, -- seeded Random of the run (architecture.md §4 rule 6); default: the service Random
}
export type WalkOptions = {
	AvoidQueue: boolean?, -- default true: Q1..Q5 only as start or goal
	AvoidCrossings: boolean?, -- default false (thief, wave 2)
	Face: boolean?, -- default true: on arrival, face the MapPoint direction of the goal (when it is a point)
}
export type Variant = "blank" | "mirror" | "raincoat"

export type Public = {
	Active: { [number]: Npc },
	ByModel: { [Model]: number },
	Despawned: SignalLib.Signal<number>,
	Enabled: boolean,
	Folder: Folder?,
	Frame: number,
	NextId: number,
	Parking: Folder?,
	Pool: Pool.Pool,
	Random: Random,
	RouteFrame: number,
	RoutesInFrame: number,
	Spawned: SignalLib.Signal<number, Model>,
	Tension: boolean,
	Warned: { [string]: boolean },
	Setup: (self: Public) -> (),
	WarnOnce: (self: Public, key: string, message: string) -> (),
	Get: (self: Public, id: number) -> Npc?,
	GetModel: (self: Public, id: number) -> Model?,
	Anchors: (self: Public, id: number) -> (Attachment?, Attachment?),
	IdOf: (self: Public, instance: Instance) -> number?,
	GetNode: (self: Public, id: number) -> string?,
	Count: (self: Public) -> number,
	Capacity: (self: Public) -> number,
	PoolStats: (self: Public) -> (number, number),
	Pack: (self: Public) -> string,
	PackFor: (self: Public, role: Role, outfit: string) -> string,
	IsTension: (self: Public) -> boolean,
	PickType: (self: Public, rng: Random?) -> string?,
	AllocateId: (self: Public) -> number?,
	PickSpawnPoint: (self: Public, isNight: boolean, rng: Random) -> string,
	Choose: (self: Public, r: SpawnRequest, rng: Random) -> (Look.Choice?, string?, string?),
	Spawn: (self: Public, request: SpawnRequest?) -> number?,
	Despawn: (self: Public, id: number) -> boolean,
	DespawnAll: (self: Public) -> (),
	Route: (self: Public, from: string, to: string, options: WalkOptions?) -> { string }?,
	WalkTo: (self: Public, id: number, target: string, options: WalkOptions?) -> boolean,
	Crossing: (self: Public, id: number, at: { [number]: string }) -> Walker.Crossing?,
	Stop: (self: Public, id: number) -> (),
	RefreshPacks: (self: Public) -> (),
	SetTension: (self: Public, on: boolean) -> (),
	DevParade: (self: Public, count: number?) -> (),
}

return {}
