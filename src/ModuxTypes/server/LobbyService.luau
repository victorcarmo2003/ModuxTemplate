--!strict

export type Public = {
	Random: Random,
	Warned: boolean,
	Setup: (self: Public) -> (),
	SpawnCFrame: (self: Public) -> CFrame?,
	SwapToR15: (self: Public, player: Player, old: Model, at: CFrame) -> (),
	OnCharacter: (self: Public, player: Player, character: Model) -> (),
}

return {}
