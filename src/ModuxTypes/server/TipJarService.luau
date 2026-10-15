--!strict

export type Public = {
	Enabled: boolean,
	Jars: { [Attachment]: Instance },
	WarnedLegacy: boolean,
	Setup: (self: Public) -> (),
	FindJar: (self: Public, vehicle: Instance) -> Model?,
	Build: (self: Public, vehicle: Instance) -> (),
	CollectNow: (self: Public) -> number,
	IsLive: (self: Public, anchor: Instance) -> boolean,
	Refresh: (self: Public) -> (),
}

return {}
