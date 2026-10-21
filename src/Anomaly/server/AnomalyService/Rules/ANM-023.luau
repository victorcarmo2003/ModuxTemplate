--!strict
-- ANM-023 The one on camera, server rule (T10: never in shared). V2 family A (owner request 2026-10-21, Provisional
-- Q-437). Looks like any customer at the window; only the security cameras show what it is (broken body, the head
-- turned to the lens). Refuse resolves; "Take Order" on it is the error (jumpscare + faint); patience out is no error.
local Api = require(script.Parent.Parent.Api)

const rule: Api.Rule = {
	Anomaly = "anm_023_on_camera",
	Verb = "refuse",
	LikelyWrongVerb = "serve",
	Window = 0,
	IsCritical = false,
	Params = {
		Variant = "oncam", -- CustomerService:SpawnActor variant
		Wrong = "take_order", -- customer action that fails the rule
		OmissionFails = false, -- left waiting until patience runs out: no penalty
	},
}

return rule
