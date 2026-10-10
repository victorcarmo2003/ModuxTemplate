--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Charm = require(ReplicatedStorage.Packages.Charm)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Ledger = require(ServerScriptService.server.Economy.EconomyService.Ledger)

export type SaleResult = Ledger.SaleResult
export type DrawerKind = Ledger.DrawerKind
export type Report = Ledger.Report
type ShiftInfo = { Day: number, Night: number, IsNight: boolean, Attempt: number }

export type Public = {
	Cash: Charm.Atom<number>,
	Drawer: Charm.Atom<number>,
	Last: Report?,
	Reported: SignalLib.Signal<ShiftInfo, Report>,
	Shift: Ledger.Ledger,
	Setup: (self: Public) -> (),
	GetCash: (self: Public) -> number,
	GetDrawer: (self: Public) -> number,
	CanAfford: (self: Public, amount: number) -> boolean,
	GetLedger: (self: Public) -> Ledger.Ledger,
	LastReport: (self: Public) -> Report?,
	IsShopOpen: (self: Public) -> boolean,
	Spend: (self: Public, amount: number, player: Player?) -> boolean,
	AddToDrawer: (self: Public, amount: number, kind: DrawerKind) -> number,
	CountArrival: (self: Public) -> (),
	CountResult: (self: Public, result: SaleResult) -> (),
	BossPoints: (self: Public) -> number,
	Deposit: (self: Public, info: ShiftInfo) -> Report,
	BeginShift: (self: Public) -> (),
	RestoreCash: (self: Public, data: any) -> (),
	DevAddCash: (self: Public, amount: number) -> number,
	Record: (self: Public) -> { Cash: number, Drawer: number },
}

return {}
