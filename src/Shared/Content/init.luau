--!strict
-- Data-driven content (docs/tech/content-data.md). ReplicatedStorage.shared.Content, read by server and client.
-- Pure data: no Modux, Lync, Vide or self.Libs, so Net can require it to build enums (network.md §1 rule 3).
-- Owner of this file: TASK-003 (wave 1), TASK-047 (wave 2), TASK-096 (wave 3). Content tasks edit only their own
-- table file.
local Achievements = require(script.Achievements)
local Actions = require(script.Actions)
local Animations = require(script.Animations)
local Anomalies = require(script.Anomalies)
local Atmospheres = require(script.Atmospheres)
local BossCalls = require(script.BossCalls)
local Classes = require(script.Classes)
local CustomerTypes = require(script.CustomerTypes)
local Cutscenes = require(script.Cutscenes)
local Flow = require(script.Flow)
local GemRewards = require(script.GemRewards)
local Hallucinations = require(script.Hallucinations)
local Haptics = require(script.Haptics)
local HudReveal = require(script.HudReveal)
local Ingredients = require(script.Ingredients)
local Journal = require(script.Journal)
local Items = require(script.Items)
local LightGroups = require(script.LightGroups)
local LightPresets = require(script.LightPresets)
local CoffeeCup = require(script.CoffeeCup)
local Trash = require(script.Trash)
local RailSlot = require(script.RailSlot)
local Lobby = require(script.Lobby)
local Mart = require(script.Mart)
local Mode = require(script.Mode)
local Moods = require(script.Moods)
local Movement = require(script.Movement)
local Neon = require(script.Neon)
local Nights = require(script.Nights)
local Notices = require(script.Notices)
local OpalLines = require(script.OpalLines)
local Orders = require(script.Orders)
local Outfits = require(script.Outfits)
local Packages = require(script.Packages)
local Prep = require(script.Prep)
local Restaurant = require(script.Restaurant)
local Revive = require(script.Revive)
local RunParams = require(script.RunParams)
local Sanity = require(script.Sanity)
local Seating = require(script.Seating)
local Security = require(script.Security)
local Shift = require(script.Shift)
local Shop = require(script.Shop)
local Skins = require(script.Skins)
local ShopWindow = require(script.ShopWindow)
local Sounds = require(script.Sounds)
local Species = require(script.Species)
local Stations = require(script.Stations)
local Stats = require(script.Stats)
local Table = require(script.Table)
local Thief = require(script.Thief)
local TipJar = require(script.TipJar)
local Metrics = require(script.Metrics)
local Traffic = require(script.Traffic)
local TrafficLights = require(script.TrafficLights)
local Upgrades = require(script.Upgrades)
local VoiceLines = require(script.VoiceLines)
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
export type Atmosphere = Atmospheres.Atmosphere
export type AtmosphereLight = Atmospheres.LightOverride
export type AtmosphereRain = Atmospheres.Rain
export type AtmosphereLightning = Atmospheres.Lightning
export type BossCall = BossCalls.BossCall
export type BossCallLine = BossCalls.Line
export type BossCallRules = BossCalls.Rules
export type Class = Classes.Class
export type ClassEffect = Classes.Effect
export type CustomerType = CustomerTypes.CustomerType
export type Cutscene = Cutscenes.Cutscene
export type CutsceneBeat = Cutscenes.Beat
export type CutsceneShot = Cutscenes.Shot
export type CutsceneCinema = Cutscenes.Cinema
export type CutsceneExtra = Cutscenes.Extra
export type CutsceneFlock = Cutscenes.Flock
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
export type JournalPage = Journal.Page
export type JournalRules = Journal.Rules
export type ItemRules = Items.ItemRules
export type LightGroup = LightGroups.LightGroup
export type LightPreset = LightPresets.LightPreset
export type LightPresets = LightPresets.LightPresets
export type Lobby = Lobby.Lobby
export type LobbyZone = Lobby.Zone
export type LobbyPanel = Lobby.Panel
export type LobbyPadPulse = Lobby.PadPulse
export type Locomotion = Animations.Locomotion
export type Mart = Mart.Mart
export type MartDoor = Mart.Door
export type MartPedestal = Mart.Pedestal
export type Looks = Outfits.Looks
export type MusicCue = Sounds.Cue
export type Mood = Moods.Mood
export type Mode = Mode.Mode
export type Neon = Neon.Neon
export type MoodRules = Moods.MoodRules
export type Night = Nights.Night
export type Notice = Notices.Notice
export type OpalPool = OpalLines.OpalPool
export type OrderPhase = Orders.OrderPhase
export type OrderRules = Orders.OrderRules
export type Outfit = Outfits.Outfit
export type Package = Packages.Package
export type PrepRules = Prep.Rules
export type PrepGrades = Prep.Grades
export type PrepTolerance = Prep.Tolerance
export type PrepGesture = Prep.Gesture
export type PrepStep = Prep.Step
export type PrepBand = Prep.Band
export type PrepTab = Prep.Tab
export type PrepView = Prep.View
export type PrepViewKey = Prep.ViewKey
export type PrepTarget = Prep.PrepTarget
export type PrepTargetKind = Prep.TargetKind
export type PrepToolKind = Prep.ToolKind
export type PrepSlotPhase = Prep.SlotPhase
export type PrepWorldRules = Prep.WorldRules
export type Phase = Shift.Phase
export type Revive = Revive.Revive
export type Restaurant = Restaurant.Restaurant
export type RestaurantRules = Restaurant.Rules
export type RestaurantTalk = Restaurant.Talk
export type RestaurantDrive = Restaurant.Drive
export type RestaurantSupply = Restaurant.Supply
export type RestaurantDialog = Restaurant.Dialog
export type RestaurantBinding = Restaurant.Binding
export type HapticProfile = Haptics.Profile
export type HapticKey = Haptics.Key
export type RunParams = RunParams.RunParams
export type Sanity = Sanity.Sanity
export type Seating = Seating.Seating
export type Security = Security.Security
export type SecurityCam = Security.Cam
export type SecurityLook = Security.Look
export type SecurityView = Security.View
export type SeatingGroup = Seating.Group
export type Shop = Shop.Shop
export type ShopGemPack = Shop.GemPack
export type ShopClassProduct = Shop.ClassProduct
export type ShopGift = Shop.Gift
export type ShopGiftKind = Shop.GiftKind
export type ShopOffer = Shop.Offer
export type ShopOfferRules = Shop.OfferRules
export type ShopBundle = Shop.Bundle
export type ShopPass = Shop.Pass
export type GroupPair = Flow.GroupPair
export type Groups = Flow.Groups
export type Adopt = Flow.Adopt
export type Sound = Sounds.Sound
export type VoiceLine = VoiceLines.VoiceLine
export type SoundRules = Sounds.SoundRules
export type Species = Species.Species
export type Skin = Skins.Skin
export type Stat = Stats.Stat
export type Station = Stations.Station
export type Thief = Thief.Thief
export type TipJar = TipJar.TipJar
export type Metrics = Metrics.Metrics
export type Traffic = Traffic.Traffic
export type TrafficDensity = Traffic.Density
export type TrafficRoute = Traffic.Route
export type Upgrade = Upgrades.Upgrade
export type UpgradeLevel = Upgrades.Level
export type Trailer = Trailer.Trailer
export type ShopWindow = ShopWindow.ShopWindow
export type AnomalyWindow = ShopWindow.AnomalyWindow
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
	-- service window = shop (TASK-284, owner request 2026-10-14, Provisional Q-270): the line leaves, anomalies it avoids/closes
	ShopWindow = ShopWindow,
	-- anomaly mode / day-only mode switch (owner request 2026-10-14, Provisional; tables, thief, Wide Counter off)
	Mode = Mode,
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
	-- TASK-268: vibration profiles (Input/client/Haptics), Provisional
	Haptics = Haptics,

	-- wave 3 (TASK-096; content-data.md §6.10, §6.11, §3.14). Numbers and texts Provisional; WalkPaths rows in TASK-098
	Anomalies = Anomalies,
	AnomalyCues = Anomalies.Cues,
	Atmospheres = Atmospheres,
	Cutscenes = Cutscenes,
	HallucinationRules = Hallucinations.Rules,
	Hallucinations = Hallucinations,
	Traffic = Traffic,
	WalkPathRules = WalkPaths.Rules,
	WalkPaths = WalkPaths,

	-- neon tube signs (user request 2026-10-11; NeonController)
	Neon = Neon,

	-- walking feel (playtest 2026-10-12; NpcService/Walker, PedestrianController). Numbers Provisional
	Movement = Movement,

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

	-- Pre-generated voice lines (Kokoro-82M; tools/voice, generated by build_content.py). Speech plays them as Sounds
	VoiceLines = VoiceLines,

	-- Focused prep mode: rules, tabs, steps, gestures, tolerances, grades (DEC-223; docs/tech/prep-mode.md §6). Provisional
	Prep = Prep,

	-- Street light cycle of MAP-01 (owner request 2026-10-12; TrafficLightController). Pure, Provisional
	TrafficLights = TrafficLights,

	-- Coffee cup on the trailer counter: surface rises / sinks with the coffee machine (owner request 2026-10-12;
	-- CoffeeCupController). Provisional
	CoffeeCup = CoffeeCup,

	-- Table trash dumpsters: the cleaned tray flies to the nearest bin (owner request 2026-10-12; TrashController). Provisional
	Trash = Trash,

	-- Tip jar that replaced the cash drawer (DEC-239, user decision 2026-10-13; TipJarService, EconomyController). Provisional
	TipJar = TipJar,
	-- RoMetrics analytics: the client-reported wire lists (owner request 2026-10-16; MetricsService). Provisional
	Metrics = Metrics,

	-- Sausage pose on the RestRail Parts (owner request 2026-10-12; Kitchen/shared/RailSlot). Provisional
	RailSlot = RailSlot,

	-- Security cameras: CCTV monitor in the trailer, fixed views from the pivots of the camera models, Normal / Night looks
	-- (FEAT-040, TASK-285; owner request 2026-10-14; SecurityService, SecurityController). Provisional
	Security = Security,

	-- Anomaly Tablet in the trailer: one page per V2 anomaly, unlocked per profile (TASK-335, TASK-345; owner request 2026-10-15;
	-- JournalService, JournalController). Provisional
	Journal = Journal,

	-- Class skins, Robux only (owner request 2026-10-17; design/skins-proposal.md; SkinService, SkinController). Provisional
	Skins = Skins,

	-- Restaurant flow (DEC-269..DEC-280; tech/restaurant-flow.md rev. 2 §4.1, design/restaurant-flow.md). Provisional.
	-- Restaurant.Rules.Enabled is THE single switch (TASK-390): Prep, Seating, Vehicles, Anomalies and Nights derive their
	-- restaurant values from Restaurant.Switch at require time (see the header of Restaurant.luau); false = published game
	Restaurant = Restaurant,
})
