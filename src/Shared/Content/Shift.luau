--!strict
-- Shift phases (content-data.md §3.2, §6.2; architecture.md §19.4; FEAT-003; DEC-048, DEC-080, DEC-127).
-- Keys are wire enum values (Shift.Phase), PascalCase by rule §1.3. PhaseKeys did not change in wave 2.
-- Duration is the real-time cap of the phase in seconds; the clock runs ClockFrom -> ClockTo across that time.
-- ClockFrom = ClockTo = a fixed time: the clock is stopped on that time. ClockFrom = ClockTo = 0 (Resume,
-- NightLost, RunEnd): the clock holds whatever the previous phase showed.
-- Night: { Duration, ClockFrom, ClockTo } overrides the row on a night shift (Prep 90 s 7->8 PM, Closing and
-- Summary at 6 AM). The Night phase itself has Duration 0: its length is Nights[k].Duration (DEC-127).
-- Selling: customers spawn and the drawer counts (Economy, Customer). Only Open and Night (Validate).
-- SkipWithoutProbe: the phase is skipped when no feature registered a probe for it (architecture.md §19.0 rule 4).
local Table = require(script.Parent.Table)

export type Kind = "Day" | "Night" | "Any"

export type NightOverride = {
	Duration: number,
	ClockFrom: number,
	ClockTo: number,
}

export type Phase = {
	Key: string,
	Duration: number, -- seconds (cap of the phase); 0 = set elsewhere (Night: Nights[k].Duration)
	ClockFrom: number, -- game minutes since 0:00 of the shift day (0..2880)
	ClockTo: number,
	Kind: Kind,
	Selling: boolean,
	SkipWithoutProbe: boolean,
	Night: NightOverride?,
}

local function hours(h: number, m: number?): number
	return h * 60 + (m or 0)
end

const base = Table.new({
	-- Resume wait after a reconnect (DEC-080); = RunParams.ResumeWait (architect). Clock held.
	{ Key = "Resume", Duration = 15, ClockFrom = 0, ClockTo = 0, Kind = "Any", Selling = false, SkipWithoutProbe = false },
	-- Intro cutscene, first shift of a new run only; cap 70 s (FEAT-004; PROVISIONAL frontend-coder 2026-10-11: the
	-- intro got dramatic pauses after the user's play feedback, was 50 s). Clock stopped at 7:00 AM.
	{
		Key = "Intro",
		Duration = 70,
		ClockFrom = hours(7),
		ClockTo = hours(7),
		Kind = "Day",
		Selling = false,
		SkipWithoutProbe = true,
	},
	-- Prep: 7:00 -> 8:00 AM, up to 60 s; "Open Shop" ends it early (DEC-048, FEAT-003). Night: 7 -> 8 PM, 90 s.
	{
		Key = "Prep",
		Duration = 60,
		ClockFrom = hours(7),
		ClockTo = hours(8),
		Kind = "Any",
		Selling = false,
		SkipWithoutProbe = false,
		Night = { Duration = 90, ClockFrom = hours(19), ClockTo = hours(20) },
	},
	-- Open: 8:00 AM -> 6:00 PM in 360 s, 1 game hour = 36 s (DEC-048, FEAT-003).
	{ Key = "Open", Duration = 360, ClockFrom = hours(8), ClockTo = hours(18), Kind = "Day", Selling = true, SkipWithoutProbe = false },
	-- Closing: sign CLOSED, queue still served; ends when the counter empties or at 30 s (DEC-048). 6 PM / 6 AM.
	{
		Key = "Closing",
		Duration = 30,
		ClockFrom = hours(18),
		ClockTo = hours(18),
		Kind = "Any",
		Selling = false,
		SkipWithoutProbe = false,
		Night = { Duration = 30, ClockFrom = hours(30), ClockTo = hours(30) },
	},
	-- Summary: 15 s on day, 20 s at night (DEC-048, FEAT-014). Clock stopped.
	{
		Key = "Summary",
		Duration = 15,
		ClockFrom = hours(18),
		ClockTo = hours(18),
		Kind = "Any",
		Selling = false,
		SkipWithoutProbe = false,
		Night = { Duration = 20, ClockFrom = hours(30), ClockTo = hours(30) },
	},
	-- Boss call before the night; cap 60 s, clock stopped at 7:00 PM (FEAT-018). Ends by the Boss probe.
	{
		Key = "Call",
		Duration = 60,
		ClockFrom = hours(19),
		ClockTo = hours(19),
		Kind = "Night",
		Selling = false,
		SkipWithoutProbe = true,
	},
	-- Night: 8:00 PM -> 6:00 AM (DEC-048); duration per night from Nights (DEC-127).
	{ Key = "Night", Duration = 0, ClockFrom = hours(20), ClockTo = hours(30), Kind = "Night", Selling = true, SkipWithoutProbe = false },
	-- 6:00 AM beat after a won night (3 s).
	{
		Key = "NightEnd",
		Duration = 3,
		ClockFrom = hours(30),
		ClockTo = hours(30),
		Kind = "Night",
		Selling = false,
		SkipWithoutProbe = false,
	},
	-- Lost night sequence (lights out, dawn), 6 s; clock held (architecture.md §19.4, T58).
	{ Key = "NightLost", Duration = 6, ClockFrom = 0, ClockTo = 0, Kind = "Night", Selling = false, SkipWithoutProbe = false },
	-- Finale cutscene after Night 10 is won; cap 150 s at 6:00 AM (FEAT-027).
	{
		Key = "Finale",
		Duration = 150,
		ClockFrom = hours(30),
		ClockTo = hours(30),
		Kind = "Night",
		Selling = false,
		SkipWithoutProbe = true,
	},
	-- End of run screen, 15 s; clock held.
	{ Key = "RunEnd", Duration = 15, ClockFrom = 0, ClockTo = 0, Kind = "Any", Selling = false, SkipWithoutProbe = false },
} :: { Phase })

return Table.with(base, {
	PhaseKeys = base.Keys,
	ClockStepMinutes = 5, -- HUD updates every 5 game minutes (3 s real on day) (DEC-048; user request 2026-10-11, was 10)
})
