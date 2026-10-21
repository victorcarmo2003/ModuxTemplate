--!strict
-- ANM-021 The red fog - the blackout's bar (TASK-588; design/horror-cinematic.md §3.11, §11.1, §11.2). Replaces the scene
-- of HorrorScenes/init (owner 2026-10-18). Fitted to Rules/ANM-021 as before: Signal = OmenFor 12 s (the fog rises red
-- over the street, Effects/ANM-021, and the runner comes down it; the bell tolls three times), Active = BangFor 14 s (it
-- beats on the glass: three blows, a silence, three more, the biggest of the second series first), then Resolved /
-- Failed (Linger 5 s, the fog recedes). The fog, the runner and its lunges are Effects/ANM-021 (BLOWS = the Glass Bang
-- times below).
-- What the bar adds: a jolt and the lights flinching on the first bell (R1); shapes in the fog that only the security
-- cameras show - one walking up to the queue, a tall one crossing behind the tables (R4, the signature); every blow
-- FLEXES the glass and shakes dust from its frame (R9, Glass Bang, sound included); the warning on screen (R5).
-- Outside (§3.0): steps in the fog around the player, a blur that thickens, the words say get inside.
-- TASK-593 (owner Play 2026-10-19): no single runner any more. SEVERAL ghosts walk out of the fog to the window and the
-- door, seen with the bare eye (Silhouettes named by Text, Seen "Eyes"; the feed keeps its own shapes), stand there
-- facing in through the blows and back off into the fog at the end. With the window shut each blow is a Glass "Paw":
-- a BLACK ANIMAL PAW PRINT appears on the glass (they pile up), the pane shakes and rocks, dust falls.
-- Every number PROVISIONAL until the owner's Play (Q-397).
local Types = require(script.Parent.Parent.Types)

type Scene = Types.Scene

