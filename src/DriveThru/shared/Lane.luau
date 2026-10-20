--!strict
-- Drive-thru lane (TASK-574; tech/restaurant-flow.md §3.4). Shared, pure: the caller passes the MapPoint lookup (server
-- MapIndex.FindPoint, client the tagged MapPoint parts), so both sides build the same polyline and the same car poses.
--
-- Polyline: DT-IN -> DTQ-n .. DTQ-1 (the waiting points, highest first, the ones the map has) -> two turn points ->
-- DT-STOP (the window) -> DT-OUT. The turn points are made here (MAP-01 has no MapPoint for the U-turn): TURN_RUN studs
-- past the last lane point along the lane, and TURN_RUN studs before DT-STOP against the exit direction.
-- Spot 1 = DT-STOP (at the window); spot k >= 2 = DTQ-(k-1) when the map has it, else CAR_GAP studs behind spot k-1.
-- Times: a car crosses the whole way in (DT-IN -> DT-STOP) in Drive.ArriveTime, so a move of d studs takes
-- ArriveTime x d / that length (floor MIN_MOVE); leaving (DT-STOP -> DT-OUT) takes Drive.LeaveTime.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Motion = require(ReplicatedStorage.shared.Traffic.Motion)

export type Find = (id: string) -> CFrame?

export type Lane = {
	Path: Motion.Path,
	Stop: number, -- distance of DT-STOP along the path
	Spots: { number }, -- distance of each lane spot (1 = DT-STOP)
	Ground: number, -- Y of the road (DT-STOP)
}

const QUEUE_POINT = "DTQ-%d" -- MapPoints of the waiting cars, DTQ-1 = right behind the window
const QUEUE_MAX = 8
const TURN_RUN = 8 -- studs
const CAR_GAP = 16 -- studs between two waiting cars when the map has no DTQ point
const MIN_MOVE = 1 -- s
const HALF = 3 -- studs each side for the heading chord
const EXTRA_OUT = 40 -- studs driven past DT-OUT before the car is gone (client)

const Lane = {}

Lane.ExtraOut = EXTRA_OUT

local function flat(v: Vector3, default: Vector3): Vector3
	const out = Vector3.new(v.X, 0, v.Z)
	return if out.Magnitude > 1e-3 then out.Unit else default
end

-- nil = the map lacks DT-IN, DT-STOP or DT-OUT
function Lane.Build(find: Find): Lane?
	const binding = Content.Restaurant.Binding
	const into = find(binding.DriveIn)
	const stop = find(binding.DriveStop)
	const out = find(binding.DriveOut)
	if into == nil or stop == nil or out == nil then
		return nil
	end
	const ground = stop.Position.Y
	local function level(p: Vector3): Vector3
		return Vector3.new(p.X, ground, p.Z)
	end
	const queue: { Vector3 } = {}
	for index = 1, QUEUE_MAX do
		const point = find(string.format(QUEUE_POINT, index))
		if point == nil then
			break
		end
		table.insert(queue, level(point.Position))
	end
	const points: { Vector3 } = { level(into.Position) }
	for index = #queue, 1, -1 do
		table.insert(points, queue[index])
	end
	const stopAt = level(stop.Position)
	const outAt = level(out.Position)
	const last = points[#points]
	const before = if #points >= 2 then points[#points - 1] else last
	const laneDir = flat(last - before, flat(stopAt - last, Vector3.zAxis))
	const exitDir = flat(outAt - stopAt, -laneDir)
	if #queue > 0 then
		-- U-turn: the lane and the exit run side by side (MAP-01); a straight approach needs no turn points
		table.insert(points, last + laneDir * TURN_RUN)
		table.insert(points, stopAt - exitDir * TURN_RUN)
	end
	table.insert(points, stopAt)
	const stopIndex = #points
	table.insert(points, outAt)
	const path = Motion.Path(points)
	if path == nil then
		return nil
	end
	const stopDist = path.Cum[stopIndex]
	const spots: { number } = { stopDist }
	for spot = 2, Content.Restaurant.Drive.Lanes do
		const at = queue[spot - 1]
		if at ~= nil then
			-- DTQ-(spot-1) sits at index 1 + (#queue - (spot - 1) + 1) of the polyline
			spots[spot] = path.Cum[2 + #queue - (spot - 1)]
		else
			spots[spot] = math.max(spots[spot - 1] - CAR_GAP, 0)
		end
	end
	return { Path = path, Stop = stopDist, Spots = spots, Ground = ground }
end

-- Distance of lane spot `spot` (clamped to the spots the lane has)
function Lane.Spot(lane: Lane, spot: number): number
	return lane.Spots[math.clamp(spot, 1, #lane.Spots)]
end

-- Seconds a car takes from distance `from` to `to` (forward)
function Lane.MoveTime(lane: Lane, from: number, to: number): number
	const whole = math.max(lane.Stop, 1)
	return math.max(Content.Restaurant.Drive.ArriveTime * math.abs(to - from) / whole, MIN_MOVE)
end

-- Seconds from the window to DT-OUT
function Lane.LeaveTime(): number
	return Content.Restaurant.Drive.LeaveTime
end

-- Ground point at distance `s`
function Lane.PointAt(lane: Lane, s: number): Vector3
	return Motion.PointAt(lane.Path, s)
end

-- Car pivot (base centre on the road, LookVector = front) at distance `s`
function Lane.Pose(lane: Lane, s: number): CFrame
	const position = Motion.PointAt(lane.Path, s)
	return CFrame.lookAt(position, position + Motion.Heading(lane.Path, s, HALF))
end

-- Eased position between two distances: `alpha` 0..1 of the move (smooth start and stop)
function Lane.Ease(from: number, to: number, alpha: number): number
	const x = math.clamp(alpha, 0, 1)
	return from + (to - from) * x * x * (3 - 2 * x)
end

return table.freeze(Lane)
