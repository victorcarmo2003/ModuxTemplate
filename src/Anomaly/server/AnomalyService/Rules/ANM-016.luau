--!strict
-- ANM-016 The starer, server rule (T10: never in shared). V2 family A (DEC-254, DEC-255; TASK-292).
-- Until 2026-10-22: Refuse resolved, "Take Order" on the actor was the error; patience running out is no error.
-- Owner 2026-10-22 (Provisional; design/anomalies-after-accept-proposal.md §9): no ACCEPT / REFUSE; the order is taken
-- at the end of the talk and the actor waits in the delivery queue (Kit/CustomerActor). Not migrated yet: condition
-- "Serve" (interim: any served order = Resolved, no error, no jumpscare); planned: Serve (proposal §2.11: serve him, don't stare back).
local Api = require(script.Parent.Parent.Api)

const rule: Api.Rule = {
	Anomaly = "anm_016_starer",
	Verb = "serve",
	LikelyWrongVerb = "serve",
	Window = 0,
	IsCritical = false,
	Params = {
		Variant = "stare", -- CustomerService:SpawnActor variant
		Condition = { Kind = "Serve" },
	},
}

return rule
