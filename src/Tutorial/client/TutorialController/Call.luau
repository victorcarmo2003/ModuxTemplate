--!strict
--[[
	Call: Walt on the line during the first-hot-dog tutorial (user request 2026-10-11, Provisional).

	A queue of Walt's lines, one at a time: each line goes to the boss call subtitle (the `show` callback, owner
	TutorialController -> BossController:Say) and to the text-to-speech voice of "walt" (Content.Cutscenes.Rules.Voices),
	and holds for its reading time. The voice is the cutscene's Speech module, required as is (owner: CutsceneController;
	not edited here). Prepare(lines) generates every line ahead, so a line starts on its beat.

	Replace(lines) drops the lines not started yet (the step changed again) and queues the new ones; the line on
	screen finishes first. The last line lingers LINGER s, then the strip hides. Pure presentation: nothing is sent.

	Voice in sync (playtest 2026-10-11: the subtitle "Here comes your first customer." showed, Walt stayed silent).
	Cause: Say() only voices a line already loaded or loading within Speech's LATE (1 s) of the call, and the call
	gave every line its beat the moment the previous one ended, so any line whose text-to-speech was still in the load
	queue (about 45 lines prepared one by one, each a server request) was shown silent and never voiced. Now the next
	line waits for its own voice: Speech.Fetch puts it first in the load queue, and the line starts (subtitle + voice
	together) once it is "Loaded", or after HOLD s / when the voice is "Failed" / "Off" (subtitle only, Speech warns
	once per session). A loaded line holds the screen for its real length (TimeLength) when longer than the reading
	time.

	Preload(lines, timeout, progress) (LoadingController, under the loading screen of a rookie) queues every line and
	yields until all are settled or the timeout; the rest keeps loading in the background, so Walt's lines are
	"Loaded" when the call starts. Voice() / Line(text) give the dev tools (/dev voice, the debug panel) the same Speech
	and beat the call uses.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Content = require(ReplicatedStorage.shared.Content)
local Speech = require(StarterPlayer.StarterPlayerScripts.client.Cutscene.CutsceneController.Speech)

export type Call = {
	Prepare: (lines: { string }) -> (),
	-- yields until every line is settled or `timeout` s; progress(0..1)
	Preload: (lines: { string }, timeout: number, progress: ((number) -> ())?) -> (),
	-- the Speech of the call (built on first use) and the beat of one of Walt's lines
	Voice: () -> Speech.Speech,
	Line: (text: string) -> Content.CutsceneBeat,
	-- lines waiting to be said
	Pending: () -> number,
	Queue: (lines: { string }) -> (),
	Replace: (lines: { string }) -> (),
	Cut: () -> (),
	Busy: () -> boolean,
	Step: () -> (),
	Destroy: () -> (),
}

const SPEAKER = "walt" -- Content.Cutscenes.Rules.Voices key
-- PROVISIONAL: reading time of a line (TTS at Speed 0.9 says ~2.6 words/s)
const BASE_TIME = 0.7
const WORD_TIME = 0.36
const MIN_TIME = 1.4
const GAP = 0.25 -- s of silence between two lines
const LINGER = 4 -- s the last line stays on screen after it was said
-- s a line waits for its voice before it goes on as a subtitle only (was 4: a LoadQueue job stuck up to 8 s made the
-- greeting skip its voice for good, a line that loads later is never voiced)
const HOLD = 12
const MAX_WARNINGS = 3 -- subtitle-only warnings per session (one per distinct reason)
const TAIL = 0.4 -- s the subtitle stays after the voice ends (and before the next line)
const VOICE_WAIT = 20 -- s a line waits for its voice to start before it goes on as a subtitle only

const Call = {}

const warned: { [string]: boolean } = {}
local warnings = 0

-- One warning per kind of reason (the status, and at most MAX_WARNINGS) when a line of Walt goes on without its voice
local function warnSilent(kind: string, reason: string, text: string)
	if warned[kind] or warnings >= MAX_WARNINGS then
		return
	end
	warned[kind] = true
	warnings += 1
	warn(`[TutorialCall] Walt's line "{text}" goes on as a subtitle only: {reason}`)
