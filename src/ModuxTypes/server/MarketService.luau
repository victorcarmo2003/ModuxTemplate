--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

export type Public = {
	HintedShift: string,
	LastBuy: { [Player]: number },
	LastNotice: { [Player]: { [string]: number } },
	Setup: (self: Public) -> (),
	IsBlocked: (self: Public, ingredientKey: string) -> boolean,
	PackageOf: (self: Public, anchor: Instance) -> Content.Package?,
	UpgradeOf: (self: Public, anchor: Instance) -> Content.Upgrade?,
	IsKioskOpen: (self: Public) -> boolean,
	OnSale: (self: Public, upgrade: Content.Upgrade) -> boolean,
	UpgradeText: (self: Public, upgrade: Content.Upgrade, row: Content.UpgradeLevel) -> string,
	CheapestOnSale: (self: Public) -> number?,
	NeverBought: (self: Public) -> boolean,
	HintDue: (self: Public) -> boolean,
	OnPhase: (self: Public, phase: string, info: { Day: number, Night: number, IsNight: boolean }) -> (),
	Refresh: (self: Public, anchor: Instance) -> (),
	RefreshAll: (self: Public) -> (),
	Refuse: (self: Public, player: Player, key: string, value: number) -> (),
	CanAct: (self: Public, player: Player) -> boolean,
	ValidatePackage: (self: Public, player: Player, anchor: Instance) -> boolean,
	BuyPackage: (self: Public, player: Player, anchor: Instance) -> (),
	ValidateUpgrade: (self: Public, player: Player, anchor: Instance) -> boolean,
	BuyUpgrade: (self: Public, player: Player, anchor: Instance) -> (),
}

return {}
