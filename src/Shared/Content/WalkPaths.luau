--!strict
-- Sidewalk paths of the pedestrians (content-data.md §6.11; architecture.md §19.17, T46; network.md §13.7;
-- DEC-183). Owner: level-designer (rows, TASK-098, from the MAP-01 binding); architect (shape, TASK-096).
-- Record id in the Pedestrians set = IndexOf (Path = Lync.int(1, Rules.MaxPaths)); no wire enum, so an empty table
-- is valid until the binding has the sidewalk nodes.
-- Nodes = NodeId chain of NpcNode on the sidewalk, in walking order. A crosswalk is a pair of consecutive nodes
-- linked as Crosswalk in the map; PedestrianService asks TrafficService:ReserveCrossing there (§8.1).
-- Loop: the last node connects back to the first (walk forever); otherwise the pedestrian despawns at the end.
-- Shift: Day / Night / Any. Weight: chance among the paths of the current shift.
local Table = require(script.Parent.Table)

export type Shift = "Day" | "Night" | "Any"

export type WalkPath = {
	Key: string,
	Nodes: { string },
	Loop: boolean,
	Shift: Shift,
	Weight: number,
}

export type Rules = {
	MaxPaths: number, -- Pedestrians.Path range (network.md §13.7)
	Slots: number, -- Pedestrians set ids 1..Slots (>= max of Flow.DayWalkers)
	Speed: { number }, -- {min, max} studs/s; Pedestrians.Speed = Lync.quant(4, 12, 0.5)
	LodDistance: number, -- studs: beyond it the client hides the local rig (PedestrianController)
}

const rules: Rules = {
	MaxPaths = 64,
	Slots = 8,
	Speed = { 7, 9 }, -- Provisional, around CustomerTypes.pedestrian.WalkSpeed (8)
	LodDistance = 120, -- architecture.md §19.17
}

-- Rows: MAP-01 §9.3 (TASK-098, level-designer; Provisional). Every node is an NpcNode of workspace.MapBinding
-- written by tools/assetplace/bind_map01.luau; consecutive nodes are linked there (check_map01 rule 10).
-- Crosswalk pairs: CW-4 N-Z02-01/N-Z06-01, CW-3 N-Z02-10/N-Z06-02, CW-1 N-Z08-04/N-Z08-05, CW-2 N-Z02-14/N-Z06-06.
-- Through paths start and end out of sight (beyond BAR-N, EX-E, the west/east ends of the sidewalks). Night
-- walkers only use the far west crossing (Shift Any): never the customer routes (SP-A, D1) nor the Juniper North
-- posts, so a night NPC off those routes stays a readable anomaly sign (MAP-01 §9.1).
const base = Table.new({
	-- loop around the east block: CW-4, north sidewalk in front of the bank, CW-3, LANE-W back to the corner
	{
		Key = "ninth_east_loop",
		Nodes = { "N-Z02-02", "N-Z02-01", "N-Z06-01", "N-Z06-03", "N-Z06-02", "N-Z02-10", "N-Z02-05", "N-Z02-04", "N-Z02-03" },
		Loop = true,
		Shift = "Day",
		Weight = 1,
	},
	-- Juniper North east sidewalk (from beyond BAR-N) -> CW-4 curb -> north sidewalk -> east end
	{
		Key = "juniper_north_to_east",
		Nodes = { "N-Z13-01", "N-Z13-02", "N-Z07-01", "N-Z07-02", "N-Z06-01", "N-Z06-03", "N-Z06-02", "N-Z06-04", "N-Z06-05" },
		Loop = false,
		Shift = "Day",
		Weight = 1,
	},
	{
		Key = "east_to_juniper_north",
		Nodes = { "N-Z06-05", "N-Z06-04", "N-Z06-02", "N-Z06-03", "N-Z06-01", "N-Z07-02", "N-Z07-01", "N-Z13-02", "N-Z13-01" },
		Loop = false,
		Shift = "Day",
		Weight = 1,
	},
	-- EX-E -> LANE-W behind the queue -> Juniper South east sidewalk -> CW-1 (the Mart crossing) -> plaza -> west end
	{
		Key = "east_to_west_via_mart",
		Nodes = {
			"EX-E", "N-Z02-09", "N-Z02-08", "N-Z02-06", "N-Z02-05", "N-Z02-04", "N-Z02-03", "N-Z02-02",
			"N-Z08-03", "N-Z08-04", "N-Z08-05", "N-Z12-01", "N-Z12-02", "N-Z02-11", "N-Z02-12",
		},
		Loop = false,
		Shift = "Day",
		Weight = 1,
	},
	{
		Key = "west_to_east_via_mart",
		Nodes = {
			"N-Z02-12", "N-Z02-11", "N-Z12-02", "N-Z12-01", "N-Z08-05", "N-Z08-04", "N-Z08-03", "N-Z02-02",
			"N-Z02-03", "N-Z02-04", "N-Z02-05", "N-Z02-06", "N-Z02-08", "N-Z02-09", "EX-E",
		},
		Loop = false,
		Shift = "Day",
		Weight = 1,
	},
	-- far west: south sidewalk -> CW-2 -> north sidewalk (the only night walk, ~60 studs left of the window)
	{
		Key = "west_cross_north",
		Nodes = { "N-Z02-12", "N-Z02-11", "N-Z02-13", "N-Z02-14", "N-Z06-06", "N-Z06-07", "N-Z06-08", "N-Z06-09" },
		Loop = false,
		Shift = "Any",
		Weight = 1,
	},
	{
		Key = "west_cross_south",
		Nodes = { "N-Z06-09", "N-Z06-08", "N-Z06-07", "N-Z06-06", "N-Z02-14", "N-Z02-13", "N-Z02-11", "N-Z02-12" },
		Loop = false,
		Shift = "Any",
		Weight = 1,
	},
} :: { WalkPath })

return Table.with(base, {
	Rules = Table.record(rules),
})
