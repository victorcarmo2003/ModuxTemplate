--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Slots = require(ServerScriptService.server.Plate.PlateService.Slots)

export type Carry = { Line: number, Since: number }

export type Public = {
	AnchorSlot: { [Instance]: number },
	Carried: { [Tool]: Carry },
	DevNext: number,
	Enabled: boolean,
	NoticeAt: { [Player]: { [string]: number } },
	Parts: { [number]: Instance },
	Published: { [number]: boolean },
	PutAnchors: { [number]: Instance },
	Slots: { [number]: Slots.Slot },
	TakeAnchors: { [number]: Instance },
	Setup: (self: Public) -> (),
	IsLive: (self: Public) -> boolean,
	ActiveCount: (self: Public) -> number,
	IsActive: (self: Public, index: number) -> boolean,
	Active: (self: Public) -> { Slots.Slot },
	FreeCount: (self: Public) -> number,
	LinesOf: (self: Public, npc: number?) -> number,
	HasRoom: (self: Public, lines: number?) -> boolean,
	HasRoomFor: (self: Public, npc: number?) -> boolean,
	SlotOf: (self: Public, anchor: Instance) -> Slots.Slot?,
	SlotsOf: (self: Public, npc: number) -> { Slots.Slot },
	Record: (self: Public, slot: Slots.Slot) -> any,
	Publish: (self: Public, index: number) -> (),
	Refresh: (self: Public) -> (),
	NotifyThrottled: (self: Public, player: Player, key: string) -> (),
	Assign: (self: Public, npc: number, lines: number?) -> { number },
	Release: (self: Public, npc: number) -> number,
	Clear: (self: Public) -> (),
	PickPut: (self: Public, player: Player, slot: Slots.Slot) -> (Tool?, Slots.PutKind?, string?),
	CanUse: (self: Public, player: Player, anchor: Instance) -> Slots.Slot?,
	ValidatePut: (self: Public, player: Player, anchor: Instance) -> boolean,
	Put: (self: Public, player: Player, anchor: Instance) -> (),
	ValidateTake: (self: Public, player: Player, anchor: Instance) -> boolean,
	Take: (self: Public, player: Player, anchor: Instance) -> (),
	BindAnchor: (self: Public, index: number, root: Instance, name: string, action: string) -> Instance?,
	Bind: (self: Public) -> (),
	DevCheck: (self: Public) -> (),
	DevList: (self: Public) -> string,
	DevAssign: (self: Public, npc: number) -> string,
	DevFill: (self: Public, count: number) -> string,
	DevPrep: (self: Public, index: number) -> string,
	DevClear: (self: Public) -> string,
}

return {}
