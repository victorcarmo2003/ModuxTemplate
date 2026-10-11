--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Public = {
	Unmount: (() -> ())?,
	Waited: Vide.Source<boolean>,
	Setup: (self: Public) -> (),
	SceneActive: (self: Public) -> boolean,
	Active: (self: Public) -> boolean,
}

return {}
