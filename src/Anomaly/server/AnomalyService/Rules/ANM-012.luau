--!strict
-- ANM-012 The turned neck, server rule (T10: never in shared). V2 family A (DEC-254, DEC-255; TASK-292).
-- Refuse resolves; "Take Order" on the actor is the error (jumpscare + faint); patience running out is no error.
local Api = require(script.Parent.Parent.Api)

const rule: Api.Rule = {
	Anomaly = "anm_012_turned_neck",
	Verb = "refuse",
	LikelyWrongVerb = "serve",
	Window = 0,
	IsCritical = false,
	Params = {
		Variant = "neck", -- CustomerService:SpawnActor variant
		Wrong = "take_order", -- customer action that fails the rule
		OmissionFails = false, -- left waiting until patience runs out: no penalty
		-- s from the window shut in her face to her throwing it open again (TASK-336; PROVISIONAL)
		SlamAfter = 1.2,
	},
}

return rule
