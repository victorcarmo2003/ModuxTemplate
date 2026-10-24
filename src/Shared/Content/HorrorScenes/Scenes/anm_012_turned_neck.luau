--!strict
-- ANM-012 the turned neck up to the blackout's bar (TASK-590; design/horror-cinematic.md §6, §11.2). Extend: the cracks,
-- words, bars, grading and the stare pressure stay as they are (init, Stare); this adds:
--   R1  her arrival lands: a jolt and the view pulled in a little
--   R2  every crack of her neck reaches the room: the lamps near the camera flicker, the lamp over the counter swings,
--       a pulse of blur; the third crack kills the light for a breath
--   R4  on the security feed her head is already turning, slowly, to stare INTO the camera (Pose Turn on the feed)
--   R9  refused: the head snaps the last half turn, the lights flicker once more; wrong: her head is the face (Kit Scare)
--   R12 outside: the cracks are heard from the counter, and the words tell him what is waiting inside
-- owner 2026-10-21: R2 (the room shaking with the arrival cracks) is gone with the cracks; her neck breaks only in the talk.
-- Pose and Prop are the TASK-587 pieces.
local Types = require(script.Parent.Parent.Types)

const scene: Types.Scene = {
	Key = "anm_012_turned_neck",
	Name = "The turned neck (room, cameras)",
	Extend = true,
	Steps = {
		{ At = 0, Phase = "Active", Kind = "Shake", Target = "Jolt" },
		{ At = 0, Phase = "Active", Kind = "Fov", Value = -2.5, To = 0, Duration = 1.2 },
		-- R4: on the feed she stares into the camera, the head turning slowly the whole time
		{ At = 1, Phase = "Active", Kind = "Pose", Target = "Turn", Duration = 6, Seen = "Cameras" },
		-- R9: refused, the head snaps the last half turn and the lights answer once more
		{ At = 0.3, Phase = "Resolved", Kind = "Lights", Target = "Flicker", Duration = 0.35 },
		{ At = 0, Phase = "Resolved", Kind = "Fov", Value = 2, To = 0, Duration = 1 },
		{ At = 0, Phase = "Failed", Kind = "Lights", Target = "Flicker", Duration = 0.5 },
		-- R12: outside
		{ At = 1, Phase = "Active", Where = "Outside", Kind = "Whispers", Target = "neck_outside", Value = 0.4, To = 1.2, Duration = 7 },
		{ At = 9.5, Phase = "Active", Where = "Outside", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
	},
	Words = {
		neck_outside = {
			"SOMEONE'S AT THE COUNTER",
			"DON'T TAKE HER ORDER",
			"her neck...",
			"go back inside... carefully",
		},
	},
}

return scene
