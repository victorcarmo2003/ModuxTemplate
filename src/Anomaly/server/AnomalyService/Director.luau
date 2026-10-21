--!strict
-- AnomalyService/Director: one beat budget for the night (owner 2026-10-21, Provisional; Content.Nights.Beats;
-- design/gameplay-flow-review.md §3b). Every system that asks the crew to act asks here before it starts something:
-- the anomaly agenda (StepAgenda), the breaker trips (Trip), the chores (ChoreService) and the suspense events
-- (SuspenseService). Pure: no require, no Roblox service; the host passes the time, the crew size and the rules.
--   Gap        two beat starts are at least Gap[crew] real seconds apart
--   MaxActive  beats asking for action at once: anomalies running (counted by the host) plus the beats noted here that
--              are still on (a chore until its deadline or end, a trip for Hold s)
--   Reserve    a beat that is not an anomaly waits while a regular anomaly is due within Reserve s (the agenda first)

export type Rules = { Gap: { number }, MaxActive: { number }, Reserve: number, Hold: number }

export type State = {
	-- server time of the last beat start (0 = none tonight)
	LastAt: number,
	-- beat key -> server time it stops counting as active
	Active: { [string]: number },
}

const Director = {}

function Director.new(): State
	return { LastAt = 0, Active = {} }
end

function Director.reset(state: State)
	state.LastAt = 0
	table.clear(state.Active)
end

local function pick(list: { number }, crew: number): number
	return list[math.clamp(crew, 1, #list)] or list[#list] or 0
end

-- Beats noted here that still count at `t` (expired ones are dropped)
function Director.count(state: State, t: number): number
	local count = 0
	for key, untilAt in state.Active do
		if t >= untilAt then
			state.Active[key] = nil
		else
			count += 1
		end
	end
	return count
end

-- Can a beat start now? running = anomaly occurrences in progress; dueIn = real seconds until the next regular anomaly
-- (math.huge if none); anomaly = the asker is the agenda itself (no Reserve). Returns (ok, reason).
function Director.clear(
	state: State,
	rules: Rules,
	t: number,
	crew: number,
	running: number,
	dueIn: number,
	anomaly: boolean
): (boolean, string?)
	if state.LastAt > 0 and t - state.LastAt < pick(rules.Gap, crew) then
		return false, "gap"
	end
	if running + Director.count(state, t) >= pick(rules.MaxActive, crew) then
		return false, "active"
	end
	if not anomaly and dueIn < rules.Reserve then
		return false, "reserve"
	end
	return true, nil
end

-- A beat started now; it counts as active for `hold` s (0 = only the gap, e.g. an anomaly: the host counts it running)
function Director.begin(state: State, key: string, t: number, hold: number)
	state.LastAt = t
	if hold > 0 then
		state.Active[key] = t + hold
	end
end

-- A beat ended before its hold ran out (a chore fixed, the breaker reset)
function Director.finish(state: State, key: string)
	state.Active[key] = nil
end

function Director.describe(state: State, rules: Rules, t: number, crew: number, running: number): string
	const since = if state.LastAt > 0 then string.format("%.0fs ago", t - state.LastAt) else "none yet"
	const keys: { string } = {}
	for key in state.Active do
		table.insert(keys, key)
	end
	table.sort(keys)
	return `beats: last {since} (gap {pick(rules.Gap, crew)}s), active {running} anomalies + {Director.count(state, t)} [{table.concat(keys, ", ")}] / max {pick(rules.MaxActive, crew)} (crew {crew})`
end

return table.freeze(Director)
