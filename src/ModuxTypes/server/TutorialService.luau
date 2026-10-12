--!strict

export type Public = {
	Asked: boolean,
	Closed: { [number]: boolean },
	Enabled: boolean,
	Past: boolean,
	Revived: { [number]: boolean },
	Seeded: boolean,
	Setup: (self: Public) -> (),
	Complete: (self: Public, player: Player) -> (),
	OnDayOne: (self: Public) -> boolean,
	IsPending: (self: Public, player: Player) -> boolean,
	Reason: (self: Public, player: Player) -> string?,
	AnyPending: (self: Public) -> boolean,
	AllPending: (self: Public) -> boolean,
	EnsureCash: (self: Public) -> (),
	Seed: (self: Public) -> (),
	OnDiscarded: (self: Public, item: string) -> (),
	Begin: (self: Public, player: Player) -> (),
	DevCheck: (self: Public, name: string) -> (),
	DevSend: (self: Public, player: Player, command: string, text: string?) -> (),
	DevReset: (self: Public, player: Player) -> (),
	DevStatus: (self: Public) -> string,
	Step: (self: Public) -> (),
}

return {}
