--!strict
-- ANM-005 The Raincoat Lady, server rule (T10: never in shared). anomalies.md N5; npcs.md NPC-013; DEC-051, DEC-054,
-- DEC-195, DEC-204. Serve resolves (Complete, Perfect or Incomplete: an incomplete hot dog is not an error).
-- Window 0: the deadline is her patience (normal customer patience, CustomerService).
-- Owner 2026-10-22 (Provisional; design/anomalies-after-accept-proposal.md §9): no ACCEPT / REFUSE; the order is taken
-- at the end of the talk and she waits in the delivery queue (Kit/CustomerActor). Condition "Serve" (proposal §2.10, not
-- tuned yet): any served order = Resolved; her patience out = -OmitSanity from every active player (was -RuleBroken
-- each, OmissionFails), never a jumpscare.
local Api = require(script.Parent.Parent.Api)

const rule: Api.Rule = {
	Anomaly = "anm_005_raincoat_lady",
	Verb = "serve",
	LikelyWrongVerb = "refuse",
	Window = 0,
	IsCritical = false,
	Params = {
		Variant = "raincoat", -- CustomerService:SpawnActor variant
		Condition = { Kind = "Serve", OmitSanity = 5 },
	},
}

return rule
