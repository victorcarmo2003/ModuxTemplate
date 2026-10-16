--!strict

export type Public = {
	RunDev: (self: Public, name: string, args: { string }) -> (),
	CommandDevHelp: (self: Public) -> string,
	RunShowcase: (self: Public, action: string, id: string, arg: string) -> (),
	CommandShowcase: (self: Public) -> (),
	CommandTeleport: (self: Public, a: Player, b: Player?) -> (),
	CommandGift: (self: Public, target: string, kind: "Class" | "Gems", key: string, amount: number) -> (),
	CommandContent: (self: Public, kind: string, key: string) -> (),
	Register: (self: Public) -> (),
}

return {}
