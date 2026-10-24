--!strict
-- ANM-014 The big head, server rule (T10: never in shared). V2 family A (DEC-254, DEC-255; TASK-292).
-- Owner 2026-10-22 (Provisional; design/anomalies-after-accept-proposal.md §9, pilot): no ACCEPT / REFUSE; its order is
-- taken at the end of the talk and it waits in the delivery queue. Condition Hurry (Kit/CustomerActor): served within
-- Seconds = Resolved, x PayMult the price; the head swells a step every Seconds / Steps (record Step, rig AnomalyStep);
-- Seconds out, or its patience out first = jumpscare + faint of the taker.
local Api = require(script.Parent.Parent.Api)

const rule: Api.Rule = {
	Anomaly = "anm_014_big_head",
	Verb = "serve",
	LikelyWrongVerb = "serve",
	Window = 0,
	IsCritical = false,
	Params = {
		Variant = "bighead", -- CustomerService:SpawnActor variant
		-- PROVISIONAL (owner's Play): a K2 order takes ~30 s solo; 40 s leaves a margin, the order patience is 75 + 5K
		Condition = { Kind = "Hurry", Seconds = 40, Steps = 4, PayMult = 2 },
	},
}

return rule
