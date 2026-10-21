--!strict
-- ANM-016 The starer, the blackout's bar (TASK-587; design/horror-cinematic.md §3.10, §11.1 R1-R10, §11.2). Anchored
-- to the actor's record (Rules/ANM-016: refuse = close the window on it, Take Order = Failed; no deadline). The family A
-- modifier already turns its head to follow the camera (OddCustomer "stare"). Signature: a clock ticking loud at the
-- counter; every OTHER customer blinks together every few seconds and it never does (Pose Blink, Value 1); the clock
-- stops dead; then it blinks ONCE - and every light in the room blinks with it. On the security cameras the whole room
-- turns to look into the lens (Seen "Cameras"; its own head already follows whatever camera looks at it). Presentation
-- only (T10). Every number PROVISIONAL until the owner's Play; the tick is the `amb_clock_tick` clip played once on a
-- carrier at the counter and cut when the carrier goes (CLOCK_FOR s), until clock_tick (one tick, slowing down) has an
-- Id (sound-list.md).
local Types = require(script.Parent.Parent.Types)

const COUNTER = "Q1"
const CLOCK_FOR = 9 -- s: the clock stops dead (the carrier of the sound goes)

const scene: Types.Scene = {
	Key = "anm_016_starer",
	Name = "The starer",
	Live = true,
	Words = {
		starer_blink = {
			"IT NEVER BLINKS",
			"IT NEVER BLINKS",
			"CLOSE THE WINDOW",
			"DON'T TAKE ITS ORDER",
			"it's watching you",
			"don't blink...",
		},
	},
	Steps = {
		-- R1: a sting, a jolt, the view pulses; the clock starts ticking loud at the counter
		{ At = 0, Phase = "Active", Kind = "Sound", Target = "horror_sting", Value = 0.3 },
		{ At = 0, Phase = "Active", Kind = "Shake", Target = "Jolt", Value = 0.35 },
		{ At = 0, Phase = "Active", Kind = "Fov", Value = -2, To = 0, Duration = 0.7 },
		{ At = 0, Phase = "Active", Kind = "Sound", Target = "amb_clock_tick", Point = COUNTER, Duration = CLOCK_FOR },
		{ At = 1, Phase = "Active", Kind = "Cinema", Value = 0.08, Duration = 1.5 },
		-- R2 + R3: the others blink together every 3 s, it never does
		{ At = 1, Phase = "Active", Kind = "Pose", Target = "Blink", Value = 1, Duration = 0.14, To = 3 },
		-- R4: on the cameras the whole room looks into the lens, heads a little to the side
		{ At = 2, Phase = "Active", Kind = "Pose", Target = "Turn", Value = 1, Duration = 1, Seen = "Cameras" },
		{ At = 2, Phase = "Active", Kind = "Pose", Target = "Tilt", Value = 14, Duration = 2, Seen = "Cameras" },
		-- R5 + R7: the hint, the heart, the edges, the colour going
		{ At = 2, Phase = "Active", Kind = "Whispers", Target = "starer_blink", Value = 0.3, To = 1.2, Duration = 7, Where = "Inside" },
		{ At = 2, Phase = "Active", Kind = "Whispers", Target = "outside", Value = 0.3, To = 1.1, Duration = 7, Where = "Outside" },
		{ At = 2, Phase = "Active", Kind = "Heartbeat", Value = 70, To = 120, Duration = 7 },
		{ At = 2, Phase = "Active", Kind = "Vignette", Value = 0, To = 0.22, Duration = 7 },
		{ At = 2, Phase = "Active", Kind = "Grade", Target = "Cold", Value = 0, To = 0.3, Duration = 7 },
		{ At = 4, Phase = "Active", Kind = "Fov", Value = 1, To = 0, Duration = 4 },
		{ At = 5, Phase = "Active", Kind = "Nudge", Point = COUNTER, Value = 1.5, Duration = 0.8 },
		-- R8: the clock stops (its carrier goes at CLOCK_FOR), the room goes quiet
		{ At = CLOCK_FOR, Phase = "Active", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = CLOCK_FOR, Phase = "Active", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = CLOCK_FOR, Phase = "Active", Kind = "Silence", Value = 1, To = 0.25, Duration = 0.3 },
		-- R9: it blinks once - and every light blinks with it
		{ At = 10.5, Phase = "Active", Kind = "Pose", Target = "Blink", Duration = 0.22 },
		{ At = 10.5, Phase = "Active", Kind = "Lights", Target = "Flicker", Duration = 0.25 },
		{ At = 10.5, Phase = "Active", Kind = "Sound", Target = "lights_off", Value = 0.6 },
		{ At = 10.5, Phase = "Active", Kind = "Shake", Target = "Jolt" },
		{ At = 10.5, Phase = "Active", Kind = "Blur", Value = 4, To = 0, Duration = 1 },
		{ At = 10.8, Phase = "Active", Kind = "Sound", Target = "horror_sting", Value = 0.55 },
		{ At = 10.8, Phase = "Active", Kind = "Silence", Value = 0.25, To = 1, Duration = 1.5 },
		{ At = 11, Phase = "Active", Kind = "Heartbeat", Value = 100, To = 105, Duration = 19 },
		-- the work goes on
		{ At = 16, Phase = "Active", Kind = "Cinema", Value = 0, Duration = 1.5 },
		{ At = 16, Phase = "Active", Kind = "Vignette", Value = 0.22, To = 0.08, Duration = 4 },
		{ At = 16, Phase = "Active", Kind = "Grade", Value = 0.3, To = 0.1, Duration = 4 },
		{ At = 30, Phase = "Active", Kind = "Heartbeat", Value = 0, To = 0 },

		-- Resolved (the window shut on it): R10 in steps
		{ At = 0, Phase = "Resolved", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Silence", Value = 1, To = 0.5, Duration = 0.3 },
		{ At = 1, Phase = "Resolved", Kind = "Silence", Value = 0.5, To = 1, Duration = 1.5 },
		{ At = 1, Phase = "Resolved", Kind = "Grade", Value = 0.3, To = 0, Duration = 2.5 },
		{ At = 1, Phase = "Resolved", Kind = "Vignette", Value = 0.22, To = 0, Duration = 2 },
		{ At = 0, Phase = "Resolved", Kind = "Blur", Value = 0, To = 0, Duration = 0 },
		{ At = 1.2, Phase = "Resolved", Kind = "Sound", Target = "breath_held" },
		{ At = 1.5, Phase = "Resolved", Kind = "Cinema", Value = 0, Duration = 1 },

		-- Failed (its order taken): the lights blink, the face (Kit/Jumpscare on the cue), red + blur on who did it
		{ At = 0, Phase = "Failed", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Failed", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0, Phase = "Failed", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 0, Phase = "Failed", Kind = "Lights", Target = "Flicker", Duration = 0.3 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Grade", Target = "Red", Value = 0.85, To = 0, Duration = 2.8 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Blur", Value = 12, To = 0, Duration = 1.4 },
		{ At = 0, Phase = "Failed", Who = "Safe", Kind = "Shake", Target = "Jolt" },
		{ At = 0.8, Phase = "Failed", Kind = "Vignette", Value = 0.4, To = 0, Duration = 3 },
		{ At = 1.5, Phase = "Failed", Who = "Safe", Kind = "Grade", Value = 0.3, To = 0, Duration = 2 },
		{ At = 2, Phase = "Failed", Kind = "Cinema", Value = 0, Duration = 1 },
	},
}

return scene
