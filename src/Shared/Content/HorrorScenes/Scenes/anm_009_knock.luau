--!strict
-- ANM-009 The knock, "it's me, Walt" - the blackout's bar (TASK-588; design/horror-cinematic.md §11.1, §11.2; owner
-- 2026-10-18, TASK-561). Replaces the scene of HorrorScenes/init: restaurant only, the pantry's exit door DOOR-B
-- (Vehicle/RestaurantDoorService).
-- TASK-592 (owner 2026-10-19, PROVISIONAL Q-398): the answer is no longer "do nothing" - RUN AND LOCK THE BACK DOOR. The
-- door's prompt reads "Lock Door" until the heavy series (Rules/ANM-009 LockBy 10 s). Timeline fitted to Rules/ANM-009:
-- series 1 at 0 (far and soft), series 2 at 5 (closer, Walt's voice), series 3 at 10 (the heavy one: three blows at 10,
-- 11.2, 12.4 = Series3At + HeavyGap; each one bulges the door, Door Bulge). Not locked: the door gives on the third blow
-- (Failed at ~12.4, everyone gets the face). Locked: the latch holds on the last blow, then it gives up at 15 (Window 13
-- + DoorGrace 2): one soft knock, the steps and its shadow go away for LeaveFor 4 s; Resolved at 19.
-- The knocks, the voice, the bolt and the pressure near the door (heart, colour drained, edges closing in) are
-- Effects/ANM-009; this scene keeps the room: the hush, the cold, the words that say lock it, the silence before the
-- heavy series and the blows on the door.
-- Opened / burst (Failed): the face (Effects/ANM-009 jumpscare) with a white-out blur, red, a lunge of the view and the
-- sting; the others hear the door bang. Locked (Resolved): the room and the colour come back, a breath out.
-- Every number PROVISIONAL until the owner's Play (Q-397, Q-398).
local Types = require(script.Parent.Parent.Types)

type Scene = Types.Scene

const DOOR = "SCENE-DOOR"
const DOOR_OUT = "SCENE-DOOR-OUT"
const FAR = "SCENE-STEPS-FAR"

