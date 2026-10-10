--!strict
-- Route geometry from the MAP-01 binding (TASK-104; architecture.md §8.1; Required.luau traffic tags, TASK-097 d;
-- bind_map01.luau W5). Read once per route on the server; same rules as the client (TrafficController):
--   TrafficPath / PathId = Routes[].Path: Folder/Model whose BasePart/Attachment descendants are the route nodes,
--     ordered by attribute Index (binding), else Order, else the number at the end of the name. A BasePart node counts
--     at its bottom face (road surface).
--   TrafficLine / LineId = SL-*: stop line piece; its distance along a route = projection of its centre (XZ).
--   TrafficBox / BoxId = X-T, CW-1..4: volume; its range along a route = stretches whose XZ falls in the footprint.
-- Profile: SpeedStraight, SpeedCrossing inside the X-T footprint, Crossing.PullAway / Crossing.BrakeDecel.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Motion = require(ReplicatedStorage.shared.Traffic.Motion)

type Route = typeof(Content.Traffic.Routes.List[1])

export type Zone = {
	Key: string, -- box key (X-T or CW-n)
	Entry: number, -- where a car must stop before it: the route's stop line for that box, else the box start
	From: number,
	To: number,
}

-- A place where a car of this route may stop: a route stop line, or the start of a crosswalk box the route crosses
-- without listing it (binding/content mismatch, warned; the car still stops before it)
export type StopPoint = {
	Key: string, -- line name (shared by every route stopping there), or "<CW>@<route>"
	Kind: "Pare" | "Crosswalk",
	Ref: string, -- Pare: the line; Crosswalk: key of Crosswalks
	At: number, -- distance of the line along this path
}

export type Geo = {
	Key: string,
	Path: Motion.Path,
	Profile: Motion.Profile,
	-- stop line name -> distance of the line along this path
	Lines: { [string]: number },
	-- X-T range along this path (nil when the path does not cross it)
	Cross: { number }?,
	-- every box the path crosses (X-T and crosswalks), sorted by From
	Zones: { Zone },
	-- stop points sorted by At, and At by Key
	Stops: { StopPoint },
	StopAt: { [string]: number },
}

const PATH_TAG = "TrafficPath"
const PATH_ATTRIBUTE = "PathId"
const LINE_TAG = "TrafficLine"
const LINE_ATTRIBUTE = "LineId"
const BOX_TAG = "TrafficBox"
const BOX_ATTRIBUTE = "BoxId"
const LINE_OFFSET_MAX = 20 -- studs between a stop line and its route before the binding is suspicious

const Paths = {}

local function findTagged(tag: string, attribute: string, id: string): Instance?
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:GetAttribute(attribute) == id then
			return instance
		end
	end
	return nil
end

local function nodeOrder(instance: Instance): number
	for _, attribute in { "Index", "Order" } do
		const value = instance:GetAttribute(attribute)
		if type(value) == "number" then
			return value
		end
	end
	const digits = string.match(instance.Name, "(%d+)%D*$")
	return if digits then tonumber(digits) or math.huge else math.huge
end

local function nodePosition(instance: Instance): Vector3?
	if instance:IsA("BasePart") then
		return instance.Position - Vector3.new(0, instance.Size.Y / 2, 0)
	elseif instance:IsA("Attachment") then
		return instance.WorldPosition
	end
	return nil
end

local function boxPart(key: string): BasePart?
	const instance = findTagged(BOX_TAG, BOX_ATTRIBUTE, key)
	return if instance and instance:IsA("BasePart") then instance else nil
end

