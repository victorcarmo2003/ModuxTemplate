--!strict
-- Sanity, single record (content-data.md §3.16, §6.5; architecture.md §19.7, §19.8; FEAT-019, FEAT-021;
-- DEC-056, DEC-069, DEC-166, DEC-167). Owner: game-designer. Losses and gains are positive amounts.
-- Class stats on top: SanityStart, SanityMax, SeeAnomalyLoss, CoffeeRestore, CoffeeBrewTime (Stats.luau).
-- Brew time of the machine: Stations.coffee_machine.Params.BrewTime. Trailer light radius: Upgrades.trailer_lights
-- effect LightRadius. Neither is repeated here (one source per number).
local Table = require(script.Parent.Table)

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
}

return Table.record(sanity)
