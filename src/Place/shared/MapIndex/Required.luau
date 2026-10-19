--!strict
-- What the MAP-01 binding must contain, per wave (architecture.md §18.4-§18.7, §19.22; TASK-010, TASK-048).
-- PlaceService validates ForWave(Content.RunParams.BindingWave). Runtime twin of the REQUIRED lists in
-- tools/assetplace/check_map01.luau (edit-time tool, level-designer): change both together.
-- Counts that are game data come from Content (packages, toppings, bench spots, slot counts, light zones); map ids
-- (PointId, PostId, roads, crosswalks) come from MAP-01 and live here. Pure data: no Modux, Lync, Vide or self.Libs.
-- A6 (architecture.md §19.26): nothing here is "the current vehicle". Vehicles lists every vehicle that must be
-- authored in the place; which one is current is VehicleService's state. Since 2026-10-12 (user decision, Provisional)
-- the Food Trailer is the only vehicle: the cart, the tarp, TRL-SALE and SIGN-T left the binding (CART stays as a legacy
-- point: the opening cutscene looks at it and the customers face it; it sits at the trailer service window).
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

-- Mart v2 Gear Stand (TASK-135; MAP-01 §18.4, §18.8). Soft rule: MapIndex.KioskNotes reports it as warnings, never
-- as a binding error, so the place keeps running while TASK-138 builds the kiosk (the client has fallbacks).
export type KioskRule = {
	PedestalTag: string, -- Content.Mart.Tags.Pedestal
	ShutterTag: string, -- Content.Mart.Tags.Shutter
	SlotAttribute: string, -- Content.Mart.Tags.Slot
	Pedestals: { string }, -- BenchSlot of every pedestal (Content.Mart.Pedestals)
	Shutters: { string }, -- Content.Mart.Doors[].Key
	OpalPoint: string, -- MapPoint of Opal's counter (Q-175 A)
	OpalFacing: Vector3?, -- WORLD direction OP-1 must face (MAP east = world -X, MAP-01 §18.4); nil = Mart off the map, OP-1 not checked
}

-- Pad tables (TASK-144; FEAT-037; MAP-01 "Mesas do Pad", TASK-149). Soft rule like the kiosk: MapIndex.SeatingNotes
-- reports warnings only, SeatingService falls back (search by name, runtime prompt anchor) until the binding exists.
export type SeatingRule = {
	Tag: string, -- Content.Seating.Binding.Tag (Model of each table)
	IndexAttribute: string, -- TableIndex 1..Tables, closest to Q1 first
	Tables: number,
	SeatPrefix: string,
	SeatCount: number, -- BaseParts Seat1..SeatN inside each table
	Anchors: { string }, -- optional anchors, noted when missing (Prompt_BuyTable, Prompt_CleanTable, Tray_Anchor)
}

