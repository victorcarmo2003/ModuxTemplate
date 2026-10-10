--!strict
-- The ten nights (content-data.md §6.3; FEAT-003, FEAT-009, FEAT-022; DEC-060, DEC-073, DEC-127).
-- Owner: game-designer (numbers) + narrative-writer (calls live in BossCalls). Not a wire enum (no Keys on the wire).
-- Duration = real seconds of the Night phase (8 PM -> 6 AM), increasing (DEC-127).
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
	-- Duration DEC-127; MaxSimultaneous and MinGap FEAT-022; interval FEAT-009 (40 s / 36 s, Provisional, TASK-081)
	night(1, 1200, "anm_001_blank_folks", 1, 60, 40),
	night(2, 1260, "anm_002_wrong_food", 1, 60, 40),
	night(3, 1320, "anm_003_stopped_clock", 1, 60, 40),
	night(4, 1380, "anm_004_copies", 2, 60, 40),
	night(5, 1440, "anm_005_raincoat_lady", 2, 40, 40),
	night(6, 1560, "anm_006_wavers", 2, 40, 36),
	night(7, 1620, "anm_007_walker", 2, 40, 36),
	night(8, 1680, "anm_008_long_car", 3, 25, 36),
	night(9, 1740, "anm_009_knock", 3, 25, 36),
	night(10, 1800, "anm_010_hush", 3, 25, 36),
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
