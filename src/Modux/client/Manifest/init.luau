--!strict

local StarterPlayer = game:GetService("StarterPlayer")
local CameraController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.CameraController)
local ClassController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.ClassController)
local RigController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.RigController)
local CustomerController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.CustomerController)
local EconomyController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.EconomyController)
local HudController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.HudController)
local InputController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.InputController)
local PromptController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.PromptController)
local KitchenController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.KitchenController)
local MarketController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.MarketController)
local NetController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.NetController)
local OpalController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.OpalController)
local PlaceController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.PlaceController)
local ProfileController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.ProfileController)
local RoundController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.RoundController)
local VitalController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.VitalController)

export type AllControllers = {
	CameraController: CameraController.Public,
	ClassController: ClassController.Public,
	RigController: RigController.Public,
	CustomerController: CustomerController.Public,
	EconomyController: EconomyController.Public,
	HudController: HudController.Public,
	InputController: InputController.Public,
	PromptController: PromptController.Public,
	KitchenController: KitchenController.Public,
	MarketController: MarketController.Public,
	NetController: NetController.Public,
	OpalController: OpalController.Public,
	PlaceController: PlaceController.Public,
	ProfileController: ProfileController.Public,
	RoundController: RoundController.Public,
	VitalController: VitalController.Public,
}

export type AllComponents = {}

export type ComponentAccess = {}

return {}
