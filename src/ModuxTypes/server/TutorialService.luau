--!strict

export type Public = {
	Asked: boolean,
	Enabled: boolean,
	Setup: (self: Public) -> (),
	Complete: (self: Public, player: Player) -> (),
	IsPending: (self: Public, player: Player) -> boolean,
	AnyPending: (self: Public) -> boolean,
	Begin: (self: Public, player: Player) -> (),
	Step: (self: Public) -> (),
}

return {}
