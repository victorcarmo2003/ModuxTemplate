--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

export type Context = {
	Packages: number?, -- packages in the hotbar (bear, PackagesAtLeast); default 0
	IsNight: boolean?, -- default false (wave 1 has no night)
}

export type Public = {
	Locked: { [Player]: string },
	RateCount: { [Player]: number },
	RateStart: { [Player]: number },
	Setup: (self: Public) -> (),
	CanWrite: (self: Public) -> boolean,
	Allow: (self: Public, player: Player) -> boolean,
	Notify: (self: Public, player: Player, kind: string, value: number) -> (),
	GetClass: (self: Public, player: Player) -> string,
	IsLocked: (self: Public, player: Player) -> boolean,
	GetModifier: (self: Public, player: Player, stat: Content.Stat, base: number?, context: Context?) -> number,
	Buy: (self: Public, player: Player, key: string) -> (),
	Select: (self: Public, player: Player, key: string) -> (),
	DevGrantGems: (self: Public, player: Player, amount: number) -> number,
}

return {}
