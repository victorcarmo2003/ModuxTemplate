--!strict
-- ANM-008 The long car, server rule (T10: never in shared). anomalies.md N8; npcs.md NPC-016; content-data.md §6.10;
-- architecture.md §19.13; FEAT-023; DEC-054, DEC-087, DEC-195, DEC-204; TASK-117.
-- Verb hide, personal target: every active player in the trailer zone must be hidden when the high beam flashes twice
-- (Window = HideWindow s after the beam comes on) and stay hidden until the car drives away (StayFor s after the
-- flash). Not hidden at the flash, or getting up before the car leaves = -35 for that player only. A player outside the
-- trailer zone at the flash (e.g. at the Mart) is not tested.
local Api = require(script.Parent.Parent.Api)

const rule: Api.Rule = {
	Anomaly = "anm_008_long_car",
	Verb = "hide",
	LikelyWrongVerb = "keep_working",
	Window = 8,
	IsCritical = false,
	Params = {
		-- s after the start the car is parked on AN-12 (client timeline of Effects/ANM-008: 6 + 0.5 + 3); PROVISIONAL
		ArriveAt = 9.5,
		-- s between parking and the high beam (npcs.md N8 "farol alto acende 2 s após estacionar")
		BeamDelay = 2,
		-- s after the beam to hide (content-data.md §6.10 HideWindow; same number as Window)
		HideWindow = 8,
		-- s after the flash the car stays parked (it drives away after that)
		StayFor = 15,
		-- s the record stays after Resolved/Failed so every client drives the car away (Effects/ANM-008); PROVISIONAL
		LeaveLinger = 6,
		-- trailer zone (tests/wave-3.md L3-03/L3-15; PROVISIONAL): flat radius around MapPoint TRL (the Pad; CART is
		-- 3.5 studs away). Covers the trailer and the counter porch (LZ-1/LZ-2), far from the Mart (~100 studs).
		-- A hidden player is always in the zone.
		ZonePoint = "TRL",
		ZoneRadius = 24,
	},
}

return rule