export type List = {
	Wave: number,
	Tags: { string }, -- tags that must exist in the Workspace (§18.1, §19.22)
	Points: { string }, -- PointId (§18.5)
	Nodes: { string }, -- NpcNode ids that must be in the graph (§18.6)
	Vehicles: { [string]: VehicleRule }, -- key of Content.Vehicles -> rule; exactly one Model of each
	Toppings: { string }, -- ingredient keys of the toppings grid
	MapActions: { [string]: number }, -- PromptAction outside any vehicle, exact count (open sign)
	Packages: { string }, -- one buy_package anchor per key (Mart shelves); empty when the Mart is off the map (MART_ON)
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
	Kiosk: KioskRule, -- soft (warnings only), see KioskRule
	Seating: SeatingRule, -- soft (warnings only), see SeatingRule
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

-- The Mart (shelves BUY-*, checkout OP-1, door MKT-DOOR) left the map with the restaurant (owner 2026-10-17: it is kept in
-- ServerStorage.Mart, the lot is a plaza; stock comes from the phone / bays, SupplyService). Off = no BUY-* anchor, no OP-1
-- facing rule and the Mart points (MART_POINTS) not required. The Gear Stand (B1..B5, S1, shutters) stays required.
const MART_ON = Content.Restaurant.Supply.MartShelves and not Content.Restaurant.Rules.Enabled
const MART_POINTS = { "OP-1", "MKT-DOOR" }

-- GEAR WALL: B1..B5 from Upgrades.BenchSpot (DEC-106), S1 = special spot (bench_buy_item).
local function bench(): { [string]: string }
	const out: { [string]: string } = { S1 = "bench_buy_item" }
	for _, upgrade in Content.Upgrades.List do
		if upgrade.SoldAt == "Bench" then -- Pad tables are sold in place (TASK-144, Q-178 A)
			out[upgrade.BenchSpot] = "bench_buy_upgrade"
		end
	end
	return out
end

-- Gear Stand (Mart v2): pedestal slots and shutter keys come from Content.Mart.
local function kiosk(): KioskRule
	const pedestals: { string } = {}
	for _, row in Content.Mart.Pedestals do
		table.insert(pedestals, row.Slot)
	end
	const shutters: { string } = {}
	for _, door in Content.Mart.Doors do
		table.insert(shutters, door.Key)
	end
	return {
		PedestalTag = Content.Mart.Tags.Pedestal,
		ShutterTag = Content.Mart.Tags.Shutter,
		SlotAttribute = Content.Mart.Tags.Slot,
		Pedestals = pedestals,
		Shutters = shutters,
		OpalPoint = "OP-1",
		OpalFacing = if MART_ON then Vector3.new(-1, 0, 0) else nil,
	}
end

-- Pad tables: names from Content.Seating.Binding.
local function seating(): SeatingRule
	const binding = Content.Seating.Binding
	return {
		Tag = binding.Tag,
		IndexAttribute = binding.IndexAttribute,
		Tables = Content.Seating.Tables,
		SeatPrefix = binding.SeatPrefix,
		SeatCount = binding.SeatCount,
		Anchors = { binding.BuyAnchor, binding.CleanAnchor, binding.TrayAnchor },
	}
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
	["CW-1"] = mapRect("CW-1", -12, 12, 20, 28), -- owner moved the stripes 2026-10-12 (was Z 34..42)
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
			-- the service window lever TRL-SHUTTER is the shop (TASK-284, 2026-10-14; the red switch TRL-SWITCH-OPEN left)
			trailer = { Stations = kitchen("trailer"), Actions = { shutter_toggle = 1 } },
		},
		Toppings = Content.Ingredients.ToppingKeys,
		MapActions = {}, -- the shop lever is the trailer service window (TASK-284)
		Packages = if MART_ON then Content.Packages.Keys else {},
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
		Kiosk = kiosk(),
		Seating = seating(),
	}
end

-- Wave 1: the vehicle and its kitchen (§18.4-§18.7; the trailer since 2026-10-12).
const wave1 = base(1)

