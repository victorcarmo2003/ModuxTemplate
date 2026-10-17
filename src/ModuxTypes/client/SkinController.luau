--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)

export type Public = {
	Equipped: Vide.Source<{ [string]: string }>,
	Granted: SignalLib.Signal<string>,
	Now: Vide.Source<number>,
	Owned: Vide.Source<{ [string]: boolean }>,
	Prices: Vide.Source<{ [string]: number }>,
	Prompting: Vide.Source<string>,
	Ready: Vide.Source<boolean>,
	Setup: (self: Public) -> (),
	OnSale: (self: Public, key: string) -> boolean,
	Listed: (self: Public, key: string) -> boolean,
	Owns: (self: Public, key: string) -> boolean,
	EquippedOf: (self: Public, class: string) -> string,
	Shown: (self: Public, class: string) -> { string },
	RobuxOf: (self: Public, key: string) -> number?,
	LimitedLeft: (self: Public) -> number?,
	Buy: (self: Public, key: string) -> boolean,
	Equip: (self: Public, class: string, key: string) -> (),
	LoadPrices: (self: Public) -> (),
}

return {}
