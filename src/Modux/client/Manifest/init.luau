--!strict

local StarterPlayer = game:GetService("StarterPlayer")
local InputController = require(StarterPlayer.StarterPlayerScripts.client.Types.InputController)
local NetController = require(StarterPlayer.StarterPlayerScripts.client.Types.NetController)
local ProfileController = require(StarterPlayer.StarterPlayerScripts.client.Types.ProfileController)
local RoundController = require(StarterPlayer.StarterPlayerScripts.client.Types.RoundController)
local VitalController = require(StarterPlayer.StarterPlayerScripts.client.Types.VitalController)

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
