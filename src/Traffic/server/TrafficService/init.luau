--!strict
--[[
	Street traffic and car hits (TASK-104; architecture.md §8, §19.17, T21, T30; network.md §6.2, §13.7; FEAT-033,
	FEAT-036; DEC-087, DEC-095, DEC-103, DEC-130, DEC-133, DEC-197, DEC-198). Run place only. Single writer of the
	Traffic set (record = car slot 1..8); responder of CarHit.

	Servidor decide, client interpola: each car is a 1D body along its route path (Paths, from the map binding) moved
	by the shared Motion from its record { AnchorAt, AnchorDist, StopDist, HeldUntil }. Tick at 10 Hz, only
	arithmetic; the set changes only on events (spawn, stop added, pull away, leave).

	Records (Motion: the anchor is a standstill):
	  * spawn: anchored at rest at distance 0 of the route (entry behind the barriers), StopDist = first stop ahead.
	  * a stop that appears ahead of a MOVING car (crosswalk reservation, queue) is written in place (same anchor), only
	    while it does not change the motion up to now (checked with Motion); it never can be farther than braking
	    distance thanks to the reservation rule (15 studs, DEC-133).
	  * a PARKED car pulls away with a new record anchored where it stands (now), StopDist = its next stop.
	Stops (all at the stop point minus HALF_CAR: the front bumper stops on the line, or before it when the line would
	leave the body on crosswalk stripes; Paths.build, TASK-281):
	  * PARE (route stop Kind Pare, DEC-133): always; after Crossing.PareStop parked, the car leaves only with the X-T
	    box reserved for [entry, exit + ConflictGap]. Ninth cars (routes without PARE) are preferential: the box is
	    given only if no Ninth car can reach it in that window (earliest arrival = its record without stops); a Ninth
	    car does not spawn if it could reach the box inside a reservation. One Juniper car at a time in the box.
	  * crosswalk line: only while an NPC holds the reservation of that crosswalk (or of its Linked one).
	  * queue: a car stops Crossing.CarGap (centre to centre) behind the rest point of the car ahead in its lane, any
	    route or line (TASK-294); a parked follower moves up
	    Crossing.FollowDelay after its slot moves. No stop with the body inside a crosswalk or the X-T box
	    (anti-bloqueio): such a stop moves back before the box.
	  * never for a player (DEC-133, DEC-095): no player position enters any decision.
	Spawn (Content.Traffic.Density by game clock): cap min(row.MaxCars, MaxCars); night rows only DayNight routes;
	Juniper South by direction (NB/SB) every Crossing.JuniperSouthInterval by day, the other routes every
	row.Interval; Crossing.LaneGap per entry lane; not while the entry is occupied; not while a Hold is on; not in
	the phases of NO_TRAFFIC_PHASES. Cars already on the street finish their route.

	Hit (§8.2): CarHit { Car } from the client that owns the character. Valid when the car exists and moves, the
	player is Active, not knocked, not frozen (hidden, cutscene), not immune, not hit by that car yet, and the HRP is
	within Traffic.HitTolerance of the car box at now - ping/2 (also tried at now - ping and now). Valid ->
	CharacterService:Knock(KnockTime, impulse) -> VitalService:SetKnocked -> ItemService:DropHeld(player, "Hit") ->
	immunity until stand-up + ImmuneTime -> LifeEvent Hit. No sanity effect (DEC-103).

	API: Hold(reason, on), IsHeld(), ReserveCrossing(cw, npcId, duration?) -> boolean, ReleaseCrossing(cw, npcId),
	IsReserved(cw), ReservedUntil(cw, npcId), Count(), Status(); dev: DevSpawn(route?), DevClear(), DevHit(player).

	PROVISIONAL (backend-coder, TASK-104; the user is away):
	  (a) every record starts from rest (Motion header): a parked car always gets a new record to pull away, also at
	      the PARE (1 record more than §8.1's pre-set HeldUntil, but a next stop is always expressible);
	  (b) HALF_CAR = 7 studs (stop setback and box padding; kit cars are 12-14 long), HIT_HALF_WIDTH / HIT_HALF_LENGTH;
	  (c) one spawn timer for the non-Juniper-South routes (row.Interval), weighted by Routes[].Weight;
	  (d) a crosswalk reserved by one NPC refuses another NPC until released (+ Cooldown);
	  (e) the 15 studs of the reservation are measured from the car's front bumper;
	  (f) no traffic in Resume, NightEnd, NightLost, Finale and RunEnd (clock rows aside).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Motion = require(ReplicatedStorage.shared.Traffic.Motion)
local Paths = require(script.Paths)
local Modux = require(ServerScriptService.server.Modux)

type Route = typeof(Content.Traffic.Routes.List[1])
type Stop = typeof(Content.Traffic.Routes.List[1].Stops[1])

-- Traffic set record (network.md §6.2)
export type Record = {
	Route: number,
	Look: number,
	AnchorAt: number,
	AnchorDist: number,
	StopDist: number,
	HeldUntil: number,
}

type Car = {
	Id: number,
	Route: Route,
	RouteIndex: number,
	Geo: Paths.Geo,
	Look: number,
	Record: Record,
	Cursor: Motion.Cursor,
	Dist: number,
	Speed: number,
	-- route has a PARE: Juniper arm (not preferential)
	Juniper: boolean,
	-- PARE lines already served
	PareDone: { [string]: boolean },
	-- server time the car parked on its current stop (nil = not parked)
	ParkedAt: number?,
	-- pending pull away of a parked follower (FollowDelay)
	ReleaseAt: number?,
	-- StopDist that failed the in-place check for the current record (retried only when it changes)
	Refused: number?,
	-- UserIds this car already hit (1 hit per car per player, §8.2 d)
	Hits: { [number]: boolean },
}

type Reservation = {
	Npc: number,
	GrantedAt: number,
	ExpiresAt: number,
}

-- X-T box held by a Juniper car: [From, To] server time (To includes ConflictGap)
type BoxHold = {
	Car: number,
	From: number,
	To: number,
}

const TICK_RATE = 10 -- Hz (§8.1)
const SLOTS = 8 -- Traffic record ids 1..8 (network.md §6.2)
const LOOK_MAX = 32 -- Traffic.Look wire range
const HALF_CAR = 7 -- PROVISIONAL (b): stop setback and box padding, studs
const HIT_HALF_WIDTH = 3.5 -- PROVISIONAL (b): car box half width for the hit check
const HIT_HALF_LENGTH = 6.5 -- PROVISIONAL (b): car box half length
const HIT_BELOW = 4 -- HRP this far under the road point still counts
const HIT_ABOVE = 14 -- HRP this far above it still counts (the client already threw the body)
const HIT_RATE = 0.25 -- seconds between CarHit packets of one player
const HEADING_HALF = 4 -- studs each side for the car heading
const LANE_HALF = 3 -- studs off a path still in its lane (lanes are 12 apart; TASK-294)
const SAME_WAY = 0.5 -- heading dot: same direction of travel (TASK-294)
const HORIZON = 60 -- seconds Motion.TimeAt may look ahead
const MATCH = 1e-3 -- studs / studs per second: same motion up to now
const PATH_RETRY = 5 -- seconds between lookups of a route path missing in the map
const MAX_RESERVE = 12 -- seconds: ceiling of a reservation asked longer than Crossing.MaxWait (PROVISIONAL, debugger)
const SPAWN_GROUP_OTHER = "Other"
const NO_TRAFFIC_PHASES = { "Resume", "NightEnd", "NightLost", "Finale", "RunEnd" }

const TRAFFIC = Content.Traffic
const CROSSING = TRAFFIC.Crossing
-- TASK-263 (owner request 2026-10-14, Provisional): the lamps of Content.TrafficLights rule the street too. Axis of each stop line:
-- a crosswalk line by the direction it serves (EB/WB = EW, NB/SB = NS), a PARE line (Juniper arms) NS
const LIGHTS = Content.TrafficLights
const DIRECTION_AXIS: { [string]: "EW" | "NS" } = { EB = "EW", WB = "EW", NB = "NS", SB = "NS" }
const LINE_AXIS: { [string]: "EW" | "NS" } = {}
for _, crosswalk in TRAFFIC.Crosswalks.List do
	-- TASK-281: a crosswalk with no Axis has no lamp (CW-3, mid-block): its lines follow only the reservation
	if crosswalk.Axis == nil then
		continue
	end
	for direction, line in crosswalk.Lines do
		LINE_AXIS[line] = DIRECTION_AXIS[direction]
	end
end
for _, routeRow in TRAFFIC.Routes.List do
	for _, stopRow in routeRow.Stops do
		if stopRow.Kind == "Pare" then
			LINE_AXIS[stopRow.Line] = "NS"
		end
	end
end

-- The light of a stop's axis is not green at server time t (TASK-263): the car must stop at that line
local function redFor(kind: string, key: string, ref: string, t: number): boolean
	if not TRAFFIC.Lights then
		return false
	end
	local axis: ("EW" | "NS")? = LINE_AXIS[key]
	if axis == nil and kind == "Crosswalk" then
		const row = TRAFFIC.Crosswalks.ByKey[ref]
		axis = if row ~= nil then row.Axis else nil
	end
	if axis == nil then
		return false
	end
	const phase = LIGHTS.sample(axis :: "EW" | "NS", t)
	return phase ~= LIGHTS.PHASE_GREEN
end

-- The walk sign of a crosswalk says Walk (TASK-263): its walkers go along the OTHER axis than its street
local function walkFor(cw: string, t: number): boolean
	if not TRAFFIC.Lights then
		return true
	end
	const row = TRAFFIC.Crosswalks.ByKey[cw]
	if row == nil or row.Axis == nil then
		return true
	end
	const walkAxis: "EW" | "NS" = if row.Axis == "EW" then "NS" else "EW"
	return LIGHTS.pedAllowedToCross(walkAxis, t)
end
const EPSILON = Motion.Epsilon

-- The light binds this stop of this car (TASK-281): only an approach line, at or before the route's X-T entry. A line
-- past the box (a turn's exit crosswalk, SL-1N after a southbound pass) follows only the reservation, else a red there
-- would park the car inside the junction.
local function lightRed(geo: Paths.Geo, stop: Paths.StopPoint, t: number): boolean
	const cross = geo.Cross
	if cross == nil or stop.At > cross[1] + EPSILON then
		return false
	end
	return redFor(stop.Kind, stop.Key, stop.Ref, t)
end

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Value as it travels in a Lync f32 (both sides integrate the same numbers)
local function f32(value: number): number
	const packed = string.unpack("<f", string.pack("<f", value)) :: any
	return packed :: number
end

local function between(rng: Random, range: { number }): number
	const low, high = range[1] or 0, range[2] or range[1] or 0
	if high <= low then
		return low
	end
	return low + rng:NextNumber() * (high - low)
end

-- Route entering the T by a Juniper arm (has a PARE): not preferential at the X-T box
local function routeIsJuniper(route: Route): boolean
	for _, stop in route.Stops do
		if stop.Kind == "Pare" then
			return true
		end
	end
	return false
end

local function rootOf(player: Player): BasePart?
	const character = player.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

const TrafficService = Modux.Service("TrafficService", {
	Require = {
		"PlaceService",
		"NetService",
		"RoundService",
		"RunStateService",
		"CharacterService",
		"ItemService",
		"VitalService",
	},
	Priority = 600,
})

function TrafficService:Setup()
	self.Enabled = false :: boolean
	self.Cars = {} :: { [number]: Car }
	self.Geos = {} :: { [string]: Paths.Geo }
	self.GeoRetryAt = {} :: { [string]: number }
	self.Holds = {} :: { [string]: boolean }
	self.Reservations = {} :: { [string]: Reservation }
	self.LastRelease = {} :: { [string]: number }
	self.BoxHolds = {} :: { BoxHold }
	-- spawn group -> next spawn time; entry lane -> last spawn time
	self.NextSpawn = {} :: { [string]: number }
	self.LaneLast = {} :: { [string]: number }
	self.Immune = {} :: { [number]: number }
	self.LastHit = {} :: { [number]: number }
	self.Rng = Random.new() :: Random
	self.Warned = {} :: { [string]: boolean }
end

function TrafficService:WarnOnce(key: string, message: string)
	if self.Warned[key] then
		return
	end
	self.Warned[key] = true
	warn(`[TrafficService] {message}`)
end

-- Reads -----------------------------------------------------------------------------------------------------------

function TrafficService:IsHeld(): boolean
	return next(self.Holds) ~= nil
end

function TrafficService:Count(): number
	local count = 0
	for _ in self.Cars do
		count += 1
	end
	return count
end

-- Crosswalk keys that act together (Linked: CW-2 <-> CW-4 share SL-W / SL-E)
local function groupOf(cw: string): { string }
	const row = TRAFFIC.Crosswalks.ByKey[cw]
	if row and row.Linked then
		return { cw, row.Linked }
	end
	return { cw }
end

function TrafficService:IsReserved(cw: string): boolean
	for _, key in groupOf(cw) do
		if self.Reservations[key] ~= nil then
			return true
		end
	end
	return false
end

-- Server time the reservation of `cw` (or of its Linked one) held by `npcId` ends, nil when it holds none
function TrafficService:ReservedUntil(cw: string, npcId: number): number?
	for _, key in groupOf(cw) do
		const current = self.Reservations[key]
		if current ~= nil and current.Npc == npcId then
			return current.ExpiresAt
		end
	end
	return nil
end

-- Geometry of a route (cached; nil while the binding is missing, retried every PATH_RETRY s)
function TrafficService:GeoOf(route: Route): Paths.Geo?
	const cached = self.Geos[route.Key]
	if cached then
		return cached
	end
	const t = now()
	const retry = self.GeoRetryAt[route.Key]
	if retry and t < retry then
		return nil
	end
	const geo, problem, warnings = Paths.build(route, HALF_CAR)
	for _, message in warnings do
		self:WarnOnce(`geo:{message}`, message)
	end
	if geo == nil then
		self:WarnOnce(`path:{route.Key}`, `{problem or "no path"}: route {route.Key} has no cars`)
		self.GeoRetryAt[route.Key] = t + PATH_RETRY
		return nil
	end
	self.Geos[route.Key] = geo
	return geo
end

-- Stops -----------------------------------------------------------------------------------------------------------

-- Nearest stop ahead before queueing: (position, stop key) or nil. A stop where the car stands counts (it holds it).
function TrafficService:RawStop(car: Car): (number?, string?)
	const t = now()
	for _, stop in car.Geo.Stops do
		local binds = false
		-- TASK-263: a light that is not green for the stop's axis binds it too
		const red = lightRed(car.Geo, stop, t)
		if stop.Kind == "Pare" then
			binds = not car.PareDone[stop.Key] or red
		else
			binds = self:IsReserved(stop.Ref) or red
		end
		-- TASK-281: stop.At is already the hold point off the stripes (Paths.build), for every kind of stop
		const at = stop.At - HALF_CAR
		if binds and at >= car.Dist - EPSILON then
			return at, stop.Key
		end
	end
	return nil, nil
end

-- Moves a stop back so the body never stands inside a crosswalk or the X-T box (anti-bloqueio, §8.1)
local function clearOfZones(car: Car, at: number): number
	local stop = at
	for _ = 1, #car.Geo.Zones + 1 do
		local moved = false
		for _, zone in car.Geo.Zones do
			const entry = zone.Entry
			if stop + HALF_CAR > entry + EPSILON and stop - HALF_CAR < zone.To and car.Dist <= entry - HALF_CAR + EPSILON then
				stop = entry - HALF_CAR
				moved = true
			end
		end
		if not moved then
			break
		end
	end
	return stop
end

-- Where the car must stop now (0 = nowhere): nearest stop, or CarGap behind the rest point of the car physically ahead
-- in its lane (TASK-294), kept out of the boxes, never behind the car. The queue used to count only cars heading to
-- the SAME line, so on Juniper South a car held at SL-1S (hold 84) stood inside the one parked at the PARE of SL-S
-- (hold 87.5, 3.5 studs on): the leader is now found by position (any route, any line) and followed by its StopDist.
function TrafficService:DesiredStop(car: Car): number
	const raw = self:RawStop(car)
	local stop = raw or math.huge
	local followed = false
	const path = car.Geo.Path
	for _, other in self.Cars do
		if other == car or other.Record.StopDist <= 0 then
			continue -- a car running free (no stop ahead) never slows a follower down: same profile, spawned apart
		end
		-- the other car is ahead of this one, in its lane, going the same way
		const here = Motion.PointAt(other.Geo.Path, other.Dist)
		const ahead, offset = Motion.Project(path, here)
		if offset > LANE_HALF or ahead <= car.Dist + EPSILON then
			continue
		end
		const mine = Motion.Heading(path, ahead, HEADING_HALF)
		const theirs = Motion.Heading(other.Geo.Path, other.Dist, HEADING_HALF)
		if mine:Dot(theirs) < SAME_WAY then
			continue
		end
		-- where it will be at rest, seen from this path (it may leave the lane before: then it does not count)
		const rest, restOffset = Motion.Project(path, Motion.PointAt(other.Geo.Path, other.Record.StopDist))
		if restOffset > LANE_HALF or rest < ahead - EPSILON then
			continue
		end
		const slot = rest - CROSSING.CarGap
		if slot < stop then
			stop = slot
			followed = true
		end
	end
	if stop == math.huge then
		return 0
	end
	-- a line stop is legal by itself (the map puts it before its box); a queue slot may fall inside a box
	if followed then
		stop = clearOfZones(car, stop)
	end
	if stop < car.Dist then
		stop = car.Dist
	end
	return math.max(stop, EPSILON)
end

-- True when the car is parked at one of its stop points (not at a queue slot)
local function atLine(car: Car): boolean
	for _, stop in car.Geo.Stops do
		if math.abs(stop.At - HALF_CAR - car.Dist) <= EPSILON then
			return true
		end
	end
	return false
end

-- The PARE line the car is parked on, if it still has to be served
local function pareHere(car: Car): string?
	for _, stop in car.Geo.Stops do
		if stop.Kind == "Pare" and not car.PareDone[stop.Key] then
			if math.abs(stop.At - HALF_CAR - car.Dist) <= EPSILON then
				return stop.Key
			end
		end
	end
	return nil
end

-- Records ---------------------------------------------------------------------------------------------------------

function TrafficService:Publish(car: Car, added: boolean)
	if not self.Dependencies.NetService:IsRunning() then
		return
	end
	const record = table.clone(car.Record)
	if added then
		self.Libs.Net.Traffic:add(car.Id, record)
	else
		self.Libs.Net.Traffic:update(car.Id, record)
	end
end

function TrafficService:SetRecord(car: Car, record: Record, t: number)
	car.Record = record
	car.Cursor = Motion.Cursor(car.Geo.Profile, record)
	car.Dist, car.Speed = Motion.Sample(car.Geo.Profile, record, car.Cursor, t)
	car.ParkedAt = nil
	car.ReleaseAt = nil
	car.Refused = nil
	self:Publish(car, false)
end

-- New record anchored where the car stands (it must be at rest), heading to `stop`
function TrafficService:PullAway(car: Car, stop: number, t: number)
	self:SetRecord(car, {
		Route = car.RouteIndex,
		Look = car.Look,
		AnchorAt = t,
		AnchorDist = f32(car.Dist),
		StopDist = f32(stop),
		HeldUntil = 0,
	}, t)
end

-- Same anchor, new StopDist, only when the motion up to `t` does not change (a moving car)
function TrafficService:Restop(car: Car, stop: number, t: number): boolean
	const candidate = table.clone(car.Record)
	candidate.StopDist = f32(stop)
	candidate.HeldUntil = 0
	const s, u = Motion.At(car.Geo.Profile, candidate, t)
	if math.abs(s - car.Dist) > MATCH or math.abs(u - car.Speed) > MATCH then
		return false
	end
	self:SetRecord(car, candidate, t)
	return true
end

-- X-T box (PARE, Ninth priority) ------------------------------------------------------------------------------------

-- Time window [enter, leave] of the X-T box for a record, or nil if it does not cross it / would stop inside
local function boxWindow(car: Car, record: Record, t: number): (number?, number?)
	const cross = car.Geo.Cross
	if cross == nil then
		return nil, nil
	end
	const profile = car.Geo.Profile
	const enter = Motion.TimeAt(profile, record, cross[1] - HALF_CAR, t + HORIZON)
	const leave = Motion.TimeAt(profile, record, cross[2] + HALF_CAR, t + HORIZON)
	return enter, leave
end

-- Earliest time a Ninth car can reach the X-T box (its record without stops), nil when it is past the box
local function earliestEntry(car: Car, t: number): number?
	const cross = car.Geo.Cross
	if cross == nil or car.Dist - HALF_CAR > cross[2] then
		return nil
	end
	const free = table.clone(car.Record)
	free.StopDist = 0
	free.HeldUntil = 0
	return Motion.TimeAt(car.Geo.Profile, free, cross[1] - HALF_CAR, t + HORIZON) or math.huge
end

-- The X-T box is free for [from, to] (to already has ConflictGap)
function TrafficService:BoxFree(from: number, to: number, t: number, except: Car?): boolean
	for _, hold in self.BoxHolds do
		if from < hold.To and hold.From < to then
			return false
		end
	end
	for _, other in self.Cars do
		if other == except or other.Juniper then
			continue
		end
		const entry = earliestEntry(other, t)
		if entry ~= nil and entry < to then
			return false
		end
	end
	return true
end

-- A car parked on its PARE for PareStop asks for the box; on success it pulls away (returns true)
function TrafficService:TryPare(car: Car, line: string, t: number): boolean
	car.PareDone[line] = true
	const stop = self:DesiredStop(car)
	if stop > 0 and stop <= car.Dist + EPSILON then
		-- no room past the box (queue ahead): wait on the line
		car.PareDone[line] = nil
		return false
	end
	const candidate: Record = {
		Route = car.RouteIndex,
		Look = car.Look,
		AnchorAt = t,
		AnchorDist = f32(car.Dist),
		StopDist = f32(stop),
		HeldUntil = 0,
	}
	const enter, leave = boxWindow(car, candidate, t)
	if car.Geo.Cross ~= nil then
		if enter == nil or leave == nil then
			car.PareDone[line] = nil
			return false
		end
		const to = leave + TRAFFIC.ConflictGap
		if not self:BoxFree(enter, to, t, car) then
			car.PareDone[line] = nil
			return false
		end
		table.insert(self.BoxHolds, { Car = car.Id, From = enter, To = to })
	end
	self:SetRecord(car, candidate, t)
	return true
end

-- Crosswalk reservation (T30; NpcService / PedestrianService, no network) -------------------------------------------

-- Granted only with no car whose front is within ReserveRadius of a line of the crosswalk (both directions) nor with
-- its body inside the crosswalk, and Cooldown s after the last release. Cars that still have to cross stop on the line.
-- `duration` (s): how long the holder needs the road; default and floor Crossing.MaxWait, ceiling MAX_RESERVE (a
-- passer-by at walking speed needs more than MaxWait on the wide Ninth crosswalks).
function TrafficService:ReserveCrossing(cw: string, npcId: number, duration: number?): boolean
	const row = TRAFFIC.Crosswalks.ByKey[cw]
	if row == nil then
		self:WarnOnce(`cw:{cw}`, `ReserveCrossing: unknown crosswalk {cw}`)
		return false
	end
	const t = now()
	const group = groupOf(cw)
	for _, key in group do
		const current = self.Reservations[key]
		if current ~= nil then
			return current.Npc == npcId
		end
		const last = self.LastRelease[key]
		if last ~= nil and t - last < CROSSING.Cooldown then
			return false
		end
	end
	-- TASK-263: walkers start across only on Walk (a refusal makes them wait on the curb and ask again)
	if not walkFor(cw, t) then
		return false
	end
	if not self.Enabled then
		return true
	end
	const radius = CROSSING.ReserveRadius
	for _, car in self.Cars do
		for _, stop in car.Geo.Stops do
			if stop.Kind ~= "Crosswalk" or table.find(group, stop.Ref) == nil then
				continue
			end
			const line = stop.At
			-- TASK-263: a car held by its red light, at rest behind the line or able to brake before it, does not block the walk
			if lightRed(car.Geo, stop, t) and car.Dist + HALF_CAR <= line + EPSILON then
				const braking = car.Speed * car.Speed / (2 * CROSSING.BrakeDecel) + car.Speed * Motion.DT
				if car.Speed == 0 or line - (car.Dist + HALF_CAR) >= braking then
					continue
				end
			end
			local out = line + radius
			for _, zone in car.Geo.Zones do
				if table.find(group, zone.Key) ~= nil then
					out = math.max(out, zone.To)
				end
			end
			const front = car.Dist + HALF_CAR
			if front > line - radius and car.Dist - HALF_CAR < out then
				return false
			end
		end
	end
	local hold = CROSSING.MaxWait
	if type(duration) == "number" and duration == duration then
		hold = math.clamp(duration, CROSSING.MaxWait, math.max(MAX_RESERVE, CROSSING.MaxWait))
	end
	self.Reservations[cw] = { Npc = npcId, GrantedAt = t, ExpiresAt = t + hold }
	self:Reconcile(t)
	return true
end

function TrafficService:ReleaseCrossing(cw: string, npcId: number)
	for _, key in groupOf(cw) do
		const current = self.Reservations[key]
		if current ~= nil and current.Npc == npcId then
			self:EndReservation(key, now())
			return
		end
	end
end

function TrafficService:EndReservation(key: string, t: number)
	self.Reservations[key] = nil
	for _, member in groupOf(key) do
		self.LastRelease[member] = t
	end
	if self.Enabled then
		self:Reconcile(t)
	end
end

-- Hold (§19.17) -----------------------------------------------------------------------------------------------------

-- No car spawns while any reason is on (anm_008, anm_010, cutscene, ambulance). Cars on the street finish.
function TrafficService:Hold(reason: string, on: boolean)
	if type(reason) ~= "string" or reason == "" then
		return
	end
	if table.find(TRAFFIC.HoldReasons, reason) == nil then
		self:WarnOnce(`hold:{reason}`, `Hold: reason "{reason}" is not in Content.Traffic.HoldReasons (kept anyway)`)
	end
	self.Holds[reason] = if on then true else nil
end

-- Cars ------------------------------------------------------------------------------------------------------------

function TrafficService:FreeSlot(): number?
	for id = 1, SLOTS do
		if self.Cars[id] == nil then
			return id
		end
	end
	return nil
end

function TrafficService:Remove(car: Car)
	self.Cars[car.Id] = nil
	for i = #self.BoxHolds, 1, -1 do
		if self.BoxHolds[i].Car == car.Id then
			table.remove(self.BoxHolds, i)
		end
	end
	if self.Dependencies.NetService:IsRunning() then
		self.Libs.Net.Traffic:remove(car.Id)
	end
end

-- The route can take a new car now (lane gap, entry free, Ninth car clear of the X-T reservations)
function TrafficService:CanSpawn(route: Route, geo: Paths.Geo, t: number): boolean
	const last = self.LaneLast[route.Lane]
	if last ~= nil and t - last < CROSSING.LaneGap then
		return false
	end
	const clear = CROSSING.CarGap + 2 * HALF_CAR
	for _, car in self.Cars do
		if car.Route.Lane == route.Lane and car.Dist < clear then
			return false
		end
	end
	if not routeIsJuniper(route) and geo.Cross ~= nil and #self.BoxHolds > 0 then
		const fresh: Record = { Route = 0, Look = 1, AnchorAt = t, AnchorDist = 0, StopDist = 0, HeldUntil = 0 }
		const entry = Motion.TimeAt(geo.Profile, fresh, geo.Cross[1] - HALF_CAR, t + HORIZON) or math.huge
		for _, hold in self.BoxHolds do
			if entry < hold.To then
				return false
			end
		end
	end
	return true
end

function TrafficService:Spawn(route: Route, t: number): Car?
	const id = self:FreeSlot()
	const geo = self:GeoOf(route)
	if id == nil or geo == nil then
		return nil
	end
	const looks = math.min(#TRAFFIC.Looks.Shapes * #TRAFFIC.Looks.Paints, LOOK_MAX)
	const record: Record = {
		Route = TRAFFIC.Routes.IndexOf[route.Key],
		Look = self.Rng:NextInteger(1, math.max(looks, 1)),
		AnchorAt = t,
		AnchorDist = 0,
		StopDist = 0,
		HeldUntil = 0,
	}
	const car: Car = {
		Id = id,
		Route = route,
		RouteIndex = record.Route,
		Geo = geo,
		Look = record.Look,
		Record = record,
		Cursor = Motion.Cursor(geo.Profile, record),
		Dist = 0,
		Speed = 0,
		Juniper = routeIsJuniper(route),
		PareDone = {},
		ParkedAt = nil,
		ReleaseAt = nil,
		Refused = nil,
		Hits = {},
	}
	self.Cars[id] = car
	record.StopDist = f32(self:DesiredStop(car))
	if record.StopDist <= EPSILON then
		record.StopDist = 0
	end
	car.Cursor = Motion.Cursor(geo.Profile, record)
	self.LaneLast[route.Lane] = t
	self:Publish(car, true)
	return car
end

-- Picks a route of the group by Weight among those that can spawn now
function TrafficService:PickRoute(group: string, night: boolean, t: number): Route?
	local total = 0
	const pool: { Route } = {}
	for _, route in TRAFFIC.Routes.List do
		const inGroup = if group == SPAWN_GROUP_OTHER then route.JuniperSouth == nil else route.JuniperSouth == group
		if not inGroup or (night and route.Shift ~= "DayNight") or route.Weight <= 0 then
			continue
		end
		const geo = self:GeoOf(route)
		if geo == nil or not self:CanSpawn(route, geo, t) then
			continue
		end
		table.insert(pool, route)
		total += route.Weight
	end
	if total <= 0 then
		return nil
	end
	local roll = self.Rng:NextNumber() * total
	for _, route in pool do
		roll -= route.Weight
		if roll <= 0 then
			return route
		end
	end
	return pool[#pool]
end

function TrafficService:SpawnPhaseOk(): boolean
	const round = self.Dependencies.RoundService
	return round:IsStarted() and table.find(NO_TRAFFIC_PHASES, round:GetPhase()) == nil
end

function TrafficService:TrySpawn(t: number)
	if self:IsHeld() or not self:SpawnPhaseOk() then
		return
	end
	const row = TRAFFIC.DensityAt(self.Dependencies.RoundService:Minutes())
	if row == nil or row.MaxCars <= 0 then
		return
	end
	const cap = math.min(row.MaxCars, TRAFFIC.MaxCars, SLOTS)
	const groups: { { Key: string, Interval: { number } } } = {}
	if not row.Night then
		table.insert(groups, { Key = "NB", Interval = CROSSING.JuniperSouthInterval })
		table.insert(groups, { Key = "SB", Interval = CROSSING.JuniperSouthInterval })
	end
	table.insert(groups, { Key = SPAWN_GROUP_OTHER, Interval = row.Interval })
	for _, group in groups do
		if self:Count() >= cap then
			return
		end
		const nextAt = self.NextSpawn[group.Key] or 0
		if t < nextAt then
			continue
		end
		const route = self:PickRoute(group.Key, row.Night, t)
		if route ~= nil and self:Spawn(route, t) ~= nil then
			self.NextSpawn[group.Key] = t + between(self.Rng, group.Interval)
		end
	end
end

-- Tick ------------------------------------------------------------------------------------------------------------

-- Brings every record in line with the stops of now (in place, pull away, PARE)
function TrafficService:Reconcile(t: number)
	-- every car at `t` first: the stops of one car read the others (queue)
	for _, car in self.Cars do
		car.Dist, car.Speed = Motion.Sample(car.Geo.Profile, car.Record, car.Cursor, t)
	end
	for _, car in self.Cars do
		const record = car.Record
		const parked = car.Speed == 0
			and record.StopDist > 0
			and math.abs(car.Dist - record.StopDist) <= EPSILON
			and Motion.Holding(record, car.Dist, t)
		if parked then
			if car.ParkedAt == nil then
				car.ParkedAt = Motion.TimeAt(car.Geo.Profile, record, record.StopDist, t) or t
			end
			const pare = pareHere(car)
			if pare ~= nil then
				if t >= (car.ParkedAt :: number) + CROSSING.PareStop then
					self:TryPare(car, pare, t)
				end
				continue
			end
			const stop = self:DesiredStop(car)
			if stop > car.Dist + EPSILON or stop <= EPSILON then
				if car.ReleaseAt == nil then
					car.ReleaseAt = if atLine(car) then t else t + CROSSING.FollowDelay
				end
				if t >= (car.ReleaseAt :: number) then
					self:PullAway(car, if stop <= EPSILON then 0 else stop, t)
				end
			else
				car.ReleaseAt = nil
			end
			continue
		end
		car.ParkedAt = nil
		car.ReleaseAt = nil
		local stop = self:DesiredStop(car)
		if stop <= EPSILON then
			stop = 0
		end
		if math.abs(stop - record.StopDist) > MATCH and car.Refused ~= stop then
			-- a closer stop inside the braking distance cannot be taken in place (no simulation needed)
			const braking = car.Speed * car.Speed / (2 * CROSSING.BrakeDecel) + car.Speed * Motion.DT
			const reachable = stop <= 0
				or stop - car.Dist >= braking
				or (record.StopDist > 0 and stop > record.StopDist)
			if not reachable or not self:Restop(car, stop, t) then
				car.Refused = stop
			end
		end
	end
end

function TrafficService:Step()
	const t = now()
	-- reservations past their ExpiresAt end by themselves (NpcService pivots its NPC off the road, §8.1)
	for key, reservation in self.Reservations do
		if t >= reservation.ExpiresAt then
			self:EndReservation(key, t)
		end
	end
	for i = #self.BoxHolds, 1, -1 do
		if self.BoxHolds[i].To < t then
			table.remove(self.BoxHolds, i)
		end
	end
	for _, car in self.Cars do
		car.Dist, car.Speed = Motion.Sample(car.Geo.Profile, car.Record, car.Cursor, t)
		if car.Dist >= car.Geo.Path.Length then
			self:Remove(car)
		end
	end
	self:Reconcile(t)
	self:TrySpawn(t)
end

-- Hit (§8.2) ------------------------------------------------------------------------------------------------------

-- Horizontal distance from `point` to the car box at time `at`, and the car speed and heading then
local function carDistance(car: Car, point: Vector3, at: number): (number, number, Vector3)
	const geo = car.Geo
	const s, u = Motion.At(geo.Profile, car.Record, at)
	if s < 0 or s > geo.Path.Length then
		return math.huge, u, Vector3.zAxis
	end
	const base = Motion.PointAt(geo.Path, s)
	const heading = Motion.Heading(geo.Path, s, HEADING_HALF)
	const offset = point - base
	if offset.Y < -HIT_BELOW or offset.Y > HIT_ABOVE then
		return math.huge, u, heading
	end
	const right = Vector3.new(-heading.Z, 0, heading.X)
	const along = math.max(math.abs(offset:Dot(heading)) - HIT_HALF_LENGTH, 0)
	const side = math.max(math.abs(offset:Dot(right)) - HIT_HALF_WIDTH, 0)
	return math.sqrt(along * along + side * side), u, heading
end

function TrafficService:OnCarHit(player: Player, id: number)
	const t = now()
	const userId = player.UserId
	const last = self.LastHit[userId]
	if last ~= nil and t - last < HIT_RATE then
		return
	end
	self.LastHit[userId] = t
	const car = self.Cars[id]
	if car == nil or car.Hits[userId] then
		return
	end
	if (self.Immune[userId] or 0) > t then
		return
	end
	const character = self.Dependencies.CharacterService
	if
		not self.Dependencies.VitalService:IsActive(player)
		or character:IsKnocked(player)
		or character:IsFrozen(player)
	then
		return
	end
	const root = rootOf(player)
	if root == nil then
		return
	end
	const ping = math.clamp(player:GetNetworkPing(), 0, 1)
	local best, speed, heading = math.huge, 0, Vector3.zAxis
	for _, at in { t - ping / 2, t - ping, t } do
		const d, u, h = carDistance(car, root.Position, at)
		if d < best then
			best, speed, heading = d, u, h
		end
	end
	if best > TRAFFIC.HitTolerance or speed < TRAFFIC.HitMinSpeed * 0.5 then
		return
	end
	const impulse = heading * TRAFFIC.ImpulseForward + Vector3.yAxis * TRAFFIC.ImpulseUp
	self:ApplyHit(player, car, impulse)
end

-- Knock -> SetKnocked -> DropHeld -> immunity -> LifeEvent Hit (§19.17). False when the body cannot be knocked.
function TrafficService:ApplyHit(player: Player, car: Car?, impulse: Vector3): boolean
	const standUp = self.Dependencies.CharacterService:Knock(player, TRAFFIC.KnockTime, impulse)
	if standUp == nil then
		return false
	end
	const userId = player.UserId
	if car ~= nil then
		car.Hits[userId] = true
	end
	self.Dependencies.VitalService:SetKnocked(player, standUp)
	self.Dependencies.ItemService:DropHeld(player, "Hit")
	self.Immune[userId] = standUp + TRAFFIC.ImmuneTime
	self.Dependencies.VitalService:FireLife(userId, "Hit")
	return true
end

-- Dev (DevService/Commands/Traffic.luau) ------------------------------------------------------------------------

function TrafficService:Status(): string
	const parts: { string } = {}
	const holds: { string } = {}
	for reason in self.Holds do
		table.insert(holds, reason)
	end
	table.insert(parts, `cars {self:Count()}`)
	table.insert(parts, `hold {if #holds > 0 then table.concat(holds, ",") else "none"}`)
	if self.Enabled and self.Dependencies.RoundService:IsStarted() then
		const row = TRAFFIC.DensityAt(self.Dependencies.RoundService:Minutes())
		table.insert(parts, `density {if row then row.MaxCars else 0}`)
	end
	for id = 1, SLOTS do
		const car = self.Cars[id]
		if car then
			table.insert(
				parts,
				string.format(
					"#%d %s %.0f/%.0f v%.0f stop %.0f",
					id,
					car.Route.Key,
					car.Dist,
					car.Geo.Path.Length,
					car.Speed,
					car.Record.StopDist
				)
			)
		end
	end
	for key, reservation in self.Reservations do
		table.insert(parts, string.format("%s npc %s %.1fs", key, tostring(reservation.Npc), reservation.ExpiresAt - now()))
	end
	return table.concat(parts, "; ")
end

-- Spawns a car now on `routeKey` (or a random route), ignoring timers, density and holds
function TrafficService:DevSpawn(routeKey: string?): string
	if not self.Enabled then
		error("traffic runs only in the Run place", 0)
	end
	const t = now()
	local route: Route? = nil
	if routeKey ~= nil then
		route = TRAFFIC.Routes.ByKey[routeKey]
		if route == nil then
			error(`unknown route {routeKey}`, 0)
		end
	else
		const list = TRAFFIC.Routes.List
		route = list[self.Rng:NextInteger(1, #list)]
	end
	const chosen = route :: Route
	if self:GeoOf(chosen) == nil then
		error(`route {chosen.Key} has no TrafficPath in the map`, 0)
	end
	const car = self:Spawn(chosen, t)
	if car == nil then
		error("no free car slot", 0)
	end
	return `car #{car.Id} on {chosen.Key} (look {car.Look})`
end

function TrafficService:DevClear(): number
	local count = 0
	for _, car in self.Cars do
		self:Remove(car)
		count += 1
	end
	return count
end

-- Knocks `player` as a car hit from behind (no car)
function TrafficService:DevHit(player: Player): boolean
	const root = rootOf(player)
	const forward = if root then root.CFrame.LookVector else Vector3.zAxis
	const flat = Vector3.new(forward.X, 0, forward.Z)
	const heading = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
	return self:ApplyHit(player, nil, heading * TRAFFIC.ImpulseForward + Vector3.yAxis * TRAFFIC.ImpulseUp)
end

-- Lifecycle -------------------------------------------------------------------------------------------------------

TrafficService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self.Enabled = true

	self.Libs.Net.CarHit:onServer(function(value, player: Player)
		if type(value) == "table" and type(value.Car) == "number" then
			self:OnCarHit(player, value.Car)
		end
	end)

	-- RoundService (750) created its signals in its own OnInit, before ours
	self.Dependencies.RoundService.ShiftStarted:Connect(function()
		const t = now()
		for key in self.NextSpawn do
			self.NextSpawn[key] = t
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		self.Immune[player.UserId] = nil
		self.LastHit[player.UserId] = nil
	end)
end)

TrafficService:OnTick(function(self)
	if self.Enabled then
		self:Step()
	end
end, TICK_RATE)

return TrafficService
