--!strict

export type Public = {
	UseAt: { [Player]: number },
	Setup: (self: Public) -> (),
	Credits: (self: Public, player: Player) -> number,
	SendCount: (self: Public, player: Player) -> (),
	Grant: (self: Public, player: Player, amount: number) -> (),
	Use: (self: Public, payer: Player, target: Player) -> boolean,
	FallenOf: (self: Public, player: Player, anchor: Instance) -> Player?,
	AddAnchor: (self: Public, userId: number) -> (),
	RemoveAnchor: (self: Public, userId: number) -> (),
}

return {}
