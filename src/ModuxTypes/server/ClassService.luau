--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

export type Currency = "Gems" | "Robux"
export type BuyReason =
	"Ok"
	| "Prompt"
	| "Granted"
	| "Converted"
	| "Owned"
	| "NotEnoughGems"
	| "NotForSale"
	| "Unavailable"
	| "Busy"
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
	BuyWithGems: (self: Public, player: Player, key: string) -> BuyReason,
	CheckRobux: (self: Public, player: Player, key: string) -> BuyReason,
	Reply: (self: Public, player: Player, key: string, reason: BuyReason) -> (),
	Buy: (self: Public, player: Player, key: string) -> (),
	HandleBuy: (self: Public, player: Player, key: string, currency: Currency) -> (),
	Select: (self: Public, player: Player, key: string) -> (),
	DevGrantGems: (self: Public, player: Player, amount: number) -> number,
}

return {}
