--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Public = {
	Follow: RBXScriptConnection?,
	Gui: Instance?,
	Hidden: () -> boolean,
	Holder: BasePart?,
	LastFire: number,
	LocalPoses: { [number]: Model },
	MySlot: Vide.Source<number>,
	Slots: { [number]: number },
	Unmount: (() -> ())?,
	Setup: (self: Public) -> (),
	IsHidden: (self: Public, userId: number) -> boolean,
	SlotOf: (self: Public, userId: number) -> number?,
	SlotTaken: (self: Public, slot: number) -> boolean,
	SpotId: (self: Public, slot: number) -> number?,
	GetUp: (self: Public) -> (),
	ShowButton: (self: Public) -> (),
	HideButton: (self: Public) -> (),
	PoseMate: (self: Public, userId: number) -> (),
	UnposeMate: (self: Public, userId: number) -> (),
	Apply: (self: Public, userId: number, slot: number?) -> (),
}

return {}
