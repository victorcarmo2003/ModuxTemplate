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
-- when they are empty (counter probe); Duration is only the safety cap against an AFK crew. The night Closing (6 AM) is a
-- last call too since 2026-10-21 (Night override LastCall, owner request, Provisional): the line still at the window when
-- the night ends is served, then the shift ends (an empty line ends it at once).
local Table = require(script.Parent.Table)

export type Kind = "Day" | "Night" | "Any"

export type NightOverride = {
	Duration: number,
	ClockFrom: number,
	ClockTo: number,
	-- seconds the phase probe cannot end it (an empty counter waits until then); nil = the probe ends it any time
	Min: number?,
	-- night Last call (Closing only): the line still there at 6 AM is served, nobody new arrives (see LastCall)
	LastCall: boolean?,
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
	-- Day shortened (user playtest 2026-10-11, PROVISIONAL Q-200): day turn ~7.7 min -> ~4.6 min (Prep 60 -> 30 s,
	-- Open 360 -> 216 s, Closing 30 -> 20 s, Summary 15 -> 8 s; night shift: Summary 20 -> 10 s).
	-- Prep: 7:00 -> 8:00 AM, up to 30 s; "Open Shop" ends it early (DEC-048, FEAT-003). Night: 7 -> 8 PM, 36 s.
	{
		Key = "Prep",
		Duration = 30,
		ClockFrom = hours(7),
		ClockTo = hours(8),
		Kind = "Any",
		Selling = false,
		SkipWithoutProbe = false,
		-- the night's buying break: 30 s after the report and the boss call, then the night starts with the window open
		-- (opening the window earlier starts it at once). Was 90 s, then 36 s (owner 2026-10-21, Provisional)
		-- 7 PM -> 8 PM, dark (owner 2026-10-21: "tira esse sistema de ficar de dia"). With Shift.Morning.Enabled the clock
		-- ran 6 AM -> 8 PM over the 30 s: day light, walkers and day traffic, dusk in the last ~5 s
		Night = { Duration = 30, ClockFrom = hours(19), ClockTo = hours(20) },
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
		-- owner 2026-10-21 (Provisional): the night's last call. The customer still in line at 6 AM is served, then the
		-- shift ends (window shut, report) the moment nobody is left; an empty line ends it at once. Nothing holds it:
		-- 60 s is only the ceiling against a crew that walked away from a customer. Was
		-- Min = 45 (upgrade time after the night: the minute where nothing happened; the Gear Stand stays open through
		-- Summary, Call and Prep anyway)
		Night = { Duration = 60, ClockFrom = hours(30), ClockTo = hours(30), LastCall = true },
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
	-- Boss call before the night; cap 120 s (BossCalls ReadyWait 20 + ring up to 15 + lines + coffee), clock stopped at
	-- 7:00 PM (FEAT-018). Ends by the Boss probe. Cap 120 -> 50 s (owner 2026-10-21, Provisional: "cut 60%"; 48 s fails the
	-- Validate fit of call_night_1 + coffee call + ReadyWait + AutoAnswer = 50 s).
	{
		Key = "Call",
		Duration = 50,
		-- 7 PM (owner 2026-10-21: the morning after the night is off for now, Shift.Morning.Enabled; it was 6 AM with it)
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
	-- Finale cutscene after Night 10 is won; cap 200 s at 6:00 AM (FEAT-027).
	{
		Key = "Finale",
		Duration = 200, -- "The Second Coffee" chain (caps 43 + 38 + 23) and the credits (75), owner request 2026-10-22; was 150
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
	-- Co-op cap (DEC-320, Q-412 C, Provisional): seconds per RUN the clock may stay held while a crewmate who is done
	-- waits for a rookie (TutorialService:CountWait); a rookie who joins later never restarts it
	TutorialWaitMax = 180,
	-- Back door of the trailer (user request 2026-10-12, Provisional): false = the prompt opens / closes the leaf and the
	-- player walks through; true = the old fade + teleport (Exit / Enter Trailer).
	TrailerDoorTeleport = false,
	-- A new run skips the day shift (owner 2026-10-18, DEC-300): it opens straight on Night 1 (Day 2), with the boss call
	-- (the intro cutscene was removed, DEC-309). false = the old Day 1 (day shift + tutorial) first.
	RunStartsAtNight = true,
	-- The morning of a night shift (owner 2026-10-21, Provisional): Call and Prep of a night shift are daytime - day
	-- light, more walkers, day traffic, no Hunter (OutsideService is Night-phase only) - until DuskFrom (game minutes of the
	-- Prep clock), when it darkens fast (LightController blend), the fog comes back and walkers / cars stop spawning.
	-- 5:40 PM = the last ~5 s of the 30 s Prep (6 AM -> 8 PM). RoundService:IsDark() / RoundController.Dark read it.
	-- FromNight: the first night that has a morning. Owner 2026-10-21 ("tem que começar já na noite"): the run opens on
	-- Night 1 already dark; the morning is the break between two nights.
	-- Enabled: owner 2026-10-21 ("tira esse sistema de ficar de dia, vamos deixar sem ele por enquanto"): off, the night
	-- shift stays dark from the report to the next night; the Call / Prep clocks went back to 7 PM.
	Morning = { Enabled = false, DuskFrom = hours(17, 40), FromNight = 2 },
	ClockStepMinutes = 5, -- HUD updates every 5 game minutes (1.8 s real on day) (DEC-048; user request 2026-10-11, was 10)
})
