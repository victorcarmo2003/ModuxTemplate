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
--               the window (FEAT-022: the player has just heard about it), when it is in the pool; with
--               Input.PremiereAt (owner 2026-10-20, Provisional Q-415) it takes the first slot at that fixed minute and
--               the later slots are pushed to stay MinGap after it
--   scripted    an anomaly whose Scripted.Night is N gets one fixed entry at Scripted.Clock (outside the window) on top
--               of the draws (N10: the Hush and the Walker at 5:45 AM, FEAT-024/027), whatever its family
--   times       window Nights.Windows.Shift (9 PM-5 AM, game minutes) cut in Events equal slots, one start per slot,
--               jittered so two starts are always >= MinGap real seconds apart (MinGap x minutes per second)
--   night event owner 2026-10-22 (Provisional): exactly ONE world event per night, mandatory and above every other beat.
--               Input.NightEvent opens it: one key drawn (uniform) from the world anomalies with a verb that are open
--               tonight (families B/C/D, not Customer actors, not Scripted; Scheduler.NightPool) and one minute drawn
--               (uniform) in a safe stretch (Scheduler.NightAt: after the night's grace and the fixed premiere, early
--               enough to end before 5 AM). The entry has Night = true; the regular entries that fall within MinGap of it
--               are pushed after it. When the drawn key is the night's premiere, that premiere entry becomes the event
--               (no second entry). No pool (Night 1-2 have no B/C anomaly) = no entry: the service draws the minute with
--               NightAt and trips the breaker instead. Drawn after everything else, so the other draws never change.
--               The lock around it, the forced start and the fallback live in AnomalyService (StepNightEvent).
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
	Actor: string?, -- Content.Anomalies Actor ("Customer" is never a night event)
}

export type Counts = { Premiere: number, Recent: number, Old: number }

-- Owner 2026-10-22 (Provisional): the mandatory night event. Families = families a night event may come from (B, C, D);
-- Grace = the night's grace game minute (Nights.Grace[k]) or nil; Span = real seconds the event takes (Beats.NightSpan):
-- it must start early enough to end before the end of the Shift window.
export type NightEventInput = { Families: { string }, Grace: number?, Span: number }

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
	-- fixed game minute of the premiere (Nights.PremiereAt[k]); nil = a drawn slot in the first third
	PremiereAt: number?,
	-- the mandatory night event (owner 2026-10-22); nil = none (pure tests of the regular agenda)
	NightEvent: NightEventInput?,
	-- { from, to } game minutes (Nights.Windows.Shift)
	Window: { number },
	-- real seconds between two starts (Nights[k].MinGap)
	MinGap: number,
	-- game minutes per real second during the Night phase ((ClockTo - ClockFrom) / Nights[k].Duration)
	MinutesPerSecond: number,
}

-- At = game minute of the Night phase clock. Slot = index in the regular order (0 for scripted): seeds the
-- occurrence's own Random.
-- Premiere = the presented anomaly at its fixed minute (Input.PremiereAt): the night's grace does not hold it.
-- Night = the night's mandatory world event (owner 2026-10-22): the service starts it whatever the grace, the gap, the
-- caps and the window say, and nothing else starts around it (AnomalyService:StepNightEvent).
export type Entry = {
	Key: string,
	At: number,
	Scripted: boolean,
	Slot: number,
	Premiere: boolean,
	Night: boolean,
}

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

-- Keys a night event may be drawn from tonight (owner 2026-10-22, Provisional): world anomalies with a verb of the
-- families Input.NightEvent names, open tonight (Eligible), never a Customer actor and never a Scripted one. Content
-- order; empty when Input.NightEvent is nil.
function Scheduler.NightPool(input: Input): { string }
	const out: { string } = {}
	const rules = input.NightEvent
	if rules == nil then
		return out
	end
	for _, row in input.Anomalies do
		if row.Scripted ~= nil or row.Actor == "Customer" or row.Family == nil then
			continue
		end
		if table.find(rules.Families, row.Family) ~= nil and Scheduler.Eligible(row, input) then
			table.insert(out, row.Key)
		end
	end
	return out
