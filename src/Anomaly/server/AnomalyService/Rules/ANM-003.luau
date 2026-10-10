--!strict
-- ANM-003 "The stopped clock", server rule (T10: never replicated). docs/story/anomalies.md N3; design/npcs.md
-- NPC-011; architecture.md §19.13; DEC-054, DEC-195, DEC-204; TASK-113.
-- Verb light: the trailer switch off for DarkHold s in a row and then back on, within Window s of the clock stopping.
-- Turning it back on earlier resets the count (no failure). Past the window: every active player pays (omission on a
-- party target, DEC-204).
local Api = require(script.Parent.Parent.Api)

const rule: Api.Rule = {
	Anomaly = "anm_003_stopped_clock",
	Verb = "light",
	LikelyWrongVerb = "ignore",
	Window = 60,
	IsCritical = false,
	Params = {
		-- s the switch must stay off without interruption before it is turned back on
		DarkHold = 5,
	},
}

return rule
