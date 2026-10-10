--!strict
-- AnomalyService/Scheduler: the night's anomaly agenda (architecture.md §19.13; FEAT-022; progression.md §4.2;
-- npcs.md "Exclusões do agendador"; DEC-025, DEC-045, DEC-060; TASK-106). Pure: no require, no Roblox service, no
-- global Random. Data comes in through Input (built by the service from Content) and draws through a `random`
-- function returning [0, 1), so it runs as is in lune: the same input and the same random stream give the same
-- agenda.
--
-- Build (once per night shift, recomputed at every ShiftStarted; not in the snapshot, data.md §2.2):
--   active      anomalies with debut Night <= N, in Content order (DEC-025); which ones is never drawn (DEC-060)
--   count       debut night Occurrences.Premiere (3), 1-2 nights later Recent (2), older Old (1)
--   scripted    an anomaly whose Scripted.Night is N gets one fixed entry at Scripted.Clock (outside the window) in
--               place of one of its regular ones (N10: 2 regular + 5:45 AM; N7 on Night 10: only the 5:45 AM one,
--               FEAT-024, progression.md §4.2 = 14 on Night 10)
--   times       window Nights.Windows.Shift (9 PM-5 AM, game minutes) cut in n equal slots, one start per slot,
--               jittered so two starts are always >= MinGap real seconds apart (MinGap x minutes per second)
--   order       entries shuffled over the slots; the debut's first entry goes to a slot inside the first third of
--               the window (FEAT-022: the player has just heard the rule)
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
}

export type Counts = { Premiere: number, Recent: number, Old: number }

export type Input = {
	Night: number,
	-- active anomalies of this night, Content order
	Anomalies: { Candidate },
	Occurrences: Counts,
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

-- Occurrences of an anomaly on night `night` (progression.md §4.2).
function Scheduler.Count(debut: number, night: number, counts: Counts): number
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

local function shuffle(list: { string }, random: () -> number)
	for index = #list, 2, -1 do
		const other = math.floor(random() * index) + 1
		list[index], list[other] = list[other], list[index]
	end
end

-- Agenda of the night, sorted by At (scripted entries last at equal minute).
function Scheduler.Build(input: Input, random: () -> number): { Entry }
	const out: { Entry } = {}
	const regular: { string } = {}
	local premiere: string? = nil
	for _, row in input.Anomalies do
		if row.Night > input.Night then
			continue
		end
		local count = Scheduler.Count(row.Night, input.Night, input.Occurrences)
		const scripted = row.Scripted
		if scripted ~= nil and scripted.Night == input.Night then
			table.insert(out, { Key = row.Key, At = scripted.Clock, Scripted = true, Slot = 0 })
			count -= 1
		end
		for _ = 1, count do
			table.insert(regular, row.Key)
		end
		if row.Night == input.Night and count > 0 then
			premiere = row.Key
		end
	end

	const n = #regular
	if n > 0 then
		shuffle(regular, random)
		const from, to = input.Window[1], input.Window[2]
		const length = math.max(to - from, 0)
		const slot = length / n
		const gap = math.min(math.max(input.MinGap, 0) * math.max(input.MinutesPerSecond, 0), slot)
		const times: { number } = {}
		for index = 1, n do
			times[index] = from + (index - 1) * slot + random() * (slot - gap)
		end
		-- the debut's first entry inside the first third of the window
		if premiere ~= nil then
			const third = from + length / 3
			const eligible: { number } = {}
			for index = 1, n do
				if times[index] < third then
					table.insert(eligible, index)
				end
			end
			const target = if #eligible > 0 then eligible[math.floor(random() * #eligible) + 1] else 1
			local first = 0
			for index = 1, n do
				if regular[index] == premiere then
					first = index
					break
				end
			end
			if first > target then
				regular[first], regular[target] = regular[target], regular[first]
			end
		end
		for index = 1, n do
			table.insert(out, { Key = regular[index], At = times[index], Scripted = false, Slot = index })
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
