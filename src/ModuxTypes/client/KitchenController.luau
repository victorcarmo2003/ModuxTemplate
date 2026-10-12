--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Context = require(StarterPlayer.StarterPlayerScripts.client.Kitchen.KitchenController.Context)
local Slots = require(StarterPlayer.StarterPlayerScripts.client.Kitchen.KitchenController.Slots)

export type StockRecord = Context.StockRecord
export type SlotRecord = Context.SlotRecord

export type Public = {
	Slots: { [number]: Vide.Source<SlotRecord | false> },
	Stock: { [string]: Vide.Source<StockRecord | false> },
	Views: { [Instance]: () -> () },
	Setup: (self: Public) -> (),
	StockOf: (self: Public, ingredient: string) -> StockRecord?,
	SlotSource: (self: Public, id: number) -> Vide.Source<SlotRecord | false>,
	SlotOf: (self: Public, id: number) -> SlotRecord?,
	WriteStock: (self: Public, id: number, record: StockRecord?) -> (),
	WriteSlot: (self: Public, id: number, record: SlotRecord?) -> (),
	IsCurrent: (self: Public, station: Instance) -> boolean,
	Audio: (self: Public) -> Context.Audio,
	Context: (self: Public) -> Context.Context,
	SlotView: (self: Public, kind: string, slot: number) -> Slots.Live?,
	OnSlotChanged: (self: Public, fn: (entry: Slots.Live) -> ()) -> () -> (),
	Mount: (self: Public, station: Instance) -> (),
	Unmount: (self: Public, station: Instance) -> (),
	Watch: (self: Public) -> (),
}

return {}
