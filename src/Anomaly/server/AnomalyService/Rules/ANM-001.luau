--!strict
-- ANM-001 The blank folks, server rule (T10: never in shared). anomalies.md N1; npcs.md NPC-009; DEC-051, DEC-054.
-- Refuse resolves; "Take Order" on the actor is the error (Fail of who took it); patience running out is no error.
-- Window 0: the deadline is the customer's own patience (CustomerService).
local Api = require(script.Parent.Parent.Api)

const rule: Api.Rule = {
	Anomaly = "anm_001_blank_folks",
	Verb = "refuse",
	LikelyWrongVerb = "serve",
	Window = 0,
	IsCritical = false,
	Params = {
		Variant = "blank", -- CustomerService:SpawnActor variant
		Wrong = "take_order", -- customer action that fails the rule
		OmissionFails = false, -- left waiting until patience runs out: no penalty
	},
}

return rule
