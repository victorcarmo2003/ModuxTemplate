--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

export type StockRecord = { Amount: number, Capacity: number, Blocked: boolean, Wrapped: boolean? }

export type Public = {
	Gui: ScreenGui?,
	Live: boolean,
	LowKeys: Vide.Source<{ string }>,
	Stock: { [string]: StockRecord },
	Toasted: { [string]: boolean },
	Setup: (self: Public) -> (),
	WriteStock: (self: Public, id: number, record: StockRecord?) -> (),
	ToastLow: (self: Public, ingredient: string) -> (),
	ChipText: (self: Public) -> string,
	ChipIcon: (self: Public) -> string,
	Mount: (self: Public) -> (),
}

return {}
