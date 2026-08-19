--!strict
-- Lista explícita de módulos que o Loader deve carregar (ver src/shared/Modux/src/Loader.luau).
-- Se este arquivo não existisse, o Loader cairia num fallback que carrega todo
-- ModuleScript debaixo de Shared/Server/Client -- funciona, mas é menos previsível.
--
-- Caminhos são relativos à raiz de cada escopo:
--   Shared -> ReplicatedStorage.Shared (src/shared)
--   Server -> ServerScriptService.Server (src/server)
--   Client -> StarterPlayer.StarterPlayerScripts.Client (src/client)

return {
	Shared = {},
	Server = {
		"Components.Player.VitalComponent",
		"Services.Player.PlayerService",
		"Services.Player.SpawnService",
		"Services.Player.VitalService",
		"Services.ProfileService",
	},
	Client = {
		"Controllers.InputContext.InputController",
		"Controllers.Player.AnimateController",
	},
}
