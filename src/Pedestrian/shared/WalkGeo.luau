--!strict
--[[
	WalkGeo (TASK-122; architecture.md §19.17, T46; network.md §13.7; DEC-183). Shared, pure geometry of a passer-by
	path: same inputs -> same numbers on the server (PedestrianService) and on every client (PedestrianController,
	TASK-123), so a passer-by drawn from its Pedestrians record stands at the same place everywhere.

	Path = Content.WalkPaths row: NodeId chain of NpcNode (MapIndex) in walking order. Polyline through the node floor
	points; a Loop path also has the closing segment (last -> first), so its Length is one lap.
	Distance `s` of a record (AnchorDist, StopDist) is along that polyline. A Loop passer-by keeps going: `s` may pass
	Length and the position is read at `s mod Length` (PointAt / Heading). A through path ends at Length.
	Crossings: two consecutive nodes with the same `Crosswalk` attribute (MapIndex, §18.6) = a crosswalk edge. From =
	distance of the near curb node (where the passer-by waits for the reservation), To = the far curb node.

	Motion profile (Traffic/shared/Motion): flat, Fast = SlowSpeed = record Speed, no Slow stretch. ACCEL / BRAKE are
	PROVISIONAL (backend-coder, TASK-122): Content.WalkPaths.Rules has no field for them yet (pedido ao architect:
	mover para Rules.Accel / Rules.Brake). Both sides must read them from here.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Motion = require(ReplicatedStorage.shared.Traffic.Motion)

type WalkPath = typeof(Content.WalkPaths.List[1])

export type Crossing = {
	Crosswalk: string, -- key of Content.Traffic.Crosswalks
	From: number, -- near curb (stop point while waiting for the reservation)
	To: number, -- far curb (off the road)
}

export type Geo = {
	Key: string,
	Index: number, -- Content.WalkPaths.IndexOf (Pedestrians.Path)
	Loop: boolean,
	Path: Motion.Path,
	Length: number, -- one lap on a Loop path
	Crossings: { Crossing }, -- sorted by From, inside [0, Length]
}

const ACCEL = 16 -- studs/s^2, PROVISIONAL: 0 -> 8 studs/s in 0.5 s
const BRAKE = 16 -- studs/s^2, PROVISIONAL: stops in ~2 studs at 8 studs/s
const HEADING_HALF = 1.5 -- studs each side for the heading chord

const WalkGeo = {}

WalkGeo.Accel = ACCEL
WalkGeo.Brake = BRAKE

-- Speed as it travels in Pedestrians.Speed (Lync.quant(4, 12, 0.5)): both sides integrate the same number
function WalkGeo.QuantSpeed(speed: number): number
	return math.clamp(math.floor(speed * 2 + 0.5) / 2, 4, 12)
end

-- Geometry of a WalkPaths row from the map binding. nil + problem when a node is missing (binding / streaming).
-- `warnings` lists crosswalk pairs that do not name a known crosswalk (walked as plain sidewalk).
function WalkGeo.Build(row: WalkPath): (Geo?, string?, { string })
	const warnings: { string } = {}
	const nodes = row.Nodes
	const points: { Vector3 } = {}
	const crosswalks: { string? } = {}
	for i, id in nodes do
		const ok, info = pcall(MapIndex.Node, id)
		if not ok then
			return nil, `WalkPaths {row.Key}: NpcNode {id} not found`, warnings
		end
		points[i] = info.Position
		crosswalks[i] = info.Crosswalk
	end
	const count = #nodes
	if row.Loop then
		table.insert(points, points[1])
	end
	const path = Motion.Path(points)
	if path == nil then
		return nil, `WalkPaths {row.Key}: fewer than 2 nodes`, warnings
	end
	const crossings: { Crossing } = {}
	const edges = if row.Loop then count else count - 1
	for i = 1, edges do
		const j = if i == count then 1 else i + 1
		const a, b = crosswalks[i], crosswalks[j]
		if a ~= nil and a == b then
			if Content.Traffic.Crosswalks.ByKey[a] == nil then
				table.insert(warnings, `WalkPaths {row.Key}: {nodes[i]}-{nodes[j]} Crosswalk {a} is not in Traffic.Crosswalks`)
				continue
			end
			table.insert(crossings, { Crosswalk = a, From = path.Cum[i], To = path.Cum[i + 1] })
		end
	end
	return {
		Key = row.Key,
		Index = Content.WalkPaths.IndexOf[row.Key],
		Loop = row.Loop,
		Path = path,
		Length = path.Length,
		Crossings = crossings,
	},
		nil,
		warnings
end

-- Motion profile of a passer-by at `speed` (the record's quantized Speed)
function WalkGeo.Profile(geo: Geo, speed: number): Motion.Profile
	return Motion.Profile(geo.Length, {}, speed, speed, ACCEL, BRAKE)
end

-- Distance folded into one lap (Loop) or kept (through path)
function WalkGeo.Fold(geo: Geo, s: number): number
	if geo.Loop and geo.Length > 0 then
		return s % geo.Length
	end
	return s
end

-- Floor point at distance `s` (NpcNode height; the client lifts the rig by its hip height)
function WalkGeo.PointAt(geo: Geo, s: number): Vector3
	return Motion.PointAt(geo.Path, WalkGeo.Fold(geo, s))
end

-- Horizontal unit heading at distance `s`
function WalkGeo.Heading(geo: Geo, s: number): Vector3
	return Motion.Heading(geo.Path, WalkGeo.Fold(geo, s), HEADING_HALF)
end

-- A through path is over at its end; a Loop path never is
function WalkGeo.Done(geo: Geo, s: number): boolean
	return not geo.Loop and s >= geo.Length - Motion.Epsilon
end

return table.freeze(WalkGeo)
