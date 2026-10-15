--!strict

export type Public = {
	Active: boolean,
	Anchor: Attachment?,
	Watching: { [Player]: boolean },
	Setup: (self: Public) -> (),
	Monitor: (self: Public) -> Model?,
	EnsureAnchor: (self: Public) -> Attachment?,
	Open: (self: Public, player: Player) -> (),
	Release: (self: Public, player: Player, gone: boolean?) -> (),
	Register: (self: Public) -> (),
}

return {}
