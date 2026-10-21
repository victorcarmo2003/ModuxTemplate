--!nocheck
-- Pure test of the V2 anomaly agenda (TASK-271; DEC-254, DEC-257; anomalies-v2-proposal.md §5): runs the real
-- AnomalyService/Scheduler.luau over the real Content.Nights and Content.Anomalies (Table, Flow) for the 10 nights and
-- 200 seeds each. No Roblox, no Studio:
--   lune run tools/studio/scheduler_check
-- Run it from the repo root. Prints the night table and `SCHEDULER: N ok, M failures`; exit code 1 on a failure.
-- Checks: same seed = same agenda; Events regular entries inside the Shift window, MinGap apart; only open families,
-- never a skipped atmosphere, never a row before its debut, never Family nil (ANM-006/008 cut); no anomaly twice in a
-- row when the pool has more than one; the presented anomaly (NewAnomaly) once inside the first third; scripted on top.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local CONTENT = "src/Shared/Content/"
local loaded = {}

-- the repo uses `const`; plain Luau wants `local`. `script.Parent.X` resolves to another Content module.
local function load(path, name)
	if loaded[path] then
		return loaded[path]
	end
	local source = fs.readFile(path)
	source = string.gsub(source, "%f[%w_]const%f[^%w_]", "local")
	local parent = setmetatable({}, {
		__index = function(_, child)
			return { __module = CONTENT .. child .. ".luau", __name = child }
		end,
	})
	local env = setmetatable({
		script = { Parent = parent },
		require = function(target)
			return load(target.__module, target.__name)
		end,
	}, { __index = getfenv() })
	local chunk = luau.load(source, { debugName = name, environment = env })
	local value = chunk()
	loaded[path] = value
	return value
end

local Scheduler = load("src/Anomaly/server/AnomalyService/Scheduler.luau", "Scheduler")
local Nights = load(CONTENT .. "Nights.luau", "Nights")
local Anomalies = load(CONTENT .. "Anomalies.luau", "Anomalies")

-- Night phase clock (Content.Shift.ByKey.Night: 8 PM -> 6 AM)
local CLOCK_FROM, CLOCK_TO = 1200, 1800
local SEEDS = 200

local failures, passes = 0, 0
local function fail(night, text)
	failures += 1
	print(`  FAIL [night {night}] {text}`)
end

-- deterministic [0, 1) stream (Park-Miller), stands in for Random:NextNumber
local function rng(seed)
	local state = seed % 2147483646 + 1
	return function()
		state = (state * 48271) % 2147483647
		return (state - 1) / 2147483646
	end
end

local function candidates()
	local out = {}
	for _, row in Anomalies.List do
		table.insert(out, {
			Key = row.Key,
			Night = row.Night,
			NpcCost = row.NpcCost,
			ExclusiveWith = row.ExclusiveWith,
			Scripted = row.Scripted,
			Family = row.Family,
			SkipAtmospheres = row.SkipAtmospheres,
		})
	end
	return out
end

local function input(night)
	return {
		Night = night.Index,
		Anomalies = candidates(),
		Occurrences = Nights.Occurrences,
		Families = night.Families,
		Atmosphere = night.Atmosphere,
		Events = night.Events,
		Premiere = night.NewAnomaly,
		PremiereAt = Nights.PremiereAt[night.Index], -- owner 2026-10-20 (Provisional Q-415)
		Window = Nights.Windows.Shift,
		MinGap = night.MinGap,
		MinutesPerSecond = (CLOCK_TO - CLOCK_FROM) / night.Duration,
	}
end

print("Noite | Famílias | Novidade | ATM | Eventos | Sustos | pool")
for _, night in Nights.List do
	local k = night.Index
	local before = failures
	local data = input(night)
	local pool = {}
	for _, row in data.Anomalies do
		if Scheduler.Eligible(row, data) then
			table.insert(pool, row.Key)
		end
	end
	print(
		`{k} | {table.concat(night.Families, " ")} | {night.NewAnomaly} | {night.Atmosphere} | {night.Events} | {night.Scares} | {#pool}`
	)

	-- determinism
	local a = Scheduler.Build(data, rng(42))
	local b = Scheduler.Build(data, rng(42))
	if #a ~= #b then
		fail(k, "same seed, different size")
	else
		for i = 1, #a do
			if a[i].Key ~= b[i].Key or a[i].At ~= b[i].At then
				fail(k, "same seed, different agenda")
				break
			end
		end
	end

	local from, to = data.Window[1], data.Window[2]
	local third = from + (to - from) / 3
	local gap = night.MinGap * data.MinutesPerSecond
	local seen = {}
	for seed = 1, SEEDS do
		local agenda = Scheduler.Build(data, rng(seed * 7919 + k))
		local regular, premiereEarly, previous, previousAt = 0, false, nil, nil
		local scripted = 0
		for _, entry in agenda do
			local row = Anomalies.ByKey[entry.Key]
			if entry.Scripted then
				scripted += 1
				if not (row.Scripted and row.Scripted.Night == k) then
					fail(k, `seed {seed}: scripted {entry.Key} not scripted on this night`)
				end
				continue
			end
			regular += 1
			seen[entry.Key] = true
			if row.Family == nil then
				fail(k, `seed {seed}: {entry.Key} is cut from the agenda`)
			elseif not table.find(night.Families, row.Family) then
				fail(k, `seed {seed}: {entry.Key} family {row.Family} closed`)
			end
			if row.Night > k then
				fail(k, `seed {seed}: {entry.Key} before its debut night {row.Night}`)
			end
			if row.SkipAtmospheres and table.find(row.SkipAtmospheres, night.Atmosphere) then
				fail(k, `seed {seed}: {entry.Key} on skipped atmosphere {night.Atmosphere}`)
			end
			if entry.At < from or entry.At >= to then
				fail(k, `seed {seed}: {entry.Key} at {entry.At} outside the Shift window`)
			end
			if previousAt ~= nil and entry.At - previousAt < gap - 1e-6 then
				fail(k, `seed {seed}: two starts {entry.At - previousAt} min apart (< MinGap {gap})`)
			end
			if previous == entry.Key and #pool > 1 then
				fail(k, `seed {seed}: {entry.Key} twice in a row`)
			end
			if entry.Key == night.NewAnomaly and entry.At < third then
				premiereEarly = true
			end
			previous, previousAt = entry.Key, entry.At
		end
		if regular ~= night.Events then
			fail(k, `seed {seed}: {regular} regular entries, Events = {night.Events}`)
		end
		if table.find(pool, night.NewAnomaly) and not premiereEarly then
			fail(k, `seed {seed}: {night.NewAnomaly} not in the first third`)
		end
		if k == #Nights.List and scripted ~= 2 then
			fail(k, `seed {seed}: {scripted} scripted entries on the last night (Hush + Walker)`)
		end
	end
	for _, key in pool do
		if not seen[key] then
			fail(k, `{key} never drawn in {SEEDS} seeds`)
		end
	end
	if failures == before then
		passes += 1
	end
end

-- Admit still guards the actor cap
local walker = { Key = "w", Night = 1, NpcCost = 1, ExclusiveWith = {} }
local ok = Scheduler.Admit(walker, { { Key = "x", Night = 1, NpcCost = 1, ExclusiveWith = {} } }, {
	MaxSimultaneous = 3,
	MaxActors = 1,
	MinGap = 0,
}, math.huge)
if ok then
	fail(0, "Admit let a second actor past MaxActors = 1")
end

print(`SCHEDULER: {passes} ok, {failures} failures`)
if failures > 0 then
	process.exit(1)
end
