--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Charm = require(ReplicatedStorage.Packages.Charm)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Ledger = require(ServerScriptService.server.Economy.EconomyService.Ledger)

export type SaleResult = Ledger.SaleResult
export type DrawerKind = Ledger.DrawerKind
export type SaleKind = Ledger.SaleKind
export type Report = Ledger.Report
export type ShiftInfo = { Day: number, Night: number, IsNight: boolean, Attempt: number }
export type ReportStep = (info: ShiftInfo, report: Report) -> ()
type Step = { Name: string, Run: ReportStep }

export type Public = {
	Cash: Charm.Atom<number>,
	Drawer: Charm.Atom<number>,
	Last: Report?,
	PromptedAt: { [Player]: number },
	Reported: SignalLib.Signal<ShiftInfo, Report>,
	Shift: Ledger.Ledger,
	Steps: { Step },
	Setup: (self: Public) -> (),
	GetCash: (self: Public) -> number,
	GetDrawer: (self: Public) -> number,
	CanAfford: (self: Public, amount: number) -> boolean,
	GetLedger: (self: Public) -> Ledger.Ledger,
	LastReport: (self: Public) -> Report?,
	IsShopOpen: (self: Public) -> boolean,
	IsDrawerOpen: (self: Public) -> boolean,
	Spend: (self: Public, amount: number, player: Player?, sku: string?) -> boolean,
	PromptCashPack: (self: Public, player: Player, missing: number) -> (),
	AddSale: (self: Public, amount: number, kind: SaleKind) -> number,
	AddTip: (self: Public, amount: number) -> number,
	AddToDrawer: (self: Public, amount: number, kind: DrawerKind) -> number,
	Steal: (self: Public, amount: number) -> number,
	CollectTips: (self: Public) -> number,
	CountArrival: (self: Public) -> (),
	CountResult: (self: Public, result: SaleResult) -> (),
	AddReportStep: (self: Public, name: string, fn: ReportStep) -> (),
	RunReportSteps: (self: Public, info: ShiftInfo, report: Report) -> (),
	BossPoints: (self: Public) -> number,
	Deposit: (self: Public, info: ShiftInfo) -> Report,
	BeginShift: (self: Public) -> (),
	RestoreCash: (self: Public, data: any) -> (),
	TopUp: (self: Public, amount: number, transaction: string?, player: Player?, sku: string?) -> number,
	DevAddCash: (self: Public, amount: number) -> number,
	Record: (self: Public) -> { Cash: number, Drawer: number },
}

return {}
