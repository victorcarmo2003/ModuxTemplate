--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Lobby = require(ServerScriptService.server.Metrics.MetricsService.Lobby)

export type Public = {
	Lobby: Lobby.Lobby?,
	ProductKeys: { [number]: string },
	RunStarted: boolean,
	Started: boolean,
	Tutorial: { [Player]: { [number]: boolean } },
	UiAt: { [Player]: number },
	Setup: (self: Public) -> (),
	Init: (self: Public) -> (),
	Members: (self: Public) -> { Player },
	WireRound: (self: Public) -> (),
	WireAnomalies: (self: Public) -> (),
	WireCrew: (self: Public) -> (),
	WireWorld: (self: Public) -> (),
	OnTutorialStep: (self: Public, player: Player, index: number) -> (),
	OnUi: (self: Public, player: Player, event: string, key: string?, offer: string?) -> (),
	WireLobby: (self: Public) -> (),
	WireNet: (self: Public) -> (),
}

return {}
