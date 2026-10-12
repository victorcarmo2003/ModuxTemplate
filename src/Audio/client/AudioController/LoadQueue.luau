--!strict
--[[
	LoadQueue: the one queue of every audio load of this client (playtest 2026-10-11: AudioController preloading every
	Content.Sounds id in one PreloadAsync, the loading screen preloading the intro sounds and the text-to-speech lines
	loading, all at once -> "Failed to load sound : Rate limited by the client" x24 and failed voices).

	One job at a time, GAP s between two jobs; a job that reports a failure holds the queue BACKOFF s (a rate limit
	clears before the next request). A job still running after JOB_TIMEOUT s counts as failed and the queue moves on
	(playtest 2026-10-11: one text-to-speech LoadAsync that never returned held every later line, Walt's voice
	included, for the whole session); the stuck call keeps running on its own thread. Urgent jobs (loading screen, text-to-speech) go before the background ones, and background jobs wait for Release()
	(LoadingController, loading screen over; failsafe HOLD_FAILSAFE s).
	  Preload(items, progress?, urgent?)  ContentProvider:PreloadAsync in batches of BATCH (Sound instances or content
	                                      ids); ids already loaded are skipped. Yields until every batch ran.
	  Run(work, urgent?)                  runs work() inside the queue (work returns true on failure); yields until it ran.
  Want(id)                            demand load of one id (first Play of a sound that is not loaded yet): urgent, once.
  State(id)                           "loaded" | "cooldown" (failed, in backoff: do not ask again) | "unknown".
  Quota (2026-10-12): a failed id enters cooldown 10 -> 20 -> 40 -> 60 s (doubling per failure of that id) and is
  skipped by Preload/Want until it ends; a job that times out puts its unresolved ids in cooldown too. In flight:
  one job at a time of BATCH (4) ids, so never more than 4 (limit 6). One warn per session with the counts.
	Module singleton (require cache): every caller shares the same queue.
]]
local ContentProvider = game:GetService("ContentProvider")
local LogService = game:GetService("LogService")

type Job = { Work: () -> boolean?, Done: boolean, Name: string?, TimedOut: boolean }

const BATCH = 4 -- assets per PreloadAsync
const GAP = 0.25 -- s between two jobs
const BACKOFF = 2 -- s the queue waits after a job that failed
const POLL = 0.05
const JOB_TIMEOUT = 8 -- s before a job that has not returned is abandoned (counts as failed)

const urgentJobs: { Job } = {}
const backgroundJobs: { Job } = {}
const loaded: { [string]: boolean } = {}
const HOLD_FAILSAFE = 40 -- s: background jobs are released even if nobody calls Release
local held = true -- background jobs wait for the loading screen (LoadingController calls Release)
local working = false
local warnedTimeout = false
const STATS_WINDOW = 60 -- s: window of the requests-per-minute counter (Stats)
const starts: { number } = {} -- os.clock() of every job that started in the last STATS_WINDOW s
local timeouts = 0
local failures = 0
const COOLDOWN_FIRST = 10 -- s: first backoff of an id that failed
const COOLDOWN_MAX = 60
const QUOTA_WARN_DELAY = 10 -- s after the first failure: the one warn of the session
const cooldowns: { [string]: { Until: number, Tries: number } } = {} -- id -> failure state
const requested: { [string]: boolean } = {} -- distinct ids ever sent to PreloadAsync / Want
const queued: { [string]: boolean } = {} -- ids in a job that has not finished (no duplicate requests)
local requestedCount = 0
local inFlight = 0
local peakInFlight = 0
local quotaMessages = 0 -- "NotEnoughQuota" lines seen in the log (sounds, text-to-speech)
local warnedQuota = false

local pump: () -> ()

local function failedCount(): number
	local count = 0
	for _ in cooldowns do
		count += 1
	end
	return count
end

local function loadedCount(): number
	local count = 0
	for _ in loaded do
		count += 1
	end
	return count
end

local function markFailed(id: string)
	const now = os.clock()
	const state = cooldowns[id]
	const tries = if state then state.Tries + 1 else 1
	cooldowns[id] = { Until = now + math.min(COOLDOWN_FIRST * 2 ^ (tries - 1), COOLDOWN_MAX), Tries = tries }
	if not warnedQuota then
		warnedQuota = true -- once per session; Stats has the live counts
		task.delay(QUOTA_WARN_DELAY, function()
			warn(
				`[LoadQueue] audio loads failing (quota / rate limit): {failedCount()} id(s) in backoff, `
					.. `{quotaMessages} NotEnoughQuota line(s) so far; they are not asked again until the backoff ends`
			)
		end)
	end
end

local function markLoaded(id: string)
	loaded[id] = true
	cooldowns[id] = nil
end

local function inCooldown(id: string): boolean
	const state = cooldowns[id]
	return state ~= nil and state.Until > os.clock()
end

pcall(function()
	LogService.MessageOut:Connect(function(message: string)
		if string.find(message, "NotEnoughQuota", 1, true) then
			quotaMessages += 1
		end
	end)
end)

pump = function()
	if working then
		return
	end
	working = true
	task.spawn(function()
		while true do
			const job = table.remove(urgentJobs, 1) or (if held then nil else table.remove(backgroundJobs, 1))
			if job == nil then
				break
			end
			local finished = false
			local ok, result: any = true, nil
			table.insert(starts, os.clock())
			task.spawn(function()
				ok, result = pcall(job.Work)
				finished = true
			end)
			const deadline = os.clock() + JOB_TIMEOUT
			while not finished and os.clock() < deadline do
				task.wait(POLL)
			end
			job.Done = true
				if not finished then
				job.TimedOut = true
				timeouts += 1
				inFlight = 0
				if not warnedTimeout then
					warnedTimeout = true -- once per session; later timeouts are routine
					warn(`[LoadQueue] load job {job.Name or "?"} still running after {JOB_TIMEOUT} s: moving on`)
				end
				ok, result = true, true
			elseif not ok then
				warn(`[LoadQueue] load job failed: {result}`)
			end
			if not ok or result == true then
				failures += 1
			end
			task.wait(if not ok or result == true then BACKOFF else GAP)
		end
		working = false
	end)
