--!strict
--[[
	Passers-by (TASK-122; architecture.md §19.17, T46; network.md §13.7; DEC-183; Q-162 a, PROVISIONAL). Run place only.
	Single writer of the Pedestrians set (record = slot 1..WalkPaths.Rules.Slots).

	No Humanoid on the server and outside the cap of 12 (Flow.MaxNpc, DEC-045): each passer-by is a 1D body along a
	Content.WalkPaths row (shared WalkGeo) moved by the shared Motion from its record { AnchorAt, AnchorDist, StopDist,
	HeldUntil } + Speed. Each client builds a local rig and walks it (PedestrianController, TASK-123). Tick at 10 Hz,
	only arithmetic; the set changes only on events (spawn, pull away from a stop, leave).

	How many: Flow.DayWalkers by day, Flow.NightWalkers at night, drawn at every ShiftStarted; 0 while
	AnomalyService:IsTension() (rua deserta). Paths: WalkPaths rows of the shift (Day: Day/Any; Night: Night/Any),
	by Weight. Look: species with Pedestrian = true (never a reserved one) + civil outfit of CustomerTypes.pedestrian.

	Records (Motion: the anchor is a standstill):
	  * spawn: at rest at distance 0 of the path (through paths start out of sight); the first fill of a run puts the
	    walkers at random distances off the crosswalks. StopDist = the next stop.
	  * stops: the near curb of every crosswalk of the path (wait for TrafficService:ReserveCrossing, §8.1); on a Loop
	    path without crosswalks, the lap seam (PAUSE s), so a loop record never runs for long.
	  * parked on a crosswalk curb: reserve; granted -> new record anchored there, StopDist = next stop. A walker of
	    this service may cross under a reservation another of ours holds on the same crosswalk when it reaches the far
	    curb before the reservation expires (people cross together). The reservation is released when the last of
	    them is off the road. Failsafe (§8.1): still on the road when it expires -> new record at the far curb (logged).
	  * Loop distances are folded into one lap on every new record.

	API: Count(), Target(), Status(); dev: DevSpawn(pathKey?), DevClear(), DevAdopt(). Reservation id of a walker =
	-slot (never an NpcId of NpcService, which are 1..65535).

	Adoption (TASK-163; user request 2026-10-11; CustomerService/Adopt.luau decides when, PROVISIONAL): registered
	with CustomerService:SetAdopter in OnInit (T42: this service requires CustomerService, never the other way).
	  * Pick: nearest walker within the radius that is not on a crosswalk nor near the end of its path, whose look
	    the customer side accepts; it is "noticed": StopDist moves to where it can brake now (anchor kept, so the
	    past of the record is unchanged on every client), and it never asks for a crosswalk meanwhile;
	  * Peek / Take: look, floor point, heading and the nearer node of its sidewalk; Take removes the record (the
	    customer rig appears there in the same frame). The slot refills from a path start like any leaving walker;
	  * Release: walks on from where it stands.

	PROVISIONAL (backend-coder, TASK-122; the user is away):
	  (a) tension removes every walker at once (the client may fade them, TASK-123); spawns resume after it, one by
	      one from the path starts;
	  (b) shift change: walkers on paths of the other shift leave at once; extra walkers (new target lower) leave at the
	      end of their path (Loop: at the lap seam);
	  (c) only the first fill of a run is at random distances; later walkers enter from the path start every
	      SPAWN_GAP s;
	  (d) no walker in the phases of NO_PHASES (same as the traffic); the draws use an unseeded Random (cosmetic);
	  (e) WalkGeo.Accel / Brake and PAUSE are constants until Content.WalkPaths.Rules has them (architect).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Motion = require(ReplicatedStorage.shared.Traffic.Motion)
local WalkGeo = require(ReplicatedStorage.shared.Pedestrian.WalkGeo)
local Modux = require(ServerScriptService.server.Modux)

type WalkPath = typeof(Content.WalkPaths.List[1])

-- Pedestrians set record (network.md §13.7)
export type Record = {
	Path: number,
	Species: string,
	Outfit: string,
	Speed: number,
	AnchorAt: number,
	AnchorDist: number,
	StopDist: number,
	HeldUntil: number,
}

type Stop = {
	At: number, -- absolute distance of the record
	Kind: "Crossing" | "Pause" | "Hold", -- Hold: behind another walker (spacing), not a place of the path
	Crosswalk: string?,
	Exit: number, -- Crossing: far curb (absolute); Pause: = At
	-- Crossing: the curb itself; At may sit up to WAIT_SLOTS * WAIT_GAP behind it, in the waiting line (TASK-321)
	Curb: number?,
}

type Walker = {
	Id: number,
	Npc: number, -- reservation id (-slot)
	Geo: WalkGeo.Geo,
	Profile: Motion.Profile,
	Record: Record,
	Cursor: Motion.Cursor,
	Dist: number,
	Speed: number,
	Lane: number, -- WalkGeo.LaneOfSlot(Id): lateral lane on the crosswalks (same rule on every client)
	Stop: Stop?, -- stop the current record heads to
	ParkedAt: number?,
	-- on the road under a reservation: crosswalk and far curb (absolute)
	Crossing: { Crosswalk: string, Exit: number }?,
	-- leaving: Loop -> removed at this distance (lap seam)
	Leaving: boolean,
	LapEnd: number?,
	-- braking / standing for the customer side (adoption): no crosswalk request until released or taken
	Noticed: boolean,
	-- server time the walker started braking behind another one (Stop.Kind "Hold"); nil = not holding
	HoldAt: number?,
}

-- What the customer side reads of a noticed walker (CustomerService/Adopt.luau Handoff)
export type Handoff = { Species: string, Outfit: string, Position: Vector3, Heading: Vector3, Node: string }

-- One reservation held by this service on a crosswalk (key = crosswalk)
type Hold = {
	Holder: number, -- reservation id given to TrafficService
	Expires: number, -- server time: GrantedAt + the duration asked (mirror of TrafficService, >= Crossing.MaxWait)
	Riders: { [number]: boolean }, -- walker slots on the road under it
}

const TICK_RATE = 10 -- Hz
const NO_PHASES = { "Resume", "NightEnd", "NightLost", "Finale", "RunEnd" } -- PROVISIONAL (d)
const SPAWN_GAP = { 2, 5 } -- seconds between walkers entering from a path start, PROVISIONAL (c)
const SPACING = 4 -- studs: a path start must be this clear to take a new walker
const PAUSE = 1 -- seconds at the seam of a Loop path without crosswalks, PROVISIONAL (e)
const RIDE_MARGIN = 0.5 -- seconds: a rider must be off the road this long before the reservation expires
const PATH_RETRY = 5 -- seconds between lookups of a path whose nodes are missing
const HORIZON = 30 -- seconds Motion.TimeAt may look ahead
const MIN_STOP = 0.1 -- studs: StopDist 0 means "no stop", so a curb at distance 0 stops here
const NOTICE_ROOM = 0.25 -- studs added to the braking distance of a noticed walker
const END_ROOM = 6 -- studs: a walker this close to the end of a through path is never picked
-- Spacing (playtest 2026-10-11: walkers stacked on the same curb / walking inside each other), PROVISIONAL:
-- a walking passer-by brakes when another one stands or walks the same way less than HOLD_GAP studs (+ its braking
-- distance) ahead within HOLD_LANE studs of its line, and walks on once the way is clear (or after HOLD_MAX s).
-- World space, so walkers of different paths sharing a sidewalk or a curb keep apart too. Oncoming walkers pass.
const HOLD_GAP = 3 -- studs between two walkers in line (2.5 -> 3, TASK-321: the owner saw them glued together)
const HOLD_LANE = 1.5 -- studs off the line that still count as "in the way"
const HOLD_SAME = 0.3 -- min dot of the two headings: same way (perpendicular and oncoming walkers pass)
const HOLD_MIN = 0.3 -- studs: closer than this along the line is "beside", not ahead
const HOLD_MAX = 10 -- seconds: safety, a hold never lasts longer (one stud later it brakes again if still blocked)
const HOLD_SPEED = 0.5 -- studs/s: slower than this is standing (no new hold)
-- Lanes on crosswalks (playtest 2026-10-11: walkers crossed through each other on the same line), PROVISIONAL:
-- the slot decides the lane (WalkGeo.LaneOfSlot; FreeSlot gives the least used lane), the lane is a lateral offset on
-- the road part. A walker only steps on the road when no rider is closer than CROSS_GAP studs (centre to centre) to
-- its place, and walks no faster than the rider ahead of it in the same lane.
const CROSS_GAP = 1.6 -- studs: minimum centre-to-centre separation on a crossing
const CROSS_LOOK = 14 -- studs: a rider this far ahead in the same lane caps the speed of the one entering behind it
const SPAWN_CLEAR = 3.2 -- studs: a path start must be this far (world space) from every walker to take a new one
const PREFIX = "[PedestrianService]"

const EPSILON = Motion.Epsilon
const RULES = Content.WalkPaths.Rules
const CROSSING = Content.Traffic.Crossing

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

local function allowed(row: WalkPath, night: boolean): boolean
	if row.Weight <= 0 then
		return false
	end
	return row.Shift == "Any" or row.Shift == (if night then "Night" else "Day")
end

-- Species a passer-by may be (Pedestrian = true, never reserved) and civil outfits of the pedestrian type
local function lookLists(): ({ string }, { string })
	const species: { string } = {}
	for _, row in Content.Species.List do
		if row.Pedestrian and row.ReservedFor == nil then
			table.insert(species, row.Key)
		end
	end
	const never = Content.Looks.NpcNeverUses.Outfits
	local source: { string } = {}
	const pedestrian = Content.CustomerTypes.ByKey["pedestrian"]
	if pedestrian ~= nil then
		source = pedestrian.Outfits
	else
		for _, row in Content.Outfits.List do
			table.insert(source, row.Key)
		end
	end
	const outfits: { string } = {}
	for _, key in source do
		const row = Content.Outfits.ByKey[key]
		if row ~= nil and row.Use == "Civil" and table.find(never, key) == nil then
			table.insert(outfits, key)
		end
	end
	return species, outfits
end

-- First stop of `geo` at or after `s` (inclusive) / strictly after `s`, in absolute distance. nil = none (end of a
-- through path).
local function stopFrom(geo: WalkGeo.Geo, s: number, inclusive: boolean): Stop?
	local function ahead(at: number): boolean
		return if inclusive then at >= s - EPSILON else at > s + EPSILON
	end
	if not geo.Loop then
		for _, crossing in geo.Crossings do
			if ahead(crossing.From) then
				return {
					At = crossing.From,
					Kind = "Crossing",
					Crosswalk = crossing.Crosswalk,
					Exit = crossing.To,
					Curb = crossing.From,
				}
			end
		end
		return nil
	end
	const length = geo.Length
	const lap = math.floor(s / length) * length
	if #geo.Crossings == 0 then
		for k = 0, 1 do
			const seam = lap + k * length
			if seam > 0 and ahead(seam) then
				return { At = seam, Kind = "Pause", Crosswalk = nil, Exit = seam }
			end
		end
		return { At = lap + 2 * length, Kind = "Pause", Crosswalk = nil, Exit = lap + 2 * length }
	end
	for k = 0, 2 do
		const base = lap + k * length
		for _, crossing in geo.Crossings do
			const at = base + crossing.From
			if ahead(at) then
				return { At = at, Kind = "Crossing", Crosswalk = crossing.Crosswalk, Exit = base + crossing.To, Curb = at }
			end
		end
	end
	return nil
end

-- Inside the road part of a crosswalk (spawn must avoid it)
local function onRoad(geo: WalkGeo.Geo, s: number): boolean
	const folded = WalkGeo.Fold(geo, s)
	for _, crossing in geo.Crossings do
		if folded > crossing.From - SPACING and folded < crossing.To + 1 then
			return true
		end
	end
	return false
end

const PedestrianService = Modux.Service("PedestrianService", {
	Require = { "PlaceService", "NetService", "RoundService", "TrafficService", "AnomalyService", "CustomerService" },
	Priority = 545,
})

function PedestrianService:Setup()
	self.Enabled = false :: boolean
	self.Walkers = {} :: { [number]: Walker }
	self.Holds = {} :: { [string]: Hold }
	self.Geos = {} :: { [string]: WalkGeo.Geo }
	self.GeoRetryAt = {} :: { [string]: number }
	self.TargetCount = 0 :: number
	self.TargetNight = false :: boolean
	self.Drawn = false :: boolean
	self.FillPending = true :: boolean
	self.NextSpawnAt = 0 :: number
	self.Rng = Random.new() :: Random
	self.Warned = {} :: { [string]: boolean }
	const species, outfits = lookLists()
	self.SpeciesList = species :: { string }
	self.OutfitList = outfits :: { string }
	-- dev controls of the customer side (CustomerService:SetAdopter)
	self.Adoption = nil :: { Force: () -> string, Status: () -> string }?
end

function PedestrianService:WarnOnce(key: string, message: string)
	if self.Warned[key] then
		return
	end
	self.Warned[key] = true
	warn(`{PREFIX} {message}`)
end

-- Reads -----------------------------------------------------------------------------------------------------------

function PedestrianService:Count(): number
	local count = 0
	for _ in self.Walkers do
		count += 1
	end
	return count
end

-- Walkers wanted now (0 under tension or outside the walking phases)
function PedestrianService:Target(): number
	if not self:CanWalk() then
		return 0
	end
	return self.TargetCount
end

function PedestrianService:CanWalk(): boolean
	if not self.Enabled then
		return false
	end
	const round = self.Dependencies.RoundService
	if not round:IsStarted() or table.find(NO_PHASES, round:GetPhase()) ~= nil then
		return false
	end
	return not self.Dependencies.AnomalyService:IsTension()
end

-- Geometry of a path (cached; nil while the binding is missing, retried every PATH_RETRY s)
function PedestrianService:GeoOf(row: WalkPath): WalkGeo.Geo?
	const cached = self.Geos[row.Key]
	if cached then
		return cached
	end
	const t = now()
	const retry = self.GeoRetryAt[row.Key]
	if retry and t < retry then
		return nil
	end
	const geo, problem, warnings = WalkGeo.Build(row)
	for _, message in warnings do
		self:WarnOnce(`geo:{message}`, message)
	end
	if geo == nil then
		self:WarnOnce(`path:{row.Key}`, `{problem or "no path"}: no walkers on it`)
		self.GeoRetryAt[row.Key] = t + PATH_RETRY
		return nil
	end
	self.Geos[row.Key] = geo
	return geo
end

-- Waiting line at a curb (TASK-321, owner print 2026-10-15: walkers waiting for the walk sign stood inside each other,
-- the stop of every walker of a crosswalk is the same curb point and the Hold above only sees walkers coming the same
-- way), PROVISIONAL: a walker heading to a crosswalk takes the first spot from the curb back along its own sidewalk,
-- WAIT_GAP studs apart, that no other walker stands on or claims first (who is nearer its curb claims first), and only
-- crosses from the curb itself: the next in line walks up when the spot ahead clears.
const WAIT_GAP = 2.8 -- studs (world, centre to centre) between two waiting walkers
const WAIT_SLOTS = 6 -- spots behind the curb (then it waits where it is)
const WAIT_MOVE = 0.05 -- studs: smaller changes of the spot are ignored
-- Records ---------------------------------------------------------------------------------------------------------

function PedestrianService:Publish(walker: Walker, added: boolean)
	if not self.Dependencies.NetService:IsRunning() then
		return
	end
	const record = table.clone(walker.Record)
	if added then
		self.Libs.Net.Pedestrians:add(walker.Id, record)
	else
		self.Libs.Net.Pedestrians:update(walker.Id, record)
	end
end

-- New record anchored at rest at `dist` (folded into one lap on a Loop path), heading to the stop after it.
-- `inclusive`: a stop right at `dist` counts (spawn); otherwise only stops ahead (pull away from a stop).
function PedestrianService:Anchor(walker: Walker, dist: number, inclusive: boolean, t: number, added: boolean)
	const geo = walker.Geo
	const folded = WalkGeo.Fold(geo, dist)
	const offset = dist - folded
	if walker.Crossing ~= nil then
		walker.Crossing.Exit -= offset
	end
	if walker.LapEnd ~= nil then
		walker.LapEnd = (walker.LapEnd :: number) - offset
	end
	const anchor = f32(folded)
	const stop = stopFrom(geo, anchor, inclusive)
	walker.Stop = stop
	local stopDist = 0
	if stop ~= nil then
		stopDist = f32(math.max(stop.At, MIN_STOP))
		stop.At = stopDist
		if stop.Kind == "Crossing" then
			stop.Curb = stopDist
			-- TASK-321: from rest (spawn, end of a Hold, off a crossing) straight to its spot of the waiting line
			walker.Dist = anchor
			const spot = self:WaitSpot(walker, stop)
			if spot < stopDist - WAIT_MOVE then
				stopDist = f32(math.max(spot, MIN_STOP))
				stop.At = stopDist
			end
		end
	end
	walker.Record.AnchorAt = t
	walker.Record.AnchorDist = anchor
	walker.Record.StopDist = stopDist
	walker.Record.HeldUntil = 0
	walker.Cursor = Motion.Cursor(walker.Profile, walker.Record)
	walker.Dist, walker.Speed = anchor, 0
	walker.ParkedAt = nil
	walker.HoldAt = nil
	self:Publish(walker, added)
end

-- Walkers ---------------------------------------------------------------------------------------------------------

-- Free slot whose lane is the least used (lowest slot on a tie)
function PedestrianService:FreeSlot(): number?
	const use: { [number]: number } = {}
	for _, walker in self.Walkers do
		use[walker.Lane] = (use[walker.Lane] or 0) + 1
	end
	local best: number? = nil
	local bestUse = math.huge
	for id = 1, RULES.Slots do
		if self.Walkers[id] == nil then
			const used = use[WalkGeo.LaneOfSlot(id)] or 0
			if used < bestUse then
				best, bestUse = id, used
			end
		end
	end
	return best
end

function PedestrianService:Spawn(row: WalkPath, geo: WalkGeo.Geo, dist: number, t: number): Walker?
	const id = self:FreeSlot()
	if id == nil or #self.SpeciesList == 0 or #self.OutfitList == 0 then
		return nil
	end
	const rng = self.Rng
	const speed = WalkGeo.QuantSpeed(between(rng, RULES.Speed))
	const record: Record = {
		Path = geo.Index,
		Species = self.SpeciesList[rng:NextInteger(1, #self.SpeciesList)],
		Outfit = self.OutfitList[rng:NextInteger(1, #self.OutfitList)],
		Speed = speed,
		AnchorAt = t,
		AnchorDist = 0,
		StopDist = 0,
		HeldUntil = 0,
	}
	const profile = WalkGeo.Profile(geo, speed)
	const walker: Walker = {
		Id = id,
		Npc = -id,
		Geo = geo,
		Profile = profile,
		Record = record,
		Cursor = Motion.Cursor(profile, record),
		Dist = 0,
		Speed = 0,
		Lane = WalkGeo.LaneOfSlot(id),
		Stop = nil,
		ParkedAt = nil,
		Crossing = nil,
		Leaving = false,
		LapEnd = nil,
		Noticed = false,
		HoldAt = nil,
	}
	self.Walkers[id] = walker
	self:Anchor(walker, dist, true, t, true)
	return walker
end

function PedestrianService:Remove(walker: Walker)
	if self.Walkers[walker.Id] ~= walker then
		return
	end
	self:OffRoad(walker)
	self.Walkers[walker.Id] = nil
	if self.Dependencies.NetService:IsRunning() then
		self.Libs.Net.Pedestrians:remove(walker.Id)
	end
end

function PedestrianService:RemoveAll()
	for _, walker in self.Walkers do
		self:Remove(walker)
	end
end

-- The walker leaves the road part of its crosswalk: drops out of the hold; the last one releases the reservation
function PedestrianService:OffRoad(walker: Walker)
	const crossing = walker.Crossing
	if crossing == nil then
		return
	end
	walker.Crossing = nil
	const key = crossing.Crosswalk
	const hold = self.Holds[key]
	if hold == nil then
		return
	end
	hold.Riders[walker.Id] = nil
	if next(hold.Riders) == nil then
		self.Holds[key] = nil
		self.Dependencies.TrafficService:ReleaseCrossing(key, hold.Holder)
	end
end

-- Crosswalk (§8.1) --------------------------------------------------------------------------------------------------

-- Parked on the near curb: cross under our own live reservation if there is time, else ask TrafficService
function PedestrianService:TryCross(walker: Walker, stop: Stop, t: number)
	const key = stop.Crosswalk
	if key == nil then
		return
	end
	-- TASK-321: only the first of the waiting line (on the curb) steps on the road
	if stop.Curb ~= nil and walker.Dist < (stop.Curb :: number) - WAIT_MOVE then
		return
	end
	-- never faster than the rider ahead in the same lane (it would catch up and walk through it)
	const cap = self:LeaderSpeed(walker, key)
	if cap ~= nil and cap < walker.Record.Speed then
		walker.Record.Speed = cap
		walker.Profile = WalkGeo.Profile(walker.Geo, cap)
	end
	-- time to the far curb from rest here
	const probe: Record = table.clone(walker.Record)
	probe.AnchorAt = t
	probe.AnchorDist = walker.Dist
	probe.StopDist = 0
	probe.HeldUntil = 0
	const arrival = Motion.TimeAt(walker.Profile, probe, stop.Exit, t + HORIZON)
	if arrival == nil then
		return
	end
	-- lateral + longitudinal separation on entering: wait on the curb while a rider stands on our place
	if self:RiderNear(walker, key) then
		return
	end
	local hold = self.Holds[key]
	if hold ~= nil then
		if arrival + RIDE_MARGIN > hold.Expires then
			return
		end
	else
		-- the reservation lasts the real crossing at this walker's speed (the Ninth crosswalks take > MaxWait)
		const traffic = self.Dependencies.TrafficService
		if not traffic:ReserveCrossing(key, walker.Npc, math.max(CROSSING.MaxWait, arrival + RIDE_MARGIN - t)) then
			return
		end
		-- mirror of what TrafficService granted (it clamps the duration; with traffic off it holds nothing)
		const expires = traffic:ReservedUntil(key, walker.Npc) or (arrival + RIDE_MARGIN)
		if arrival + RIDE_MARGIN > expires then
			self:WarnOnce(`long:{key}`, `{key} takes longer than the longest crosswalk reservation at walking speed`)
		end
		hold = { Holder = walker.Npc, Expires = expires, Riders = {} }
		self.Holds[key] = hold
	end
	const granted = hold :: Hold
	granted.Riders[walker.Id] = true

	walker.Crossing = { Crosswalk = key, Exit = stop.Exit }
	self:Anchor(walker, walker.Dist, false, t, false)
end

-- Spacing ---------------------------------------------------------------------------------------------------------

-- World place of a walker (floor point plus the lane offset)
function PedestrianService:PlaceOf(walker: Walker): Vector3
	return WalkGeo.LanePointAt(walker.Geo, walker.Dist, walker.Lane)
end

-- A walker on the road of crosswalk `key` (or about to be) closer than CROSS_GAP to where `walker` stands
function PedestrianService:RiderNear(walker: Walker, key: string): boolean
	const place = self:PlaceOf(walker)
	for _, other in self.Walkers do
		if other == walker then
			continue
		end
		const riding = other.Crossing ~= nil and other.Crossing.Crosswalk == key
		if not riding then
			continue
		end
		const offset = self:PlaceOf(other) - place
		if Vector3.new(offset.X, 0, offset.Z).Magnitude < CROSS_GAP then
			return true
		end
	end
	return false
end

-- Speed of the nearest rider ahead of `walker` (same crosswalk, same lane, same way, within CROSS_LOOK), nil if none
function PedestrianService:LeaderSpeed(walker: Walker, key: string): number?
	const place = self:PlaceOf(walker)
	const heading = WalkGeo.Heading(walker.Geo, walker.Dist)
	local best: number? = nil
	local bestAlong = CROSS_LOOK
	for _, other in self.Walkers do
		if other == walker or other.Lane ~= walker.Lane then
			continue
		end
		const theirs = other.Crossing
		if theirs == nil or theirs.Crosswalk ~= key then
			continue
		end
		const offset = self:PlaceOf(other) - place
		const along = offset.X * heading.X + offset.Z * heading.Z
		const otherHeading = WalkGeo.Heading(other.Geo, other.Dist)
		if along > 0 and along < bestAlong and otherHeading.X * heading.X + otherHeading.Z * heading.Z > HOLD_SAME then
			best, bestAlong = other.Record.Speed, along
		end
	end
	return best
end

-- Another walker stands or walks the same way less than `reach` studs ahead of `walker`, near its line
function PedestrianService:Ahead(walker: Walker, reach: number): boolean
	const position = self:PlaceOf(walker)
	const heading = WalkGeo.Heading(walker.Geo, walker.Dist)
	for _, other in self.Walkers do
		if other == walker then
			continue
		end
		const offset = self:PlaceOf(other) - position
		const along = offset.X * heading.X + offset.Z * heading.Z
		if along <= HOLD_MIN or along > reach then
			continue
		end
		if math.abs(offset.X * heading.Z - offset.Z * heading.X) > HOLD_LANE then
			continue
		end
		const otherHeading = WalkGeo.Heading(other.Geo, other.Dist)
		if otherHeading.X * heading.X + otherHeading.Z * heading.Z < HOLD_SAME then
			continue
		end
		return true
	end
	return false
end

-- First free spot of the waiting line of `stop` for `walker` (TASK-321): the curb, else WAIT_GAP steps back along its
-- path. Taken = another walker standing there, or heading to a crosswalk stop there and nearer its own curb.
function PedestrianService:WaitSpot(walker: Walker, stop: Stop): number
	const curb = stop.Curb or stop.At
	const mine = curb - walker.Dist
	const claims: { Vector3 } = {}
	for _, other in self.Walkers do
		if other == walker or other.Crossing ~= nil then
			continue
		end
		if other.Speed <= 0 then
			table.insert(claims, self:PlaceOf(other))
			continue
		end
		const theirs = other.Stop
		if theirs == nil or theirs.Kind == "Pause" or other.Record.StopDist <= 0 then
			continue
		end
		-- a walker braking behind another one (Hold) will stand at its StopDist: that place is taken too
		const left = if theirs.Kind == "Hold" then -1 else (theirs.Curb or theirs.At) - other.Dist
		if left < mine or (left == mine and other.Id < walker.Id) then
			table.insert(claims, WalkGeo.LanePointAt(other.Geo, other.Record.StopDist, other.Lane))
		end
	end
	for k = 0, WAIT_SLOTS do
		const at = curb - k * WAIT_GAP
		if at <= walker.Dist then
			return walker.Dist
		end
		const place = WalkGeo.LanePointAt(walker.Geo, at, walker.Lane)
		local free = true
		for _, claim in claims do
			const offset = claim - place
			if Vector3.new(offset.X, 0, offset.Z).Magnitude < WAIT_GAP then
				free = false
				break
			end
		end
		if free then
			return at
		end
	end
	return math.max(curb - WAIT_SLOTS * WAIT_GAP, walker.Dist)
end

-- Keeps the walker on its spot of the waiting line (TASK-321): a walking one stops earlier when its spot is taken
-- (only while it can still brake there); a standing one walks up when a spot ahead clears. True when it re-anchored.
function PedestrianService:Queue(walker: Walker, stop: Stop, t: number): boolean
	const spot = self:WaitSpot(walker, stop)
	const record = walker.Record
	const parked = Motion.Parked(walker.Profile, record, walker.Cursor, t)
	if not parked then
		if spot < record.StopDist - WAIT_MOVE then
			const brake = walker.Speed * walker.Speed / (2 * WalkGeo.Brake) + walker.Speed / TICK_RATE
			if spot >= walker.Dist + brake then
				record.StopDist = f32(math.max(spot, MIN_STOP))
				record.HeldUntil = 0
				walker.Cursor = Motion.Cursor(walker.Profile, record)
				stop.At = record.StopDist
				self:Publish(walker, false)
			end
		end
		return false
	end
	if spot <= walker.Dist + WAIT_MOVE then
		return false
	end
	record.AnchorAt = t
	record.AnchorDist = f32(walker.Dist)
	record.StopDist = f32(spot)
	record.HeldUntil = 0
	walker.Cursor = Motion.Cursor(walker.Profile, record)
	walker.Speed = 0
	walker.ParkedAt = nil
	stop.At = record.StopDist
	self:Publish(walker, false)
	return true
end

-- Brakes the walker from where it is now (same rule as AdoptPick: the record's past does not change). A nearer stop
-- already set is kept (it brakes there anyway). Returns true when it holds.
function PedestrianService:Hold(walker: Walker, brake: number, t: number): boolean
	const record = walker.Record
	local stopAt = walker.Dist + brake
	if record.StopDist > 0 and record.StopDist >= walker.Dist - EPSILON and record.StopDist <= stopAt then
		return false
	end
	if not walker.Geo.Loop then
		stopAt = math.min(stopAt, walker.Geo.Length - MIN_STOP)
	end
	record.StopDist = f32(math.max(stopAt, MIN_STOP))
	record.HeldUntil = 0
	walker.Cursor = Motion.Cursor(walker.Profile, record)
	walker.Stop = { At = record.StopDist, Kind = "Hold", Crosswalk = nil, Exit = record.StopDist }
	walker.HoldAt = t
	walker.ParkedAt = nil
	self:Publish(walker, false)
	return true
end

-- Tick ------------------------------------------------------------------------------------------------------------

function PedestrianService:StepWalker(walker: Walker, t: number)
	if walker.Noticed then
		return -- stands for the customer side until Take / Release
	end
	-- spacing: holding behind another walker -> walk on once the way is clear (re-anchored at rest, real stop again)
	const holdAt = walker.HoldAt
	if holdAt ~= nil and walker.Crossing == nil then
		if
			Motion.Parked(walker.Profile, walker.Record, walker.Cursor, t)
			and (t - holdAt > HOLD_MAX or not self:Ahead(walker, HOLD_GAP + 0.5))
		then
			self:Anchor(walker, walker.Dist, true, t, false)
		end
		return
	end
	if walker.Crossing == nil and walker.Speed > HOLD_SPEED then
		const brake = walker.Speed * walker.Speed / (2 * WalkGeo.Brake) + walker.Speed / TICK_RATE + NOTICE_ROOM
		if self:Ahead(walker, HOLD_GAP + brake) and self:Hold(walker, brake, t) then
			return
		end
	end
	const crossing = walker.Crossing
	if crossing ~= nil then
		if walker.Dist >= crossing.Exit - EPSILON then
			self:OffRoad(walker)
			return
		end
		const hold = self.Holds[crossing.Crosswalk]
		if hold == nil or t >= hold.Expires then
			-- failsafe (§8.1): the reservation ended with the walker on the road
			warn(`{PREFIX} walker {walker.Id} still on {crossing.Crosswalk} when its reservation ended: moved to the curb`)
			const exit = crossing.Exit
			self:OffRoad(walker)
			self:Anchor(walker, exit, false, t, false)
		end
		return
	end
	const stop = walker.Stop
	if stop ~= nil and stop.Kind == "Crossing" and self:Queue(walker, stop, t) then
		return
	end
	if stop == nil or not Motion.Parked(walker.Profile, walker.Record, walker.Cursor, t) then
		walker.ParkedAt = nil
		return
	end
	if walker.ParkedAt == nil then
		walker.ParkedAt = t
	end
	if stop.Kind == "Pause" then
		if t >= (walker.ParkedAt :: number) + PAUSE then
			self:Anchor(walker, walker.Dist, false, t, false)
		end
	elseif not walker.Leaving or walker.LapEnd == nil or stop.At < (walker.LapEnd :: number) then
		self:TryCross(walker, stop, t)
	end
end

-- New target for the shift: walkers of the other shift's paths leave now, extras leave at their path end
function PedestrianService:Retarget()
	const round = self.Dependencies.RoundService
	-- owner 2026-10-21: the morning of a night shift has the day's walkers (RoundService:IsDark, Content.Shift.Morning)
	const night = round:IsDark()
	const range = if night then Content.Flow.NightWalkers else Content.Flow.DayWalkers
	const low, high = range[1] or 0, range[2] or range[1] or 0
	self.TargetCount = math.min(self.Rng:NextInteger(low, math.max(high, low)), RULES.Slots)
	self.TargetNight = night
	self.Drawn = true
	for _, walker in self.Walkers do
		const row = Content.WalkPaths.ByKey[walker.Geo.Key]
		if row == nil or not allowed(row, night) then
			self:Remove(walker)
		end
	end
	self:TrimExtras()
end

-- Marks walkers over the target as leaving (through paths finish; loops stop at the lap seam)
function PedestrianService:TrimExtras()
	local staying = 0
	for _, walker in self.Walkers do
		if not walker.Leaving then
			staying += 1
		end
	end
	local extra = staying - self.TargetCount
	if extra <= 0 then
		return
	end
	-- through paths first: they leave out of sight by themselves
	for pass = 1, 2 do
		for _, walker in self.Walkers do
			if extra <= 0 then
				return
			end
			if walker.Leaving or (pass == 1 and walker.Geo.Loop) then
				continue
			end
			walker.Leaving = true
			if walker.Geo.Loop then
				const length = walker.Geo.Length
				walker.LapEnd = (math.floor(walker.Dist / length) + 1) * length
			end
			extra -= 1
		end
	end
end

-- Weighted draw among the paths of the shift whose start is clear now
function PedestrianService:PickPath(night: boolean, startClear: boolean): (WalkPath?, WalkGeo.Geo?)
	local total = 0
	const pool: { WalkPath } = {}
	const geos: { [string]: WalkGeo.Geo } = {}
	for _, row in Content.WalkPaths.List do
		if not allowed(row, night) then
			continue
		end
		const geo = self:GeoOf(row)
		if geo == nil then
			continue
		end
		if startClear then
			local clear = true
			const start = WalkGeo.PointAt(geo, 0)
			for _, walker in self.Walkers do
				if walker.Geo == geo and WalkGeo.Fold(geo, walker.Dist) < SPACING then
					clear = false
					break
				end
				-- another path starting at the same place (EX-E, a door) or a walker passing by it
				const offset = self:PlaceOf(walker) - start
				if Vector3.new(offset.X, 0, offset.Z).Magnitude < SPAWN_CLEAR then
					clear = false
					break
				end
			end
			if not clear then
				continue
			end
		end
		table.insert(pool, row)
		geos[row.Key] = geo
		total += row.Weight
	end
	if total <= 0 then
		return nil, nil
	end
	local roll = self.Rng:NextNumber() * total
	for _, row in pool do
		roll -= row.Weight
		if roll <= 0 then
			return row, geos[row.Key]
		end
	end
	const last = pool[#pool]
	return last, geos[last.Key]
end

-- Random distance of `geo` off the crosswalks (first fill), nil after a few tries
function PedestrianService:RandomSpot(geo: WalkGeo.Geo): number?
	const top = if geo.Loop then geo.Length else geo.Length * 0.9
	for _ = 1, 8 do
		const s = self.Rng:NextNumber() * top
		if not onRoad(geo, s) then
			return s
		end
	end
	return nil
end

function PedestrianService:TrySpawn(t: number)
	if not self:CanWalk() then
		return
	end
	const round = self.Dependencies.RoundService
	-- owner 2026-10-21: no new walker at the dusk of the morning; the night's few come with the Night phase
	if round:IsDusk() then
		return
	end
	if not self.Drawn or self.TargetNight ~= round:IsDark() then
		self:Retarget()
	end
	const night = self.TargetNight
	if self.FillPending then
		self.FillPending = false
		for _ = self:Count() + 1, self.TargetCount do
			const row, geo = self:PickPath(night, false)
			if row == nil or geo == nil then
				break
			end
			const spot = self:RandomSpot(geo)
			if spot ~= nil then
				self:Spawn(row, geo, spot, t)
			end
		end
		self.NextSpawnAt = t + between(self.Rng, SPAWN_GAP)
		return
	end
	if t < self.NextSpawnAt then
		return
	end
	local staying = 0
	for _, walker in self.Walkers do
		if not walker.Leaving then
			staying += 1
		end
	end
	if staying >= self.TargetCount then
		return
	end
	const row, geo = self:PickPath(night, true)
	if row ~= nil and geo ~= nil and self:Spawn(row, geo, 0, t) ~= nil then
		self.NextSpawnAt = t + between(self.Rng, SPAWN_GAP)
	end
end

function PedestrianService:Step()
	const t = now()
	for _, walker in self.Walkers do
		walker.Dist, walker.Speed = Motion.Sample(walker.Profile, walker.Record, walker.Cursor, t)
		const lapEnd = walker.LapEnd
		if
			WalkGeo.Done(walker.Geo, walker.Dist)
			or (lapEnd ~= nil and walker.Crossing == nil and walker.Dist >= lapEnd - EPSILON)
		then
			self:Remove(walker)
		end
	end
	for _, walker in self.Walkers do
		self:StepWalker(walker, t)
	end
	self:TrySpawn(t)
end

-- Adoption (TASK-163; CustomerService/Adopt.luau) ------------------------------------------------------------------

-- Inside the road part of a crosswalk (the near curb itself is sidewalk)
local function onCrosswalk(geo: WalkGeo.Geo, s: number): boolean
	const folded = WalkGeo.Fold(geo, s)
	for _, crossing in geo.Crossings do
		if folded > crossing.From + 0.5 and folded < crossing.To + 0.5 then
			return true
		end
	end
	return false
end

-- Nearest free walker within `radius` (XZ) of `center` whose look `accept`s; it brakes there. Returns its slot.
function PedestrianService:AdoptPick(
	center: Vector3,
	radius: number,
	accept: (species: string, outfit: string) -> boolean
): number?
	if not self:CanWalk() then
		return nil
	end
	local best: Walker? = nil
	local bestDistance = radius
	for _, walker in self.Walkers do
		const geo = walker.Geo
		if
			walker.Noticed
			or walker.Crossing ~= nil
			or onCrosswalk(geo, walker.Dist)
			or (not geo.Loop and walker.Dist > geo.Length - END_ROOM)
		then
			continue
		end
		const offset = self:PlaceOf(walker) - center
		const distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
		if distance <= bestDistance and accept(walker.Record.Species, walker.Record.Outfit) then
			best = walker
			bestDistance = distance
		end
	end
	if best == nil then
		return nil
	end
	const walker = best :: Walker
	-- brake from where it is now: StopDist past the braking distance + one grid step of Motion (so the record's past
	-- does not change); a nearer stop already set is kept
	const record = walker.Record
	walker.Dist, walker.Speed = Motion.Sample(walker.Profile, record, walker.Cursor, now())
	local stopAt = walker.Dist + walker.Speed * walker.Speed / (2 * WalkGeo.Brake) + walker.Speed * 0.1 + NOTICE_ROOM
	if record.StopDist > 0 and record.StopDist >= walker.Dist - EPSILON and record.StopDist < stopAt then
		stopAt = record.StopDist
	end
	if not walker.Geo.Loop then
		stopAt = math.min(stopAt, walker.Geo.Length - MIN_STOP)
	end
	record.StopDist = f32(math.max(stopAt, MIN_STOP))
	record.HeldUntil = 0
	walker.Cursor = Motion.Cursor(walker.Profile, record)
	walker.Noticed = true
	walker.ParkedAt = nil
	self:Publish(walker, false)
	return walker.Id
end

function PedestrianService:NoticedWalker(slot: number): Walker?
	const walker = self.Walkers[slot]
	return if walker ~= nil and walker.Noticed then walker else nil
end

-- Look and place of the noticed walker of `slot`, nil when it is gone
function PedestrianService:AdoptPeek(slot: number): Handoff?
	const walker = self:NoticedWalker(slot)
	if walker == nil then
		return nil
	end
	const geo = walker.Geo
	const row = Content.WalkPaths.ByKey[geo.Key]
	if row == nil then
		return nil
	end
	const nodes = row.Nodes
	const cum = geo.Path.Cum
	const folded = WalkGeo.Fold(geo, walker.Dist)
	-- segment [i, i + 1] holding the walker; the nearer of its two nodes (a Loop closes back to node 1)
	local index = 1
	for i = 1, #cum - 1 do
		if folded >= cum[i] then
			index = i
		end
	end
	const nextIndex = if index >= #nodes then 1 else index + 1
	const toNext = (cum[index + 1] or cum[index]) - folded
	const toPrevious = folded - cum[index]
	const node = if toNext < toPrevious then nodes[nextIndex] else nodes[index]
	return {
		Species = walker.Record.Species,
		Outfit = walker.Record.Outfit,
		Position = self:PlaceOf(walker),
		Heading = WalkGeo.Heading(geo, walker.Dist),
		Node = node,
	}
end

-- The noticed walker became a customer: its record goes (the slot refills from a path start)
function PedestrianService:AdoptTake(slot: number): boolean
	const walker = self:NoticedWalker(slot)
	if walker == nil then
		return false
	end
	self:Remove(walker)
	return true
end

-- Nobody took the noticed walker: it walks on from where it stands
function PedestrianService:AdoptRelease(slot: number)
	const walker = self:NoticedWalker(slot)
	if walker == nil then
		return
	end
	walker.Noticed = false
	const t = now()
	walker.Dist, walker.Speed = Motion.Sample(walker.Profile, walker.Record, walker.Cursor, t)
	self:Anchor(walker, walker.Dist, true, t, false)
end

-- Dev (DevService/Commands/Pedestrian.luau) -------------------------------------------------------------------------

function PedestrianService:Status(): string
	const parts: { string } = {}
	table.insert(parts, `walkers {self:Count()}/{self:Target()} (drawn {self.TargetCount}, {if self.TargetNight then "night" else "day"})`)
	if self.Enabled and self.Dependencies.AnomalyService:IsTension() then
		table.insert(parts, "tension")
	end
	const adoption = self.Adoption
	if adoption ~= nil then
		table.insert(parts, adoption.Status())
	end
	for id = 1, RULES.Slots do
		const walker = self.Walkers[id]
		if walker then
			const stop = walker.Stop
			table.insert(
				parts,
				string.format(
					"#%d %s %.0f/%.0f v%.1f stop %s%s%s%s",
					id,
					walker.Geo.Key,
					WalkGeo.Fold(walker.Geo, walker.Dist),
					walker.Geo.Length,
					walker.Speed,
					if stop then `{stop.Crosswalk or stop.Kind}@{math.floor(stop.At)}` else "-",
					if walker.Crossing then ` crossing {walker.Crossing.Crosswalk}` else "",
					if walker.Leaving then " leaving" else "",
					if walker.Noticed then " noticed" else ""
				)
			)
		end
	end
	for key, hold in self.Holds do
		local riders = 0
		for _ in hold.Riders do
			riders += 1
		end
		table.insert(parts, string.format("%s held by %d (%d on road) %.1fs", key, hold.Holder, riders, hold.Expires - now()))
	end
	return table.concat(parts, "; ")
end

-- A walker now at the start of `pathKey` (or a random path of the shift), ignoring the target and the timers
function PedestrianService:DevSpawn(pathKey: string?): string
	if not self.Enabled then
		error("pedestrians run only in the Run place", 0)
	end
	const t = now()
	local row: WalkPath? = nil
	local geo: WalkGeo.Geo? = nil
	if pathKey ~= nil then
		row = Content.WalkPaths.ByKey[pathKey]
		if row == nil then
			error(`unknown walk path {pathKey}`, 0)
		end
		geo = self:GeoOf(row :: WalkPath)
	else
		row, geo = self:PickPath(self.Dependencies.RoundService:IsDark(), false)
	end
	if row == nil or geo == nil then
		error("no walk path with its nodes in the map", 0)
	end
	const walker = self:Spawn(row :: WalkPath, geo :: WalkGeo.Geo, 0, t)
	if walker == nil then
		error("no free slot", 0)
	end
	return `walker #{walker.Id} on {(row :: WalkPath).Key} ({walker.Record.Species}, {walker.Record.Outfit}, {walker.Record.Speed} studs/s)`
end

-- The next customer attempt adopts a walker near the queue if one fits (chance and gap ignored)
function PedestrianService:DevAdopt(): string
	const adoption = self.Adoption
	if adoption == nil then
		error("adoption runs only in the Run place", 0)
	end
	return adoption.Force()
end

function PedestrianService:DevClear(): number
	const count = self:Count()
	self:RemoveAll()
	return count
end

-- Lifecycle -------------------------------------------------------------------------------------------------------

PedestrianService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self.Enabled = true
	-- passers-by that may become customers (TASK-163); CustomerService (590) set up in its own OnInit, before ours
	self.Adoption = self.Dependencies.CustomerService:SetAdopter({
		Pick = function(center: Vector3, radius: number, accept: (species: string, outfit: string) -> boolean): number?
			return self:AdoptPick(center, radius, accept)
		end,
		Peek = function(slot: number): Handoff?
			return self:AdoptPeek(slot)
		end,
		Take = function(slot: number): boolean
			return self:AdoptTake(slot)
		end,
		Release = function(slot: number)
			self:AdoptRelease(slot)
		end,
	})
	if #self.SpeciesList == 0 or #self.OutfitList == 0 then
		self:WarnOnce("look", "no species with Pedestrian = true or no civil outfit: no walkers")
	end

	-- RoundService (750) and AnomalyService (570) created their signals in their own OnInit, before ours
	self.Dependencies.RoundService.ShiftStarted:Connect(function()
		self:Retarget()
	end)
	self.Dependencies.AnomalyService.Tension:Connect(function(on: boolean)
		if on then
			self:RemoveAll() -- rua deserta (DEC-183), PROVISIONAL (a)
		else
			self.NextSpawnAt = now() + between(self.Rng, SPAWN_GAP)
		end
	end)
end)

PedestrianService:OnTick(function(self)
	if self.Enabled then
		self:Step()
	end
end, TICK_RATE)

return PedestrianService
