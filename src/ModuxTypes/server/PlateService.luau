--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)

export type Slot = { Index: number, Part: BasePart, Anchor: Attachment, Npc: number, Line: number }
export type Entry = {
	Id: number,
	Player: Player,
	Tool: Tool,
	Ticket: number, -- NpcId, 0 = none
	Line: number, -- 1 leader, 2 pair partner, 0 = none
	Since: number, -- server time the order was taken, 0 = none
}
type Wire = {
	Npc: number,
	Bun: boolean,
	Sausage: boolean,
	Toppings: { [string]: boolean },
	Since: number,
	Altered: boolean?,
}
export type FreeTicket = { Npc: number, Line: number, Since: number }

export type Public = {
	Changed: SignalLib.Signal<number>,
	Enabled: boolean,
	NoticeAt: { [Player]: { [string]: number } },
	Plates: { [number]: Entry },
	Sent: { [number]: Wire },
	Slots: { [number]: Slot },
	Setup: (self: Public) -> (),
	AliveCount: (self: Public) -> number,
	HasRoomFor: (self: Public, _npc: number?) -> boolean,
	Of: (self: Public, id: number) -> Entry?,
	PlateOf: (self: Public, player: Player) -> Entry?,
	NumberOf: (self: Public, npc: number) -> number,
	FreeTickets: (self: Public) -> { FreeTicket },
	WireOf: (self: Public, entry: Entry) -> Wire,
	Publish: (self: Public, id: number) -> (),
	NotifyThrottled: (self: Public, player: Player, key: string, value: number?) -> (),
	Stamp: (self: Public, entry: Entry) -> (),
	FreeId: (self: Public) -> number?,
	Bind: (self: Public, entry: Entry) -> boolean,
	Follow: (self: Public, player: Player) -> (),
	ValidateTake: (self: Public, player: Player) -> boolean,
	Take: (self: Public, player: Player, anchor: Instance?) -> Entry?,
	SlotOf: (self: Public, instance: Instance) -> Slot?,
	BindSlots: (self: Public) -> (),
	RefreshSlots: (self: Public) -> (),
	OnTicket: (self: Public, _npc: number) -> (),
	Release: (self: Public, npc: number) -> number,
	Clear: (self: Public) -> (),
	CheckPickup: (self: Public, player: Player, action: string, anchor: Instance) -> (boolean, string?),
	DevCheck: (self: Public) -> (),
	DevList: (self: Public) -> string,
	DevGive: (self: Public, player: Player) -> string,
	DevClear: (self: Public) -> string,
}

return {}
