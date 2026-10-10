--!strict

export type Public = {
	Connections: { [Player]: { RBXScriptConnection } },
	Queue: { Player },
	Spawning: { [Player]: boolean },
	Working: boolean,
	Setup: (self: Public) -> (),
	SetupCollision: (self: Public) -> (),
	Disconnect: (self: Public, player: Player) -> (),
	IsCrew: (self: Public, character: Model) -> boolean,
	CanSpawn: (self: Public, player: Player) -> boolean,
	Enqueue: (self: Public, player: Player) -> (),
	SpeciesOf: (self: Public, player: Player) -> string,
	SpawnPoint: (self: Public, player: Player) -> CFrame?,
	Spawn: (self: Public, player: Player) -> (),
	Prepare: (self: Public, player: Player, character: Model) -> (),
	CountPackages: (self: Public, player: Player) -> number,
	RefreshSpeed: (self: Public, player: Player) -> (),
	OnCharacter: (self: Public, player: Player, character: Model) -> (),
}

return {}
