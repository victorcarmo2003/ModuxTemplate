--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Mode = "FirstPerson" | "External"
type Group = "Head" | "Arm" | "Body"

export type Public = {
	Applied: boolean,
	ArmsVisible: Vide.Source<boolean>,
	Character: Model?,
	CharacterConnections: { RBXScriptConnection },
	Dirty: boolean,
	Groups: { [BasePart]: Group },
	Mode: Vide.Source<Mode>,
	Setup: (self: Public) -> (),
	SetMode: (self: Public, mode: Mode) -> (),
	SetArmsVisible: (self: Public, visible: boolean) -> (),
	IsFirstPerson: (self: Public) -> boolean,
	Track: (self: Public, character: Model?) -> (),
	Restore: (self: Public) -> (),
	Update: (self: Public) -> (),
}

return {}
