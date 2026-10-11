--!strict

export type Public = {
	Active: boolean,
	Expected: { number }?,
	FirstAt: number?,
	LastReturn: { [Player]: number },
	Returning: { [Player]: number },
	Setup: (self: Public) -> (),
	IsExpected: (self: Public, userId: number) -> boolean,
	SquadIn: (self: Public) -> boolean,
	Notice: (self: Public, player: Player, key: string) -> (),
	CanReturn: (self: Public, player: Player?) -> boolean,
	SendToLobby: (self: Public, players: { Player }) -> (),
	OnReturnFailed: (self: Public, player: Player, result: Enum.TeleportResult, message: string) -> (),
	HandleReturn: (self: Public, player: Player) -> (),
	OnPlayerAdded: (self: Public, player: Player) -> (),
}

return {}
