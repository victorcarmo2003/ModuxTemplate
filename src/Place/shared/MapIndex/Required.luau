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

-- XZ rectangle in studs (MAP-01 §4 coordinates).
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

const ROADS: { Rect } = {
	{ Name = "Ninth", X0 = -136, X1 = 136, Z0 = -16, Z1 = 16 },
	{ Name = "Juniper North", X0 = -12, X1 = 12, Z0 = -152, Z1 = -16 },
	{ Name = "Juniper South", X0 = -12, X1 = 12, Z0 = 16, Z1 = 120 },
}

const CROSSWALKS: { [string]: Rect } = {
	["CW-1"] = { Name = "CW-1", X0 = -12, X1 = 12, Z0 = 34, Z1 = 42 },
	["CW-2"] = { Name = "CW-2", X0 = -24, X1 = -12, Z0 = -16, Z1 = 16 },
	["CW-3"] = { Name = "CW-3", X0 = 54, X1 = 60, Z0 = -16, Z1 = 16 },
	["CW-4"] = { Name = "CW-4", X0 = 12, X1 = 24, Z0 = -16, Z1 = 16 },
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
		Ids = { "JL-01", "JL-02", "JL-03", "JL-04", "JL-05", "JL-06", "JL-07", "JL-08", "JL-09", "P-01" },
	},
}
-- thief routes from the street spawn to each lurk (MAP-01 §9.2; AvoidCrossings is the thief's own query)
const THIEF_ROUTES: { Route } = {
	{ From = "ST-R", To = "L1", Name = "ROUTE-THIEF-L1" },
	{ From = "ST-R", To = "L2", Name = "ROUTE-THIEF-L2" },
	{ From = "ST-R", To = "L3", Name = "ROUTE-THIEF-L3" },
}
wave2.Routes = concat(WAVE1_ROUTES, THIEF_ROUTES)

const BY_WAVE: { List } = { wave1, wave2 }

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
	ForWave = forWave,
	Last = #BY_WAVE,
})
