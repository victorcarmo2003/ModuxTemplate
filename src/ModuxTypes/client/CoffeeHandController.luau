--!strict

export type Public = {
	Cups: { [Instance]: { RBXScriptConnection } },
	Setup: (self: Public) -> (),
	Paint: (self: Public, cup: Instance, drinking: boolean) -> (),
	Add: (self: Public, cup: Instance) -> (),
	Remove: (self: Public, cup: Instance) -> (),
}

return {}