end

-- Game minute of the night event: uniform in [From, To]. From = the Shift window start, held back by the night's grace
-- and by the fixed premiere + one MinGap; To = the window end minus the event's Span (so it ends before 5 AM).
function Scheduler.NightAt(input: Input, random: () -> number): number
	const rules = input.NightEvent
	const windowFrom, windowTo = input.Window[1], input.Window[2]
	const perSecond = math.max(input.MinutesPerSecond, 0)
	local from = windowFrom
	local to = windowTo
	if rules ~= nil then
		from = math.max(from, rules.Grace or 0)
		to = windowTo - math.max(rules.Span, 0) * perSecond
	end
	if input.PremiereAt ~= nil then
		from = math.max(from, input.PremiereAt + math.max(input.MinGap, 0) * perSecond)
	end
	from = math.min(from, windowTo)
	to = math.max(to, from)
	return from + random() * (to - from)
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

-- Same draw for the sanity pressure's extra entries (Pressure.luau, DEC-352)
Scheduler.Draw = draw

-- Agenda of the night, sorted by At (scripted entries last at equal minute).
function Scheduler.Build(input: Input, random: () -> number): { Entry }
	const out: { Entry } = {}
	const pool: { string } = {}
	const weights: { number } = {}
	local premiere: string? = nil
	for _, row in input.Anomalies do
		const scripted = row.Scripted
		if scripted ~= nil and scripted.Night == input.Night and row.Night <= input.Night then
			table.insert(out, { Key = row.Key, At = scripted.Clock, Scripted = true, Slot = 0, Premiere = false, Night = false })
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
		const fixed = input.PremiereAt
		if premiere ~= nil and fixed ~= nil then
			-- owner 2026-10-20 (Provisional Q-415): the presented anomaly at its fixed minute, the others kept MinGap after
			order[1] = premiere
			times[1] = math.clamp(fixed, from, to)
			for index = 2, n do
				times[index] = math.min(math.max(times[index], times[index - 1] + gap), to)
			end
		elseif premiere ~= nil then
			-- the presented anomaly first, in a slot inside the first third of the window
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
			table.insert(out, {
				Key = order[index] :: string,
				At = times[index],
				Scripted = false,
				Slot = index,
				Premiere = fixed ~= nil and index == 1 and order[index] == premiere,
				Night = false,
			})
		end
	end

	-- the mandatory night event (owner 2026-10-22, Provisional): drawn last so the draws above never change
	const nightPool = Scheduler.NightPool(input)
	if #nightPool > 0 then
		const key = nightPool[math.floor(random() * #nightPool) + 1]
		local merged = false
		if key == premiere then
			-- the presented anomaly is already on the agenda: it becomes the event, no second entry
			for _, entry in out do
				if entry.Key == key and not entry.Scripted and not entry.Night then
					entry.Night = true
					merged = true
					break
				end
			end
		end
		if not merged then
			const at = Scheduler.NightAt(input, random)
			const gap = math.max(input.MinGap, 0) * math.max(input.MinutesPerSecond, 0)
			const regular: { Entry } = {}
			for _, entry in out do
				if entry.Scripted or entry.Premiere then
					continue
				end
				table.insert(regular, entry)
				-- too close to the event (either side): pushed right after it
				if entry.At > at - gap and entry.At < at + gap then
					entry.At = at + gap
				end
			end
			table.sort(regular, function(a: Entry, b: Entry): boolean
				return a.At < b.At
			end)
			local previous = at
			for _, entry in regular do
				if entry.At >= at then
					entry.At = math.min(math.max(entry.At, previous + gap), math.max(input.Window[2], at))
					previous = entry.At
				end
			end
			table.insert(out, { Key = key, At = at, Scripted = false, Slot = 0, Premiere = false, Night = true })
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
