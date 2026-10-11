--!strict
-- What the MAP-01 binding must contain, per wave (architecture.md §18.4-§18.7, §19.22; TASK-010, TASK-048).
-- PlaceService validates ForWave(Content.RunParams.BindingWave). Runtime twin of the REQUIRED lists in
-- tools/assetplace/check_map01.luau (edit-time tool, level-designer): change both together.
-- Counts that are game data come from Content (packages, toppings, bench spots, slot counts, light zones); map ids
-- (PointId, PostId, roads, crosswalks) come from MAP-01 and live here. Pure data: no Modux, Lync, Vide or self.Libs.
-- A6 (architecture.md §19.26): nothing here is "the current vehicle". Vehicles lists every vehicle that must be
-- authored in the place; which one is current is VehicleService's state.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

-- XZ rectangle in studs, WORLD coordinates (built from MAP-01 §4 numbers by mapRect below).
export type Rect = { Name: string, X0: number, X1: number, Z0: number, Z1: number }

export type StationRule = {
	Actions: { [string]: number }?, -- exact number of Interactable anchors per PromptAction owned by the station
	SlotAnchors: number?, -- Interactable anchors with Slot 1..n (grill_collect, one per slot)
	Slots: number?, -- slot Attachments (not Interactable) with Slot 1..n
	PerIngredient: { string }?, -- each action exactly once per topping ingredient (toppings grid)
}

-- One authored vehicle: its stations, and anchors inside the vehicle that belong to no station (phone, switch,
-- the "buy" prompt of the trailer for sale), exact count per PromptAction.
export type VehicleRule = {
	Stations: { [string]: StationRule }, -- StationKind -> rule, one station of each inside the vehicle
	Actions: { [string]: number },
}

-- Every Id must appear exactly once as `Attribute` on an instance tagged `Tag` (light zones, street lights).
export type TaggedIds = { Tag: string, Attribute: string, Ids: { string } }

export type Route = { From: string, To: string, Name: string }

export type List = {
	Wave: number,
	Tags: { string }, -- tags that must exist in the Workspace (§18.1, §19.22)
	Points: { string }, -- PointId (§18.5)
	Nodes: { string }, -- NpcNode ids that must be in the graph (§18.6)
	Vehicles: { [string]: VehicleRule }, -- key of Content.Vehicles -> rule; exactly one Model of each
	Toppings: { string }, -- ingredient keys of the toppings grid
	MapActions: { [string]: number }, -- PromptAction outside any vehicle, exact count (open sign)
	Packages: { string }, -- one buy_package anchor per key (Mart shelves)
	Bench: { [string]: string }, -- BenchSlot -> PromptAction (GEAR WALL)
	Tagged: { TaggedIds },
	StationGap: number, -- min distance between anchors of different stations (§18.7 item 4)
	ToppingGap: number, -- min distance between anchors of different ingredients in the grid
	ShelfGap: number, -- min distance between Mart shelf anchors
	BenchGap: number, -- min distance between bench anchors
	MaxEdge: number, -- studs (§18.6)
	MaxNodes: number, -- §12.3
	Roads: { Rect }, -- carriageways an edge may only cross on a crosswalk edge
	Crosswalks: { [string]: Rect }, -- Crosswalk attribute value -> stripes
	Routes: { Route }, -- blockout routes that must have a path (§18.6)
}

-- Grill anchors: one grill_collect per roller slot at the highest level of the vehicle (DEC-201: 4 on L3).
local function maxGrillSlots(vehicle: string): number
	local most = 0
	for _, level in Content.Upgrades.ByKey.grill.Levels[vehicle] or {} do
		most = math.max(most, level.Effects.GrillSlots or 0)
	end
	return most
end

-- The kitchen every vehicle carries (§18.4); rail and board sizes from Content.Vehicles.
local function kitchen(vehicle: string): { [string]: StationRule }
	const row = Content.Vehicles.ByKey[vehicle]
	return {
		sausage_stock = { Actions = { grill_place = 1, restock = 1 } },
		grill = { SlotAnchors = maxGrillSlots(vehicle) },
		rail = { Slots = row.RailSlots },
		bun_crate = { Actions = { bun_cut = 1, restock = 1 } },
		board = { Actions = { board_add_sausage = 1 }, Slots = row.BoardSlots }, -- DEC-190, DEC-215
		toppings = { PerIngredient = { "topping_add", "restock" } },
		trash = { Actions = { discard = 1 } },
	}
