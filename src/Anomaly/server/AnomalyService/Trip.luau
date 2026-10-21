--!strict
-- AnomalyService/Trip: the breaker trips by itself (owner request 2026-10-21, Q-435, Provisional; Content.Breaker).
-- Server-authoritative. Night phase only, never under the tutorial hold or the grace (StepAgenda does not call it then).
-- Not an anomaly: no occurrence, no record, no verb check. LightService:TripBreaker() puts the power out and the breaker
-- outside (breaker_reset) brings it back, exactly as after the ANM-020 attack. A busy moment (an anomaly running, the
-- power already out, the bulb burnt) waits Breaker.Retry s, so a trip never lands on top of an anomaly's answer.
const ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

const RULES = Content.Breaker

export type State = {
	Night: number,
	Random: Random,
	-- server time of the next trip (0 = not started)
	NextAt: number,
	Count: number,
}

-- What Trip needs of the service (AnomalyService passes itself)
export type Host = {
	TripBusy: (self: any) -> boolean,
	TripBreaker: (self: any) -> boolean,
}

const Trip = {}

function Trip.new(): State
	return { Night = 0, Random = Random.new(), NextAt = 0, Count = 0 }
end

function Trip.reset(state: State, night: number, seed: number)
	state.Night = night
	state.Random = Random.new(seed)
	state.NextAt = 0
	state.Count = 0
end

-- Trips allowed tonight
function Trip.limit(state: State): number
	if state.Night < RULES.FromNight then
		return 0
	end
	const list = RULES.PerNight
	return list[math.clamp(state.Night, 1, #list)] or 0
end

local function between(random: Random): number
	return random:NextNumber(RULES.Every[1], RULES.Every[2] or RULES.Every[1])
end

-- Returns true when it tripped now.
function Trip.step(state: State, host: Host, t: number): boolean
	if state.Count >= Trip.limit(state) then
		return false
	end
	if state.NextAt == 0 then
		state.NextAt = t + between(state.Random)
		return false
	end
	if t < state.NextAt then
		return false
	end
	if host:TripBusy() or not host:TripBreaker() then
		state.NextAt = t + RULES.Retry
		return false
	end
	state.Count += 1
	state.NextAt = t + between(state.Random)
	return true
end

-- Dev: the next trip is due now (the busy check still holds)
function Trip.hurry(state: State, t: number)
	state.NextAt = t
	if state.Count >= Trip.limit(state) then
		state.Count = math.max(0, Trip.limit(state) - 1)
	end
end

function Trip.describe(state: State, t: number): string
	const next = if state.NextAt == 0 then "not started" else string.format("in %.0fs", math.max(0, state.NextAt - t))
	return `breaker trips {state.Count}/{Trip.limit(state)} (night {state.Night}, from {RULES.FromNight}); next {next}`
end

return table.freeze(Trip)
