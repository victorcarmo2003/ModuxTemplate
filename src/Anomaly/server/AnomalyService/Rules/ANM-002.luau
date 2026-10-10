--!strict
-- ANM-002 "The wrong food", server rule (T10: never replicated). docs/story/anomalies.md N2; design/npcs.md NPC-010;
-- architecture.md §19.13; DEC-054, DEC-195, DEC-204; TASK-113.
-- Verb discard: throwing the altered item (or the hot dog made with it) away resolves. Serving a hot dog made with it
-- is the error (Wrong, no payment, smoke, -RuleBroken for who served). Leaving it there is not an error.
-- Window 0: no deadline, the occurrence lasts until the item is used, discarded or the night ends (06:00 AM).
local Api = require(script.Parent.Parent.Api)

const rule: Api.Rule = {
	Anomaly = "anm_002_wrong_food",
	Verb = "discard",
	LikelyWrongVerb = "serve",
	Window = 0,
	IsCritical = false,
	Params = {
		-- where the altered item may show up (KitchenService:Alter kinds), tried in a random order per occurrence
		Kinds = { "rail", "board" },
		-- s the altered item may be missing (no station, Tool or stash has it) before the occurrence closes with no
		-- success and no failure (item lost on the ground, FEAT-036). Covers the deferred Discarded signal.
		-- PROVISIONAL (backend-coder, TASK-113)
		LostGrace = 2,
	},
}

return rule
