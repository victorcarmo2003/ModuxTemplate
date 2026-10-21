--!strict
-- ANM-004 the copies up to the blackout's bar (TASK-590; design/horror-cinematic.md §6, §11.2). Extend: the hint words,
-- bars, grading and the stare pressure ("DON'T LOOK AT IT") stay as they are (init, Stare); this adds:
--   R1  the copy arrives with the lamps blinking and a jolt
--   R3  it copies YOU: its head follows this client's camera a beat late (Pose Mimic), never quite in time
--   R4  on the security feed it is not there at all (only the one who left): a copy only exists to the eye
--   R8  a breath of silence before the hint words end; its head tilts, still
--   R9  refused: one short knock on the front glass from outside, where it stood; wrong: the jolt and the red
-- Pose, Prop are the TASK-587 pieces. Mimic is one rig: the actor of this record (the copy).
local Types = require(script.Parent.Parent.Types)

const scene: Types.Scene = {
	Key = "anm_004_copies",
	Name = "The copies (mimic, cameras)",
	Extend = true,
	Steps = {
		{ At = 0, Phase = "Active", Kind = "Lights", Target = "Flicker", Duration = 0.4 },
		{ At = 0, Phase = "Active", Kind = "Shake", Target = "Jolt" },
		{ At = 0, Phase = "Active", Kind = "Fov", Value = -2, To = 0, Duration = 1 },
		-- R3: it copies the player's look, late (the eye); R4: on the feed it vanishes (Scale 0 on the cameras layer)
		{ At = 1.5, Phase = "Active", Kind = "Pose", Target = "Mimic", Value = 0.7, Seen = "Eyes" },
		{ At = 0, Phase = "Active", Kind = "Pose", Target = "Scale", Value = 0.01, Duration = 0.01, Seen = "Cameras" },
		-- R8: the room holds its breath, its head tilts and stays
		{ At = 8.5, Phase = "Active", Kind = "Silence", Value = 1, To = 0.2, Duration = 0.5 },
		{ At = 8.5, Phase = "Active", Kind = "Pose", Target = "Tilt", Value = 20, Duration = 1.2, Seen = "Eyes" },
		{ At = 10.5, Phase = "Active", Kind = "Silence", Value = 0.2, To = 1, Duration = 1.5 },
		-- R9: refused, a knock on the front glass from outside, where it stood
		{ At = 1.6, Phase = "Resolved", Kind = "Sound", Target = "door_knock", Point = "SCENE-WINDOW-EYES", Value = 0.7 },
		{ At = 1.6, Phase = "Resolved", Kind = "Shake", Target = "Step" },
		{ At = 0, Phase = "Failed", Kind = "Lights", Target = "Flicker", Duration = 0.5 },
		{ At = 0, Phase = "Failed", Kind = "Fov", Value = -4, To = 0, Duration = 0.7 },
	},
}

return scene
