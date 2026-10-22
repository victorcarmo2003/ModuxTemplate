--!strict
-- AnomalyService/Pressure: low sanity brings more of the night (DEC-352, Provisional; Content.Sanity.Tiers, .Pressure).
-- Server-authoritative; the clients only present what it sends. Night phase only, never under the tutorial hold.
--
--   Personal scares   each Active player in a tier with Scare {min, max} gets family D scares of his own
--                     (HallucinationService:Scare(player)), the first Pressure.FirstScare s after entering the tier, then
--                     every min..max s. A scare is never sent while the night scheduler's scare gap holds (NextScareAt),
--                     so the shared scares and the personal ones never pile up. Family D: no verb, no damage, never an
--                     anomaly seen (DEC-254, DEC-256).
--   Extra anomalies   every Pressure.Every s the crew's average sanity picks a tier; with chance Tier.Extra one more
--                     regular entry of tonight's pool (same draw weights as the agenda) is queued Pressure.Lead game
--                     minutes ahead. It is an ordinary agenda entry: Admit (MinGap, MaxSimultaneous, actor cap,
--                     ExclusiveWith), the grace, the shut window and the end of the window treat it like any other, so
--                     the rules of every anomaly (what is right, what is wrong) do not change. At most Pressure.MaxExtra
--                     per night, none before Pressure.FromNight.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local SanityTier = require(ReplicatedStorage.shared.Anomaly.SanityTier)
local Scheduler = require(script.Parent.Scheduler)

const TIERS = Content.Sanity.Tiers
const RULES = Content.Sanity.Pressure
-- Slot of an extra entry (seeds its occurrence): above any regular slot of a night
const EXTRA_SLOT = 200

export type State = {
	Night: number,
	-- tonight's draw pool (keys and parallel weights), as the agenda saw it
	Pool: { string },
	Weights: { number },
	Random: Random,
	-- server time of the next extra roll (0 = not started)
	NextRollAt: number,
	Extra: number,
	-- per UserId: tier index the scare timer belongs to, and server time of the next personal scare
	ScareTier: { [number]: number },
	NextScare: { [number]: number },
}

-- What Pressure needs of the service (AnomalyService passes itself)
export type Host = {
	ActivePlayers: (self: any) -> { Player },
	SanityOf: (self: any, player: Player) -> (number, number),
	Scare: (self: any, player: Player) -> (),
	ScareGapUntil: (self: any) -> number,
	Queued: (self: any) -> { Scheduler.Entry },
	Enqueue: (self: any, entry: Scheduler.Entry) -> (),
}

const Pressure = {}

Pressure.EXTRA_SLOT = EXTRA_SLOT

function Pressure.new(): State
	return {
		Night = 0,
		Pool = {},
		Weights = {},
		Random = Random.new(),
		NextRollAt = 0,
		Extra = 0,
		ScareTier = {},
		NextScare = {},
	}
end

-- A new night shift: tonight's pool from the agenda's input (Scheduler.Eligible + Scheduler.Weight, the same filter).
function Pressure.reset(state: State, input: Scheduler.Input, seed: number)
	state.Night = input.Night
	state.Pool = {}
	state.Weights = {}
	state.Random = Random.new(seed)
	state.NextRollAt = 0
	state.Extra = 0
	state.ScareTier = {}
	state.NextScare = {}
	for _, row in input.Anomalies do
		if not Scheduler.Eligible(row, input) then
			continue
		end
		const weight = Scheduler.Weight(row.Night, input.Night, input.Occurrences)
		if weight > 0 then
			table.insert(state.Pool, row.Key)
			table.insert(state.Weights, weight)
		end
	end
end

local function between(random: Random, range: { number }): number
	return random:NextNumber(range[1], range[2] or range[1])
end

