--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SettingsRules = require(ReplicatedStorage.shared.Settings.SettingsRules)

export type Public = {
	LastAt: { [Player]: number },
	Setup: (self: Public) -> (),
	Get: (self: Public, player: Player) -> SettingsRules.Settings?,
	Send: (self: Public, player: Player) -> (),
	Save: (self: Public, player: Player, raw: any) -> (),
}

return {}
