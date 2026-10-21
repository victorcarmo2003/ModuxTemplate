--!strict
-- ANM-019 the roof walker, the camera layer and the "Fora" (TASK-589; design/horror-cinematic.md §3.11, §11.2). Extend: the
-- walk, the stain, the drops and the drop on whoever looked up stay as they are (init + Effects/ANM-019).
--   Inside: the security cameras show what the ceiling hides - the shape STANDING on the roof, walking its line, and
--     standing still over the shop when the steps stop (R4). Never seen with the bare eye from inside.
--   Outside: he sees it against the sky with his own eyes, walking to the edge of the roof on his side; the words say
--     get inside and don't look up (looking up still counts: the rule reads every player's gaze).
-- Timing follows Rules/ANM-019: Signal = OmenFor 3 s (the landing), Active = WalkFor 16 s (over every head at ~7 s, still
-- 2.5 s), Failed / Resolved = LeaveFor 5 s. Points read off TRL (roof top ~16 studs; the shop spans x -62..-25).
local Types = require(script.Parent.Parent.Types)

const ROOF_WEST = "TRL@-17,16.5,-6"
const ROOF_MID = "TRL@0,16.5,-1"
const ROOF_EAST = "TRL@15,16.5,4"
const ROOF_EDGE = "TRL@0,16.5,10" -- the street edge, over the front glass
const OFF_ROOF = "TRL@24,16.5,14" -- where it jumps off (it fades as it goes)

const scene: Types.Scene = {
	Key = "anm_019_roof_walker",
	Name = "The roof walker (cameras, outside)",
	Extend = true,
	Steps = {
		-- the landing: on the feed it is already up there, crouched at the west end
		{ At = 0, Phase = "Signal", Where = "Inside", Kind = "Silhouette", Target = "Arrive", Point = ROOF_WEST, To = ROOF_WEST, Duration = 0.5, Value = 0.7, Seen = "Cameras" },
		{ At = 0, Phase = "Signal", Where = "Outside", Kind = "Silhouette", Target = "Arrive", Point = ROOF_WEST, To = ROOF_WEST, Duration = 0.5, Value = 0.7 },
		{ At = 0.5, Phase = "Signal", Where = "Outside", Kind = "Text", Text = "SOMETHING IS ON THE ROOF. GET INSIDE!", Duration = 2.5 },
		{ At = 0.5, Phase = "Signal", Where = "Outside", Kind = "Heartbeat", Value = 85, To = 120, Duration = 3 },
		-- the walk: to the middle (the steps stand still there at ~7 s), then on to the far end
		{ At = 0, Phase = "Active", Where = "Inside", Kind = "Silhouette", Target = "Arrive", Point = ROOF_WEST, To = ROOF_MID, Duration = 7, Value = 0.7, Seen = "Cameras" },
		{ At = 9.5, Phase = "Active", Where = "Inside", Kind = "Silhouette", Target = "Arrive", Point = ROOF_MID, To = ROOF_EAST, Duration = 6.5, Value = 0.7, Seen = "Cameras" },
		-- outside it comes to the edge on his side instead, and looks down at him
		{ At = 0, Phase = "Active", Where = "Outside", Kind = "Silhouette", Target = "Arrive", Point = ROOF_WEST, To = ROOF_EDGE, Duration = 7, Value = 0.7 },
		{ At = 1, Phase = "Active", Where = "Outside", Kind = "Whispers", Target = "roof_outside", Value = 0.5, To = 2.4, Duration = 8 },
		{ At = 7, Phase = "Active", Where = "Outside", Kind = "Fov", Value = 3, To = 0, Duration = 2.5 },
		{ At = 7, Phase = "Active", Where = "Outside", Kind = "Heartbeat", Value = 140, To = 165, Duration = 3 },
		{ At = 9.5, Phase = "Active", Where = "Outside", Kind = "Silhouette", Target = "Arrive", Point = ROOF_EDGE, To = ROOF_EAST, Duration = 6.5, Value = 0.7 },
		-- gone: off the far end, fading
		{ At = 0, Phase = "Resolved", Kind = "Silhouette", Target = "Leave", To = OFF_ROOF, Duration = 1.6 },
		{ At = 0, Phase = "Failed", Kind = "Silhouette", Target = "Leave", To = OFF_ROOF, Duration = 0.8 },
		{ At = 0, Phase = "Resolved", Where = "Outside", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0, Phase = "Failed", Where = "Outside", Kind = "Heartbeat", Value = 0, To = 0 },
	},
	Words = {
		roof_outside = {
			"GET INSIDE",
			"GET INSIDE",
			"DON'T LOOK UP",
			"IT'S ON THE ROOF",
			"it can see you from up there",
			"eyes down... walk",
		},
	},
}

return scene
