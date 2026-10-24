--!strict
-- ANM-013 The white eyes, the blackout's bar (TASK-587; design/horror-cinematic.md §3.7, §11.1 R1-R10, §11.2).
-- Anchored to the actor's record (Rules/ANM-013: refuse = close the window on it, Take Order = Failed; no deadline).
-- Staring at it is the stare pressure (Content.Anomalies Stare; TASK-482), so the heart and the words of this scene
-- live in the first seconds. Signature: the hum drops, it lifts its head and EVERY customer turns to the player at once
-- (Pose Turn, Value 1) with a dry crack; pairs of white eyes light up outside the front glass one by one (Lantern
-- Eyes); in the silence every light dies and only ITS eyes light the counter (the inverse of the blackout's glow); on
-- the security cameras there are eyes at every window and they never go out (Seen "Cameras"). After the refusal the
-- eyes shine through the shutter for a second. Presentation only (T10). Every number PROVISIONAL until the owner's
-- Play. Owner 2026-10-22 (anomaly tics): it arrives with normal eyes (the cameras see them white) and they turn white
-- in the Take Order talk (Content.Tics); this scene no longer lights ITS eyes at the counter. The "windows" are the MapPoints outside the shop (restaurant_bind): the service window (Kit eyes, already at
-- eye height), the drive-thru stop, the pantry's exit door and the van stop (Lantern eyes, 5 studs over the point);
-- the camera layer adds the back alley, where the cameras watch.
local Types = require(script.Parent.Parent.Types)

const OUTSIDE = "SCENE-WINDOW-EYES" -- outside the service window (eyes height)
const WINDOWS = { "DT-STOP", "DOOR-B", "VAN-STOP" } -- after the service window, in the order they light up
const WATCHED = { "DT-STOP", "DOOR-B", "SCENE-STEPS-FAR", "SCENE-DOOR-OUT", "VAN-STOP" } -- the camera layer (floor points)
const EYES_FROM = 3 -- s: the first pair
const EYES_GAP = 1.5
const EYES_OUT = 9 -- s: every pair outside goes out at once (the silence)

const scene: Types.Scene = {
	Key = "anm_013_white_eyes",
	Name = "The white eyes",
	Live = true,
	Words = {
		white_eyes_all = {
			"THEY'RE ALL LOOKING",
			"THEY'RE ALL LOOKING",
			"CLOSE THE WINDOW",
			"DON'T TAKE ITS ORDER",
			"SEND IT AWAY",
			"those aren't eyes...",
		},
	},
	Steps = {
		-- R1: the hum drops, a soft drop of the sound, a jolt and the view pulses; the colour goes cold at once
		{ At = 0, Phase = "Active", Kind = "Sound", Target = "hum_die", Value = 0.6 },
		{ At = 0, Phase = "Active", Kind = "Sound", Target = "suspense_drop", Value = 0.5 },
		{ At = 0, Phase = "Active", Kind = "Shake", Target = "Jolt", Value = 0.4 },
		{ At = 0, Phase = "Active", Kind = "Fov", Value = -2, To = 0, Duration = 0.7 },
		{ At = 0, Phase = "Active", Kind = "Grade", Target = "Cold", Value = 0, To = 0.2, Duration = 1 },
		{ At = 1, Phase = "Active", Kind = "Pose", Target = "Lift", Value = 12, Duration = 1.5 },
		-- every customer turns to the player together, with one dry crack, and holds the look
		{ At = 2, Phase = "Active", Kind = "Pose", Target = "Turn", Value = 1, Duration = 0.25, To = 6 },
		{ At = 2, Phase = "Active", Kind = "Sound", Target = "neck_crack", Value = 0.45 },
		{ At = 2, Phase = "Active", Kind = "Cinema", Value = 0.08, Duration = 1.5 },
		-- R5 + R7: the hint, the heart, the edges, the colour going
		{ At = 3, Phase = "Active", Kind = "Whispers", Target = "white_eyes_all", Value = 0.3, To = 1.2, Duration = 6, Where = "Inside" },
		{ At = 3, Phase = "Active", Kind = "Whispers", Target = "outside", Value = 0.3, To = 1.2, Duration = 6, Where = "Outside" },
		{ At = 3, Phase = "Active", Kind = "Heartbeat", Value = 70, To = 125, Duration = 6 },
		{ At = 3, Phase = "Active", Kind = "Vignette", Value = 0, To = 0.25, Duration = 6 },
		{ At = 3, Phase = "Active", Kind = "Grade", Value = 0.2, To = 0.38, Duration = 6 },
		{ At = 4, Phase = "Active", Kind = "Fov", Value = 1, To = 0, Duration = 5 },
		-- R8: the eyes outside go out together, the room goes quiet, then every light dies but ITS eyes
		{ At = EYES_OUT, Phase = "Active", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = EYES_OUT, Phase = "Active", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = EYES_OUT, Phase = "Active", Kind = "Silence", Value = 1, To = 0.25, Duration = 0.4 },
		{ At = 9.4, Phase = "Active", Kind = "Lights", Target = "Off" },
		{ At = 9.4, Phase = "Active", Kind = "Sound", Target = "lights_off", Value = 0.6 },
		-- owner 2026-10-22: ITS white eyes at the counter in the dark (Lantern Eyes at Q1, Value 12, 2.3 s) showed the tic before
		-- the talk; the eyes turn white only in the talk now (Content.Tics, Kit/Tic). The dark stays, without them
		-- R9: the lights crash back, every head snaps to the player again
		{ At = 11.7, Phase = "Active", Kind = "Lights", Target = "Cascade", Duration = 1.5 },
		{ At = 11.7, Phase = "Active", Kind = "Sound", Target = "horror_sting", Value = 0.6 },
		{ At = 11.7, Phase = "Active", Kind = "Pose", Target = "Turn", Value = 1, Duration = 0.2, To = 4 },
		{ At = 11.7, Phase = "Active", Kind = "Shake", Target = "Jolt" },
		{ At = 11.7, Phase = "Active", Kind = "Blur", Value = 5, To = 0, Duration = 1 },
		{ At = 11.7, Phase = "Active", Kind = "Silence", Value = 0.25, To = 1, Duration = 2 },
		-- the work goes on (the stare pressure takes over from here)
		{ At = 16, Phase = "Active", Kind = "Cinema", Value = 0, Duration = 1.5 },
		{ At = 16, Phase = "Active", Kind = "Vignette", Value = 0.25, To = 0.08, Duration = 4 },
		{ At = 16, Phase = "Active", Kind = "Grade", Value = 0.38, To = 0.12, Duration = 4 },

		-- Resolved (the window shut on it): the eyes shine through the shutter a second; R10 in steps
		{ At = 0, Phase = "Resolved", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Lights", Target = "Cascade", Duration = 1 },
		{ At = 0, Phase = "Resolved", Kind = "Silence", Value = 1, To = 0.5, Duration = 0.3 },
		{ At = 0.8, Phase = "Resolved", Kind = "Actor", Point = OUTSIDE, Duration = 1 },
		{ At = 0.8, Phase = "Resolved", Kind = "Sound", Target = "suspense_hiss", Point = OUTSIDE, Value = 0.5 },
		{ At = 1.8, Phase = "Resolved", Kind = "Silence", Value = 0.5, To = 1, Duration = 1.5 },
		{ At = 2, Phase = "Resolved", Kind = "Sound", Target = "breath_held" },
		{ At = 1.8, Phase = "Resolved", Kind = "Grade", Value = 0.38, To = 0, Duration = 2.5 },
		{ At = 1.8, Phase = "Resolved", Kind = "Vignette", Value = 0.25, To = 0, Duration = 2 },
		{ At = 0, Phase = "Resolved", Kind = "Blur", Value = 0, To = 0, Duration = 0 },
		{ At = 2.2, Phase = "Resolved", Kind = "Cinema", Value = 0, Duration = 1 },

		-- Failed (its order taken): a white flash, the eyes on the screen (Kit/Jumpscare on the cue), red + blur
		{ At = 0, Phase = "Failed", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Failed", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0, Phase = "Failed", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 0, Phase = "Failed", Kind = "Lights", Target = "Flicker", Duration = 0.3 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Grade", Target = "Red", Value = 0.85, To = 0, Duration = 2.8 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Blur", Value = 12, To = 0, Duration = 1.4 },
		{ At = 0, Phase = "Failed", Who = "Safe", Kind = "Shake", Target = "Jolt" },
		{ At = 0, Phase = "Failed", Who = "Safe", Kind = "Pose", Target = "Turn", Value = 1, Duration = 0.2, To = 3 },
		{ At = 0.8, Phase = "Failed", Kind = "Vignette", Value = 0.4, To = 0, Duration = 3 },
		{ At = 1.5, Phase = "Failed", Who = "Safe", Kind = "Grade", Value = 0.38, To = 0, Duration = 2 },
		{ At = 2, Phase = "Failed", Kind = "Cinema", Value = 0, Duration = 1 },
	},
}

-- R3 + R4 (generated, not typed): a pair of white eyes at each window one by one (the service window first), all out
-- at EYES_OUT; on the cameras every window has its eyes from the start and they never go out
do
	const front: Types.Step = { At = EYES_FROM, Phase = "Active", Kind = "Actor", Point = OUTSIDE, Duration = EYES_OUT - EYES_FROM }
	table.insert(scene.Steps, front)
	for index, point in WINDOWS do
		const at = EYES_FROM + index * EYES_GAP
		const eyes: Types.Step = { At = at, Phase = "Active", Kind = "Lantern", Target = "Eyes", Point = point, Value = 6, Duration = EYES_OUT - at }
		const hiss: Types.Step = { At = at, Phase = "Active", Kind = "Sound", Target = "suspense_hiss", Point = point, Value = 0.3 }
		table.insert(scene.Steps, eyes)
		table.insert(scene.Steps, hiss)
	end
	for _, point in WATCHED do
		const watched: Types.Step = { At = 2, Phase = "Active", Kind = "Lantern", Target = "Eyes", Point = point, Value = 6, Seen = "Cameras" }
		table.insert(scene.Steps, watched)
	end
end

return scene
