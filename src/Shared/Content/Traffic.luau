--!strict
-- Street traffic, single record with lists (content-data.md §3.14, §6.11; architecture.md §8, §19.17, T21, T30;
-- MAP-01 §9.5 rev. 3; FEAT-033, FEAT-036; DEC-087, DEC-095, DEC-103, DEC-130, DEC-133, DEC-198).
-- Owner: level-designer (routes, lines, boxes) + game-designer (numbers); architect (shape). Not a wire enum:
-- the Traffic set carries Route = IndexOf in Routes and Look = index in Looks (network.md §6.2).
--
-- Rules that no number here can change (DEC-133): cars stop ONLY at the PARE lines of the Juniper arms (1 s) and at a
-- crosswalk line while an NPC holds its reservation; never for a player. No traffic light (DEC-130).
-- AMENDED, Provisional (TASK-263, owner request 2026-10-14; the owner placed traffic lights on the map): with `Lights = true`
-- the cars ALSO obey Content.TrafficLights (the same cycle the lamps show): at every stop line of an axis that is not green they
-- stop, before the stripes; NPCs only start across a crosswalk while its walk sign says Walk. `Lights = false` = the old rules.
-- Names (Path, Line, Box, Stops.Ref) are names in the MAP-01 binding (TASK-098); PlaceService checks them, and the
-- map checks spawn distance and stop order (Validate here only sees numbers).
--
-- Routes.Shift: Day (day windows only) or DayNight (also in night windows with cars; Ninth straight only).
-- Density: by game clock (minutes since 0:00 of the shift day), [From, To). A clock outside every row = no cars
-- (Resume, NightEnd, NightLost, Summary at night, Finale, RunEnd). Night rows spawn only DayNight routes.
-- DEC-198 (Provisional numbers): <= 1 car in the Calm (7-9 PM), 0 after 9 PM. Juniper South (CW-1) uses its own
-- per-direction interval (Crossing.JuniperSouthInterval) inside the cap.
-- Hold reasons (TrafficService:Hold): no car spawns while any is on (anm_008, anm_010, cutscene, ambulance).
-- Looks: index = (shape - 1) x #Paints + paint; kit Assets.Vehicles (TASK-099). Never black and long (ANM-008).
local Table = require(script.Parent.Table)

export type RouteShift = "Day" | "DayNight"
export type StopKind = "Pare" | "Crosswalk"

export type Stop = {
	Kind: StopKind,
	Ref: string, -- Pare: the line name (SL-N/SL-S); Crosswalk: key of Crosswalks
	Line: string, -- stop line piece in the map
}

export type Route = {
	Key: string, -- TR-<n> (map name; not a wire enum)
	Path: string, -- folder of route nodes in the map
	Shift: RouteShift,
	Lane: string, -- entry lane (LaneGap applies per lane)
	JuniperSouth: string?, -- "NB" | "SB": direction on Juniper South (CW-1), spawned by JuniperSouthInterval
	Weight: number, -- chance inside its group (Juniper South direction, or the other routes)
	Conflicts: { string }, -- keys of Conflicts the route crosses
	Stops: { Stop }, -- in order along Path
}

export type Crosswalk = {
	Key: string, -- CW-<n>
	Box: string, -- volume of the crosswalk in the map
	-- axis of the STREET it crosses (TASK-263): its cars follow that axis' light; the walkers cross on the other axis' Walk.
	-- nil = no lamp at this crosswalk (TASK-281): cars and walkers follow only the reservation, as before TASK-263
	Axis: ("EW" | "NS")?,
	Lines: { [string]: string }, -- direction -> stop line
	Linked: string?, -- reserving this crosswalk also reserves the linked one (CW-2 <-> CW-4 share SL-W/SL-E)
}

export type Conflict = {
	Key: string,
	Box: string,
}

export type Density = {
	From: number,
	To: number,
	Night: boolean,
	MaxCars: number,
	Interval: { number }, -- {min, max} seconds between spawns per route (unused when MaxCars = 0)
}

export type Crossing = {
	PareStop: number,
	ReserveRadius: number,
	MaxWait: number,
	Cooldown: number,
	NpcCrossTime: number,
	SpawnMinDist: number,
	LaneGap: number,
	JuniperSouthInterval: { number },
	BrakeDecel: number,
	PullAway: number,
	CarGap: number,
	FollowDelay: number,
}

