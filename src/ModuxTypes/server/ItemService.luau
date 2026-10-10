--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Drops = require(ServerScriptService.server.Item.ItemService.Drops)
local Pickup = require(ServerScriptService.server.Item.ItemService.Pickup)
local Stash = require(ServerScriptService.server.Item.ItemService.Stash)
local Uses = require(ServerScriptService.server.Item.ItemService.Uses)

export type GiveOptions = {
	Count: number?,
	Toppings: string?,
	Equip: boolean?,
	Silent: boolean?,
	Restore: number?,
	Altered: boolean?,
}
export type UseHandler = Uses.Handler

export type Public = {
	ByPlayer: { [Player]: { [Tool]: boolean } },
	Changed: SignalLib.Signal<Player>,
	Drops: Drops.Drops,
	Links: { [Tool]: { RBXScriptConnection } },
	Owners: { [Tool]: Player },
	Pickup: Pickup.Pickup,
	ShiftIndex: number,
	Uses: Uses.Uses,
	Setup: (self: Public) -> (),
	Template: (self: Public, key: string) -> Tool?,
	CheckKit: (self: Public) -> (),
	InPlay: (self: Public, tool: Tool, player: Player) -> boolean,
	Forget: (self: Public, tool: Tool) -> (),
	Track: (self: Public, player: Player, tool: Tool) -> (),
	Untrack: (self: Public, tool: Tool) -> (),
	Release: (self: Public, player: Player) -> (),
	ItemOf: (self: Public, tool: Tool) -> string?,
	Tools: (self: Public, player: Player) -> { Tool },
	GetHeld: (self: Public, player: Player) -> Tool?,
	Holding: (self: Public, player: Player, spec: string) -> Tool?,
	IsAltered: (self: Public, tool: Tool) -> boolean,
	Count: (self: Public, tool: Tool) -> number,
	Toppings: (self: Public, tool: Tool) -> { string },
	CountCategory: (self: Public, player: Player, category: string) -> number,
	PackageCount: (self: Public, player: Player) -> number,
	PackageLimit: (self: Public, player: Player) -> number,
	CategoryLimit: (self: Public, player: Player, category: string) -> number,
	CanGive: (self: Public, player: Player, key: string) -> (boolean, string?, number?),
	Paint: (self: Public, tool: Tool) -> (),
	Give: (self: Public, player: Player, key: string, options: GiveOptions?) -> Tool?,
	Consume: (self: Public, player: Player, tool: Tool) -> (),
	SetCount: (self: Public, tool: Tool, count: number) -> number,
	AddTopping: (self: Public, tool: Tool, ingredient: string) -> boolean,
	Transfer: (self: Public, tool: Tool, target: Player) -> boolean,
	TargetOf: (self: Public, anchor: Instance) -> Player?,
	CanGiveCoffee: (self: Public, player: Player, anchor: Instance) -> boolean,
	GiveCoffee: (self: Public, player: Player, anchor: Instance) -> (),
	RegisterUse: (self: Public, item: string, handler: UseHandler) -> (),
	EntriesOf: (self: Public, player: Player) -> { Stash.Entry },
	Stash: (self: Public, player: Player) -> boolean,
	CanHold: (self: Public, player: Player) -> boolean,
	Unstash: (self: Public, player: Player) -> boolean,
	CaptureTools: (self: Public) -> { [string]: any },
	RestoreTools: (self: Public, data: { [string]: any }) -> (),
	OnCharacter: (self: Public, player: Player, character: Model) -> (),
	ClearAltered: (self: Public) -> number,
	DropHeld: (self: Public, player: Player, _reason: string) -> boolean,
	DropStash: (self: Public, userId: number, pointId: string) -> (),
	CurrentVehicle: (self: Public) -> string,
	OnSwapped: (self: Public, _from: string, to: string) -> (),
	WirePickup: (self: Public) -> (),
	WireWave2: (self: Public) -> (),
}

return {}
