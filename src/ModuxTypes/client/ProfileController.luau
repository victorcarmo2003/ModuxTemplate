--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Public = {
	Classes: Vide.Source<{ [string]: boolean }>,
	Gems: Vide.Source<number>,
	Guides: Vide.Source<{ [string]: boolean }>,
	Ready: Vide.Source<boolean>,
	Selected: Vide.Source<string>,
	TutorialDone: Vide.Source<boolean>,
	Setup: (self: Public) -> (),
	Owns: (self: Public, class: string) -> boolean,
}

return {}
