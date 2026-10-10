--!strict
-- Gems per event, single record (content-data.md §3.11; architecture.md §19.11; data.md §1.3; FEAT-017, FEAT-029,
-- FEAT-031; DEC-070, DEC-083, DEC-084, DEC-104). Owner: game-designer. Credited and saved at the event (DEC-104);
-- idempotent by the RunRewards key in the profile (D{n}:day, D{n}:gradeA, D{n}:endless, N{n}:night, finale).
local Table = require(script.Parent.Table)

export type GemRewards = {
	DayShift: number, -- day done with the anti-AFK minimum (RunParams.AntiAfkMinCompleted)
	DayGradeA: number, -- grade A (anti-AFK per RunParams.AntiAfkAppliesToGradeA)
	NightBase: number, -- night N won: NightBase + NightPerIndex x (N - 1)
	NightPerIndex: number,
	Finale: number, -- last night won, before the Finale cutscene
	RunFailedExtra: number,
	CreditMoment: "Event", -- fixed (DEC-104)
}

const rewards: GemRewards = {
	DayShift = 2, -- DEC-070
	DayGradeA = 1, -- DEC-070
	NightBase = 15, -- DEC-070
	NightPerIndex = 2, -- DEC-070
	Finale = 100, -- FEAT-027
	RunFailedExtra = 0,
	CreditMoment = "Event", -- DEC-104
}

return Table.record(rewards)
