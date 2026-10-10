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
	Coffee: number, -- restored by a coffee (25; Barista 35 by CoffeeRestore)
	CoffeeCooldown: number, -- seconds between two drinks
	CoffeeDrinkTime: number, -- seconds of the drink animation
	CoffeeNightOnly: boolean, -- Provisional (Q-170)
	BasicLampRadius: number, -- studs of the factory lamp beyond its LightZone volumes (0: LZ-1 and LZ-2 only)
	Bands: Bands,
	BandMinHold: number, -- seconds a band must hold before the look changes (Provisional, DEC-167)
}

const sanity: Sanity = {
	Start = 100, -- DEC-056
	SeeAnomaly = 5, -- FEAT-019
	SeeTime = 1,
	SeeAngle = 40,
	SeeRange = 60,
	RuleBroken = 35, -- FEAT-019
	DarkDelay = 3, -- FEAT-020
	DarkPerSecond = 1, -- FEAT-020
	DarkPhases = { "Call", "Prep", "Night" }, -- not NightEnd: the night is already won (L2-03, Provisional)
	Coffee = 25, -- FEAT-021
	CoffeeCooldown = 60, -- FEAT-021
	CoffeeDrinkTime = 1.5, -- FEAT-021
	CoffeeNightOnly = true, -- Q-170 option A (Provisional): brewed by day, drunk only at night
	BasicLampRadius = 0, -- Provisional (TASK-081, DEC-189)
	Bands = { High = 60, Mid = 40 }, -- DEC-167
	BandMinHold = 0, -- 1 s if it flickers in the wave 2 test (Provisional)
}

return Table.record(sanity)
