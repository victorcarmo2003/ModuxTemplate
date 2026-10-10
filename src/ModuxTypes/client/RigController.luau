--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)

type Pack = CrewRig.Pack
type Rig = { Connections: { RBXScriptConnection }, Pending: boolean }

export type Public = {
	CharacterConnection: RBXScriptConnection?,
	Expressions: { [Model]: string },
	LowBand: boolean,
	Preloaded: { [string]: boolean },
	Rigs: { [Model]: Rig },
	Setup: (self: Public) -> (),
	Resolve: (self: Public, model: Model) -> (Pack, string?),
	SetExpression: (self: Public, model: Model, expression: string?) -> (),
	Refresh: (self: Public, model: Model?) -> (),
	Schedule: (self: Public, model: Model) -> (),
	Apply: (self: Public, model: Model) -> (),
	Preload: (self: Public, model: Model) -> (),
	Add: (self: Public, instance: Instance) -> (),
	Remove: (self: Public, instance: Instance) -> (),
	WatchCharacter: (self: Public, character: Model?) -> (),
}

return {}
