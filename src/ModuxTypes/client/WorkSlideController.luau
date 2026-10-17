--!strict

export type Public = {
	Anchors: { [Attachment]: Vector3 },
	Setup: (self: Public) -> (),
	Track: (self: Public, instance: Instance) -> (),
	Untrack: (self: Public, instance: Instance) -> (),
	Step: (self: Public) -> (),
}

return {}
