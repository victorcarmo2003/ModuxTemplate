--!strict
-- Data-driven content (docs/tech/content-data.md). ReplicatedStorage.shared.Content, read by server and client.
-- Pure data: no Modux, Lync, Vide or self.Libs, so Net can require it to build enums (network.md §1 rule 3).
-- Owner of this file: TASK-003 (wave 1), TASK-047 (wave 2), TASK-096 (wave 3). Content tasks edit only their own
-- table file.
local Achievements = require(script.Achievements)
local Actions = require(script.Actions)
local Animations = require(script.Animations)
local Anomalies = require(script.Anomalies)
local BossCalls = require(script.BossCalls)
local Classes = require(script.Classes)
local CustomerTypes = require(script.CustomerTypes)
local Cutscenes = require(script.Cutscenes)
local Flow = require(script.Flow)
local GemRewards = require(script.GemRewards)
local Hallucinations = require(script.Hallucinations)
local HudReveal = require(script.HudReveal)
local Ingredients = require(script.Ingredients)
local Items = require(script.Items)
local LightGroups = require(script.LightGroups)
local LightPresets = require(script.LightPresets)
local Lobby = require(script.Lobby)
local Mart = require(script.Mart)
local Moods = require(script.Moods)
local Neon = require(script.Neon)
local Nights = require(script.Nights)
local Notices = require(script.Notices)
local OpalLines = require(script.OpalLines)
local Orders = require(script.Orders)
local Outfits = require(script.Outfits)
local Packages = require(script.Packages)
local Revive = require(script.Revive)
local RunParams = require(script.RunParams)
local Sanity = require(script.Sanity)
local Seating = require(script.Seating)
local Shift = require(script.Shift)
local Shop = require(script.Shop)
local Sounds = require(script.Sounds)
local Species = require(script.Species)
local Stations = require(script.Stations)
local Stats = require(script.Stats)
local Table = require(script.Table)
local Thief = require(script.Thief)
local Traffic = require(script.Traffic)
local Upgrades = require(script.Upgrades)
local Validate = require(script.Validate)
local Trailer = require(script.Trailer)
local Vehicles = require(script.Vehicles)
local WalkPaths = require(script.WalkPaths)

export type Table<T> = Table.Table<T>
export type Achievement = Achievements.Achievement
export type Action = Actions.Action
export type Animation = Animations.Animation
export type Anomaly = Anomalies.Anomaly
export type AnomalyCue = Anomalies.Cue
export type BossCall = BossCalls.BossCall
export type BossCallLine = BossCalls.Line
export type BossCallRules = BossCalls.Rules
export type Class = Classes.Class
export type ClassEffect = Classes.Effect
export type CustomerType = CustomerTypes.CustomerType
export type Cutscene = Cutscenes.Cutscene
export type CutsceneBeat = Cutscenes.Beat
export type CutsceneCar = Cutscenes.Car
export type CutsceneRules = Cutscenes.Rules
export type CutsceneVoice = Cutscenes.Voice
export type GemRewards = GemRewards.GemRewards
export type Hallucination = Hallucinations.Hallucination
export type HudRevealElement = HudReveal.Element
export type HudRevealTrigger = HudReveal.Trigger
export type HallucinationRules = Hallucinations.Rules
export type Ingredient = Ingredients.Ingredient
export type Item = Items.Item
export type ItemRules = Items.ItemRules
export type LightGroup = LightGroups.LightGroup
export type LightPreset = LightPresets.LightPreset
export type LightPresets = LightPresets.LightPresets
export type Lobby = Lobby.Lobby
export type LobbyZone = Lobby.Zone
export type LobbyPanel = Lobby.Panel
export type Locomotion = Animations.Locomotion
export type Mart = Mart.Mart
export type MartDoor = Mart.Door
export type MartPedestal = Mart.Pedestal
export type Looks = Outfits.Looks
export type MusicCue = Sounds.Cue
export type Mood = Moods.Mood
export type Neon = Neon.Neon
export type MoodRules = Moods.MoodRules
export type Night = Nights.Night
export type Notice = Notices.Notice
export type OpalPool = OpalLines.OpalPool
export type OrderPhase = Orders.OrderPhase
export type OrderRules = Orders.OrderRules
export type Outfit = Outfits.Outfit
export type Package = Packages.Package
export type Phase = Shift.Phase
export type Revive = Revive.Revive
export type RunParams = RunParams.RunParams
export type Sanity = Sanity.Sanity
export type Seating = Seating.Seating
export type SeatingGroup = Seating.Group
export type Shop = Shop.Shop
export type ShopGemPack = Shop.GemPack
export type ShopClassProduct = Shop.ClassProduct
export type GroupPair = Flow.GroupPair
export type Groups = Flow.Groups
export type Adopt = Flow.Adopt
export type Sound = Sounds.Sound
export type SoundRules = Sounds.SoundRules
export type Species = Species.Species
export type Stat = Stats.Stat
export type Station = Stations.Station
export type Thief = Thief.Thief
export type Traffic = Traffic.Traffic
export type TrafficDensity = Traffic.Density
export type TrafficRoute = Traffic.Route
export type Upgrade = Upgrades.Upgrade
export type UpgradeLevel = Upgrades.Level
export type Trailer = Trailer.Trailer
export type Vehicle = Vehicles.Vehicle
export type WalkPath = WalkPaths.WalkPath
export type WalkPathRules = WalkPaths.Rules

