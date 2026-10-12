--!strict

export type Public = {
	Neons: { [Instance]: { Lit: boolean, Count: number } },
	Shown: boolean?,
	Setup: (self: Public) -> (),
	IsOpen: (self: Public) -> boolean,
	Paint: (self: Public, board: Instance, open: boolean) -> (),
	PaintNeon: (self: Public, model: Instance, lit: boolean) -> (),
	RefreshNeons: (self: Public, open: boolean) -> (),
	Refresh: (self: Public) -> (),
}

return {}
