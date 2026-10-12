--!strict
-- Which BossCalls row a trigger picks (architecture.md §19.9; content-data.md §3.19; ui-text.md §11; FEAT-018).
-- Pure lookups over Content.BossCalls and Content.Nights, built once: no Modux, no network, no state. The service
-- owns the queue, the "played" set and the phone.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

export type DayQuery = {
	Day: number,
	-- nights already played (Shift.Night of the day shift)
	Night: number,
	-- RunState.Counters.quentin_caught_day (0 = never)
	CaughtDay: number,
	Endless: boolean,
	-- last call_day_infinite_* rung (never twice in a row), "" = none
	LastInfinite: string,
	Played: { [string]: boolean },
}

const VARIANT_BASE = ""

-- Day -> variant ("" or "quentin") -> key
const byDay: { [number]: { [string]: string } } = {}
-- night k -> variant ("" or "quentin") -> key of the first day after it (call_day_after_<k>[_quentin])
const afterNight: { [number]: { [string]: string } } = {}
const infinite: { string } = {}
-- night k -> key of its NightCoffee call (Night 1)
const coffeeByNight: { [number]: string } = {}
-- action key -> hint key
const hints: { [string]: string } = {}
-- trigger kind -> first key of that kind (TrailerBought, LostCritical, LostLastChance)
const firstOfKind: { [string]: string } = {}

for _, row in Content.BossCalls.List do
	const trigger = row.Trigger
	const kind = trigger.Kind
	if kind == "DayPrep" then
		if trigger.Day ~= nil then
			const variants = byDay[trigger.Day] or {}
			byDay[trigger.Day] = variants
			variants[trigger.Variant or VARIANT_BASE] = row.Key
		elseif trigger.Night ~= nil then
			const variants = afterNight[trigger.Night] or {}
			afterNight[trigger.Night] = variants
			variants[trigger.Variant or VARIANT_BASE] = row.Key
		end
	elseif kind == "NightCoffee" and trigger.Night ~= nil then
		coffeeByNight[trigger.Night] = row.Key
	elseif kind == "DayInfinite" then
		table.insert(infinite, row.Key)
	elseif kind == "Hint" and trigger.Action ~= nil then
		hints[trigger.Action] = row.Key
	end
	if firstOfKind[kind] == nil then
		firstOfKind[kind] = row.Key
	end
end

const Calls = {}

function Calls.row(key: string): Content.BossCall?
	return Content.BossCalls.ByKey[key]
end

-- A key the phone may ring: a real row ("none" and RunOver never ring)
function Calls.isRingable(key: string): boolean
	const row = Content.BossCalls.ByKey[key]
	return row ~= nil and row.Trigger.Kind ~= "None" and row.Trigger.Kind ~= "RunOver"
end

function Calls.ofKind(kind: string): string?
	return firstOfKind[kind]
end

function Calls.hint(action: string): string?
	return hints[action]
end

-- Coffee call that follows the call of night k (nil = none)
function Calls.nightCoffee(night: number): string?
	return coffeeByNight[night]
end

-- Night k: (first-attempt call, repeated-night opener) from Content.Nights
function Calls.night(night: number): (string?, string?)
	const row = Content.Nights.List[night]
	if row == nil then
		return nil, nil
	end
	return row.Call, row.ShortCall
end

-- Prep of a day shift: the day after night k first, then the fixed day N call (quentin variant when the thief was
-- caught the day before), then the endless pool. nil = no call today.
function Calls.day(query: DayQuery, random: Random): string?
	-- The thief was caught the day before: the quentin variant of a day call (user request 2026-10-12: from Day 3 on
	-- every day follows a night, so the day-after calls carry it too)
	const quentinDay = query.CaughtDay >= 1 and query.CaughtDay == query.Day - 1
	if query.Night >= 1 then
		const afterVariants = afterNight[query.Night]
		if afterVariants ~= nil then
			-- one call per day: any variant already played closes it
			for _, key in afterVariants do
				if query.Played[key] then
					return nil
				end
			end
			return (if quentinDay then afterVariants.quentin else nil) or afterVariants[VARIANT_BASE]
		end
	end

	const variants = byDay[query.Day]
	if variants ~= nil then
		-- one call per day: any variant already played closes the day
		for _, key in variants do
			if query.Played[key] then
				return nil
			end
		end
		const quentin = variants.quentin
		if quentin ~= nil and quentinDay then
			return quentin
		end
		return variants[VARIANT_BASE]
	end

	if query.Endless and #infinite > 0 then
		const pool: { string } = {}
		for _, key in infinite do
			if key ~= query.LastInfinite then
				table.insert(pool, key)
			end
		end
		if #pool == 0 then
			return infinite[1]
		end
		return pool[random:NextInteger(1, #pool)]
	end
	return nil
end

return table.freeze(Calls)
