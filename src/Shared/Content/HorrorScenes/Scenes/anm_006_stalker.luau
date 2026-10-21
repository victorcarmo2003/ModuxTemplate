--!strict
-- ANM-006 The stalker, "don't look" - the blackout's bar (TASK-588; design/horror-cinematic.md §3.3, §11.1, §11.2).
-- Replaces the scene of HorrorScenes/init (TASK-490). Fitted to Rules/ANM-006 as before: Signal = it stands on the far
-- sidewalk and only comes closer while someone stares (12 s of stare to the window, AutoOff 28 s), Active = it reached
-- the window (LeapDelay 1 s: the last chance to shut it), then Failed (it leapt in) or Resolved (shut: it bangs and
-- goes; or nobody looked: it fades). The figure, its steps, the leap and the bangs are Effects/ANM-006.
-- What the bar adds: the shop lights flinch and the camera jolts on the first second (R1); colour drains cold (R2); on
-- the security cameras it already stands at the glass the whole time, much closer than it looks from the counter (R4);
-- a dead quiet once the words stop (R8); at the window the glass mists at face height and one fingertip taps it (R9,
-- the signature); shut in time, its palm slides down the other side of the misted glass and the mist clears (R10).
-- Outside (§3.0): its steps come from behind, the words say don't look back / get inside.
-- Every number PROVISIONAL until the owner's Play (Q-397).
local Types = require(script.Parent.Parent.Types)

type Scene = Types.Scene

const WINDOW = "SCENE-WINDOW-EYES" -- outside the service window, face height
const SHAPE = "AST-Stalker" -- Effects/ANM-006's art name (a dark placeholder while missing)

