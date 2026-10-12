--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Beacon = require(StarterPlayer.StarterPlayerScripts.client.Tutorial.TutorialController.Beacon)

export type Public = {
	ArrowFar: Vide.Source<boolean>,
	Beacon: Beacon.Beacon,
	FocusToken: number,
	Focusing: boolean,
	Folder: Folder?,
	Marked: Vide.Source<boolean>,
	Mounted: boolean,
	Scale: Vide.Source<number>,
	Unmounts: { () -> () },
	Setup: (self: Public) -> (),
	FxFolder: (self: Public) -> Folder,
	Mark: (self: Public, adornee: Instance?, lift: number?) -> (),
	Clear: (self: Public) -> (),
	IsMarked: (self: Public) -> boolean,
	Focus: (self: Public, getter: () -> Vector3?, seconds: number, fov: number?) -> boolean,
	EndFocus: (self: Public) -> (),
	Mount: (self: Public, playerGui: Instance) -> (),
	Update: (self: Public) -> (),
}

return {}
