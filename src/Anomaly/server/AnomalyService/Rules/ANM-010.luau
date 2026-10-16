--!strict
-- ANM-010 The Hush, server rule (T10: never in shared). anomalies.md N10; npcs.md NPC-018; content-data.md §6.10;
-- architecture.md §19.13, §19.14; FEAT-020, FEAT-023, FEAT-027; DEC-054, DEC-195, DEC-204; TASK-117.
-- Verb safe_spot, personal target: every active player must be in the safe zone when the corner post goes out
-- (PostsOff s after the start) and stay there until the posts come back (HoldFor s later). Outside at the corner
-- post, or leaving before the posts return = -35 for that player only. Night 10, 5:45 AM (Scripted): the posts stay
-- out until 6:00 AM (FEAT-027), so the hold lasts until the night ends. TASK-334 (Provisional): the error is jumpscare +
-- faint (V2), a watched player fails only after OutGrace s outside in a row, wider radius around SS.
local Api = require(script.Parent.Parent.Api)

const rule: Api.Rule = {
	Anomaly = "anm_010_hush",
	Verb = "safe_spot",
	LikelyWrongVerb = "stay_in_trailer",
	Window = 15,
	IsCritical = false,
	Params = {
		-- s from the first post to the corner post. Fallback only: the real moment is the one LightService uses
		-- (largest StreetLight Order x LightGroups.juniper_posts.Step = 5 x 3 = 15; NL-01..04 + P-01, MAP-01 §5.6)
		PostsOff = 15,
		-- s the posts stay out after the corner post (then they come back and the occurrence resolves)
		HoldFor = 20,
		-- safe point (architecture.md §19.14: InZone(player, "SS", r)); 6 -> 10 (TASK-334, PROVISIONAL): the doorway counts
		Point = "SS",
		Radius = 14, -- 10 -> 14 (owner 2026-10-16: the inside of the doorway counts)
		-- s outside the safe zone in a row before a watched player fails (the Mart doorway, TASK-334; PROVISIONAL)
		OutGrace = 2,
		-- s between the jumpscare and the faint
		ScareFaint = 0.7,
		-- extra safe volumes: LightZone ZoneIds (tests/wave-3.md L3-12, npcs.md N10 "e o interior do Mart": who is
		-- shopping inside the Mart does not fail). PROVISIONAL (backend-coder, TASK-117)
		-- owner 2026-10-16: standing just inside the Mart failed (LZ-4 alone left the entrance out): LZ-5 (entrance) too
		SafeZones = { "LZ-4", "LZ-5" },
		-- studs added on every side of each safe LightZone (the gap between LZ-4 and LZ-5 at the door)
		ZoneMargin = 4,
	},
}

return rule
