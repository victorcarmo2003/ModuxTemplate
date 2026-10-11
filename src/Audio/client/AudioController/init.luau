--!strict
--[[
	AudioController (TASK-076; architecture.md §19.21, T55; content-data.md §3.21; sound-list.md §0, §2, §6)

	Every sound of the game is played here, on the client. No network of its own: each controller calls Play/Loop on
	the event it already receives (Sale, Notice, Call, Lights...). The server never creates a Sound.

	- SoundGroups in SoundService: Master > Music, Ambient, Sfx, Voice, Ui. SetVolume(group, 0..1) is the hook for a
	  future settings screen (Provisional: not persisted).
	- Play(key, at?, opts?) -> Sound?: one-shot from Content.Sounds, pooled per key. `at` = Vector3 (temporary
	  Attachment in Terrain) or Instance (BasePart/Attachment, or the first BasePart of a Model); rows with
	  Spatial = false always play on screen. Cap Content.SoundRules.MaxVoices (12, §12.5) counting one-shots and loops
	  (music is apart): when full, the oldest one-shot is stolen; if only loops are playing, the new sound is dropped.
	  Rows with a single variation get +-5% pitch (sound-list §2) unless opts.Vary says otherwise.
	- Loop(key, at, on) -> Sound?: one looped voice per (key, at); on = false stops it. A destroyed anchor ends it.
	- Music: the highest Priority cue of Content.Music whose When holds for RoundController (Phase, IsNight,
	  NightWindow); PushMusic(cue) overrides (cutscene, finale) until PopMusic(cue). Crossfade with the cue's
	  FadeOut/FadeIn. An anomaly never changes the music (sound-list §6). Today the cues are lobby and finale only.
	- Shift music (user decision 2026-10-10, sound-list §3): when RoundController enters SoundRules.ShiftMusicPhase
	  (Prep) of a new shift, one track of SoundRules.ShiftMusic.Day/Night plays once (no loop), not the same track as
	  the last shift of that kind. A client that sees the phase more than ShiftMusicFresh s after it started (late
	  joiner, reconnect) hears nothing; a retried night counts as a new shift. One music at a time: a cue (finale,
	  cutscene push) or a cutscene playing (attribute CutsceneActive on the LocalPlayer, set by CutsceneController)
	  fades the shift track out, and a shift that starts while one of them is on keeps its track pending until both
	  are off (still in that shift's ShiftMusicPhase), then fades it in over SHIFT_FADE while the cue fades out.
	  The lobby cue (empty When) only plays before the first Shift record (Cues.Matches).
	- Ambience: SoundRules.Ambient.Day/Night on screen while a shift runs (not in the lobby, during a pushed cue or in
	  SoundRules.AmbientOff phases); inside a LightZone of SoundRules.AmbientZones (LZ-4 = Mart interior, character
	  position, AMBIENT_RATE Hz) that zone's bed replaces the street. Each bed is a crossfaded loop of two copies
	  (Bed.luau, Sound.Crossfade); a change of bed crossfades too. Beds are apart from the MaxVoices pool, like music.
	- Tension layer (user request 2026-10-10): SoundRules.Tension.Key (amb_horror) plays as a second crossfaded bed
	  on top of the street while the night window is SoundRules.Tension.Window ("Last", 5-6 AM) and a street/zone bed
	  plays. Provisional: the client does not see NpcService.Tension, so the window stands in for it.
	- Stings (SoundRules.Stings): NightLost on entering the NightLost phase, LastWindow on the window turning
	  Tension.Window. Only on a change this client saw (a late joiner hears nothing). The anomaly stings are played by
	  AnomalyController / VitalController.
	- Ducking: while the Call set (network.md §13.3, record 1) is "Talking", the Music group goes to
	  SoundRules.DuckOnCall.
	- Id "" = silence: Play/Loop return nil, no error and no warn (every Id is "" until Q-168). An unknown key warns
	  once per key.
	- Caps (DEC-005, DEC-173): siren_soft never above SoundRules.SirenMaxVolume; opts.Scare clamps to
	  SoundRules.ScareMaxVolume (Provisional: the table has no scare flag yet, the caller marks it).
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Players = game:GetService("Players")
local Zones = require(ReplicatedStorage.shared.Light.Zones)
local Bed = require(script.Bed)
local Cues = require(script.Cues)
local LoadQueue = require(script.LoadQueue)

const RULES = Content.SoundRules
const GROUPS = { "Music", "Ambient", "Sfx", "Voice", "Ui" }
const MASTER = "Master"
const SCREEN = "AudioScreen" -- folder for 2D sounds
const CALL_RECORD = 1 -- network.md §13.3
const TALKING = "Talking"
const SIREN_KEY = "siren_soft" -- DEC-005
const VARY = 0.05 -- sound-list §2: +-5% pitch when there is a single variation
const ROLLOFF_MIN = 8 -- studs at full volume around a spatial sound
const IDLE_PER_KEY = 3 -- pooled Sounds kept per key
const STALE_AFTER = 1 -- s: a one-shot not playing after this is released (failed load never fires Ended)
const DUCK_TIME = 0.5 -- s
const SCREEN_ANCHOR = "screen"
const SHIFT_FADE = 1.5 -- s: fade of a shift track cut by a cue or by the next shift
const AMBIENT_RATE = 4 -- Hz: zone check of the local character (Mart bed)
const CUTSCENE_ATTRIBUTE = "CutsceneActive" -- CutsceneController (true while a chain plays, nil otherwise)

export type PendingShift = { Id: string, IsNight: boolean }

export type AmbientBed = {
	Key: string,
	Stop: (fade: number?) -> (),
}

export type GroupName = "Music" | "Ambient" | "Sfx" | "Voice" | "Ui"
export type At = Vector3 | Instance

export type PlayOptions = {
	Volume: number?, -- multiplier over the row Volume
	Speed: number?, -- PlaybackSpeed multiplier
	Vary: number?, -- random pitch range (+-), default 0.05 for Sfx/Voice one-shots, 0 otherwise
	Scare: boolean?, -- clamp to SoundRules.ScareMaxVolume (DEC-173)
}

export type Voice = {
	Key: string,
	Sound: Sound,
	Holder: Attachment?,
	Looped: boolean,
	Anchor: any,
	Started: number,
	Destroyed: boolean, -- the anchor took the Sound with it: not reusable
	Connections: { RBXScriptConnection },
}

const AudioController = Modux.Controller("AudioController", { Require = { "RoundController" }, Priority = 640 })

function AudioController:Setup()
	self.Master = nil :: SoundGroup?
	self.Groups = {} :: { [string]: SoundGroup }
	self.Screen = nil :: Folder?
	-- user volume per group (0..1); Master included
	self.Volumes = {} :: { [string]: number }
	-- one-shots and loops playing, oldest first
	self.Voices = {} :: { Voice }
	self.Idle = {} :: { [string]: { Sound } }
	-- Loops[key][anchor] (anchor = Instance, tostring(Vector3) or "screen")
	self.Loops = {} :: { [string]: { [any]: Voice } }
	self.Warned = {} :: { [string]: boolean }
	self.Rng = Random.new() :: Random
	-- music
	self.MusicStack = Vide.source({} :: { string }) :: Vide.Source<{ string }>
	-- key of Content.Music playing now ("" = none); QA and debug read it
	self.MusicCue = Vide.source("") :: Vide.Source<string>
	self.Track = nil :: Sound?
	self.TrackKey = nil :: string?
	self.Ducked = Vide.source(false) :: Vide.Source<boolean>
	-- shift track (once per shift): the Sound, its key ("" = none; QA and debug read it), the last shift that got
	-- its chance and the last key per kind ("Day" / "Night") so the pool does not repeat
	self.ShiftTrack = nil :: Sound?
	self.ShiftMusic = Vide.source("") :: Vide.Source<string>
	self.ShiftId = nil :: string?
	self.LastShiftTrack = {} :: { [string]: string }
	-- shift whose track waits for the cue / cutscene to end (nil = none)
	self.PendingShift = nil :: PendingShift?
	-- a cutscene chain plays (LocalPlayer attribute CutsceneActive)
	self.CutsceneOn = Vide.source(false) :: Vide.Source<boolean>
	-- ambience key and bed playing now (nil = none)
	self.AmbientKey = nil :: string?
	self.Bed = nil :: AmbientBed?
	-- Ambient key of the SoundRules.AmbientZones zone the character is in ("" = outside)
	self.ZoneAmbient = Vide.source("") :: Vide.Source<string>
	-- ZoneId -> LightZone part (rescanned when it leaves the Workspace)
	self.ZoneParts = {} :: { [string]: BasePart }
	self.Unmount = nil :: (() -> ())?
	-- tension layer bed (nil = off)
	self.TensionBed = nil :: AmbientBed?
	-- last phase / night window seen (nil = nothing seen yet: no sting on the first read)
	self.SeenPhase = nil :: string?
	self.SeenWindow = nil :: string?
end

function AudioController:WarnOnce(tag: string, message: string)
	if self.Warned[tag] then
		return
	end
	self.Warned[tag] = true
	warn(`[AudioController] {message}`)
end

-- SoundService > Master > Music/Ambient/Sfx/Voice/Ui (reused if already there)
function AudioController:BuildGroups()
	local master = SoundService:FindFirstChild(MASTER)
	if not (master and master:IsA("SoundGroup")) then
		const created = Instance.new("SoundGroup")
		created.Name = MASTER
		created.Parent = SoundService
		master = created
	end
	const masterGroup = master :: SoundGroup
	self.Master = masterGroup
	self.Volumes[MASTER] = 1
	masterGroup.Volume = 1
	for _, name in GROUPS do
		local group = masterGroup:FindFirstChild(name)
		if not (group and group:IsA("SoundGroup")) then
			const created = Instance.new("SoundGroup")
			created.Name = name
			created.Parent = masterGroup
			group = created
		end
		const soundGroup = group :: SoundGroup
		soundGroup.Volume = 1
		self.Groups[name] = soundGroup
		self.Volumes[name] = 1
	end
	local screen = SoundService:FindFirstChild(SCREEN)
	if not (screen and screen:IsA("Folder")) then
		const created = Instance.new("Folder")
		created.Name = SCREEN
		created.Parent = SoundService
		screen = created
	end
	self.Screen = screen :: Folder
end

-- Group volume = user volume x ducking (Music only)
function AudioController:ApplyGroup(name: string, time: number?)
	const target = if name == MASTER then self.Master else self.Groups[name]
	if target == nil then
		return
	end
	local volume = self.Volumes[name] or 1
	if name == "Music" and self.Ducked() then
		volume *= RULES.DuckOnCall
	end
	if time and time > 0 then
		TweenService:Create(target, TweenInfo.new(time), { Volume = volume }):Play()
	else
		target.Volume = volume
	end
end

-- Settings hook (Provisional: no screen yet, not persisted)
function AudioController:SetVolume(group: GroupName | "Master", volume: number)
	self.Volumes[group] = math.clamp(volume, 0, 1)
	self:ApplyGroup(group)
end

-- Row of Content.Sounds that has an id; nil = silence (Id "") or unknown key (warned once)
function AudioController:Row(key: string): Content.Sound?
	const row = Content.Sounds.ByKey[key]
	if row == nil then
		self:WarnOnce(`unknown:{key}`, `unknown sound key "{key}" (Content.Sounds)`)
		return nil
	end
	if row.Id == "" then
		return nil
	end
	return row
end

function AudioController:Volume(row: Content.Sound, opts: PlayOptions?): number
	local volume = row.Volume * (if opts and opts.Volume then opts.Volume else 1)
	if row.Key == SIREN_KEY then
		volume = math.min(volume, RULES.SirenMaxVolume)
	end
	if opts and opts.Scare then
		volume = math.min(volume, RULES.ScareMaxVolume)
	end
	return math.clamp(volume, 0, 1)
end

-- Where the sound lives: the instance to parent it to and, for a Vector3, the temporary holder
function AudioController:Place(row: Content.Sound, at: At?): (Instance?, Attachment?)
	if not row.Spatial or at == nil then
		return self.Screen, nil
	end
	if typeof(at) == "Vector3" then
		const holder = Instance.new("Attachment")
		holder.Name = `Audio_{row.Key}`
		holder.WorldPosition = at
		holder.Parent = workspace.Terrain
		return holder, holder
	end
	const instance = at :: Instance
	if instance:IsA("BasePart") or instance:IsA("Attachment") then
		return instance, nil
	end
	if instance:IsA("Model") then
		const part = instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
		if part then
			return part, nil
		end
	end
	-- nothing positional to hang it on: play on screen
	return self.Screen, nil
end

function AudioController:Take(row: Content.Sound): Sound
	const idle = self.Idle[row.Key]
	if idle and #idle > 0 then
		return table.remove(idle) :: Sound
	end
	const sound = Instance.new("Sound")
	sound.Name = row.Key
	sound.SoundId = row.Id
	return sound
end

function AudioController:Configure(sound: Sound, row: Content.Sound, opts: PlayOptions?, looped: boolean)
	const default = if not looped and (row.Group == "Sfx" or row.Group == "Voice") then VARY else 0
	const vary = if opts and opts.Vary ~= nil then opts.Vary else default
	const speed = (if opts and opts.Speed then opts.Speed else 1) * (1 + self.Rng:NextNumber(-vary, vary))
	sound.SoundGroup = self.Groups[row.Group]
	sound.Looped = looped
	sound.Volume = self:Volume(row, opts)
	sound.PlaybackSpeed = math.max(speed, 0.01)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = math.min(ROLLOFF_MIN, math.max(row.MaxDistance, 1))
	sound.RollOffMaxDistance = math.max(row.MaxDistance, ROLLOFF_MIN)
	sound.TimePosition = 0
end

function AudioController:Release(voice: Voice)
	const index = table.find(self.Voices, voice)
	if index == nil then
		return
	end
	table.remove(self.Voices, index)
	for _, connection in voice.Connections do
		connection:Disconnect()
	end
	table.clear(voice.Connections)
	if voice.Looped then
		const byAnchor = self.Loops[voice.Key]
		if byAnchor and byAnchor[voice.Anchor] == voice then
			byAnchor[voice.Anchor] = nil
		end
	end

	const sound = voice.Sound
	-- a sound whose anchor was destroyed is locked (Parent cannot be set): drop it
	local alive = not voice.Destroyed
	if alive then
		alive = pcall(function()
			sound:Stop()
			sound.Parent = nil
		end)
	end
	const holder = voice.Holder
	if holder then
		holder:Destroy()
	end

	local idle = self.Idle[voice.Key]
	if idle == nil then
		idle = {}
		self.Idle[voice.Key] = idle
	end
	if alive and #idle < IDLE_PER_KEY then
		table.insert(idle, sound)
	else
		sound:Destroy()
	end
end

-- Drops one-shots that are not playing anymore (failed load, anchor gone) so they stop counting against the cap
function AudioController:Purge()
	const now = os.clock()
	for index = #self.Voices, 1, -1 do
		const voice = self.Voices[index]
		const gone = voice.Sound.Parent == nil
		const stale = not voice.Looped and not voice.Sound.IsPlaying and now - voice.Started > STALE_AFTER
		if gone or stale then
			self:Release(voice)
		end
	end
end

-- true when there is room for one more voice (steals the oldest one-shot if needed)
function AudioController:MakeRoom(key: string): boolean
	if #self.Voices < RULES.MaxVoices then
		return true
	end
	self:Purge()
	if #self.Voices < RULES.MaxVoices then
		return true
	end
	for _, voice in self.Voices do
		if not voice.Looped then
			self:Release(voice)
			return true
		end
	end
	self:WarnOnce(`cap:{key}`, `"{key}" dropped: {RULES.MaxVoices} loops already playing (SoundRules.MaxVoices)`)
	return false
end

function AudioController:Start(row: Content.Sound, at: At?, opts: PlayOptions?, looped: boolean, anchor: any): Sound?
	if not self:MakeRoom(row.Key) then
		return nil
	end
	const parent, holder = self:Place(row, at)
	if parent == nil then
		return nil
	end
	const sound = self:Take(row)
	self:Configure(sound, row, opts, looped)
	sound.Parent = parent

	const voice: Voice = {
		Key = row.Key,
		Sound = sound,
		Holder = holder,
		Looped = looped,
		Anchor = anchor,
		Started = os.clock(),
		Destroyed = false,
		Connections = {},
	}
	table.insert(self.Voices, voice)
	if not looped then
		table.insert(
			voice.Connections,
			sound.Ended:Connect(function()
				self:Release(voice)
			end)
		)
	end
	-- anchor destroyed with the sound inside (customer left, vehicle swapped)
	table.insert(
		voice.Connections,
		sound.Destroying:Connect(function()
			voice.Destroyed = true
			task.defer(function()
				self:Release(voice)
			end)
		end)
	)
	sound:Play()
	return sound
end

-- One-shot. nil = silence (Id ""), unknown key or cap full of loops.
function AudioController:Play(key: string, at: At?, opts: PlayOptions?): Sound?
	const row = self:Row(key)
	if row == nil then
		return nil
	end
	return self:Start(row, at, opts, false, nil)
end

local function anchorOf(at: At?): any
	if at == nil then
		return SCREEN_ANCHOR
	end
	if typeof(at) == "Vector3" then
		return tostring(at)
	end
	return at
end

-- Looped voice per (key, at); on = false stops it. Returns the playing Sound (nil when off or silent).
function AudioController:Loop(key: string, at: At?, on: boolean, opts: PlayOptions?): Sound?
	const anchor = anchorOf(at)
	const byAnchor = self.Loops[key]
	const current = if byAnchor then byAnchor[anchor] else nil
	if not on then
		if current then
			self:Release(current)
		end
		return nil
	end
	if current and current.Sound.Parent ~= nil then
		return current.Sound
	end
	if current then
		self:Release(current)
	end
	const row = self:Row(key)
	if row == nil then
		return nil
	end
	const sound = self:Start(row, at, opts, true, anchor)
	if sound == nil then
		return nil
	end
	local loops = self.Loops[key]
	if loops == nil then
		loops = {}
		self.Loops[key] = loops
	end
	loops[anchor] = self.Voices[#self.Voices]
	return sound
end

-- Stops every loop of a key (e.g. all grills off at the end of the shift)
function AudioController:StopAll(key: string)
	const byAnchor = self.Loops[key]
	if byAnchor == nil then
		return
	end
	const list: { Voice } = {}
	for _, voice in byAnchor do
		table.insert(list, voice)
	end
	for _, voice in list do
		self:Release(voice)
	end
end

-- Override cue (cutscene, finale): the last pushed wins until popped
function AudioController:PushMusic(cue: string)
	if Content.Music.ByKey[cue] == nil then
		self:WarnOnce(`cue:{cue}`, `unknown music cue "{cue}" (Content.Music)`)
		return
	end
	const stack = table.clone(self.MusicStack())
	const index = table.find(stack, cue)
	if index then
		table.remove(stack, index)
	end
	table.insert(stack, cue)
	self.MusicStack(stack)
end

function AudioController:PopMusic(cue: string)
	const stack = self.MusicStack()
	const index = table.find(stack, cue)
	if index == nil then
		return
	end
	const copy = table.clone(stack)
	table.remove(copy, index)
	self.MusicStack(copy)
end

function AudioController:FadeOut(sound: Sound, time: number)
	if time <= 0 then
		sound:Destroy()
		return
	end
	const tween = TweenService:Create(sound, TweenInfo.new(time), { Volume = 0 })
	tween.Completed:Connect(function()
		sound:Destroy()
	end)
	tween:Play()
end

-- Crossfades to the cue's track; same track across two cues keeps playing. nil cue = silence.
function AudioController:SetMusic(cueKey: string?)
	const previous: string = self.MusicCue()
	if previous == (cueKey or "") then
		return
	end
	const cue = if cueKey then Content.Music.ByKey[cueKey] else nil
	const soundKey = if cue then cue.Sound else nil
	const old = Content.Music.ByKey[previous]
	self.MusicCue(cueKey or "")
	if soundKey == self.TrackKey then
		return
	end

	const track = self.Track
	if track then
		self.Track = nil
		self:FadeOut(track, if old then old.FadeOut else 0)
	end
	self.TrackKey = soundKey

	if cue == nil or soundKey == nil then
		return
	end
	const row = self:Row(soundKey)
	if row == nil then
		return
	end
	const sound = Instance.new("Sound")
	sound.Name = `Music_{cue.Key}`
	sound.SoundId = row.Id
	sound.SoundGroup = self.Groups.Music
	sound.Looped = row.Looped
	sound.Volume = if cue.FadeIn > 0 then 0 else row.Volume
	sound.Parent = self.Screen
	sound:Play()
	if cue.FadeIn > 0 then
		TweenService:Create(sound, TweenInfo.new(cue.FadeIn), { Volume = row.Volume }):Play()
	end
	self.Track = sound
end

function AudioController:StopShiftTrack(time: number)
	const track = self.ShiftTrack
	if track == nil then
		return
	end
	self.ShiftTrack = nil
	self.ShiftMusic("")
	self:FadeOut(track, time)
end

-- One track of the shift pool, once (sound-list §3); nil key or Id "" = silence. fadeIn > 0 = rises from 0 (the
-- crossfade with a cue that is fading out)
function AudioController:PlayShiftTrack(isNight: boolean, fadeIn: number?)
	const kind = if isNight then "Night" else "Day"
	const pool = if isNight then RULES.ShiftMusic.Night else RULES.ShiftMusic.Day
	const key = Cues.PickTrack(pool, self.LastShiftTrack[kind], self.Rng)
	if key == nil then
		return
	end
	self.LastShiftTrack[kind] = key
	self:StopShiftTrack(SHIFT_FADE)
	const row = self:Row(key)
	if row == nil then
		return
	end
	const sound = Instance.new("Sound")
	sound.Name = `Shift_{key}`
	sound.SoundId = row.Id
	sound.SoundGroup = self.Groups.Music
	sound.Looped = false
	const rise = fadeIn or 0
	sound.Volume = if rise > 0 then 0 else row.Volume
	sound.Parent = self.Screen
	if rise > 0 then
		TweenService:Create(sound, TweenInfo.new(rise), { Volume = row.Volume }):Play()
	end
	sound.Ended:Once(function()
		if self.ShiftTrack == sound then
			self.ShiftTrack = nil
			self.ShiftMusic("")
		end
		sound:Destroy()
	end)
	self.ShiftTrack = sound
	self.ShiftMusic(key)
	sound:Play()
end

-- Another music owns the screen: a pushed cue or a cutscene chain
function AudioController:MusicBusy(): boolean
	return #Vide.untrack(self.MusicStack) > 0 or Vide.untrack(self.CutsceneOn)
end

-- Shift start: plays the shift track once per shift, only for a client that saw the phase begin; while another
-- music owns the screen (intro cutscene) the track waits (PendingShift, FlushShift)
function AudioController:OnShiftState(ready: boolean, phase: string, id: string, isNight: boolean)
	const pending = self.PendingShift
	if pending ~= nil and (not ready or phase ~= RULES.ShiftMusicPhase or id ~= pending.Id) then
		-- the shift moved on before the cutscene ended: that track is not played late
		self.PendingShift = nil
	end
	if not ready then
		-- lobby: the next run starts clean
		self.ShiftId = nil
		return
	end
	if phase ~= RULES.ShiftMusicPhase or id == self.ShiftId then
		return
	end
	self.ShiftId = id
	const clock = self.Dependencies.RoundController.Clock
	const fresh = clock ~= nil and Workspace:GetServerTimeNow() - clock.PhaseStartedAt <= RULES.ShiftMusicFresh
	if not fresh then
		return
	end
	if self:MusicBusy() then
		self.PendingShift = { Id = id, IsNight = isNight }
	else
		self:PlayShiftTrack(isNight)
	end
end

-- The cue / cutscene is over: a pending shift track starts, crossfading with the cue that fades out
function AudioController:FlushShift()
	const pending = self.PendingShift
	if pending == nil or self:MusicBusy() then
		return
	end
	self.PendingShift = nil
	self:PlayShiftTrack(pending.IsNight, SHIFT_FADE)
end

-- Crossfades to the bed of `key` (nil = silence): the old bed fades out over the new bed's Crossfade
function AudioController:SetAmbient(key: string?)
	if self.AmbientKey == key then
		return
	end
	self.AmbientKey = key
	const row = if key ~= nil then self:Row(key) else nil
	const old = self.Bed
	self.Bed = nil
	if old then
		old.Stop(if row then row.Crossfade else nil)
	end
	if row == nil then
		return
	end
	const screen = self.Screen
	if screen == nil then
		return
	end
	self.Bed = Bed.start(row, screen, self.Groups.Ambient)
end

-- Tension layer on/off (crossfaded bed over the street, SoundRules.Tension)
function AudioController:SetTension(on: boolean)
	if (self.TensionBed ~= nil) == on then
		return
	end
	if not on then
		const bed = self.TensionBed
		self.TensionBed = nil
		if bed then
			bed.Stop()
		end
		return
	end
	const row = self:Row(RULES.Tension.Key)
	const screen = self.Screen
	if row == nil or screen == nil then
		return
	end
	self.TensionBed = Bed.start(row, screen, self.Groups.Ambient)
end

-- Phase / window stings, only on a change seen by this client
function AudioController:OnStingState(phase: string, window: string?)
	const previousPhase = self.SeenPhase
	const previousWindow = self.SeenWindow
	self.SeenPhase = phase
	self.SeenWindow = window
	if previousPhase ~= nil and phase ~= previousPhase and phase == "NightLost" then
		self:Play(RULES.Stings.NightLost, nil, { Scare = true })
	end
	if
		previousWindow ~= nil
		and window ~= previousWindow
		and window == RULES.Tension.Window
	then
		self:Play(RULES.Stings.LastWindow, nil, { Scare = true })
	end
end

function AudioController:ZonePart(id: string): BasePart?
	const cached = self.ZoneParts[id]
	if cached and cached:IsDescendantOf(Workspace) then
		return cached
	end
	self.ZoneParts[id] = nil
	for _, instance in CollectionService:GetTagged(Zones.Tag) do
		if instance:IsA("BasePart") and instance:GetAttribute("ZoneId") == id and instance:IsDescendantOf(Workspace) then
			self.ZoneParts[id] = instance
			return instance
		end
	end
	return nil
end

-- Ambient key of the zone the local character stands in (SoundRules.AmbientZones), nil = outside
function AudioController:ZoneAt(): string?
	const character = Players.LocalPlayer.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	for id, key in RULES.AmbientZones do
		const part = self:ZonePart(id)
		const zone = if part then Zones.read(part) else nil
		if zone and Zones.contains(zone, root.Position) then
			return key
		end
	end
	return nil
end

function AudioController:Preload()
	const ids: { string } = {}
	for _, row in Content.Sounds.List do
		if row.Id ~= "" then
			table.insert(ids, row.Id)
		end
	end
	if #ids == 0 then
		return
	end
	-- background job of the one audio queue (LoadQueue): never a burst next to the loading screen and the voices
	const ok, err = pcall(function()
		LoadQueue.Preload(ids)
	end)
	if not ok then
		warn(`[AudioController] preload failed: {err}`)
	end
end

function AudioController:SetDucked(record: { State: string }?)
	const ducked = record ~= nil and record.State == TALKING
	if self.Ducked() ~= ducked then
		self.Ducked(ducked)
	end
end

AudioController:OnInit(function(self)
	self:Setup()
	self:BuildGroups()

	-- network.md §13.3: AudioController reads Call for the ducking only
	const call = self.Libs.Net.Call
	call:onAdded(function(id, record)
		if id == CALL_RECORD then
			self:SetDucked(record)
		end
	end)
	call:onChanged(function(id, record)
		if id == CALL_RECORD then
			self:SetDucked(record)
		end
	end)
	call:onRemoved(function(id)
		if id == CALL_RECORD then
			self:SetDucked(nil)
		end
	end)
end)

AudioController:OnStart(function(self)
	const round = self.Dependencies.RoundController
	const player = Players.LocalPlayer
	local function readCutscene()
		const on = player:GetAttribute(CUTSCENE_ATTRIBUTE) == true
		if Vide.untrack(self.CutsceneOn) ~= on then
			self.CutsceneOn(on)
		end
	end
	player:GetAttributeChangedSignal(CUTSCENE_ATTRIBUTE):Connect(readCutscene)
	readCutscene()
	self.Unmount = Vide.root(function()
		Vide.effect(function()
			const state: Cues.State = {
				Ready = round.Ready(),
				IsNight = round.IsNight(),
				Phase = round.Phase(),
				Window = (round.NightWindow :: () -> ("Calm" | "Last" | "Shift")?)(),
			}
			const stack = self.MusicStack()
			const cue = if #stack > 0 then stack[#stack] else Cues.Pick(Content.Music.List, state)
			const zone: string = self.ZoneAmbient()
			const ambient = Cues.Ambient(state, RULES.Ambient, RULES.AmbientOff, #stack > 0, if zone ~= "" then zone else nil)
			Vide.untrack(function()
				if cue ~= nil then
					self:StopShiftTrack(SHIFT_FADE)
				end
				self:SetMusic(cue)
				self:SetAmbient(ambient)
				self:SetTension(ambient ~= nil and state.IsNight and state.Window == RULES.Tension.Window)
				return nil
			end)
		end)
		Vide.effect(function()
			const ready = round.Ready()
			const phase = round.Phase()
			const window = (round.NightWindow :: () -> ("Calm" | "Last" | "Shift")?)()
			Vide.untrack(function()
				self:OnStingState(if ready then phase else "", window)
				return nil
			end)
		end)
		Vide.effect(function()
			const ready = round.Ready()
			const phase = round.Phase()
			const isNight = round.IsNight()
			const id = Cues.ShiftId(round.Day(), round.Night(), round.Attempt(), isNight)
			Vide.untrack(function()
				self:OnShiftState(ready, phase, id, isNight)
				return nil
			end)
		end)
		-- one music at a time: no shift track under a cue or a cutscene; a pending one starts when both are off
		Vide.effect(function()
			const busy = #self.MusicStack() > 0 or self.CutsceneOn()
			Vide.untrack(function()
				if busy then
					self:StopShiftTrack(SHIFT_FADE)
				else
					self:FlushShift()
				end
				return nil
			end)
		end)
		Vide.effect(function()
			const _ducked: boolean = self.Ducked()
			Vide.untrack(function()
				self:ApplyGroup("Music", DUCK_TIME)
				return nil
			end)
		end)
	end)

	task.spawn(function()
		self:Preload()
	end)
end)

AudioController:OnTick(function(self)
	const key = self:ZoneAt() or ""
	if self.ZoneAmbient() ~= key then
		self.ZoneAmbient(key)
	end
end, AMBIENT_RATE)

return AudioController
