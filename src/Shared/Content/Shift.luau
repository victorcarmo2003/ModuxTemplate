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
-- LastCall (DEC-240, user decision 2026-10-13): on a DAY shift the Closing row is "Last call": the clock stands at 6 PM,
-- nobody new arrives (Selling stays false) but the trailer is still OPEN (the sign shows OPEN, the kitchen, the prep mode,
-- the tables and the drawer keep working) and the queue and the tables are served without a rush. The day closes by itself
-- when they are empty (counter probe); Duration is only the safety cap against an AFK crew. The night Closing
-- (Night override) is NOT a last call: it keeps its own short cap and the counter is emptied.
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
	LastCall: boolean?, -- day shift only: still open to the crew and the queue, but no new arrival (Closing)
}

local function hours(h: number, m: number?): number
	return h * 60 + (m or 0)
end

const base = Table.new({
	-- Resume wait after a reconnect (DEC-080); = RunParams.ResumeWait (architect). Clock held.
	{ Key = "Resume", Duration = 15, ClockFrom = 0, ClockTo = 0, Kind = "Any", Selling = false, SkipWithoutProbe = false },
	-- Intro cutscene, first shift of a new run only (FEAT-004; PROVISIONAL frontend-coder 2026-10-12, owner D3: short
	-- intro, was 108 s; D3 rev. 2: 35 s; DEC-300: 32 s). Cap 67 s = the wait for every participant's ClientReady
	-- (Cutscenes.Rules.ReadyTimeout 30 s) + the intro Cap (35 s) + 2 s margin (Validate); the probe ends it once the chain is
	-- over. Clock stopped at 7:00 AM; on a run that starts at night (RunStartsAtNight, DEC-300) the intro opens Night 1
	-- and the clock stands at 7:00 PM.
	{
		Key = "Intro",
		Duration = 67,
		ClockFrom = hours(7),
		ClockTo = hours(7),
		Kind = "Any",
		Selling = false,
		SkipWithoutProbe = true,
		Night = { Duration = 67, ClockFrom = hours(19), ClockTo = hours(19) },
	},
	-- Day shortened (user playtest 2026-10-11, PROVISIONAL Q-200): day turn ~7.7 min -> ~4.6 min (Prep 60 -> 30 s,
	-- Open 360 -> 216 s, Closing 30 -> 20 s, Summary 15 -> 8 s; night shift: Summary 20 -> 10 s).
	-- Prep: 7:00 -> 8:00 AM, up to 30 s; "Open Shop" ends it early (DEC-048, FEAT-003). Night: 7 -> 8 PM, 90 s.
	{
		Key = "Prep",
		Duration = 30,
		ClockFrom = hours(7),
		ClockTo = hours(8),
		Kind = "Any",
		Selling = false,
		SkipWithoutProbe = false,
		Night = { Duration = 90, ClockFrom = hours(19), ClockTo = hours(20) },
	},
	-- Open: 8:00 AM -> 6:00 PM in 216 s, 1 game hour = 21.6 s (DEC-048, FEAT-003; was 360 s / 36 s, Q-200).
	{ Key = "Open", Duration = 216, ClockFrom = hours(8), ClockTo = hours(18), Kind = "Day", Selling = true, SkipWithoutProbe = false },
	-- Closing, day = LAST CALL (DEC-240; was "sign CLOSED, ends at 20 s", DEC-048, Q-200): no new arrival, the sign stays
	-- OPEN, the queue and the tables are served; ends when the counter and the tables empty, or at the 120 s safety cap
	-- (Provisional). Night (6 AM): the old 30 s Closing. 6 PM / 6 AM.
	{
		Key = "Closing",
		Duration = 120,
		LastCall = true,
		ClockFrom = hours(18),
		ClockTo = hours(18),
		Kind = "Any",
		Selling = false,
		SkipWithoutProbe = false,
		Night = { Duration = 30, ClockFrom = hours(30), ClockTo = hours(30) },
	},
	-- Summary: 8 s on day, 10 s at night (DEC-048, FEAT-014; was 15 / 20 s, halved by Q-200). Clock stopped.
	{
		Key = "Summary",
		Duration = 8,
		ClockFrom = hours(18),
		ClockTo = hours(18),
		Kind = "Any",
		Selling = false,
		SkipWithoutProbe = false,
		Night = { Duration = 10, ClockFrom = hours(30), ClockTo = hours(30) },
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
	-- Safety cap on the Day 1 hold (user decision 2026-10-12, PROVISIONAL): TutorialService freezes the clock and holds the
	-- regular customers while a rookie is in the tutorial; after this many seconds of holding it lets go (AFK rookie).
	TutorialHoldMax = 600,
	-- Back door of the trailer (user request 2026-10-12, Provisional): false = the prompt opens / closes the leaf and the
	-- player walks through; true = the old fade + teleport (Exit / Enter Trailer).
	TrailerDoorTeleport = false,
	-- A new run skips the day shift (owner 2026-10-18, DEC-300): it opens on Night 1 (Day 2) with the intro cutscene, which
	-- ends looking at the restaurant while the night falls; the game fades in inside it, at night. false = the old Day 1
	-- (day shift + tutorial) first.
	RunStartsAtNight = true,
	ClockStepMinutes = 5, -- HUD updates every 5 game minutes (1.8 s real on day) (DEC-048; user request 2026-10-11, was 10)
})
