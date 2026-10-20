--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Public = {
	Elapsed: Vide.Source<number>,
	Gui: ScreenGui?,
	Scale: Vide.Source<number>,
	Setup: (self: Public) -> (),
	Shown: (self: Public) -> boolean,
	Broken: (self: Public) -> boolean,
	Title: (self: Public) -> string,
	LossTitle: (self: Public) -> string,
	Line: (self: Public) -> string,
	Progress: (self: Public) -> number,
	Tick: (self: Public) -> (),
	WatchViewport: (self: Public) -> (),
	Mount: (self: Public, playerGui: Instance) -> (),
}

return {}
