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
-- MAP-01 §9.8 (level-designer 2026-10-10, Provisional): a walker is born and vanishes only at a building door
-- (DR-APT, SP-B laundry, DR-B3, MKT-DOOR) or at a street end beyond the player limits and out of sight of the Pad
-- and the Mart (SP-A, EX-E alley, SP-S). No loop any more (ninth_east_loop was born in sight). Night walkers only
-- use the far west (Shift Any: DR-B3 <-> CW-2 <-> Mart door): never the customer routes (D1, DR-APT, SP-S, SP-A)
-- nor the Juniper North posts, so a night NPC off those routes stays a readable anomaly sign (MAP-01 §9.1).
local function reversed(list: { string }): { string }
	const out: { string } = {}
	for index = #list, 1, -1 do
		table.insert(out, list[index])
	end
	return out
end

-- bank / apartments door -> north sidewalk -> CW-3 -> LANE-W east -> EX-E alley
const APT_EAST = { "DR-APT", "N-Z06-10", "N-Z06-03", "N-Z06-02", "N-Z02-10", "N-Z02-06", "N-Z02-08", "N-Z02-09", "EX-E" }
-- alley beyond BAR-N -> Juniper North east sidewalk -> CW-4 curb -> north sidewalk -> CW-3 -> EX-E alley
const NORTH_EAST = {
	"SP-A", "N-Z13-02", "N-Z07-01", "N-Z07-02", "N-Z06-01", "N-Z06-03", "N-Z06-02", "N-Z02-10", "N-Z02-06",
	"N-Z02-08", "N-Z02-09", "EX-E",
}
-- EX-E alley -> LANE-W behind the queue -> Juniper South east sidewalk -> CW-1 -> plaza -> Mart door
const EAST_MART = {
	"EX-E", "N-Z02-09", "N-Z02-08", "N-Z02-06", "N-Z02-05", "N-Z02-04", "N-Z02-03", "N-Z02-02", "N-Z08-03",
	"N-Z08-04", "N-Z08-05", "N-Z12-01", "N-Z12-02", "MKT-DOOR",
}
-- laundry door -> CW-2 -> Juniper South west sidewalk -> CW-1 -> LANE-W east -> EX-E alley
const LAUNDRY_EAST = {
	"SP-B", "N-Z06-07", "N-Z06-06", "N-Z02-14", "N-Z08-05", "N-Z08-04", "N-Z08-03", "N-Z02-02", "N-Z02-03",
	"N-Z02-04", "N-Z02-05", "N-Z02-06", "N-Z02-08", "N-Z02-09", "EX-E",
}
-- B3b door (far west, north sidewalk) -> CW-2 -> south sidewalk west -> SS rim -> Mart door (the night walk)
const B3_MART = { "DR-B3", "N-Z06-08", "N-Z06-07", "N-Z06-06", "N-Z02-14", "N-Z02-13", "N-Z02-11", "N-Z12-02", "MKT-DOOR" }

const base = Table.new({
	{ Key = "apt_to_east", Nodes = APT_EAST, Loop = false, Shift = "Day", Weight = 1 },
	{ Key = "east_to_apt", Nodes = reversed(APT_EAST), Loop = false, Shift = "Day", Weight = 1 },
	{ Key = "juniper_north_to_east", Nodes = NORTH_EAST, Loop = false, Shift = "Day", Weight = 1 },
	{ Key = "east_to_juniper_north", Nodes = reversed(NORTH_EAST), Loop = false, Shift = "Day", Weight = 1 },
	{ Key = "east_to_mart", Nodes = EAST_MART, Loop = false, Shift = "Day", Weight = 1 },
	{ Key = "mart_to_east", Nodes = reversed(EAST_MART), Loop = false, Shift = "Day", Weight = 1 },
	{ Key = "laundry_to_east", Nodes = LAUNDRY_EAST, Loop = false, Shift = "Day", Weight = 1 },
	{ Key = "east_to_laundry", Nodes = reversed(LAUNDRY_EAST), Loop = false, Shift = "Day", Weight = 1 },
	{ Key = "b3_to_mart", Nodes = B3_MART, Loop = false, Shift = "Any", Weight = 1 },
	{ Key = "mart_to_b3", Nodes = reversed(B3_MART), Loop = false, Shift = "Any", Weight = 1 },
} :: { WalkPath })

return Table.with(base, {
	Rules = Table.record(rules),
})