end

-- GEAR WALL: B1..B5 from Upgrades.BenchSpot (DEC-106), S1 = special spot (bench_buy_item).
local function bench(): { [string]: string }
	const out: { [string]: string } = { S1 = "bench_buy_item" }
	for _, upgrade in Content.Upgrades.List do
		out[upgrade.BenchSpot] = "bench_buy_upgrade"
	end
	return out
end

-- LightZone ids from Content.LightGroups (one source for the zone list).
local function lightZones(): { string }
	const out: { string } = {}
	for _, group in Content.LightGroups.List do
		for _, zone in group.Zones do
			table.insert(out, zone)
		end
	end
	table.sort(out)
	return out
end

local function concat<T>(...: { T }): { T }
	const out: { T } = {}
	for _, list in { ... } do
		for _, value in list do
			table.insert(out, value)
		end
	end
	return out
end

-- Map frame (2026-10-10, user's decision): the place is turned 180 degrees in Y, MAP-01 (x, z) is world (-x, K - z).
-- Same K as tools/assetplace/map_frame.luau (change both together). The numbers below stay the MAP-01 §4 ones.
const MAP_K = 67.887287
local function mapRect(name: string, x0: number, x1: number, z0: number, z1: number): Rect
	return { Name = name, X0 = -x1, X1 = -x0, Z0 = MAP_K - z1, Z1 = MAP_K - z0 }
end

const ROADS: { Rect } = {
	mapRect("Ninth", -136, 136, -16, 16),
	mapRect("Juniper North", -12, 12, -152, -16),
	mapRect("Juniper South", -12, 12, 16, 120),
}

const CROSSWALKS: { [string]: Rect } = {
	["CW-1"] = mapRect("CW-1", -12, 12, 34, 42),
	["CW-2"] = mapRect("CW-2", -24, -12, -16, 16),
	["CW-3"] = mapRect("CW-3", 54, 60, -16, 16),
	["CW-4"] = mapRect("CW-4", 12, 24, -16, 16),
}

const WAVE1_TAGS = { "MapBinding", "MapPoint", "NpcNode", "Vehicle", "Station", "Interactable" }
const WAVE1_POINTS = { "PS-1", "PS-2", "PS-3", "PS-4", "Q1", "Q2", "Q3", "Q4", "Q5", "D1", "SP-A", "EX-E", "OP-1" }
const WAVE1_NODES = { "SP-A", "D1", "EX-E", "Q1", "Q2", "Q3", "Q4", "Q5" }
const WAVE1_ROUTES: { Route } = {
	{ From = "SP-A", To = "Q5", Name = "ROUTE-SP-A" },
	{ From = "D1", To = "Q5", Name = "ROUTE-D1-IN" },
	{ From = "Q1", To = "EX-E", Name = "ROUTE-EXIT-E" },
	{ From = "Q1", To = "D1", Name = "ROUTE-EXIT-D1" },
}

local function base(wave: number): List
	return {
		Wave = wave,
		Tags = WAVE1_TAGS,
		Points = WAVE1_POINTS,
		Nodes = WAVE1_NODES,
		Vehicles = {
			cart = { Stations = kitchen("cart"), Actions = {} },
		},
		Toppings = Content.Ingredients.ToppingKeys,
		MapActions = { open_sign = 1 }, -- the sign stays on the map, not in the vehicle (MAP-01 §7.3)
		Packages = Content.Packages.Keys,
		Bench = bench(),
		Tagged = {},
		StationGap = 2.5,
		ToppingGap = 2.0,
		ShelfGap = 2.5,
		BenchGap = 2.5,
		MaxEdge = 40,
		MaxNodes = 80,
		Roads = ROADS,
		Crosswalks = CROSSWALKS,
		Routes = WAVE1_ROUTES,
	}
end

-- Wave 1: the cart and its kitchen (§18.4-§18.7). Unchanged from TASK-010.
const wave1 = base(1)

-- Wave 2 (§19.22): trailer kitchen with coffee machine, phones on both vehicles, the trailer's buy prompt and light
-- switch, tarp, light zones, street lights, night/revive/spectate/swap points, thief lurks.
-- Street bins (Prompt_Discard, DEC-200) are not counted: how many is open (Q-166).
const wave2 = base(2)
wave2.Tags = concat(WAVE1_TAGS, { "VehicleCover", "LightZone", "StreetLight" })
wave2.Points = concat(WAVE1_POINTS, {
	"PS-N1",
	"PS-N2",
	"PS-N3",
	"PS-N4",
	"REV-1",
	"REV-2",
	"REV-3",
	"REV-4",
	"TRL",
	"TRL-SALE",
	"CART",
	"SPEC-P",
	"SPEC-M",
	"DROP-T",
	"L1",
	"L2",
	"L3",
	"ST-R",
})
wave2.Nodes = concat(WAVE1_NODES, { "ST-R", "L1", "L2", "L3" })
const trailerKitchen = kitchen("trailer")
trailerKitchen.coffee_machine = { Actions = { brew_coffee = 1, restock = 1 } } -- FEAT-021
wave2.Vehicles = {
	cart = { Stations = kitchen("cart"), Actions = { answer_phone = 1 } }, -- DEC-124
	trailer = { Stations = trailerKitchen, Actions = { answer_phone = 1, switch_light = 1, buy_trailer = 1 } },
}
wave2.Tagged = {
	{ Tag = "LightZone", Attribute = "ZoneId", Ids = lightZones() },
	{
		Tag = "StreetLight",
		Attribute = "PostId",
		Ids = { "JL-01", "JL-02", "JL-03", "JL-04", "JL-05", "P-01" },
	},
}
-- thief routes from the street spawn to each lurk (MAP-01 §9.2; AvoidCrossings is the thief's own query)
const THIEF_ROUTES: { Route } = {
	{ From = "ST-R", To = "L1", Name = "ROUTE-THIEF-L1" },
	{ From = "ST-R", To = "L2", Name = "ROUTE-THIEF-L2" },
	{ From = "ST-R", To = "L3", Name = "ROUTE-THIEF-L3" },
}
wave2.Routes = concat(WAVE1_ROUTES, THIEF_ROUTES)

-- Wave 3 (§19.22, §8; MAP-01 §5.4-§5.6, §9.5, §10.3, §11; TASK-097). Names that are game data come from Content:
-- cutscene marks and targets (Cutscenes), route paths, stop lines and boxes (Traffic), sidewalk nodes (WalkPaths,
-- rows from TASK-098). Map-only names stay here.
-- Traffic binding (Provisional, architect, TASK-097; architecture.md §18.1 gets the 3 tags in the next doc pass):
--   TrafficPath  Folder/Model of the ordered route nodes of one route, attribute PathId = Traffic.Routes[].Path
--   TrafficLine  stop line piece, attribute LineId = SL-* (Routes[].Stops[].Line and Crosswalks[].Lines)
--   TrafficBox   volume, attribute BoxId = Traffic.Conflicts[].Box (X-T) and Traffic.Crosswalks[].Box (CW-1..4)
-- Entries and exits W/E/JN/JS-IN/OUT are MapPoints (AMB-IN = W-IN, AMB-OUT = E-OUT reuse them in wave 4).

-- Adds the values of `extra` missing from `list`, keeping the order.
local function union(list: { string }, extra: { string }): { string }
	const out = table.clone(list)
	const seen: { [string]: boolean } = {}
	for _, value in out do
		seen[value] = true
	end
	for _, value in extra do
		if not seen[value] then
			seen[value] = true
			table.insert(out, value)
		end
	end
	return out
end

const STREET_POSTS = { "JL-01", "JL-02", "JL-03", "JL-04", "JL-05", "P-01" }

-- MapPoints a cutscene stands on, walks to or looks at (Marks, MoveTo with "{slot}" = 1..4, LookAt). LookAt on a
-- street post is the StreetLight itself (PostId), not a point. Client actors start and end on the explicit ones
-- (MAP-01 §11.3: Walt MKT-DOOR -> WALT-1, Raincoat Lady RL-1 -> RL-END).
local function cutscenePoints(): { string }
	const posts: { [string]: boolean } = {}
	for _, id in STREET_POSTS do
		posts[id] = true
	end
	local out: { string } = {}
	for _, scene in Content.Cutscenes.List do
		out = union(out, scene.Marks)
		for _, beat in scene.Beats do
			if beat.Kind == "MoveTo" and string.find(beat.Target, "{slot}", 1, true) then
				for slot = 1, 4 do
					const id = string.gsub(beat.Target, "{slot}", tostring(slot))
					out = union(out, { id })
				end
			elseif (beat.Kind == "MoveTo" or beat.Kind == "LookAt") and not posts[beat.Target] then
				out = union(out, { beat.Target })
			end
		end
	end
	return union(out, { "MKT-DOOR", "WALT-1", "RL-1", "RL-END" })
end

-- Every NodeId of every sidewalk path (Content.WalkPaths; empty until TASK-098 writes the rows).
local function walkNodes(): { string }
	local out: { string } = {}
	for _, path in Content.WalkPaths.List do
		out = union(out, path.Nodes)
	end
	return out
end

local function trafficPaths(): { string }
	const out: { string } = {}
	for _, route in Content.Traffic.Routes.List do
		table.insert(out, route.Path)
	end
	return union({}, out)
end

local function trafficLines(): { string }
	local out: { string } = {}
	for _, route in Content.Traffic.Routes.List do
		for _, stop in route.Stops do
			out = union(out, { stop.Line })
		end
	end
	for _, crosswalk in Content.Traffic.Crosswalks.List do
		for _, line in crosswalk.Lines do
			out = union(out, { line })
		end
	end
	table.sort(out)
	return out
end

local function trafficBoxes(): { string }
	local out: { string } = {}
	for _, conflict in Content.Traffic.Conflicts.List do
		out = union(out, { conflict.Box })
	end
	for _, crosswalk in Content.Traffic.Crosswalks.List do
		out = union(out, { crosswalk.Box })
	end
	return out
end

const wave3 = base(3)
wave3.Tags = union(wave2.Tags, { "AnomalyAnchor", "TrafficPath", "TrafficLine", "TrafficBox" })
wave3.Points = union(
	wave2.Points,
	concat(
		-- safe spot (SS, §19.14), anomaly anchors and hidden actor spawns (MAP-01 §10.3), Walker step 10 (§5.6, fixed)
		{ "SS", "AN-04", "AN-05", "AN-11", "AN-12", "AS-1", "AS-2", "AS-3", "AS-4", "WALKER-10" },
		cutscenePoints(),
		-- traffic entries and exits (MAP-01 §5.4)
		{ "W-IN", "W-OUT", "E-IN", "E-OUT", "JN-IN", "JN-OUT", "JS-IN", "JS-OUT" }
	)
)
wave3.Nodes = union(wave2.Nodes, walkNodes())
const trailer3 = kitchen("trailer")
trailer3.coffee_machine = { Actions = { brew_coffee = 1, restock = 1 } }
wave3.Vehicles = {
	cart = { Stations = kitchen("cart"), Actions = { answer_phone = 1 } },
	trailer = {
		Stations = trailer3,
		-- service window button TRL-SHUTTER (Prompt_Shutter) next to the switch (DEC-221); H1..H4 left the place
		Actions = { answer_phone = 1, switch_light = 1, buy_trailer = 1, shutter_toggle = 1 },
	},
}
wave3.Tagged = concat(wave2.Tagged, {
	{ Tag = "AnomalyAnchor", Attribute = "AnchorId", Ids = { "WV-1", "WV-2", "WV-3" } },
	{ Tag = "TrafficPath", Attribute = "PathId", Ids = trafficPaths() },
	{ Tag = "TrafficLine", Attribute = "LineId", Ids = trafficLines() },
	{ Tag = "TrafficBox", Attribute = "BoxId", Ids = trafficBoxes() },
})
wave3.Routes = wave2.Routes

const BY_WAVE: { List } = { wave1, wave2, wave3 }

local function freezeDeep<V>(value: V): V
	if type(value) == "table" and not table.isfrozen(value :: any) then
		for _, child in value :: any do
			freezeDeep(child)
		end
		table.freeze(value :: any)
	end
	return value
end

for _, list in BY_WAVE do
	freezeDeep(list)
end

-- List of the given wave; a wave above the last authored one gets the last list.
local function forWave(wave: number): List
	return BY_WAVE[math.clamp(math.floor(wave), 1, #BY_WAVE)]
end

return table.freeze({
	Wave1 = wave1,
	Wave2 = wave2,
	Wave3 = wave3,
	ForWave = forWave,
	Last = #BY_WAVE,
})
