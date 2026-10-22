--!strict
-- Sanity, single record (content-data.md §3.16, §6.5; architecture.md §19.7, §19.8; FEAT-019, FEAT-021;
-- DEC-056, DEC-069, DEC-166, DEC-167). Owner: game-designer. Losses and gains are positive amounts.
-- Class stats on top: SanityStart, SanityMax, SeeAnomalyLoss, CoffeeRestore, CoffeeBrewTime (Stats.luau).
-- Brew time of the machine: Stations.coffee_machine.Params.BrewTime. Trailer light radius: Upgrades.trailer_lights
-- effect LightRadius. Neither is repeated here (one source per number).
local Table = require(script.Parent.Table)

-- Idle drain (owner 2026-10-22 "dentro do trailer a sanidade não cai ... 1 a cada 3 segundos"; Provisional, Q-477): sanity
-- falls by itself during the Night phase anywhere, lit or not. In the dark it does not add to DarkPerSecond: the higher
-- of the two rates applies (Sanity.passiveLoss).
export type Idle = {
	PerSecond: number, -- lost per second in the Night phase (1/3 = one point every 3 s)
	NightScale: { [number]: number }, -- multiplier by night number; a night not listed uses 1
}

export type Bands = {
	High: number, -- >= High -> look pack "Day"
	Mid: number, -- >= Mid -> "Mid"; below -> "Night" (absolute points, DEC-167)
}

-- Stare pressure (TASK-482; DEC-294, DEC-295; design/horror-cinematic.md §8; tech/stare-pressure.md). Rows flagged
-- Anomalies[k].Stare only. Same cone on both sides: the client builds the look from Delay, the server drains from
-- DrainAfter. Sight first (SeeAnomaly at SeeTime, once per night), then the stare: never the same second twice.
export type Stare = {
	Angle: number, -- degrees, full cone around the gaze (narrower than SeeAngle: looking STRAIGHT at it)
	Delay: number, -- s of continuous stare before the pressure starts (heart, edges, head)
	Release: number, -- s looking away that release everything (the stare count restarts)
	DrainAfter: number, -- s of continuous stare before sanity starts to fall (>= Delay; > SeeTime)
	PerSecond: number, -- sanity lost per second of stare past DrainAfter
	Cap: number, -- most sanity one occurrence can take from one player by staring
}

