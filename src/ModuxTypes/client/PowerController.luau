--!strict

type Record = { Burnt: boolean, Out: boolean, Trip: boolean, At: number }

export type Public = {
	Burnt: boolean,
	Out: boolean,
	Setup: (self: Public) -> (),
	Burn: (self: Public) -> (),
	Apply: (self: Public, record: Record, fresh: boolean) -> (),
}

return {}