Validate()

return table.freeze({
	-- wave 1, complete
	Actions = Actions,
	Ingredients = Ingredients,
	Items = Items,
	ItemRules = Items.Rules,
	Looks = Outfits.Looks,
	MoodRules = Moods.Rules,
	Moods = Moods,
	Notices = Notices,
	Outfits = Outfits,
	Packages = Packages,
	Stations = Stations,
	Stats = Stats,

	-- wave 1, typed stubs (values in TASK-008 / TASK-009)
	Classes = Classes,
	CustomerTypes = CustomerTypes,
	Flow = Flow,
	OpalLines = OpalLines,
	OrderPhases = Orders,
	OrderRules = Orders.Rules,
	RunParams = RunParams,
	Shift = Shift,
	Species = Species,
	Upgrades = Upgrades,
	Trailer = Trailer,
	Vehicles = Vehicles,

	-- wave 2 (TASK-047; content-data.md §6). Numbers and texts Provisional (TASK-081, TASK-082); ids empty (Q-167, Q-168)
	Achievements = Achievements,
	Animations = Animations,
	BossCallRules = BossCalls.Rules,
	BossCalls = BossCalls,
	GemRewards = GemRewards,
	LightGroups = LightGroups,
	Music = Sounds.Music,
	Nights = Nights,
	Revive = Revive,
	Sanity = Sanity,
	SoundRules = Sounds.Rules,
	Sounds = Sounds,
	Thief = Thief,

	-- wave 3 (TASK-096; content-data.md §6.10, §6.11, §3.14). Numbers and texts Provisional; WalkPaths rows in TASK-098
	Anomalies = Anomalies,
	AnomalyCues = Anomalies.Cues,
	Cutscenes = Cutscenes,
	HallucinationRules = Hallucinations.Rules,
	Hallucinations = Hallucinations,
	Traffic = Traffic,
	WalkPathRules = WalkPaths.Rules,
	WalkPaths = WalkPaths,

	-- neon tube signs (user request 2026-10-11; NeonController)
	Neon = Neon,

	-- Mart v2 "Gear Stand" (TASK-135; FEAT-015 v2; MAP-01 §18). Numbers Provisional
	Mart = Mart,

	-- Pad tables and pairs (TASK-144; FEAT-037, FEAT-038; content-data.md §3.25). Numbers Provisional; Flow.Groups
	-- lives in Flow
	Seating = Seating,

	-- Robux shop: gem packs and class products (user request 2026-10-11, TASK-160; data.md §1.7). Ids 0 until the
	-- Creator Hub products exist; prices Provisional (Q-190)
	Shop = Shop,

	-- Lighting presets day / golden / nights / lobby, warm pass (user request 2026-10-11; LightController). Provisional
	LightPresets = LightPresets,

	-- Lobby zones (auto-open triggers), ring VFX, platform squads, lobby camera (user request 2026-10-11; LobbyController,
	-- PartyService). Provisional
	Lobby = Lobby,

	-- Progressive HUD reveal: which element appears when (owner request 2026-10-12; HudController). Provisional
	HudReveal = HudReveal,
})
