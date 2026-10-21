--!strict
-- Kitchen bulb burnout (owner request 2026-10-21, Q-433; PROVISIONAL numbers and texts).
-- Toggling the trailer switch Toggles times within Window s (party-wide: everyone shares the same light) burns the
-- bulb: trailer_interior goes dark, the switch stops responding and the breaker outside (breaker_reset, the ANM-020
-- panel) is the only fix. LightService counts and owns the Bulb set; BulbController plays the spark, sound and line.

export type Bulb = {
	Toggles: number, -- switch toggles that burn the bulb ...
	Window: number, -- ... within this many seconds
	DeadText: string, -- switch prompt text while burnt (the prompt stays up and refuses)
	Title: string, -- Announce title at the burn
	Line: string, -- Announce line at the burn
	Hold: number, -- s the Announce stays up
	Sound: string, -- Content.Sounds key at the burn (local, non-spatial)
	Sparks: number, -- particles in the burst at the switch
	Fresh: number, -- s after Bulb.At in which a client still plays the burn (late joiners see only the dark)
}

return table.freeze({
	Toggles = 6, -- PROVISIONAL
	Window = 8, -- PROVISIONAL
	DeadText = "Burnt Out",
	Title = "BULB BURNT OUT",
	Line = "Fix it at the breaker outside.",
	Hold = 3,
	Sound = "power_cut",
	Sparks = 24,
	Fresh = 2,
} :: Bulb)
