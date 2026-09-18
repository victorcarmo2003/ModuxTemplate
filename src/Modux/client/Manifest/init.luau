--!strict

local StarterPlayer = game:GetService("StarterPlayer")
local InputController = require(StarterPlayer.StarterPlayerScripts.client.Controllers.InputController.Type)
local NetController = require(StarterPlayer.StarterPlayerScripts.client.Controllers.NetController.Type)
local ProfileController = require(StarterPlayer.StarterPlayerScripts.client.Controllers.ProfileController.Type)
local RoundController = require(StarterPlayer.StarterPlayerScripts.client.Controllers.RoundController.Type)
local VitalController = require(StarterPlayer.StarterPlayerScripts.client.Controllers.VitalController.Type)

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
