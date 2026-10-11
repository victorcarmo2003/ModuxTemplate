--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local AnomalyService = require(ServerScriptService.server.ModuxTypes.AnomalyService)
local BossService = require(ServerScriptService.server.ModuxTypes.BossService)
local CharacterService = require(ServerScriptService.server.ModuxTypes.CharacterService)
local ClassService = require(ServerScriptService.server.ModuxTypes.ClassService)
local CustomerService = require(ServerScriptService.server.ModuxTypes.CustomerService)
local CutsceneService = require(ServerScriptService.server.ModuxTypes.CutsceneService)
local DevService = require(ServerScriptService.server.ModuxTypes.DevService)
local EconomyService = require(ServerScriptService.server.ModuxTypes.EconomyService)
local InteractionService = require(ServerScriptService.server.ModuxTypes.InteractionService)
local ItemService = require(ServerScriptService.server.ModuxTypes.ItemService)
local KitchenService = require(ServerScriptService.server.ModuxTypes.KitchenService)
local LightService = require(ServerScriptService.server.ModuxTypes.LightService)
local MarketService = require(ServerScriptService.server.ModuxTypes.MarketService)
local NetService = require(ServerScriptService.server.ModuxTypes.NetService)
local NpcService = require(ServerScriptService.server.ModuxTypes.NpcService)
local PedestrianService = require(ServerScriptService.server.ModuxTypes.PedestrianService)
local PlaceService = require(ServerScriptService.server.ModuxTypes.PlaceService)
local PlayerService = require(ServerScriptService.server.ModuxTypes.PlayerService)
local ProfileService = require(ServerScriptService.server.ModuxTypes.ProfileService)
local RewardService = require(ServerScriptService.server.ModuxTypes.RewardService)
local RoundService = require(ServerScriptService.server.ModuxTypes.RoundService)
local RunStateService = require(ServerScriptService.server.ModuxTypes.RunStateService)
local SeatingService = require(ServerScriptService.server.ModuxTypes.SeatingService)
local ThiefService = require(ServerScriptService.server.ModuxTypes.ThiefService)
local TrafficService = require(ServerScriptService.server.ModuxTypes.TrafficService)
local TutorialService = require(ServerScriptService.server.ModuxTypes.TutorialService)
local UpgradeService = require(ServerScriptService.server.ModuxTypes.UpgradeService)
local VehicleService = require(ServerScriptService.server.ModuxTypes.VehicleService)
local VitalService = require(ServerScriptService.server.ModuxTypes.VitalService)

export type AllServices = {
	AnomalyService: AnomalyService.Public,
	BossService: BossService.Public,
	CharacterService: CharacterService.Public,
	ClassService: ClassService.Public,
	CustomerService: CustomerService.Public,
	CutsceneService: CutsceneService.Public,
	DevService: DevService.Public,
	EconomyService: EconomyService.Public,
	InteractionService: InteractionService.Public,
	ItemService: ItemService.Public,
	KitchenService: KitchenService.Public,
	LightService: LightService.Public,
	MarketService: MarketService.Public,
	NetService: NetService.Public,
	NpcService: NpcService.Public,
	PedestrianService: PedestrianService.Public,
	PlaceService: PlaceService.Public,
	PlayerService: PlayerService.Public,
	ProfileService: ProfileService.Public,
	RewardService: RewardService.Public,
	RoundService: RoundService.Public,
	RunStateService: RunStateService.Public,
	SeatingService: SeatingService.Public,
	ThiefService: ThiefService.Public,
	TrafficService: TrafficService.Public,
	TutorialService: TutorialService.Public,
	UpgradeService: UpgradeService.Public,
	VehicleService: VehicleService.Public,
	VitalService: VitalService.Public,
}

export type AllComponents = {}

export type ComponentAccess = {}

return {}
