--!strict
-- ANM-005 The Raincoat Lady, the blackout's bar (TASK-587; design/horror-cinematic.md §3.2, §11.1 R1-R10, §11.2).
-- Anchored to the actor's record (Rules/ANM-005: SERVE her = Resolved; refusing her, or her patience running out =
-- Failed). She is not a threat: the dread is the deadline you can see. Signature: a PUDDLE that grows from where she
-- stands to the edge of the counter (Prop Puddle), the drip that stops dead in the silence, the hood lifted (only the
-- mouth), on the security cameras she is DRY (the water is Seen "Eyes") and she looks into the lens; on a failure the
-- thunder is close and the water runs to whoever failed her. And she never stops staring (owner 2026-10-19): from the
-- moment she comes in her head turns slowly after this client's camera and stays on it, also while she walks off
-- (Pose Turn, no hold; each client sees her staring at its own player). Presentation only (T10). Every number PROVISIONAL until
-- the owner's Play; the drip is `splash` until drip_loop has an Id (sound-list.md).
local Types = require(script.Parent.Parent.Types)

const COUNTER = "Q1" -- the order spot at the counter (where she stands)
const DRIP = "splash" -- stands in for drip_loop (sound-list.md, TASK-587)
const DRIP_FROM = 2 -- s into Active
const DRIP_TO = 51.5 -- the drip stops for the silence
const DRIP_GAP = 2.4 -- s between two drops

