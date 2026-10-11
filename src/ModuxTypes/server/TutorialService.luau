--!strict

export type Public = {
	Complete: (self: Public, player: Player) -> (),
	IsPending: (self: Public, player: Player) -> boolean,
	AnyPending: (self: Public) -> boolean,
}

return {}
