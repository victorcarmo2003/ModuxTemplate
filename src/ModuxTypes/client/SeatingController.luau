--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
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
	Unmount: (() -> ())?,
	Gui: Instance?,
}
export type State = "Locked" | "Ghost" | "Free" | "Occupied" | "Dirty"

export type Public = {
	Cash: Vide.Source<number>,
	CashReady: Vide.Source<boolean>,
	Folder: Folder?,
	Gui: Instance?,
	Meal: Meal.Meal,
	Spots: { [number]: Spot },
	Tracked: { [Model]: { RBXScriptConnection } },
	Setup: (self: Public) -> (),
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
	MountSign: (self: Public, spot: Spot) -> (),
	Bought: (self: Public, spot: Spot) -> (),
	Cleaned: (self: Public, spot: Spot, tip: number) -> (),
	Watch: (self: Public, gui: Instance) -> (),
}

return {}