const scene: Scene = {
	Key = "anm_006_stalker",
	Name = "The stalker",
	Live = true,
	Words = {
		stalker_outside = {
			"DON'T LOOK BACK",
			"DON'T LOOK BACK",
			"GET INSIDE",
			"GET INSIDE",
			"it's right behind you...",
			"don't turn around",
		},
	},
	Steps = {
		-- R1: the sting, the lights flinch, a small jolt
		{ At = 0, Phase = "Signal", Kind = "Sound", Target = "horror_sting", Value = 0.4 },
		{ At = 0, Phase = "Signal", Kind = "Sound", Target = "post_buzz", Value = 0.7 },
		{ At = 0.1, Phase = "Signal", Kind = "Lights", Target = "Flicker", Duration = 1.2 },
		{ At = 0.1, Phase = "Signal", Kind = "Shake", Target = "Jolt", Value = 0.5 },
		{ At = 0.1, Phase = "Signal", Kind = "Fov", Value = -2, To = 0, Duration = 0.8 },
		{ At = 0.3, Phase = "Signal", Kind = "Cinema", Value = 0.09, Duration = 1.5 },
		-- R4: on the cameras it is already at the glass, standing still
		{ At = 2, Phase = "Signal", Kind = "Actor", Target = SHAPE, Point = WINDOW, To = WINDOW, Duration = 0.5, Seen = "Cameras" },
		-- R7: the words (don't look), the heart, the edges, the cold, a view that breathes
		{ At = 1, Phase = "Signal", Kind = "Whispers", Target = "stalker", Value = 0.3, To = 1.8, Duration = 12, Where = "Inside" },
		{ At = 1, Phase = "Signal", Kind = "Whispers", Target = "stalker_outside", Value = 0.5, To = 2.2, Duration = 12, Where = "Outside" },
		{ At = 1, Phase = "Signal", Kind = "Heartbeat", Value = 60, To = 110, Duration = 20, Where = "Inside" },
		{ At = 1, Phase = "Signal", Kind = "Heartbeat", Value = 75, To = 125, Duration = 20, Where = "Outside" },
		{ At = 1, Phase = "Signal", Kind = "Vignette", Value = 0, To = 0.3, Duration = 14 },
		{ At = 1, Phase = "Signal", Kind = "Grade", Target = "Cold", Value = 0, To = 0.45, Duration = 20 },
		{ At = 6, Phase = "Signal", Kind = "Fov", Value = 1, To = 0, Duration = 6 },
		-- outside: its steps come from behind (on screen, no place in the street)
		{ At = 5, Phase = "Signal", Kind = "Sound", Target = "walker_step", Value = 0.4, Where = "Outside" },
		{ At = 8.5, Phase = "Signal", Kind = "Sound", Target = "walker_step", Value = 0.6, Where = "Outside" },
		{ At = 11.5, Phase = "Signal", Kind = "Sound", Target = "walker_step", Value = 0.8, Where = "Outside" },
		-- R8: the words stop and the room goes quiet while it comes (12 s of stare at least)
		{ At = 13, Phase = "Signal", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 13, Phase = "Signal", Kind = "Silence", Value = 1, To = 0.3, Duration = 1.5 },
		{ At = 13, Phase = "Signal", Kind = "Vignette", Value = 0.3, To = 0.38, Duration = 4 },
		-- R9: at the window - one second to shut it. The glass mists at face height, a fingertip taps it once
		{ At = 0, Phase = "Active", Kind = "Actor", Target = SHAPE, To = WINDOW, Duration = 0.5, Value = 1 },
		{ At = 0, Phase = "Active", Kind = "Shake", Target = "Jolt" },
		{ At = 0, Phase = "Active", Kind = "Fov", Value = -3, To = 0, Duration = 0.6 },
		{ At = 0, Phase = "Active", Kind = "Sound", Target = "horror_sting", Value = 1 },
		{ At = 0, Phase = "Active", Kind = "Silence", Value = 0.3, To = 0.05, Duration = 0.25 },
		{ At = 0, Phase = "Active", Kind = "Heartbeat", Value = 160, To = 160, Duration = 1 },
		{ At = 0, Phase = "Active", Kind = "Whispers", Target = "stalker_window", Value = 3, To = 3, Duration = 1, Where = "Inside" },
		{ At = 0, Phase = "Active", Kind = "Text", Text = "CLOSE THE WINDOW!", Duration = 1.5, Where = "Inside" },
		{ At = 0, Phase = "Active", Kind = "Vignette", Value = 0.38, To = 0.45, Duration = 0.6 },
		{ At = 0, Phase = "Active", Kind = "Blur", Value = 6, To = 1.5, Duration = 0.8 },
		{ At = 0, Phase = "Active", Kind = "Grade", Target = "Cold", Value = 0.45, To = 0.7, Duration = 0.6 },
		{ At = 0, Phase = "Active", Kind = "Glass", Target = "Fog", Point = WINDOW, Value = 0.6, Duration = 0.5 },
		{ At = 0.35, Phase = "Active", Kind = "Glass", Target = "Knock", Point = WINDOW, Value = 1 },
		{ At = 0.35, Phase = "Active", Kind = "Shake", Target = "Step" },
		-- R10, shut in time (or it faded away): it bangs twice (Effects: the sound), the glass flexes; its palm slides
		-- down the misted glass (only if it really got there); colour and sound come back
		{ At = 0, Phase = "Resolved", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Blur", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Actor", Target = SHAPE, To = WINDOW, Duration = 0.5, Value = 1 },
		{ At = 0, Phase = "Resolved", Kind = "Glass", Target = "Bang", Point = WINDOW, Value = 0.8, Sound = "", To = "Misted" },
		{ At = 0.35, Phase = "Resolved", Kind = "Glass", Target = "Bang", Point = WINDOW, Value = 1, Sound = "", To = "Misted" },
		{ At = 0.9, Phase = "Resolved", Kind = "Glass", Target = "Hand", Point = WINDOW, Duration = 2, To = "Misted" },
		{ At = 0.3, Phase = "Resolved", Kind = "Sound", Target = "breath_held" },
		{ At = 0.4, Phase = "Resolved", Kind = "Grade", Value = 0.45, To = 0, Duration = 2 },
		{ At = 0.5, Phase = "Resolved", Kind = "Vignette", Value = 0.38, To = 0, Duration = 1.5 },
		{ At = 1, Phase = "Resolved", Kind = "Cinema", Value = 0, Duration = 1 },
		{ At = 1.2, Phase = "Resolved", Kind = "Glass", Target = "Fog", Point = WINDOW, Value = 0, Duration = 1.3 },
		-- it leapt in (Failed): the face for whoever it got (Effects), the glass shakes and the lights jump for the rest
		{ At = 0, Phase = "Failed", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Failed", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 0, Phase = "Failed", Kind = "Actor", Target = SHAPE, To = WINDOW, Duration = 0.5, Value = 1 },
		{ At = 0, Phase = "Failed", Kind = "Lights", Target = "Flicker", Duration = 0.8 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Grade", Target = "Red", Value = 0.85, To = 0, Duration = 2.8 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Blur", Value = 12, To = 0, Duration = 1.4 },
		{ At = 0, Phase = "Failed", Who = "Safe", Kind = "Glass", Target = "Bang", Point = WINDOW, Value = 1.3 },
		{ At = 0, Phase = "Failed", Who = "Safe", Kind = "Shake", Target = "Door" },
		{ At = 0, Phase = "Failed", Who = "Safe", Kind = "Heartbeat", Value = 150, To = 80, Duration = 3 },
		{ At = 3, Phase = "Failed", Who = "Safe", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0.8, Phase = "Failed", Kind = "Vignette", Value = 0.45, To = 0, Duration = 2.5 },
		{ At = 1.5, Phase = "Failed", Who = "Safe", Kind = "Grade", Value = 0.45, To = 0, Duration = 2.5 },
		{ At = 1.5, Phase = "Failed", Kind = "Glass", Target = "Fog", Point = WINDOW, Value = 0, Duration = 1 },
		{ At = 2, Phase = "Failed", Kind = "Cinema", Value = 0, Duration = 1 },
	},
}

return scene
