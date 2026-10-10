--!strict
-- Shift phases (content-data.md §3.2; DEC-048, DEC-080). Keys are wire enum values (Shift.Phase), PascalCase by
-- rule §1.3. PhaseKeys is complete from wave 1 so Net does not change in wave 2.
-- STUB (TASK-003): day numbers from content-data.md v4; night phases have keys only (durations from Nights,
-- wave 2). Reviewed in TASK-008.
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
	{ Key = "Resume", Duration = 15, ClockFrom = 0, ClockTo = 0, Kind = "Any" },
	{ Key = "Intro", Duration = 0, ClockFrom = 0, ClockTo = 0, Kind = "Any" },
	{ Key = "Prep", Duration = 60, ClockFrom = hours(7), ClockTo = hours(8), Kind = "Any" },
	{ Key = "Open", Duration = 360, ClockFrom = hours(8), ClockTo = hours(18), Kind = "Day" },
	{ Key = "Closing", Duration = 30, ClockFrom = hours(18), ClockTo = hours(18), Kind = "Day" },
	{ Key = "Summary", Duration = 15, ClockFrom = hours(18), ClockTo = hours(18), Kind = "Any" },
	{ Key = "Call", Duration = 0, ClockFrom = 0, ClockTo = 0, Kind = "Night" },
	{ Key = "Night", Duration = 0, ClockFrom = hours(20), ClockTo = hours(30), Kind = "Night" }, -- 20:00 -> 06:00
	{ Key = "NightEnd", Duration = 0, ClockFrom = 0, ClockTo = 0, Kind = "Night" },
	{ Key = "NightLost", Duration = 0, ClockFrom = 0, ClockTo = 0, Kind = "Night" },
	{ Key = "Finale", Duration = 0, ClockFrom = 0, ClockTo = 0, Kind = "Night" },
	{ Key = "RunEnd", Duration = 0, ClockFrom = 0, ClockTo = 0, Kind = "Any" },
} :: { Phase })

return Table.with(base, {
	PhaseKeys = base.Keys,
	ClockStepMinutes = 10, -- DEC-048
})
