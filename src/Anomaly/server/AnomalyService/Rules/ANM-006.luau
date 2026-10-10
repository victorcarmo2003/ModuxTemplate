--!strict
-- Server rule of ANM-006 The wavers (anomalies.md N6; npcs.md NPC-014; content-data.md §6.10; FEAT-023; TASK-115).
-- Verb "dont_look", personal target: a player fails by keeping the lit window in the gaze cone for LookLimit seconds
-- in a row (a glance only costs the -5 of "seen"). No omission: with nobody failing, the window goes dark by itself
-- after AutoOff seconds. Never critical (DEC-074).
--   LookLimit   s of continuous gaze that fail (npcs.md: 2.9 s does not fail, 3.0 s fails)
--   AutoOff     s from the start until the window goes dark (end of the occurrence)
--   CurtainLead s between the curtain sound (Phase Signal) and the waving silhouette (Phase Active); PROVISIONAL
--               (TASK-115: "curtain before the silhouette", npcs.md N6, gives no number)
return {
	Anomaly = "anm_006_wavers",
	Verb = "dont_look",
	LikelyWrongVerb = "look",
	Window = 0,
	IsCritical = false,
	Params = {
		LookLimit = 3,
		AutoOff = 20,
		CurtainLead = 1,
	},
}
