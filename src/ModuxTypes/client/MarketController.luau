--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local BenchCard = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.BenchCard)

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
	LastLevel: { [string]: number },
	Levels: { [string]: Vide.Source<number> },
	Mounted: { [Instance]: Mounted },
	Stock: { [string]: Vide.Source<Availability> },
	SwappedAt: number,
	Unmount: (() -> ())?,
	Setup: (self: Public) -> (),
	BenchAnchor: (self: Public, slot: string) -> Instance?,
	CurrentVehicle: (self: Public) -> Model?,
	Cue: (self: Public, key: string, at: Instance) -> (),
	OnLevel: (self: Public, upgrade: Content.Upgrade, level: number) -> (),
	CanPay: (self: Public, price: number) -> boolean,
	UpgradeAt: (self: Public, slot: string) -> Content.Upgrade?,
	BenchView: (self: Public, upgrade: Content.Upgrade, vehicle: string, level: number) -> View,
	CardAdornee: (self: Public, anchor: Instance, slot: string) -> Instance,
	MountShelf: (self: Public, anchor: Instance, packageKey: string) -> Mounted?,
	MountBench: (self: Public, anchor: Instance, slot: string) -> Mounted?,
	Add: (self: Public, anchor: Instance) -> (),
	Remove: (self: Public, anchor: Instance) -> (),
	Watch: (self: Public, gui: Instance) -> (),
}

return {}
