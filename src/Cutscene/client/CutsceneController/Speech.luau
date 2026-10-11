--!strict
--[[
	Speech: text-to-speech of the cutscene lines (AudioTextToSpeech, Roblox audio API). Defensive by design: the class,
	a property, the load or the play may be missing or fail (beta API, voice ids, region) and then the line simply
	stays a subtitle, with one warning.

	Graph: one AudioTextToSpeech per line -> Wire -> AudioFader (volume = AudioController Master x Voice group x the
	speaker's Content volume) -> Wire -> AudioDeviceOutput (this client only). Voices per speaker in
	Content.Cutscenes.Rules.Voices (VoiceId, Speed, Pitch, Volume); VoiceId "" = that speaker is silent.

	Prepare(lines) loads every line of the segment up front (generation takes time), so Say(line) starts on the beat
	together with the subtitle. A line not loaded yet starts when it loads, if that is still within LATE s of its
	beat; a new line cuts the one playing.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Content = require(ReplicatedStorage.shared.Content)

type Beat = Content.CutsceneBeat

export type Speech = {
	Prepare: (lines: { Beat }) -> (),
	Say: (line: Beat) -> (),
	Stop: () -> (),
	Destroy: () -> (),
}

type Entry = {
	Voice: Instance?, -- the AudioTextToSpeech (typed loosely: the API may not exist)
	Loaded: boolean,
	Failed: boolean,
	Wanted: number?, -- os.clock when Say asked for it before the load finished
}

const VOICES = Content.Cutscenes.Rules.Voices
const FOLDER = "CutsceneVoice"
const LATE = 1 -- s: a line that loads later than this after its beat is not voiced

const Speech = {}

local function keyOf(line: Beat): string
	return `{line.Speaker or "walt"}\0{line.Text or ""}`
end

-- Sets a property that may not exist on this engine version
local function try(instance: Instance, property: string, value: any): boolean
	return (pcall(function()
		(instance :: any)[property] = value
	end))
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
	local warned = false
	const entries: { [string]: Entry } = {}
	local playing: Instance? = nil

	local folder: Instance? = nil
	local fader: Instance? = nil

	local function disable(reason: string)
		enabled = false
		if not warned then
			warned = true
			warn(`[CutsceneController] text-to-speech off, subtitles only: {reason}`)
		end
	end

	-- Fader + device output, built once
	local function graph(): Instance?
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
			try(fade, "Volume", math.clamp(volume(), 0, 2))
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
				(previous :: any):Pause()
			end)
		end
		refreshVolume()
		playing = voice
		const ok, problem = pcall(function()
			(voice :: any).TimePosition = 0;
			(voice :: any):Play()
		end)
		if not ok then
			disable(`Play failed: {problem}`)
		end
	end

	local function load(line: Beat)
		const key = keyOf(line)
		if entries[key] ~= nil then
			return
		end
		const speaker = line.Speaker or "walt"
		const row = VOICES[speaker]
		const entry: Entry = { Voice = nil, Loaded = false, Failed = row == nil or row.VoiceId == "", Wanted = nil }
		entries[key] = entry
		if entry.Failed or row == nil then
			return
		end
		const fade = graph()
		if fade == nil then
			entry.Failed = true
			return
		end
		const ok, created = pcall(function(): Instance
			return Instance.new("AudioTextToSpeech" :: any)
		end)
		if not ok then
			entry.Failed = true
			disable(`AudioTextToSpeech unavailable ({created})`)
			return
		end
		const voice = created :: Instance
		voice.Name = `Line_{speaker}`
		if not try(voice, "Text", line.Text or "") or not try(voice, "VoiceId", row.VoiceId) then
			entry.Failed = true
			voice:Destroy()
			disable("Text/VoiceId not settable")
			return
		end
		if row.Speed ~= nil then
			try(voice, "Speed", row.Speed)
		end
		if row.Pitch ~= nil then
			try(voice, "Pitch", row.Pitch)
		end
		try(voice, "Volume", row.Volume)
		voice.Parent = folder
		if not wire(voice, fade, voice) then
			entry.Failed = true
			voice:Destroy()
			return
		end
		entry.Voice = voice
		task.spawn(function()
			const loaded, status = pcall(function(): any
				return (voice :: any):LoadAsync()
			end)
			if voice.Parent == nil then
				return
			end
			if not loaded or (status ~= nil and status ~= Enum.AssetFetchStatus.Success) then
				-- only this line stays silent (a bad VoiceId of one speaker does not mute the others)
				entry.Failed = true
				if not warned then
					warned = true
					warn(`[CutsceneController] text-to-speech load failed ({status}, VoiceId "{row.VoiceId}"): subtitle only`)
				end
				return
			end
			entry.Loaded = true
			const wanted = entry.Wanted
			if wanted ~= nil and os.clock() - wanted <= LATE and enabled then
				entry.Wanted = nil
				start(entry)
			end
		end)
	end

	return {
		Prepare = function(lines: { Beat })
			if not enabled then
				return
			end
			for _, line in lines do
				if line.Kind == "Line" then
					load(line)
					if not enabled then
						return
					end
				end
			end
		end,
		Say = function(line: Beat)
			if not enabled then
				return
			end
			load(line)
			const entry = entries[keyOf(line)]
			if entry == nil or entry.Failed then
				return
			end
			if entry.Loaded then
				start(entry)
			else
				entry.Wanted = os.clock()
			end
		end,
		Stop = function()
			const current = playing
			playing = nil
			if current ~= nil then
				pcall(function()
					(current :: any):Pause()
				end)
			end
			for _, entry in entries do
				entry.Wanted = nil
			end
		end,
		Destroy = function()
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
