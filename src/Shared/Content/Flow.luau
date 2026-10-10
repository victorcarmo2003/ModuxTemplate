--!strict
-- Customer flow, single record (content-data.md §3.16; DEC-045, DEC-183, DEC-185).
-- STUB (TASK-003): values from content-data.md v4; reviewed in TASK-008.
local Table = require(script.Parent.Table)

export type Flow = {
	BaseInterval: number, -- seconds between spawns, solo, Day 1
	GrowthPerDay: number,
	GrowthCap: number,
	PartyMult: { number }, -- by connected players 1..4
	PartySource: "Connected", -- DEC-185
	RecalcOn: "ShiftStarted", -- Provisional (DEC-185)
	Jitter: number,
	MaxCustomersDay: number,
	MaxCustomersNight: number,
	MaxActorsNight: number,
	MaxNpc: number, -- DEC-045 (walkers inside or outside the cap: Q-162)
	DayWalkers: { number }, -- {min, max}, wave 2 (DEC-183)
	NightWalkers: { number },
}

const flow: Flow = {
	BaseInterval = 22,
	GrowthPerDay = 0.08,
	GrowthCap = 0.40,
	PartyMult = { 1.0, 1.6, 2.1, 2.5 },
	PartySource = "Connected",
	RecalcOn = "ShiftStarted",
	Jitter = 0.25,
	MaxCustomersDay = 8,
	MaxCustomersNight = 6,
	MaxActorsNight = 3,
	MaxNpc = 12,
	DayWalkers = { 6, 8 },
	NightWalkers = { 1, 2 },
}

return Table.record(flow)
