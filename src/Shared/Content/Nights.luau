--!strict
-- The ten nights (content-data.md §6.3; FEAT-003, FEAT-009, FEAT-022; DEC-060, DEC-073, DEC-127).
-- Owner: game-designer (numbers) + narrative-writer (calls live in BossCalls). Not a wire enum (no Keys on the wire).
-- Duration = real seconds of the Night phase (8 PM -> 6 AM), increasing (DEC-127). Shortened with the new run flow
-- (user request 2026-10-12, Provisional Q-207): nights now follow a day shift from Day 2, so Night 1 is ~9 min and the
-- length grows 40 s per night to ~15 min on Night 10 (was 20 -> 30 min). MinGap and MaxSimultaneous did not change:
-- the agenda still fits (N10: 12 drawn starts + the scripted 5:45 AM in a 720 s window, 60 s per slot, MinGap 25 s).
-- Call / ShortCall = keys of BossCalls (Trigger NightCall for this night / the single NightRepeat call).
-- Customers.BaseInterval = seconds between spawns at night, solo (40 N1-5, 36 N6-10; Provisional, TASK-081, FEAT-009);
-- Max = Flow.MaxCustomersNight.
-- Windows (game minutes since 0:00 of the shift day): Calm 8-9 PM, Shift 9 PM-5 AM, Last 5-6 AM (FEAT-003). Not
-- phases: RoundService:NightWindow() derives them from the clock.
-- Occurrences: draw weight of an anomaly by age (Premiere = debut night, Recent = 1-2 nights after, Old = older;
-- progression.md §4.2; since TASK-271 a weight, no longer a count).
-- V2 night table (DEC-254, DEC-257; anomalies-v2-proposal.md §5; TASK-271; numbers Provisional, game-designer tunes):
--   Families    families open on the night (A refuse, B hide, C blackout, D scare); the scheduler draws only rows of
--               these families (Anomalies[k].Family)
--   NewAnomaly  the novelty the boss call presents (one row debuting on this night, of an open family)
--   Atmosphere  ATM-# key of Content.Atmospheres (TASK-275), fixed per night (DEC-257)
--   Events      regular anomaly occurrences of the night (scripted ones come on top), drawn by age weight from the
--               open families, never the same anomaly twice in a row
--   Scares      family D scares without a verb (HallucinationController, TASK-274); 0 when D is closed
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
	Families: { string },
	Atmosphere: string,
	Events: number,
	Scares: number,
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
	families: { string },
	atmosphere: string,
	events: number,
	scares: number,
	maxSimultaneous: number,
	minGap: number,
	interval: number
): Night
	return {
		Key = `night_{index}`,
		Index = index,
		Duration = duration,
		NewAnomaly = anomaly,
		Families = families,
		Atmosphere = atmosphere,
		Events = events,
		Scares = scares,
		Call = `call_night_{index}`,
		ShortCall = "call_night_short",
		MaxSimultaneous = maxSimultaneous,
		MinGap = minGap,
		Customers = { BaseInterval = interval, Max = Flow.MaxCustomersNight },
	}
end

const base = Table.new({
	-- Duration 540 s + 40 s per night (2026-10-12; DEC-127 shape, was 1200..1800); MaxSimultaneous and MinGap FEAT-022;
	-- interval FEAT-009 (40 s / 36 s, Provisional, TASK-081). V2 columns (TASK-271): new anomaly, families,
	-- atmosphere (ATM-1 normal, 2 pitch dark, 3 red fog, 4 rain, 5 storm, 6 white fog, 7 blood moon), events, scares.
	-- Validate checks that Events x MinGap fits the Shift window of the night.
	-- TASK-341 (owner 2026-10-15, Provisional; anomalies-v2-proposal.md §8): D opens on Night 1 (environment scares from
	-- the first night), the blackout is presented on Night 3 (was 4, swapped with the turned neck), more events and
	-- scares on Nights 1-5 and one more event on Nights 6-9 so the curve keeps rising.
	night(1, 540, "anm_001_blank_folks", { "A", "D" }, "ATM-1", 4, 4, 1, 60, 40),
	night(2, 580, "anm_011_shaker", { "A", "D" }, "ATM-1", 6, 4, 1, 50, 40),
	night(3, 620, "anm_020_blackout", { "A", "C", "D" }, "ATM-2", 6, 4, 1, 50, 40),
	night(4, 660, "anm_012_turned_neck", { "A", "C", "D" }, "ATM-4", 7, 5, 2, 45, 40),
	night(5, 700, "anm_013_white_eyes", { "A", "C", "D" }, "ATM-6", 7, 5, 2, 40, 40),
	night(6, 740, "anm_014_big_head", { "A", "B", "C", "D" }, "ATM-3", 8, 5, 2, 40, 36),
	night(7, 780, "anm_017_crawler", { "A", "B", "C", "D" }, "ATM-5", 8, 5, 2, 40, 36),
	night(8, 820, "anm_008_long_car", { "A", "B", "C", "D" }, "ATM-2", 9, 6, 3, 25, 36),
	night(9, 860, "anm_019_roof_walker", { "A", "B", "C", "D" }, "ATM-3", 10, 6, 3, 25, 36),
	night(10, 900, "anm_010_hush", { "A", "B", "C", "D" }, "ATM-7", 12, 6, 3, 25, 36),
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
