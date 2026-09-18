--!strict

local ServerScriptService = game:GetService("ServerScriptService")

return {
	ServerScriptService.server.Components.Vital,
	ServerScriptService.server.Services.GameService,
	ServerScriptService.server.Services.NetService,
	ServerScriptService.server.Services.PlayerService,
	ServerScriptService.server.Services.ProfileService,
	ServerScriptService.server.Services.VitalService,
} :: { ModuleScript }
