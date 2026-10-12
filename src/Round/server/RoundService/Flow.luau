--!strict
-- Pure run flow (architecture.md §19.4; FEAT-002, FEAT-003, FEAT-017, FEAT-026, FEAT-027; DEC-084, DEC-127).
-- No Roblox API, no Content require: the RoundService passes the rows and numbers in, so this file runs in lune.
-- Phases that end in a decision the service owns (Night -> verdict, Summary -> shift boundary, NightLost -> chance,
-- RunEnd -> reset/lobby) have no fixed next phase here: After returns nil for them.

export type Info = { Day: number, Night: number, IsNight: boolean, Attempt: number }

export type Override = { Duration: number, ClockFrom: number, ClockTo: number }

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
const PROBED: { [string]: boolean } = { Intro = true, Call = true, Closing = true, Finale = true, Resume = true }
-- Phases where a night can still be lost (LoseNight)
const LOSABLE: { [string]: boolean } = { Call = true, Prep = true, Night = true }
const MAX_SKIPS = 8 -- guard against a skip loop on a broken table

const Flow = {}

-- Next shift at the boundary (end of Summary). A night is followed by the next day; a day shift of Day >= firstNightDay
-- is followed by a night while nights are left, in whatever vehicle (Day D -> Night N + 1 keeps D, data.md §3.3).
-- Sequence with firstNightDay = 2: D1, D2, N1, D3, N2, ... D11, N10 (user request 2026-10-12, Q-207; was: nights only
-- with the trailer, bought on Day 5). Day 1 is the tutorial day: no night after it.
function Flow.Next(prev: Info, lastNight: number, maxDay: number, firstNightDay: number): Info
	if not prev.IsNight and prev.Day >= firstNightDay and prev.Night < lastNight then
		return { Day = prev.Day, Night = prev.Night + 1, IsNight = true, Attempt = 0 }
	end
	return { Day = math.min(prev.Day + 1, maxDay), Night = prev.Night, IsNight = false, Attempt = 0 }
end

-- Nights played before the day shift of `day` (clamped): Day d >= firstNightDay + 1 comes after Night d - firstNightDay
function Flow.NightsBefore(day: number, lastNight: number, firstNightDay: number): number
	return math.clamp(day - firstNightDay, 0, lastNight)
end

-- Day on which night k is played
function Flow.DayOfNight(night: number, firstNightDay: number): number
	return night + firstNightDay - 1
end

-- First phase of a shift: Intro only on the first shift of a new run; a night opens with the boss call
function Flow.First(info: Info, newRun: boolean): string
	if info.IsNight then
		return "Call"
	end
	return if newRun then "Intro" else "Prep"
end

-- Fixed successor of a phase, nil when the service decides (Night, Summary, NightLost, RunEnd)
function Flow.After(phase: string, info: Info, lastNight: number): string?
	if phase == "Intro" or phase == "Call" then
		return "Prep"
	elseif phase == "Resume" then
		return Flow.First(info, false)
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
