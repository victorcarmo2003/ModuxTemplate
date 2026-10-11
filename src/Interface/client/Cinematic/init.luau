--!strict
-- Cinematic: one shared switch for "a cinematic owns the screen" (intro / finale / credits cutscene, and the moment
-- before the first Shift record of a run arrives). World tags read it to stay off while it is on (user request
-- 2026-10-11: the "Available on Day 5" sign, stock counters and price tags showed over the intro), and the HUD hides
-- with it.
-- Plain state, not a component: StageController (src/Stage/client) is the only writer; Interface components only
-- read `Active()` (reactive). Outside a play session (UI Labs stories) it stays false, so stories are unaffected.
-- Not read by PromptBillboard, SpeechBalloon, CallSubtitle, ScreenFade or SkipPill: the cutscene itself uses them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

const active = Vide.source(false)

local function read(): boolean
	return active()
end

local function set(value: boolean)
	if Vide.untrack(active) ~= value then
		active(value)
	end
end

return table.freeze({
	-- Reactive read: true while a cinematic owns the screen.
	Active = read,
	-- Only StageController writes.
	Set = set,
})
