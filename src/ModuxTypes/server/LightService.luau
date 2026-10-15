--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Zones = require(ReplicatedStorage.shared.Light.Zones)
local Rules = require(ServerScriptService.server.Light.LightService.Rules)

export type Record = { On: boolean, At: number }
export type Hush = Rules.Hush

export type Public = {
	Blackout: number?,
	Breakers: { [Instance]: boolean },
	Cache: Zones.Cache,
	Enabled: boolean,
	Hush: Hush?,
	LastToggle: number,
	MaxOrder: { [string]: number },
	Night: boolean,
	PostsOut: boolean,
	Published: boolean,
	Radii: { [string]: number },
	Records: { [string]: Record },
	Switch: boolean,
	SwitchChanged: SignalLib.Signal<boolean, Player?>,
	Switches: { [Instance]: boolean },
	Warned: { [string]: boolean },
	Zones: { [Instance]: Zones.Zone },
	ZonesDirty: boolean,
	Setup: (self: Public) -> (),
	WarnOnce: (self: Public, key: string, message: string) -> (),
	IsLit: (self: Public, position: Vector3) -> boolean,
	IsSwitchOn: (self: Public) -> boolean,
	IsHush: (self: Public) -> boolean,
	IsBlackout: (self: Public) -> boolean,
	GroupOn: (self: Public, key: string) -> boolean,
	Vehicle: (self: Public) -> string,
	Radius: (self: Public, group: Content.LightGroup) -> number,
	Input: (self: Public) -> Rules.Input,
	Refresh: (self: Public) -> (),
	Write: (self: Public, key: string, record: Record) -> (),
	SetSwitch: (self: Public, on: boolean, player: Player?, force: boolean?) -> boolean,
	BeginHush: (self: Public, startedAt: number, holdUntil: number) -> (),
	EndHush: (self: Public) -> (),
	BeginBlackout: (self: Public) -> (),
	EndBlackout: (self: Public) -> (),
	BeginPostsOut: (self: Public) -> (),
	EndPostsOut: (self: Public) -> (),
	Capture: (self: Public) -> { S: boolean },
	Restore: (self: Public, data: any) -> (),
	AddZone: (self: Public, instance: Instance) -> (),
	RemoveZone: (self: Public, instance: Instance) -> (),
	CheckZones: (self: Public) -> (),
	AddPost: (self: Public, instance: Instance) -> (),
	IsSwitchAnchor: (self: Public, anchor: Instance) -> boolean,
	RefreshSwitches: (self: Public) -> (),
	AddSwitch: (self: Public, anchor: Instance) -> (),
	TrailerModel: (self: Public) -> Model?,
	AddBreaker: (self: Public, anchor: Instance) -> (),
	RefreshBreakers: (self: Public) -> (),
	EnsureBreaker: (self: Public) -> boolean,
	CanReset: (self: Public, anchor: Instance) -> boolean,
	CanToggle: (self: Public, anchor: Instance) -> boolean,
}

return {}
