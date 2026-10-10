--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

type Controls = {
	Enable: (self: Controls, enabled: boolean?) -> (),
	Disable: (self: Controls) -> (),
}

export type Public = {
	Applied: boolean,
	Character: Model?,
	Controls: Controls?,
	Faces: { [Model]: boolean },
	Frozen: Vide.Source<boolean>,
	FrozenConnection: RBXScriptConnection?,
	Locked: Vide.Source<boolean>,
	Looked: boolean,
	Sinking: boolean,
	Setup: (self: Public) -> (),
	RefreshFaces: (self: Public) -> (),
	GetControls: (self: Public) -> Controls?,
	Sink: (self: Public, on: boolean) -> (),
	Apply: (self: Public, locked: boolean) -> (),
	Watch: (self: Public, character: Model?) -> (),
}

return {}
