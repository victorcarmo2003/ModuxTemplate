--!strict
-- Sidewalk paths of the pedestrians (content-data.md §6.11; architecture.md §19.17, T46; DEC-183). Owner:
-- level-designer. Wave 2 ships the shape only, with no rows; the wave 3 content task (TASK-096) fills it from the
-- MAP-01 binding. Record id in the Pedestrians set = IndexOf (no wire enum, so an empty table is valid).
-- Nodes = NodeId chain of NpcNode on the sidewalk; a crosswalk is a pair of nodes linked as Crosswalk.
local Table = require(script.Parent.Table)

export type Shift = "Day" | "Night" | "Any"

export type WalkPath = {
	Key: string,
	Nodes: { string },
	Loop: boolean,
	Shift: Shift,
	Weight: number,
}

return Table.new({} :: { WalkPath })
