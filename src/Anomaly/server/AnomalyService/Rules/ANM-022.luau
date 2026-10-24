--!strict
-- ANM-022 The head banger, server rule (T10: never in shared). V2 family A (TASK-591; owner 2026-10-19, Provisional
-- Q-399). It comes to the window like a customer; the window does NOT send it away. Only the shop's lights going out
-- (the switch, ctx.Light.IsSwitchOn) makes it leave: Resolved. With the window shut it beats its head on it (cue
-- head_bang every BangEvery s: thud, camera shake, the shutter jumping) - no penalty, it only gets worse. "Take Order"
-- on it was the error until 2026-10-22. Left waiting = it gives up, no penalty.
-- Owner 2026-10-22 (Provisional; design/anomalies-after-accept-proposal.md §9): no ACCEPT / REFUSE; the order is taken
-- at the end of the talk and the actor waits in the delivery queue (Kit/CustomerActor). Not migrated yet: condition
-- "Serve" (interim: any served order = Resolved, no error, no jumpscare); planned: Hurry by blows (proposal §2.8).
local Api = require(script.Parent.Parent.Api)

const rule: Api.Rule = {
	Anomaly = "anm_022_head_banger",
	-- the lights going out at the counter are Anomalies/ANM-022's answer; in the queue the Kit's condition decides
	Verb = "serve",
	LikelyWrongVerb = "refuse",
	Window = 0,
	IsCritical = false,
	Params = {
		Variant = "banger", -- CustomerService:SpawnActor variant
		Condition = { Kind = "Serve" },
		BangEvery = 0.55, -- s between two blows on the shut window
		BangFaster = 0.35, -- s between blows once it has banged BangRamp times
		BangRamp = 8,
		LeaveAfterDark = 0.8, -- s it stands in the dark before it walks off
	},
}

return rule
