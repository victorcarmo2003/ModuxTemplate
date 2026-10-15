--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Public = {
	Bound: boolean,
	Busy: Vide.Source<boolean>,
	Count: Vide.Source<number>,
	Gui: ScreenGui?,
	Setup: (self: Public) -> (),
	Shows: (self: Public) -> boolean,
	CanBuy: (self: Public) -> boolean,
	Label: (self: Public) -> string,
	Use: (self: Public) -> (),
	Buy: (self: Public) -> (),
	SetBound: (self: Public, on: boolean) -> (),
	Mount: (self: Public, playerGui: Instance) -> (),
}

return {}
