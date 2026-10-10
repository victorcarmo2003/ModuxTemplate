--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Pickup = require(ServerScriptService.server.Item.ItemService.Pickup)

export type GiveOptions = {
	Count: number?,
	Toppings: string?,
	Equip: boolean?,
	Silent: boolean?,
}

export type Public = {
	ByPlayer: { [Player]: { [Tool]: boolean } },
	Changed: SignalLib.Signal<Player>,
	Links: { [Tool]: { RBXScriptConnection } },
	Owners: { [Tool]: Player },
	Pickup: Pickup.Pickup,
	Setup: (self: Public) -> (),
	Template: (self: Public, key: string) -> Tool?,
	CheckKit: (self: Public) -> (),
	InPlay: (self: Public, tool: Tool, player: Player) -> boolean,
	Forget: (self: Public, tool: Tool) -> (),
	Track: (self: Public, player: Player, tool: Tool) -> (),
	Release: (self: Public, player: Player) -> (),
	ItemOf: (self: Public, tool: Tool) -> string?,
	Tools: (self: Public, player: Player) -> { Tool },
	GetHeld: (self: Public, player: Player) -> Tool?,
	Holding: (self: Public, player: Player, spec: string) -> Tool?,
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
	CurrentVehicle: (self: Public) -> string,
	WirePickup: (self: Public) -> (),
}

return {}