const scene: Scene = {
	Key = "anm_009_knock",
	Name = "The knock",
	Live = true,
	Words = {
		knock_outside = {
			"GET AWAY FROM THE DOOR",
			"GET AWAY FROM THE DOOR",
			"GO ROUND THE FRONT",
			"THAT'S NOT WALT",
			"don't let it see you",
			"it's at the back door...",
		},
		-- TASK-592: the new verb, said plainly
		knock_lock = {
			"LOCK THE BACK DOOR",
			"LOCK THE BACK DOOR",
			"LOCK IT",
			"THAT'S NOT WALT",
			"WALT HAS A KEY",
			"before it gets in...",
		},
	},
	Steps = {
		-- R4 (§11.2): on the security feed whoever knocks is NOT Walt - a figure far too tall stands at the pantry's
		-- exit door the whole time; the eye only gets the shadow under the door. It walks off when the knocking ends.
		{ At = 0, Phase = "Active", Kind = "Actor", Target = "AST-064_Walker", Point = "SCENE-DOOR-OUT", To = "SCENE-DOOR-OUT", Duration = 0.5, Seen = "Cameras" },
		{ At = 1.5, Phase = "Resolved", Kind = "Actor", Target = "AST-064_Walker", To = "SCENE-STEPS-FAR", Duration = 6, Sound = "walker_step", Seen = "Cameras", Value = 1 },
		{ At = 2, Phase = "Failed", Kind = "Actor", Target = "AST-064_Walker", To = "SCENE-STEPS-FAR", Duration = 4, Sound = "walker_step", Seen = "Cameras", Value = 1 },
		-- 0 s, first series far and soft: the room starts to hush, bars close in
		{ At = 0, Phase = "Active", Kind = "Silence", Value = 1, To = 0.6, Duration = 2 },
		{ At = 0.5, Phase = "Active", Kind = "Cinema", Value = 0.1, Duration = 1.5 },
		-- its shadow on the light under the door, there the whole time it knocks (owner 2026-10-18, as in the blackout)
		{ At = 0, Phase = "Active", Kind = "Shadow", Target = "Arrive", Point = DOOR, To = FAR, Duration = 1 },
		{ At = 0.5, Phase = "Active", Kind = "Grade", Target = "Cold", Value = 0, To = 0.5, Duration = 12 },
		{ At = 1, Phase = "Active", Kind = "Vignette", Value = 0, To = 0.25, Duration = 9 },
		-- 1.5 s, the verb (TASK-592): said once, big, then the words keep saying it
		{ At = 1.5, Phase = "Active", Kind = "Text", Text = "SOMEONE'S AT THE BACK DOOR. LOCK IT!", Duration = 2.5, Where = "Inside" },
		{ At = 1.5, Phase = "Active", Kind = "Text", Text = "GET AWAY FROM THE BACK DOOR!", Duration = 2.5, Where = "Outside" },
		{ At = 2, Phase = "Active", Kind = "Whispers", Target = "knock_lock", Value = 0.5, To = 1.8, Duration = 7, Where = "Inside" },
		{ At = 2, Phase = "Active", Kind = "Whispers", Target = "knock_outside", Value = 0.5, To = 2, Duration = 7, Where = "Outside" },
		{ At = 2, Phase = "Active", Kind = "Heartbeat", Value = 80, To = 143, Duration = 8, Where = "Outside" },
		-- 5 s, second series closer, Walt's voice: a small push of the view towards the door
		{ At = 5, Phase = "Active", Kind = "Silence", Value = 0.6, To = 0.35, Duration = 3 },
		{ At = 5, Phase = "Active", Kind = "Nudge", Value = 3, Point = DOOR, Duration = 0.8 },
		{ At = 5, Phase = "Active", Kind = "Fov", Value = -2, To = 0, Duration = 4 },
		{ At = 7.5, Phase = "Active", Kind = "Lights", Target = "Flicker", Duration = 0.5 },
		-- 9.2 s, the silence before the heavy series: no words, the world muted, a held breath
		{ At = 9.2, Phase = "Active", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 9.2, Phase = "Active", Kind = "Silence", Value = 0.35, To = 0.04, Duration = 0.5 },
		{ At = 9.4, Phase = "Active", Kind = "Sound", Target = "breath_held" },
		-- 10 / 11.2 / 12.4 s, the heavy series (TASK-592): each blow bulges the door in, shakes the room, the lights flinch
		{ At = 10, Phase = "Active", Kind = "Door", Target = "Bulge", Point = DOOR, Duration = 1 },
		{ At = 10, Phase = "Active", Kind = "Sound", Target = "door_force", Point = DOOR, Value = 1.4 },
		{ At = 10, Phase = "Active", Kind = "Shake", Target = "Door", Point = DOOR, Value = 1.3 },
		{ At = 10, Phase = "Active", Kind = "Lights", Target = "Flicker", Duration = 0.3 },
		{ At = 10, Phase = "Active", Kind = "Blur", Value = 2.5, To = 0, Duration = 0.8 },
		{ At = 10, Phase = "Active", Kind = "Vignette", Value = 0.25, To = 0.35, Duration = 0.6 },
		{ At = 11.2, Phase = "Active", Kind = "Door", Target = "Bulge", Point = DOOR, Duration = 1 },
		{ At = 11.2, Phase = "Active", Kind = "Sound", Target = "door_force", Point = DOOR, Value = 1.7 },
		{ At = 11.2, Phase = "Active", Kind = "Shake", Target = "Door", Point = DOOR, Value = 1.6 },
		{ At = 11.2, Phase = "Active", Kind = "Lights", Target = "Flicker", Duration = 0.35 },
		{ At = 11.2, Phase = "Active", Kind = "Blur", Value = 3.5, To = 0, Duration = 0.8 },
		{ At = 11.2, Phase = "Active", Kind = "Vignette", Value = 0.35, To = 0.45, Duration = 0.6 },
		{ At = 12.4, Phase = "Active", Kind = "Door", Target = "Bulge", Point = DOOR, Duration = 1.1 },
		{ At = 12.4, Phase = "Active", Kind = "Sound", Target = "door_force", Point = DOOR, Value = 2 },
		{ At = 12.4, Phase = "Active", Kind = "Shake", Target = "Jolt", Value = 1.3 },
		{ At = 12.4, Phase = "Active", Kind = "Lights", Target = "Flicker", Duration = 0.45 },
		{ At = 12.4, Phase = "Active", Kind = "Blur", Value = 4.5, To = 0, Duration = 1 },
		{ At = 12.4, Phase = "Active", Kind = "Vignette", Value = 0.45, To = 0.5, Duration = 0.6 },
		-- 12.9 s, still Active = it was locked: the latch holds (unlocked, the run is already Failed)
		{ At = 12.9, Phase = "Active", Kind = "Door", Target = "Hold", Point = DOOR, Duration = 0.4 },
		{ At = 12.9, Phase = "Active", Kind = "Sound", Target = "latch_hold", Point = DOOR },
		{ At = 13.3, Phase = "Active", Kind = "Silence", Value = 0.04, To = 0.3, Duration = 2 },
		-- 15 s, it gives up (Rules/ANM-009 Window + DoorGrace): one last soft knock, the steps go away and its shadow
		-- slides out of the gap, slow; still Active until LeaveFor (4 s) ends
		{ At = 15, Phase = "Active", Kind = "Sound", Target = "door_knock", Point = DOOR_OUT, Value = 0.25 },
		{ At = 15.8, Phase = "Active", Kind = "Sound", Target = "walker_step", Point = DOOR_OUT, To = FAR, Duration = 3 },
		{ At = 15.8, Phase = "Active", Kind = "Shadow", Target = "Leave", Point = DOOR, To = FAR, Duration = 3 },
		-- locked (Resolved, record kept Linger 4.5 s): the room comes back, a breath out
		{ At = 0, Phase = "Resolved", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Blur", Value = 0, To = 0, Duration = 0 },
		{ At = 0.2, Phase = "Resolved", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0.5, Phase = "Resolved", Kind = "Silence", Value = 0.3, To = 1, Duration = 3 },
		{ At = 1, Phase = "Resolved", Kind = "Sound", Target = "breath_held", Value = 0.6 },
		{ At = 1, Phase = "Resolved", Kind = "Grade", Value = 0.5, To = 0, Duration = 3 },
		{ At = 1, Phase = "Resolved", Kind = "Vignette", Value = 0.5, To = 0, Duration = 3 },
		{ At = 1.5, Phase = "Resolved", Kind = "Cinema", Value = 0, Duration = 1.2 },
		-- not locked (the door burst) or opened by hand (Failed): the climax for who was caught, the bang for the others
		{ At = 0, Phase = "Failed", Kind = "Shadow", Target = "Leave", Point = DOOR, To = FAR, Duration = 0.3 },
		{ At = 0, Phase = "Failed", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Failed", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0, Phase = "Failed", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 0, Phase = "Failed", Kind = "Sound", Target = "door_force", Point = DOOR, Value = 2 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Sound", Target = "horror_sting", Value = 2.5 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Blur", Value = 18, To = 0, Duration = 1.6 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Grade", Target = "Red", Value = 1, To = 0, Duration = 3.2 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Fov", Value = -6, To = 0, Duration = 1.2 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Shake", Target = "Jolt", Value = 1.5 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Vignette", Value = 0.55, To = 0, Duration = 3.5 },
		{ At = 0.1, Phase = "Failed", Who = "Safe", Kind = "Sound", Target = "horror_sting", Value = 0.8 },
		{ At = 0.1, Phase = "Failed", Who = "Safe", Kind = "Shake", Target = "Door", Point = DOOR },
		{ At = 0, Phase = "Failed", Who = "Safe", Kind = "Blur", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Failed", Who = "Safe", Kind = "Lights", Target = "Flicker", Duration = 0.7 },
		{ At = 1, Phase = "Failed", Who = "Safe", Kind = "Vignette", Value = 0.5, To = 0, Duration = 3 },
		{ At = 1.5, Phase = "Failed", Who = "Safe", Kind = "Grade", Value = 0.5, To = 0, Duration = 2.5 },
		{ At = 3, Phase = "Failed", Kind = "Cinema", Value = 0, Duration = 1 },
	},
}

return scene
