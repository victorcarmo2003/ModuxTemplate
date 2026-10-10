--!strict

local StarterPlayer = game:GetService("StarterPlayer")

return {
	StarterPlayer.StarterPlayerScripts.client.Camera.CameraController,
	StarterPlayer.StarterPlayerScripts.client.Input.InputController,
	StarterPlayer.StarterPlayerScripts.client.Interaction.PromptController,
	StarterPlayer.StarterPlayerScripts.client.Net.NetController,
	StarterPlayer.StarterPlayerScripts.client.Place.PlaceController,
	StarterPlayer.StarterPlayerScripts.client.Profile.ProfileController,
	StarterPlayer.StarterPlayerScripts.client.Round.RoundController,
	StarterPlayer.StarterPlayerScripts.client.Vital.VitalController,
} :: { ModuleScript }
