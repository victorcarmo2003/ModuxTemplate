--!strict
-- Server rule of ANM-007 The Walker (anomalies.md N7; npcs.md NPC-015; content-data.md §6.10; architecture.md §19.13;
-- FEAT-023; DEC-074, DEC-094, DEC-123; TASK-115). The only critical rule (DEC-074): reaching step Steps loses the
-- night at once, no 10 s window (RoundService:LoseNight("critical")). Verb "dont_look", party target: the Walker
-- advances one step per StepEvery seconds of party time in which any active player has it in the cone (not summed
-- per player), and backs one step every BackEvery seconds with nobody looking. Ignoring it is the right answer.
--   Steps      step that loses the night (step 0 = JL-09 ... 9 = P-01, StreetLight Order - 1; Steps = WALKER-10)
--   StepEvery  s of accumulated party gaze per step forward
--   BackEvery  s without any gaze per step back
--   Duration   s the occurrence lasts (npcs.md NPC-015 "45 s"); then the Walker backs into the dark and is gone
--   SignalFor  s of the post buzz (DEC-123, "~2 s and stops dead") before the Walker counts gazes; PROVISIONAL
return {
	Anomaly = "anm_007_walker",
	Verb = "dont_look",
	LikelyWrongVerb = "look",
	Window = 0,
	IsCritical = true,
	Params = {
		Steps = 5, -- 5 Juniper posts (user, 2026-10-10; MAP-01 §5.6)
		StepEvery = 1,
		BackEvery = 10,
		Duration = 45,
		SignalFor = 2,
	},
}
