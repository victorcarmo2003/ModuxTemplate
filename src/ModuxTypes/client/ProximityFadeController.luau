--!strict

export type Public = {
	Faded: { [Model]: number },
	Setup: (self: Public) -> (),
	Step: (self: Public) -> (),
}

return {}
