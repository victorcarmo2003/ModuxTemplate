--!strict

export type Public = {
	Active: boolean,
	Setup: (self: Public) -> (),
	Pages: (self: Public, player: Player) -> { [string]: boolean }?,
	Claimed: (self: Public, player: Player) -> { [string]: boolean },
	Send: (self: Public, player: Player, new: string?, gained: string?) -> (),
	Claim: (self: Public, player: Player, key: string) -> boolean,
	Unlock: (self: Public, player: Player, key: string) -> boolean,
	Reset: (self: Public, player: Player) -> (),
	Open: (self: Public, player: Player) -> (),
	Register: (self: Public) -> (),
}

return {}
