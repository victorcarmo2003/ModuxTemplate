--!strict
-- ANM-005 The Raincoat Lady, server rule (T10: never in shared). anomalies.md N5; npcs.md NPC-013; DEC-051, DEC-054,
-- DEC-195, DEC-204. Serve resolves (Complete, Perfect or Incomplete: an incomplete hot dog is not an error); "Refuse"
-- is the error (Fail of who refused); patience running out fails every active member (party target).
-- Window 0: the deadline is her patience (normal customer patience, CustomerService).
local Api = require(script.Parent.Parent.Api)

const rule: Api.Rule = {
	Anomaly = "anm_005_raincoat_lady",
	Verb = "serve",
	LikelyWrongVerb = "refuse",
	Window = 0,
	IsCritical = false,
	Params = {
		Variant = "raincoat", -- CustomerService:SpawnActor variant
		Wrong = "refuse", -- customer action that fails the rule
		OmissionFails = true, -- patience ran out: Fail("active")
		Pass = { "Complete", "Perfect", "Incomplete" }, -- serve results that resolve it
	},
}

return rule
