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
	Module singleton (require cache): every caller shares the same queue.
]]
local ContentProvider = game:GetService("ContentProvider")

type Job = { Work: () -> boolean?, Done: boolean, Name: string? }

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

local pump: () -> ()

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
				if not warnedTimeout then
					warnedTimeout = true -- once per session; later timeouts are routine
					warn(`[LoadQueue] load job {job.Name or "?"} still running after {JOB_TIMEOUT} s: moving on`)
				end
				ok, result = true, true
			elseif not ok then
				warn(`[LoadQueue] load job failed: {result}`)
			end
			task.wait(if not ok or result == true then BACKOFF else GAP)
		end
		working = false
	end)
end

local function enqueue(work: () -> boolean?, urgent: boolean?, name: string?): Job
	const job: Job = { Work = work, Done = false, Name = name }
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
function LoadQueue.Stats(): { Urgent: number, Background: number, Working: boolean, Held: boolean, PerMinute: number, Timeouts: number, Failures: number }
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
	}
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
		if key ~= nil and loaded[key] then
			done += 1
		else
			table.insert(pending, item)
		end
	end
	if progress ~= nil and done > 0 then
		progress(done, total)
	end
	const jobs: { Job } = {}
	for first = 1, #pending, BATCH do
		const batch = table.move(pending, first, math.min(first + BATCH - 1, #pending), 1, {})
		table.insert(
			jobs,
			enqueue(function(): boolean?
				local failed = false
				ContentProvider:PreloadAsync(batch, function(contentId: string, status: Enum.AssetFetchStatus)
					if status == Enum.AssetFetchStatus.Success then
						loaded[contentId] = true
					elseif status == Enum.AssetFetchStatus.Failure then
						failed = true
					end
				end)
				done += #batch
				if progress ~= nil then
					progress(math.min(done, total), total)
				end
				return failed
			end, urgent, `{tostring(keyOf(batch[1]))} (+{#batch - 1})`)
		)
	end
	for _, job in jobs do
		waitFor(job)
	end
end

return table.freeze(LoadQueue)