export type Looks = {
	Shapes: { string },
	Paints: { string },
}

export type Traffic = {
	Lights: boolean, -- TASK-263: cars and walkers follow Content.TrafficLights (false = DEC-130/133 as before)
	Routes: Table.Table<Route>,
	Crosswalks: Table.Table<Crosswalk>,
	Conflicts: Table.Table<Conflict>,
	Density: { Density },
	MaxCars: number, -- absolute cap (the ambulance takes one vehicle slot)
	ConflictGap: number,
	SpeedStraight: number,
	SpeedCrossing: number,
	Looks: Looks,
	HoldReasons: { string },
	HitMinSpeed: number,
	HitTolerance: number,
	KnockTime: number,
	GetUpTime: number,
	ImpulseForward: number,
	ImpulseUp: number,
	ImmuneTime: number,
	HitsNpcs: boolean,
	AmbulanceHits: boolean,
	Crossing: Crossing,
}

local function pare(line: string): Stop
	return { Kind = "Pare", Ref = line, Line = line }
end

local function crosswalk(key: string, line: string): Stop
	return { Kind = "Crosswalk", Ref = key, Line = line }
end

local function route(
	key: string,
	shift: RouteShift,
	lane: string,
	juniperSouth: string?,
	stops: { Stop }
): Route
	return {
		Key = key,
		Path = key,
		Shift = shift,
		Lane = lane,
		JuniperSouth = juniperSouth,
		Weight = 1,
		Conflicts = { "X-T" },
		Stops = stops,
	}
end

-- MAP-01 §9.5: "(SL-x)" = crosswalk line (stop only with an NPC reservation); PARE = always 1 s.
-- Juniper routes that turn into the Ninth cross CW-2 (west) or CW-4 (east) right after the X-T box and pass no SL-W /
-- SL-E: their line for that crosswalk is their own PARE line (SL-N / SL-S), so a reservation keeps them out of the box
-- (no car stops inside X-T). PROVISIONAL (debugger, 2026-10-10): MAP-01 §9.5 lists only SL-W/SL-E for CW-2/CW-4.
const routes = Table.new({
	route("TR-1", "DayNight", "W-IN", nil, { crosswalk("CW-2", "SL-W"), crosswalk("CW-3", "SL-3W") }),
	route("TR-2", "DayNight", "E-IN", nil, { crosswalk("CW-3", "SL-3E"), crosswalk("CW-2", "SL-E") }),
	route("TR-3", "Day", "JN-IN", nil, { pare("SL-N"), crosswalk("CW-4", "SL-N"), crosswalk("CW-3", "SL-3W") }),
	route("TR-4", "Day", "JN-IN", nil, { pare("SL-N"), crosswalk("CW-2", "SL-N") }),
	route("TR-5", "Day", "W-IN", nil, { crosswalk("CW-2", "SL-W") }),
	route("TR-6", "Day", "E-IN", nil, { crosswalk("CW-3", "SL-3E"), crosswalk("CW-2", "SL-E") }),
	route("TR-7", "Day", "JS-IN", "NB", { crosswalk("CW-1", "SL-1S"), pare("SL-S") }),
	route("TR-8", "Day", "JN-IN", "SB", { pare("SL-N"), crosswalk("CW-1", "SL-1N") }),
	route("TR-9", "Day", "W-IN", "SB", { crosswalk("CW-2", "SL-W"), crosswalk("CW-1", "SL-1N") }),
	route(
		"TR-10",
		"Day",
		"JS-IN",
		"NB",
		{ crosswalk("CW-1", "SL-1S"), pare("SL-S"), crosswalk("CW-4", "SL-S"), crosswalk("CW-3", "SL-3W") }
	),
} :: { Route })

const crosswalks = Table.new({
	{ Key = "CW-1", Box = "CW-1", Axis = "NS", Lines = { NB = "SL-1S", SB = "SL-1N" } }, -- Juniper South, trailer <-> Mart
	{ Key = "CW-2", Box = "CW-2", Axis = "EW", Lines = { EB = "SL-W", WB = "SL-E", SB = "SL-N" }, Linked = "CW-4" }, -- SB: TR-4
	-- mid-block, no lamp on the map (TASK-281, Provisional): no Axis
	{ Key = "CW-3", Box = "CW-3", Lines = { EB = "SL-3W", WB = "SL-3E" } },
	-- SB: TR-3 (left from Juniper North), NB: TR-10 (right from Juniper South)
	{
		Key = "CW-4",
		Box = "CW-4",
		Axis = "EW",
		Lines = { EB = "SL-W", WB = "SL-E", SB = "SL-N", NB = "SL-S" },
		Linked = "CW-2",
	},
} :: { Crosswalk })

