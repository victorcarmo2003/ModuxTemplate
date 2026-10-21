--!strict
-- The ten nights (content-data.md §6.3; FEAT-003, FEAT-009, FEAT-022; DEC-060, DEC-073, DEC-127).
-- Owner: game-designer (numbers) + narrative-writer (calls live in BossCalls). Not a wire enum (no Keys on the wire).
-- Duration = real seconds of the Night phase (8 PM -> 6 AM), increasing (DEC-127). Shortened with the new run flow
-- (user request 2026-10-12, Provisional Q-207), then cut 60% (owner 2026-10-21, Provisional): Night 1 is 3.6 min and the
-- length grows 16 s per night to 6 min on Night 10 (was 9 -> 15 min). Owner 2026-10-21 (gameplay review phase 1,
-- Provisional): Events and Scares rescaled to the short nights (they had kept the 9-15 min counts: one beat every
-- 16-20 s against the ~45-55 s aim of TASK-341) and MinGap raised; every anomaly still debuts and stays in the draw,
-- only the repeats drop.
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
	-- Duration 216 s + 16 s per night (owner 2026-10-21, 60% cut of 540 + 40; DEC-127 shape, was 1200..1800); MaxSimultaneous and MinGap FEAT-022;
	-- interval FEAT-009 (40 s / 36 s, Provisional, TASK-081). V2 columns (TASK-271): new anomaly, families,
	-- atmosphere (ATM-1 normal, 2 pitch dark, 3 red fog, 4 rain, 5 storm, 6 white fog, 7 blood moon), events, scares.
	-- Validate checks that Events x MinGap fits the Shift window of the night.
	-- TASK-341 (owner 2026-10-15, Provisional; anomalies-v2-proposal.md §8): D opens on Night 1 (environment scares from
	-- the first night), the blackout is presented on Night 3 (was 4, swapped with the turned neck), more events and
	-- scares on Nights 1-5 and one more event on Nights 6-9 so the curve keeps rising.
	-- Owner 2026-10-21 (Provisional, gameplay review phase 1): events 4,6,6,7,7,8,8,9,10,12 -> 2,3,4,4,5,6,6,7,8,8;
	-- scares 4,4,4,5,5,5,5,6,6,6 -> 3,3,3,4,4,4,4,5,5,5; MinGap 30..22 -> 40..30 s
	night(1, 216, "anm_001_blank_folks", { "A", "D" }, "ATM-1", 2, 3, 1, 40, 40),
	night(2, 232, "anm_011_shaker", { "A", "D" }, "ATM-1", 3, 3, 1, 40, 40),
	night(3, 248, "anm_020_blackout", { "A", "C", "D" }, "ATM-2", 4, 3, 1, 40, 40),
	night(4, 264, "anm_012_turned_neck", { "A", "C", "D" }, "ATM-4", 4, 4, 2, 38, 40),
	night(5, 280, "anm_013_white_eyes", { "A", "C", "D" }, "ATM-6", 5, 4, 2, 38, 40),
	night(6, 296, "anm_014_big_head", { "A", "B", "C", "D" }, "ATM-3", 6, 4, 2, 35, 36),
	night(7, 312, "anm_017_crawler", { "A", "B", "C", "D" }, "ATM-5", 6, 4, 2, 35, 36),
	night(8, 328, "anm_008_long_car", { "A", "B", "C", "D" }, "ATM-2", 7, 5, 3, 32, 36),
	night(9, 344, "anm_019_roof_walker", { "A", "B", "C", "D" }, "ATM-3", 8, 5, 3, 32, 36),
	night(10, 360, "anm_010_hush", { "A", "B", "C", "D" }, "ATM-7", 8, 5, 3, 30, 36),
} :: { Night })

const windows: Windows = {
	Calm = { 1200, 1260 }, -- 8:00 -> 9:00 PM
	Shift = { 1260, 1740 }, -- 9:00 PM -> 5:00 AM
	Last = { 1740, 1800 }, -- 5:00 -> 6:00 AM
}

-- Owner 2026-10-19 (Provisional): the first nights let the player learn the kitchen before the fear. No regular anomaly
-- starts before this game minute of these nights (the ones due earlier wait for it); the scripted ones are not held.
-- Owner 2026-10-20 (Provisional, Q-415): the grace now holds only the anomalies that punish (regular events); the
-- family D scares (no verb, no cost) play from 8 PM (ScaresFrom), and the presented premiere keeps its fixed time
-- (PremiereAt), so Night 1 is never silent for its first minutes.
const grace: { [number]: number } = {
	[1] = 1380, -- Night 1: 11:00 PM
	[2] = 1320, -- Night 2: 10:00 PM
}

-- Owner 2026-10-20 (Provisional, Q-415): game minute of the presented anomaly's debut (NewAnomaly) on these nights,
-- instead of a drawn slot: right after the call presented it. Not held by the grace (the tutorial still holds it).
const premiereAt: { [number]: number } = {
	[1] = 1350, -- Night 1: 10:30 PM (~54 s in, after the opening), anm_001_blank_folks
}

-- Owner 2026-10-20 (Provisional, Q-415): the scripted opening of these nights, a family D key (Content.Hallucinations,
-- Scripted) played for everyone as the Night phase starts (first attempt only); no verb, no sanity cost. The drawn scares
-- of the night start after Until (game minute) so they never land on top of it.
export type Opening = { Key: string, Until: number }
const opening: { [number]: Opening } = {
	[1] = { Key = "night_opening", Until = 1325 }, -- ~45 s of Night 1 (216 s for 600 min)
}

-- Owner 2026-10-20 (Provisional, Q-415): game minute the family D scares window opens (was Windows.Shift[1], 9 PM)
const scaresFrom = 1200 -- 8:00 PM

const occurrences: Occurrences = {
	Premiere = 3,
	Recent = 2,
	Old = 1,
}

-- DEC-320 (Q-413, Provisional): extra regular anomaly events of a night by the crew connected at its start (1..4 players):
-- +1 with 3, +2 with 4 (more eyes make every anomaly easier)
const crewEvents: { number } = { 0, 0, 1, 2 }

return Table.with(base, {
	Windows = Table.record(windows),
	Grace = table.freeze(grace),
	PremiereAt = table.freeze(premiereAt),
	Opening = table.freeze(opening),
	ScaresFrom = scaresFrom,
	CrewEvents = table.freeze(crewEvents),
	Occurrences = Table.record(occurrences),
})
