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
	Order2: { [string]: boolean }?, -- pair leader: 2nd pending hot dog (network.md §14.2)
	Leader: number?, -- pair partner: NpcId of its leader (no bubble)
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
	Variant: Vide.Source<string | false>, -- rig attribute Variant (TASK-110); false = ordinary customer
	Done: Vide.Source<Done | false>, -- pair row just resolved (TASK-148)
	DoneTimer: thread?,
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
type Done = { Row: number, Toppings: { OrderBubble.Topping } }

export type Public = {
	Entries: { [number]: Entry },
	Focus: Vide.Source<number>,
	Gui: Instance?,
	Models: { [number]: Model },
	Mounted: number,
	Now: Vide.Source<number>,
	Random: Random,
	Reactions: { [Model]: Reaction },
	Tracked: { [Model]: Tracked },
	Setup: (self: Public) -> (),
	RecordOf: (self: Public, id: number) -> Record?,
	VariantOf: (self: Public, id: number) -> string?,
	ToppingsOf: (self: Public, record: Record) -> { OrderBubble.Topping },
	ToppingsOfOrder: (self: Public, order: { [string]: boolean }) -> { OrderBubble.Topping },
	PatienceOf: (self: Public, entry: Entry) -> number,
	NewEntry: (self: Public, id: number) -> Entry,
	WriteRecord: (self: Public, id: number, record: Record?) -> (),
	MarkDone: (self: Public, entry: Entry, row: number, toppings: { OrderBubble.Topping }) -> (),
	ClearDone: (self: Public, entry: Entry) -> (),
	RowsOf: (self: Public, entry: Entry) -> ({ OrderBubble.Topping }, { OrderBubble.Topping }?, number),
	Drop: (self: Public, id: number) -> (),
	Detach: (self: Public, entry: Entry) -> (),
	Unmount: (self: Public, entry: Entry) -> (),
	Fill: (self: Public) -> (),
	Sync: (self: Public, id: number) -> (),
	Mount: (self: Public, entry: Entry, model: Model) -> (),
	React: (self: Public, id: number, result: string) -> (),
	ClearReaction: (self: Public, model: Model) -> (),
	Cue: (self: Public, id: number, key: string) -> (),
	Feedback: (self: Public, id: number, result: string) -> (),
	PickFocus: (self: Public) -> number,
	UpdateFocus: (self: Public) -> (),
	FocusEntry: (self: Public) -> (Entry?, Record?),
	CardShown: (self: Public) -> boolean,
	CardEmpty: (self: Public) -> boolean,
	CardToppings: (self: Public) -> { string },
	CardToppings2: (self: Public) -> { string }?,
	CardPatience: (self: Public) -> number,
	Bind: (self: Public, model: Model) -> (),
	Track: (self: Public, instance: Instance) -> (),
	Untrack: (self: Public, instance: Instance) -> (),
	Watch: (self: Public, gui: Instance) -> (),
}

return {}
