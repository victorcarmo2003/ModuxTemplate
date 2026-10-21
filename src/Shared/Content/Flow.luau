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
-- Pedestrians start/end on the ends of Content.WalkPaths.
-- Groups (TASK-144; FEAT-038; Q-182 A, Provisional): one spawn attempt may bring a pair (leader + partner) that takes
-- ONE queue slot, orders 2 hot dogs, pays per hot dog and counts 2 on the shift grade. Chance per attempt by shift
-- from FromDay / FromNight; a pair needs room for 2 in the customer cap and the NPC cap, else 1 customer spawns.
-- The next interval after a pair is x IntervalMult. Patience = Orders patience with K = K1 + K2, + PatienceBonus.
-- Pairs: weighted per shift; a pair with a type locked this shift weighs 0. Never the same species AND the same
-- outfit; at night never the same species (ANM-004 copies). Couple = walks and sits side by side (no gesture, Q-182 b).
-- The partner follows the leader (no pathfinding of its own): FollowGap behind (Couple: beside), QueueGap beside
-- while standing, snapped back to its spot past Leash studs.
-- Adopt (user request 2026-10-11, TASK-163; FEAT-009 note, Provisional): a passer-by near the queue may become the
-- next customer instead of a spawn at a door. NoticeLead s before an attempt, with Chance (per shift) and at most one
-- adoption per MinGapSeconds, the nearest passer-by within MaxDistance studs of Q5 whose species fits a customer type
-- of the shift stops on the sidewalk; at the attempt it becomes that customer (same species and outfit, no type
-- accessory), faces the cart for Beat s and walks to Q5. FirstDelay: the first attempt of a selling phase comes
-- {min, max} s after it starts (was one whole interval), so the first customer is at the counter in ~8-12 s.
local Table = require(script.Parent.Table)

export type SpawnWeight = { Point: string, Weight: number }
export type SpawnShift = { Day: { SpawnWeight }, Night: { SpawnWeight } }
export type Spawns = {
	Arrivals: SpawnShift, -- customers and customer anomalies (Role Customer / Actor) walking to Q5
	Exits: SpawnShift, -- where a customer leaving Q1 despawns
}

export type GroupPair = {
	Shift: "Day" | "Night",
	Leader: string, -- CustomerTypes key
	Partner: string, -- CustomerTypes key
	Weight: number,
	Couple: boolean,
}

export type Groups = {
	ChanceDay: number,
	ChanceNight: number,
	FromDay: number, -- first day with pairs (Day 1 = 0)
	FromNight: number, -- first night with pairs (Night 1 = 0)
	IntervalMult: number,
	PatienceBonus: number, -- seconds
	FollowGap: number, -- studs behind the walking leader (pair of friends)
	SideGap: number, -- studs beside the walking leader (couple)
	QueueGap: number, -- studs beside the standing leader (queue, counter)
	Leash: number, -- studs: farther than this from its spot the partner is snapped back
	PartnerSpeedMult: number, -- partner WalkSpeed = leader WalkSpeed x this (catches up)
	Pairs: { GroupPair },
}

export type Adopt = {
	ChanceDay: number, -- 0..1 per attempt
	ChanceNight: number, -- 0..1 per attempt (night walkers keep to the far west: few are ever in range)
	FromDay: number, -- first day with adoptions (Day 1 = 1)
	FromNight: number, -- first night with adoptions (0 = never at night)
	MaxDistance: number, -- studs (horizontal) from Q5
	MinGapSeconds: number, -- at least this long between two adoptions
	NoticeLead: number, -- s before the attempt the passer-by brakes (>= its braking time)
	Beat: number, -- s the new customer faces the cart before walking to the queue
	FirstDelay: { number }, -- {min, max} s from the start of a selling phase to its first attempt
}

