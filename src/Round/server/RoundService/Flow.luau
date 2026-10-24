--!strict
-- Pure run flow (architecture.md §19.4; FEAT-002, FEAT-003, FEAT-017, FEAT-026, FEAT-027; DEC-084, DEC-127).
-- No Roblox API, no Content require: the RoundService passes the rows and numbers in, so this file runs in lune.
-- Phases that end in a decision the service owns (Night -> verdict, Summary -> shift boundary, NightLost -> chance,
-- RunEnd -> reset/lobby) have no fixed next phase here: After returns nil for them.

export type Info = { Day: number, Night: number, IsNight: boolean, Attempt: number }

export type Override = { Duration: number, ClockFrom: number, ClockTo: number, Min: number?, LastCall: boolean? }

-- Subset of Content.Shift rows that the flow reads
export type Row = {
	Duration: number,
	ClockFrom: number,
	ClockTo: number,
	SkipWithoutProbe: boolean,
	Night: Override?,
}

export type Timing = { Duration: number, ClockFrom: number, ClockTo: number }

export type Window = "Calm" | "Shift" | "Last"
export type Windows = { Calm: { number }, Shift: { number }, Last: { number } }

-- Phases a probe may end early (architecture.md §19.4 "Termina"). Night only ends on its cap or LoseNight.
const PROBED: { [string]: boolean } = { Call = true, Closing = true, Finale = true, Resume = true }
-- Phases where a night can still be lost (LoseNight)
const LOSABLE: { [string]: boolean } = { Call = true, Prep = true, Night = true }
const MAX_SKIPS = 8 -- guard against a skip loop on a broken table

const Flow = {}

-- Next shift at the boundary (end of Summary). Calendar (DEC-360): the run is nights only and starts at night, no day
-- shift: N1 (Day 2), N2 (Day 3) ... N10 (Day 11), Finale. Day keeps counting one per shift (unlocks, order phases and
-- growth read it), so night k is always played on Day k + 1. Past the last night (never reached: it ends in the Finale)
-- the last night repeats.
function Flow.Next(prev: Info, lastNight: number, maxDay: number): Info
	return {
		Day = math.min(prev.Day + 1, maxDay),
		Night = math.min(prev.Night + 1, lastNight),
		IsNight = true,
		Attempt = 0,
	}
end

-- Day on which night k is played
function Flow.DayOfNight(night: number): number
	return night + 1
end

-- Shift played on `day` (clamped): Day d is Night d - 1; Day 1 (no shift since DEC-360) is Night 1 too
function Flow.OfDay(day: number, lastNight: number): Info
	const night = math.clamp(day - 1, 1, lastNight)
	return { Day = math.max(day, Flow.DayOfNight(night)), Night = night, IsNight = true, Attempt = 0 }
end

-- First shift of a new run: Night 1 on Day 2 (DEC-300, DEC-360: the run always starts at night)
function Flow.Start(): Info
	return Flow.OfDay(Flow.DayOfNight(1), 1)
end

-- The run's first shift (Night 1): PriceParty is fixed at its end (DEC-121)
function Flow.IsFirst(info: Info): boolean
	return info.IsNight and info.Night <= 1
end

-- First phase of a shift: a night opens with the boss call, a day with Prep
function Flow.First(info: Info): string
	return if info.IsNight then "Call" else "Prep"
end

-- Fixed successor of a phase, nil when the service decides (Night, Summary, NightLost, RunEnd)
function Flow.After(phase: string, info: Info, lastNight: number): string?
	if phase == "Call" then
		return "Prep"
	elseif phase == "Resume" then
		return Flow.First(info)
	elseif phase == "Prep" then
		return if info.IsNight then "Night" else "Open"
	elseif phase == "Open" then
		return "Closing"
	elseif phase == "NightEnd" then
		-- The last night has no Closing/Summary: straight to the finale (FEAT-027)
		return if info.Night >= lastNight then "Finale" else "Closing"
	elseif phase == "Closing" then
		return "Summary"
	elseif phase == "Finale" then
		return "RunEnd"
	end
	return nil
end

-- Walks past phases flagged SkipWithoutProbe that nobody registered a probe for (§19.0 rule 4)
function Flow.Resolve(
	phase: string,
	info: Info,
	lastNight: number,
	rowOf: (string) -> Row?,
	hasProbe: (string) -> boolean
): string
	local current = phase
	for _ = 1, MAX_SKIPS do
		const row = rowOf(current)
		if row == nil or not row.SkipWithoutProbe or hasProbe(current) then
			return current
		end
		const nextPhase = Flow.After(current, info, lastNight)
		if nextPhase == nil then
			return current
		end
		current = nextPhase
	end
	return current
end

-- Duration and clock of a phase on this shift: night override on a night shift, Night length from Nights[k]
function Flow.Timing(phase: string, row: Row, isNight: boolean, nightDuration: number): Timing
	if phase == "Night" then
		return { Duration = nightDuration, ClockFrom = row.ClockFrom, ClockTo = row.ClockTo }
	end
	const override = row.Night
	if isNight and override then
		return { Duration = override.Duration, ClockFrom = override.ClockFrom, ClockTo = override.ClockTo }
	end
	return { Duration = row.Duration, ClockFrom = row.ClockFrom, ClockTo = row.ClockTo }
end

-- Rows with ClockFrom = ClockTo = 0 hold the clock of the previous phase (Resume, NightLost, RunEnd)
function Flow.HoldsClock(timing: Timing): boolean
	return timing.ClockFrom == 0 and timing.ClockTo == 0
end

-- Game minutes after `elapsed` seconds of a phase (network.md §3.1, without the 10 min floor)
function Flow.Clock(timing: Timing, elapsed: number): number
	if timing.Duration <= 0 then
		return timing.ClockFrom
	end
	const alpha = math.clamp(elapsed / timing.Duration, 0, 1)
	return timing.ClockFrom + (timing.ClockTo - timing.ClockFrom) * alpha
end

-- Night window from the clock (FEAT-003): [from, to) each; Last also includes 6:00 AM itself
function Flow.Window(minutes: number, windows: Windows): Window?
	if minutes >= windows.Calm[1] and minutes < windows.Calm[2] then
		return "Calm"
	elseif minutes >= windows.Shift[1] and minutes < windows.Shift[2] then
		return "Shift"
	elseif minutes >= windows.Last[1] and minutes <= windows.Last[2] then
		return "Last"
	end
	return nil
end

function Flow.CanProbe(phase: string): boolean
	return PROBED[phase] == true
end

function Flow.CanLose(phase: string, info: Info): boolean
	return info.IsNight and LOSABLE[phase] == true
end

return table.freeze(Flow)
