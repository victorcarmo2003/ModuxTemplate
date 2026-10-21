--!strict
-- ANM-001 The blank folks, the blackout's bar (TASK-587; design/horror-cinematic.md §3.1, §11.1 R1-R10, §11.2).
-- Anchored to the actor's record (Rules/ANM-001: refuse = close the window on it, Take Order = Failed; no deadline, so
-- Active lasts until the verb). Signature: the lamp blinks twice when it arrives, it RAISES its smooth face (Pose
-- Lift), on the security cameras it looks up into the camera and tilts its head (Seen "Cameras"), the cups on the
-- counter shiver, a silence with the head tilted, and once the window is shut a finger knocks from the other side.
-- Presentation only (T10). Every number PROVISIONAL until the owner's Play.
local Types = require(script.Parent.Parent.Types)

const COUNTER = "Q1" -- the order spot at the counter
const OUTSIDE = "SCENE-WINDOW-EYES" -- outside the service window

const scene: Types.Scene = {
	Key = "anm_001_blank_folks",
	Name = "The blank folks",
	Live = true,
	Words = {
		-- the hint (refuse = close the service window on it)
		blank_close = {
			"CLOSE THE WINDOW",
			"CLOSE THE WINDOW",
			"DON'T TAKE ITS ORDER",
			"IT HAS NO FACE",
			"it's looking at you...",
			"where is its face?",
		},
	},
	Steps = {
		-- R1: the lamp blinks twice, a jolt and the view pulses (owner 2026-10-19: no more phone glitch without words)
		{ At = 0, Phase = "Active", Kind = "Shake", Target = "Jolt", Value = 0.5 },
		{ At = 0, Phase = "Active", Kind = "Fov", Value = -2, To = 0, Duration = 0.7 },
		{ At = 0.4, Phase = "Active", Kind = "Lights", Target = "Flicker", Duration = 0.6 },
		{ At = 1, Phase = "Active", Kind = "Cinema", Value = 0.08, Duration = 1.5 },
		-- the face comes up: smooth (a low sting on its head)
		{ At = 3, Phase = "Active", Kind = "Pose", Target = "Lift", Value = 24, Duration = 2.2, Sound = "horror_sting" },
		{ At = 3, Phase = "Active", Kind = "Nudge", Point = COUNTER, Value = 1.5, Duration = 0.8 },
		-- R4: on the cameras it looks straight up into the lens and tilts its head
		{ At = 3, Phase = "Active", Kind = "Pose", Target = "Turn", Duration = 1.4, Seen = "Cameras" },
		{ At = 3, Phase = "Active", Kind = "Pose", Target = "Tilt", Value = 14, Duration = 2, Seen = "Cameras" },
		-- R5 + R7: the hint words ramp, the heart, the edges, the colour leaving; the view breathes
		{ At = 3.5, Phase = "Active", Kind = "Whispers", Target = "blank_close", Value = 0.3, To = 1.3, Duration = 8, Where = "Inside" },
		{ At = 3.5, Phase = "Active", Kind = "Whispers", Target = "outside", Value = 0.3, To = 1.2, Duration = 8, Where = "Outside" },
		{ At = 3.5, Phase = "Active", Kind = "Vignette", Value = 0, To = 0.22, Duration = 8 },
		{ At = 3.5, Phase = "Active", Kind = "Grade", Target = "Cold", Value = 0, To = 0.3, Duration = 8 },
		{ At = 4, Phase = "Active", Kind = "Heartbeat", Value = 70, To = 115, Duration = 8 },
		{ At = 4, Phase = "Active", Kind = "Fov", Value = 1, To = 0, Duration = 6 },
		-- R2: the cups on the counter shiver as it stares; R3: a whisper right at it
		{ At = 6, Phase = "Active", Kind = "Prop", Target = "Shake", Point = COUNTER, Value = 0.02, To = 5, Duration = 2, Seen = "Eyes" },
		{ At = 8, Phase = "Active", Kind = "Sound", Target = "whisper", Point = COUNTER, Value = 0.5 },
		-- R8: the silence, the head tilts to the side and holds
		{ At = 11.5, Phase = "Active", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 11.5, Phase = "Active", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 11.5, Phase = "Active", Kind = "Silence", Value = 1, To = 0.3, Duration = 0.8 },
		{ At = 11.6, Phase = "Active", Kind = "Pose", Target = "Tilt", Value = 28, Duration = 1.6 },
		{ At = 11.6, Phase = "Active", Kind = "Sound", Target = "neck_crack", Point = COUNTER, Value = 0.25 },
		-- R9: the head snaps up to whoever looks, the lights blink, everything on the counter jumps
		{ At = 13.5, Phase = "Active", Kind = "Pose", Target = "Lift", Value = 34, Duration = 0.25 },
		{ At = 13.5, Phase = "Active", Kind = "Sound", Target = "horror_sting", Value = 0.6 },
		{ At = 13.5, Phase = "Active", Kind = "Lights", Target = "Flicker", Duration = 0.4 },
		{ At = 13.5, Phase = "Active", Kind = "Prop", Target = "Shake", Point = COUNTER, Value = 0.07, To = 5, Duration = 0.6, Seen = "Eyes" },
		{ At = 13.5, Phase = "Active", Kind = "Shake", Target = "Jolt" },
		{ At = 13.5, Phase = "Active", Kind = "Blur", Value = 5, To = 0, Duration = 1 },
		{ At = 13.5, Phase = "Active", Kind = "Vignette", Value = 0.22, To = 0.32, Duration = 0.3 },
		{ At = 13.5, Phase = "Active", Kind = "Silence", Value = 0.3, To = 1, Duration = 2 },
		{ At = 14, Phase = "Active", Kind = "Heartbeat", Value = 95, To = 100, Duration = 16 },
		-- the work goes on: bars out, the edges and the colour hold low until the verb
		{ At = 17, Phase = "Active", Kind = "Cinema", Value = 0, Duration = 1.5 },
		{ At = 17, Phase = "Active", Kind = "Vignette", Value = 0.32, To = 0.1, Duration = 4 },
		{ At = 17, Phase = "Active", Kind = "Grade", Value = 0.3, To = 0.12, Duration = 4 },
		{ At = 30, Phase = "Active", Kind = "Heartbeat", Value = 0, To = 0 },
		-- Fora (§3.0): eyes out in the drive-thru lane, behind whoever is outside
		{ At = 3, Phase = "Active", Kind = "Lantern", Target = "Eyes", Point = "DT-STOP", Duration = 1.2, Where = "Outside" },

		-- Resolved (the window shut on it): the shutter, then ONE finger knocking from the other side; R10 in steps
		{ At = 0, Phase = "Resolved", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Silence", Value = 1, To = 0.5, Duration = 0.3 },
		{ At = 1.5, Phase = "Resolved", Kind = "Sound", Target = "door_knock", Point = OUTSIDE, Value = 0.5 },
		{ At = 1.5, Phase = "Resolved", Kind = "Shake", Target = "Jolt", Value = 0.5 },
		{ At = 1.8, Phase = "Resolved", Kind = "Silence", Value = 0.5, To = 1, Duration = 1.5 },
		{ At = 2, Phase = "Resolved", Kind = "Sound", Target = "breath_held" },
		{ At = 1.8, Phase = "Resolved", Kind = "Grade", Value = 0.3, To = 0, Duration = 2.5 },
		{ At = 1.8, Phase = "Resolved", Kind = "Vignette", Value = 0.32, To = 0, Duration = 2 },
		{ At = 0, Phase = "Resolved", Kind = "Blur", Value = 0, To = 0, Duration = 0 },
		{ At = 2.2, Phase = "Resolved", Kind = "Cinema", Value = 0, Duration = 1 },

		-- Failed (its order taken): the face fills the screen (Kit/Jumpscare on the cue), red + blur on who did it
		{ At = 0, Phase = "Failed", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Failed", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0, Phase = "Failed", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Grade", Target = "Red", Value = 0.85, To = 0, Duration = 2.8 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Blur", Value = 12, To = 0, Duration = 1.4 },
		{ At = 0, Phase = "Failed", Who = "Safe", Kind = "Shake", Target = "Jolt" },
		{ At = 0, Phase = "Failed", Who = "Safe", Kind = "Sound", Target = "horror_sting", Value = 0.4 },
		{ At = 0, Phase = "Failed", Kind = "Lights", Target = "Flicker", Duration = 0.5 },
		{ At = 0.8, Phase = "Failed", Kind = "Vignette", Value = 0.4, To = 0, Duration = 3 },
		{ At = 1.5, Phase = "Failed", Who = "Safe", Kind = "Grade", Value = 0.3, To = 0, Duration = 2 },
		{ At = 2, Phase = "Failed", Kind = "Cinema", Value = 0, Duration = 1 },
	},
}

return scene
