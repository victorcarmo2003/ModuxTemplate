--!strict
-- The ten nights (content-data.md §6.3; FEAT-003, FEAT-009, FEAT-022; DEC-060, DEC-073, DEC-127).
-- Owner: game-designer (numbers) + narrative-writer (calls live in BossCalls). Not a wire enum (no Keys on the wire).
-- Duration = real seconds of the Night phase (8 PM -> 6 AM), increasing (DEC-127). Shortened with the new run flow
-- (user request 2026-10-12, Provisional Q-207): nights now follow a day shift from Day 2, so Night 1 is ~9 min and the
-- length grows 40 s per night to ~15 min on Night 10 (was 20 -> 30 min). MinGap and MaxSimultaneous did not change:
-- the agenda still fits (N10: 14 starts in a 720 s window, ~51 s per slot, MinGap 25 s).
-- NewAnomaly = key of Anomalies (wave 3 table, TASK-096 checks the reference); here only the key pattern is checked.
-- Call / ShortCall = keys of BossCalls (Trigger NightCall for this night / the single NightRepeat call).
-- Customers.BaseInterval = seconds between spawns at night, solo (40 N1-5, 36 N6-10; Provisional, TASK-081, FEAT-009);
-- Max = Flow.MaxCustomersNight.
-- Windows (game minutes since 0:00 of the shift day): Calm 8-9 PM, Shift 9 PM-5 AM, Last 5-6 AM (FEAT-003). Not
-- phases: RoundService:NightWindow() derives them from the clock.
-- Occurrences: weight of an anomaly by age (Premiere = debut night, Recent = 1-2 nights after, Old = older;
-- progression.md §4.2).
local Flow = require(script.Parent.Flow)
local Table = require(script.Parent.Table)

export type Customers = {
	BaseInterval: number,
	Max: number,
}

export type Night = {
	Key: string, -- night_<k>
	Index: number, -- 1..RunParams.Nights
	Duration: number,
	NewAnomaly: string,
	Call: string,
	ShortCall: string,
	MaxSimultaneous: number,
	MinGap: number, -- seconds between two anomaly starts
	Customers: Customers,
}

export type Windows = {
	Calm: { number },
	Shift: { number },
	Last: { number },
}

export type Occurrences = {
	Premiere: number,
	Recent: number,
	Old: number,
}

local function night(
	index: number,
	duration: number,
	anomaly: string,
	maxSimultaneous: number,
	minGap: number,
	interval: number
): Night
	return {
		Key = `night_{index}`,
		Index = index,
		Duration = duration,
		NewAnomaly = anomaly,
		Call = `call_night_{index}`,
		ShortCall = "call_night_short",
		MaxSimultaneous = maxSimultaneous,
		MinGap = minGap,
		Customers = { BaseInterval = interval, Max = Flow.MaxCustomersNight },
	}
end

const base = Table.new({
	-- Duration 540 s + 40 s per night (2026-10-12; DEC-127 shape, was 1200..1800); MaxSimultaneous and MinGap FEAT-022;
	-- interval FEAT-009 (40 s / 36 s, Provisional, TASK-081). Nights 1-2 are always in the cart and only have
	-- anomalies with Trailer None (blank folks: refuse, wrong food: discard).
	night(1, 540, "anm_001_blank_folks", 1, 60, 40),
	night(2, 580, "anm_002_wrong_food", 1, 60, 40),
	night(3, 620, "anm_003_stopped_clock", 1, 60, 40),
	night(4, 660, "anm_004_copies", 2, 60, 40),
	night(5, 700, "anm_005_raincoat_lady", 2, 40, 40),
	night(6, 740, "anm_006_wavers", 2, 40, 36),
	night(7, 780, "anm_007_walker", 2, 40, 36),
	night(8, 820, "anm_008_long_car", 3, 25, 36),
	night(9, 860, "anm_009_knock", 3, 25, 36),
	night(10, 900, "anm_010_hush", 3, 25, 36),
} :: { Night })

const windows: Windows = {
	Calm = { 1200, 1260 }, -- 8:00 -> 9:00 PM
	Shift = { 1260, 1740 }, -- 9:00 PM -> 5:00 AM
	Last = { 1740, 1800 }, -- 5:00 -> 6:00 AM
}

const occurrences: Occurrences = {
	Premiere = 3,
	Recent = 2,
	Old = 1,
}

return Table.with(base, {
	Windows = Table.record(windows),
	Occurrences = Table.record(occurrences),
})