-- First and last distance of the path inside the box footprint (nil if it never enters)
local function rangeOf(path: Motion.Path, box: BasePart): { number }?
	const stretches = Motion.Stretches(path, box.CFrame, box.Size)
	if #stretches == 0 then
		return nil
	end
	return { stretches[1][1], stretches[#stretches][2] }
end

-- Ordered polyline of a TrafficPath (nil + problem when missing)
function Paths.polyline(pathId: string): (Motion.Path?, string?)
	const container = findTagged(PATH_TAG, PATH_ATTRIBUTE, pathId)
	if container == nil then
		return nil, `no {PATH_TAG} with {PATH_ATTRIBUTE} = {pathId}`
	end
	const nodes: { Instance } = {}
	for _, child in container:GetDescendants() do
		if child:IsA("BasePart") or child:IsA("Attachment") then
			table.insert(nodes, child)
		end
	end
	table.sort(nodes, function(a: Instance, b: Instance): boolean
		const oa, ob = nodeOrder(a), nodeOrder(b)
		if oa == ob then
			return a.Name < b.Name
		end
		return oa < ob
	end)
	const points: { Vector3 } = {}
	for _, node in nodes do
		const position = nodePosition(node)
		if position then
			table.insert(points, position)
		end
	end
	const path = Motion.Path(points)
	if path == nil then
		return nil, `{PATH_TAG} {pathId} has fewer than 2 nodes`
	end
	return path, nil
end

-- Geometry of one route. Returns nil + problem when the path is missing; missing lines/boxes are listed in
-- `warnings` (the route still runs: a missing line = that stop is skipped).
function Paths.build(route: Route): (Geo?, string?, { string })
	const warnings: { string } = {}
	const path, problem = Paths.polyline(route.Path)
	if path == nil then
		return nil, problem, warnings
	end
	const traffic = Content.Traffic
	const crossing = traffic.Crossing

	-- X-T: Slow profile (SpeedCrossing) and the conflict range
	local slow: { { number } } = {}
	local cross: { number }? = nil
	const zones: { Zone } = {}
	for _, conflict in traffic.Conflicts.List do
		const box = boxPart(conflict.Box)
		if box == nil then
			table.insert(warnings, `no {BOX_TAG} {conflict.Box}`)
			continue
		end
		const stretches = Motion.Stretches(path, box.CFrame, box.Size)
		if #stretches > 0 then
			slow = stretches
			const range = { stretches[1][1], stretches[#stretches][2] }
			cross = range
			table.insert(zones, { Key = conflict.Key, Entry = range[1], From = range[1], To = range[2] })
		end
	end

	-- stop lines of this route
	const lines: { [string]: number } = {}
	for _, stop in route.Stops do
		if lines[stop.Line] ~= nil then
			continue
		end
		const line = findTagged(LINE_TAG, LINE_ATTRIBUTE, stop.Line)
		if line == nil or not line:IsA("BasePart") then
			table.insert(warnings, `no {LINE_TAG} {stop.Line}: stop skipped on {route.Key}`)
			continue
		end
		const dist, offset = Motion.Project(path, line.Position)
		if offset > LINE_OFFSET_MAX then
			table.insert(warnings, `{stop.Line} is {math.floor(offset)} studs off {route.Key}`)
		end
		lines[stop.Line] = dist
		if stop.Kind == "Crosswalk" and dist < crossing.SpawnMinDist then
			table.insert(
				warnings,
				`{route.Key}: {stop.Line} at {math.floor(dist)} studs from the spawn (< {crossing.SpawnMinDist}, DEC-133)`
			)
		end
	end

	const stops: { StopPoint } = {}
	for _, stop in route.Stops do
		const at = lines[stop.Line]
		if at ~= nil then
			table.insert(stops, { Key = stop.Line, Kind = stop.Kind, Ref = stop.Ref, At = at })
		end
	end

	-- crosswalk boxes the path crosses (entry = the route's line for it when it has one)
	for _, crosswalk in traffic.Crosswalks.List do
		const box = boxPart(crosswalk.Box)
		if box == nil then
			table.insert(warnings, `no {BOX_TAG} {crosswalk.Box}`)
			continue
		end
		const range = rangeOf(path, box)
		if range == nil then
			continue
		end
		local entry = range[1]
		local listed = false
		for _, stop in route.Stops do
			if stop.Kind == "Crosswalk" and (stop.Ref == crosswalk.Key or stop.Ref == crosswalk.Linked) then
				listed = true
				const at = lines[stop.Line]
				if at ~= nil and at <= range[1] + 1 then
					entry = at
				end
			end
		end
		table.insert(zones, { Key = crosswalk.Key, Entry = entry, From = range[1], To = range[2] })
		if not listed then
			table.insert(warnings, `{route.Key} crosses {crosswalk.Box} without a stop for it: stops at the box edge`)
			const point: StopPoint = { Key = `{crosswalk.Key}@{route.Key}`, Kind = "Crosswalk", Ref = crosswalk.Key, At = entry }
			table.insert(stops, point)
		end
	end
	table.sort(zones, function(a: Zone, b: Zone): boolean
		return a.From < b.From
	end)
	table.sort(stops, function(a: StopPoint, b: StopPoint): boolean
		return a.At < b.At
	end)
	const stopAt: { [string]: number } = {}
	for _, stop in stops do
		stopAt[stop.Key] = stop.At
	end

	const profile = Motion.Profile(
		path.Length,
		slow,
		traffic.SpeedStraight,
		traffic.SpeedCrossing,
		crossing.PullAway,
		crossing.BrakeDecel
	)
	return {
		Key = route.Key,
		Path = path,
		Profile = profile,
		Lines = lines,
		Cross = cross,
		Zones = zones,
		Stops = stops,
		StopAt = stopAt,
	},
		nil,
		warnings
end

return Paths
