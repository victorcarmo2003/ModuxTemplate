--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)

export type Public = {
	Bought: SignalLib.Signal<Player>,
	MissingPoints: { [string]: boolean },
	Pending: Charm.Atom<boolean>,
	PlaceToken: number,
	Purchased: Charm.Atom<boolean>,
	Swapped: SignalLib.Signal<string, string>,
	Vehicle: Charm.Atom<string>,
	Setup: (self: Public) -> (),
	Current: (self: Public) -> string,
	IsBought: (self: Public) -> boolean,
	IsPending: (self: Public) -> boolean,
	Price: (self: Public) -> number,
	IsOnSale: (self: Public) -> boolean,
	PromptText: (self: Public) -> string,
	Models: (self: Public) -> { Instance },
	PointFor: (self: Public, key: string) -> string,
	IsBuyAnchor: (self: Public, anchor: Instance) -> boolean,
	RefreshCover: (self: Public, cover: Instance) -> (),
	RefreshCovers: (self: Public) -> (),
	PlaceNow: (self: Public) -> (),
	Place: (self: Public, delay: number) -> (),
	RefreshSale: (self: Public) -> (),
	Buy: (self: Public, player: Player) -> boolean,
	MarkBought: (self: Public, player: Player?) -> (),
	Swap: (self: Public) -> (),
	Remind: (self: Public, info: { Day: number, IsNight: boolean }) -> (),
	Restore: (self: Public, data: any) -> (),
	DevCheck: (self: Public, name: string) -> (),
	DevBuy: (self: Public) -> boolean,
	DevSwap: (self: Public) -> boolean,
}

return {}
