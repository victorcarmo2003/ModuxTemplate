--!strict
-- ANM-015 The floater, the blackout's bar (TASK-587; design/horror-cinematic.md §3.9, §11.1 R1-R10, §11.2). Anchored
-- to the actor's record (Rules/ANM-015: refuse = close the window on it, Take Order = Failed; no deadline). The v3
-- review found 20 cm too subtle (Q-389), so the room floats with it: the napkins, cups and sauce on the counter rise
-- slowly and turn (Prop Float) while it lifts a little more (Pose Float, visual only) and a hum climbs; on the security
-- cameras it hangs up by the ceiling (Seen "Cameras"). The hum cuts, a second of nothing, and EVERYTHING falls at once
-- (Prop Drop) with a dry thud and a jolt; then, slowly, it starts to rise again. Presentation only (T10). Every number
-- PROVISIONAL until the owner's Play; the hum is `hum_rise` until float_hum has an Id (sound-list.md). TASK-591: the
-- sporadic head-first hits on the ceiling (BANGS, below).
local Types = require(script.Parent.Parent.Types)

const COUNTER = "Q1"
const HUM = "hum_rise" -- stands in for float_hum (sound-list.md, TASK-587)

const scene: Types.Scene = {
	Key = "anm_015_floater",
	Name = "The floater",
	Live = true,
	Words = {
		floater_up = {
			"LOOK AT ITS FEET",
			"EVERYTHING IS FLOATING",
			"CLOSE THE WINDOW",
			"DON'T TAKE ITS ORDER",
			"it isn't touching the ground",
			"why is it so light...",
		},
	},
	Steps = {
		-- R1: the hum starts, a jolt, the view pulses; it lifts a little more
		{ At = 0, Phase = "Active", Kind = "Sound", Target = HUM, Value = 0.5 },
		{ At = 0, Phase = "Active", Kind = "Shake", Target = "Jolt", Value = 0.3 },
		{ At = 0, Phase = "Active", Kind = "Fov", Value = -2, To = 0, Duration = 0.7 },
		{ At = 0.5, Phase = "Active", Kind = "Pose", Target = "Float", Value = 0.6, Duration = 3 },
		{ At = 1, Phase = "Active", Kind = "Cinema", Value = 0.08, Duration = 1.5 },
		-- R2: the counter floats with it
		{ At = 2, Phase = "Active", Kind = "Prop", Target = "Float", Point = COUNTER, Value = 1.1, To = 6, Duration = 6 },
		-- R4: on the cameras it hangs up by the ceiling, its head bent down at the room
		{ At = 2, Phase = "Active", Kind = "Pose", Target = "Float", Value = 6, Duration = 3, Seen = "Cameras" },
		{ At = 2, Phase = "Active", Kind = "Pose", Target = "Lift", Value = -30, Duration = 3, Seen = "Cameras" },
		-- R5 + R7: the hint, the heart, the edges, the colour going sick; the hum climbs again
		{ At = 2, Phase = "Active", Kind = "Whispers", Target = "floater_up", Value = 0.3, To = 1.2, Duration = 6, Where = "Inside" },
		{ At = 2, Phase = "Active", Kind = "Whispers", Target = "outside", Value = 0.3, To = 1.1, Duration = 6, Where = "Outside" },
		{ At = 2, Phase = "Active", Kind = "Heartbeat", Value = 70, To = 115, Duration = 6 },
		{ At = 2, Phase = "Active", Kind = "Vignette", Value = 0, To = 0.2, Duration = 6 },
		{ At = 2, Phase = "Active", Kind = "Grade", Target = "Sick", Value = 0, To = 0.22, Duration = 6 },
		{ At = 4, Phase = "Active", Kind = "Fov", Value = 1.5, To = 0, Duration = 4 },
		{ At = 4.5, Phase = "Active", Kind = "Sound", Target = HUM, Value = 0.75 },
		-- R3: something light brushes past outside
		{ At = 6, Phase = "Active", Kind = "Sound", Target = "shadow_whoosh", Point = "SCENE-WINDOW-EYES", Value = 0.4 },
		-- R8: the hum cuts, a second of nothing
		{ At = 8, Phase = "Active", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 8, Phase = "Active", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 8, Phase = "Active", Kind = "Silence", Value = 1, To = 0.2, Duration = 0.2 },
		-- R9: everything falls at once, it with them
		{ At = 9.2, Phase = "Active", Kind = "Prop", Target = "Drop", Point = COUNTER, Duration = 0.25, Sound = "plate_put" },
		{ At = 9.2, Phase = "Active", Kind = "Pose", Target = "Float", To = 0, Duration = 0.2 },
		{ At = 9.4, Phase = "Active", Kind = "Sound", Target = "grill_drop", Point = COUNTER, Value = 0.8 },
		{ At = 9.4, Phase = "Active", Kind = "Shake", Target = "Jolt" },
		{ At = 9.4, Phase = "Active", Kind = "Lights", Target = "Flicker", Duration = 0.3 },
		{ At = 9.4, Phase = "Active", Kind = "Blur", Value = 4, To = 0, Duration = 1 },
		{ At = 9.4, Phase = "Active", Kind = "Silence", Value = 0.2, To = 1, Duration = 1.5 },
		{ At = 10, Phase = "Active", Kind = "Heartbeat", Value = 100, To = 105, Duration = 20 },
		-- ...and slowly it starts to rise again
		{ At = 12, Phase = "Active", Kind = "Pose", Target = "Float", Value = 0.5, Duration = 6 },
		{ At = 12, Phase = "Active", Kind = "Sound", Target = HUM, Value = 0.3 },
		-- the work goes on
		{ At = 16, Phase = "Active", Kind = "Cinema", Value = 0, Duration = 1.5 },
		{ At = 16, Phase = "Active", Kind = "Vignette", Value = 0.2, To = 0.08, Duration = 4 },
		{ At = 16, Phase = "Active", Kind = "Grade", Value = 0.22, To = 0.1, Duration = 4 },
		{ At = 30, Phase = "Active", Kind = "Heartbeat", Value = 0, To = 0 },

		-- Resolved (the window shut on it): R10 in steps
		{ At = 0, Phase = "Resolved", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Prop", Target = "Drop", Point = COUNTER, Duration = 0.3 },
		{ At = 0, Phase = "Resolved", Kind = "Silence", Value = 1, To = 0.5, Duration = 0.3 },
		{ At = 1, Phase = "Resolved", Kind = "Silence", Value = 0.5, To = 1, Duration = 1.5 },
		{ At = 1, Phase = "Resolved", Kind = "Grade", Value = 0.22, To = 0, Duration = 2.5 },
		{ At = 1, Phase = "Resolved", Kind = "Vignette", Value = 0.2, To = 0, Duration = 2 },
		{ At = 0, Phase = "Resolved", Kind = "Blur", Value = 0, To = 0, Duration = 0 },
		{ At = 1.2, Phase = "Resolved", Kind = "Sound", Target = "breath_held" },
		{ At = 1.5, Phase = "Resolved", Kind = "Cinema", Value = 0, Duration = 1 },

		-- Failed (its order taken): everything drops, the face (Kit/Jumpscare on the cue), red + blur on who did it
		{ At = 0, Phase = "Failed", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Failed", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0, Phase = "Failed", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 0, Phase = "Failed", Kind = "Prop", Target = "Drop", Point = COUNTER, Duration = 0.2, Sound = "plate_put" },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Grade", Target = "Red", Value = 0.85, To = 0, Duration = 2.8 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Blur", Value = 12, To = 0, Duration = 1.4 },
		{ At = 0, Phase = "Failed", Who = "Safe", Kind = "Shake", Target = "Jolt" },
		{ At = 0.8, Phase = "Failed", Kind = "Vignette", Value = 0.4, To = 0, Duration = 3 },
		{ At = 1.5, Phase = "Failed", Who = "Safe", Kind = "Grade", Value = 0.22, To = 0, Duration = 2 },
		{ At = 2, Phase = "Failed", Kind = "Cinema", Value = 0, Duration = 1 },
	},
}

-- TASK-591 (owner 2026-10-19): now and then, without warning, the head tips all the way back, it shoots up and slams
-- its forehead into the ceiling upside down - very fast, a loud thud, the lights die for a blink (the starer's flash
-- blackout), a jolt - then it sinks back and waits as if nothing happened. Irregular times so it never feels like a
-- loop; the drop at 9.2 s (R9) stays clear of them.
const BANGS = { 5, 14.5, 22, 31, 43, 56, 74 } -- s of Active
const THUD = "door_force" -- stands in for a ceiling thud (sound-list.md, TASK-591)
for _, t in BANGS do
	const bang: { Types.Step } = {
		-- the head tips back, then it shoots up
		{ At = t - 0.55, Phase = "Active", Kind = "Pose", Target = "Lift", Value = -75, Duration = 0.2, To = 1.1 },
		{ At = t - 0.3, Phase = "Active", Kind = "Pose", Target = "Float", Value = 3.4, Duration = 0.28, To = 0.35 },
		-- the hit: thud, flash blackout, jolt, view punched
		{ At = t, Phase = "Active", Kind = "Sound", Target = THUD, Point = COUNTER, Value = 1.4 },
		{ At = t, Phase = "Active", Kind = "Sound", Target = "neck_crack", Point = COUNTER, Value = 0.4 },
		{ At = t, Phase = "Active", Kind = "Lights", Target = "Off" },
		{ At = t + 0.16, Phase = "Active", Kind = "Lights", Target = "On" },
		{ At = t, Phase = "Active", Kind = "Shake", Target = "Jolt" },
		{ At = t, Phase = "Active", Kind = "Fov", Value = -3, To = 0, Duration = 0.5 },
		{ At = t, Phase = "Active", Kind = "Blur", Value = 3, To = 0, Duration = 0.6 },
		{ At = t, Phase = "Active", Kind = "Prop", Target = "Shake", Point = COUNTER, Value = 0.05, To = 7, Duration = 0.35 },
	}
	for _, step in bang do
		table.insert(scene.Steps, step)
	end
end

return scene
