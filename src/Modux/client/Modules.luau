--!strict

local StarterPlayer = game:GetService("StarterPlayer")

return {
	StarterPlayer.StarterPlayerScripts.client.Controllers.InputController,
	StarterPlayer.StarterPlayerScripts.client.Controllers.NetController,
	StarterPlayer.StarterPlayerScripts.client.Controllers.ProfileController,
	StarterPlayer.StarterPlayerScripts.client.Controllers.RoundController,
	StarterPlayer.StarterPlayerScripts.client.Controllers.VitalController,
} :: { ModuleScript }
