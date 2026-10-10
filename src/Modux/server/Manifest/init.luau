--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ClassService = require(ServerScriptService.server.ModuxTypes.ClassService)
local InteractionService = require(ServerScriptService.server.ModuxTypes.InteractionService)
local NetService = require(ServerScriptService.server.ModuxTypes.NetService)
local PlaceService = require(ServerScriptService.server.ModuxTypes.PlaceService)
local PlayerService = require(ServerScriptService.server.ModuxTypes.PlayerService)
local ProfileService = require(ServerScriptService.server.ModuxTypes.ProfileService)
local RoundService = require(ServerScriptService.server.ModuxTypes.RoundService)
local RunStateService = require(ServerScriptService.server.ModuxTypes.RunStateService)
local Vital = require(ServerScriptService.server.ModuxTypes.Vital)
local VitalService = require(ServerScriptService.server.ModuxTypes.VitalService)

export type AllServices = {
	ClassService: ClassService.Public,
	InteractionService: InteractionService.Public,
	NetService: NetService.Public,
	PlaceService: PlaceService.Public,
	PlayerService: PlayerService.Public,
	ProfileService: ProfileService.Public,
	RoundService: RoundService.Public,
	RunStateService: RunStateService.Public,
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
