--!strict
-- ANM-022 The head banger (TASK-591; owner 2026-10-19, Provisional Q-399; design/horror-cinematic.md §11). Anchored to
-- the actor's record (Rules/ANM-022): Active = it came to the window and will not leave; Resolved = the shop went dark
-- while it stood there; Failed = its order taken. The blows on the shut window are cue-driven (Effects/ANM-022); the
-- scene gives the room around them: the hint that the window does nothing and the lights do, the heart, the colour,
-- on the security feed its face pressed to the glass staring INTO the camera, and the relief when the dark sends it
-- off. Every number PROVISIONAL until the owner's Play.
local Types = require(script.Parent.Parent.Types)

const scene: Types.Scene = {
	Key = "anm_022_head_banger",
	Name = "The head banger",
	Live = true,
	Words = {
		banger = {
			"IT WON'T LEAVE",
			"THE WINDOW WON'T STOP IT",
			"TURN OFF THE LIGHTS",
			"TURN OFF THE LIGHTS",
			"DON'T TAKE ITS ORDER",
			"it wants the light...",
			"lights off... now",
		},
	},
	Steps = {
		-- R1: a low sting, a jolt, the view pulled in a little
		{ At = 0, Phase = "Active", Kind = "Sound", Target = "horror_sting", Value = 0.35 },
		{ At = 0, Phase = "Active", Kind = "Shake", Target = "Jolt", Value = 0.4 },
		{ At = 0, Phase = "Active", Kind = "Fov", Value = -2, To = 0, Duration = 0.8 },
		{ At = 1, Phase = "Active", Kind = "Cinema", Value = 0.08, Duration = 1.5 },
		-- R4: on the feed it stares into the camera
		{ At = 1, Phase = "Active", Kind = "Pose", Target = "Turn", Duration = 2, Seen = "Cameras" },
		-- R5 + R7: the hint (the lights, not the window), the heart, the edges, the colour
		{ At = 2, Phase = "Active", Kind = "Whispers", Target = "banger", Value = 0.3, To = 1.4, Duration = 10 },
		{ At = 2, Phase = "Active", Kind = "Heartbeat", Value = 70, To = 125, Duration = 12 },
		{ At = 2, Phase = "Active", Kind = "Vignette", Value = 0, To = 0.25, Duration = 10 },
		{ At = 2, Phase = "Active", Kind = "Grade", Target = "Cold", Value = 0, To = 0.3, Duration = 10 },
		{ At = 4, Phase = "Active", Kind = "Lights", Target = "Flicker", Duration = 0.4 },
		{ At = 12, Phase = "Active", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 12, Phase = "Active", Kind = "Cinema", Value = 0, Duration = 1.5 },
		{ At = 30, Phase = "Active", Kind = "Heartbeat", Value = 0, To = 0 },
		-- Resolved (the dark sent it off): silence, a breath, the colour back
		{ At = 0, Phase = "Resolved", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Silence", Value = 1, To = 0.3, Duration = 0.4 },
		{ At = 1.2, Phase = "Resolved", Kind = "Silence", Value = 0.3, To = 1, Duration = 2 },
		{ At = 1.2, Phase = "Resolved", Kind = "Sound", Target = "breath_held" },
		{ At = 0.5, Phase = "Resolved", Kind = "Grade", Value = 0.3, To = 0, Duration = 2.5 },
		{ At = 0.5, Phase = "Resolved", Kind = "Vignette", Value = 0.25, To = 0, Duration = 2 },
		{ At = 1, Phase = "Resolved", Kind = "Cinema", Value = 0, Duration = 1 },
		-- Failed (its order taken): the face (Kit/Jumpscare on the cue), red + blur on who did it
		{ At = 0, Phase = "Failed", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Failed", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Grade", Target = "Red", Value = 0.85, To = 0, Duration = 2.8 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Blur", Value = 12, To = 0, Duration = 1.4 },
		{ At = 0, Phase = "Failed", Who = "Safe", Kind = "Shake", Target = "Jolt" },
		{ At = 0.8, Phase = "Failed", Kind = "Vignette", Value = 0.4, To = 0, Duration = 3 },
		{ At = 2, Phase = "Failed", Kind = "Cinema", Value = 0, Duration = 1 },
	},
}

return scene
