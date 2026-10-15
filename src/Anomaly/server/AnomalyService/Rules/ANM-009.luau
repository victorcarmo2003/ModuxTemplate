--!strict
-- ANM-009 The knock, server rule (T10: never in shared). anomalies.md N9; npcs.md NPC-017; content-data.md §6.10;
-- architecture.md §19.13; FEAT-019; DEC-054, DEC-204, DEC-254, DEC-255; TASK-117, TASK-333.
-- V2 family D: someone knocks on the back door pretending to be Walt (two series of three knocks). The answer is not
-- opening the door: opening it from the first knock until DoorGrace s after the Window = jumpscare + faint at once for
-- who opened (personal). Verb "refuse" (refuse to open; the back door has no verb of its own). "Seen" is AudioZone: in
-- the trailer zone at the first knock. Camera 2 shows the one knocking (client).
local Api = require(script.Parent.Parent.Api)

const rule: Api.Rule = {
	Anomaly = "anm_009_knock",
	Verb = "refuse",
	LikelyWrongVerb = "open_door",
	Window = 12,
	IsCritical = false,
	Params = {
		-- s after the start of the second series of three knocks (the first one is at 0); it ends ~1 s later, at the
		-- Window ("três batidas, pausa, mais três (~12 s)"). PROVISIONAL
		SecondAt = 10.8,
		-- s after the Window the door still bites (the figure is still outside); PROVISIONAL (TASK-333)
		DoorGrace = 2,
		-- s between the jumpscare and the faint
		ScareFaint = 0.5,
		-- trailer zone for "seen" (flat radius around MapPoint TRL, same as ANM-008). Inside the trailer always counts.
		Zone = "trailer",
		ZonePoint = "TRL",
		ZoneRadius = 24,
	},
}

return rule
