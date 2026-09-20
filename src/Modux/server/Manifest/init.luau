--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local NetService = require(ServerScriptService.server.Types.NetService)
local PlayerService = require(ServerScriptService.server.Types.PlayerService)
local ProfileService = require(ServerScriptService.server.Types.ProfileService)
local RoundService = require(ServerScriptService.server.Types.RoundService)
local Vital = require(ServerScriptService.server.Types.Vital)
local VitalService = require(ServerScriptService.server.Types.VitalService)

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
