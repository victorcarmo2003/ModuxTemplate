--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local BenchCard = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.BenchCard)
local Kiosk = require(StarterPlayer.StarterPlayerScripts.client.Market.MarketController.Kiosk)
local Minis = require(StarterPlayer.StarterPlayerScripts.client.Market.MarketController.Minis)

export type View = {
	Visible: boolean,
	Mode: BenchCard.Mode,
	Title: string,
	Detail: string,
	Tag: string,
}
type Mounted = {
	Gui: BillboardGui,
	Unmount: () -> (),
}
type Availability = "Unknown" | "Open" | "Blocked"

export type Public = {
	Cash: Vide.Source<number>,
	CashReady: Vide.Source<boolean>,
	Gui: Instance?,
	Kiosk: Kiosk.Kiosk,
	KioskOpen: Vide.Source<boolean>,
	KioskSynced: boolean,
	LastLevel: { [string]: number },
	LastRelocate: number,
	LastStep: number,
	Levels: { [string]: Vide.Source<number> },
	Minis: Minis.Minis,
	Mounted: { [Instance]: Mounted },
	Pedestals: { [string]: Instance },
	Stock: { [string]: Vide.Source<Availability> },
	SwappedAt: number,
	Unmount: (() -> ())?,
	Setup: (self: Public) -> (),
	BenchAnchor: (self: Public, slot: string) -> Instance?,
	CurrentVehicle: (self: Public) -> Model?,
	Cue: (self: Public, key: string, at: Instance) -> (),
	Celebrate: (self: Public, slot: string) -> (),
	OnLevel: (self: Public, upgrade: Content.Upgrade, level: number) -> (),
	CanPay: (self: Public, price: number) -> boolean,
	UpgradeAt: (self: Public, slot: string) -> Content.Upgrade?,
	BenchView: (self: Public, upgrade: Content.Upgrade, vehicle: string, level: number) -> View,
	MiniTarget: (self: Public, upgrade: Content.Upgrade, vehicle: string, level: number) -> Minis.Target,
	PlateFitting: (self: Public, anchor: Instance, slot: string) -> Instance?,
	MountShelf: (self: Public, anchor: Instance, packageKey: string) -> Mounted?,
	MountBench: (self: Public, anchor: Instance, slot: string) -> Mounted?,
	SlotAnchor: (self: Public, slot: string) -> Instance?,
	Rebind: (self: Public, slot: string) -> (),
	AddPedestal: (self: Public, pedestal: Instance) -> (),
	RemovePedestal: (self: Public, pedestal: Instance) -> (),
	ApplyPhase: (self: Public, phase: string, ready: boolean) -> (),
	WatchMinis: (self: Public) -> (),
	WatchKiosk: (self: Public) -> (),
	Step: (self: Public) -> (),
	Add: (self: Public, anchor: Instance) -> (),
	Remove: (self: Public, anchor: Instance) -> (),
	Watch: (self: Public, gui: Instance) -> (),
}

return {}
