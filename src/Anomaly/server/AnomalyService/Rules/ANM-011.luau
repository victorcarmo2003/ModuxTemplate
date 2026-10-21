--!strict
-- ANM-011 The shaker, server rule (T10: never in shared). V2 family A (DEC-254, DEC-255; TASK-292).
-- TASK-591 (owner 2026-10-19, Provisional, Q-399): he is not a monster, he is starving and stressed. The verb is
-- SERVE: his ticket is a plain hot dog with nothing on it (CustomerService.OpenTicket, Variant "shake"); serving it
-- calms him (Resolved). Shutting the window on him (refuse) or serving anything with a topping = jumpscare + faint of
-- who did it. Patience running out is no error.
local Api = require(script.Parent.Parent.Api)

const rule: Api.Rule = {
	Anomaly = "anm_011_shaker",
	Verb = "serve",
	LikelyWrongVerb = "refuse",
	Window = 0,
	IsCritical = false,
	Params = {
		Variant = "shake", -- CustomerService:SpawnActor variant (its ticket is plain)
		Wrong = "refuse", -- the window shut in his face (after ShutGrace) fails the rule
		WrongServeFails = true, -- a hot dog with any topping is the error too (Kit/CustomerActor)
		OmissionFails = false, -- left waiting until patience runs out: no penalty
		Pass = { "Complete", "Perfect" }, -- serve results that resolve it
	},
}

return rule
