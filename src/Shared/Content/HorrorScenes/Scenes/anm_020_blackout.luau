--!strict
-- ANM-020 the blackout, the layer for whoever is OUTSIDE the shop when the power goes (TASK-589; design/horror-cinematic.md
-- §3.0, §11.2: the reference scene was the only one without its "Fora"). Extend: the inside scene stays as it is (init).
-- Outside, the street is the dark: the words say get inside, the heart starts sooner and higher (+15 BPM), the white
-- light around him is the only light in the street, and when the Walker comes for the pantry door a tall shape stands
-- at the shop's front glass between him and the door, watching him, and goes when the dark ends.
-- Points: the street front is read off TRL (the shop spans x -62..-25, z -12..17; the street is z > 17).
local Types = require(script.Parent.Parent.Types)

const FRONT_FAR = "TRL@26,0,26" -- down the street, east of the patio
const FRONT_GLASS = "TRL@6,0,19" -- just outside the front glass

const scene: Types.Scene = {
	Key = "anm_020_blackout",
	Name = "The blackout (outside)",
	Extend = true,
	Steps = {
		-- the power cuts: the street lamps of the shop die with it; he only has his own light
		{ At = 0.2, Phase = "Active", Where = "Outside", Kind = "Lantern", Target = "Glow", Value = 5.6, To = 0.9, Duration = 0.6 },
		{ At = 1, Phase = "Active", Where = "Outside", Kind = "Text", Text = "THE POWER IS OUT. GET INSIDE!", Duration = 3 },
		{ At = 3, Phase = "Active", Where = "Outside", Kind = "Whispers", Target = "outside", Value = 0.4, To = 2.6, Duration = 18 },
		{ At = 6, Phase = "Active", Where = "Outside", Kind = "Heartbeat", Value = 77, To = 165, Duration = 22 },
		-- when the Walker reaches the pantry door, a second shape stands at the front glass, watching the street
		{
			At = 18,
			Phase = "Active",
			Where = "Outside",
			Kind = "Silhouette",
			Target = "Arrive",
			Point = FRONT_FAR,
			To = FRONT_GLASS,
			Duration = 7,
			Sound = "walker_step",
		},
		{ At = 25, Phase = "Active", Where = "Outside", Kind = "Fov", Value = 2, To = 0, Duration = 3 },
		-- it goes when the dark ends either way
		{ At = 0, Phase = "Resolved", Where = "Outside", Kind = "Silhouette", Target = "Leave", To = FRONT_FAR, Duration = 4 },
		{ At = 0, Phase = "Resolved", Where = "Outside", Kind = "Lantern", Target = "Glow", Value = 0, Duration = 1.2 },
		-- the heart stops for everyone (no Where: a player who ran in meanwhile still hears it stop), fading (owner 2026-10-19)
		{ At = 0, Phase = "Resolved", Kind = "Heartbeat", Value = 0, To = 0, Duration = 0.6 },
		{ At = 2, Phase = "Failed", Where = "Outside", Kind = "Silhouette", Target = "Leave", To = FRONT_FAR, Duration = 5 },
		{ At = 0, Phase = "Failed", Kind = "Heartbeat", Value = 0, To = 0, Duration = 0.6 },
	},
}

return scene
