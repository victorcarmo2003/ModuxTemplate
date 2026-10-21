--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)

type Door = {
	MapId: string,
	Model: Model,
	Leaves: { BasePart },
	Collide: { [BasePart]: boolean },
	Anchors: { Attachment },
	Open: boolean,
}

export type Public = {
	AnchorDoor: { [Instance]: string },
	Closed: SignalLib.Signal<Player?, string>,
	Doors: { [string]: Door },
	Enabled: boolean,
	Lockable: { [string]: boolean },
	LockedBy: SignalLib.Signal<Player, string>,
	Locks: { [string]: boolean },
	Opened: SignalLib.Signal<Player, string>,
	Tried: SignalLib.Signal<Player, string>,
	Setup: (self: Public) -> (),
	Door: (self: Public, mapId: string?) -> Door?,
	IsOpen: (self: Public, mapId: string?) -> boolean,
	IsLocked: (self: Public) -> boolean,
	IsLockedByHand: (self: Public) -> boolean,
	DoorPosition: (self: Public, mapId: string?) -> Vector3?,
	Refresh: (self: Public, door: Door) -> (),
	SetOpen: (self: Public, mapId: string, open: boolean, player: Player?) -> (),
	SetLocked: (self: Public, reason: string, on: boolean) -> (),
	SetLockable: (self: Public, reason: string, on: boolean) -> (),
	LockByHand: (self: Public, player: Player, mapId: string) -> (),
	Bind: (self: Public, model: Instance) -> (),
}

return {}
