--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local GearTag = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.GearTag)
local Hint = require(StarterPlayer.StarterPlayerScripts.client.Market.MarketController.Hint)
local Kiosk = require(StarterPlayer.StarterPlayerScripts.client.Market.MarketController.Kiosk)
local Minis = require(StarterPlayer.StarterPlayerScripts.client.Market.MarketController.Minis)

export type View = {
	Visible: boolean,
	Mode: GearTag.Mode,
	Title: string,
	Detail: string,
	Tag: string,
}
type Mounted = {
	Gui: BillboardGui,
	Unmount: () -> (),
	Slot: string?, -- bench slot whose plate this is (adornee follows the miniature)
}
type Availability = "Unknown" | "Open" | "Blocked"
type GearState = "Unknown" | "Open" | "Closed"

export type Public = {
	BunDismissed: boolean,
	BunHint: Hint.Hint?,
	BunShown: boolean,
	BunToasted: boolean,
	Cash: Vide.Source<number>,
	CashReady: Vide.Source<boolean>,
	Drawer: Vide.Source<number>,
	GearOpen: Vide.Source<GearState>,
	Gui: Instance?,
	Hint: Hint.Hint?,
	HintDismissed: boolean,
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
	Plates: { [string]: Part },
	Stock: { [string]: Vide.Source<Availability> },
	SwappedAt: number,
	Unmount: (() -> ())?,
	Waits: { [string]: Vide.Source<number> },
	Setup: (self: Public) -> (),
	BenchAnchor: (self: Public, slot: string) -> Instance?,
	CurrentVehicle: (self: Public) -> Instance?,
	Cue: (self: Public, key: string, at: Instance) -> (),
	Celebrate: (self: Public, slot: string) -> (),
	OnLevel: (self: Public, upgrade: Content.Upgrade, level: number) -> (),
	CanPay: (self: Public, price: number) -> boolean,
	UpgradeAt: (self: Public, slot: string) -> Content.Upgrade?,
	BenchView: (self: Public, upgrade: Content.Upgrade, vehicle: string, level: number, wait: number) -> View,
	MiniTarget: (self: Public, upgrade: Content.Upgrade, vehicle: string, level: number, wait: number) -> Minis.Target,
	PlatePart: (self: Public, slot: string) -> Part?,
	SyncPlates: (self: Public) -> (),
	MountBench: (self: Public, anchor: Instance, slot: string) -> Mounted?,
	SlotAnchor: (self: Public, slot: string) -> Instance?,
	Rebind: (self: Public, slot: string) -> (),
	AddPedestal: (self: Public, pedestal: Instance) -> (),
	RemovePedestal: (self: Public, pedestal: Instance) -> (),
	StandPoint: (self: Public) -> Vector3?,
	DoorCue: (self: Public, open: boolean) -> (),
	ApplyPhase: (self: Public, phase: string, ready: boolean) -> (),
	WatchMinis: (self: Public) -> (),
	WatchKiosk: (self: Public) -> (),
	CheapestOnSale: (self: Public) -> number?,
	NeverBought: (self: Public) -> boolean,
	HintTarget: (self: Public) -> Instance?,
	StepBunHint: (self: Public) -> (),
	StepHint: (self: Public) -> (),
	Step: (self: Public) -> (),
	Add: (self: Public, anchor: Instance) -> (),
	Remove: (self: Public, anchor: Instance) -> (),
	Watch: (self: Public, gui: Instance) -> (),
}

return {}
