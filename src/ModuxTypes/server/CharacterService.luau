--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)

export type Pack = CrewRig.Pack
export type ShiftInfo = { Day: number, Night: number, IsNight: boolean, Attempt: number }

export type Public = {
	Connections: { [Player]: { RBXScriptConnection } },
	Fainted: any,
	ForcedPoint: { [Player]: string },
	Frozen: { [Player]: { [string]: boolean } },
	Knocked: any,
	Packs: { [number]: Pack },
	Queue: { Player },
	Spawning: { [Player]: boolean },
	Working: boolean,
	Setup: (self: Public) -> (),
	SetupCollision: (self: Public) -> (),
	Disconnect: (self: Public, player: Player) -> (),
	IsCrew: (self: Public, character: Model) -> boolean,
	CanSpawn: (self: Public, player: Player) -> boolean,
	CharacterOf: (self: Public, player: Player) -> Model?,
	IsFainted: (self: Public, player: Player) -> boolean,
	Enqueue: (self: Public, player: Player) -> (),
	SpeciesOf: (self: Public, player: Player) -> string,
	SkinOf: (self: Public, player: Player) -> string?,
	SpawnPrefix: (self: Public, info: ShiftInfo) -> string,
	SpawnPointFor: (self: Public, player: Player, info: ShiftInfo) -> CFrame?,
	PointFor: (self: Public, player: Player) -> CFrame?,
	Spawn: (self: Public, player: Player, point: string?) -> (),
	Prepare: (self: Public, player: Player, character: Model) -> (),
	AddGiveAnchor: (self: Public, character: Model) -> (),
	ApplyAnimations: (self: Public, character: Model, bucket: { RBXScriptConnection }) -> (),
	PackOf: (self: Public, player: Player) -> Pack,
	SetLookPack: (self: Public, player: Player, pack: Pack) -> (),
	IsFrozen: (self: Public, player: Player) -> boolean,
	Freeze: (self: Public, player: Player, reason: string, on: boolean) -> (),
	ApplyFreeze: (self: Public, player: Player) -> (),
	Faint: (self: Public, player: Player) -> (),
	IsKnocked: (self: Public, player: Player) -> boolean,
	Knock: (self: Public, player: Player, seconds: number, impulse: Vector3) -> number?,
	RemoveBody: (self: Public, player: Player, instant: boolean?) -> (),
	CountPackages: (self: Public, player: Player) -> number,
	RefreshSpeed: (self: Public, player: Player) -> (),
	OnLifeChanged: (self: Public, userId: number, new: string) -> (),
	OnShiftStarted: (self: Public, info: ShiftInfo) -> (),
	OnCharacter: (self: Public, player: Player, character: Model) -> (),
}

return {}
