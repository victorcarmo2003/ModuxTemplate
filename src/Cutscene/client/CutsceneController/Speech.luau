--!strict
--[[
	Speech: text-to-speech of the cutscene lines (AudioTextToSpeech: Text, VoiceId, Speed, Pitch, Volume, LoadAsync ->
	Enum.AssetFetchStatus, IsLoaded, Play/Pause). Defensive by design: the class, a property, the load or the play may
	be missing or fail, and then the line simply stays a subtitle.

	Graph: one AudioTextToSpeech per line -> Wire -> AudioFader (volume = AudioController Master x Voice group x the
	speaker's Content volume) -> Wire -> AudioDeviceOutput (this client only). Voices per speaker in
	Content.Cutscenes.Rules.Voices (VoiceId, Speed, Pitch, Volume); VoiceId "" = that speaker is silent.

	Loading (playtest 2026-10-11: every line of the segment called LoadAsync in the same frame and the engine refused
	them all with "Failed to load sound : Rate limited by the client" + one "Failed to load text to speech" error each):
	  * one request at a time (GAP s between two), never a burst, and inside the client's one audio queue
	    (Audio/AudioController/LoadQueue), so no sound preload runs next to it;
	  * a failed load is retried (MAX_TRIES) after a growing pause (BACKOFF x 2^n, up to MAX_BACKOFF) that holds the
	    whole queue, so a rate limit clears before the next request;
	  * a VoiceId that never loaded a single line after MAX_TRIES is judged bad; its lines move to a voice that did
	    load (one warning), or wait for one;
	  * GIVE_UP failures in a row switch text-to-speech off for the session (one warning, subtitles only).
	The engine prints its own error for each failed request (not catchable); the queue keeps that to a handful.

	Preload(lines, timeout, progress) queues every line and yields until all are settled (loaded or failed) or the
	timeout; the rest keeps loading in the background (LoadingController, before the intro). Prepare(lines) queues
	without waiting. Say(line) plays a loaded line on its beat; one still loading jumps to the front of the queue and
	plays when it loads, if that is still within LATE s of its beat. A new line cuts the one playing.
	Fetch(line) (Walt's tutorial call, user feedback 2026-10-11: his lines were said before their voice had loaded and
	stayed silent) queues the line first and returns its state, so a caller without a fixed timeline can hold the line
	until the voice is ready ("Loaded") or gone ("Failed" / "Off": subtitle only). Length(line) = seconds of a loaded
	line (TimeLength), nil when unknown.
	Warnings: one per session for every Speech together (module-level), the rest of the session is silent.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local StarterPlayer = game:GetService("StarterPlayer")
local Content = require(ReplicatedStorage.shared.Content)
local LoadQueue = require(StarterPlayer.StarterPlayerScripts.client.Audio.AudioController.LoadQueue)

type Beat = Content.CutsceneBeat

export type Status = "Queued" | "Loading" | "Loaded" | "Failed" | "Off"

export type Speech = {
	Prepare: (lines: { Beat }) -> (),
	-- queues the line first (if not loaded yet) and returns its state; "Off" = no voice for it (subtitle only)
	Fetch: (line: Beat) -> Status,
	-- seconds of a loaded line (nil = not loaded or unknown)
	Length: (line: Beat) -> number?,
	-- yields; progress(fraction 0..1) while it waits
	Preload: (lines: { Beat }, timeout: number, progress: ((number) -> ())?) -> (),
	Say: (line: Beat) -> (),
	Stop: () -> (),
	Destroy: () -> (),
}

type State = "Queued" | "Loading" | "Loaded" | "Failed"

type Entry = {
	Line: Beat,
	Speaker: string,
	VoiceId: string, -- the id in use (the speaker's, or the fallback after a bad id)
	Voice: AudioTextToSpeech?,
	State: State,
	Tries: number,
	Wanted: number?, -- os.clock when Say asked for it before the load finished
	BadVoice: boolean, -- failed because its VoiceId is bad (re-queued when a good voice appears)
}

const VOICES = Content.Cutscenes.Rules.Voices
const FOLDER = "CutsceneVoice"
const LATE = 1 -- s: a line that loads later than this after its beat is not voiced
const GAP = 0.2 -- s between two load requests
const MAX_TRIES = 3 -- load attempts per line (same VoiceId)
const BACKOFF = 1.5 -- s of pause after a failure, doubled per try of that line
const MAX_BACKOFF = 6
const GIVE_UP = 6 -- failures in a row (no success between) that switch text-to-speech off
const POLL = 0.1 -- s between two progress reads of Preload

const Speech = {}

-- one text-to-speech warning per session, shared by every Speech (intro and tutorial call)
local warnedOnce = false

-- Text sent to AudioTextToSpeech. Roblox filters TTS text and refuses lines with phone-number-like digit runs
-- ("Failed to load sound : FilteredText", 2026-10-11: "555-0179... Here goes."); the subtitle keeps the number, the
-- voice skips it.
function Speech.Spoken(text: string): string
	local out = string.gsub(text, "%d[%d%-%s]*%d", "")
	out = string.gsub(out, "^[%s%.,!%?]+", "")
	out = string.gsub(out, "%s+", " ")
	return out
end

local function keyOf(line: Beat): string
	return `{line.Speaker or "walt"}\0{line.Text or ""}`
end

local function wire(source: Instance, target: Instance, parent: Instance): boolean
	return (pcall(function()
		const link = Instance.new("Wire")
		link.SourceInstance = source
		link.TargetInstance = target
		link.Parent = parent
	end))
end

function Speech.new(volume: () -> number): Speech
	local enabled = true
	local alive = true
	const warned: { [string]: boolean } = {}
	const entries: { [string]: Entry } = {}
	const queue: { Entry } = {}
	local working = false
	local pause = 0 -- s the queue waits before its next request (backoff)
	local streak = 0 -- failures in a row
	const goodVoices: { [string]: boolean } = {}
	const badVoices: { [string]: boolean } = {}
	local playing: AudioTextToSpeech? = nil

	local folder: Instance? = nil
	local fader: AudioFader? = nil

	local function warnOnce(key: string, message: string)
		if warned[key] then
			return
		end
		warned[key] = true
		if warnedOnce then
			return
		end
		warnedOnce = true
		warn(`[Speech] {message}`)
	end

	local function disable(reason: string)
		enabled = false
		table.clear(queue)
		warnOnce("off", `text-to-speech off, subtitles only: {reason}`)
	end

	-- Fader + device output, built once
	local function graph(): AudioFader?
		if fader ~= nil and fader.Parent ~= nil then
			return fader
		end
		const ok, problem = pcall(function()
			const holder = Instance.new("Folder")
			holder.Name = FOLDER
			holder.Parent = SoundService
			const out = Instance.new("AudioDeviceOutput")
			out.Parent = holder
			const fade = Instance.new("AudioFader")
			fade.Parent = holder
			if not wire(fade, out, holder) then
				error("Wire unavailable")
			end
			folder = holder
			fader = fade
		end)
		if not ok then
			disable(tostring(problem))
			return nil
		end
		return fader
	end

	local function refreshVolume()
		const fade = fader
		if fade ~= nil then
			pcall(function()
				fade.Volume = math.clamp(volume(), 0, 2)
			end)
		end
	end

	local function start(entry: Entry)
		const voice = entry.Voice
		if voice == nil then
			return
		end
		const previous = playing
		if previous ~= nil and previous ~= voice then
			pcall(function()
				previous:Pause()
			end)
		end
		refreshVolume()
		playing = voice
		const ok, problem = pcall(function()
			voice.TimePosition = 0
			voice:Play()
		end)
		if not ok then
			disable(`Play failed: {problem}`)
		end
	end

	-- VoiceId a speaker uses now: its own, or a voice that loaded when its own is bad
	local function voiceIdOf(speaker: string): string?
		const row = VOICES[speaker]
		if row == nil or row.VoiceId == "" then
			return nil
		end
		if not badVoices[row.VoiceId] then
			return row.VoiceId
		end
		for id in goodVoices do
			return id
		end
		return nil
	end

	-- The AudioTextToSpeech of an entry, built for its current VoiceId (nil = cannot build: entry failed)
	local function build(entry: Entry): AudioTextToSpeech?
		const existing = entry.Voice
		if existing ~= nil then
			if existing.VoiceId == entry.VoiceId then
				return existing
			end
			existing:Destroy()
			entry.Voice = nil
		end
		const fade = graph()
		if fade == nil then
			return nil
		end
		const row = VOICES[entry.Speaker]
		const ok, created = pcall(function(): AudioTextToSpeech
			const voice = Instance.new("AudioTextToSpeech")
			voice.Name = `Line_{entry.Speaker}`
			voice.Text = Speech.Spoken(entry.Line.Text or "")
			voice.VoiceId = entry.VoiceId
			if row ~= nil and row.Speed ~= nil then
				voice.Speed = row.Speed
			end
			if row ~= nil and row.Pitch ~= nil then
				voice.Pitch = row.Pitch
			end
			voice.Volume = if row ~= nil then row.Volume else 1
			voice.Parent = folder
			return voice
		end)
		if not ok then
			disable(`AudioTextToSpeech unavailable ({created})`)
			return nil
		end
		const voice = created :: AudioTextToSpeech
		if not wire(voice, fade, voice) then
			voice:Destroy()
			disable("Wire unavailable")
			return nil
		end
		entry.Voice = voice
		return voice
	end

	local pump: () -> ()

	-- A voice loaded: lines that failed on a bad VoiceId get another chance with it
	local function rescue()
		for _, entry in entries do
			if entry.State == "Failed" and entry.BadVoice then
				const id = voiceIdOf(entry.Speaker)
				if id ~= nil and not badVoices[id] then
					entry.VoiceId = id
					entry.State = "Queued"
					entry.Tries = 0
					entry.BadVoice = false
					table.insert(queue, entry)
				end
			end
		end
	end

	local function failed(entry: Entry, status: string)
		entry.Tries += 1
		streak += 1
		pause = math.min(BACKOFF * 2 ^ (entry.Tries - 1), MAX_BACKOFF)
		if streak >= GIVE_UP then
			entry.State = "Failed"
			disable(`{streak} loads failed in a row (last: {status})`)
			return
		end
		if entry.Tries < MAX_TRIES then
			entry.State = "Queued"
			table.insert(queue, 1, entry)
			return
		end
		entry.State = "Failed"
		const id = entry.VoiceId
		if goodVoices[id] then
			return -- the voice works: only this line stays a subtitle
		end
		badVoices[id] = true
		entry.BadVoice = true
		const fallback = voiceIdOf(entry.Speaker)
		if fallback ~= nil and fallback ~= id then
			warnOnce(`voice:{id}`, `text-to-speech VoiceId "{id}" did not load ({status}): using "{fallback}"`)
			rescue()
		else
			warnOnce(`voice:{id}`, `text-to-speech VoiceId "{id}" did not load ({status}): subtitle only for now`)
		end
		-- the other lines of that voice move to the fallback right away (no need to fail each of them)
		for _, other in queue do
			if other.State == "Queued" and other.VoiceId == id and fallback ~= nil and fallback ~= id then
				other.VoiceId = fallback
				other.Tries = 0
			end
		end
	end

	local function loadOne(entry: Entry)
		const voice = build(entry)
		if voice == nil then
			entry.State = "Failed"
			return
		end
		entry.State = "Loading"
		-- inside the one audio queue of the client (LoadQueue, urgent): never next to another sound load
		local ok, status: any = false, nil
		local returned = false
		LoadQueue.Run(function(): boolean?
			ok, status = pcall(function(): Enum.AssetFetchStatus
				return voice:LoadAsync()
			end)
			returned = true
			return not ok or status ~= Enum.AssetFetchStatus.Success
		end, true)
		if not alive or voice.Parent == nil then
			return
		end
		if not returned then
			-- LoadQueue gave up on a LoadAsync that never returned: the retry builds a fresh instance
			voice:Destroy()
			entry.Voice = nil
			failed(entry, "timed out")
			return
		end
		if ok and status == Enum.AssetFetchStatus.Success then
			entry.State = "Loaded"
			streak = 0
			pause = 0
			const fresh = not goodVoices[entry.VoiceId]
			goodVoices[entry.VoiceId] = true
			if fresh then
				rescue()
			end
			const wanted = entry.Wanted
			if wanted ~= nil and enabled then
				entry.Wanted = nil
				if os.clock() - wanted <= LATE then
					start(entry)
				end
			end
			return
		end
		failed(entry, if ok then tostring(status) else `error: {status}`)
	end

	pump = function()
		if working or not enabled or not alive then
			return
		end
		working = true
		task.spawn(function()
			while alive and enabled and #queue > 0 do
				if pause > 0 then
					task.wait(pause)
					pause = 0
				end
				const entry = table.remove(queue, 1)
				if entry ~= nil and entry.State == "Queued" then
					loadOne(entry)
					task.wait(GAP)
				end
			end
			working = false
		end)
	end

	-- Entry of a line (created and queued the first time). nil = no voice for its speaker.
	local function ensure(line: Beat, front: boolean): Entry?
		const key = keyOf(line)
		const existing = entries[key]
		if existing ~= nil then
			return existing
		end
		const speaker = line.Speaker or "walt"
		const id = voiceIdOf(speaker)
		if id == nil then
			return nil
		end
		const entry: Entry = {
			Line = line,
			Speaker = speaker,
			VoiceId = id,
			Voice = nil,
			State = "Queued",
			Tries = 0,
			Wanted = nil,
			BadVoice = false,
		}
		entries[key] = entry
		if front then
			table.insert(queue, 1, entry)
		else
			table.insert(queue, entry)
		end
		return entry
	end

	local function queueAll(lines: { Beat }): { Entry }
		const list: { Entry } = {}
		if not enabled then
			return list
		end
		for _, line in lines do
			if line.Kind == "Line" and (line.Text or "") ~= "" then
				const entry = ensure(line, false)
				if entry ~= nil and table.find(list, entry) == nil then
					table.insert(list, entry)
				end
			end
		end
		pump()
		return list
	end

	-- Moves a queued entry to the front of the load queue
	local function hurry(entry: Entry)
		const index = table.find(queue, entry)
		if index ~= nil and index > 1 then
			table.remove(queue, index)
			table.insert(queue, 1, entry)
		end
	end

	return {
		Prepare = function(lines: { Beat })
			queueAll(lines)
		end,
		Fetch = function(line: Beat): Status
			if not enabled or not alive then
				return "Off"
			end
			const entry = ensure(line, true)
			if entry == nil then
				return "Off"
			end
			if entry.State == "Queued" then
				hurry(entry)
				pump()
			end
			return entry.State
		end,
		Length = function(line: Beat): number?
			const entry = entries[keyOf(line)]
			const voice = if entry ~= nil and entry.State == "Loaded" then entry.Voice else nil
			if voice == nil then
				return nil
			end
			const ok, length = pcall(function(): number
				return voice.TimeLength
			end)
			return if ok and type(length) == "number" and length > 0 then length else nil
		end,
		Preload = function(lines: { Beat }, timeout: number, progress: ((number) -> ())?)
			const list = queueAll(lines)
			const deadline = os.clock() + timeout
			while true do
				local settled = 0
				for _, entry in list do
					if entry.State == "Loaded" or entry.State == "Failed" then
						settled += 1
					end
				end
				const done = not enabled or not alive or settled >= #list
				if progress ~= nil then
					progress(if done or #list == 0 then 1 else settled / #list)
				end
				if done or os.clock() >= deadline then
					return
				end
				task.wait(POLL)
			end
		end,
		Say = function(line: Beat)
			if not enabled then
				return
			end
			const entry = ensure(line, true)
			if entry == nil or entry.State == "Failed" then
				return
			end
			if entry.State == "Loaded" then
				start(entry)
				return
			end
			entry.Wanted = os.clock()
			-- late line: first in the queue
			hurry(entry)
			pump()
		end,
		Stop = function()
			const current = playing
			playing = nil
			if current ~= nil then
				pcall(function()
					current:Pause()
				end)
			end
			for _, entry in entries do
				entry.Wanted = nil
			end
		end,
		Destroy = function()
			alive = false
			table.clear(queue)
			for _, entry in entries do
				if entry.Voice ~= nil then
					entry.Voice:Destroy()
				end
			end
			table.clear(entries)
			playing = nil
			const holder = folder
			folder = nil
			fader = nil
			if holder ~= nil then
				holder:Destroy()
			end
		end,
	}
end

return table.freeze(Speech)
