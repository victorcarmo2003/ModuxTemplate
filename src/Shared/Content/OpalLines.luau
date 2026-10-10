--!strict
-- Opal's lines by shift phase (content-data.md §3.19; NPC-020, CHR-003, DEC-079). Owner: narrative-writer.
-- Keys: day, n1_3, n4_6, n7_10 (content-data "Phase" Day/N1_3/N4_6/N7_10, lowercased by rule §1.3).
-- STUB (TASK-003): lines filled in TASK-009.
local Table = require(script.Parent.Table)

export type OpalPool = {
	Key: string,
	FromNight: number, -- 0 = day pool
	ToNight: number,
	Lines: { string },
}

return Table.new({
	{ Key = "day", FromNight = 0, ToNight = 0, Lines = {} },
	{ Key = "n1_3", FromNight = 1, ToNight = 3, Lines = {} },
	{ Key = "n4_6", FromNight = 4, ToNight = 6, Lines = {} },
	{ Key = "n7_10", FromNight = 7, ToNight = 10, Lines = {} },
} :: { OpalPool })
