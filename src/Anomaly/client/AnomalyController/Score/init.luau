--!strict
--[[
	Horror score director (TASK-443, TASK-444; owner request 2026-10-17; Content.Score). Started by AnomalyController
	(OnStart, like Breaker.luau): it already sees the Anomalies set and requires AudioController and RoundController, so
	no new controller is needed (a new Modux controller pushed PlateController over the type checker budget).

	The score in steps: Calm -> Uneasy -> Tension -> Climax -> Release -> Calm. Presents only: the stage is read from
	what the server already replicates (the Anomalies set, the shift phase); nothing here decides an anomaly, a failure
	or a penalty.

	  - Stage of the moment: Stage.Pick over the live records of the anomalies listed in Content.Score.Anomalies (by
	    Ref), only in Content.Score.Rules.Phases and while no cue / cutscene owns the music; Stage.Next moves up at once
	    and down after the current stage's Hold (a hot stage falls through Release).
	  - One theme at a time: each stage with a Sound plays one looped Sound in the Music group; a change crossfades
	    (the old theme fades over its stage's FadeOut, the new one rises over its FadeIn). Tension ramps PlaybackSpeed
	    and volume from Speed/Volume to SpeedTo/VolumeTo over the driving anomaly's Ramp (Stage.Progress).
	  - Stings: the stage's Sting on entering it (not on the first read: a late joiner hears the theme, no sting).
	  - Uneasy / Tension / Climax: AudioController:SetScoreHold(true) (street tension layer off, shift track faded);
	    every stage sets the kitchen SFX duck to its DuckKitchen (AudioController:SetKitchenDuck).
	  - Captions (TASK-444): a record of a listed anomaly with a Caption turning Active (seen live, or arriving Active
	    less than Rules.CaptionFresh s old) shows Content.Score.Captions[k] once (HorrorCaption, its own ScreenGui).
	  - Score.Scene(key) (TASK-462, horror scene Music steps): the scene owns the theme. The stage theme fades out and
	    Content.Sounds[key] loops in its place ("Stop" = silence); Score.Scene(nil) gives the theme back to the stage.
	    Stage hold, duck and stings go on as usual meanwhile.
	  - `/dev score <calm|uneasy|tension|climax|release|auto>`: forces a stage until `auto` (DevAudio "score:<stage>",
	    AudioController.ScoreHook).
	Content.Score.Rules.Enabled = false: Start does nothing and AnomalyController keeps its old stings.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Components = StarterPlayer.StarterPlayerScripts.client.Interface.Components
local HorrorCaption = require(Components.HorrorCaption)
local UiScale = require(Components.UiScale)
local Stage = require(script.Stage)

export type StageKey = Stage.StageKey

-- Narrow views of what the director calls (AudioController, RoundController, AnomalyController)
export type Audio = {
	Row: (self: any, key: string) -> Content.Sound?,
	Ensure: (self: any, row: Content.Sound) -> boolean,
	Play: (self: any, key: string, at: any, opts: any) -> Sound?,
	SetScoreHold: (self: any, on: boolean) -> (),
	SetKitchenDuck: (self: any, multiplier: number, time: number?) -> (),
	MusicBusy: (self: any) -> boolean,
	Request: (self: any, ids: { string }) -> (),
	Screen: Folder?,
	Groups: { [string]: SoundGroup },
	ScoreHook: ((command: string) -> ())?,
}

export type Round = {
	Ready: () -> boolean,
	Phase: () -> string,
	IsNight: () -> boolean,
}

-- One live occurrence as AnomalyController lists them
export type Live = {
	Id: number,
	Key: string,
	Ref: string,
	Record: () -> { Phase: string, StartedAt: number },
}

export type Deps = {
	Audio: Audio,
	Round: Round,
	Occurrences: () -> { Live },
}

const SCORE = Content.Score
const RULES = SCORE.Rules
const ANOMALIES = SCORE.Anomalies :: { [string]: Content.ScoreAnomaly }
const TICK = 1 / 15 -- s: stage pick and the Tension ramp
const DEV_RAMP = 15 -- s of the ramp of a forced Tension
const SCENE_FADE = 1 -- s: crossfade between the stage theme and a scene's (Score.Scene)
const SCENE_STOP = "Stop"
const STAGE_KEYS: { [string]: StageKey } = {
	calm = "Calm",
	uneasy = "Uneasy",
	tension = "Tension",
	climax = "Climax",
	release = "Release",
}

-- What the director remembers of one record (id of the Anomalies set)
type Mark = { Key: string, Ref: string, Phase: string, Since: number, StartedAt: number }

-- The theme playing: its Sound, the stage it belongs to and when it started (os.clock, for the fade-in envelope)
type Theme = { Stage: StageKey, Sound: Sound, StartedAt: number, Layer: Sound? } -- Layer: the stage's one-shot (Stage.Layer)

type Director = {
	Deps: Deps,
	Stage: StageKey,
	EnteredAt: number,
	Pick: Stage.Pick,
	Theme: Theme?,
	Marks: { [number]: Mark },
	Forced: StageKey?,
	ForcedSince: number,
	SceneOn: boolean, -- a horror scene owns the theme (Score.Scene)
	SceneSound: Sound?,
	Started: boolean,
	Warned: { [string]: boolean },
	CaptionShown: Vide.Source<boolean>,
	CaptionTitle: Vide.Source<string>,
	CaptionLine: Vide.Source<string>,
	CaptionToken: number,
	Captioned: { [string]: boolean },
}

const Score = {}

-- the live director (nil until Start); QA and debug read the stage through Score.Current()
local current: Director? = nil

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function warnOnce(director: Director, tag: string, message: string)
	if director.Warned[tag] then
		return
	end
	director.Warned[tag] = true
	warn(`[Score] {message}`)
end

-- Caption ------------------------------------------------------------------------------------------------------------

local function showCaption(director: Director, key: string)
	const row = SCORE.Captions.ByKey[key]
	if row == nil then
		warnOnce(director, `caption:{key}`, `unknown caption "{key}" (Content.Score.Captions)`)
		return
	end
	director.CaptionTitle(row.Title)
	director.CaptionLine(row.Line)
	director.CaptionShown(true)
	director.CaptionToken += 1
	const token = director.CaptionToken
	task.delay(row.Duration, function()
		if director.CaptionToken == token then
			director.CaptionShown(false)
		end
	end)
end

local function mount(director: Director, playerGui: Instance)
	const _, gui = Vide.root(function()
		return Vide.create("ScreenGui")({
			Name = "HorrorScore",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = 3, -- over the HUD, under full-screen fades and the jumpscare
			HorrorCaption({
				Shown = director.CaptionShown,
				Title = director.CaptionTitle,
				Line = director.CaptionLine,
				Scale = UiScale.Current,
			}),
		})
	end)
	gui.Parent = playerGui
end

-- Records ------------------------------------------------------------------------------------------------------------

-- A record entered a phase (fresh = this client saw it happen, or it is only a moment old): the caption, once
local function onPhase(director: Director, id: number, mark: Mark, fresh: boolean)
	if not fresh or mark.Phase ~= "Active" then
		return
	end
	const score = ANOMALIES[mark.Ref]
	const captionKey = if score ~= nil then score.Caption else nil
	if captionKey == nil then
		return
	end
	const token = `{id}:{mark.StartedAt}`
	if director.Captioned[token] then
		return
	end
	director.Captioned[token] = true
	showCaption(director, captionKey)
end

-- Reads the live occurrences: new ones, phase changes (Since), captions. Returns the list for Stage.Pick.
local function read(director: Director): { Stage.Seen }
	const t = now()
	const alive: { [number]: boolean } = {}
	const seen: { Stage.Seen } = {}
	for _, occ in director.Deps.Occurrences() do
		const record = Vide.untrack(occ.Record)
		alive[occ.Id] = true
		const known: Mark? = director.Marks[occ.Id]
		local mark: Mark
		if known == nil or known.Key ~= occ.Key or known.StartedAt ~= record.StartedAt then
			const created: Mark = {
				Key = occ.Key,
				Ref = occ.Ref,
				Phase = record.Phase,
				Since = record.StartedAt,
				StartedAt = record.StartedAt,
			}
			director.Marks[occ.Id] = created
			mark = created
			onPhase(director, occ.Id, created, t - record.StartedAt <= RULES.CaptionFresh)
		else
			mark = known
			if known.Phase ~= record.Phase then
				known.Phase = record.Phase
				known.Since = t
				onPhase(director, occ.Id, known, true)
			end
		end
		const entry: Stage.Seen = { Ref = mark.Ref, Phase = mark.Phase, Since = mark.Since }
		table.insert(seen, entry)
	end
	for id in director.Marks do
		if not alive[id] then
			director.Marks[id] = nil
		end
	end
	return seen
end

-- Themes -------------------------------------------------------------------------------------------------------------

local function fadeSound(sound: Sound, time: number)
	if time <= 0 then
		sound:Destroy()
		return
	end
	const tween = TweenService:Create(sound, TweenInfo.new(time), { Volume = 0 })
	tween.Completed:Once(function()
		sound:Destroy()
	end)
	tween:Play()
end

local function fadeOut(theme: Theme, time: number)
	fadeSound(theme.Sound, time)
	-- the layer (the rising note) never fades: it dies with the stage
	const layer = theme.Layer
	if layer ~= nil then
		theme.Layer = nil
		layer:Destroy()
	end
end

-- The stage's one-shot layer (owner 2026-10-18: the blackout's rising violin), started at the point of the file that matches
-- the time since the driving phase began (server clock), so it ends at LayerCut on every client. nil = none / already past.
local function newLayer(director: Director, stage: Content.ScoreStage): Sound?
	const key = stage.Layer
	if key == nil then
		return nil
	end
	const elapsed = math.max(now() - director.Pick.Since, 0)
	const cut = stage.LayerCut
	if cut ~= nil and elapsed >= cut then
		return nil
	end
	const audio = director.Deps.Audio
	const row = audio:Row(key)
	const screen = audio.Screen
	if row == nil or screen == nil or not audio:Ensure(row) then
		return nil
	end
	const sound = Instance.new("Sound")
	sound.Name = `Score_{stage.Key}_Layer`
	sound.SoundId = row.Id
	sound.SoundGroup = audio.Groups.Music
	sound.Looped = false
	sound.Volume = stage.LayerVolume or row.Volume
	sound.TimePosition = elapsed
	sound.Parent = screen
	sound:Play()
	return sound
end

-- The theme Sound of a stage (nil = silent stage, or the row has no audio yet)
local function newTheme(director: Director, stage: Content.ScoreStage): Theme?
	const key = stage.Sound
	if key == nil then
		return nil
	end
	const audio = director.Deps.Audio
	const row = audio:Row(key)
	if row == nil or not audio:Ensure(row) then
		return nil
	end
	const screen = audio.Screen
	if screen == nil then
		return nil
	end
	const sound = Instance.new("Sound")
	sound.Name = `Score_{stage.Key}`
	sound.SoundId = row.Id
	sound.SoundGroup = audio.Groups.Music
	sound.Looped = true
	sound.Volume = 0
	sound.PlaybackSpeed = stage.Speed
	sound.Parent = screen
	sound:Play()
	return { Stage = stage.Key, Sound = sound, StartedAt = os.clock(), Layer = newLayer(director, stage) }
end

-- Enters `key`: crossfade of the themes, sting, hold and duck
local function enter(director: Director, key: StageKey, sting: boolean)
	const from = SCORE.ByKey[director.Stage]
	const to = SCORE.ByKey[key]
	if to == nil then
		return
	end
	director.Stage = key
	director.EnteredAt = os.clock()

	const old = director.Theme
	const sameSound = old ~= nil and from ~= nil and from.Sound == to.Sound
	if director.SceneOn then
		-- a horror scene owns the theme (Score.Scene): the stage only moves hold, duck and sting
	elseif not sameSound then
		if old ~= nil then
			director.Theme = nil
			fadeOut(old, if from ~= nil then from.FadeOut else 1)
		end
		director.Theme = newTheme(director, to)
	elseif old ~= nil then
		old.Stage = key
	end

	const audio = director.Deps.Audio
	if sting and to.Sting ~= nil then
		audio:Play(to.Sting, nil, { Scare = true })
	end
	audio:SetScoreHold(Stage.IsHot(key))
	audio:SetKitchenDuck(to.DuckKitchen, RULES.DuckTime)
end

-- Volume / speed of the theme this frame: the stage's ramp times the fade-in envelope
local function shape(director: Director)
	const theme = director.Theme
	if theme == nil then
		return
	end
	const stage = SCORE.ByKey[theme.Stage]
	if stage == nil then
		return
	end
	local since = director.Pick.Since
	local ramp = director.Pick.Ramp
	if director.Forced ~= nil then
		since = director.ForcedSince
		ramp = DEV_RAMP
	end
	const ramps = stage.VolumeTo ~= stage.Volume or stage.SpeedTo ~= stage.Speed
	const t = if ramps then Stage.Progress(stage, since, ramp, now()) else 0
	const envelope = if stage.FadeIn > 0 then math.clamp((os.clock() - theme.StartedAt) / stage.FadeIn, 0, 1) else 1
	-- past LayerCut (the jumpscare second) the layer is cut dead and the theme stays silent until the stage changes
	const cut = stage.LayerCut
	if cut ~= nil and now() - since >= cut then
		const layer = theme.Layer
		if layer ~= nil then
			theme.Layer = nil
			layer:Destroy()
		end
		theme.Sound.Volume = 0
		return
	end
	theme.Sound.Volume = (stage.Volume + (stage.VolumeTo - stage.Volume) * t) * envelope
	theme.Sound.PlaybackSpeed = stage.Speed + (stage.SpeedTo - stage.Speed) * t
end

-- Step ---------------------------------------------------------------------------------------------------------------

-- The score may leave Calm: a shift phase of Rules.Phases and no cue / cutscene owning the music
local function open(director: Director): boolean
	const round = director.Deps.Round
	if not Vide.untrack(round.Ready) then
		return false
	end
	if table.find(RULES.Phases, Vide.untrack(round.Phase)) == nil then
		return false
	end
	return not director.Deps.Audio:MusicBusy()
end

local function step(director: Director)
	const seen = read(director)
	local pick: Stage.Pick = Stage.Pick(seen)
	if not open(director) then
		const calm: Stage.Pick = { Stage = "Calm", Since = 0, Ramp = 0, Ref = nil }
		pick = calm
	end
	const forced: StageKey? = director.Forced
	if forced ~= nil then
		const forcedPick: Stage.Pick = { Stage = forced, Since = director.ForcedSince, Ramp = DEV_RAMP, Ref = nil }
		pick = forcedPick
	end
	director.Pick = pick
	const stage = director.Stage
	const nextStage = if forced ~= nil then forced else Stage.Next(stage, director.EnteredAt, pick.Stage, os.clock())
	if nextStage ~= stage then
		enter(director, nextStage, director.Started)
	end
	director.Started = true
	shape(director)
end

-- `/dev score <stage|auto>` (DevAudio "score:<stage>", dev mode only)
local function dev(director: Director, command: string)
	const word = string.lower(command)
	if word == "auto" or word == "" then
		director.Forced = nil
		print("[Score] back to auto")
		return
	end
	const key = STAGE_KEYS[word]
	if key == nil then
		warn(`[Score] /dev score {command}: use calm, uneasy, tension, climax, release or auto`)
		return
	end
	director.Forced = key
	director.ForcedSince = now()
	print(`[Score] forced to {key} (/dev score auto to release)`)
end

-- Ids of the theme and sting rows, asked to the audio queue once the night comes (the Studio rows resolve here)
local function warm(director: Director)
	const audio = director.Deps.Audio
	const ids: { string } = {}
	local function add(key: string?)
		const sound = if key ~= nil then audio:Row(key) else nil
		if sound ~= nil then
			table.insert(ids, sound.Id)
		end
	end
	for _, row in SCORE.List do
		add(row.Sound)
		add(row.Sting)
	end
	audio:Request(ids)
end

-- Starts the director (AnomalyController:OnStart). No-op with Content.Score.Rules.Enabled false.
function Score.Start(deps: Deps)
	if not RULES.Enabled or current ~= nil then
		return
	end
	const director: Director = {
		Deps = deps,
		Stage = "Calm",
		EnteredAt = 0,
		Pick = { Stage = "Calm", Since = 0, Ramp = 0, Ref = nil },
		Theme = nil,
		Marks = {},
		Forced = nil,
		ForcedSince = 0,
		SceneOn = false,
		SceneSound = nil,
		Started = false,
		Warned = {},
		CaptionShown = Vide.source(false),
		CaptionTitle = Vide.source(""),
		CaptionLine = Vide.source(""),
		CaptionToken = 0,
		Captioned = {},
	}
	current = director
	deps.Audio.ScoreHook = function(command: string)
		dev(director, command)
	end
	Vide.root(function()
		Vide.effect(function()
			if deps.Round.IsNight() then
				Vide.untrack(function()
					warm(director)
					return nil
				end)
			end
		end)
	end)
	task.spawn(function()
		mount(director, Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < TICK then
			return
		end
		elapsed = 0
		step(director)
	end)
end

-- A scene's own looped theme (fades in to the row volume)
local function sceneSound(director: Director, key: string): Sound?
	const audio = director.Deps.Audio
	const row = audio:Row(key)
	const screen = audio.Screen
	if row == nil or screen == nil or not audio:Ensure(row) then
		return nil
	end
	const sound = Instance.new("Sound")
	sound.Name = `Score_Scene_{key}`
	sound.SoundId = row.Id
	sound.SoundGroup = audio.Groups.Music
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = screen
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(SCENE_FADE), { Volume = row.Volume }):Play()
	return sound
end

-- Horror scene Music step (TASK-462): key = Content.Sounds key the scene loops instead of the stage theme, "Stop" =
-- silence, nil = the stage gets its theme back. false = the director is not running (score off): the caller plays it.
function Score.Scene(key: string?): boolean
	const director = current
	if director == nil then
		return false
	end
	const old = director.SceneSound
	if old ~= nil then
		director.SceneSound = nil
		fadeSound(old, SCENE_FADE)
	end
	if key == nil then
		if director.SceneOn then
			director.SceneOn = false
			const stage = SCORE.ByKey[director.Stage]
			if stage ~= nil and director.Theme == nil then
				director.Theme = newTheme(director, stage)
			end
		end
		return true
	end
	if not director.SceneOn then
		director.SceneOn = true
		const theme = director.Theme
		if theme ~= nil then
			director.Theme = nil
			fadeOut(theme, SCENE_FADE)
		end
	end
	if key ~= SCENE_STOP then
		director.SceneSound = sceneSound(director, key)
	end
	return true
end

-- Stage of the moment ("Calm" before Start or with the score off)
function Score.Current(): StageKey
	const director = current
	return if director ~= nil then director.Stage else "Calm"
end

return table.freeze(Score)
