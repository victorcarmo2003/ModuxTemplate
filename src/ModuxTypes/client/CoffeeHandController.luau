--!strict

export type Public = {
	Cups: { [Instance]: { RBXScriptConnection } },
	Setup: (self: Public) -> (),
	Paint: (self: Public, cup: Instance, drinking: boolean) -> (),
	Puff: (self: Public, cup: Instance) -> (),
	Add: (self: Public, cup: Instance, loud: boolean) -> (),
	Remove: (self: Public, cup: Instance) -> (),
}

return {}
