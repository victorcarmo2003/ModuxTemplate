--!strict
-- AnomalyService/Scheduler: the night's anomaly agenda (architecture.md §19.13; FEAT-022; progression.md §4.2;
-- npcs.md "Exclusões do agendador"; DEC-025, DEC-045, DEC-060; TASK-106). Pure: no require, no Roblox service, no
-- global Random. Data comes in through Input (built by the service from Content) and draws through a `random`
-- function returning [0, 1), so it runs as is in lune: the same input and the same random stream give the same
-- agenda.
--
-- Build (once per night shift, recomputed at every ShiftStarted; not in the snapshot, data.md §2.2). V2 night table
-- (DEC-254, DEC-257; anomalies-v2-proposal.md §5; TASK-271):
--   pool        anomalies with debut Night <= N whose Family is open on the night (Input.Families) and whose
--               SkipAtmospheres does not hold the night's Atmosphere; Family nil = cut from the agenda (DEC-254)
--   draws       Input.Events regular entries, each one a weighted draw from the pool by age (Weight: debut night
--               Occurrences.Premiere, 1-2 nights later Recent, older Old); never the same anomaly in two neighbouring
--               slots when the pool has another one
--   premiere    Input.Premiere (Nights[k].NewAnomaly, the boss call) gets one entry in a slot inside the first third of
--               the window (FEAT-022: the player has just heard about it), when it is in the pool
--   scripted    an anomaly whose Scripted.Night is N gets one fixed entry at Scripted.Clock (outside the window) on top
--               of the draws (N10: the Hush and the Walker at 5:45 AM, FEAT-024/027), whatever its family
--   times       window Nights.Windows.Shift (9 PM-5 AM, game minutes) cut in Events equal slots, one start per slot,
--               jittered so two starts are always >= MinGap real seconds apart (MinGap x minutes per second)
-- Admit (every time an entry is due, at runtime): MaxSimultaneous of the night, actor cap Flow.MaxActorsNight by
-- NpcCost (DEC-045), ExclusiveWith both ways, the same anomaly never twice at once, MinGap since the last start.
-- A due entry that is not admitted waits; past the end of the window it is dropped (FEAT-022: no unscripted start
-- outside 9 PM-5 AM). Scripted entries skip Admit.

export type Scripted = { Night: number, Clock: number }

-- What the scheduler needs of a Content.Anomalies row
export type Candidate = {
	Key: string,
	Night: number,
	NpcCost: number,
	ExclusiveWith: { string },
	Scripted: Scripted?,
	Family: string?, -- nil = cut from the agenda (DEC-254)
	SkipAtmospheres: { string }?,
}

export type Counts = { Premiere: number, Recent: number, Old: number }

export type Input = {
	Night: number,
	-- anomalies of the content (any debut night), Content order
	Anomalies: { Candidate },
	-- draw weights by age (Nights.Occurrences)
	Occurrences: Counts,
	-- open families of the night (Nights[k].Families)
	Families: { string },
	-- ATM-# of the night (Nights[k].Atmosphere)
	Atmosphere: string,
	-- regular entries to draw (Nights[k].Events)
	Events: number,
	-- key the boss presents (Nights[k].NewAnomaly); nil = none
	Premiere: string?,
	-- { from, to } game minutes (Nights.Windows.Shift)
	Window: { number },
	-- real seconds between two starts (Nights[k].MinGap)
	MinGap: number,
	-- game minutes per real second during the Night phase ((ClockTo - ClockFrom) / Nights[k].Duration)
	MinutesPerSecond: number,
}

-- At = game minute of the Night phase clock. Slot = index in the regular order (0 for scripted): seeds the
-- occurrence's own Random.
export type Entry = { Key: string, At: number, Scripted: boolean, Slot: number }

export type Limits = { MaxSimultaneous: number, MaxActors: number, MinGap: number }

const Scheduler = {}

-- Draw weight of an anomaly on night `night` by its age (progression.md §4.2); 0 before its debut.
function Scheduler.Weight(debut: number, night: number, counts: Counts): number
	const age = night - debut
	if age < 0 then
		return 0
	elseif age == 0 then
		return counts.Premiere
	elseif age <= 2 then
		return counts.Recent
	end
	return counts.Old
end

-- Can `row` be drawn on the night of `input`? (debut reached, family open, atmosphere not skipped)
function Scheduler.Eligible(row: Candidate, input: Input): boolean
	if row.Night > input.Night or row.Family == nil or table.find(input.Families, row.Family) == nil then
		return false
	end
	const skip = row.SkipAtmospheres
	return skip == nil or table.find(skip, input.Atmosphere) == nil
end

