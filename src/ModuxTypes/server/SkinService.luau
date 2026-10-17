--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

export type Public = {
	RateCount: { [Player]: number },
	RateStart: { [Player]: number },
	Setup: (self: Public) -> (),
	Allow: (self: Public, player: Player) -> boolean,
	Owned: (self: Public, player: Player) -> { [string]: boolean },
	OnSale: (self: Public, skin: Content.Skin) -> boolean,
	SkinOf: (self: Public, player: Player, class: string) -> string?,
	Send: (self: Public, player: Player) -> (),
	CanWrite: (self: Public) -> boolean,
	Equip: (self: Public, player: Player, class: string, key: string) -> (),
	Handler: (self: Public, skin: Content.Skin) -> any,
	DevReset: (self: Public, player: Player) -> (),
}

return {}
