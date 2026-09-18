--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Vital = require(ServerScriptService.server.Components.Vital.Type)
local GameService = require(ServerScriptService.server.Services.GameService.Type)
local NetService = require(ServerScriptService.server.Services.NetService.Type)
local PlayerService = require(ServerScriptService.server.Services.PlayerService.Type)
local ProfileService = require(ServerScriptService.server.Services.ProfileService.Type)
local VitalService = require(ServerScriptService.server.Services.VitalService.Type)

export type AllServices = {
	GameService: GameService.Public,
	NetService: NetService.Public,
	PlayerService: PlayerService.Public,
	ProfileService: ProfileService.Public,
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
