--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Slots = require(ServerScriptService.server.Hide.HideService.Slots)

export type Public = {
	Anchors: { [Instance]: boolean },
	Changed: SignalLib.Signal<Player, boolean>,
	Enabled: boolean,
	Records: { [number]: boolean },
	Slots: Slots.Slots,
	Setup: (self: Public) -> (),
	IsHidden: (self: Public, player: Player) -> boolean,
	SlotOf: (self: Public, player: Player) -> number?,
	InZone: (self: Public, player: Player, pointId: string, radius: number) -> boolean,
	PhaseAllows: (self: Public) -> boolean,
	IsLiveSpot: (self: Public, anchor: Instance) -> boolean,
	Write: (self: Public, player: Player, slot: number?) -> (),
	Hide: (self: Public, player: Player, anchor: Instance) -> boolean,
	Release: (self: Public, player: Player) -> (),
	ReleaseAll: (self: Public) -> (),
	Check: (self: Public) -> (),
	RefreshPrompts: (self: Public) -> (),
	AddAnchor: (self: Public, anchor: Instance) -> (),
	CanHide: (self: Public, player: Player, anchor: Instance) -> boolean,
	CanGetUp: (self: Public, player: Player, anchor: Instance) -> boolean,
}

return {}
