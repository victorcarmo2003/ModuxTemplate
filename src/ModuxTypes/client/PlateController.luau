--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Record = {
	Npc: number,
	Line: number,
	Bun: boolean,
	Sausage: boolean,
	Toppings: { [string]: boolean },
	Since: number,
	Orphan: boolean?,
	Altered: boolean?,
}
type Customer = {
	State: string,
	Number: number?,
	Order: { [string]: boolean },
	Order2: { [string]: boolean }?,
	PatienceEndsAt: number,
	PatienceSpan: number,
	Phase: string,
}
type Slot = {
	Index: number,
	Record: Vide.Source<Record | false>,
	Blank: Vide.Source<boolean>,
	Part: BasePart?,
	Saved: { [BasePart]: number }, -- authored Transparency of the visible parts of PLATE-n
	Food: Model?,
	FoodKey: string,
	Memo: Memo?,
	Unmount: (() -> ())?,
	Gui: Instance?,
}
type Memo = { Npc: number, Line: number, Number: number?, Toppings: { string } }

export type Public = {
	Clock: thread?,
	Customers: Vide.Source<{ [number]: Customer }>,
	Folder: Folder?,
	Gui: Instance?,
	Now: Vide.Source<number>,
	Slots: { [number]: Slot },
	Tracked: { [Instance]: { RBXScriptConnection } },
	Warned: boolean,
	Setup: (self: Public) -> (),
	Enabled: (self: Public) -> boolean,
	RecordOf: (self: Public, index: number) -> Record?,
	PlateOf: (self: Public, npc: number) -> number?,
	SlotOf: (self: Public, index: number) -> Slot,
	WriteRecord: (self: Public, index: number, record: Record?) -> (),
	WriteCustomer: (self: Public, id: number, record: any?) -> (),
	Remember: (self: Public, slot: Slot) -> (),
	HasTicket: (self: Public, slot: Slot) -> boolean,
	AnyTicket: (self: Public) -> boolean,
	CustomerOf: (self: Public, slot: Slot) -> Customer?,
	NumberOf: (self: Public, slot: Slot) -> number?,
	ToppingsOf: (self: Public, slot: Slot) -> { string },
	PatienceOf: (self: Public, slot: Slot) -> number,
	IsOldest: (self: Public, slot: Slot) -> boolean,
	Refresh: (self: Public, slot: Slot) -> (),
	ApplyLook: (self: Public, slot: Slot) -> (),
	KitModel: (self: Public, key: string) -> Model?,
	BuildFood: (self: Public, slot: Slot) -> (),
	MountTicket: (self: Public, slot: Slot) -> (),
	UnmountTicket: (self: Public, slot: Slot) -> (),
	RunClock: (self: Public) -> (),
	Bind: (self: Public, instance: Instance) -> (),
	Release: (self: Public, slot: Slot) -> (),
	Track: (self: Public, instance: Instance) -> (),
	Untrack: (self: Public, instance: Instance) -> (),
	Watch: (self: Public, gui: Instance) -> (),
}

return {}
