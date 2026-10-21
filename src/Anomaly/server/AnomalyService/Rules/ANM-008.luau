--!strict
-- ANM-008 The long car, server rule (T10: never in shared). anomalies.md N8; npcs.md NPC-016; content-data.md §6.10;
-- architecture.md §19.13, §19.14; FEAT-023; DEC-204, DEC-221, DEC-255; TASK-117, TASK-130, TASK-331.
-- Verb shutter (close the trailer service window), personal target: every active player in the trailer zone must be
-- protected (window closed and inside the trailer) when the high beam comes on (BeamDelay s after the car brakes in
-- front of the trailer). Not protected at the beam = blinding flash + jumpscare + -Sanity.RuleBroken (35) for that player
-- only, no faint (V2, DEC-255; owner 2026-10-19: a scare, not a kill). Until the car
-- drives away (StayFor s after the beam): opening the window, or a protected player leaving the trailer, = the same.
-- A player outside the trailer zone at the beam (e.g. at the Mart) is not tested.
local Api = require(script.Parent.Parent.Api)

const rule: Api.Rule = {
	Anomaly = "anm_008_long_car",
	Verb = "shutter",
	LikelyWrongVerb = "keep_working",
	Window = 13, -- was 10.5; owner 2026-10-19: +2.5 s (follows BeamDelay)
	IsCritical = false,
	Params = {
		-- s after the start the car has braked in front of the trailer (client timeline of Effects/ANM-008:
		-- slow 5.6 + rush 1.8 + brake 0.8); PROVISIONAL (TASK-331)
		ArriveAt = 8.2,
		-- s between braking and the high beam + horn (the last moment to close the window); PROVISIONAL
		-- was 1; owner 2026-10-16: +1.5 s to close the window (TASK-348); owner 2026-10-19: +2.5 s more (~5 s from the
		-- brake: the player may be at the back of the kitchen and has to come back to the window)
		BeamDelay = 5,
		-- s after the beam the car stays with the beam on (it backs out and drives away after that)
		StayFor = 6,
		-- s the record stays after Resolved/Failed so every client drives the car away (Effects/ANM-008); PROVISIONAL
		LeaveLinger = 6,
		-- trailer zone (tests/wave-3.md L3-03/L3-15; PROVISIONAL): flat radius around MapPoint TRL. Covers the trailer and
		-- the counter porch, far from the Mart (~100 studs). A player inside the trailer is always in the zone.
		ZonePoint = "TRL",
		ZoneRadius = 24,
	},
}

return rule
