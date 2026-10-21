--!strict
-- ANM-008 The long car - the blackout's bar (TASK-588; design/horror-cinematic.md §3.4, §11.1, §11.2). Replaces the scene
-- of HorrorScenes/init (TASK-490). Fitted to Rules/ANM-008 as before: Signal = it rolls down the drive-thru lane (5.6 s),
-- floors it (1.8 s), brakes at the window (8.2 s) and waits BeamDelay 5 s; Active = the high beam, StayFor 6 s (whoever
-- is not behind a shut window pays); then Resolved / Failed as it backs out. The car, its engine, beam, horn and the
-- blinding of the caught player are Effects/ANM-008.
-- What the bar adds: the lights flinch and the view jolts as it turns in (R1); colour drains (R2); its headlights sweep
-- the ceiling through the drive-thru window as it rushes in (the signature); on the security cameras the car has no
-- driver (Effects/ANM-008: the driver is seen with the bare eye only) (R4); braked, two seconds of nothing, then one
-- knock on the glass (R8); the high beam blinds whoever is looking at the window (Glare Flash) and the shutter is beaten,
-- harder each time, while it waits (R9); as it leaves its lights sweep back across the room (R10).
-- Outside (§3.0): the beam finds whoever is on the lane; the words say get off the road.
-- Every number PROVISIONAL until the owner's Play (Q-397).
local Types = require(script.Parent.Parent.Types)

type Scene = Types.Scene

const WINDOW = "DT-WIN" -- the drive-thru window + its shutter (east wall)
const STOP = "DT-STOP" -- the car at the window, on the lane

