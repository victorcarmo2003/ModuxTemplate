--!strict

export type Public = {
	Shown: boolean?,
	Setup: (self: Public) -> (),
	IsOpen: (self: Public) -> boolean,
	Paint: (self: Public, board: Instance, open: boolean) -> (),
	Refresh: (self: Public, force: boolean?) -> (),
}

return {}
