--!strict

local StarterPlayer = game:GetService("StarterPlayer")
local AdminController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.AdminController)
local AnimController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.AnimController)
local AnomalyController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.AnomalyController)
local OutsideController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.OutsideController)
local AtmosphereController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.AtmosphereController)
local AudioController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.AudioController)
local BossController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.BossController)
local CameraController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.CameraController)
local CharacterController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.CharacterController)
local ClassController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.ClassController)
local CoffeeCupController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.CoffeeCupController)
local CoffeeHandController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.CoffeeHandController)
local NameTagController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.NameTagController)
local RigController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.RigController)
local CustomerController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.CustomerController)
local CutsceneController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.CutsceneController)
local DeliveryController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.DeliveryController)
local DoorController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.DoorController)
local EconomyController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.EconomyController)
local HallucinationController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.HallucinationController)
local HudController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.HudController)
local HapticsController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.HapticsController)
local InputController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.InputController)
local PromptController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.PromptController)
local BackdropController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.BackdropController)
local ItemController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.ItemController)
local JournalController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.JournalController)
local KitchenController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.KitchenController)
local LightController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.LightController)
local LoadingController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.LoadingController)
local LobbyController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.LobbyController)
local MarketController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.MarketController)
local NeonController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.NeonController)
local OpenSignController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.OpenSignController)
local NetController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.NetController)
local ObjectiveController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.ObjectiveController)
local OpalController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.OpalController)
local OrderBoardController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.OrderBoardController)
local PedestrianController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.PedestrianController)
local PlaceController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.PlaceController)
local PrepController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.PrepController)
local WorkSlideController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.WorkSlideController)
local ProfileController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.ProfileController)
local NightLostController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.NightLostController)
local RoundController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.RoundController)
local SeatingController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.SeatingController)
local SecurityController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.SecurityController)
local SessionController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.SessionController)
local SettingsController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.SettingsController)
local GiftController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.GiftController)
local OfferController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.OfferController)
local PurchaseFxController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.PurchaseFxController)
local ReviveKitController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.ReviveKitController)
local ShopController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.ShopController)
local ShowcaseController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.ShowcaseController)
local SkinController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.SkinController)
local StageController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.StageController)
local ThiefController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.ThiefController)
local TrafficController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.TrafficController)
local TrafficLightController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.TrafficLightController)
local TrashController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.TrashController)
local TutorialController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.TutorialController)
local SwitchLeverController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.SwitchLeverController)
local VehicleController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.VehicleController)
local VitalController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.VitalController)

export type AllControllers = {
	AdminController: AdminController.Public,
	AnimController: AnimController.Public,
	AnomalyController: AnomalyController.Public,
	OutsideController: OutsideController.Public,
	AtmosphereController: AtmosphereController.Public,
	AudioController: AudioController.Public,
	BossController: BossController.Public,
	CameraController: CameraController.Public,
	CharacterController: CharacterController.Public,
	ClassController: ClassController.Public,
	CoffeeCupController: CoffeeCupController.Public,
	CoffeeHandController: CoffeeHandController.Public,
	NameTagController: NameTagController.Public,
	RigController: RigController.Public,
	CustomerController: CustomerController.Public,
	CutsceneController: CutsceneController.Public,
	DeliveryController: DeliveryController.Public,
	DoorController: DoorController.Public,
	EconomyController: EconomyController.Public,
	HallucinationController: HallucinationController.Public,
	HudController: HudController.Public,
	HapticsController: HapticsController.Public,
	InputController: InputController.Public,
	PromptController: PromptController.Public,
	BackdropController: BackdropController.Public,
	ItemController: ItemController.Public,
	JournalController: JournalController.Public,
	KitchenController: KitchenController.Public,
	LightController: LightController.Public,
	LoadingController: LoadingController.Public,
	LobbyController: LobbyController.Public,
	MarketController: MarketController.Public,
	NeonController: NeonController.Public,
	OpenSignController: OpenSignController.Public,
	NetController: NetController.Public,
	ObjectiveController: ObjectiveController.Public,
	OpalController: OpalController.Public,
	OrderBoardController: OrderBoardController.Public,
	PedestrianController: PedestrianController.Public,
	PlaceController: PlaceController.Public,
	PrepController: PrepController.Public,
	WorkSlideController: WorkSlideController.Public,
	ProfileController: ProfileController.Public,
	NightLostController: NightLostController.Public,
	RoundController: RoundController.Public,
	SeatingController: SeatingController.Public,
	SecurityController: SecurityController.Public,
	SessionController: SessionController.Public,
	SettingsController: SettingsController.Public,
	GiftController: GiftController.Public,
	OfferController: OfferController.Public,
	PurchaseFxController: PurchaseFxController.Public,
	ReviveKitController: ReviveKitController.Public,
	ShopController: ShopController.Public,
	ShowcaseController: ShowcaseController.Public,
	SkinController: SkinController.Public,
	StageController: StageController.Public,
	ThiefController: ThiefController.Public,
	TrafficController: TrafficController.Public,
	TrafficLightController: TrafficLightController.Public,
	TrashController: TrashController.Public,
	TutorialController: TutorialController.Public,
	SwitchLeverController: SwitchLeverController.Public,
	VehicleController: VehicleController.Public,
	VitalController: VitalController.Public,
}

export type AllComponents = {}

export type ComponentAccess = {}

return {}