end

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
function Call.new(show: (text: string?) -> (), volume: () -> number, trace: (message: string) -> ()): Call
	local speech: Speech.Speech? = nil
	const queue: { string } = {}
	local endsAt = 0 -- os.clock when the line on screen is over (0 = none)
	local hideAt = 0 -- os.clock when the strip hides (0 = hidden)
	local waitFrom = 0 -- os.clock the next line started waiting for its voice (0 = not waiting)
	-- the line handed to the voice: "" = none, "Voice" = waiting for it to start / speaking (the subtitle follows it)
	local phase = ""
	local voiceBy = 0 -- os.clock past which a voice that did not start is given up (subtitle only)
	local generation = 0 -- bumped by every line / Cut, so a late handler of an old line does nothing
	local cancelVoice: (() -> ())? = nil
	local pendingText = "" -- the line waiting for its voice, and its reading time
	local pendingTime = 0

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
		return #queue > 0 or phase ~= "" or (endsAt > 0 and os.clock() < endsAt)
	end

	local function beats(lines: { string }): { Content.CutsceneBeat }
		const out: { Content.CutsceneBeat } = {}
		for _, text in lines do
			table.insert(out, beat(text))
		end
		return out
	end

	return {
		Prepare = function(lines: { string })
			voice().Prepare(beats(lines))
		end,
		Preload = function(lines: { string }, timeout: number, progress: ((number) -> ())?)
			voice().Preload(beats(lines), timeout, progress)
		end,
		Voice = voice,
		Line = beat,
		Pending = function(): number
			return #queue
		end,
		Queue = function(lines: { string })
			for _, text in lines do
				table.insert(queue, text)
			end
		end,
		Replace = function(lines: { string })
			table.clear(queue)
			waitFrom = 0
			for _, text in lines do
				table.insert(queue, text)
			end
			trace(`replace: {#lines} line(s) queued (the line on screen finishes first)`)
		end,
		Cut = function()
			trace("cut: queue cleared, voice stopped")
			table.clear(queue)
			waitFrom = 0
			endsAt = 0
			hideAt = 0
			phase = ""
			generation += 1
			cancelVoice = nil
			const current = speech
			if current ~= nil then
				current.Stop()
			end
			show(nil)
		end,
		Busy = busy,
		Step = function()
			const now = os.clock()
			if phase ~= "" then
				-- the voice of the line on screen: its subtitle waits for the start and stays until the end
				if now >= voiceBy and phase == "Waiting" then
					-- the voice never started (muted engine, stuck load): the subtitle goes on without it
					const cancel = cancelVoice
					cancelVoice = nil
					if cancel ~= nil then
						cancel()
					end
					generation += 1
					phase = ""
					endsAt = now + pendingTime + GAP
					hideAt = now + pendingTime + LINGER
					show(pendingText)
					return
				else
					return
				end
			end
			if endsAt > 0 and now < endsAt then
				return
			end
			-- a line is never cut by the next: wait until the voice actually ended (timers only estimate it)
			const talking = speech
			if talking ~= nil and talking.Busy() then
				return
			end
			const text = queue[1]
			if text ~= nil then
				const line = beat(text)
				const speech = voice()
				const status = speech.Fetch(line)
				if status == "Queued" or status == "Loading" then
					if waitFrom == 0 then
						waitFrom = now
						trace(`line waits for its voice ({status}): "{text}"`)
					end
					if now - waitFrom < HOLD then
						return -- the voice is on its way: the line starts with it
					end
				end
				table.remove(queue, 1)
				const waited = if waitFrom > 0 then now - waitFrom else 0
				waitFrom = 0
				if status ~= "Loaded" then
					local reason = speech.Reason(line)
					if status == "Queued" or status == "Loading" then
						reason = `waited {string.format("%.1f", waited)} s (HOLD {HOLD} s), {reason}`
					end
					warnSilent(status, if reason ~= "" then reason else status, text)
				end
				const time = readTime(text)
				pendingText = text
				pendingTime = time
				const mine = generation + 1
				generation = mine
				phase = "Waiting"
				endsAt = 0
				voiceBy = now + VOICE_WAIT
				trace(`say ({status}, {#queue} left): "{text}"`)
				-- the subtitle follows the voice: it shows when the voice starts and stays until it ended (+ TAIL); a line
				-- without a voice (off, failed, late) shows now for its reading time
				cancelVoice = speech.Say(line, {
					OnStart = function()
						if generation ~= mine then
							return
						end
						phase = "Voice"
						endsAt = 0
						show(text)
					end,
					OnEnd = function()
						if generation ~= mine then
							return
						end
						const ended = os.clock()
						phase = ""
						cancelVoice = nil
						endsAt = ended + TAIL + GAP
						hideAt = ended + TAIL + LINGER
					end,
					OnMiss = function()
						if generation ~= mine then
							return
						end
						const shownAt = os.clock()
						phase = ""
						cancelVoice = nil
						endsAt = shownAt + time + GAP
						hideAt = shownAt + time + LINGER
						show(text)
					end,
				})
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
			phase = ""
			generation += 1
			cancelVoice = nil
			const current = speech
			speech = nil
			if current ~= nil then
				current.Destroy()
			end
		end,
	}
end

return table.freeze(Call)
