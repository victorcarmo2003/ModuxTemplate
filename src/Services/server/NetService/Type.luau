--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)

export type Public = {
	ClientReady: SignalLib.Signal<Player>,
	Ready: { [Player]: boolean },
	Running: boolean,
	Setup: (self: Public) -> (),
	IsReady: (self: Public, player: Player) -> boolean,
}

return {}
