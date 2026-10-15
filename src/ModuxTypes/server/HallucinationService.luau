--!strict

export type Public = {
	Warned: { [string]: boolean },
	Setup: (self: Public) -> (),
	IsScare: (self: Public, key: string) -> boolean,
	Keys: (self: Public) -> { string },
	Filter: (self: Public, keys: { string }?) -> { string }?,
	Scare: (self: Public, target: (Player | { Player })?, keys: { string }?) -> number,
}

return {}
