--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local StockMenu = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.StockMenu)

export type SupplyRecord = { State: string, EndsAt: number, Boxes: number }
export type HatchRecord = { Package: string, Amount: number }
export type StockRecord = { Amount: number, Capacity: number, Blocked: boolean, Wrapped: boolean? }
type Bay = { Root: Instance, Destroy: () -> (), Gui: BillboardGui, Connections: { RBXScriptConnection } }
type HatchBox = { Part: BasePart, Destroy: () -> (), Gui: BillboardGui }

export type Public = {
	Bays: { [Instance]: Bay },
	Boxes: { [number]: HatchBox },
	Cost: Vide.Source<number>,
	Folder: Folder?,
	Gui: ScreenGui?,
	Hatch: { [number]: HatchRecord },
	Lines: Vide.Source<{ StockMenu.Line }>,
	Live: boolean,
	LowKeys: Vide.Source<{ string }>,
	Now: Vide.Source<number>,
	PhoneOpen: Vide.Source<boolean>,
	Spots: { Instance },
	Stock: { [string]: StockRecord },
	Supply: Vide.Source<SupplyRecord>,
	Toasted: { [string]: boolean },
	Setup: (self: Public) -> (),
	SecondsLeft: (self: Public) -> number,
	OpenPackages: (self: Public) -> { string },
	BoxesWaiting: (self: Public) -> { [string]: number },
	Predict: (self: Public) -> ({ StockMenu.Line }, number),
	WriteSupply: (self: Public, record: SupplyRecord?) -> (),
	WriteStock: (self: Public, id: number, record: StockRecord?) -> (),
	ToastLow: (self: Public, ingredient: string) -> (),
	WriteHatch: (self: Public, id: number, record: HatchRecord?) -> (),
	UnmountBay: (self: Public, root: Instance) -> (),
	MountBay: (self: Public, root: Instance) -> (),
	WatchBays: (self: Public) -> (),
	FindSpots: (self: Public) -> { Instance },
	ClearBox: (self: Public, index: number) -> (),
	DrawHatch: (self: Public) -> (),
	RefreshOrder: (self: Public) -> (),
	PhoneTargeted: (self: Public) -> boolean,
	ChipText: (self: Public) -> string,
	ChipIcon: (self: Public) -> string,
	Mount: (self: Public) -> (),
}

return {}
