--!strict
-- Achievements (content-data.md §3.11; architecture.md §19.11; data.md §1; DEC-058, DEC-084). Owner: game-designer +
-- narrative-writer (Name). Key = what the profile stores in Achievements; Notice "achievement" carries IndexOf.
-- Counter = numeric field of the profile Template that drives it. BadgeId 0 = no badge yet (the user creates it in
-- the Creator Hub and passes the id).
local Table = require(script.Parent.Table)

export type Achievement = {
	Key: string,
	Name: string,
	Hidden: boolean, -- secret until unlocked (DEC-058)
	Counter: string,
	Target: number,
	Gems: number,
	BadgeId: number,
}

return Table.new({
	{
		Key = "day_100",
		Name = "Never Clocked Out", -- ui-text.md §9
		Hidden = true, -- DEC-058
		Counter = "EndlessDays", -- data.md §1 (endless days with anti-AFK, across sessions)
		Target = 100, -- DEC-084
		Gems = 300, -- DEC-084
		BadgeId = 0,
	},
} :: { Achievement })
