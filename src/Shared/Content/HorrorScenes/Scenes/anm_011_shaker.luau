--!strict
-- ANM-011 The shaker, the blackout's bar (TASK-587; design/horror-cinematic.md §3.6, §11.1 R1-R10, §11.2). Anchored
-- to the actor's record (Rules/ANM-011, TASK-591: serve him a plain hot dog = Resolved; shut the window on him or
-- serve a topping = Failed; no deadline). The v3
-- review found the body's tremor unreadable on a phone (Q-389), so the ROOM shakes: the bottles and cups by the
-- counter rattle (Prop Shake), the lamp over it swings (Prop Sway), a micro tremor of the camera nearby. Then
-- everything stops at once, one last jump of the whole counter; served plain, the shaking dies out; the error starts
-- with a hard blow on the shutter. Owner 2026-10-21 (gameplay review): the look up and the step on the roof are gone -
-- they are the roof walker's sign (ANM-019, "don't look up") and told the player the wrong rule. Presentation only (T10). Every number PROVISIONAL until the owner's Play; the rattle is `plate_put`
-- until cup_rattle has an Id (sound-list.md).
local Types = require(script.Parent.Parent.Types)

const COUNTER = "Q1"
const OUTSIDE = "SCENE-WINDOW-EYES" -- outside the service window
const RATTLE = "plate_put" -- stands in for cup_rattle (sound-list.md, TASK-587)
const RATTLE_TO = 8 -- s: everything stops at once
const TREMOR_FROM = 4 -- s: the micro tremor of the camera
const TREMOR_GAP = 0.45

