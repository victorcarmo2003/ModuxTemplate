--!strict

export type Public = {
	Taken: { [number]: Player },
	Setup: (self: Public) -> (),
	Assign: (self: Public, player: Player) -> (),
	Release: (self: Public, player: Player) -> (),
}

return {}
