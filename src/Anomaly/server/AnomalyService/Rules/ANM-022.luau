--!strict
-- ANM-022 The head banger, server rule (T10: never in shared). V2 family A (TASK-591; owner 2026-10-19, Provisional
-- Q-399). It comes to the window like a customer; the window does NOT send it away. Only the shop's lights going out
-- (the switch, ctx.Light.IsSwitchOn) makes it leave: Resolved. With the window shut it beats its head on it (cue
-- head_bang every BangEvery s: thud, camera shake, the shutter jumping) - no penalty, it only gets worse. "Take Order"
-- on it = jumpscare + faint of who took it. Left waiting = it gives up, no penalty.
local Api = require(script.Parent.Parent.Api)

const rule: Api.Rule = {
	Anomaly = "anm_022_head_banger",
	-- "refuse" only so Kit/CustomerActor takes the actor (spawn, Take Order = error); the real answer, the lights going
	-- out, is Anomalies/ANM-022's (WindowRefuses = false: the window never counts as a refusal)
	Verb = "refuse",
	LikelyWrongVerb = "refuse",
	Window = 0,
	IsCritical = false,
	Params = {
		Variant = "banger", -- CustomerService:SpawnActor variant
		Wrong = "take_order", -- customer action that fails the rule
		OmissionFails = false,
		WindowRefuses = false, -- Kit/CustomerActor: the shut window never reaches it
		BangEvery = 0.55, -- s between two blows on the shut window
		BangFaster = 0.35, -- s between blows once it has banged BangRamp times
		BangRamp = 8,
		LeaveAfterDark = 0.8, -- s it stands in the dark before it walks off
	},
}

return rule
