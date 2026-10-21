--!strict
-- ANM-017 the crawler up to the blackout's bar (TASK-589; design/horror-cinematic.md §6, §9, §11.2). Extend: the words,
-- heart, bars and the pass (Effects/ANM-017, Kit/Hide) stay as they are; this adds:
--   R2  the floor itself: boards lifting along its line under the kitchen aisle, the lamps over it swaying, the colour
--       going sick-green, the kitchen hushed
--   R4  on the security cameras it is ALREADY under the counter during the warning, crawling the aisle (REV-1 to REV-4)
--       while the eye only hears the scratching
--   R8  a real silence right before it bursts out (the floor goes quiet, the heart stops)
--   R10 after it: the boards settle, the colour and the sound come back
-- Timing follows Rules/ANM-017 (WarnFor 10 = Signal, PassFor 9 = Active). The board / lamp steps are the Prop piece of
-- TASK-587 (a stub until it lands: nothing breaks, they only do nothing yet).
local Types = require(script.Parent.Parent.Types)

const scene: Types.Scene = {
	Key = "anm_017_crawler",
	Name = "The crawler (floor, cameras, silence)",
	Extend = true,
	Steps = {
		-- R4: on the feed it crawls the aisle under the counter, slow, during the whole warning; gone when it arrives
		{ At = 0.5, Phase = "Signal", Kind = "Actor", Target = "ANM-017_Crawler", Point = "REV-1", To = "REV-4", Duration = 8.5, Sound = "floor_scratch", Seen = "Cameras", Value = 1 },
		-- R2: the floor answers along its line, the lamps sway, the colour goes sick
		{ At = 1, Phase = "Signal", Kind = "Sound", Target = "floor_scratch", Point = "REV-2", Value = 0.8 },
		{ At = 2, Phase = "Signal", Kind = "Grade", Target = "Sick", Value = 0, To = 0.35, Duration = 7 },
		{ At = 2, Phase = "Signal", Kind = "Silence", Value = 1, To = 0.5, Duration = 3 },
		{ At = 3, Phase = "Signal", Kind = "Prop", Target = "Lift", Point = "REV-2", Value = 1, Duration = 0.6 },
		{ At = 4.6, Phase = "Signal", Kind = "Prop", Target = "Lift", Point = "REV-3", Value = 1, Duration = 0.6 },
		{ At = 5, Phase = "Signal", Kind = "Prop", Target = "Sway", Point = "TRL", Value = 1, Duration = 4 },
		{ At = 6.2, Phase = "Signal", Kind = "Prop", Target = "Lift", Point = "REV-4", Value = 1.4, Duration = 0.6 },
		{ At = 6.2, Phase = "Signal", Kind = "Sound", Target = "floor_creak", Point = "REV-4" },
		{ At = 6.5, Phase = "Signal", Kind = "Fov", Value = 2, To = 0, Duration = 2.5 },
		-- R8: everything stops a breath before it comes out
		{ At = 9, Phase = "Signal", Kind = "Silence", Value = 0.5, To = 0.05, Duration = 0.4 },
		{ At = 9, Phase = "Signal", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0, Phase = "Active", Kind = "Silence", Value = 0.05, To = 1, Duration = 0.3 },
		{ At = 0, Phase = "Active", Kind = "Prop", Target = "Lift", Point = "REV-1", Value = 2, Duration = 0.8 },
		{ At = 0, Phase = "Active", Kind = "Blur", Value = 4, To = 0, Duration = 0.8 },
		-- R10: the floor settles, the colour comes back
		{ At = 0.4, Phase = "Resolved", Kind = "Sound", Target = "floor_creak", Point = "REV-2", Value = 0.5 },
		{ At = 0, Phase = "Resolved", Kind = "Grade", Value = 0.35, To = 0, Duration = 2.5 },
		{ At = 1, Phase = "Resolved", Kind = "Sound", Target = "breath_held" },
		{ At = 0, Phase = "Failed", Who = "Safe", Kind = "Grade", Value = 0.35, To = 0, Duration = 3 },
	},
}

return scene