-- Guarantee (user request 2026-10-11, Provisional; Q-202): on a day shift, when no customer is in the queue nor on the
-- way for MaxEmpty s (Day 1: MaxEmptyDay1), the next spawn attempt is forced now (the NPC cap, the queue size and
-- the tutorial still apply). Each empty gap draws its own limit: Max + [0, Spread] s, so it never feels robotic.
export type Guarantee = {
	MaxEmpty: number, -- seconds without any customer (day 2+)
	MaxEmptyDay1: number, -- same on Day 1
	Spread: number, -- seconds added at random to each gap's limit
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
	Groups: Groups, -- FEAT-038 (Provisional)
	Adopt: Adopt, -- TASK-163 (Provisional)
	Guarantee: Guarantee, -- Q-202 (Provisional)
	FullRetry: number, -- s: a spawn attempt skipped by a full counter tries again after this (DEC-241, Provisional)
	ReopenPause: number, -- s with no new arrival after the service window reopens (owner 2026-10-20, Provisional)
	NightQueueSize: number, -- counter slots at night, whatever the Counter level (TASK-287, Provisional)
	-- counter slots at night by connected members 1..4 (DEC-320, Q-413: 2 slots with 3+ players); wins over NightQueueSize
	NightQueueByParty: { number },
	-- s (min, max) after the counter frees at night before the next customer may come (owner 2026-10-18: "quando eu
	-- recuso um cliente vem outro logo após"); drawn again each time
	CounterGap: { number },
	-- s the customer who left the counter takes to walk out of the shop area; CounterGap starts counting after it
	CounterLeave: number,
}

const flow: Flow = {
	-- 1 customer every 14 s, solo, Day 1. PROVISIONAL Q-200: was 22 s (DEC-045) when the open shop lasted 360 s; the
	-- open shop is now 216 s (x0.6), so the rate went x1.6 and a day still brings ~15 customers
	BaseInterval = 14,
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
				{ Point = "D1", Weight = 35 }, -- B1 door on the Ninth front, east of the Pad
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
	Groups = {
		ChanceDay = 0.20,
		ChanceNight = 0, -- TASK-287: one NPC at the counter at night, no pairs (was 0.10, Q-182 a)
		FromDay = 2,
		FromNight = 2,
		IntervalMult = 1.6,
		PatienceBonus = 10,
		FollowGap = 2,
		SideGap = 2,
		QueueGap = 1.8,
		Leash = 8,
		PartnerSpeedMult = 1.2,
		Pairs = {
			-- Day (FEAT-038 Groups.Pairs)
			{ Shift = "Day", Leader = "student", Partner = "student", Weight = 30, Couple = false }, -- hamster + mouse
			{ Shift = "Day", Leader = "office_worker", Partner = "office_worker", Weight = 20, Couple = false },
			{ Shift = "Day", Leader = "grandparent", Partner = "grandparent", Weight = 15, Couple = true }, -- turtle + sheep
			{ Shift = "Day", Leader = "construction_worker", Partner = "construction_worker", Weight = 15, Couple = false },
			{ Shift = "Day", Leader = "office_worker", Partner = "student", Weight = 10, Couple = false },
			{ Shift = "Day", Leader = "construction_worker", Partner = "office_worker", Weight = 10, Couple = false },
			-- Night: never the same species
			{ Shift = "Night", Leader = "night_shift_worker", Partner = "construction_worker", Weight = 40, Couple = false },
			{ Shift = "Night", Leader = "night_shift_worker", Partner = "office_worker", Weight = 35, Couple = false },
			{ Shift = "Night", Leader = "office_worker", Partner = "construction_worker", Weight = 25, Couple = false },
		},
	},
	Adopt = {
		ChanceDay = 0.5, -- Provisional (user request 2026-10-11: ~50% by day)
		ChanceNight = 0.15, -- Provisional: lower at night
		FromDay = 1, -- Day 1 morning too (never the tutorial customer)
		FromNight = 1,
		MaxDistance = 60, -- ~4-5 s to Q5 at customer pace
		MinGapSeconds = 8,
		NoticeLead = 0.8, -- a walker at 12 studs/s brakes in 0.75 s (WalkGeo.Brake 16)
		Beat = 0.6,
		FirstDelay = { 3, 5 }, -- + walk (adopted ~5 s, door ~8 s) = first customer at Q5 in ~8-12 s
	},
	Guarantee = { MaxEmpty = 9, MaxEmptyDay1 = 5, Spread = 2 }, -- day 2+: 9-11 s (~10), Day 1: 5-7 s (~6)
	-- DEC-241 (user decision 2026-10-13, Provisional): the counter holds 1 customer by default, so most attempts meet it
	-- full; instead of waiting the whole interval, an attempt skipped for a full counter tries again after ~3.5 s.
	FullRetry = 3.5,
	ReopenPause = 15,
	-- TASK-287 (owner request 2026-10-14, Provisional): at night ONE NPC at the counter at a time. An anomaly actor
	-- (CustomerService:SpawnActor) takes the ordinary customer's turn; the next one comes when the current one leaves.
	NightQueueSize = 1,
	NightQueueByParty = { 1, 1, 2, 2 }, -- DEC-320 (Q-413), Provisional
	CounterGap = { 10, 20 }, -- owner 2026-10-18, Provisional
	CounterLeave = 5, -- owner 2026-10-18: "a contagem deve só iniciar quando o cliente que estava na frente sair"
}

return Table.record(flow)
