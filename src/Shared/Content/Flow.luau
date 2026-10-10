--!strict
-- Customer flow, single record (content-data.md §3.16; FEAT-009; DEC-045, DEC-183, DEC-185).
-- Spawn rate (day) = (1 / BaseInterval) x min(1 + GrowthPerDay x (Day - 1), 1 + GrowthCap) x PartyMult[connected]
-- x DayFlowBonus (Trailer Lights); interval jittered by +-Jitter; spawn skipped while the counter is full (FEAT-009).
-- Night (wave 2): base interval per night in Nights[k].Customers.BaseInterval (fallback NightInterval), same
-- PartyMult and Jitter, cap MaxCustomersNight. Values of TASK-081 (FEAT-009: 40 s N1-5 / 36 s N6-10, Provisional).
-- Spawns (MAP-01 §9.8, level-designer 2026-10-10, Provisional): where customers come from and where they leave, by
-- shift. Point = MapPoint/NpcNode id of the MAP-01 binding (attribute Spawn / Despawn on the point). Every point is a
-- building door (D1, DR-APT) or a street end beyond the player limits, out of sight of the Pad and the Mart; route to
-- Q5 <= ~100 studs (<= 10 s at 13 studs/s). Weight 0 = known point, not drawn (SP-A: 136 studs; SP-B: 151 studs).
-- The thief keeps Content.Thief.Spawn / Exits; pedestrians start/end on the ends of Content.WalkPaths.
local Table = require(script.Parent.Table)

export type SpawnWeight = { Point: string, Weight: number }
export type SpawnShift = { Day: { SpawnWeight }, Night: { SpawnWeight } }
export type Spawns = {
	Arrivals: SpawnShift, -- customers and customer anomalies (Role Customer / Actor) walking to Q5
	Exits: SpawnShift, -- where a customer leaving Q1 despawns
}

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
	NightInterval: number, -- seconds between spawns at night, solo; fallback when a night has no own value
	Spawns: Spawns, -- MAP-01 §9.8 (Provisional)
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
	NightInterval = 40, -- FEAT-009, Provisional (TASK-081)
	Spawns = {
		Arrivals = {
			Day = {
				{ Point = "D1", Weight = 35 }, -- B1 door on the Pad, ~79 studs
				{ Point = "DR-APT", Weight = 35 }, -- Bellmoor Savings / apartments door, CW-4, ~80 studs
				{ Point = "SP-S", Weight = 30 }, -- Juniper South beyond BAR-S, ~93 studs
				{ Point = "SP-A", Weight = 0 }, -- alley beyond BAR-N, ~136 studs (> 10 s): kept for actors / tests
			},
			Night = {
				{ Point = "D1", Weight = 50 },
				{ Point = "SP-S", Weight = 30 },
				{ Point = "DR-APT", Weight = 20 }, -- residents' door (the bank is closed)
				{ Point = "SP-A", Weight = 0 },
			},
		},
		Exits = {
			Day = { { Point = "EX-E", Weight = 60 }, { Point = "D1", Weight = 40 } },
			Night = { { Point = "EX-E", Weight = 60 }, { Point = "D1", Weight = 40 } },
		},
	},
}

return Table.record(flow)
