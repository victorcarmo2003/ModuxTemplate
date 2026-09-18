--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Struct = require(ReplicatedStorage.shared.Types.Struct)
local Template = require(script.Parent.Template)

export type Data = typeof(Template)

export type Public = {
	Loaded: SignalLib.Signal<Player, Data>,
	Profiles: { [Player]: any },
	Store: any,
	Setup: (self: Public) -> (),
	Get: (self: Public, player: Player) -> Data?,
	Update: (self: Public, player: Player, patch: Struct.Partial<Data>) -> (),
	Load: (self: Public, player: Player) -> (),
	Unload: (self: Public, player: Player) -> (),
}

return {}
