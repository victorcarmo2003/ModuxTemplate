--!strict
-- Revive, single record (content-data.md §3.12, §6.8; architecture.md §19.7, T54; FEAT-034; DEC-094, DEC-129).
-- Owner: game-designer. Waves 2-3 use only these three numbers; the rest of §3.12 (SanityPct, ProtectTime, Kit,
-- wipe freeze, IntentTimeout, credits) arrives with the wave 4 content task.
local Table = require(script.Parent.Table)

export type Revive = {
	MaxPerNight: number, -- per player per night; the next fall is Spectator at once (DEC-129)
	WipeWindow: number, -- seconds with nobody Active before the night is lost (DEC-094)
	BodyFallback: number, -- seconds until the body fades when there is no ambulance (waves 2-3, T54)
	-- Fall screens (DEC-318, design/faint-screen-flow.md): the cause card, then the revive countdown; nobody standing
	-- with a team life left = the heart breaks and the night repeats after CauseTime; with none left = ReviveAllWindow s
	-- for "Revive all" (util_revive_all) after the cause card
	CauseTime: number,
	DownWindow: number, -- s a Down can be revived after the cause card; then Spectator until the next night
	ReviveAllWindow: number,
}

const revive: Revive = {
	MaxPerNight = 2, -- DEC-129
	WipeWindow = 10, -- DEC-094
	BodyFallback = 20, -- architect (T54)
	CauseTime = 3, -- DEC-318
	DownWindow = 15, -- DEC-318
	ReviveAllWindow = 15, -- DEC-318
}

return Table.record(revive)
