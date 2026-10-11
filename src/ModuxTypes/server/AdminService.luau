--!strict

export type Public = {
	RunDev: (self: Public, name: string, args: { string }) -> (),
	CommandTeleport: (self: Public, a: Player, b: Player?) -> (),
	CommandContent: (self: Public, kind: string, key: string) -> (),
	Register: (self: Public) -> (),
}

return {}
