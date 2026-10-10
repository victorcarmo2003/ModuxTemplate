--!strict
-- ANM-009 The knock, server rule (T10: never in shared). anomalies.md N9; npcs.md NPC-017; content-data.md §6.10;
-- architecture.md §19.13; FEAT-019, FEAT-023; DEC-054, DEC-195, DEC-204; TASK-117.
-- Verb hide, personal target: every active player in the trailer zone must be hidden when the last knock ends (Window
-- s after the first series). Going to the door is not an action (the back door has no prompt, DEC-054): it only means
-- "not hidden". Outside the zone (e.g. at the Mart) = not tested. "Seen" is AudioZone: in the zone at the first knock.
local Api = require(script.Parent.Parent.Api)

const rule: Api.Rule = {
	Anomaly = "anm_009_knock",
	Verb = "hide",
	LikelyWrongVerb = "go_to_door",
	Window = 12,
	IsCritical = false,
	Params = {
		-- s after the start of the second series of three knocks (the first one is at 0); it ends ~1 s later, at the
		-- Window ("três batidas, pausa, mais três (~12 s)"). PROVISIONAL
		SecondAt = 10.8,
		-- trailer zone (content-data.md §6.10 Zone = "trailer"; tests/wave-3.md L3-15; PROVISIONAL): flat radius around
		-- MapPoint TRL, same as ANM-008. A hidden player is always in the zone.
		Zone = "trailer",
		ZonePoint = "TRL",
		ZoneRadius = 24,
	},
}

return rule