const scene: Types.Scene = {
	Key = "anm_011_shaker",
	Name = "The shaker",
	Live = true,
	Words = {
		-- TASK-591 (owner 2026-10-19): he is starving, not a monster - serve him plain, never shut him out
		shaker_close = {
			"HE'S JUST HUNGRY",
			"HE'S JUST HUNGRY",
			"SERVE HIM PLAIN",
			"NOTHING ON IT",
			"DON'T SHUT HIM OUT",
			"everything is shaking...",
			"just a plain one...",
		},
	},
	Steps = {
		-- R1: a sting, a jolt, the view pulses; R2: the bottles start to rattle
		{ At = 0, Phase = "Active", Kind = "Sound", Target = "horror_sting", Value = 0.35 },
		{ At = 0, Phase = "Active", Kind = "Shake", Target = "Jolt", Value = 0.4 },
		{ At = 0, Phase = "Active", Kind = "Fov", Value = -2, To = 0, Duration = 0.7 },
		{ At = 0, Phase = "Active", Kind = "Prop", Target = "Shake", Point = COUNTER, Value = 0.025, To = 7, Duration = 3, Seen = "Eyes" },
		{ At = 1, Phase = "Active", Kind = "Cinema", Value = 0.08, Duration = 1.5 },
		-- R5: the hint
		{ At = 2, Phase = "Active", Kind = "Whispers", Target = "shaker_close", Value = 0.3, To = 1.2, Duration = 6, Where = "Inside" },
		{ At = 2, Phase = "Active", Kind = "Whispers", Target = "outside", Value = 0.3, To = 1.1, Duration = 6, Where = "Outside" },
		-- R7: the shaking grows, the lamp swings, the heart, the colour goes sick
		{ At = 3, Phase = "Active", Kind = "Prop", Target = "Shake", Point = COUNTER, Value = 0.05, To = 8, Duration = 5, Seen = "Eyes" },
		{ At = 4, Phase = "Active", Kind = "Prop", Target = "Sway", Point = COUNTER, Value = 5, To = 14, Duration = 4, Seen = "Eyes" },
		{ At = 4, Phase = "Active", Kind = "Heartbeat", Value = 75, To = 120, Duration = 4 },
		{ At = 4, Phase = "Active", Kind = "Vignette", Value = 0, To = 0.25, Duration = 4 },
		{ At = 4, Phase = "Active", Kind = "Grade", Target = "Sick", Value = 0, To = 0.28, Duration = 4 },
		{ At = 5, Phase = "Active", Kind = "Fov", Value = 1.5, To = 0, Duration = 3 },
		-- R8: it stops dead - the props, the words, the heart, the room
		{ At = 8, Phase = "Active", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 8, Phase = "Active", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 8, Phase = "Active", Kind = "Silence", Value = 1, To = 0.15, Duration = 0.15 },
		-- R9: the whole counter jumps once, the lights with it
		{ At = 10, Phase = "Active", Kind = "Prop", Target = "Shake", Point = COUNTER, Value = 0.12, To = 8, Duration = 0.6, Seen = "Eyes" },
		{ At = 10, Phase = "Active", Kind = "Sound", Target = "horror_sting", Value = 0.7 },
		{ At = 10, Phase = "Active", Kind = "Sound", Target = RATTLE, Point = COUNTER, Value = 1 },
		{ At = 10, Phase = "Active", Kind = "Lights", Target = "Flicker", Duration = 0.3 },
		{ At = 10, Phase = "Active", Kind = "Shake", Target = "Jolt" },
		{ At = 10, Phase = "Active", Kind = "Blur", Value = 5, To = 0, Duration = 1 },
		{ At = 10, Phase = "Active", Kind = "Silence", Value = 0.15, To = 1, Duration = 2 },
		{ At = 10.5, Phase = "Active", Kind = "Heartbeat", Value = 105, To = 110, Duration = 18 },
		-- the work goes on
		{ At = 16, Phase = "Active", Kind = "Cinema", Value = 0, Duration = 1.5 },
		{ At = 16, Phase = "Active", Kind = "Vignette", Value = 0.25, To = 0.08, Duration = 4 },
		{ At = 16, Phase = "Active", Kind = "Grade", Value = 0.28, To = 0.1, Duration = 4 },
		{ At = 30, Phase = "Active", Kind = "Heartbeat", Value = 0, To = 0 },
		-- Fora (§3.0): the tremor comes through the ground, the tables by him shake
		{ At = 1, Phase = "Active", Kind = "Prop", Target = "Shake", Point = "Player", Value = 0.03, To = 8, Duration = 7, Where = "Outside" },

		-- Resolved (TASK-591: served plain): he eats, the shaking dies out, the room breathes again (R10 in steps)
		{ At = 0, Phase = "Resolved", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Prop", Target = "Shake", Point = COUNTER, Value = 0.015, To = 8, Duration = 1.2 },
		{ At = 0.4, Phase = "Resolved", Kind = "Silence", Value = 0.6, To = 1, Duration = 2 },
		{ At = 1, Phase = "Resolved", Kind = "Sound", Target = "breath_held" },
		{ At = 0.6, Phase = "Resolved", Kind = "Grade", Value = 0.28, To = 0, Duration = 2.5 },
		{ At = 0.6, Phase = "Resolved", Kind = "Vignette", Value = 0.25, To = 0, Duration = 2 },
		{ At = 1, Phase = "Resolved", Kind = "Cinema", Value = 0, Duration = 1 },

		-- Failed (window shut on him, or a hot dog with a topping): a hard blow on the shutter, then the vibrating face
		-- (Kit/Jumpscare on the cue), red + blur on who did it
		{ At = 0, Phase = "Failed", Kind = "Sound", Target = "window_slam", Point = OUTSIDE, Value = 1.2 },
		{ At = 0, Phase = "Failed", Kind = "Fov", Value = -3, To = 0, Duration = 0.6 },
		-- Failed (its order taken): the vibrating face (Kit/Jumpscare on the cue), red + blur on who did it
		{ At = 0, Phase = "Failed", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Failed", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0, Phase = "Failed", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 0, Phase = "Failed", Kind = "Prop", Target = "Shake", Point = COUNTER, Value = 0.1, To = 8, Duration = 1 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Grade", Target = "Red", Value = 0.85, To = 0, Duration = 2.8 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Blur", Value = 12, To = 0, Duration = 1.4 },
		{ At = 0, Phase = "Failed", Who = "Safe", Kind = "Shake", Target = "Jolt" },
		{ At = 0.8, Phase = "Failed", Kind = "Vignette", Value = 0.4, To = 0, Duration = 3 },
		{ At = 1.5, Phase = "Failed", Who = "Safe", Kind = "Grade", Value = 0.28, To = 0, Duration = 2 },
		{ At = 2, Phase = "Failed", Kind = "Cinema", Value = 0, Duration = 1 },
	},
}

-- R2/R7 (generated, not typed): the rattle on the counter, quicker and louder until it stops dead at RATTLE_TO; and
-- the micro tremor of the camera (Step profile, small) while the room shakes hardest
do
	local t = 0
	while t < RATTLE_TO do
		const share = t / RATTLE_TO
		const rattle: Types.Step = { At = t, Phase = "Active", Kind = "Sound", Target = RATTLE, Point = COUNTER, Value = 0.25 + 0.5 * share }
		table.insert(scene.Steps, rattle)
		t += 0.6 - 0.35 * share
	end
	t = TREMOR_FROM
	while t < RATTLE_TO do
		const tremor: Types.Step = { At = t, Phase = "Active", Kind = "Shake", Target = "Step", Value = 0.6, Where = "Inside" }
		table.insert(scene.Steps, tremor)
		t += TREMOR_GAP
	end
end

return scene
