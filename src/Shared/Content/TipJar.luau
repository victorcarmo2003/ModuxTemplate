--!strict
-- Tip jar (DEC-239, user decision 2026-10-13; PROVISIONAL): replaces the cash drawer / register. Sales go straight to the
-- party Cash (DEC-238); the jar only holds TIPS (customer tips and table tips). The crew collects it on a prompt
-- (Content.Actions.collect_tips) and it goes to the party Cash; what is left at the end of the shift is deposited at
-- the Summary. The jar level lives in the Economy set field `Drawer` (kept for the wire; it means "tips in the jar").
-- Owner of the numbers: game-designer. Read by TipJarService (server) and EconomyController (client, fills the jar).
local Table = require(script.Parent.Table)

export type TipJar = {
	FullAt: number, -- $ in the jar at which it shows full (the client scales the pieces up to this amount)
	MaxBills: number, -- most pieces (bills + coins) drawn inside the jar model
	MapId: string, -- MapId of the jar Model inside the Vehicle (the level designer authors it)
	LegacyMapIds: { string }, -- old drawer / register ids still accepted while the map has not migrated
}

const jar: TipJar = {
	FullAt = 20, -- Provisional
	MaxBills = 14, -- Provisional
	MapId = "TRL-TIPJAR",
	LegacyMapIds = { "DRAWER", "TRL-DRAWER" },
}

return Table.record(jar)
