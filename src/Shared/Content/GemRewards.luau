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

-- x75 of DEC-070 / FEAT-027 (TASK-308, owner request 2026-10-15, Provisional): the class prices went x44..x125, so a
-- full run still buys every MVP class (perfect run 382 -> 28,650 gems; MVP classes 27,000).
const rewards: GemRewards = {
	DayShift = 150, -- DEC-070: 2
	DayGradeA = 75, -- DEC-070: 1
	NightBase = 1125, -- DEC-070: 15
	NightPerIndex = 150, -- DEC-070: 2
	Finale = 7500, -- FEAT-027: 100
	RunFailedExtra = 0,
	CreditMoment = "Event", -- DEC-104
}

return Table.record(rewards)
