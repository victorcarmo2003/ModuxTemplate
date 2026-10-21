--!strict
-- ANM-009 The knock, server rule (T10: never in shared). anomalies.md N9; npcs.md NPC-017; content-data.md §6.10;
-- architecture.md §19.13; FEAT-019; DEC-054, DEC-204, DEC-254, DEC-255; TASK-117, TASK-333.
-- V2 family D: someone knocks on the back door pretending to be Walt (two series of three knocks). The answer was not
-- opening the door: opening it from the first knock until DoorGrace s after the Window = jumpscare + faint at once for
-- who opened (personal). Verb "refuse" (refuse to open; the back door has no verb of its own). "Seen" is AudioZone: in
-- the trailer zone at the first knock. Camera 2 shows the one knocking (client).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)

-- restaurant (owner 2026-10-18): longer, the scene builds over it (Content.HorrorScenes anm_009_knock)
-- TASK-592 (owner 2026-10-19, PROVISIONAL Q-398): the answer is no longer "do nothing" but RUN AND LOCK the back door
-- (verb "lock"): two normal series, then a third one heavy (HeavyHits blows, HeavyGap s apart, each one bulging the
-- door). Locked before the heavy series starts (LockBy) = Resolved; not locked = the door gives on the last blow and
-- everyone active gets the existing error (jumpscare + -RuleBroken).

const rule: Api.Rule = {
	Anomaly = "anm_009_knock",
	Verb = "lock",
	LikelyWrongVerb = "refuse",
	Window = 13,
	IsCritical = false,
	Params = {
		-- s after the start of the second series of three knocks (the first one is at 0); trailer only. PROVISIONAL
		SecondAt = 10.8,
		-- restaurant (TASK-592): s of series 2 (closer, Walt's voice) and 3 (the heavy one). PROVISIONAL
		Series2At = 5,
		Series3At = 10,
		-- the heavy series: blows and s between them (the scene's Door Bulge steps sit on the same beats). PROVISIONAL
		HeavyHits = 3,
		HeavyGap = 1.2,
		-- s after the start the lock still counts (the heavy series' start). PROVISIONAL
		LockBy = 10,
		-- s after the Window the door still bites (the figure is still outside); PROVISIONAL (TASK-333)
		DoorGrace = 2,
		-- s after the grace it is leaving: the steps and the shadow slide out of the gap (scene); the door still bites
		-- until it is gone (owner 2026-10-19). PROVISIONAL
		LeaveFor = 4,
		-- s the record stays after Resolved / Failed so the release plays on every client (LINGER is 1 s). PROVISIONAL
		Linger = 4.5,
		-- s between the jumpscare and the faint
		ScareFaint = 0.5,
		-- trailer zone for "seen" (flat radius around MapPoint TRL, same as ANM-008). Inside the trailer always counts.
		Zone = "trailer",
		ZonePoint = "TRL",
		ZoneRadius = 24,
	},
}

return rule