-- Personal family D scares by each player's own tier.
function Pressure.scares(state: State, host: Host, t: number)
	const seen: { [number]: boolean } = {}
	for _, player in host:ActivePlayers() do
		const userId = player.UserId
		seen[userId] = true
		const value, max = host:SanityOf(player)
		const index = SanityTier.index(value, max)
		const range = TIERS[index].Scare
		if #range == 0 then
			state.ScareTier[userId] = nil
			state.NextScare[userId] = nil
			continue
		end
		if state.ScareTier[userId] ~= index then
			-- entering a scare tier (or moving between two): the first one comes soon, then the tier's pace
			state.ScareTier[userId] = index
			const first = t + RULES.FirstScare
			const current = state.NextScare[userId]
			state.NextScare[userId] = if current ~= nil then math.min(current, first) else first
			continue
		end
		if t < (state.NextScare[userId] or math.huge) or t < host:ScareGapUntil() then
			continue
		end
		state.NextScare[userId] = t + between(state.Random, range)
		host:Scare(player)
	end
	for userId in state.NextScare do
		if not seen[userId] then
			state.NextScare[userId] = nil
			state.ScareTier[userId] = nil
		end
	end
end

-- Tier of the crew: the average sanity of the Active players that have sanity (max > 0).
function Pressure.crewTier(host: Host): number
	local sum, count = 0, 0
	for _, player in host:ActivePlayers() do
		const value, max = host:SanityOf(player)
		if max > 0 then
			sum += value
			count += 1
		end
	end
	if count == 0 then
		return 1
	end
	return SanityTier.index(sum / count, 1)
end

-- Extra regular anomalies by the crew's tier. Returns the key queued, nil when none.
function Pressure.extra(state: State, host: Host, t: number, minutes: number, windowEnd: number): string?
	if state.Night < RULES.FromNight or state.Extra >= RULES.MaxExtra or #state.Pool == 0 then
		return nil
	end
	if state.NextRollAt == 0 then
		state.NextRollAt = t + RULES.Every
		return nil
	end
	if t < state.NextRollAt then
		return nil
	end
	state.NextRollAt = t + RULES.Every
	const at = minutes + RULES.Lead
	if at >= windowEnd then
		return nil
	end
	const chance = TIERS[Pressure.crewTier(host)].Extra
	if chance <= 0 or state.Random:NextNumber() >= chance then
		return nil
	end
	-- avoid what is still waiting in the queue or running (Admit would refuse "same" anyway)
	const avoid: { string } = {}
	for _, entry in host:Queued() do
		table.insert(avoid, entry.Key)
	end
	const key = Scheduler.Draw(state.Pool, state.Weights, avoid, function(): number
		return state.Random:NextNumber()
	end)
	state.Extra += 1
	host:Enqueue({ Key = key, At = at, Scripted = false, Slot = EXTRA_SLOT + state.Extra, Premiere = false, Night = false })
	return key
end

-- Dev: the next extra roll and every personal scare due now.
function Pressure.hurry(state: State, t: number)
	if state.NextRollAt ~= 0 then
		state.NextRollAt = t
	end
	for userId in state.NextScare do
		state.NextScare[userId] = t
	end
end

-- Dev line: tier of each Active player, next personal scare, extras tonight.
function Pressure.describe(state: State, host: Host, t: number): string
	const lines: { string } = {}
	for _, player in host:ActivePlayers() do
		const value, max = host:SanityOf(player)
		const tier = SanityTier.of(value, max)
		const nextAt = state.NextScare[player.UserId]
		table.insert(
			lines,
			`{player.Name}: {value}/{max} {tier.Key}{if nextAt then string.format(", scare in %.0fs", math.max(0, nextAt - t)) else ""}`
		)
	end
	if #lines == 0 then
		table.insert(lines, "no Active player")
	end
	table.insert(
		lines,
		`crew tier {TIERS[Pressure.crewTier(host)].Key}; extra anomalies {state.Extra}/{RULES.MaxExtra} (night {state.Night}, from {RULES.FromNight}); pool {#state.Pool}`
	)
	return table.concat(lines, "\n")
end

return table.freeze(Pressure)
