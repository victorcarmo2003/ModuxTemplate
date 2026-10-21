--!strict
-- AnomalyService/Behind: "behind you" (owner 2026-10-21, Provisional; Content.Nights.Behind). While a player cooks with
-- the back to the window and the night is calm, one of the behind_* family D scares plays on that player's client only
-- (HallucinationService:Scare, scripted key): steps, a creak or taps on the glass right behind them. No verb, no cost, not a beat.
-- Night phase only, never under the tutorial hold or the grace (StepAgenda does not call it then).
const ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

const RULES = Content.Nights.Behind
const WAIT_CALM = 4 -- s before asking again when the night is not calm
const WAIT_PLAYER = 1 -- s before asking again when nobody faces away (posture changes fast)

export type State = {
	Night: number,
	Random: Random,
	-- server time of the next try (0 = not started)
	NextAt: number,
	Count: number,
	-- key of the last one played, never twice in a row
	Last: string,
}

-- What Behind needs of the service (AnomalyService passes itself)
export type Host = {
	BehindCalm: (self: any) -> boolean,
	BehindTargets: (self: any) -> { Player },
	BehindScare: (self: any, player: Player, key: string) -> number,
}

const Behind = {}

function Behind.new(): State
	return { Night = 0, Random = Random.new(), NextAt = 0, Count = 0, Last = "" }
end

function Behind.reset(state: State, night: number, seed: number)
	state.Night = night
	state.Random = Random.new(seed)
	state.NextAt = 0
	state.Count = 0
	state.Last = ""
end

function Behind.limit(state: State): number
	if state.Night < RULES.FromNight then
		return 0
	end
	const list = RULES.PerNight
	return list[math.clamp(state.Night, 1, #list)] or 0
end

local function between(random: Random): number
	return random:NextNumber(RULES.Every[1], RULES.Every[2] or RULES.Every[1])
end

-- Returns true when one was sent now.
function Behind.step(state: State, host: Host, t: number): boolean
	if state.Count >= Behind.limit(state) then
		return false
	end
	if state.NextAt == 0 then
		state.NextAt = t + between(state.Random)
		return false
	end
	if t < state.NextAt then
		return false
	end
	if not host:BehindCalm() then
		state.NextAt = t + WAIT_CALM
		return false
	end
	const targets = host:BehindTargets()
	if #targets == 0 then
		state.NextAt = t + WAIT_PLAYER
		return false
	end
	const player = targets[state.Random:NextInteger(1, #targets)]
	const keys: { string } = {}
	for _, key in RULES.Keys do
		if key ~= state.Last or #RULES.Keys == 1 then
			table.insert(keys, key)
		end
	end
	const key = keys[state.Random:NextInteger(1, #keys)]
	if host:BehindScare(player, key) <= 0 then
		state.NextAt = t + WAIT_PLAYER
		return false
	end
	state.Last = key
	state.Count += 1
	state.NextAt = t + between(state.Random)
	return true
end

-- Dev: the next one is due now (it still waits for a calm moment and a player facing away)
function Behind.hurry(state: State, t: number)
	state.NextAt = t
	if state.Count >= Behind.limit(state) then
		state.Count = math.max(0, Behind.limit(state) - 1)
	end
end

function Behind.describe(state: State, t: number): string
	const next = if state.NextAt == 0 then "not started" else string.format("in %.0fs", math.max(0, state.NextAt - t))
	return `behind you {state.Count}/{Behind.limit(state)} (night {state.Night}); next try {next}; last '{state.Last}'`
end

return table.freeze(Behind)