end

local function enqueue(work: () -> boolean?, urgent: boolean?, name: string?): Job
	const job: Job = { Work = work, Done = false, Name = name, TimedOut = false }
	table.insert(if urgent then urgentJobs else backgroundJobs, job)
	pump()
	return job
end

local function waitFor(job: Job)
	while not job.Done do
		task.wait(POLL)
	end
end

local function keyOf(item: any): string?
	if typeof(item) == "string" then
		return item
	elseif typeof(item) == "Instance" then
		const instance = item :: Instance
		if instance:IsA("Sound") then
			return instance.SoundId
		end
	end
	return nil
end

const LoadQueue = {}

-- Background jobs (AudioController's preload of every sound) wait until the loading screen is over, so they never
-- compete with the kit, the intro sounds and the voices; urgent jobs are not held.
function LoadQueue.Release()
	if not held then
		return
	end
	held = false
	pump()
end

task.delay(HOLD_FAILSAFE, LoadQueue.Release)

-- Dev counter (`/dev audio`): queue size and jobs started in the last minute (one job = one PreloadAsync batch or one
-- text-to-speech LoadAsync, so it is the request rate this client sends to the audio loader).
function LoadQueue.Stats(): {
	Urgent: number,
	Background: number,
	Working: boolean,
	Held: boolean,
	PerMinute: number,
	Timeouts: number,
	Failures: number,
	Requested: number,
	Loaded: number,
	InFlight: number,
	PeakInFlight: number,
	Cooldown: number,
	QuotaMessages: number,
}
	const now = os.clock()
	while #starts > 0 and now - starts[1] > STATS_WINDOW do
		table.remove(starts, 1)
	end
	return {
		Urgent = #urgentJobs,
		Background = #backgroundJobs,
		Working = working,
		Held = held,
		PerMinute = #starts,
		Timeouts = timeouts,
		Failures = failures,
		Requested = requestedCount,
		Loaded = loadedCount(),
		InFlight = inFlight,
		PeakInFlight = peakInFlight,
		Cooldown = failedCount(),
		QuotaMessages = quotaMessages,
	}
end

-- Total "NotEnoughQuota" log lines seen by this client (Speech compares before/after one LoadAsync)
function LoadQueue.QuotaMessages(): number
	return quotaMessages
end

function LoadQueue.State(id: string): string
	if loaded[id] then
		return "loaded"
	end
	return if inCooldown(id) then "cooldown" else "unknown"
end

-- Demand load: the first Play of a sound whose id is not loaded. Urgent, once per id, never during its cooldown.
function LoadQueue.Want(id: string)
	if id == "" or loaded[id] or queued[id] or inCooldown(id) then
		return
	end
	task.spawn(LoadQueue.Preload, { id }, nil, true)
end

function LoadQueue.Run(work: () -> boolean?, urgent: boolean?)
	waitFor(enqueue(work, urgent))
end

function LoadQueue.Preload(items: { any }, progress: ((done: number, total: number) -> ())?, urgent: boolean?)
	const total = #items
	local done = 0
	const pending: { any } = {}
	for _, item in items do
		const key = keyOf(item)
		if key ~= nil and (loaded[key] or inCooldown(key) or queued[key]) then
			-- loaded, backing off after a failure (never blocks the caller) or already in a job
			done += 1
		else
			if key ~= nil then
				queued[key] = true
				if not requested[key] then
					requested[key] = true
					requestedCount += 1
				end
			end
			table.insert(pending, item)
		end
	end
	if progress ~= nil and done > 0 then
		progress(done, total)
	end
	const jobs: { Job } = {}
	for first = 1, #pending, BATCH do
		const batch = table.move(pending, first, math.min(first + BATCH - 1, #pending), 1, {})
		const job = enqueue(function(): boolean?
			const open: { [string]: boolean } = {}
			for _, item in batch do
				const key = keyOf(item)
				if key ~= nil then
					open[key] = true
				end
			end
			inFlight = #batch
			peakInFlight = math.max(peakInFlight, inFlight)
			local failed = false
			ContentProvider:PreloadAsync(batch, function(contentId: string, status: Enum.AssetFetchStatus)
				if status == Enum.AssetFetchStatus.Success then
					markLoaded(contentId)
				elseif status == Enum.AssetFetchStatus.Failure then
					failed = true
					markFailed(contentId)
				end
			end)
			inFlight = 0
			done += #batch
			if progress ~= nil then
				progress(math.min(done, total), total)
			end
			return failed
		end, urgent, `{tostring(keyOf(batch[1]))} (+{#batch - 1})`)
		table.insert(jobs, job)
		-- the job ended (or was abandoned by the timeout): its ids are no longer in flight; an abandoned job leaves
		-- ids unresolved and they back off instead of being asked again
		task.spawn(function()
			waitFor(job)
			for _, item in batch do
				const key = keyOf(item)
				if key ~= nil then
					queued[key] = nil
					if job.TimedOut and not loaded[key] and not inCooldown(key) then
						markFailed(key)
					end
				end
			end
		end)
	end
	for _, job in jobs do
		waitFor(job)
	end
end

return table.freeze(LoadQueue)
