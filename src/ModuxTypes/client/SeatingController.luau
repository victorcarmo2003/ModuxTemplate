--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local OrderBubble = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.OrderBubble)
local Look = require(StarterPlayer.StarterPlayerScripts.client.Seating.SeatingController.Look)
local Meal = require(StarterPlayer.StarterPlayerScripts.client.Seating.SeatingController.Meal)

export type Record = { State: string, Price: number, Npc1: number, Npc2: number, Tip: number }
type Spot = {
	Index: number,
	Record: Vide.Source<Record | false>,
	Model: Model?,
	Saved: Look.Saved?, -- authored look of Model
	Top: Attachment?, -- table top centre (Terrain), adornee of the plate and the pops
	TrayAt: CFrame?, -- where the tray goes
	Tray: Model?,
	TrayTip: number, -- tip the tray was built with
	Dim: boolean, -- ghost drawn fainter: for sale but the party cannot pay it yet (like the bench)
	Unmount: (() -> ())?,
	Gui: Instance?,
	OrderUnmounts: { () -> () }, -- order label (plate + bubble) of a customer waiting at the table (Q-209)
	OrderGuis: { Instance },
}
type Orders = { Order: { [string]: boolean }, Order2: { [string]: boolean }? }
export type State = "Locked" | "Ghost" | "Free" | "Occupied" | "Dirty"

export type Public = {
	Cash: Vide.Source<number>,
	CashReady: Vide.Source<boolean>,
	Folder: Folder?,
	Gui: Instance?,
	Meal: Meal.Meal,
	Orders: { [number]: Orders },
	Spots: { [number]: Spot },
	Tracked: { [Model]: { RBXScriptConnection } },
	Setup: (self: Public) -> (),
	CarriedToppings: (self: Public, rig: Model) -> { string },
	RememberOrder: (self: Public, id: number, record: { Order: { [string]: boolean }, Order2: { [string]: boolean }? }) -> (),
	RecordOf: (self: Public, index: number) -> Record?,
	SpotOf: (self: Public, index: number) -> Spot,
	FolderOf: (self: Public) -> Folder,
	Cue: (self: Public, key: string, at: Instance) -> (),
	WriteRecord: (self: Public, index: number, record: Record?) -> (),
	Bind: (self: Public, spot: Spot, model: Model) -> (),
	Unbind: (self: Public, spot: Spot) -> (),
	Rebind: (self: Public, model: Model) -> (),
	Track: (self: Public, instance: Instance) -> (),
	Untrack: (self: Public, instance: Instance) -> (),
	Apply: (self: Public, spot: Spot) -> (),
	ShowTray: (self: Public, spot: Spot, tip: number) -> (),
	ClearTray: (self: Public, spot: Spot) -> (),
	CanPay: (self: Public, price: number) -> boolean,
	CanPayNow: (self: Public, price: number) -> boolean,
	RefreshDim: (self: Public) -> (),
	MountSign: (self: Public, spot: Spot) -> (),
	WaitingAt: (self: Public, spot: Spot) -> number?,
	OrderRows: (self: Public, spot: Spot) -> { { OrderBubble.Topping } },
	MountOrder: (self: Public, spot: Spot) -> (),
	UnmountOrder: (self: Public, spot: Spot) -> (),
	Bought: (self: Public, spot: Spot) -> (),
	Cleaned: (self: Public, spot: Spot, tip: number) -> (),
	Watch: (self: Public, gui: Instance) -> (),
}

return {}
