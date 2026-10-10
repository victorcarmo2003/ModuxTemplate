--!strict
-- Opal's lines by shift phase (content-data.md §3.19; NPC-020, CHR-003, DEC-079, DEC-099, DEC-191).
-- Keys: day, n1_3, n4_6, n7_10 (content-data "Phase" Day/N1_3/N4_6/N7_10, lowercased by rule §1.3).
-- TASK-009: text from story/characters.md CHR-003 (narrative-writer, Rascunho; <= 70 characters each).
-- One balloon per visit, drawn locally by the client (OpalController, TASK-038) without repeating the player's last.
-- Opal is an owl (DEC-203) and never an anomaly (DEC-191); her species lives in the controller, not here.
-- Not here (conditional lines, no pool shape yet): first Mart exit "Look both ways, Rookie." (proposal),
-- Rescue Whistle on the bench (DEC-100, DEC-129), after a party member fainted (night).
local Table = require(script.Parent.Table)

export type OpalPool = {
	Key: string,
	FromNight: number, -- 0 = day pool
	ToNight: number,
	Lines: { string },
}

return Table.new({
	{
		Key = "day",
		FromNight = 0,
		ToNight = 0,
		Lines = {
			"Mustard again? You're a mustard family.",
			"Walt's cart, huh? Good cart.",
			"Ketchup's on aisle two. Always has been.",
			"Back wall's got gear. Who stocks it? I don't ask.",
			"Look both ways out there. Twice.",
			"Cars won't wait for you, hon. Look first.",
		},
	},
	{
		Key = "n1_3",
		FromNight = 1,
		ToNight = 3,
		Lines = {
			"Night shift? Huh. Bring a jacket.",
			"Coffee's fresh. You'll want it.",
		},
	},
	{
		Key = "n4_6",
		FromNight = 4,
		ToNight = 6,
		Lines = {
			"Two coffees tonight? Oh — never mind. Habit.",
			"Don't mind the windows upstairs.",
		},
	},
	{
		Key = "n7_10",
		FromNight = 7,
		ToNight = 10,
		Lines = {
			"Sign's on. Sign's always on.",
			"If the lamps go out, you come here. Got it?",
		},
	},
} :: { OpalPool })
