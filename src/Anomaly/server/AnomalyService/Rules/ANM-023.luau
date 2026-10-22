--!strict
-- ANM-023 The one on camera, server rule (T10: never in shared). V2 family A (owner request 2026-10-21, Provisional
-- Q-437). Looks like any customer at the window; only the security cameras show what it is (broken body, the head
-- turned to the lens). Until 2026-10-22: Refuse resolved, "Take Order" was the error; patience out is no error.
-- Owner 2026-10-22 (Provisional; design/anomalies-after-accept-proposal.md §9): no ACCEPT / REFUSE; the order is taken
-- at the end of the talk and the actor waits in the delivery queue (Kit/CustomerActor). Not migrated yet: condition
-- "Serve" (interim: any served order = Resolved, no error, no jumpscare); planned: NoServe + the cameras (proposal §2.9).
local Api = require(script.Parent.Parent.Api)

const rule: Api.Rule = {
	Anomaly = "anm_023_on_camera",
	Verb = "serve",
	LikelyWrongVerb = "serve",
	Window = 0,
	IsCritical = false,
	Params = {
		Variant = "oncam", -- CustomerService:SpawnActor variant
		Condition = { Kind = "Serve" },
		-- owner 2026-10-22 (Provisional): NoServe actor, its patience runs OrderRules.UnservablePatienceScale (x0.5)
		Unservable = true,
	},
}

return rule