-- Wave 2 (§19.22): trailer kitchen with coffee machine, phone, light switch, light zones, street lights, night/revive/spectate/swap points, thief lurks.
-- Street bins (Prompt_Discard, DEC-200) are not counted: how many is open (Q-166).
const wave2 = base(2)
wave2.Tags = concat(WAVE1_TAGS, { "LightZone", "StreetLight" })
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
	trailer = { Stations = trailerKitchen, Actions = { shutter_toggle = 1, answer_phone = 1, switch_light = 1 } }, -- DEC-124, TASK-284
}
wave2.Tagged = {
	{ Tag = "LightZone", Attribute = "ZoneId", Ids = lightZones() },
	{
		Tag = "StreetLight",
		Attribute = "PostId",
		Ids = { "NL-01", "NL-02", "NL-03", "NL-04", "P-01" }, -- Walker / Hush posts (MAP-01 §5.6, 2026-10-10)
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

const STREET_POSTS = { "NL-01", "NL-02", "NL-03", "NL-04", "P-01" }

-- MapPoints a cutscene stands on, walks to or looks at (Marks, MoveTo with "{slot}" = 1..4, LookAt). LookAt on a
-- street post is the StreetLight itself (PostId), not a point. Client actors start and end on the explicit ones
-- (MAP-01 §11.3: Walt MKT-DOOR -> WALT-1, Raincoat Lady RL-1 -> RL-END).
local function cutscenePoints(): { string }
	const posts: { [string]: boolean } = {}
	for _, id in STREET_POSTS do
		posts[id] = true
	end
	-- Special targets of src/Cutscene/shared/Anchors.luau: "Sign" / "Poster" / "Phone" are found at runtime (tags,
	-- names) and need no MapPoint, nor does "Poster>o,s" (a spot beside the flyer); "a|b@f" / "a|b" is a point between
	-- two MapPoints, so only a and b are required.
	const anchors: { [string]: boolean } = { Sign = true, Poster = true, Phone = true }
	local function pointsOf(target: string): { string }
		if anchors[target] or posts[target] or string.find(target, "^Poster>") then
			return {}
		end
		const a, rest = string.match(target, "^([^|]+)|(.+)$")
		if a ~= nil and rest ~= nil then
			return { a, string.match(rest, "^([^@]+)@") or rest }
		end
		return { target }
	end
	local out: { string } = {}
	for _, scene in Content.Cutscenes.List do
		for _, mark in scene.Marks do
			out = union(out, pointsOf(mark))
		end
		for _, beat in scene.Beats do
			if beat.Kind ~= "MoveTo" and beat.Kind ~= "LookAt" then
				continue
			end
			if string.find(beat.Target, "{slot}", 1, true) then
				for slot = 1, 4 do
					const id = string.gsub(beat.Target, "{slot}", tostring(slot))
					out = union(out, pointsOf(id))
				end
			else
				out = union(out, pointsOf(beat.Target))
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
		-- safe spot (SS, §19.14), anomaly anchors and hidden actor spawns (MAP-01 §10.3), Walker last step (§5.6, fixed)
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
	trailer = {
		Stations = trailer3,
		-- service window lever TRL-SHUTTER (Prompt_Shutter) next to the phone (DEC-221) = the shop (TASK-284); H1..H4 left
		Actions = { answer_phone = 1, switch_light = 1, shutter_toggle = 1 },
	},
}
wave3.Tagged = concat(wave2.Tagged, {
	{ Tag = "AnomalyAnchor", Attribute = "AnchorId", Ids = { "WV-1", "WV-2", "WV-3" } },
	{ Tag = "TrafficPath", Attribute = "PathId", Ids = trafficPaths() },
	{ Tag = "TrafficLine", Attribute = "LineId", Ids = trafficLines() },
	{ Tag = "TrafficBox", Attribute = "BoxId", Ids = trafficBoxes() },
})
wave3.Routes = wave2.Routes

-- Restaurant (DEC-269..DEC-280; tech/restaurant-flow.md rev. 2 §4.1). Only with Content.Restaurant.Rules.Enabled: until the
-- restaurant map lands (track R1-E) the place has the trailer and none of these, so nothing new is required and the boot
-- stays the same. The legacy points (TRL, CART, Q1..Q5, PS-*, DROP-T, L3, AN-05, TRL-OUT, LZ-1, TBL-1..4) stay required.
-- Required when on: tags Tablet (TAB-1) and Pickup (PICKUP); MapPoint + NpcNode PU-1..n (n = largest active pickup line,
-- Rules.PickupSlots) chained to Q1 and to the exit. Optional (never required here): TAB-2 / Q1B, PLATE-n (PlateService binds
-- what exists), DT-* (wave R3), the supply hatch, phone prompt and VAN-* (FEAT-050).
-- The restaurant kitchen has repeated kinds (GRILL-n, CUT-n, COND-n) and no board / bun crate, so the "exactly one station
-- of each kind" rule of kitchen() does not fit it: only the coffee machine stays checked (KitchenService binds the rest by
-- tag + StationKind). Change tools/assetplace/check_map01.luau together when this goes on.
const restaurant = Content.Restaurant
if restaurant.Rules.Enabled then
	local pickups = 0
	for _, count in restaurant.Rules.PickupSlots do
		pickups = math.max(pickups, count)
	end
	const pickupIds = restaurant.PickupPoints(pickups)
	wave3.Tags = union(wave3.Tags, { restaurant.Binding.TabletTag, restaurant.Binding.PickupTag })
	wave3.Points = union(wave3.Points, pickupIds)
	wave3.Nodes = union(wave3.Nodes, pickupIds)
	wave3.Vehicles = {
		trailer = {
			Stations = { coffee_machine = { Actions = { brew_coffee = 1, restock = 1 } } },
			Actions = { answer_phone = 1, switch_light = 1, shutter_toggle = 1 },
		},
	}
	wave3.Routes = concat(wave2.Routes, {
		{ From = "Q1", To = pickupIds[#pickupIds], Name = "ROUTE-PICKUP-IN" },
		{ From = pickupIds[1], To = "EX-E", Name = "ROUTE-PICKUP-EXIT" },
	})
end

const BY_WAVE: { List } = { wave1, wave2, wave3 }

-- Mart off the map: its points stay optional (the MapPoints may still exist; OpalController prefers Att_Opal)
if not MART_ON then
	const drop: { [string]: boolean } = {}
	for _, id in MART_POINTS do
		drop[id] = true
	end
	for _, list in BY_WAVE do
		const kept: { string } = {}
		for _, id in list.Points do
			if not drop[id] then
				table.insert(kept, id)
			end
		end
		list.Points = kept
	end
	-- the Mart's LightZones (LightGroups "mart") leave the map with it
	const zones: { [string]: boolean } = {}
	for _, group in Content.LightGroups.List do
		if group.Key == "mart" then
			for _, id in group.Zones do
				zones[id] = true
			end
		end
	end
	for _, list in BY_WAVE do
		for _, rule in list.Tagged do
			if rule.Tag == "LightZone" then
				const ids: { string } = {}
				for _, id in rule.Ids do
					if not zones[id] then
						table.insert(ids, id)
					end
				end
				rule.Ids = ids
			end
		end
	end
end

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