const scene: Types.Scene = {
	Key = "anm_005_raincoat_lady",
	Name = "The Raincoat Lady",
	Live = true,
	Words = {
		raincoat_outside = {
			"SHE'S WAITING",
			"SHE'S WAITING",
			"GET INSIDE",
			"SERVE HER",
			"she's looking at you...",
			"it isn't raining...",
		},
	},
	Steps = {
		-- R1: thunder far away as she comes in dripping, a jolt, the view pulses
		{ At = 0, Phase = "Active", Kind = "Sound", Target = "thunder", Value = 0.45 },
		{ At = 0, Phase = "Active", Kind = "Shake", Target = "Jolt", Value = 0.4 },
		{ At = 0, Phase = "Active", Kind = "Fov", Value = -2, To = 0, Duration = 0.8 },
		{ At = 1, Phase = "Active", Kind = "Cinema", Value = 0.07, Duration = 1.5 },
		-- R2: the puddle, the visible deadline: under her, then to the edge of the counter (gone on the cameras)
		{ At = 2, Phase = "Active", Kind = "Prop", Target = "Puddle", Point = COUNTER, Value = 0.3, To = 1.4, Duration = 25, Seen = "Eyes" },
		{ At = 27, Phase = "Active", Kind = "Prop", Target = "Puddle", Point = COUNTER, To = 2.6, Duration = 25, Seen = "Eyes" },
		-- R5: the hint (serve her, don't shut her out)
		{ At = 4, Phase = "Active", Kind = "Whispers", Target = "raincoat", Value = 0.3, To = 0.8, Duration = 10, Where = "Inside" },
		{ At = 4, Phase = "Active", Kind = "Whispers", Target = "raincoat_outside", Value = 0.3, To = 0.9, Duration = 10, Where = "Outside" },
		{ At = 14, Phase = "Active", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		-- she stares at the player and never stops (owner 2026-10-19): a slow head turn, held until the run ends
		{ At = 0.5, Phase = "Active", Kind = "Pose", Target = "Turn", Duration = 2.5 },
		-- R4: on the cameras she is dry and she turns to the lens, the hood a little up
		{ At = 6, Phase = "Active", Kind = "Pose", Target = "Turn", Duration = 1.6, Seen = "Cameras" },
		{ At = 6, Phase = "Active", Kind = "Pose", Target = "Lift", Value = 14, Duration = 2, Seen = "Cameras" },
		-- R7: the colour drains and the edges creep in with the deadline
		{ At = 5, Phase = "Active", Kind = "Vignette", Value = 0, To = 0.12, Duration = 25 },
		{ At = 5, Phase = "Active", Kind = "Grade", Target = "Cold", Value = 0, To = 0.25, Duration = 25 },
		{ At = 20, Phase = "Active", Kind = "Cinema", Value = 0, Duration = 1.5 },
		-- half her patience: thunder closer, the lamps stutter, the heart and the words come back stronger
		{ At = 30, Phase = "Active", Kind = "Sound", Target = "thunder", Value = 0.7 },
		{ At = 30, Phase = "Active", Kind = "Lights", Target = "Flicker", Duration = 0.5 },
		{ At = 27, Phase = "Active", Kind = "Heartbeat", Value = 80, To = 130, Duration = 25 },
		{ At = 30, Phase = "Active", Kind = "Vignette", Value = 0.12, To = 0.3, Duration = 21 },
		{ At = 30, Phase = "Active", Kind = "Whispers", Target = "raincoat", Value = 0.5, To = 1.4, Duration = 20, Where = "Inside" },
		{ At = 30, Phase = "Active", Kind = "Whispers", Target = "raincoat_outside", Value = 0.5, To = 1.4, Duration = 20, Where = "Outside" },
		{ At = 40, Phase = "Active", Kind = "Fov", Value = 1, To = 0, Duration = 10 },
		{ At = 48, Phase = "Active", Kind = "Cinema", Value = 0.08, Duration = 2 },
		-- R8: the drip stops, the heart stops, the room goes quiet; she lifts the hood (only the mouth)
		{ At = 50, Phase = "Active", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 51.5, Phase = "Active", Kind = "Silence", Value = 1, To = 0.3, Duration = 0.8 },
		{ At = 52, Phase = "Active", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 52, Phase = "Active", Kind = "Pose", Target = "Lift", Value = 20, Duration = 2 },
		-- R9: thunder overhead, the lights jump, the water surges
		{ At = 54, Phase = "Active", Kind = "Sound", Target = "thunder", Value = 1.1 },
		{ At = 54, Phase = "Active", Kind = "Lights", Target = "Flicker", Duration = 0.6 },
		{ At = 54, Phase = "Active", Kind = "Shake", Target = "Jolt" },
		{ At = 54, Phase = "Active", Kind = "Blur", Value = 6, To = 0, Duration = 1 },
		{ At = 54, Phase = "Active", Kind = "Silence", Value = 0.3, To = 1, Duration = 1.5 },
		{ At = 54, Phase = "Active", Kind = "Heartbeat", Value = 130, To = 150, Duration = 6 },
		{ At = 54, Phase = "Active", Kind = "Prop", Target = "Puddle", Point = COUNTER, To = 3.2, Duration = 2, Seen = "Eyes" },
		-- Fora (§3.0): she stands out in the rain on the drive-thru lane, looking at him
		{ At = 30, Phase = "Active", Kind = "Lantern", Target = "Eyes", Point = "DT-STOP", Duration = 1.5, Where = "Outside" },

		-- Resolved (served): the drip again, softly; the puddle dries; R10 in steps
		{ At = 0, Phase = "Resolved", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Blur", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Prop", Target = "Puddle", Point = COUNTER, To = 0, Duration = 10, Seen = "Eyes" },
		{ At = 0.5, Phase = "Resolved", Kind = "Sound", Target = DRIP, Point = COUNTER, Value = 0.2 },
		{ At = 0.4, Phase = "Resolved", Kind = "Grade", Value = 0.25, To = 0, Duration = 2.5 },
		{ At = 0.6, Phase = "Resolved", Kind = "Vignette", Value = 0.3, To = 0, Duration = 2 },
		{ At = 0.8, Phase = "Resolved", Kind = "Sound", Target = "breath_held" },
		{ At = 1, Phase = "Resolved", Kind = "Cinema", Value = 0, Duration = 1 },

		-- Failed (refused, or her patience ran out): thunder close, the lights, the water runs to who failed her
		{ At = 0, Phase = "Failed", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Failed", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0, Phase = "Failed", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 0, Phase = "Failed", Kind = "Sound", Target = "thunder", Value = 1.2 },
		{ At = 0, Phase = "Failed", Kind = "Lights", Target = "Flicker", Duration = 0.8 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Prop", Target = "Puddle", Point = COUNTER, To = "Player", Value = 1, Duration = 1.2 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Sound", Target = DRIP, Value = 0.8 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Grade", Target = "Red", Value = 0.85, To = 0, Duration = 2.8 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Blur", Value = 12, To = 0, Duration = 1.4 },
		{ At = 0, Phase = "Failed", Who = "Safe", Kind = "Shake", Target = "Jolt" },
		{ At = 0.8, Phase = "Failed", Kind = "Vignette", Value = 0.4, To = 0, Duration = 3 },
		{ At = 1.5, Phase = "Failed", Who = "Safe", Kind = "Grade", Value = 0.25, To = 0, Duration = 2 },
		{ At = 2, Phase = "Failed", Kind = "Cinema", Value = 0, Duration = 1 },
	},
}

-- R2/R7: the drip at the counter, a drop every DRIP_GAP s, louder as the deadline gets near (generated, not typed)
do
	local t = DRIP_FROM
	while t < DRIP_TO do
		const share = (t - DRIP_FROM) / (DRIP_TO - DRIP_FROM)
		const drop: Types.Step = { At = t, Phase = "Active", Kind = "Sound", Target = DRIP, Point = COUNTER, Value = 0.2 + 0.45 * share }
		table.insert(scene.Steps, drop)
		t += DRIP_GAP
	end
end

return scene
