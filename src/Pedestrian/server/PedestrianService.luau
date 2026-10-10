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

	API: Count(), Target(), Status(); dev: DevSpawn(pathKey?), DevClear(). Reservation id of a walker = -slot (never
	an NpcId of NpcService, which are 1..65535).

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
	Kind: "Crossing" | "Pause",
	Crosswalk: string?,
	Exit: number, -- Crossing: far curb (absolute); Pause: = At
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
	Stop: Stop?, -- stop the current record heads to
	ParkedAt: number?,
	-- on the road under a reservation: crosswalk and far curb (absolute)
	Crossing: { Crosswalk: string, Exit: number }?,
	-- leaving: Loop -> removed at this distance (lap seam)
	Leaving: boolean,
	LapEnd: number?,
}

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
				return { At = crossing.From, Kind = "Crossing", Crosswalk = crossing.Crosswalk, Exit = crossing.To }
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
				return { At = at, Kind = "Crossing", Crosswalk = crossing.Crosswalk, Exit = base + crossing.To }
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
	Require = { "PlaceService", "NetService", "RoundService", "TrafficService", "AnomalyService" },
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
	end
	walker.Record.AnchorAt = t
	walker.Record.AnchorDist = anchor
	walker.Record.StopDist = stopDist
	walker.Record.HeldUntil = 0
	walker.Cursor = Motion.Cursor(walker.Profile, walker.Record)
	walker.Dist, walker.Speed = anchor, 0
	walker.ParkedAt = nil
	self:Publish(walker, added)
end

-- Walkers ---------------------------------------------------------------------------------------------------------

function PedestrianService:FreeSlot(): number?
	for id = 1, RULES.Slots do
		if self.Walkers[id] == nil then
			return id
		end
	end
	return nil
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
		Stop = nil,
		ParkedAt = nil,
		Crossing = nil,
		Leaving = false,
		LapEnd = nil,
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

-- Tick ------------------------------------------------------------------------------------------------------------

function PedestrianService:StepWalker(walker: Walker, t: number)
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
	const night = round:IsNight()
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
			for _, walker in self.Walkers do
				if walker.Geo == geo and WalkGeo.Fold(geo, walker.Dist) < SPACING then
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
	if not self.Drawn or self.TargetNight ~= round:IsNight() then
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

-- Dev (DevService/Commands/Pedestrian.luau) -------------------------------------------------------------------------

function PedestrianService:Status(): string
	const parts: { string } = {}
	table.insert(parts, `walkers {self:Count()}/{self:Target()} (drawn {self.TargetCount}, {if self.TargetNight then "night" else "day"})`)
	if self.Enabled and self.Dependencies.AnomalyService:IsTension() then
		table.insert(parts, "tension")
	end
	for id = 1, RULES.Slots do
		const walker = self.Walkers[id]
		if walker then
			const stop = walker.Stop
			table.insert(
				parts,
				string.format(
					"#%d %s %.0f/%.0f v%.1f stop %s%s%s",
					id,
					walker.Geo.Key,
					WalkGeo.Fold(walker.Geo, walker.Dist),
					walker.Geo.Length,
					walker.Speed,
					if stop then `{stop.Crosswalk or stop.Kind}@{math.floor(stop.At)}` else "-",
					if walker.Crossing then ` crossing {walker.Crossing.Crosswalk}` else "",
					if walker.Leaving then " leaving" else ""
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
		row, geo = self:PickPath(self.Dependencies.RoundService:IsNight(), false)
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
