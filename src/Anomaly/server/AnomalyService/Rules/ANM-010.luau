--!strict
-- ANM-010 The Hush, server rule (T10: never in shared). anomalies.md N10; npcs.md NPC-018; content-data.md §6.10;
-- architecture.md §19.13, §19.14; FEAT-020, FEAT-023, FEAT-027; DEC-054, DEC-195, DEC-204; TASK-117.
-- Verb safe_spot, personal target: every active player must be in the safe zone when the corner post goes out
-- (PostsOff s after the start) and stay there until the posts come back (HoldFor s later). Outside at the corner
-- post, or leaving before the posts return = -35 for that player only. Night 10, 5:45 AM (Scripted): the posts stay
-- out until 6:00 AM (FEAT-027), so the hold lasts until the night ends.
local Api = require(script.Parent.Parent.Api)

const rule: Api.Rule = {
	Anomaly = "anm_010_hush",
	Verb = "safe_spot",
	LikelyWrongVerb = "stay_in_trailer",
	Window = 15,
	IsCritical = false,
	Params = {
		-- s from the first post to the corner post. Fallback only: the real moment is the one LightService uses
		-- (largest StreetLight Order x LightGroups.juniper_posts.Step = 10 x 1.5 = 15)
		PostsOff = 15,
		-- s the posts stay out after the corner post (then they come back and the occurrence resolves)
		HoldFor = 20,
		-- safe point (architecture.md §19.14: InZone(player, "SS", 6))
		Point = "SS",
		Radius = 6,
		-- extra safe volumes: LightZone ZoneIds (tests/wave-3.md L3-12, npcs.md N10 "e o interior do Mart": who is
		-- shopping inside the Mart does not fail). PROVISIONAL (backend-coder, TASK-117)
		SafeZones = { "LZ-4" },
	},
}

return rule
