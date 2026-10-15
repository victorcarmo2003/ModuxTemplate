--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShopContent = require(ReplicatedStorage.shared.Content.Shop)

type Utility = ShopContent.Utility

export type Public = {
	PickAt: { [Player]: number },
	Picks: { [Player]: { [string]: number } },
	Setup: (self: Public) -> (),
	InRun: (self: Public) -> boolean,
	Send: (self: Public, player: Player, key: string, value: number, from: number) -> (),
	TakePick: (self: Public, player: Player, key: string) -> number,
	MateOf: (self: Public, player: Player, picked: number) -> Player?,
	IngredientOf: (self: Public, picked: number) -> string?,
	Fill: (self: Public, ingredient: string) -> number,
	Handler: (self: Public, utility: Utility) -> any,
}

return {}