const conflicts = Table.new({
	{ Key = "X-T", Box = "X-T" }, -- Ninth & Juniper, 4 arms; Ninth has priority (architecture.md §8.1)
} :: { Conflict })

const traffic: Traffic = {
	Lights = true, -- TASK-263, Provisional
	Routes = routes,
	Crosswalks = crosswalks,
	Conflicts = conflicts,
	Density = {
		{ From = 420, To = 480, Night = false, MaxCars = 2, Interval = { 13, 17 } }, -- Prep 7-8 AM (MAP-01 §9.5)
		{ From = 480, To = 1080, Night = false, MaxCars = 4, Interval = { 6, 10 } }, -- Open 8 AM-6 PM (FEAT-033)
		{ From = 1080, To = 1140, Night = false, MaxCars = 2, Interval = { 13, 17 } }, -- Closing 6 PM
		{ From = 1140, To = 1260, Night = true, MaxCars = 1, Interval = { 25, 35 } }, -- Call/Prep/Calm (DEC-198)
		{ From = 1260, To = 1800, Night = true, MaxCars = 0, Interval = { 0, 0 } }, -- after 9 PM (DEC-198)
	},
	MaxCars = 4, -- FEAT-033
	ConflictGap = 1.0,
	SpeedStraight = 22, -- FEAT-033
	SpeedCrossing = 12, -- FEAT-033
	Looks = {
		Shapes = { "Sedan", "Hatch", "Van", "Pickup" }, -- TASK-099 kit Cars/<Shape>
		Paints = { "Peach", "Butter", "Lilac", "MintGray", "TealLight" }, -- Cars/<Shape>/Paints/<Paint>
	},
	HoldReasons = { "anm_008", "anm_010", "cutscene", "ambulance" },
	HitMinSpeed = 6, -- studs/s (FEAT-033)
	HitTolerance = 8, -- studs, server validation (architecture.md §8.2)
	KnockTime = 2.5, -- Q-122 a
	GetUpTime = 0.5,
	ImpulseForward = 30, -- architect calibrates
	ImpulseUp = 15,
	ImmuneTime = 5, -- Q-122 d
	HitsNpcs = false, -- DEC-133
	AmbulanceHits = false,
	Crossing = {
		PareStop = 1, -- DEC-133
		ReserveRadius = 15, -- DEC-133
		MaxWait = 4, -- DEC-133
		Cooldown = 4, -- DEC-133
		NpcCrossTime = 3, -- Provisional (FEAT-033)
		SpawnMinDist = 55, -- DEC-133
		LaneGap = 3, -- DEC-133
		JuniperSouthInterval = { 12, 20 }, -- per direction, day only (DEC-133)
		BrakeDecel = 22, -- Provisional (architect)
		PullAway = 22, -- Provisional (architect)
		CarGap = 17, -- Provisional (architect); 14 -> 17 (TASK-294): kit cars are up to 14 long, 3 studs between bumpers
		FollowDelay = 0.5, -- Provisional (architect)
	},
}

-- Density row for a game clock, or nil (no cars).
local function densityAt(clock: number): Density?
	for _, row in traffic.Density do
		if clock >= row.From and clock < row.To then
			return row
		end
	end
	return nil
end

-- Look index for a shape/paint pair (1-based), and back.
local function lookIndex(shape: number, paint: number): number
	return (shape - 1) * #traffic.Looks.Paints + paint
end

local function lookOf(index: number): (string, string)
	const paints = #traffic.Looks.Paints
	const shape = (index - 1) // paints + 1
	const paint = (index - 1) % paints + 1
	return traffic.Looks.Shapes[shape], traffic.Looks.Paints[paint]
end

export type Api = {
	DensityAt: (clock: number) -> Density?,
	LookIndex: (shape: number, paint: number) -> number,
	LookOf: (index: number) -> (string, string),
}

const out = table.clone(traffic) :: any
out.DensityAt = densityAt
out.LookIndex = lookIndex
out.LookOf = lookOf

return Table.record(out :: Traffic & Api)
