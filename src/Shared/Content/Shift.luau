--!strict
-- Shift phases (content-data.md §3.2; FEAT-003; DEC-048, DEC-080). Keys are wire enum values (Shift.Phase),
-- PascalCase by rule §1.3. PhaseKeys is complete from wave 1 so Net does not change in wave 2.
-- Wave 1 (TASK-008): only the day phases carry numbers. Night phases exist as keys only; their durations come from
-- Nights (wave 2, DEC-127) and are 0 here ("set elsewhere / not used yet").
-- Duration is the real-time cap of the phase in seconds; the clock runs ClockFrom -> ClockTo across that time.
local Table = require(script.Parent.Table)

export type Kind = "Day" | "Night" | "Any"

export type Phase = {
	Key: string,
	Duration: number, -- seconds (cap of the phase); 0 = set elsewhere / not used yet
	ClockFrom: number, -- game minutes since 0:00 of the shift day (0..2880)
	ClockTo: number,
	Kind: Kind,
}

local function hours(h: number, m: number?): number
	return h * 60 + (m or 0)
end

const base = Table.new({
	-- Resume wait after a reconnect (DEC-080); = RunParams.ResumeWait (architect).
	{ Key = "Resume", Duration = 15, ClockFrom = 0, ClockTo = 0, Kind = "Any" },
	-- Intro cutscene; length from Cutscenes (wave 4).
	{ Key = "Intro", Duration = 0, ClockFrom = 0, ClockTo = 0, Kind = "Any" },
	-- Prep: 7:00 -> 8:00 AM, up to 60 s; "Open Shop" ends it early (DEC-048, FEAT-003).
	-- Night prep (7:00 -> 8:00 PM, up to 90 s, FEAT-003 proposal) is wave 2.
	{ Key = "Prep", Duration = 60, ClockFrom = hours(7), ClockTo = hours(8), Kind = "Any" },
	-- Open: 8:00 AM -> 6:00 PM in 360 s, 1 game hour = 36 s (DEC-048, FEAT-003).
	{ Key = "Open", Duration = 360, ClockFrom = hours(8), ClockTo = hours(18), Kind = "Day" },
	-- Closing: 6:00 PM, sign CLOSED, queue still served; ends when the counter empties or at 30 s (DEC-048).
	{ Key = "Closing", Duration = 30, ClockFrom = hours(18), ClockTo = hours(18), Kind = "Day" },
	-- Summary: 15 s on day (DEC-048, FEAT-014); night summary is 20 s (FEAT-014, wave 2).
	{ Key = "Summary", Duration = 15, ClockFrom = hours(18), ClockTo = hours(18), Kind = "Any" },
	-- Night phases: keys only in wave 1 (content-data.md §3.2).
	{ Key = "Call", Duration = 0, ClockFrom = 0, ClockTo = 0, Kind = "Night" },
	-- Night: 8:00 PM -> 6:00 AM (DEC-048); duration per night from Nights (DEC-127).
	{ Key = "Night", Duration = 0, ClockFrom = hours(20), ClockTo = hours(30), Kind = "Night" },
	{ Key = "NightEnd", Duration = 0, ClockFrom = 0, ClockTo = 0, Kind = "Night" },
	{ Key = "NightLost", Duration = 0, ClockFrom = 0, ClockTo = 0, Kind = "Night" },
	{ Key = "Finale", Duration = 0, ClockFrom = 0, ClockTo = 0, Kind = "Night" },
	{ Key = "RunEnd", Duration = 0, ClockFrom = 0, ClockTo = 0, Kind = "Any" },
} :: { Phase })

return Table.with(base, {
	PhaseKeys = base.Keys,
	ClockStepMinutes = 10, -- HUD updates every 10 game minutes (6 s real on day) (DEC-048)
})
