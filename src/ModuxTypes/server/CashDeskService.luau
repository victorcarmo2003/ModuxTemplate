--!strict

export type Public = {
	Desks: { [Attachment]: Instance },
	Enabled: boolean,
	Setup: (self: Public) -> (),
	Build: (self: Public, vehicle: Instance) -> (),
	IsLive: (self: Public, anchor: Instance) -> boolean,
	Refresh: (self: Public) -> (),
}

return {}
