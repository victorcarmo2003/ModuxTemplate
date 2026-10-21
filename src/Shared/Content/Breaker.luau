--!strict
-- Breaker trips by itself (owner request 2026-10-21, Q-435; PROVISIONAL numbers and texts).
-- From FromNight on, every Every {min, max} s of the Night phase the breaker outside trips with no anomaly behind it: the
-- power goes out (LightService:TripBreaker, the same dark as the ANM-020 blackout after its attack) until somebody holds
-- the breaker (breaker_reset) or a new shift starts. No shape, no attack: the cost is the dark (VitalService drains
-- sanity there) and the trip outside. AnomalyService/Trip.luau schedules it; it never trips while an anomaly runs, the
-- power is already out or the bulb is burnt (it waits Retry s and tries again), nor under the tutorial or the grace.

export type Breaker = {
	FromNight: number, -- first night it can trip
	PerNight: { number }, -- trips at most, by night (index = night; past the end = the last value)
	Every: { number }, -- {min, max} s between two trips (the first one too, counted from the end of the grace)
	Retry: number, -- s to wait when the moment is busy (anomaly running, power out, bulb burnt)
	Title: string, -- Announce title at the trip
	Line: string, -- Announce line at the trip
	Hold: number, -- s the Announce stays up
	Sound: string, -- Content.Sounds key at the trip (local, non-spatial)
	Fresh: number, -- s after Power.At in which a client still plays the trip (late joiners see only the dark)
}

return table.freeze({
	FromNight = 3, -- PROVISIONAL
	PerNight = { 0, 0, 1, 1, 1, 2, 2, 2, 3, 3 }, -- PROVISIONAL
	Every = { 120, 210 }, -- PROVISIONAL
	Retry = 15,
	Title = "BREAKER TRIPPED",
	Line = "Reset it outside.",
	Hold = 3,
	Sound = "power_cut",
	Fresh = 2,
} :: Breaker)
