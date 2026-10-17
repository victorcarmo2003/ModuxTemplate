--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Shelves = require(ServerScriptService.server.Supply.SupplyService.Shelves)

export type Public = {
	Enabled: boolean,
	LastTake: { [Player]: number },
	Shelves: Shelves.State,
	Setup: (self: Public) -> (),
	IsLive: (self: Public) -> boolean,
	IsOpen: (self: Public, key: string) -> boolean,
	OpenPackages: (self: Public) -> { string },
	CanAct: (self: Public, player: Player) -> boolean,
	RefreshPrompts: (self: Public) -> (),
	BoxAt: (self: Public, anchor: Instance) -> string?,
	Take: (self: Public, player: Player, anchor: Instance) -> boolean,
	ValidateTake: (self: Public, player: Player, anchor: Instance) -> boolean,
	BindAnchor: (self: Public, anchor: Instance, action: string) -> (),
	Bind: (self: Public) -> (),
	DevCheck: (self: Public) -> (),
	DevState: (self: Public) -> string,
	DevTake: (self: Public, player: Player, package: string) -> string,
}

return {}
