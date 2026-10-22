--!strict
-- ANM-001 The blank folks, server rule (T10: never in shared). anomalies.md N1; npcs.md NPC-009; DEC-051, DEC-054.
-- Until 2026-10-22: Refuse resolved, "Take Order" on the actor was the error; patience running out is no error.
-- Window 0: the deadline is the customer's own patience (CustomerService).
-- Owner 2026-10-22 (Provisional; design/anomalies-after-accept-proposal.md §9): no ACCEPT / REFUSE; the order is taken
-- at the end of the talk and the actor waits in the delivery queue (Kit/CustomerActor). Not migrated yet: condition
-- "Serve" (interim: any served order = Resolved, no error, no jumpscare); planned: NoServe (a blank ticket: don't cook it, proposal §2.6).
local Api = require(script.Parent.Parent.Api)

const rule: Api.Rule = {
	Anomaly = "anm_001_blank_folks",
	Verb = "serve",
	LikelyWrongVerb = "serve",
	Window = 0,
	IsCritical = false,
	Params = {
		Variant = "blank", -- CustomerService:SpawnActor variant
		Condition = { Kind = "Serve" },
		-- owner 2026-10-22 (Provisional): NoServe actor, its patience runs OrderRules.UnservablePatienceScale (x0.5)
		Unservable = true,
	},
}

return rule