-- Sanity tiers (owner 2026-10-21 "deixar mais na cara que a sanidade está baixa, fazendo ele alucinar mais e ver mais
-- anomalias"; DEC-352, Provisional). A ladder the player feels, not a number: each step down adds hallucinations, server
-- scares and screen / sound signs. Absolute points like Bands; the first row (top down) with value >= From wins, max 0
-- (day) is always the first row. Cartoon and Mild (DEC-172): no red, no gore, no shake.
export type Tier = {
	Key: string,
	From: number, -- the tier holds while sanity >= From (rows in descending From, the last one From = 0)
	-- hallucinations (client roll, HallucinationController; replaces HallucinationRules.Interval)
	Interval: { number }, -- {min, max} s between two rolls
	Deep: number, -- weight multiplier of the rows this tier unlocks (MaxSanity <= the From of the tier above)
	-- server (AnomalyService, tech: Anomaly/server/AnomalyService/Pressure.luau)
	Scare: { number }, -- {min, max} s between two family D scares sent to this player only; {} = none
	Extra: number, -- chance, per Pressure.Every s, of one extra regular anomaly (the crew's average sanity picks the tier)
	-- screen and sound (VitalController, this client only)
	Vignette: number, -- dark edges 0..1
	Saturation: number, -- ColorCorrection (negative = greyer)
	Tint: number, -- 0..1 towards the cold blue-white tint
	PulseHz: number, -- the edges breathe at this rate; 0 = steady
	PulseDepth: number, -- +- share of the vignette
	Blur: { number }, -- {min, max} s between two short blurs (Pressure.BlurSize for Pressure.BlurTime); {} = none
	Heartbeat: number, -- s between two heartbeats; 0 = none
	Breath: number, -- s between two held breaths; 0 = none
	Words: number, -- s between two bursts of the character's words on screen (HorrorScenes.Words.low_sanity); 0 = none
}

-- Rules around the tiers (DEC-352, Provisional)
export type Pressure = {
	Every: number, -- s between two extra-anomaly rolls (server)
	MaxExtra: number, -- extra regular anomalies per night at most (the crew never drowns)
	FromNight: number, -- no extra anomaly before this night (Night 1 stays the tutorial night)
	Lead: number, -- game minutes after the roll the extra entry is due (then Admit spaces it like any other)
	FirstScare: number, -- s after entering a scare tier before its first personal scare
	BlurSize: number, -- style guide §10: Blur <= 4
	BlurTime: number, -- s (<= 0.5)
	SaturationFloor: number, -- dark + tier never wash the screen further
	EnterWords: number, -- s of the word burst when the player drops into a deeper tier (the step is felt)
	EnterBlur: number, -- s of the blur on that drop
}

export type Sanity = {
	Start: number,
	SeeAnomaly: number, -- lost once per anomaly per night when seen
	SeeTime: number, -- seconds of accumulated gaze inside the cone
	SeeAngle: number, -- degrees, full cone
	SeeRange: number, -- studs (default; per anomaly in Anomalies.ViewRange, wave 3)
	RuleBroken: number, -- lost on a broken rule (Penalize)
	DarkDelay: number, -- seconds in the dark before the loss starts
	DarkPerSecond: number, -- lost per second in the dark
	DarkPhases: { string }, -- keys of Shift where the dark counts
	DreadAfter: number, -- seconds in the dark before the dread (the punishment of the lights left off)
	DreadPerSecond: number, -- lost per second in the dark once the dread is on (instead of DarkPerSecond)
	DreadAttribute: string, -- Player attribute (true while the dread is on): the client turns the place terrifying
	DarkAtAttribute: string, -- Player attribute: server time of the last tick that took dark loss (the client's dark look)
	Idle: Idle,
	Coffee: number, -- restored by a coffee (25; Barista 35 by CoffeeRestore)
	CoffeeDrinkTime: number, -- seconds of the drink animation
	CoffeeNightOnly: boolean, -- Provisional (Q-170)
	FirstNightStart: number, -- Night 1 only: the night starts at this value (capped by the class Max), teaches the coffee
	-- Night 1: Walt's coffee call rings the first time an Active member's sanity falls to this value or below (TASK-596)
	CoffeeCallAt: number,
	CoffeeStock: number, -- doses in the coffee machine when the trailer comes into use (once per run)
	CoffeeHint: number, -- seconds the Night 1 coffee emphasis lasts after Walt's coffee call ends
	BasicLampRadius: number, -- studs of the factory lamp beyond its LightZone volumes (0: LZ-1 and LZ-2 only)
	Bands: Bands,
	BandMinHold: number, -- seconds a band must hold before the look changes (Provisional, DEC-167)
	Stare: Stare,
	Tiers: { Tier },
	Pressure: Pressure,
}

const sanity: Sanity = {
	Start = 100, -- DEC-056
	SeeAnomaly = 5, -- FEAT-019
	SeeTime = 1,
	SeeAngle = 40,
	SeeRange = 60,
	RuleBroken = 35, -- FEAT-019
	DarkDelay = 5, -- FEAT-020; owner 2026-10-18 "a sanidade está descendo muito rápido" (was 3)
	DarkPerSecond = 0.5, -- FEAT-020; owner 2026-10-18 (was 1). Fractions add up in VitalService (DarkOwed)
	DarkPhases = { "Call", "Prep", "Night" }, -- not NightEnd: the night is already won (L2-03, Provisional)
	-- owner 2026-10-19 ("se ele passar muito tempo com as luzes apagadas, acontece alguma coisa ... deixando o ambiente bem
	-- aterrorizante e diminuir a sanidade dele um pouco mais rápido"). Provisional, judged in Play
	DreadAfter = 25,
	DreadPerSecond = 1.5,
	DreadAttribute = "DarkDread",
	DarkAtAttribute = "SanityDarkAt",
	-- owner 2026-10-22 (Provisional, Q-477): inside the lit trailer sanity did not fall; now 1 point per 3 s in the Night
	-- phase. Night 1 halved (the tutorial night). Fractions add up in VitalService (DarkOwed)
	Idle = { PerSecond = 1 / 3, NightScale = { [1] = 0.5 } },
	Coffee = 25, -- FEAT-021
	CoffeeDrinkTime = 1.5, -- FEAT-021
	CoffeeNightOnly = true, -- Q-170 option A (Provisional): brewed by day, drunk only at night
	-- TASK-596 (owner 2026-10-19, Provisional, Q-205): Night 1 starts at 60 (was 50) and the coffee call waits for the first
	-- drop to CoffeeCallAt, so the rookie digests the kitchen tutorial before the coffee lesson. Other nights: Start (DEC-056)
	FirstNightStart = 60, -- Provisional (user request 2026-10-11, Night 1 teaches coffee); progression.md "10 doses"
	CoffeeCallAt = 50, -- Provisional (TASK-596)
	CoffeeStock = 10, -- Provisional: initial doses; refills are bought at the Mart (Ground Coffee, 10 doses)
	CoffeeHint = 25, -- Provisional: HUD emphasis ends at the first coffee or this many seconds after the call
	BasicLampRadius = 0, -- Provisional (TASK-081, DEC-189)
	Bands = { High = 60, Mid = 40 }, -- DEC-167
	BandMinHold = 0, -- 1 s if it flickers in the wave 2 test (Provisional)
	-- TASK-482 (Provisional, DEC-294 "~2 s", "~1 s"): mild (DEC-172), ~10 s of stare = -10, at most -20 per occurrence
	-- owner 2026-10-18: PerSecond 1.5 -> 1 (sanity fell too fast)
	Stare = { Angle = 18, Delay = 2, Release = 1, DrainAfter = 3, PerSecond = 1, Cap = 20 },
	-- DEC-352 (Provisional): 100-60 Calm / 60-40 Uneasy / 40-20 Shaken / < 20 Breaking. Same cuts as the hallucination
	-- rows (MaxSanity 60 / 40 / 20) and Bands, so every step down also unlocks new hallucinations
	Tiers = {
		{
			Key = "Calm",
			From = 60,
			Interval = { 20, 45 },
			Deep = 1,
			Scare = {},
			Extra = 0,
			Vignette = 0,
			Saturation = 0,
			Tint = 0,
			PulseHz = 0,
			PulseDepth = 0,
			Blur = {},
			Heartbeat = 0,
			Breath = 0,
			Words = 0,
		},
		{
			Key = "Uneasy",
			From = 40,
			Interval = { 16, 30 },
			Deep = 1.5,
			Scare = {},
			Extra = 0,
			Vignette = 0.22,
			Saturation = -0.06,
			Tint = 0.35,
			PulseHz = 0,
			PulseDepth = 0,
			Blur = { 30, 50 },
			Heartbeat = 0,
			Breath = 22,
			Words = 0,
		},
		{
			Key = "Shaken",
			From = 20,
			Interval = { 9, 18 },
			Deep = 2,
			Scare = { 70, 110 },
			Extra = 0.25,
			Vignette = 0.38,
			Saturation = -0.16,
			Tint = 1,
			PulseHz = 0.5,
			PulseDepth = 0.15,
			Blur = { 14, 24 },
			Heartbeat = 1.4,
			Breath = 13,
			Words = 20,
		},
		{
			Key = "Breaking",
			From = 0,
			Interval = { 5, 10 },
			Deep = 3,
			Scare = { 35, 55 },
			Extra = 0.5,
			Vignette = 0.52,
			Saturation = -0.28,
			Tint = 1,
			PulseHz = 0.9,
			PulseDepth = 0.22,
			Blur = { 6, 12 },
			Heartbeat = 0.85,
			Breath = 8,
			Words = 9,
		},
	},
	Pressure = {
		Every = 45,
		MaxExtra = 2,
		FromNight = 2,
		Lead = 1,
		FirstScare = 15,
		BlurSize = 4,
		BlurTime = 0.4,
		SaturationFloor = -0.35,
		EnterWords = 1.5,
		EnterBlur = 0.5,
	},
}

return Table.record(sanity)
