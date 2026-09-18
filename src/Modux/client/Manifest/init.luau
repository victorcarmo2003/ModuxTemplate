--!strict

local StarterPlayer = game:GetService("StarterPlayer")
local InputController = require(StarterPlayer.StarterPlayerScripts.client.Input.InputController.Type)
local NetController = require(StarterPlayer.StarterPlayerScripts.client.Net.NetController.Type)
local ProfileController = require(StarterPlayer.StarterPlayerScripts.client.Profile.ProfileController.Type)
local RoundController = require(StarterPlayer.StarterPlayerScripts.client.Round.RoundController.Type)
local VitalController = require(StarterPlayer.StarterPlayerScripts.client.Vital.VitalController.Type)

export type AllControllers = {
	InputController: InputController.Public,
	NetController: NetController.Public,
	ProfileController: ProfileController.Public,
	RoundController: RoundController.Public,
	VitalController: VitalController.Public,
}

export type AllComponents = {}

export type ComponentAccess = {}

return {}
