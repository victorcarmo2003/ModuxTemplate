--!strict
-- ANM-014 The big head, server rule (T10: never in shared). V2 family A (DEC-254, DEC-255; TASK-292).
-- Refuse resolves; "Take Order" on the actor is the error (jumpscare + faint); patience running out is no error.
local Api = require(script.Parent.Parent.Api)

const rule: Api.Rule = {
	Anomaly = "anm_014_big_head",
	Verb = "refuse",
	LikelyWrongVerb = "serve",
	Window = 0,
	IsCritical = false,
	Params = {
		Variant = "bighead", -- CustomerService:SpawnActor variant
		Wrong = "take_order", -- customer action that fails the rule
		OmissionFails = false, -- left waiting until patience runs out: no penalty
	},
}

return rule
