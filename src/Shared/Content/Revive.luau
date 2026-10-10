--!strict
-- Revive, single record (content-data.md §3.12, §6.8; architecture.md §19.7, T54; FEAT-034; DEC-094, DEC-129).
-- Owner: game-designer. Waves 2-3 use only these three numbers; the rest of §3.12 (SanityPct, ProtectTime, Kit,
-- wipe freeze, IntentTimeout, credits) arrives with the wave 4 content task.
local Table = require(script.Parent.Table)

export type Revive = {
	MaxPerNight: number, -- per player per night; the next fall is Spectator at once (DEC-129)
	WipeWindow: number, -- seconds with nobody Active before the night is lost (DEC-094)
	BodyFallback: number, -- seconds until the body fades when there is no ambulance (waves 2-3, T54)
}

const revive: Revive = {
	MaxPerNight = 2, -- DEC-129
	WipeWindow = 10, -- DEC-094
	BodyFallback = 20, -- architect (T54)
}

return Table.record(revive)
