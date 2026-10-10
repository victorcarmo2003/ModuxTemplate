--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local OrderBubble = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.OrderBubble)

export type Record = {
	State: string,
	Slot: number,
	Order: { [string]: boolean },
	PatienceEndsAt: number,
	Mood: string,
}
type Entry = {
	Id: number,
	Record: Vide.Source<Record | false>,
	Reacting: Vide.Source<boolean>,
	EndsAt: number, -- last PatienceEndsAt seen (> 0)
	Total: number, -- span of the patience ring (s); 0 = unknown
	Model: Model?, -- rig the bubble and the face are on
	Unmount: (() -> ())?,
	Gui: Instance?,
	Face: string?,
}
type Reaction = {
	Id: number,
	Unmount: () -> (),
	Gui: Instance,
	Timer: thread,
}
type Tracked = {
	Id: number?,
	Connections: { RBXScriptConnection },
}

export type Public = {
	Entries: { [number]: Entry },
	Gui: Instance?,
	Models: { [number]: Model },
	Mounted: number,
	Now: Vide.Source<number>,
	Random: Random,
	Reactions: { [Model]: Reaction },
	Tracked: { [Model]: Tracked },
	Setup: (self: Public) -> (),
	RecordOf: (self: Public, id: number) -> Record?,
	ToppingsOf: (self: Public, record: Record) -> { OrderBubble.Topping },
	PatienceOf: (self: Public, entry: Entry) -> number,
	NewEntry: (self: Public, id: number) -> Entry,
	WriteRecord: (self: Public, id: number, record: Record?) -> (),
	Drop: (self: Public, id: number) -> (),
	Detach: (self: Public, entry: Entry) -> (),
	Unmount: (self: Public, entry: Entry) -> (),
	Fill: (self: Public) -> (),
	Sync: (self: Public, id: number) -> (),
	Mount: (self: Public, entry: Entry, model: Model) -> (),
	React: (self: Public, id: number, result: string) -> (),
	ClearReaction: (self: Public, model: Model) -> (),
	Bind: (self: Public, model: Model) -> (),
	Track: (self: Public, instance: Instance) -> (),
	Untrack: (self: Public, instance: Instance) -> (),
	Watch: (self: Public, gui: Instance) -> (),
}

return {}
