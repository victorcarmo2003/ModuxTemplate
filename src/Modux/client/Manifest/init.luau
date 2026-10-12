--!strict

local StarterPlayer = game:GetService("StarterPlayer")
local AdminController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.AdminController)
local AnimController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.AnimController)
local AnomalyController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.AnomalyController)
local AudioController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.AudioController)
local BossController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.BossController)
local CameraController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.CameraController)
local CharacterController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.CharacterController)
local ClassController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.ClassController)
local RigController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.RigController)
local CustomerController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.CustomerController)
local CutsceneController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.CutsceneController)
local DoorController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.DoorController)
local EconomyController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.EconomyController)
local HallucinationController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.HallucinationController)
local HudController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.HudController)
local InputController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.InputController)
local PromptController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.PromptController)
local ItemController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.ItemController)
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
local PedestrianController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.PedestrianController)
local PlaceController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.PlaceController)
local ProfileController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.ProfileController)
local RoundController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.RoundController)
local SeatingController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.SeatingController)
local ShowcaseController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.ShowcaseController)
local StageController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.StageController)
local ThiefController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.ThiefController)
local TrafficController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.TrafficController)
local TutorialController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.TutorialController)
local PadHideController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.PadHideController)
local VehicleController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.VehicleController)
local VitalController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.VitalController)

export type AllControllers = {
	AdminController: AdminController.Public,
	AnimController: AnimController.Public,
	AnomalyController: AnomalyController.Public,
	AudioController: AudioController.Public,
	BossController: BossController.Public,
	CameraController: CameraController.Public,
	CharacterController: CharacterController.Public,
	ClassController: ClassController.Public,
	RigController: RigController.Public,
	CustomerController: CustomerController.Public,
	CutsceneController: CutsceneController.Public,
	DoorController: DoorController.Public,
	EconomyController: EconomyController.Public,
	HallucinationController: HallucinationController.Public,
	HudController: HudController.Public,
	InputController: InputController.Public,
	PromptController: PromptController.Public,
	ItemController: ItemController.Public,
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
	PedestrianController: PedestrianController.Public,
	PlaceController: PlaceController.Public,
	ProfileController: ProfileController.Public,
	RoundController: RoundController.Public,
	SeatingController: SeatingController.Public,
	ShowcaseController: ShowcaseController.Public,
	StageController: StageController.Public,
	ThiefController: ThiefController.Public,
	TrafficController: TrafficController.Public,
	TutorialController: TutorialController.Public,
	PadHideController: PadHideController.Public,
	VehicleController: VehicleController.Public,
	VitalController: VitalController.Public,
}

export type AllComponents = {}

export type ComponentAccess = {}

return {}
