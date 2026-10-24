--!strict
-- ANM-015 The floater, server rule (T10: never in shared). V2 family A (DEC-254, DEC-255; TASK-292).
-- Until 2026-10-22: Refuse resolved, "Take Order" on the actor was the error; patience running out is no error.
-- Owner 2026-10-22 (Provisional; design/anomalies-after-accept-proposal.md §9): no ACCEPT / REFUSE; the order is taken
-- at the end of the talk and the actor waits in the delivery queue (Kit/CustomerActor). Not migrated yet: condition
-- "Serve" (interim: any served order = Resolved, no error, no jumpscare); planned: Grounded (serve while it stands on the floor, proposal §2.7).
local Api = require(script.Parent.Parent.Api)

const rule: Api.Rule = {
	Anomaly = "anm_015_floater",
	Verb = "serve",
	LikelyWrongVerb = "serve",
	Window = 0,
	IsCritical = false,
	Params = {
		Variant = "float", -- CustomerService:SpawnActor variant
		Condition = { Kind = "Serve" },
	},
}

return rule
