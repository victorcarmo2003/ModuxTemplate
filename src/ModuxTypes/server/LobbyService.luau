--!strict

type Job = { Player: Player, Keep: boolean }

export type Public = {
	Cleanups: { [Player]: { () -> () } },
	Queue: { Job },
	Random: Random,
	Warned: boolean,
	Working: boolean,
	Setup: (self: Public) -> (),
	SpawnCFrame: (self: Public) -> CFrame?,
	SpeciesOf: (self: Public, player: Player) -> string,
	Spawn: (self: Public, player: Player, keep: boolean) -> (),
	Enqueue: (self: Public, player: Player, keep: boolean) -> (),
	Forget: (self: Public, player: Player) -> (),
}

return {}
