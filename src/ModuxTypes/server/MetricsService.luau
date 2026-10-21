--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Log = require(ServerScriptService.server.Metrics.MetricsService.Log)
local Lobby = require(ServerScriptService.server.Metrics.MetricsService.Lobby)
local Zones = require(ServerScriptService.server.Metrics.MetricsService.Zones)
local AnomalyTypes = require(ServerScriptService.server.ModuxTypes.AnomalyService)

type Props = Log.Props
type Trace = AnomalyTypes.Trace

export type Public = {
	Live: { [Trace]: { Session: string, Steps: { [number]: boolean } } },
	Lobby: Lobby.Lobby?,
	ProductKeys: { [number]: string },
	RunStarted: boolean,
	Started: boolean,
	Tutorial: { [Player]: { [number]: boolean } },
	UiAt: { [Player]: number },
	Zones: Zones.Zones?,
	Setup: (self: Public) -> (),
	Init: (self: Public) -> (),
	DefineFunnels: (self: Public) -> (),
	Members: (self: Public) -> { Player },
	LostCause: (self: Public) -> Props,
	WireRound: (self: Public) -> (),
	PartyOf: (self: Public, trace: Trace) -> { Player },
	AnomalyBase: (self: Public, trace: Trace, t: number) -> Props,
	AnomalyStep: (self: Public, trace: Trace, step: number, upTo: number?) -> (),
	AnomalyOutcome: (self: Public, trace: Trace, phase: string, failed: { Player }, reason: string) -> (),
	WireAnomalies: (self: Public) -> (),
	WireCrew: (self: Public) -> (),
	WireWorld: (self: Public) -> (),
	OnTutorialStep: (self: Public, player: Player, index: number) -> (),
	OnUi: (self: Public, player: Player, event: string, key: string?, offer: string?) -> (),
	WireLobby: (self: Public) -> (),
	WireRunZones: (self: Public) -> (),
	WireNet: (self: Public) -> (),
}

return {}
