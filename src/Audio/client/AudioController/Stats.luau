--!strict
-- Dev counters of the audio client (`/dev audio`, user report 2026-10-11 of a quota error): how many audio
-- instances are alive, how many this controller created and played in the last minute, and the LoadQueue state.
-- Module singleton. Mark() is two table writes: safe on a hot path.
local LoadQueue = require(script.Parent.LoadQueue)

const WINDOW = 60 -- s
const CLASSES = { "Sound", "AudioPlayer", "AudioTextToSpeech", "AudioFader", "Wire", "AudioDeviceOutput", "AudioEmitter" }

const marks: { [string]: { number } } = {}
const totals: { [string]: number } = {}

const Stats = {}

-- "play" = a Sound started, "new" = a Sound instance created (a pool miss, music, shift track or bed copy)
function Stats.Mark(name: string)
	local list = marks[name]
	if list == nil then
		list = {}
		marks[name] = list
	end
	const now = os.clock()
	table.insert(list, now)
	totals[name] = (totals[name] or 0) + 1
	while now - list[1] > WINDOW do
		table.remove(list, 1)
	end
end

local function lastMinute(name: string): number
	const list = marks[name]
	if list == nil then
		return 0
	end
	const now = os.clock()
	while #list > 0 and now - list[1] > WINDOW do
		table.remove(list, 1)
	end
	return #list
end

-- Text report; `pooled` = idle Sounds kept by the AudioController pool, `voices` = one-shots/loops it tracks
function Stats.Report(pooled: number, voices: number): string
	const alive: { [string]: number } = {}
	for _, class in CLASSES do
		alive[class] = 0
	end
	for _, instance in game:GetDescendants() do
		for _, class in CLASSES do
			if instance.ClassName == class then
				alive[class] += 1
				break
			end
		end
	end
	const queue = LoadQueue.Stats()
	const parts: { string } = {}
	for _, class in CLASSES do
		table.insert(parts, `{class}={alive[class]}`)
	end
	return `[Audio] alive: {table.concat(parts, " ")} | pool idle={pooled} voices={voices}\n`
		.. `[Audio] last {WINDOW}s: plays={lastMinute("play")} new sounds={lastMinute("new")} `
		.. `(session: plays={totals.play or 0} new={totals.new or 0})\n`
		.. `[Audio] LoadQueue: urgent={queue.Urgent} background={queue.Background} working={queue.Working} held={queue.Held} `
		.. `requests/min={queue.PerMinute} timeouts={queue.Timeouts} failures={queue.Failures}`
end

return table.freeze(Stats)
