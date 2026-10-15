--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local SettingsRules = require(ReplicatedStorage.shared.Settings.SettingsRules)

export type Public = {
	Dirty: boolean,
	Gui: ScreenGui?,
	Open: Vide.Source<boolean>,
	SaveToken: number,
	Scale: Vide.Source<number>,
	Values: Vide.Source<SettingsRules.Settings>,
	Setup: (self: Public) -> (),
	Apply: (self: Public, settings: SettingsRules.Settings) -> (),
	Set: (self: Public, key: SettingsRules.Key, value: any) -> (),
	ScheduleSave: (self: Public) -> (),
	SetOpen: (self: Public, open: boolean) -> (),
	Select: (self: Public, open: boolean) -> (),
	Toggle: (self: Public) -> (),
	Rescale: (self: Public, camera: Camera?) -> (),
	WatchViewport: (self: Public) -> (),
	Mount: (self: Public, playerGui: Instance) -> (),
}

return {}
