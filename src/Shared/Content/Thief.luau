--!strict
-- Day thief, single record (content-data.md §3.16, §6.6; architecture.md §19.10; FEAT-013; DEC-050, DEC-182).
-- Owner: game-designer. Opening time and stolen share come from the Cash Drawer Lock effects (DrawerOpenTime 8/16,
-- StealPct 50/30), not from here. Points are MapPoint ids of MAP-01 §5.3.
local Table = require(script.Parent.Table)

export type Chance = {
	Days: { number }, -- chance on Day d for d <= #Days
	Default: number, -- chance on every later day
}

export type Thief = {
	ChanceByDay: Chance,
	MaxPerDay: number,
	WindowClock: { number }, -- {from, to} in game minutes: the attempt starts inside this window
	LurkMax: number, -- seconds at the lurk point before giving up
	ZoneRadius: number, -- studs around the vehicle's Zone_Center
	ZoneEmptyTime: number, -- seconds with nobody Active in the zone before the approach
	ApproachTime: number, -- fixed; walk speed = distance / ApproachTime (DEC-182)
	MinDrawer: number, -- no theft below this drawer amount
	CatchReward: number, -- $ to the drawer when caught (DrawerKind "Catch")
	CapRetry: number, -- NPC cap full at the drawn time: retry after this many seconds, until the window ends
	Lurks: { string },
	Spawn: string,
	Exits: { string },
}

const thief: Thief = {
	ChanceByDay = { Days = { 0, 0.5 }, Default = 0.7 }, -- never on Day 1 (FEAT-013)
	MaxPerDay = 1,
	WindowClock = { 540, 900 }, -- 9 AM -> 3 PM
	LurkMax = 120,
	ZoneRadius = 14,
	ZoneEmptyTime = 3,
	ApproachTime = 4, -- DEC-182
	MinDrawer = 5,
	CatchReward = 5, -- DEC-050 ("Nice catch! +$5")
	CapRetry = 30, -- Provisional (TASK-081, NPC-007)
	Lurks = { "L1", "L2", "L3" },
	Spawn = "ST-R",
	Exits = { "ST-R", "EX-E" },
}

return Table.record(thief)
