--!strict
-- ANM-010 The Hush up to the blackout's bar (TASK-589; design/horror-cinematic.md §3.5, §11.2). Extend: the words, heart,
-- grading and the hush of the sound stay as they are (init); this adds what the bar asked for:
--   R3  the Hush itself: an enormous shape crossing outside the front glass while the shop is dark, stopping at the
--       big window (the silence), then going on - always outside, always slow
--   R4  on the security cameras a second one is already standing at the drive-thru, waiting, the whole time
--   R8  the drone-like hum under the dark CUTS when it stops at the glass: two seconds of nothing, then one creak of glass
--   R9  wrong (lights on): the jolt, the view punched in; R10 the lamps cascade, the colour and the steps leave
--   R11 with the lights off the player keeps a faint white light around him (the blackout's, weaker)
--   R12 outside: GET INSIDE, the heart higher, and the shape walks the street towards him
-- Timing follows the init scene (Rules/ANM-010: the corner post at 15 s, the hold to ~35 s). Points read off TRL / DT.
-- TASK-592 (owner 2026-10-19, PROVISIONAL Q-398): the shape stops at the SERVICE window (the shutter does not close
-- by itself any more) and at 25.5 s (Rules HeadAt) pushes its head in through it when it is open (Effects/ANM-010, record
-- Anchor); the shop lit then = the jumpscare. Here: the room holds its breath around that moment.
local Types = require(script.Parent.Parent.Types)

const STREET_WEST = "TRL@-40,0,30"
-- TASK-592: outside the service window, where its head comes in. World +Z = the street (owner 2026-10-19: -6 put it
-- inside the kitchen; the point stands ~1 stud outside the counter, z 14.5, the window plane is z 13.4)
const GLASS_BIG = "SCENE-WINDOW-EYES@0,-5,8"
const STREET_EAST = "TRL@40,0,30"

const scene: Types.Scene = {
	Key = "anm_010_hush",
	Name = "The Hush (shape, cameras, lantern)",
	Extend = true,
	Steps = {
		-- the trigger: the lamps start to die, a heavy low hum rises, a jolt and the view breathes in (R1)
		{ At = 0, Phase = "Active", Kind = "Sound", Target = "hum_rise", Value = 0.7 },
		{ At = 0, Phase = "Active", Kind = "Shake", Target = "Jolt" },
		{ At = 0, Phase = "Active", Kind = "Fov", Value = 3, To = 0, Duration = 1.6 },
		-- on the feed: something tall waits in the drive-thru lane the whole Hush (R4)
		{ At = 1, Phase = "Active", Kind = "Actor", Target = "AST-064_Walker", Point = "DTQ-1", To = "DT-STOP", Duration = 12, Sound = "walker_step", Seen = "Cameras" },
		-- the corner post: the dark is chosen; a faint light stays around him (R11)
		{ At = 15, Phase = "Active", Kind = "Lantern", Target = "Glow", Value = 4.2, To = 0.55, Duration = 1.5 },
		-- the Hush passes outside the glass (R3), slow, huge
		{ At = 17, Phase = "Active", Kind = "Silhouette", Target = "Arrive", Point = STREET_WEST, To = GLASS_BIG, Duration = 8, Value = 1.5, Sound = "heavy_steps" },
		{ At = 17, Phase = "Active", Kind = "Fov", Value = 1.5, To = 0, Duration = 8 },
		{ At = 18, Phase = "Active", Kind = "Vignette", Value = 0.3, To = 0.45, Duration = 7 },
		-- it stops at the big window: the hum dies, two seconds of nothing (R8)
		{ At = 25, Phase = "Active", Kind = "Sound", Target = "hum_die", Value = 0.8 },
		{ At = 25, Phase = "Active", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 25.2, Phase = "Active", Kind = "Sound", Target = "steps_stop", Point = "TRL" },
		{ At = 27.5, Phase = "Active", Kind = "Sound", Target = "door_creak", Point = "SCENE-WINDOW-EYES", Value = 0.6 },
		{ At = 27.5, Phase = "Active", Kind = "Shake", Target = "Step" },
		{ At = 28, Phase = "Active", Kind = "Heartbeat", Value = 70, To = 110, Duration = 7 },
		{ At = 31.5, Phase = "Active", Kind = "Sound", Target = "door_creak", Point = "SCENE-WINDOW-EYES", Value = 0.45 },
		-- TASK-592: the head through the window (25.5 .. 31.5 s): the room shrinks around it, a plain order for who is in
		{ At = 25.5, Phase = "Active", Where = "Inside", Kind = "Text", Text = "DON'T MOVE. KEEP THE LIGHTS OFF.", Duration = 2.5 },
		{ At = 25.5, Phase = "Active", Kind = "Vignette", Value = 0.45, To = 0.6, Duration = 1.5 },
		{ At = 25.5, Phase = "Active", Kind = "Fov", Value = -3, To = 0, Duration = 6 },
		{ At = 26, Phase = "Active", Kind = "Nudge", Value = 3, Point = "SCENE-WINDOW-EYES", Duration = 1.2, Where = "Inside" },
		{ At = 31.5, Phase = "Active", Kind = "Vignette", Value = 0.6, To = 0.45, Duration = 1.5 },
		-- then it goes on, east, and the street breathes
		{ At = 33, Phase = "Active", Kind = "Silhouette", Target = "Leave", To = STREET_EAST, Duration = 7 },
		{ At = 33, Phase = "Active", Kind = "Vignette", Value = 0.45, To = 0.3, Duration = 3 },
		-- right (posts back): the lamps cascade, the light around him goes, the shape is gone (R10)
		{ At = 0, Phase = "Resolved", Kind = "Silhouette", Target = "Leave", To = STREET_EAST, Duration = 3 },
		{ At = 0, Phase = "Resolved", Kind = "Lantern", Target = "Glow", Value = 0, Duration = 1.5 },
		{ At = 0.3, Phase = "Resolved", Kind = "Sound", Target = "power_up", Value = 0.7 },
		-- wrong (a light on): it saw the light; the jolt and the view punched in (R9)
		{ At = 0, Phase = "Failed", Kind = "Sound", Target = "power_cut" },
		{ At = 0, Phase = "Failed", Kind = "Shake", Target = "Jolt" },
		{ At = 0, Phase = "Failed", Kind = "Fov", Value = -5, To = 0, Duration = 0.7 },
		{ At = 0, Phase = "Failed", Kind = "Lantern", Target = "Glow", Value = 0, Duration = 0.2 },
		{ At = 1.5, Phase = "Failed", Kind = "Silhouette", Target = "Leave", To = STREET_EAST, Duration = 4 },
		-- outside (R12): get inside; the shape comes down the street at him instead
		{ At = 1, Phase = "Active", Where = "Outside", Kind = "Text", Text = "THE LIGHTS ARE DYING. GET INSIDE!", Duration = 3 },
		{ At = 4, Phase = "Active", Where = "Outside", Kind = "Whispers", Target = "outside", Value = 0.5, To = 2.4, Duration = 10 },
		{ At = 4, Phase = "Active", Where = "Outside", Kind = "Heartbeat", Value = 75, To = 145, Duration = 11 },
	},
}

return scene
