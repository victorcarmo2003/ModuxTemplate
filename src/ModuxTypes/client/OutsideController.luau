--!strict

export type Public = {
	NextBurst: number,
	Outside: number,
	Setup: (self: Public) -> (),
	HideLive: (self: Public) -> boolean,
	Check: (self: Public, dt: number) -> (),
}

return {}
