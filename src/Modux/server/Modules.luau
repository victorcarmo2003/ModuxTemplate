--!strict

local ServerScriptService = game:GetService("ServerScriptService")

return {
	ServerScriptService.server.Class.ClassService,
	ServerScriptService.server.Interaction.InteractionService,
	ServerScriptService.server.Net.NetService,
	ServerScriptService.server.Place.PlaceService,
	ServerScriptService.server.Player.PlayerService,
	ServerScriptService.server.Profile.ProfileService,
	ServerScriptService.server.Round.RoundService,
	ServerScriptService.server.Run.RunStateService,
	ServerScriptService.server.Vital.Vital,
	ServerScriptService.server.Vital.VitalService,
} :: { ModuleScript }