-- Weighted draw among `pool` (parallel `weights`), leaving out `avoid` keys while anything else has weight.
local function draw(pool: { string }, weights: { number }, avoid: { string }, random: () -> number): string
	local total = 0
	for index, key in pool do
		if table.find(avoid, key) == nil then
			total += weights[index]
		end
	end
	if total <= 0 then
		-- only avoided keys left: the rule gives way (a pool of one)
		avoid = {}
		for index in pool do
			total += weights[index]
		end
	end
	local pick = random() * total
	local last = pool[1]
	for index, key in pool do
		if table.find(avoid, key) ~= nil then
			continue
		end
		last = key
		pick -= weights[index]
		if pick < 0 then
			return key
		end
	end
	return last
end

-- Agenda of the night, sorted by At (scripted entries last at equal minute).
function Scheduler.Build(input: Input, random: () -> number): { Entry }
	const out: { Entry } = {}
	const pool: { string } = {}
	const weights: { number } = {}
	local premiere: string? = nil
	for _, row in input.Anomalies do
		const scripted = row.Scripted
		if scripted ~= nil and scripted.Night == input.Night and row.Night <= input.Night then
			table.insert(out, { Key = row.Key, At = scripted.Clock, Scripted = true, Slot = 0 })
		end
		if not Scheduler.Eligible(row, input) then
			continue
		end
		const weight = Scheduler.Weight(row.Night, input.Night, input.Occurrences)
		if weight <= 0 then
			continue
		end
		table.insert(pool, row.Key)
		table.insert(weights, weight)
		if row.Key == input.Premiere then
			premiere = row.Key
		end
	end

	const n = if #pool > 0 then math.max(math.floor(input.Events), 0) else 0
	if n > 0 then
		const from, to = input.Window[1], input.Window[2]
		const length = math.max(to - from, 0)
		const slot = length / n
		const gap = math.min(math.max(input.MinGap, 0) * math.max(input.MinutesPerSecond, 0), slot)
		const times: { number } = {}
		for index = 1, n do
			times[index] = from + (index - 1) * slot + random() * (slot - gap)
		end
		const order: { string? } = {}
		-- the presented anomaly first, in a slot inside the first third of the window
		if premiere ~= nil then
			const third = from + length / 3
			const eligible: { number } = {}
			for index = 1, n do
				if times[index] < third then
					table.insert(eligible, index)
				end
			end
			const target = if #eligible > 0 then eligible[math.floor(random() * #eligible) + 1] else 1
			order[target] = premiere
		end
		for index = 1, n do
			if order[index] ~= nil then
				continue
			end
			const avoid: { string } = {}
			const before, after = order[index - 1], order[index + 1]
			if before ~= nil then
				table.insert(avoid, before)
			end
			if after ~= nil then
				table.insert(avoid, after)
			end
			order[index] = draw(pool, weights, avoid, random)
		end
		for index = 1, n do
			table.insert(out, { Key = order[index] :: string, At = times[index], Scripted = false, Slot = index })
		end
	end

	table.sort(out, function(a: Entry, b: Entry): boolean
		if a.At ~= b.At then
			return a.At < b.At
		end
		if a.Scripted ~= b.Scripted then
			return not a.Scripted
		end
		return a.Key < b.Key
	end)
	return out
end

-- Can `candidate` start now? running = occurrences in progress; sinceLast = real seconds since the last start
-- (math.huge if none). Returns (ok, reason).
function Scheduler.Admit(
	candidate: Candidate,
	running: { Candidate },
	limits: Limits,
	sinceLast: number
): (boolean, string?)
	if sinceLast < limits.MinGap then
		return false, "gap"
	end
	if #running >= limits.MaxSimultaneous then
		return false, "simultaneous"
	end
	local actors = candidate.NpcCost
	for _, other in running do
		if other.Key == candidate.Key then
			return false, "same"
		end
		if table.find(candidate.ExclusiveWith, other.Key) ~= nil or table.find(other.ExclusiveWith, candidate.Key) ~= nil then
			return false, "exclusive"
		end
		actors += other.NpcCost
	end
	if actors > limits.MaxActors then
		return false, "actors"
	end
	return true, nil
end

-- Seed of a shift (architecture.md §4 rule 6: RunSeed, Day, Night, Attempt, domain), djb2 like CustomerService.
function Scheduler.Seed(runSeed: number, day: number, night: number, attempt: number, domain: string): number
	const text = `{runSeed}|{day}|{night}|{attempt}|{domain}`
	local h = 5381
	for index = 1, #text do
		h = (h * 33 + string.byte(text, index)) % 4294967296
	end
	return h % 2147483646 + 1
end

return table.freeze(Scheduler)
