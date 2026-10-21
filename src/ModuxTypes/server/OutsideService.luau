--!strict

type Stage = "" | "Rise" | "Chase" | "Caught"
type Track = {
	Outside: number,
	Stage: Stage,
	StageAt: number,
	Chaser: Vector3?,
}

export type Public = {
	Enabled: boolean,
	LastTick: number,
	Stand: Model?,
	Tracks: { [Player]: Track },
	Setup: (self: Public) -> (),
	GearStand: (self: Public) -> Model?,
	AtOpenStand: (self: Public, position: Vector3) -> boolean,
	SetStage: (self: Public, player: Player, track: Track, stage: Stage, t: number) -> (),
	Clear: (self: Public, player: Player, track: Track) -> (),
	SpawnFor: (self: Public, root: BasePart) -> Vector3,
	IsSafe: (self: Public, player: Player, root: BasePart) -> boolean,
	Step: (self: Public, dt: number) -> (),
}

return {}