const scene: Scene = {
	Key = "anm_008_long_car",
	Name = "The long car",
	Live = true,
	Words = {
		car_outside = {
			"GET OFF THE ROAD",
			"GET OFF THE ROAD",
			"GET INSIDE",
			"GET INSIDE",
			"it sees you...",
			"don't stand in the light",
		},
	},
	Steps = {
		-- R1: it turns into the lane - the lights flinch, the view jolts, a long low horn
		{ At = 0.2, Phase = "Signal", Kind = "Lights", Target = "Flicker", Duration = 0.8 },
		{ At = 0.3, Phase = "Signal", Kind = "Shake", Target = "Step", Value = 1.5 },
		{ At = 0.3, Phase = "Signal", Kind = "Fov", Value = -2, To = 0, Duration = 0.8 },
		{ At = 3, Phase = "Signal", Kind = "Sound", Target = "car_horn_long", Value = 0.7 },
		{ At = 0.5, Phase = "Signal", Kind = "Cinema", Value = 0.1, Duration = 1.5 },
		-- R7: the words (shut the drive-thru), the heart racing with the engine, the edges, the cold
		{ At = 0.5, Phase = "Signal", Kind = "Whispers", Target = "car", Value = 0.3, To = 2.6, Duration = 8, Where = "Inside" },
		{ At = 0.5, Phase = "Signal", Kind = "Whispers", Target = "car_outside", Value = 0.5, To = 2.8, Duration = 8, Where = "Outside" },
		{ At = 0.5, Phase = "Signal", Kind = "Heartbeat", Value = 70, To = 150, Duration = 8, Where = "Inside" },
		{ At = 0.5, Phase = "Signal", Kind = "Heartbeat", Value = 85, To = 160, Duration = 8, Where = "Outside" },
		{ At = 0.5, Phase = "Signal", Kind = "Vignette", Value = 0, To = 0.35, Duration = 8 },
		{ At = 0.5, Phase = "Signal", Kind = "Grade", Target = "Cold", Value = 0, To = 0.4, Duration = 8 },
		-- the signature: it floors it and its headlights sweep the ceiling through the drive-thru window
		{ At = 5.6, Phase = "Signal", Kind = "Fov", Value = 2, To = 0, Duration = 1.8 },
		{ At = 5.4, Phase = "Signal", Kind = "Glare", Target = "Sweep", Point = STOP, To = WINDOW, Value = 50, Duration = 2.6 },
		-- it brakes in front of the window: jolt, then nothing but the engine
		{ At = 8.2, Phase = "Signal", Kind = "Shake", Target = "Jolt" },
		{ At = 8.4, Phase = "Signal", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 8.4, Phase = "Signal", Kind = "Silence", Value = 1, To = 0.08, Duration = 0.6 },
		{ At = 8.6, Phase = "Signal", Kind = "Sound", Target = "breath_held" },
		{ At = 8.6, Phase = "Signal", Kind = "Heartbeat", Value = 150, To = 170, Duration = 4.6 }, -- BeamDelay 5 (2026-10-19)
		-- R8: two seconds of nothing, then one knock on the glass, then the shutter tried
		{ At = 10.6, Phase = "Signal", Kind = "Glass", Target = "Knock", Point = WINDOW, Value = 2 },
		{ At = 11.8, Phase = "Signal", Kind = "Glass", Target = "Rattle", Point = WINDOW, Value = 0.6, Duration = 0.4 },
		{ At = 11.8, Phase = "Signal", Kind = "Vignette", Value = 0.35, To = 0.42, Duration = 1.4 },
		-- R9: the high beam - whoever looks at the window is blinded, the room goes white
		{ At = 0, Phase = "Active", Kind = "Shake", Target = "Jolt" },
		{ At = 0, Phase = "Active", Kind = "Fov", Value = -4, To = 0, Duration = 0.7 },
		{ At = 0, Phase = "Active", Kind = "Silence", Value = 0.08, To = 1, Duration = 0.3 },
		{ At = 0, Phase = "Active", Kind = "Glare", Target = "Flash", Point = WINDOW, Value = 10, Duration = 1.2, Where = "Inside" },
		{ At = 0, Phase = "Active", Kind = "Glare", Target = "Flash", Point = STOP, Value = 12, Duration = 1.6, Where = "Outside" },
		{ At = 0, Phase = "Active", Kind = "Blur", Value = 3, To = 0, Duration = 2.5 },
		{ At = 0, Phase = "Active", Kind = "Grade", Target = "Cold", Value = 0.85, To = 0.45, Duration = 2 },
		{ At = 0, Phase = "Active", Kind = "Vignette", Value = 0.42, To = 0.5, Duration = 0.4 },
		{ At = 0.4, Phase = "Active", Kind = "Heartbeat", Value = 150, To = 100, Duration = 5.5 },
		{ At = 0.6, Phase = "Active", Kind = "Whispers", Target = "car_hold", Value = 0.5, To = 0.5, Duration = 5, Where = "Inside" },
		{ At = 0.6, Phase = "Active", Kind = "Whispers", Target = "car_outside", Value = 1.5, To = 2.5, Duration = 5, Where = "Outside" },
		-- the shutter beaten while it waits, harder each time
		{ At = 1.5, Phase = "Active", Kind = "Glass", Target = "Rattle", Point = WINDOW, Value = 1, Duration = 0.5 },
		{ At = 1.5, Phase = "Active", Kind = "Shake", Target = "Door", Value = 0.6 },
		{ At = 3.2, Phase = "Active", Kind = "Glass", Target = "Rattle", Point = WINDOW, Value = 1.4, Duration = 0.6 },
		{ At = 3.2, Phase = "Active", Kind = "Shake", Target = "Door", Value = 0.8 },
		{ At = 4.7, Phase = "Active", Kind = "Glass", Target = "Rattle", Point = WINDOW, Value = 1.8, Duration = 0.7 },
		{ At = 4.7, Phase = "Active", Kind = "Shake", Target = "Door", Value = 1 },
		{ At = 4.7, Phase = "Active", Kind = "Fov", Value = -2, To = 0, Duration = 0.6 },
		-- R10: it backs out, its lights sweep back across the ceiling; colour and sound come back
		{ At = 0, Phase = "Resolved", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Blur", Value = 0, To = 0, Duration = 0 },
		{ At = 0.5, Phase = "Resolved", Kind = "Glare", Target = "Sweep", Point = STOP, To = WINDOW, Value = -50, Duration = 3 },
		{ At = 0.6, Phase = "Resolved", Kind = "Sound", Target = "breath_held" },
		{ At = 0.4, Phase = "Resolved", Kind = "Grade", Value = 0.45, To = 0, Duration = 2 },
		{ At = 0.5, Phase = "Resolved", Kind = "Vignette", Value = 0.5, To = 0, Duration = 2 },
		{ At = 1.5, Phase = "Resolved", Kind = "Cinema", Value = 0, Duration = 1 },
		-- Failed: a car door opens out there; the caught one is blinded (Effects), the others get one more flash
		{ At = 0, Phase = "Failed", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Failed", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0, Phase = "Failed", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 0, Phase = "Failed", Kind = "Sound", Target = "door_creak", Point = STOP, Value = 0.8 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Grade", Target = "Red", Value = 0.85, To = 0, Duration = 2.8 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Blur", Value = 12, To = 0, Duration = 1.4 },
		{ At = 0, Phase = "Failed", Who = "Safe", Kind = "Glare", Target = "Flash", Point = WINDOW, Value = 6, Duration = 1 },
		{ At = 0.5, Phase = "Failed", Kind = "Vignette", Value = 0.5, To = 0, Duration = 2.5 },
		{ At = 1.5, Phase = "Failed", Who = "Safe", Kind = "Grade", Value = 0.45, To = 0, Duration = 2.5 },
		{ At = 1.5, Phase = "Failed", Kind = "Glare", Target = "Sweep", Point = STOP, To = WINDOW, Value = -50, Duration = 3 },
		{ At = 2.5, Phase = "Failed", Kind = "Cinema", Value = 0, Duration = 1 },
	},
}

return scene