const WINDOW = "SCENE-WINDOW-EYES" -- outside the service window (Effects/ANM-021's WINDOW_POINT)
const SHAPE = "AST-064_Walker" -- the dark walker (a placeholder while the art is missing)
-- TASK-593: the ghosts, read off TRL (-42.5, 0.4, 4.9): the street runs to +Z, the service window is at ~Z +10, the side
-- door (TRL-OUT) at +12.5, 0, +4. Start deep in the fog, stop just outside the glass / the door.
const GHOST = 0.55 -- Silhouette scale (~7 studs: a person, not the Hush)

const scene: Scene = {
	Key = "anm_021_red_fog",
	Name = "The red fog",
	Live = true,
	Words = {
		red_fog_outside = {
			"GET INSIDE",
			"GET INSIDE",
			"GET OUT OF THE FOG",
			"DON'T STOP",
			"something is in there...",
			"it's all around you",
		},
	},
	Steps = {
		-- TASK-593: the ghosts come out of the fog (bare eye), each at its own pace, all there when the fog reaches the glass
		{ At = 1.5, Phase = "Signal", Kind = "Silhouette", Target = "Arrive", Text = "g1", Point = "TRL@-14,0,60", To = "TRL@-4,0,11.5", Duration = 10, Value = GHOST, Seen = "Eyes" },
		{ At = 2.5, Phase = "Signal", Kind = "Silhouette", Target = "Arrive", Text = "g2", Point = "TRL@7,0,64", To = "TRL@3.5,0,11.8", Duration = 9.3, Value = GHOST * 1.08, Seen = "Eyes" },
		{ At = 3.2, Phase = "Signal", Kind = "Silhouette", Target = "Arrive", Text = "g3", Point = "TRL@-30,0,52", To = "TRL@-11,0,13", Duration = 8.6, Value = GHOST * 0.94, Seen = "Eyes" },
		{ At = 4, Phase = "Signal", Kind = "Silhouette", Target = "Arrive", Text = "g4", Point = "TRL@26,0,50", To = "TRL@14.5,0,5", Duration = 7.8, Value = GHOST, Seen = "Eyes" },
		{ At = 5, Phase = "Signal", Kind = "Silhouette", Target = "Arrive", Text = "g5", Point = "TRL@0,0,70", To = "TRL@0,0,12.5", Duration = 6.9, Value = GHOST * 1.2, Sound = "walker_step", Seen = "Eyes" },
		-- R1: the bell, a jolt, the lights flinch; the colour starts bleeding red
		{ At = 0, Phase = "Signal", Kind = "Sound", Target = "church_bell" },
		{ At = 0, Phase = "Signal", Kind = "Shake", Target = "Jolt", Value = 0.6 },
		{ At = 0, Phase = "Signal", Kind = "Fov", Value = -3, To = 0, Duration = 0.8 },
		{ At = 0.2, Phase = "Signal", Kind = "Lights", Target = "Flicker", Duration = 1 },
		{ At = 0, Phase = "Signal", Kind = "Grade", Target = "Red", Value = 0, To = 0.55, Duration = 11 },
		{ At = 0.3, Phase = "Signal", Kind = "Cinema", Value = 0.1, Duration = 1.5 },
		-- R7: the words, the heart, the edges; the bell louder each time
		{ At = 1, Phase = "Signal", Kind = "Whispers", Target = "red_fog", Value = 0.4, To = 2.4, Duration = 10, Where = "Inside" },
		{ At = 1, Phase = "Signal", Kind = "Whispers", Target = "red_fog_outside", Value = 0.6, To = 2.8, Duration = 10, Where = "Outside" },
		{ At = 1, Phase = "Signal", Kind = "Heartbeat", Value = 70, To = 145, Duration = 11, Where = "Inside" },
		{ At = 1, Phase = "Signal", Kind = "Heartbeat", Value = 85, To = 160, Duration = 11, Where = "Outside" },
		{ At = 1, Phase = "Signal", Kind = "Vignette", Value = 0, To = 0.35, Duration = 11 },
		{ At = 1, Phase = "Signal", Kind = "Blur", Value = 0, To = 8, Duration = 10, Where = "Outside" },
		{ At = 4, Phase = "Signal", Kind = "Sound", Target = "church_bell", Value = 0.9 },
		{ At = 4, Phase = "Signal", Kind = "Fov", Value = 1, To = 0, Duration = 4 },
		{ At = 8, Phase = "Signal", Kind = "Sound", Target = "church_bell", Value = 1.1 },
		-- R5: the warning
		{ At = 5, Phase = "Signal", Kind = "Text", Text = "CLOSE THE WINDOW. Keep the fog out.", Duration = 3, Where = "Inside" },
		{ At = 5, Phase = "Signal", Kind = "Text", Text = "GET INSIDE. Get out of the fog.", Duration = 3, Where = "Outside" },
		-- R4: what the cameras show in the fog - one walking up to the queue, a tall one crossing behind the tables
		{ At = 2, Phase = "Signal", Kind = "Actor", Target = SHAPE, Point = "TBL-3", To = "Q5", Duration = 10, Seen = "Cameras" },
		{ At = 5, Phase = "Signal", Kind = "Silhouette", Target = "Pass", Point = "TBL-4", To = "TBL-3", Value = 0.8, Duration = 6, Seen = "Cameras" },
		-- outside: steps in the fog around the player (on screen)
		{ At = 3, Phase = "Signal", Kind = "Sound", Target = "walker_step", Value = 0.5, Where = "Outside" },
		{ At = 6.5, Phase = "Signal", Kind = "Sound", Target = "walker_step", Value = 0.7, Where = "Outside" },
		{ At = 9.5, Phase = "Signal", Kind = "Sound", Target = "walker_step", Value = 0.9, Where = "Outside" },
		-- R8: the room goes quiet before it reaches the glass
		{ At = 8, Phase = "Signal", Kind = "Silence", Value = 1, To = 0.4, Duration = 3 },
		{ At = 11, Phase = "Signal", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 11.2, Phase = "Signal", Kind = "Silence", Value = 0.4, To = 0.03, Duration = 0.5 },
		{ At = 11.4, Phase = "Signal", Kind = "Sound", Target = "breath_held" },
		-- R9: it reaches the glass - blows that flex and rock the pane, shake the dust off its frame and leave a black paw
		-- print each (TASK-593: Glass Paw)
		{ At = 0, Phase = "Active", Kind = "Silence", Value = 0.03, To = 0.6, Duration = 0.2 },
		{ At = 0, Phase = "Active", Kind = "Glass", Target = "Paw", Point = WINDOW, Value = 1.3 },
		{ At = 0, Phase = "Active", Kind = "Shake", Target = "Door", Value = 1.6 },
		{ At = 0, Phase = "Active", Kind = "Blur", Value = 6, To = 0, Duration = 0.8 },
		{ At = 0, Phase = "Active", Kind = "Grade", Target = "Red", Value = 0.75, To = 0.6, Duration = 1 },
		{ At = 0.6, Phase = "Active", Kind = "Glass", Target = "Paw", Point = WINDOW, Value = 1 },
		{ At = 0.6, Phase = "Active", Kind = "Shake", Target = "Door" },
		{ At = 1.3, Phase = "Active", Kind = "Glass", Target = "Paw", Point = WINDOW, Value = 1.1 },
		{ At = 1.3, Phase = "Active", Kind = "Shake", Target = "Door", Value = 1.2 },
		{ At = 1.5, Phase = "Active", Kind = "Whispers", Target = "red_fog_hold", Value = 1.2, To = 2.6, Duration = 4, Where = "Inside" },
		{ At = 1.5, Phase = "Active", Kind = "Whispers", Target = "red_fog_outside", Value = 2, To = 3, Duration = 4, Where = "Outside" },
		{ At = 1.5, Phase = "Active", Kind = "Heartbeat", Value = 150, To = 170, Duration = 4 },
		-- the cameras: the one at the queue walks up to the glass during the pause
		{ At = 2, Phase = "Active", Kind = "Actor", Target = SHAPE, To = WINDOW, Duration = 5, Seen = "Cameras" },
		{ At = 5.5, Phase = "Active", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 5.6, Phase = "Active", Kind = "Silence", Value = 0.6, To = 0.05, Duration = 0.4 },
		{ At = 6, Phase = "Active", Kind = "Heartbeat", Value = 120, To = 120, Duration = 1 },
		{ At = 6, Phase = "Active", Kind = "Vignette", Value = 0.35, To = 0.48, Duration = 2.5 },
		-- the biggest blow
		{ At = 8.5, Phase = "Active", Kind = "Silence", Value = 0.05, To = 0.6, Duration = 0.1 },
		{ At = 8.5, Phase = "Active", Kind = "Glass", Target = "Paw", Point = WINDOW, Value = 1.6 },
		{ At = 8.5, Phase = "Active", Kind = "Shake", Target = "Jolt", Value = 1.5 },
		{ At = 8.5, Phase = "Active", Kind = "Fov", Value = -5, To = 0, Duration = 0.8 },
		{ At = 8.5, Phase = "Active", Kind = "Blur", Value = 10, To = 0, Duration = 1 },
		{ At = 8.5, Phase = "Active", Kind = "Lights", Target = "Flicker", Duration = 0.6 },
		{ At = 8.6, Phase = "Active", Kind = "Heartbeat", Value = 170, To = 170, Duration = 2 },
		{ At = 9, Phase = "Active", Kind = "Glass", Target = "Paw", Point = WINDOW, Value = 1.2 },
		{ At = 9, Phase = "Active", Kind = "Shake", Target = "Door", Value = 1.4 },
		{ At = 9.4, Phase = "Active", Kind = "Glass", Target = "Paw", Point = WINDOW, Value = 1.2 },
		{ At = 9.5, Phase = "Active", Kind = "Whispers", Target = "red_fog_hold", Value = 3, To = 3, Duration = 2, Where = "Inside" },
		{ At = 9.5, Phase = "Active", Kind = "Whispers", Target = "red_fog_outside", Value = 3, To = 3, Duration = 2, Where = "Outside" },
		{ At = 11.5, Phase = "Active", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 11.5, Phase = "Active", Kind = "Heartbeat", Value = 150, To = 100, Duration = 3 },
		{ At = 11.5, Phase = "Active", Kind = "Vignette", Value = 0.48, To = 0.35, Duration = 2 },
		-- R10, it held (Resolved): the fog recedes, the shape on the cameras backs off into it, colour and sound come back
		{ At = 0, Phase = "Resolved", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Silence", Value = 0.6, To = 1, Duration = 3 },
		{ At = 0, Phase = "Resolved", Kind = "Blur", Value = 0, To = 0, Duration = 0 },
		{ At = 0.3, Phase = "Resolved", Kind = "Actor", Target = SHAPE, To = "TBL-3", Duration = 4, Value = 1 },
		{ At = 0.4, Phase = "Resolved", Kind = "Silhouette", Target = "Leave", Text = "*", To = "TRL@0,0,62", Duration = 4.5 },
		{ At = 0.5, Phase = "Resolved", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0.5, Phase = "Resolved", Kind = "Grade", Value = 0.6, To = 0, Duration = 4 },
		{ At = 0.5, Phase = "Resolved", Kind = "Vignette", Value = 0.35, To = 0, Duration = 3 },
		{ At = 1, Phase = "Resolved", Kind = "Sound", Target = "breath_held", Value = 0.7 },
		{ At = 1.5, Phase = "Resolved", Kind = "Cinema", Value = 0, Duration = 1.2 },
		-- someone opened / was outside (Failed)
		{ At = 0, Phase = "Failed", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Failed", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 0, Phase = "Failed", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Blur", Value = 14, To = 0, Duration = 1.4 },
		{ At = 0, Phase = "Failed", Who = "Safe", Kind = "Blur", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Failed", Who = "Safe", Kind = "Glass", Target = "Paw", Point = WINDOW, Value = 1.4 },
		{ At = 0, Phase = "Failed", Who = "Safe", Kind = "Shake", Target = "Door", Value = 1.2 },
		{ At = 0.3, Phase = "Failed", Kind = "Actor", Target = SHAPE, To = "TBL-3", Duration = 4, Value = 1 },
		{ At = 1.2, Phase = "Failed", Kind = "Silhouette", Target = "Leave", Text = "*", To = "TRL@0,0,62", Duration = 3.5 },
		{ At = 1, Phase = "Failed", Kind = "Grade", Value = 0.8, To = 0, Duration = 4 },
		{ At = 1, Phase = "Failed", Kind = "Vignette", Value = 0.5, To = 0, Duration = 3 },
		{ At = 3, Phase = "Failed", Kind = "Cinema", Value = 0, Duration = 1 },
	},
}

return scene
