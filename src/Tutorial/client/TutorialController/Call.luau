--!strict
--[[
	Call: Walt on the line during the first-hot-dog tutorial (user request 2026-10-11, Provisional).

	A queue of Walt's lines, one at a time: each line goes to the boss call subtitle (the `show` callback, owner
	TutorialController -> BossController:Say) and to the text-to-speech voice of "walt" (Content.Cutscenes.Rules.Voices),
	and holds for its reading time. The voice is the cutscene's Speech module, required as is (owner: CutsceneController;
	not edited here). Prepare(lines) generates every line ahead, so a line starts on its beat.

	Replace(lines) drops the lines not started yet (the step changed again) and queues the new ones; the line on
	screen finishes first. The last line lingers LINGER s, then the strip hides. Pure presentation: nothing is sent.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Content = require(ReplicatedStorage.shared.Content)
local Speech = require(StarterPlayer.StarterPlayerScripts.client.Cutscene.CutsceneController.Speech)

export type Call = {
	Prepare: (lines: { string }) -> (),
	Queue: (lines: { string }) -> (),
	Replace: (lines: { string }) -> (),
	Cut: () -> (),
	Busy: () -> boolean,
	Step: () -> (),
	Destroy: () -> (),
}

const SPEAKER = "walt" -- Content.Cutscenes.Rules.Voices key
-- PROVISIONAL: reading time of a line (TTS at Speed 0.95 says ~2.7 words/s)
const BASE_TIME = 0.7
const WORD_TIME = 0.36
const MIN_TIME = 1.4
const GAP = 0.25 -- s of silence between two lines
const LINGER = 4 -- s the last line stays on screen after it was said

const Call = {}

local function beat(text: string): Content.CutsceneBeat
	return { At = 0, Kind = "Line", Target = SPEAKER, Speaker = SPEAKER, Text = text }
end

local function readTime(text: string): number
	local words = 0
	for _ in string.gmatch(text, "%S+") do
		words += 1
	end
	return math.max(MIN_TIME, BASE_TIME + words * WORD_TIME)
end

-- show(text) puts a line on the subtitle (nil hides it); volume() = Master x Voice of AudioController
function Call.new(show: (text: string?) -> (), volume: () -> number): Call
	local speech: Speech.Speech? = nil
	const queue: { string } = {}
	local endsAt = 0 -- os.clock when the line on screen is over (0 = none)
	local hideAt = 0 -- os.clock when the strip hides (0 = hidden)

	local function voice(): Speech.Speech
		const existing = speech
		if existing ~= nil then
			return existing
		end
		const created = Speech.new(volume)
		speech = created
		return created
	end

	local function busy(): boolean
		return #queue > 0 or (endsAt > 0 and os.clock() < endsAt)
	end

	return {
		Prepare = function(lines: { string })
			const beats: { Content.CutsceneBeat } = {}
			for _, text in lines do
				table.insert(beats, beat(text))
			end
			voice().Prepare(beats)
		end,
		Queue = function(lines: { string })
			for _, text in lines do
				table.insert(queue, text)
			end
		end,
		Replace = function(lines: { string })
			table.clear(queue)
			for _, text in lines do
				table.insert(queue, text)
			end
		end,
		Cut = function()
			table.clear(queue)
			endsAt = 0
			hideAt = 0
			const current = speech
			if current ~= nil then
				current.Stop()
			end
			show(nil)
		end,
		Busy = busy,
		Step = function()
			const now = os.clock()
			if endsAt > 0 and now < endsAt then
				return
			end
			const text = table.remove(queue, 1)
			if text ~= nil then
				const time = readTime(text)
				endsAt = now + time + GAP
				hideAt = now + time + LINGER
				show(text)
				voice().Say(beat(text))
				return
			end
			endsAt = 0
			if hideAt > 0 and now >= hideAt then
				hideAt = 0
				show(nil)
			end
		end,
		Destroy = function()
			table.clear(queue)
			endsAt = 0
			hideAt = 0
			const current = speech
			speech = nil
			if current ~= nil then
				current.Destroy()
			end
		end,
	}
end

return table.freeze(Call)
