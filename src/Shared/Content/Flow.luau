--!strict
-- Customer flow, single record (content-data.md §3.16; FEAT-009; DEC-045, DEC-183, DEC-185).
-- Spawn rate (day) = (1 / BaseInterval) x min(1 + GrowthPerDay x (Day - 1), 1 + GrowthCap) x PartyMult[connected]
-- x DayFlowBonus (Trailer Lights); interval jittered by +-Jitter; spawn skipped while the counter is full (FEAT-009).
-- Night intervals (40 s nights 1-5, 36 s nights 6-10) are a FEAT-009 proposal with no field yet (wave 2, architect).
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
	BaseInterval = 22, -- 1 customer every 22 s, solo, Day 1 (DEC-045)
	GrowthPerDay = 0.08, -- +8% rate per day (DEC-045)
	GrowthCap = 0.40, -- rate cap +40% (DEC-045; FEAT-009 formula)
	PartyMult = { 1.0, 1.6, 2.1, 2.5 }, -- 1p..4p on the rate (DEC-045)
	PartySource = "Connected", -- connected players (DEC-185)
	RecalcOn = "ShiftStarted", -- recalculated at the start of each shift (DEC-185, Provisional part)
	Jitter = 0.25, -- interval +-25% (FEAT-009)
	MaxCustomersDay = 8, -- DEC-045
	MaxCustomersNight = 6, -- DEC-045
	MaxActorsNight = 3, -- anomaly actors (DEC-045)
	MaxNpc = 12, -- server humanoids (DEC-045; walkers inside or outside: Q-162)
	DayWalkers = { 6, 8 }, -- DEC-183, wave 2
	NightWalkers = { 1, 2 }, -- DEC-183, wave 2
}

return Table.record(flow)
