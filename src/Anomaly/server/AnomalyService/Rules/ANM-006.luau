--!strict
-- Server rule of ANM-006 The stalker (DEC-260, replaces The wavers; TASK-351). Verb "dont_look": the more the crew stares
-- at it, the closer it comes. PROVISIONAL numbers (owner request 2026-10-16, tune in play).
--   Steps       steps from the far sidewalk to the service window
--   StepEvery   s of stare (any Active player looking at it; several lookers do not stack) per step
--   AutoOff     s from the start: nobody brought it to the window, it fades away (Resolved)
--   LeapDelay   s between reaching the window and leaping in (the last chance: close the window)
--   ScareFaint  s between the jumpscare and the faint of the nearest player
--   Linger      s the record stays after the end so every client plays the leap / bang / fade
return {
	Anomaly = "anm_006_stalker",
	Verb = "dont_look",
	LikelyWrongVerb = "look",
	Window = 0,
	IsCritical = false,
	Params = {
		Steps = 6,
		StepEvery = 1.2,
		AutoOff = 28,
		LeapDelay = 1,
		ScareFaint = 0.7,
		Linger = 2.5,
	},
}
