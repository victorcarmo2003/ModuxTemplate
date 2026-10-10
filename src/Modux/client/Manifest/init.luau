--!strict

local StarterPlayer = game:GetService("StarterPlayer")
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
local EconomyController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.EconomyController)
local HallucinationController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.HallucinationController)
local HudController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.HudController)
local InputController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.InputController)
local PromptController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.PromptController)
local ItemController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.ItemController)
local KitchenController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.KitchenController)
local LightController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.LightController)
local MarketController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.MarketController)
local NetController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.NetController)
local OpalController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.OpalController)
local PedestrianController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.PedestrianController)
local PlaceController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.PlaceController)
local ProfileController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.ProfileController)
local RoundController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.RoundController)
local ThiefController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.ThiefController)
local TrafficController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.TrafficController)
local VehicleController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.VehicleController)
local VitalController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.VitalController)

export type AllControllers = {
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
	EconomyController: EconomyController.Public,
	HallucinationController: HallucinationController.Public,
	HudController: HudController.Public,
	InputController: InputController.Public,
	PromptController: PromptController.Public,
	ItemController: ItemController.Public,
	KitchenController: KitchenController.Public,
	LightController: LightController.Public,
	MarketController: MarketController.Public,
	NetController: NetController.Public,
	OpalController: OpalController.Public,
	PedestrianController: PedestrianController.Public,
	PlaceController: PlaceController.Public,
	ProfileController: ProfileController.Public,
	RoundController: RoundController.Public,
	ThiefController: ThiefController.Public,
	TrafficController: TrafficController.Public,
	VehicleController: VehicleController.Public,
	VitalController: VitalController.Public,
}

export type AllComponents = {}

export type ComponentAccess = {}

return {}
