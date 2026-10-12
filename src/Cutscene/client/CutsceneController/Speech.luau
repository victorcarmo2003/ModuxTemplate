--!strict
--[[
	Speech: text-to-speech of the cutscene lines (AudioTextToSpeech: Text, VoiceId, Speed, Pitch, Volume, LoadAsync ->
	Enum.AssetFetchStatus, IsLoaded, Play/Pause, Ended). Defensive by design: the class, a property, the load or the play
	may be missing or fail, and then the line simply stays a subtitle.

	Graph: one AudioTextToSpeech per sentence -> Wire -> AudioFader (volume = AudioController Master x Voice group x the
	speaker's Content volume) -> Wire -> AudioDeviceOutput (this client only). Voices per speaker in
	Content.Cutscenes.Rules.Voices (VoiceId, Speed, Pitch, Volume); VoiceId "" = that speaker is silent.

	Pauses (user feedback 2026-10-11: "Can you start today? GREAT" ran together): a line with several sentences is
	spoken as a chain of AudioTextToSpeech, one per sentence (Speech.Pieces: split after . ? ! ... / the unicode
	ellipsis), with a pause after each one: PAUSE_STOP after ".", PAUSE_ASK after "?" or "!", PAUSE_DOTS after "...".
	A "..." standing alone between two sentences ("today? ... Great.") adds PAUSE_ALONE to the pause before it. The
	subtitle keeps the whole line; every piece is loaded in the same queue, and a line counts as loaded (Fetch,
	Preload) only when all of its pieces are; Length = the pieces' TimeLength + the pauses between them.

	Loading (playtest 2026-10-11: every line of the segment called LoadAsync in the same frame and the engine refused
	them all with "Failed to load sound : Rate limited by the client" + one "Failed to load text to speech" error each):
	  * one request at a time (GAP s between two), never a burst, and inside the client's one audio queue
	    (Audio/AudioController/LoadQueue), so no sound preload runs next to it;
	  * a failed load is retried (MAX_TRIES) after a growing pause (BACKOFF x 2^n, up to MAX_BACKOFF) that holds the
	    whole queue, so a rate limit clears before the next request;
	  * a VoiceId that never loaded a single piece in this session after MAX_TRIES is judged bad; its lines move to a
	    voice that did load (one warning), or wait for one;
	  * GIVE_UP failures in a row pause the queue COOLDOWN s (a rate limit after the intro's burst); text-to-speech is
	    switched off (subtitles only, one warning) only when no voice has ever loaded in this session and it happens
	    twice in a row;
	  * a line that failed is tried again when it is fetched RETRY_AFTER s later (Fetch).
	Voice health (good / bad VoiceIds) is shared by every Speech of the session (module-level).

	Root cause of Walt's silent tutorial call (playtest 2026-10-11, fixed here): the voice health and the warning flag
	were split wrong. goodVoices / badVoices lived inside each Speech, so the tutorial call's fresh Speech did not know
	that Walt's VoiceId had just worked in the intro: its first transient failures right after the intro (the call
	queues ~45 lines on top of the intro's) judged Walt's VoiceId bad after MAX_TRIES (no fallback: new lines "Off")
	and GIVE_UP failures in a row switched the whole call to subtitles for the session. The one `warnedOnce` flag of the
	module, already spent by the intro, then hid the "off" warning, so it failed silently.

	Preload(lines, timeout, progress) queues every line and yields until all are settled (loaded or failed) or the
	timeout; the rest keeps loading in the background (LoadingController, before the intro). Prepare(lines) queues
	without waiting. Say(line) plays a loaded line on its beat; one still loading jumps to the front of the queue and
	plays when it loads, if that is still within LATE s of its beat. A new line NEVER cuts the one speaking: it waits its
turn (Busy() = speaking or queued); only Stop / Destroy cut.
	Fetch(line) (Walt's tutorial call) queues the line first and returns its state, so a caller without a fixed
	timeline can hold the line until the voice is ready ("Loaded") or gone ("Failed" / "Off": subtitle only).
	Reason(line) says why a line has no voice (for the caller's warning). Length(line) = seconds of a loaded line.
	Peek(line) = state of a line without queueing or hurrying it; Stats() = lines per state, load queue size, fader
	volume, on/off (dev tools: TutorialController /dev voice, tutorial debug panel).
	Warnings: once per kind per session, for every Speech together (module-level).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LogService = game:GetService("LogService")
local SoundService = game:GetService("SoundService")
local StarterPlayer = game:GetService("StarterPlayer")
local Content = require(ReplicatedStorage.shared.Content)
local LoadQueue = require(StarterPlayer.StarterPlayerScripts.client.Audio.AudioController.LoadQueue)

type Beat = Content.CutsceneBeat

export type Status = "Queued" | "Loading" | "Loaded" | "Failed" | "Off"

-- Lines per load state, pieces waiting, fader volume (nil = no graph yet), on/off and why off
export type Stats = {
	Queued: number,
	Loading: number,
	Loaded: number,
	Failed: number,
	Waiting: number,
	Fader: number?,
	Enabled: boolean,
	OffReason: string,
}

export type Speech = {
	Prepare: (lines: { Beat }) -> (),
	-- state of a line without queueing it (nil = never queued)
	Peek: (line: Beat) -> Status?,
	Stats: () -> Stats,
	-- queues the line first (if not loaded yet) and returns its state; "Off" = no voice for it (subtitle only)
	Fetch: (line: Beat) -> Status,
	-- why the line has no voice right now ("" = it has one, or it is on its way)
	Reason: (line: Beat) -> string,
	-- seconds of a loaded line, pauses included (nil = not loaded or unknown)
	Length: (line: Beat) -> number?,
	-- yields; progress(fraction 0..1) while it waits
	Preload: (lines: { Beat }, timeout: number, progress: ((number) -> ())?) -> (),
	-- Plays a line when its turn comes. handlers.OnStart(line) = the first piece really plays, OnEnd(line) = the last
	-- piece (and its pauses) ended, OnMiss(line) = the line will not be voiced (off / failed / late / cut by a failure).
	-- Exactly one of OnStart or OnMiss fires (OnEnd follows OnStart), unless Stop / Destroy cut it (nothing fires).
	-- Returns cancel(): drops the line if it has not started yet (no handler fires).
	Say: (line: Beat, handlers: Handlers?) -> () -> (),
	-- a line is speaking or waiting its turn (lines never cut each other: they queue)
	Busy: () -> boolean,
	Stop: () -> (),
	Destroy: () -> (),
}

export type Handlers = {
	OnStart: ((line: Beat) -> ())?,
	OnEnd: ((line: Beat) -> ())?,
	OnMiss: ((line: Beat) -> ())?,
}

-- One sentence of a line to speak, and the pause after it
export type Part = { Text: string, Pause: number }

type State = "Queued" | "Loading" | "Loaded" | "Failed"

type Piece = {
	Text: string,
	Pause: number, -- s of silence after this piece (0 for the last one)
	Owner: Entry,
	VoiceId: string, -- the id in use (the speaker's, or the fallback after a bad id)
	Voice: AudioTextToSpeech?,
	State: State,
	Tries: number,
	BadVoice: boolean, -- failed because its VoiceId is bad (re-queued when a good voice appears)
}

-- One Say of a line: its handlers and where it stands
type Job = {
	Entry: Entry,
	Line: Beat,
	Handlers: Handlers?,
	Cancelled: boolean,
	Done: boolean, -- a handler of start / miss already fired
}

type Entry = {
	Speaker: string,
	Pieces: { Piece },
	Wanted: number?, -- os.clock when Say asked for it before the load finished
	WantedJob: Job?, -- that Say
	FailedAt: number, -- os.clock of the last failure (Fetch tries it again RETRY_AFTER s later)
	Reason: string, -- last load problem ("" = none)
}

const VOICES = Content.Cutscenes.Rules.Voices
const FOLDER = "CutsceneVoice"
const LATE = 1 -- s: a line that loads later than this after its beat is not voiced
const GAP = 0.1 -- s between two load requests (LoadQueue adds its own gap)
const MAX_TRIES = 3 -- load attempts per piece (same VoiceId)
const BACKOFF = 1.5 -- s of pause after a failure, doubled per try of that piece
const MAX_BACKOFF = 6
const GIVE_UP = 6 -- failures in a row (no success between) that pause the queue
const COOLDOWN = 20 -- s the queue waits after GIVE_UP failures in a row
const RETRY_AFTER = 15 -- s after a failure before Fetch tries the line again
const POLL = 0.1 -- s between two progress reads of Preload
-- PROVISIONAL pauses between the sentences of one line (user feedback 2026-10-11)
const PAUSE_STOP = 0.3 -- after "."
const PAUSE_ASK = 0.45 -- after "?" or "!"
const PAUSE_DOTS = 0.6 -- after "..."
const PAUSE_ALONE = 0.3 -- a "..." standing alone adds this to the pause before it
const PIECE_SLACK = 0.5 -- s past a piece's TimeLength before the chain moves on without its Ended
const LINE_GAP = 0.15 -- s between the end of a line and the next one
const PIECE_MAX = 12 -- s a piece of unknown length may play before the chain moves on

const Speech = {}

-- Session-wide (every Speech: intro and tutorial call)
const goodVoices: { [string]: boolean } = {}
const badVoices: { [string]: boolean } = {}
const warned: { [string]: boolean } = {}

-- "Failed to load sound : FilteredText" (Roblox filters the TTS text) reaches the output, not the LoadAsync status
-- (that is a plain Failure, like a rate limit). Loads are serialized by LoadQueue, so a message that arrives while
-- one LoadAsync runs belongs to it: the failure is deterministic (same text, same result) and is never retried.
local filteredCount = 0
local filteredWatch = false
-- "Failed to load sound : NotEnoughQuota" (playtest 2026-10-12): the text-to-speech quota of the client is spent. Every
-- further request (and each retry) spends more of it, so a quota failure is no retry: session-wide pause that grows
-- QUOTA_FIRST -> QUOTA_MAX s per quota failure in a row (reset by a load that works); the lines stay subtitles and Fetch
-- asks for them again only after the pause.
const MAX_AHEAD = 12 -- loaded pieces not played yet: past it only a line somebody waits for loads (quota, 2026-10-12)
-- one counter per Speech (intro, tutorial call...): the MAX_AHEAD cap is for the whole client, not per Speech
const aheadCounters: { () -> number } = {}
const QUOTA_FIRST = 10 -- s
const QUOTA_MAX = 60 -- s
local quotaUntil = 0 -- os.clock until which no text-to-speech request goes out
local quotaStep = 0 -- quota failures in a row
local quotaHits = 0 -- quota failures of the session (the one warn)

local function watchFiltered()
	if filteredWatch then
		return
	end
	filteredWatch = true
	pcall(function()
		LogService.MessageOut:Connect(function(message: string)
			if string.find(message, "FilteredText", 1, true) then
				filteredCount += 1
			end
		end)
	end)
end

local function warnOnce(key: string, message: string)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(`[Speech] {message}`)
end

-- Text sent to AudioTextToSpeech. Roblox filters TTS text and refuses lines with phone-number-like digit runs
-- ("Failed to load sound : FilteredText", 2026-10-11: "555-0179... Here goes."); the subtitle keeps the number, the
-- voice skips it.
function Speech.Spoken(text: string): string
	local out = string.gsub(text, "%d[%d%-%s]*%d", "")
	out = string.gsub(out, "^[%s%.,!%?]+", "")
	out = string.gsub(out, "%s+", " ")
	return out
end

local function pauseOf(punctuation: string): number
	if string.find(punctuation, "...", 1, true) then
		return PAUSE_DOTS
	elseif string.find(punctuation, "[%?!]") then
		return PAUSE_ASK
	end
	return PAUSE_STOP
end

-- The sentences of a line to speak, in order, with the pause after each (the last one has none). Empty = nothing to
-- say (a line made only of a phone number or punctuation).
function Speech.Pieces(text: string): { Part }
	const spoken = string.gsub(Speech.Spoken(text), "\u{2026}", "...")
	const parts: { Part } = {}
	local position = 1
	while position <= #spoken do
		const first, last = string.find(spoken, "[%.%?!]+", position)
		local body: string
		local punctuation = ""
		if first == nil or last == nil then
			body = string.sub(spoken, position)
			position = #spoken + 1
		else
			body = string.sub(spoken, position, first - 1)
			punctuation = string.sub(spoken, first, last)
			position = last + 1
		end
		body = string.gsub(string.gsub(body, "^[%s\"]+", ""), "[%s\"]+$", "")
		if string.find(body, "%w") then
			table.insert(parts, { Text = body .. punctuation, Pause = pauseOf(punctuation) })
		elseif #parts > 0 and string.find(punctuation, "...", 1, true) then
			parts[#parts].Pause += PAUSE_ALONE
		end
	end
	if #parts > 0 then
		parts[#parts].Pause = 0
	end
	return parts
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

local function stateOf(entry: Entry): State
	local loading = false
	local queued = false
	for _, piece in entry.Pieces do
		if piece.State == "Failed" then
			return "Failed"
		end
		loading = loading or piece.State == "Loading"
		queued = queued or piece.State == "Queued"
	end
	return if loading then "Loading" elseif queued then "Queued" else "Loaded"
end

local function timeLength(voice: AudioTextToSpeech): number?
	const ok, length = pcall(function(): number
		return voice.TimeLength
	end)
	return if ok and type(length) == "number" and length > 0 then length else nil
end

function Speech.new(volume: () -> number): Speech
	local enabled = true
	local offReason = ""
	local alive = true
	const entries: { [string]: Entry } = {}
	const queue: { Piece } = {}
	local working = false
	local pause = 0 -- s the queue waits before its next request (backoff)
	local streak = 0 -- failures in a row
	local giveUps = 0 -- GIVE_UP pauses in a row (no success between)
	local playing: AudioTextToSpeech? = nil
	local token = 0 -- the chain of pieces playing (Stop bumps it)
	const spoken: { Job } = {} -- lines waiting for the one speaking to end
	local speaking = false -- a chain is running (playing or waiting its turn)

	local folder: Instance? = nil
	local fader: AudioFader? = nil

	-- A handler of a Say (never throws into the chain)
	local function notify(job: Job, which: string)
		const handlers = job.Handlers
		if handlers == nil then
			return
		end
		const callback = if which == "Start"
			then handlers.OnStart
			elseif which == "End" then handlers.OnEnd
			else handlers.OnMiss
		if callback ~= nil then
			const ok, problem = pcall(function()
				callback(job.Line)
			end)
			if not ok then
				warn(`[Speech] handler On{which} failed: {problem}`)
			end
		end
	end

	-- The line will not be voiced
	local function miss(job: Job)
		if job.Done or job.Cancelled then
			return
		end
		job.Done = true
		notify(job, "Miss")
	end

	-- A line that waited for its load and will not get its voice
	local function dropWanted(entry: Entry)
		const job = entry.WantedJob
		entry.Wanted = nil
		entry.WantedJob = nil
		if job ~= nil then
			miss(job)
		end
	end

	local function disable(reason: string)
		enabled = false
		offReason = reason
		table.clear(queue)
		for _, entry in entries do
			dropWanted(entry)
		end
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

	-- Stops the chain playing (if any)
	local function halt()
		token += 1
		speaking = false
		table.clear(spoken)
		const current = playing
		playing = nil
		if current ~= nil then
			pcall(function()
				current:Pause()
			end)
		end
	end

	-- Plays one piece and yields until it ended (or the chain was cut). false = Play failed.
	local function playPiece(voice: AudioTextToSpeech, mine: number, onStart: () -> ()): boolean
		local ended = false
		const ok, connection = pcall(function(): RBXScriptConnection
			return voice.Ended:Once(function()
				ended = true
			end)
		end)
		playing = voice
		const played, problem = pcall(function()
			voice.TimePosition = 0
			voice:Play()
		end)
		if not played then
			if ok then
				(connection :: RBXScriptConnection):Disconnect()
			end
			disable(`Play failed: {problem}`)
			return false
		end
		const length = timeLength(voice)
		const started = os.clock()
		-- soft deadline: the piece's length plus slack (start latency included); past it the piece is only waited for
		-- while the engine still says it is playing, up to a hard cap (a voice is never cut by a clock that is short)
		const soft = started + (if length ~= nil then length * 1.25 + PIECE_SLACK + 1 else PIECE_MAX)
		const hard = started + (if length ~= nil then length * 2 + PIECE_MAX else PIECE_MAX * 2)
		local sawPlaying = false
		local announced = false
		local function announce()
			if not announced then
				announced = true
				onStart()
			end
		end
		while alive and token == mine and not ended do
			const now = os.clock()
			if now >= hard or (now >= soft and not sawPlaying) then
				break
			end
			task.wait(0.05)
			const okPlaying, isPlaying = pcall(function(): boolean
				return voice.IsPlaying
			end)
			if okPlaying and isPlaying == true then
				sawPlaying = true
				if token == mine then
					announce()
				end
			elseif okPlaying and isPlaying == false then
				-- Ended missing on this engine: IsPlaying going false after it was true ends the piece (never before it
				-- was seen true: playback may take a moment to start)
				if sawPlaying then
					break
				end
			end
			if now >= soft and okPlaying and isPlaying == false then
				break
			end
		end
		if ok then
			(connection :: RBXScriptConnection):Disconnect()
		end
		if token == mine then
			announce() -- a piece too short to be seen playing still counts as started
		end
		return true
	end

	-- Plays a line to its end: its pieces in order, with the pause after each. Returns "Cut" (Stop / Destroy), "Failed"
	-- (a play failed) or "Done"; job.Done = true once the first piece played (OnStart fired).
	local function playEntry(job: Job, mine: number): string
		const entry = job.Entry
		local function onStart()
			if not job.Done then
				job.Done = true
				notify(job, "Start")
			end
		end
		for index, piece in entry.Pieces do
			if not alive or token ~= mine then
				return "Cut"
			end
			const voice = piece.Voice
			if piece.State == "Loaded" and voice ~= nil and voice.Parent ~= nil then
				if not playPiece(voice, mine, onStart) then
					return "Failed"
				end
			end
			if index < #entry.Pieces and piece.Pause > 0 and token == mine then
				task.wait(piece.Pause)
			end
		end
		return if alive and token == mine then "Done" else "Cut"
	end

	-- Pieces loaded and not played yet (each is a live AudioTextToSpeech + Wire: 94 of them were alive in the playtest)
	local function ownAhead(): number
		local count = 0
		if not alive then
			return 0
		end
		for _, entry in entries do
			for _, piece in entry.Pieces do
				if piece.State == "Loaded" then
					count += 1
				end
			end
		end
		return count
	end
	table.insert(aheadCounters, ownAhead)

	local function loadedAhead(): number
		local count = 0
		for _, counter in aheadCounters do
			count += counter()
		end
		return count
	end

	-- A line that played to its end gives its voices back (Destroy) and leaves `entries`: a later Say loads it again
	local function release(entry: Entry, line: Beat)
		for _, piece in entry.Pieces do
			const voice = piece.Voice
			piece.Voice = nil
			if voice ~= nil then
				pcall(function()
					voice:Destroy()
				end)
			end
		end
		if entries[keyOf(line)] == entry then
			entries[keyOf(line)] = nil
		end
	end

	-- A line never cuts the one speaking (user feedback 2026-10-11: every voice was cut): it waits its turn in
	-- `spoken` and starts once the line before it ended, LINE_GAP s later. Only Stop / Destroy (halt) cut the chain.
	local function start(job: Job)
		for _, waiting in spoken do
			if waiting.Entry == job.Entry then
				miss(job) -- the same line is already waiting its turn
				return
			end
		end
		refreshVolume()
		table.insert(spoken, job)
		if speaking then
			return
		end
		speaking = true
		const mine = token
		task.spawn(function()
			while alive and token == mine and #spoken > 0 do
				const next = table.remove(spoken, 1)
				if next ~= nil and not next.Cancelled then
					const result = playEntry(next, mine)
					if result == "Cut" then
						release(next.Entry, next.Line) -- a cut line gives its voices back too
						break
					end
					-- "Done" or "Failed": started lines end, lines with nothing to play are missed
					if next.Done then
						notify(next, "End")
						if result == "Done" then
							release(next.Entry, next.Line)
						end
					else
						miss(next)
					end
					if result == "Failed" then
						break
					end
				end
				if token == mine and #spoken > 0 then
					task.wait(LINE_GAP)
				end
			end
			if token == mine then
				-- a failure left lines behind: they will not be voiced
				const rest = table.clone(spoken)
				table.clear(spoken)
				for _, job in rest do
					miss(job)
				end
				playing = nil
				speaking = false
			end
		end)
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

	-- The AudioTextToSpeech of a piece, built for its current VoiceId (nil = cannot build: piece failed)
	local function build(piece: Piece): AudioTextToSpeech?
		const existing = piece.Voice
		if existing ~= nil then
			if existing.VoiceId == piece.VoiceId and existing.Parent ~= nil then
				return existing
			end
			existing:Destroy()
			piece.Voice = nil
		end
		const fade = graph()
		if fade == nil then
			return nil
		end
		const speaker = piece.Owner.Speaker
		const row = VOICES[speaker]
		const ok, created = pcall(function(): AudioTextToSpeech
			const voice = Instance.new("AudioTextToSpeech")
			voice.Name = `Line_{speaker}`
			voice.Text = piece.Text
			voice.VoiceId = piece.VoiceId
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
		piece.Voice = voice
		return voice
	end

	-- A failed piece back in the queue (front), with the voice its speaker uses now. false = no voice for it.
	local function rearm(piece: Piece): boolean
		const id = voiceIdOf(piece.Owner.Speaker)
		if id == nil or badVoices[id] then
			return false
		end
		piece.VoiceId = id
		piece.State = "Queued"
		piece.Tries = 0
		piece.BadVoice = false
		if table.find(queue, piece) == nil then
			table.insert(queue, 1, piece)
		end
		return true
	end

	-- A voice loaded: pieces that failed on a bad VoiceId get another chance with it
	local function rescue()
		for _, entry in entries do
			for _, piece in entry.Pieces do
				if piece.State == "Failed" and piece.BadVoice then
					rearm(piece)
				end
			end
		end
	end

	local function failed(piece: Piece, status: string)
		const owner = piece.Owner
		piece.Tries += 1
		streak += 1
		owner.Reason = status
		pause = math.min(BACKOFF * 2 ^ (piece.Tries - 1), MAX_BACKOFF)
		if streak >= GIVE_UP then
			streak = 0
			giveUps += 1
			if next(goodVoices) == nil and giveUps >= 2 then
				piece.State = "Failed"
				owner.FailedAt = os.clock()
				disable(`{GIVE_UP * 2} loads failed and no voice ever loaded (last: {status})`)
				return
			end
			-- a rough patch (rate limit after a burst): wait it out, keep going
			pause = COOLDOWN
			warnOnce(
				"cooldown",
				`{GIVE_UP} text-to-speech loads failed in a row (last: {status}): pausing loads {COOLDOWN} s`
			)
		end
		if piece.Tries < MAX_TRIES then
			piece.State = "Queued"
			table.insert(queue, 1, piece)
			return
		end
		piece.State = "Failed"
		owner.FailedAt = os.clock()
		if piece.Voice ~= nil then
			piece.Voice:Destroy()
			piece.Voice = nil
		end
		dropWanted(owner)
		const id = piece.VoiceId
		if goodVoices[id] then
			-- the voice works: only this line stays a subtitle (tried again on a later Fetch)
			warnOnce(`line:{status}`, `a line stays a subtitle, its voice did not load ({status}): "{piece.Text}"`)
			return
		end
		badVoices[id] = true
		piece.BadVoice = true
		const fallback = voiceIdOf(owner.Speaker)
		if fallback ~= nil and fallback ~= id then
			warnOnce(`voice:{id}`, `text-to-speech VoiceId "{id}" did not load ({status}): using "{fallback}"`)
			rescue()
		else
			warnOnce(`voice:{id}`, `text-to-speech VoiceId "{id}" did not load ({status}): subtitle only for now`)
		end
		-- the other pieces of that voice move to the fallback right away (no need to fail each of them)
		for _, other in queue do
			if other.State == "Queued" and other.VoiceId == id and fallback ~= nil and fallback ~= id then
				other.VoiceId = fallback
				other.Tries = 0
			end
		end
	end

	local function loadOne(piece: Piece)
		const voice = build(piece)
		if voice == nil then
			piece.State = "Failed"
			piece.Owner.FailedAt = os.clock()
			piece.Owner.Reason = if offReason ~= "" then offReason else "could not build the voice"
			dropWanted(piece.Owner)
			return
		end
		piece.State = "Loading"
		watchFiltered()
		const filteredBefore = filteredCount
		const quotaBefore = LoadQueue.QuotaMessages()
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
			piece.Voice = nil
			failed(piece, "timed out")
			return
		end
		if ok and status == Enum.AssetFetchStatus.Success then
			piece.State = "Loaded"
			streak = 0
			giveUps = 0
			pause = 0
			quotaStep = 0
			const fresh = not goodVoices[piece.VoiceId]
			goodVoices[piece.VoiceId] = true
			badVoices[piece.VoiceId] = nil
			if fresh then
				rescue()
			end
			const owner = piece.Owner
			const wanted = owner.Wanted
			if wanted ~= nil and enabled and stateOf(owner) == "Loaded" then
				const job = owner.WantedJob
				owner.Wanted = nil
				owner.WantedJob = nil
				if job ~= nil and not job.Cancelled then
					if os.clock() - wanted <= LATE then
						start(job)
					else
						miss(job)
					end
				end
			end
			return
		end
		if ok then
			task.wait(0.05) -- the log line can land a frame after LoadAsync returns
		end
		if not alive then
			return
		end
		if ok and LoadQueue.QuotaMessages() > quotaBefore then
			-- quota spent: no retry, no streak, the voice stays good; the line waits out the pause as a subtitle
			quotaStep += 1
			quotaHits += 1
			const wait = math.min(QUOTA_FIRST * 2 ^ (quotaStep - 1), QUOTA_MAX)
			quotaUntil = os.clock() + wait
			piece.State = "Failed"
			piece.BadVoice = false
			-- the failed piece gives its instance back (a quota-limited client held 70+ AudioTextToSpeech + Wire)
			if piece.Voice ~= nil then
				piece.Voice:Destroy()
				piece.Voice = nil
			end
			const owner = piece.Owner
			owner.FailedAt = os.clock() + wait - RETRY_AFTER
			owner.Reason = "text-to-speech quota"
			dropWanted(owner)
			warnOnce(
				"quota",
				`text-to-speech quota spent (NotEnoughQuota): no voice requests for {wait} s (then {QUOTA_MAX} s at most), `
					.. "lines stay subtitles"
			)
			return
		end
		if ok and filteredCount > filteredBefore then
			-- filtered text: no retry, no backoff, no streak, the voice stays good; subtitle only for this line
			piece.State = "Failed"
			piece.BadVoice = false
			const owner = piece.Owner
			owner.FailedAt = math.huge -- Fetch never tries it again
			owner.Reason = "text filtered by Roblox"
			dropWanted(owner)
			warnOnce(`filtered:{piece.Text}`, `text-to-speech text was filtered, line stays a subtitle: "{piece.Text}"`)
			return
		end
		failed(piece, if ok then tostring(status) else `error: {status}`)
	end

	local function pump()
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
				const quotaWait = quotaUntil - os.clock()
				if quotaWait > 0 then
					task.wait(quotaWait)
				end
				if loadedAhead() >= MAX_AHEAD and queue[1] ~= nil and queue[1].Owner.Wanted == nil then
					task.wait(1) -- enough voices ready: the rest waits for a line that is asked for
					continue
				end
				const piece = table.remove(queue, 1)
				if piece ~= nil and piece.State == "Queued" then
					loadOne(piece)
					task.wait(GAP)
				end
			end
			working = false
		end)
	end

	-- Entry of a line (created and its pieces queued the first time). nil = no voice for it (speaker without a
	-- VoiceId, nothing speakable).
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
		const parts = Speech.Pieces(line.Text or "")
		if #parts == 0 then
			return nil
		end
		const entry: Entry = { Speaker = speaker, Pieces = {}, Wanted = nil, WantedJob = nil, FailedAt = 0, Reason = "" }
		for index, part in parts do
			const piece: Piece = {
				Text = part.Text,
				Pause = part.Pause,
				Owner = entry,
				VoiceId = id,
				Voice = nil,
				State = "Queued",
				Tries = 0,
				BadVoice = false,
			}
			entry.Pieces[index] = piece
			if front then
				table.insert(queue, index, piece)
			else
				table.insert(queue, piece)
			end
		end
		entries[key] = entry
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

	-- Moves the queued pieces of an entry to the front of the load queue, in order
	local function hurry(entry: Entry)
		local at = 1
		for _, piece in entry.Pieces do
			const index = table.find(queue, piece)
			if index ~= nil then
				table.remove(queue, index)
				table.insert(queue, at, piece)
				at += 1
			end
		end
	end

	-- A failed line tried again (Fetch) once RETRY_AFTER s passed, when its speaker has a usable voice
	local function retry(entry: Entry)
		if stateOf(entry) ~= "Failed" or os.clock() - entry.FailedAt < RETRY_AFTER then
			return
		end
		for _, piece in entry.Pieces do
			if piece.State == "Failed" then
				rearm(piece)
			end
		end
	end

	return {
		Prepare = function(lines: { Beat })
			queueAll(lines)
		end,
		Peek = function(line: Beat): Status?
			if not enabled or not alive then
				return "Off"
			end
			const entry = entries[keyOf(line)]
			return if entry ~= nil then stateOf(entry) else nil
		end,
		Stats = function(): Stats
			const stats: Stats = {
				Queued = 0,
				Loading = 0,
				Loaded = 0,
				Failed = 0,
				Waiting = #queue,
				Fader = nil,
				Enabled = enabled and alive,
				OffReason = offReason,
			}
			for _, entry in entries do
				const state = stateOf(entry)
				if state == "Queued" then
					stats.Queued += 1
				elseif state == "Loading" then
					stats.Loading += 1
				elseif state == "Loaded" then
					stats.Loaded += 1
				else
					stats.Failed += 1
				end
			end
			const fade = fader
			if fade ~= nil then
				pcall(function()
					stats.Fader = fade.Volume
				end)
			end
			return stats
		end,
		Fetch = function(line: Beat): Status
			if not enabled or not alive then
				return "Off"
			end
			const entry = ensure(line, true)
			if entry == nil then
				return "Off"
			end
			retry(entry)
			const state = stateOf(entry)
			if state == "Queued" or state == "Loading" then
				hurry(entry)
				pump()
			end
			return state
		end,
		Reason = function(line: Beat): string
			if not alive then
				return "speech destroyed"
			end
			if not enabled then
				return `text-to-speech off ({offReason})`
			end
			const speaker = line.Speaker or "walt"
			const entry = entries[keyOf(line)]
			if entry == nil then
				const row = VOICES[speaker]
				if row == nil or row.VoiceId == "" then
					return `speaker "{speaker}" has no VoiceId (Content.Cutscenes.Rules.Voices)`
				end
				if voiceIdOf(speaker) == nil then
					return `VoiceId "{row.VoiceId}" of "{speaker}" judged bad and no other voice loaded`
				end
				if #Speech.Pieces(line.Text or "") == 0 then
					return "nothing speakable in the text"
				end
				return "not queued yet"
			end
			const state = stateOf(entry)
			if state == "Failed" then
				return `load failed ({if entry.Reason ~= "" then entry.Reason else "unknown"})`
			elseif state == "Loaded" then
				return ""
			end
			const problem = if entry.Reason ~= "" then `, last problem: {entry.Reason}` else ""
			return `voice still {string.lower(state)} ({#queue} pieces waiting in the queue{problem})`
		end,
		Length = function(line: Beat): number?
			const entry = entries[keyOf(line)]
			if entry == nil or stateOf(entry) ~= "Loaded" then
				return nil
			end
			local total = 0
			for index, piece in entry.Pieces do
				const voice = piece.Voice
				const length = if voice ~= nil then timeLength(voice) else nil
				if length == nil then
					return nil
				end
				total += length
				if index < #entry.Pieces then
					total += piece.Pause
				end
			end
			return total
		end,
		Preload = function(lines: { Beat }, timeout: number, progress: ((number) -> ())?)
			const list = queueAll(lines)
			local total = 0
			for _, entry in list do
				total += #entry.Pieces
			end
			const deadline = os.clock() + timeout
			while true do
				local settled = 0
				for _, entry in list do
					for _, piece in entry.Pieces do
						if piece.State == "Loaded" or piece.State == "Failed" then
							settled += 1
						end
					end
				end
				const goal = math.min(total, MAX_AHEAD) -- the loader keeps MAX_AHEAD voices ready, no more
				const done = not enabled or not alive or settled >= goal
				if progress ~= nil then
					progress(if done or goal == 0 then 1 else settled / goal)
				end
				if done or os.clock() >= deadline then
					return
				end
				task.wait(POLL)
			end
		end,
		Say = function(line: Beat, handlers: Handlers?): () -> ()
			const job: Job = { Entry = nil :: any, Line = line, Handlers = handlers, Cancelled = false, Done = false }
			local function cancel()
				job.Cancelled = true
				const owner = job.Entry
				if owner ~= nil and owner.WantedJob == job then
					owner.Wanted = nil
					owner.WantedJob = nil
				end
				const index = table.find(spoken, job)
				if index ~= nil then
					table.remove(spoken, index)
				end
			end
			if not enabled or not alive then
				miss(job)
				return cancel
			end
			const entry = ensure(line, true)
			if entry == nil then
				miss(job)
				return cancel
			end
			job.Entry = entry
			const state = stateOf(entry)
			if state == "Failed" then
				miss(job)
				return cancel
			end
			if state == "Loaded" then
				start(job)
				return cancel
			end
			-- a newer Say of the same line takes over the wait
			dropWanted(entry)
			entry.Wanted = os.clock()
			entry.WantedJob = job
			-- late line: first in the queue
			hurry(entry)
			pump()
			return cancel
		end,
		Busy = function(): boolean
			return speaking and alive
		end,
		Stop = function()
			halt()
			for _, entry in entries do
				entry.Wanted = nil
				entry.WantedJob = nil
			end
		end,
		Destroy = function()
			alive = false
			halt()
			table.clear(queue)
			for _, entry in entries do
				for _, piece in entry.Pieces do
					const voice = piece.Voice
					piece.Voice = nil
					if voice ~= nil then
						voice:Destroy()
					end
				end
			end
			table.clear(entries)
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
