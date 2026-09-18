--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local NetService = require(ServerScriptService.server.Net.NetService.Type)
local PlayerService = require(ServerScriptService.server.Player.PlayerService.Type)
local ProfileService = require(ServerScriptService.server.Profile.ProfileService.Type)
local RoundService = require(ServerScriptService.server.Round.RoundService.Type)
local Vital = require(ServerScriptService.server.Vital.Vital.Type)
local VitalService = require(ServerScriptService.server.Vital.VitalService.Type)

export type AllServices = {
	NetService: NetService.Public,
	PlayerService: PlayerService.Public,
	ProfileService: ProfileService.Public,
	RoundService: RoundService.Public,
	VitalService: VitalService.Public,
}

export type AllComponents = {
	Vital: Vital.Public,
}

export type ComponentAccess = {
	Vital: {
		Get: (self: any, instance: Instance) -> Vital.Public?,
		Create: (self: any, instance: Instance) -> Vital.Public,
		All: (self: any) -> { Vital.Public },
		Destroy: (self: any, instance: Instance) -> (),
	},
}

return {}
