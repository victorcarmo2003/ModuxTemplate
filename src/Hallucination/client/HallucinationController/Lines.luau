--!strict
-- The next line of Walt's fake call / the radio (TASK-601; story/walt-calls-lore.md §7; Content.Hallucinations
-- WaltLines / RadioLines). On night N: the lines of night N not heard yet, in order; then the unheard ones of earlier
-- nights (never a later one); then a random Default line. Past night 10 (endless) straight to the earlier nights.
-- "Heard" lives in this client's memory for the run (Q-401 (a) open: per profile would need a saved field); a run
-- that starts again on a lower night forgets it, so the series restarts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

type Line = { Id: string, Text: string }
type Lines = { [any]: { Line } }

const LAST_NIGHT = 10

const Lines = {}

const heard: { [string]: boolean } = {}
local lastNight = 0

local function unheard(list: { Line }?): Line?
	if list == nil then
		return nil
	end
	for _, entry in list do
		if not heard[entry.Id] then
			return entry
		end
	end
	return nil
end

-- Picks and marks the next line of `channel` ("Walt" | "Radio") for `night`
function Lines.Next(channel: "Walt" | "Radio", night: number, rng: Random): Line?
	if night < lastNight then
		table.clear(heard) -- a new run (or back to the lobby and in again)
	end
	lastNight = night
	const pool = (if channel == "Walt" then Content.Hallucinations.WaltLines else Content.Hallucinations.RadioLines) :: Lines
	local pick: Line? = if night >= 1 and night <= LAST_NIGHT then unheard(pool[night]) else nil
	if pick == nil then
		for earlier = math.min(night - 1, LAST_NIGHT), 1, -1 do
			pick = unheard(pool[earlier])
			if pick ~= nil then
				break
			end
		end
	end
	if pick == nil then
		const default = pool.Default
		if default == nil or #default == 0 then
			return nil
		end
		return default[rng:NextInteger(1, #default)]
	end
	heard[pick.Id] = true
	return pick
end

return table.freeze(Lines)
