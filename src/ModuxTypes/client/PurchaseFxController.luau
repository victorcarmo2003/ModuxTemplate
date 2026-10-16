--!strict

export type Public = {
	Names: { [number]: string },
	Setup: (self: Public) -> (),
	Celebrate: (self: Public, id: number) -> (),
}

return {}
