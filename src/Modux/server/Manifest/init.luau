--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local CharacterService = require(ServerScriptService.server.ModuxTypes.CharacterService)
local ClassService = require(ServerScriptService.server.ModuxTypes.ClassService)
local CustomerService = require(ServerScriptService.server.ModuxTypes.CustomerService)
local DevService = require(ServerScriptService.server.ModuxTypes.DevService)
local EconomyService = require(ServerScriptService.server.ModuxTypes.EconomyService)
local InteractionService = require(ServerScriptService.server.ModuxTypes.InteractionService)
local ItemService = require(ServerScriptService.server.ModuxTypes.ItemService)
local KitchenService = require(ServerScriptService.server.ModuxTypes.KitchenService)
local MarketService = require(ServerScriptService.server.ModuxTypes.MarketService)
local NetService = require(ServerScriptService.server.ModuxTypes.NetService)
local NpcService = require(ServerScriptService.server.ModuxTypes.NpcService)
local PlaceService = require(ServerScriptService.server.ModuxTypes.PlaceService)
local PlayerService = require(ServerScriptService.server.ModuxTypes.PlayerService)
local ProfileService = require(ServerScriptService.server.ModuxTypes.ProfileService)
local RoundService = require(ServerScriptService.server.ModuxTypes.RoundService)
local RunStateService = require(ServerScriptService.server.ModuxTypes.RunStateService)
local UpgradeService = require(ServerScriptService.server.ModuxTypes.UpgradeService)
local Vital = require(ServerScriptService.server.ModuxTypes.Vital)
local VitalService = require(ServerScriptService.server.ModuxTypes.VitalService)

export type AllServices = {
	CharacterService: CharacterService.Public,
	ClassService: ClassService.Public,
	CustomerService: CustomerService.Public,
	DevService: DevService.Public,
	EconomyService: EconomyService.Public,
	InteractionService: InteractionService.Public,
	ItemService: ItemService.Public,
	KitchenService: KitchenService.Public,
	MarketService: MarketService.Public,
	NetService: NetService.Public,
	NpcService: NpcService.Public,
	PlaceService: PlaceService.Public,
	PlayerService: PlayerService.Public,
	ProfileService: ProfileService.Public,
	RoundService: RoundService.Public,
	RunStateService: RunStateService.Public,
	UpgradeService: UpgradeService.Public,
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
