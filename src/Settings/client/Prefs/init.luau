--!strict
-- Prefs: the player settings other client code reads without depending on SettingsController (TASK-279; Provisional).
-- Plain state, not a controller: SettingsController is the only writer (`Set`), readers call the reactive getters.
-- Outside a play session (UI Labs stories) it keeps the SettingsRules defaults, so stories are unaffected.
--   PrepAssist()     prep mode hint line and drag paw on (PrepController, World.Coach)
--   ReducedMotion()  game-side reduced motion (Motion.Reduced ORs it with the Roblox setting)
-- Volumes and PromptMode are not here: SettingsController applies them (AudioController, LocalPlayer attribute).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local SettingsRules = require(ReplicatedStorage.shared.Settings.SettingsRules)

const prepAssist = Vide.source(SettingsRules.Defaults.PrepAssist)
const reducedMotion = Vide.source(SettingsRules.Defaults.ReducedMotion)

local function readPrepAssist(): boolean
	return prepAssist()
end

local function readReducedMotion(): boolean
	return reducedMotion()
end

-- Only SettingsController writes.
local function set(settings: SettingsRules.Settings)
	if Vide.untrack(prepAssist) ~= settings.PrepAssist then
		prepAssist(settings.PrepAssist)
	end
	if Vide.untrack(reducedMotion) ~= settings.ReducedMotion then
		reducedMotion(settings.ReducedMotion)
	end
end

return table.freeze({
	PrepAssist = readPrepAssist,
	ReducedMotion = readReducedMotion,
	Set = set,
})
