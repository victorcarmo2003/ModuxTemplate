--!strict
-- ANM-012 The turned neck, server rule (T10: never in shared). V2 family A (DEC-254, DEC-255; TASK-292).
-- Owner 2026-10-22 (Provisional; design/anomalies-after-accept-proposal.md §9, pilot): no ACCEPT / REFUSE; her order is
-- taken at the end of the talk and she waits in the delivery queue. Condition NoLook (Kit/CustomerActor): at the serve,
-- her head inside the gaze cone of who serves (Angle degrees full cone, up to Range studs) = jumpscare + faint of that
-- player; served without looking = Resolved, x PayMult the price. Her patience out = she leaves, no penalty.
local Api = require(script.Parent.Parent.Api)

const rule: Api.Rule = {
	Anomaly = "anm_012_turned_neck",
	Verb = "serve",
	LikelyWrongVerb = "dont_look",
	Window = 0,
	IsCritical = false,
	Params = {
		Variant = "neck", -- CustomerService:SpawnActor variant
		-- PROVISIONAL (owner's Play): 30 degrees = her head near the middle of the screen; looking down at the counter or the
		-- tray in front of her (~25 degrees under her head at arm's length) is safe
		Condition = { Kind = "NoLook", Angle = 30, Range = 24, PayMult = 2 },
	},
}

return rule
