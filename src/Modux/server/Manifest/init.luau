--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local AdminService = require(ServerScriptService.server.ModuxTypes.AdminService)
local AnomalyService = require(ServerScriptService.server.ModuxTypes.AnomalyService)
local AtmosphereService = require(ServerScriptService.server.ModuxTypes.AtmosphereService)
local BossService = require(ServerScriptService.server.ModuxTypes.BossService)
local CharacterService = require(ServerScriptService.server.ModuxTypes.CharacterService)
local ClassService = require(ServerScriptService.server.ModuxTypes.ClassService)
local CodesService = require(ServerScriptService.server.ModuxTypes.CodesService)
local CoffeeHandService = require(ServerScriptService.server.ModuxTypes.CoffeeHandService)
local CustomerService = require(ServerScriptService.server.ModuxTypes.CustomerService)
local CutsceneService = require(ServerScriptService.server.ModuxTypes.CutsceneService)
local DevService = require(ServerScriptService.server.ModuxTypes.DevService)
local EconomyService = require(ServerScriptService.server.ModuxTypes.EconomyService)
local TipJarService = require(ServerScriptService.server.ModuxTypes.TipJarService)
local HallucinationService = require(ServerScriptService.server.ModuxTypes.HallucinationService)
local InteractionService = require(ServerScriptService.server.ModuxTypes.InteractionService)
local ItemService = require(ServerScriptService.server.ModuxTypes.ItemService)
local KitchenService = require(ServerScriptService.server.ModuxTypes.KitchenService)
local LightService = require(ServerScriptService.server.ModuxTypes.LightService)
local LobbyService = require(ServerScriptService.server.ModuxTypes.LobbyService)
local MarketService = require(ServerScriptService.server.ModuxTypes.MarketService)
local NetService = require(ServerScriptService.server.ModuxTypes.NetService)
local NpcService = require(ServerScriptService.server.ModuxTypes.NpcService)
local PartyRunService = require(ServerScriptService.server.ModuxTypes.PartyRunService)
local PartyService = require(ServerScriptService.server.ModuxTypes.PartyService)
local PedestrianService = require(ServerScriptService.server.ModuxTypes.PedestrianService)
local PlaceService = require(ServerScriptService.server.ModuxTypes.PlaceService)
local PlayerService = require(ServerScriptService.server.ModuxTypes.PlayerService)
local PrepService = require(ServerScriptService.server.ModuxTypes.PrepService)
local PresenceService = require(ServerScriptService.server.ModuxTypes.PresenceService)
local ProfileService = require(ServerScriptService.server.ModuxTypes.ProfileService)
local RewardService = require(ServerScriptService.server.ModuxTypes.RewardService)
local RoundService = require(ServerScriptService.server.ModuxTypes.RoundService)
local RunStateService = require(ServerScriptService.server.ModuxTypes.RunStateService)
local SeatingService = require(ServerScriptService.server.ModuxTypes.SeatingService)
local SecurityService = require(ServerScriptService.server.ModuxTypes.SecurityService)
local RoleService = require(ServerScriptService.server.ModuxTypes.RoleService)
local SettingsService = require(ServerScriptService.server.ModuxTypes.SettingsService)
local ReviveKitService = require(ServerScriptService.server.ModuxTypes.ReviveKitService)
local ShopService = require(ServerScriptService.server.ModuxTypes.ShopService)
local ShopUtilityService = require(ServerScriptService.server.ModuxTypes.ShopUtilityService)
local ShowcaseService = require(ServerScriptService.server.ModuxTypes.ShowcaseService)
local ThiefService = require(ServerScriptService.server.ModuxTypes.ThiefService)
local TrafficService = require(ServerScriptService.server.ModuxTypes.TrafficService)
local TutorialService = require(ServerScriptService.server.ModuxTypes.TutorialService)
local UpgradeService = require(ServerScriptService.server.ModuxTypes.UpgradeService)
local TrailerDoorService = require(ServerScriptService.server.ModuxTypes.TrailerDoorService)
local VehicleService = require(ServerScriptService.server.ModuxTypes.VehicleService)
local VitalService = require(ServerScriptService.server.ModuxTypes.VitalService)

export type AllServices = {
	AdminService: AdminService.Public,
	AnomalyService: AnomalyService.Public,
	AtmosphereService: AtmosphereService.Public,
	BossService: BossService.Public,
	CharacterService: CharacterService.Public,
	ClassService: ClassService.Public,
	CodesService: CodesService.Public,
	CoffeeHandService: CoffeeHandService.Public,
	CustomerService: CustomerService.Public,
	CutsceneService: CutsceneService.Public,
	DevService: DevService.Public,
	EconomyService: EconomyService.Public,
	TipJarService: TipJarService.Public,
	HallucinationService: HallucinationService.Public,
	InteractionService: InteractionService.Public,
	ItemService: ItemService.Public,
	KitchenService: KitchenService.Public,
	LightService: LightService.Public,
	LobbyService: LobbyService.Public,
	MarketService: MarketService.Public,
	NetService: NetService.Public,
	NpcService: NpcService.Public,
	PartyRunService: PartyRunService.Public,
	PartyService: PartyService.Public,
	PedestrianService: PedestrianService.Public,
	PlaceService: PlaceService.Public,
	PlayerService: PlayerService.Public,
	PrepService: PrepService.Public,
	PresenceService: PresenceService.Public,
	ProfileService: ProfileService.Public,
	RewardService: RewardService.Public,
	RoundService: RoundService.Public,
	RunStateService: RunStateService.Public,
	SeatingService: SeatingService.Public,
	SecurityService: SecurityService.Public,
	RoleService: RoleService.Public,
	SettingsService: SettingsService.Public,
	ReviveKitService: ReviveKitService.Public,
	ShopService: ShopService.Public,
	ShopUtilityService: ShopUtilityService.Public,
	ShowcaseService: ShowcaseService.Public,
	ThiefService: ThiefService.Public,
	TrafficService: TrafficService.Public,
	TutorialService: TutorialService.Public,
	UpgradeService: UpgradeService.Public,
	TrailerDoorService: TrailerDoorService.Public,
	VehicleService: VehicleService.Public,
	VitalService: VitalService.Public,
}

export type AllComponents = {}

export type ComponentAccess = {}

return {}
