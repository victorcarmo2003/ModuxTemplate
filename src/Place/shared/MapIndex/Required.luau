--!strict
-- What the MAP-01 binding must contain in wave 1 (architecture.md §18.4-§18.7). Runtime twin of the REQUIRED lists in
-- tools/assetplace/check_map01.luau (edit-time tool): change both together.
-- Counts that are game data come from Content (packages, toppings, bench spots, slot counts); map ids (PointId,
-- roads, crosswalks) come from MAP-01 and live here. Pure data: no Modux, Lync, Vide or self.Libs.
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

export type Route = { From: string, To: string, Name: string }

export type List = {
	Tags: { string }, -- wave 1 tags that must exist in the Workspace (§18.1)
	Points: { string }, -- PointId (§18.5)
	Nodes: { string }, -- NpcNode ids that must be in the graph (§18.6)
	Vehicle: string, -- the one vehicle that must exist (key of Content.Vehicles)
	Stations: { [string]: StationRule }, -- StationKind -> rule, one station of each inside the vehicle
	Toppings: { string }, -- ingredient keys of the toppings grid
	MapActions: { [string]: number }, -- PromptAction outside any vehicle, exact count (open sign)
	Packages: { string }, -- one buy_package anchor per key (Mart shelves)
	Bench: { [string]: string }, -- BenchSlot -> PromptAction (GEAR WALL)
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

const VEHICLE = Content.RunParams.StartVehicle -- "cart" (DEC-007)
const vehicle = Content.Vehicles.ByKey[VEHICLE]

-- Grill anchors: one grill_collect per roller slot at the highest level of the vehicle (DEC-201: 4 on L3).
local function maxGrillSlots(): number
	local most = 0
	for _, level in Content.Upgrades.ByKey.grill.Levels[VEHICLE] do
		most = math.max(most, level.Effects.GrillSlots or 0)
	end
	return most
end

-- GEAR WALL: B1..B5 from Upgrades.BenchSpot (DEC-106), S1 = special spot (bench_buy_item).
local function bench(): { [string]: string }
	const out: { [string]: string } = { S1 = "bench_buy_item" }
	for _, upgrade in Content.Upgrades.List do
		out[upgrade.BenchSpot] = "bench_buy_upgrade"
	end
	return out
end

const list: List = {
	Tags = { "MapBinding", "MapPoint", "NpcNode", "Vehicle", "Station", "Interactable" },
	Points = { "PS-1", "PS-2", "PS-3", "PS-4", "Q1", "Q2", "Q3", "Q4", "Q5", "D1", "SP-A", "EX-E", "OP-1" },
	Nodes = { "SP-A", "D1", "EX-E", "Q1", "Q2", "Q3", "Q4", "Q5" },
	Vehicle = VEHICLE,
	Stations = {
		sausage_stock = { Actions = { grill_place = 1, restock = 1 } },
		grill = { SlotAnchors = maxGrillSlots() },
		rail = { Slots = vehicle.RailSlots },
		bun_crate = { Actions = { bun_cut = 1, restock = 1 } },
		board = { Actions = { board_add_sausage = 1 }, Slots = vehicle.BoardSlots }, -- DEC-190
		toppings = { PerIngredient = { "topping_add", "restock" } },
		trash = { Actions = { discard = 1 } },
	},
	Toppings = Content.Ingredients.ToppingKeys,
	MapActions = { open_sign = 1 }, -- the sign stays on the map, not in the vehicle (MAP-01 §7.3)
	Packages = Content.Packages.Keys,
	Bench = bench(),
	StationGap = 2.5,
	ToppingGap = 2.0,
	ShelfGap = 2.5,
	BenchGap = 2.5,
	MaxEdge = 40,
	MaxNodes = 80,
	Roads = {
		{ Name = "Ninth", X0 = -136, X1 = 136, Z0 = -16, Z1 = 16 },
		{ Name = "Juniper North", X0 = -12, X1 = 12, Z0 = -152, Z1 = -16 },
		{ Name = "Juniper South", X0 = -12, X1 = 12, Z0 = 16, Z1 = 120 },
	},
	Crosswalks = {
		["CW-1"] = { Name = "CW-1", X0 = -12, X1 = 12, Z0 = 34, Z1 = 42 },
		["CW-2"] = { Name = "CW-2", X0 = -24, X1 = -12, Z0 = -16, Z1 = 16 },
		["CW-3"] = { Name = "CW-3", X0 = 54, X1 = 60, Z0 = -16, Z1 = 16 },
		["CW-4"] = { Name = "CW-4", X0 = 12, X1 = 24, Z0 = -16, Z1 = 16 },
	},
	Routes = {
		{ From = "SP-A", To = "Q5", Name = "ROUTE-SP-A" },
		{ From = "D1", To = "Q5", Name = "ROUTE-D1-IN" },
		{ From = "Q1", To = "EX-E", Name = "ROUTE-EXIT-E" },
		{ From = "Q1", To = "D1", Name = "ROUTE-EXIT-D1" },
	},
}

table.freeze(list :: any)
return list
