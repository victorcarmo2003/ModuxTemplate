--!strict
-- ANM-014 The big head, the blackout's bar (TASK-587; design/horror-cinematic.md §3.8, §11.1 R1-R10, §11.2). Anchored
-- to the actor's record (Rules/ANM-014: refuse = close the window on it, Take Order = Failed; no deadline). The family A
-- modifier already gives it the wrong head (OddCustomer, x1.9). Signature: the head GROWS in steps, and only while
-- nobody looks (Pose Scale waits until it is out of this client's view, with a creak of stretching leather); it bumps
-- the lamp over the counter, which swings and stutters; in the silence it tilts to look in through the service window;
-- on the security cameras it already fills the room up to the ceiling (Seen "Cameras"). Presentation only (T10). Every
-- number PROVISIONAL until the owner's Play; the creak is `door_creak` until stretch_creak has an Id (sound-list.md).
-- Owner 2026-10-22 (anomaly tics, Q-461): the head arrives NORMAL and grows only in the Take Order talk, in two steps
-- (Content.Tics, Kit/Tic; the huge head on the cameras is the tic body's too). Gone from this scene: the growth while
-- nobody looks (Pose Scale), the camera layer's Pose Scale and the lamp it bumped (Prop Sway): they showed the tic before
-- the talk. The rest (sting, heart, words, silence, the tilt) stays.
local Types = require(script.Parent.Parent.Types)

const COUNTER = "Q1"
const CREAK = "door_creak" -- stands in for stretch_creak (sound-list.md, TASK-587)

const scene: Types.Scene = {
	Key = "anm_014_big_head",
	Name = "The big head",
	Live = true,
	Words = {
		big_head_grow = {
			"ITS HEAD IS WRONG",
			"IT'S GROWING",
			"CLOSE THE WINDOW",
			"DON'T TAKE ITS ORDER",
			"don't look away...",
			"it gets bigger when you look away",
		},
	},
	Steps = {
		-- R1: a sting, a jolt, the view pulses
		{ At = 0, Phase = "Active", Kind = "Sound", Target = "horror_sting", Value = 0.3 },
		{ At = 0, Phase = "Active", Kind = "Shake", Target = "Jolt", Value = 0.4 },
		{ At = 0, Phase = "Active", Kind = "Fov", Value = -2, To = 0, Duration = 0.7 },
		{ At = 1, Phase = "Active", Kind = "Cinema", Value = 0.08, Duration = 1.5 },
		-- owner 2026-10-22: the head no longer grows here (Pose Scale x1.12 / 1.24 / 1.36 at 3 / 6 / 9 s while not looked
		-- at): it grows in the talk (Content.Tics)
		-- the world closes in a degree each step
		{ At = 3.2, Phase = "Active", Kind = "Fov", Value = -1, To = 0, Duration = 1.4 },
		{ At = 6.2, Phase = "Active", Kind = "Fov", Value = -1, To = 0, Duration = 1.4 },
		{ At = 9.2, Phase = "Active", Kind = "Fov", Value = -1, To = 0, Duration = 1.4 },
		-- R4: on the cameras it is already up against the ceiling: owner 2026-10-22, now the tic body's (Content.Tics
		-- Cameras, Kit/Tic) in place of Pose Scale 1.7 Seen "Cameras"
		-- R5 + R7: the hint, the heart, the edges, the colour going sick
		{ At = 3, Phase = "Active", Kind = "Whispers", Target = "big_head_grow", Value = 0.3, To = 1.2, Duration = 7, Where = "Inside" },
		{ At = 3, Phase = "Active", Kind = "Whispers", Target = "outside", Value = 0.3, To = 1.1, Duration = 7, Where = "Outside" },
		{ At = 3, Phase = "Active", Kind = "Heartbeat", Value = 70, To = 120, Duration = 7 },
		{ At = 3, Phase = "Active", Kind = "Vignette", Value = 0, To = 0.22, Duration = 7 },
		{ At = 3, Phase = "Active", Kind = "Grade", Target = "Sick", Value = 0, To = 0.24, Duration = 7 },
		-- R2 + R3: the lamp over the counter stutters (owner 2026-10-22: no longer bumped by a head that is still normal,
		-- the Prop Sway and its light_flicker at 6.5 s are gone)
		{ At = 7, Phase = "Active", Kind = "Lights", Target = "Flicker", Duration = 0.35 },
		-- R8: the silence; it tilts its head to look in through the service window
		{ At = 10.5, Phase = "Active", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 10.5, Phase = "Active", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 10.5, Phase = "Active", Kind = "Silence", Value = 1, To = 0.35, Duration = 0.6 },
		{ At = 10.6, Phase = "Active", Kind = "Pose", Target = "Tilt", Value = 25, Duration = 1.5 },
		{ At = 10.6, Phase = "Active", Kind = "Nudge", Point = COUNTER, Value = 2, Duration = 1 },
		-- R9: the sting (owner 2026-10-22: without the head turning huge, Pose Scale 1.5, nor the lamp knocked, Prop Sway)
		{ At = 12.5, Phase = "Active", Kind = "Sound", Target = "horror_sting", Value = 0.6 },
		{ At = 12.5, Phase = "Active", Kind = "Shake", Target = "Jolt" },
		{ At = 12.5, Phase = "Active", Kind = "Blur", Value = 4, To = 0, Duration = 1 },
		{ At = 12.5, Phase = "Active", Kind = "Silence", Value = 0.35, To = 1, Duration = 2 },
		{ At = 13, Phase = "Active", Kind = "Heartbeat", Value = 100, To = 105, Duration = 17 },
		-- the work goes on
		{ At = 17, Phase = "Active", Kind = "Cinema", Value = 0, Duration = 1.5 },
		{ At = 17, Phase = "Active", Kind = "Vignette", Value = 0.22, To = 0.08, Duration = 4 },
		{ At = 17, Phase = "Active", Kind = "Grade", Value = 0.24, To = 0.1, Duration = 4 },
		{ At = 30, Phase = "Active", Kind = "Heartbeat", Value = 0, To = 0 },
		-- Fora (§3.0): the head turns round to follow him through the glass
		{ At = 4, Phase = "Active", Kind = "Pose", Target = "Turn", Duration = 2, Where = "Outside" },

		-- Resolved (the window shut on it): R10 in steps
		{ At = 0, Phase = "Resolved", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Silence", Value = 1, To = 0.5, Duration = 0.3 },
		{ At = 0.4, Phase = "Resolved", Kind = "Sound", Target = CREAK, Point = COUNTER, Value = 0.5 },
		{ At = 1, Phase = "Resolved", Kind = "Silence", Value = 0.5, To = 1, Duration = 1.5 },
		{ At = 1, Phase = "Resolved", Kind = "Grade", Value = 0.24, To = 0, Duration = 2.5 },
		{ At = 1, Phase = "Resolved", Kind = "Vignette", Value = 0.22, To = 0, Duration = 2 },
		{ At = 0, Phase = "Resolved", Kind = "Blur", Value = 0, To = 0, Duration = 0 },
		{ At = 1.2, Phase = "Resolved", Kind = "Sound", Target = "breath_held" },
		{ At = 1.5, Phase = "Resolved", Kind = "Cinema", Value = 0, Duration = 1 },

		-- Failed (its order taken): the face (Kit/Jumpscare on the cue), red + blur on who did it
		{ At = 0, Phase = "Failed", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Failed", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0, Phase = "Failed", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 0, Phase = "Failed", Kind = "Prop", Target = "Sway", Point = COUNTER, Value = 10, To = 10, Duration = 1 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Grade", Target = "Red", Value = 0.85, To = 0, Duration = 2.8 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Blur", Value = 12, To = 0, Duration = 1.4 },
		{ At = 0, Phase = "Failed", Who = "Safe", Kind = "Shake", Target = "Jolt" },
		{ At = 0.8, Phase = "Failed", Kind = "Vignette", Value = 0.4, To = 0, Duration = 3 },
		{ At = 1.5, Phase = "Failed", Who = "Safe", Kind = "Grade", Value = 0.24, To = 0, Duration = 2 },
		{ At = 2, Phase = "Failed", Kind = "Cinema", Value = 0, Duration = 1 },
	},
}

return scene
