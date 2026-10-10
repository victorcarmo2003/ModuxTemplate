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

const base = Table.new({} :: { WalkPath })

return Table.with(base, {
	Rules = Table.record(rules),
})
