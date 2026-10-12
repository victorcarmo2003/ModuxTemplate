--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)

export type Public = {
	InteriorPart: BasePart?,
	MissingPoints: { [string]: boolean },
	NoticeAt: { [Player]: number },
	ShutterAnchors: { [Instance]: boolean },
	ShutterAt: number,
	ShutterChanged: SignalLib.Signal<boolean, Player?>,
	ShutterClosed: boolean,
	Swapped: SignalLib.Signal<string, string>,
	Vehicle: Charm.Atom<string>,
	Setup: (self: Public) -> (),
	Current: (self: Public) -> string,
	Models: (self: Public) -> { Instance },
	CheckPose: (self: Public) -> (),
	IsShutterClosed: (self: Public) -> boolean,
	Interior: (self: Public) -> BasePart?,
	IsInsidePoint: (self: Public, position: Vector3) -> boolean,
	IsInside: (self: Public, player: Player) -> boolean,
	IsProtected: (self: Public, player: Player) -> boolean,
	IsShutterAnchor: (self: Public, anchor: Instance) -> boolean,
	ApplyShutter: (self: Public) -> (),
	AddShutterAnchor: (self: Public, anchor: Instance) -> (),
	SetShutter: (self: Public, closed: boolean, player: Player?, force: boolean?) -> boolean,
	ShutterPhase: (self: Public) -> boolean,
	CanToggleShutter: (self: Public, player: Player, anchor: Instance) -> boolean,
	NotifyClosed: (self: Public, player: Player) -> (),
	Restore: (self: Public, _data: any) -> (),
	DevCheck: (self: Public, name: string) -> (),
	DevReset: (self: Public) -> (),
	DevStatus: (self: Public) -> string,
}

return {}
