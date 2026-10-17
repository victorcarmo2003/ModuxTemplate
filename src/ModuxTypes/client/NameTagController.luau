--!strict

type Entry = { Connections: { RBXScriptConnection } }

export type Public = {
	Entries: { [Player]: Entry },
	Setup: (self: Public) -> (),
	InRun: (self: Public) -> boolean,
	Decorate: (self: Public, player: Player, character: Model) -> (),
	Recolor: (self: Public, player: Player) -> (),
	Track: (self: Public, player: Player) -> (),
	Untrack: (self: Public, player: Player) -> (),
	RefreshOutlines: (self: Public) -> (),
}

return {}
