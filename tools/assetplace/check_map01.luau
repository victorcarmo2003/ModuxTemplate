--[[
	MAP-01 binding check, waves 1 + 2 + 3 (TASK-005, TASK-083, TASK-098; docs/tech/architecture.md §18.7, §19.22).
	Edit-mode tool, NOT gameplay code. Status: Draft (level-designer, 2026-10-10). §18.7 calls this tool
	check_binding.luau; this is that tool for MAP-01. The runtime twin is MapIndex.Validate +
	src/Place/shared/MapIndex/Required.luau (Required.Wave1 / Wave2 / Wave3 from TASK-048 / TASK-097): keep the lists
	below in sync with it (wave 2 list: MAP-01 §16.4; wave 3: MAP-01 §16.6). Wave 3 names that are game data
	(cutscene points, walk path nodes, traffic paths / lines / boxes) are read from the synced Content, like
	Required.Wave3 does; the embedded copies below are only used when Rojo has not synced Content.

	Wave 3 rules (opts.wave = 3):
	  2. trailer: shutter_toggle = 1 vehicle anchor (Prompt_Shutter on TRL-SHUTTER, DEC-221, TASK-132; no hide / Slot
	     any more, Required.Wave3 of TASK-129); points SS, AN-04/05/11/12,
	     AS-1..4, WALKER-10, W/E/JN/JS-IN/OUT, cutscene points; AnomalyAnchor WV-1..3; TrafficPath / TrafficLine /
	     TrafficBox ids once each
	 11. (wave 3) window (warn): Prompt_Shutter named and inside TRL-SHUTTER, next to Prompt_Switch (<= 4) and at
	     its height (+-1); exactly one Shutter_Hinge (Attachment on a BasePart, ClosedAngle set) in the trailer;
	     no H1..H4 / Prompt_Hide / Hide_Pose left (DEC-221); WV near the window
	     (warn); SS inside LZ-5; traffic: every path a Folder of Parts with Index 1..n, first node on its entry point,
	     last on an exit, crosses its route's stop lines in order, the first crosswalk line >= SpawnMinDist (55)
	     from the spawn, passes its conflict box; lines and boxes invisible / no collision; cutscene MoveTo chain
	     (slot 1) never crosses a carriageway outside the stripes (warn, MAP-01 P46)
	 10. (wave 3) WalkPaths: every node exists, consecutive nodes linked, Loop closes, no queue slot; Night / Any
	     paths never use a customer route node (warn, MAP-01 §9.1)
	 12. (wave 3, MAP-01 §9.8) every Flow.Spawns arrival is a node; customer spawn -> Q5 and Q1 -> exit routes exist;
	     spawn -> Q5 over 130 studs (10 s at 13) = warning
	 13. (wave 3, MAP-01 §9.8) spawn / despawn points out of sight of PS-1..4, Q1..Q5, MKT-DOOR, SS (raycast, 9 rays
	     per viewer, <= 200 studs): an edge point in sight = warning, a door point = info; AutoDoor leaves of
	     MKT-DOOR / D1 / SP-B present and not colliding. Ghost upgrade pieces (NoVisual) are reported as info (rule 9)
	 14. (wave 3, MAP-01 §5.6, 2026-10-10) Walker sight: every Walker post (StreetLight Group juniper_posts, Order 1..4)
	     and WALKER-10 must be seen from the trailer window (centre of the service window with the trailer on the Pad,
	     MAP-01 (41.5, 8.2, 36.6)): ERROR when no ray reaches the figure (feet+1, waist, head) or the lamp; from each
	     PS-N1..4 eye a miss is a warning. Same blockers as rule 13 (vehicles excluded: the window frame is measured
	     by hand, MAP-01 §5.6)

	 16. (FEAT-037, Q-209) SeatTable tables, warnings only: TableIndex 1..9 once each (Pad 1..5, Trailer 6..9), TableGroup
	     consistent with the index, Seat1..Seat4 BaseParts, an NpcNode within 20 studs (TBL-n)

	Reads only tags and attributes (never the bind script's data). Items of §18.7 (wave 1) + §19.22 (wave 2):
	  1. tags present (wave 1: MapBinding MapPoint NpcNode Vehicle Station Interactable UpgradePiece; wave 2: + LightZone
	     StreetLight VehicleCover); exactly one MapBinding; PointId / NodeId / ZoneId / PostId unique
	  2. every PointId / Station / Interactable required exists, per vehicle (cart; wave 2 also trailer with Rail 8,
	     board 3, coffee_machine) and vehicle-level prompts (answer_phone; trailer switch_light, buy_trailer)
	  3. StationKind, PromptAction, Ingredient, Package, Vehicle, BenchSlot, LightZone/StreetLight Group are valid
	     Content keys (ReplicatedStorage.shared.Content when Rojo has synced it, else the lists embedded below; a
	     wave-2 key missing from a synced Content is a warning "TASK-047 pending", not an error)
	  4. anchors of different owners in the same vehicle >= 2.5 apart; toppings grid >= 2.0 (same ingredient
	     exempt); Mart shelves >= 4.0 (error, Mart v2 MAP-01 §18.10); bench (Gear Stand) >= 2.5
	 15. (Mart v2, TASK-138; MAP-01 §18.3/§18.4/§18.10) one GearPedestal per Slot B1..B5/S1 with its Prompt_Buy inside
	     (error), Slot_/Price_Anchor_ (warn); one GearShutter per Slot L/C/R with Slat_* (error) and Roll (warn);
	     Att_Opal found like OpalController does, on OP-1 and facing MAP east (warn); OP-1 FACING = east; shelf
	     heights 3.0..4.5 and bench prompts reachable from the rail line (warn); GEAR_WALL / checkout OP-1 placed (warn)
	  5. Station under a Vehicle; every Model that is/contains a tagged instance is Persistent; nothing tagged
	     outside the Workspace; Interactable = Attachment or invisible non-colliding BasePart; LightZone invisible
	  6. graph: connected, Links resolve, no space in Links, edge <= 40, <= 80 nodes, no edge over a carriageway
	     except a crosswalk edge, queue chain Q5-Q4-Q3-Q2-Q1; wave 2: thief routes exist without queue slots and
	     without crosswalk edges (MAP-01 §9.2: never crosses a road)
	  7. pivots of the counter stations: cart at y 3.45 (DEC-157, Provisional until Q-153); trailer at pivot + 4.6 (2026-10-11, was 5.5)
	  9. (TASK-085) UpgradePiece: one Model per Content.Upgrades row with Part ~= "" in each vehicle of the wave, inside
	     that Vehicle, valid Upgrade / integer Level, nothing interactive inside (T38). Warnings: authored state not
	     "StartLevel only", invisible piece parts without UpgHidden, fixed grill / cooler / Lock / TRL-LIGHTS parts
	     still visible, grill Slot anchors off the kit Anchor_Slot<n>
	  8. zero errors -> writes on the MapBinding root: BindingVersion (+1 when the binding hash changes),
	     PointCount, NodeCount, InteractableCount (+ BindingHash, tool metadata)
	Warnings (do not block): missing named fittings, obstacles on edges (knee/chest raycast), MapPoint off the floor
	/ wrong facing, A* routes that shortcut through the queue, vehicles not parked at their start pose, StreetBin
	without anchor (DEC-200: not in Required.Wave2, Q-166 b).

	"Carriageway" rects (item 6) = the asphalt of Z-03 / Z-07 / Z-08: Ninth X -136..136 Z -16..16, Juniper North
	X -12..12 Z -152..-16, Juniper South X -12..12 Z 16..120.

	Usage (edit mode):
		local Check = require(<this module>)
		Check.run({ wave = 3 })   -- prints and returns (report, errorCount); opts { wave = 1 | 2 | 3 (default 3), write = false }
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Check = {}

---------------------------------------------------------------------------------------------------
-- Required (keep in sync with MapIndex/Required.luau: Wave1, Wave2)
---------------------------------------------------------------------------------------------------

-- UpgradePiece (§18.1, wave 1): kit TASK-084, bound by bind_pieces.luau (TASK-085). Rule 9 below.
local EDIT_TAGS_W1 = { "MapBinding", "MapPoint", "NpcNode", "Vehicle", "Station", "Interactable", "UpgradePiece" }
local EDIT_TAGS_W2 = { "LightZone", "StreetLight" } -- VehicleCover left with the cart (2026-10-12)
local EDIT_TAGS_W3 = { "AnomalyAnchor", "TrafficPath", "TrafficLine", "TrafficBox" }
local OPTIONAL_TAGS = { "StreetBin", "GearPedestal", "GearShutter" } -- StreetBin: DEC-200 / T60, never required (Q-166 b); Gear*: rule 15

-- Mart v2 "Gear Stand" (rule 15; MAP-01 §18.3, §18.4, §18.10; Content.Mart; MapIndex.KioskNotes is the soft runtime twin)
local MART_PEDESTALS = { "B1", "B2", "B3", "B4", "B5", "S1" } -- Content.Mart.Pedestals
local MART_SHUTTERS = { "L", "C", "R" } -- Content.Mart.Doors[].Key
local MART_FLOOR = 0.4
local SHELF_GAP = 4.0 -- §18.10: purchase anchors >= 4 apart (error under it)
local SHELF_H = { 3.0, 4.5 } -- §18.10: anchor height above the Mart floor (warning outside)
local OPAL_AT = Vector3.new(-98, 0, 47.887) -- MAP-01: Att_Opal / OP-1 (WORLD (98, 20))
local KIOSK_STAND_X = -93.5 -- MAP-01 X of the glass rail line (WORLD 93.5): players stand east of it
local KIOSK_REACH = 3.0 -- studs (XZ) from the rail line to a pedestal prompt before a warning
local OPAL_SEARCH_DEPTH = 4 -- same as OpalController KIOSK_SEARCH_DEPTH

-- Upgrade pieces expected per vehicle (copy of src/Shared/Content/Upgrades.luau rows with Part ~= ""; a synced
-- Content.Upgrades wins). start = StartLevel (the piece visible in the authored place).
local PIECE_ROWS_EMBEDDED = (function()
	local rows = {}
	for _, v in { "trailer" } do
		for level = 1, 3 do
			table.insert(rows, { upgrade = "grill", vehicle = v, level = level, part = "Grill_L" .. level, start = 1 })
			table.insert(rows, { upgrade = "cooler", vehicle = v, level = level, part = "Cooler_L" .. level, start = 1 })
			table.insert(rows, { upgrade = "counter", vehicle = v, level = level, part = "Counter_L" .. level, start = 1 })
		end
		table.insert(rows, { upgrade = "cash_drawer_lock", vehicle = v, level = 1, part = "DrawerLock_L1", start = 0 })
	end
	table.insert(rows, { upgrade = "trailer_lights", vehicle = "trailer", level = 1, part = "TrailerLights_L1", start = 0 })
	return rows
end)()
-- fixed models whose visible parts must be gone once the pieces exist (bind_pieces hides them)
local PIECE_FIXED = {
	{ kind = "grill", what = "all" },
	{ kind = "sausage_stock", what = "all" },
	{ ids = { "DRAWER", "TRL-DRAWER" }, what = "Lock" },
	{ ids = { "TRL-LIGHTS" }, what = "all" },
}

local POINTS_W1 = { "PS-1", "PS-2", "PS-3", "PS-4", "Q1", "Q2", "Q3", "Q4", "Q5", "D1", "SP-A", "EX-E", "OP-1" }
local POINTS_W2 = {
	"PS-N1", "PS-N2", "PS-N3", "PS-N4",
	"REV-1", "REV-2", "REV-3", "REV-4",
	"TRL", "CART", -- CART = legacy point at the trailer window (cutscene focus, customers face it)
	"SPEC-P", "SPEC-M",
	"DROP-T",
	"L1", "L2", "L3", "ST-R",
}
local NODES_W1 = { "SP-A", "D1", "EX-E", "Q1", "Q2", "Q3", "Q4", "Q5" }
local NODES_W2 = { "ST-R", "L1", "L2", "L3" }

-- wave 3 (Required.Wave3): map-only points; cutscene points come from Content.Cutscenes (embedded copy below)
local POINTS_W3 = {
	"SS", "AN-04", "AN-05", "AN-11", "AN-12", "AS-1", "AS-2", "AS-3", "AS-4", "WALKER-10",
	"W-IN", "W-OUT", "E-IN", "E-OUT", "JN-IN", "JN-OUT", "JS-IN", "JS-OUT",
	"MKT-DOOR", "WALT-1", "RL-1", "RL-END",
}
local CUTSCENE_POINTS_EMBEDDED = {
	"CutsceneMark1", "CutsceneMark2", "CutsceneMark3", "CutsceneMark4", "CS-2", "CS-3", "CS-4", "CS-5",
	"CS-P1", "CS-P2", "CS-P3", "CS-P4", "CART", "SS-1", "SS-2", "SS-3", "SS-4", "WALT-1", "RL-END",
}
-- 2026-10-10 (user): Walker posts NL-01..04 on the Ninth north curb, seen from the trailer window (MAP-01 §5.6);
-- same list as Required.luau (src/Place).
local STREET_POSTS = { "NL-01", "NL-02", "NL-03", "NL-04", "P-01" }
local WINDOWS_W3 = { ["WV-1"] = 31, ["WV-2"] = 38, ["WV-3"] = 45 } -- AnchorId -> window centre X (AST-045)
-- Traffic, embedded copy of Content.Traffic (routes: entry point, stop lines in order, conflict boxes)
local TRAFFIC_EMBEDDED = {
	routes = {
		{ path = "TR-1", lane = "W-IN", stops = { { "Crosswalk", "SL-W" }, { "Crosswalk", "SL-3W" } } },
		{ path = "TR-2", lane = "E-IN", stops = { { "Crosswalk", "SL-3E" }, { "Crosswalk", "SL-E" } } },
		{ path = "TR-3", lane = "JN-IN", stops = { { "Pare", "SL-N" }, { "Crosswalk", "SL-N" }, { "Crosswalk", "SL-3W" } } },
		{ path = "TR-4", lane = "JN-IN", stops = { { "Pare", "SL-N" }, { "Crosswalk", "SL-N" } } },
		{ path = "TR-5", lane = "W-IN", stops = { { "Crosswalk", "SL-W" } } },
		{ path = "TR-6", lane = "E-IN", stops = { { "Crosswalk", "SL-3E" }, { "Crosswalk", "SL-E" } } },
		{ path = "TR-7", lane = "JS-IN", stops = { { "Crosswalk", "SL-1S" }, { "Pare", "SL-S" } } },
		{ path = "TR-8", lane = "JN-IN", stops = { { "Pare", "SL-N" }, { "Crosswalk", "SL-1N" } } },
		{ path = "TR-9", lane = "W-IN", stops = { { "Crosswalk", "SL-W" }, { "Crosswalk", "SL-1N" } } },
		{ path = "TR-10", lane = "JS-IN", stops = { { "Crosswalk", "SL-1S" }, { "Pare", "SL-S" }, { "Crosswalk", "SL-S" }, { "Crosswalk", "SL-3W" } } },
	},
	lines = { "SL-1N", "SL-1S", "SL-3E", "SL-3W", "SL-E", "SL-N", "SL-S", "SL-W" },
	boxes = { "X-T", "CW-1", "CW-2", "CW-3", "CW-4" },
	spawnMinDist = 55,
}
local EXITS = { "W-OUT", "E-OUT", "JN-OUT", "JS-OUT" }

-- MAP-01 frame (map_frame.luau, 2026-10-10): the place is turned 180 in Y. The literals of this file stay in MAP-01
-- coordinates and are converted ONCE here (directions FD, rectangles box) or at the read (M) / probe (F).
local MAP_FRAME_URL = "http://127.0.0.1:8772/tools/assetplace/map_frame.luau"
local function loadMapFrame(): any
	local sib = script and script.Parent and script.Parent:FindFirstChild("map_frame")
	if sib and sib:IsA("ModuleScript") then
		return (require :: any)(sib)
	end
	local ms = Instance.new("ModuleScript")
	ms.Name = "map_frame"
	ms.Source = game:GetService("HttpService"):GetAsync(MAP_FRAME_URL, true)
	return (require :: any)(ms)
end
local MapFrame = loadMapFrame()
local F: (Vector3) -> Vector3 = MapFrame.F
local M: (Vector3) -> Vector3 = MapFrame.M
local FD: (Vector3) -> Vector3 = MapFrame.FD

-- MAP-01 north / south / east / west as WORLD directions
local N, S, E, W = FD(Vector3.new(0, 0, -1)), FD(Vector3.new(0, 0, 1)), FD(Vector3.new(1, 0, 0)), FD(Vector3.new(-1, 0, 0))
local FACING = { -- expected LookVector of points (warn when > 10 degrees off)
	["PS-1"] = N, ["PS-2"] = N, ["PS-3"] = N, ["PS-4"] = N,
	Q1 = S, Q2 = E, Q3 = E, Q4 = E, Q5 = E,
	["OP-1"] = E, -- Mart v2 (MAP-01 §18.4): behind the Gear Stand counter, facing the store (MAP east = WORLD -X)
	["PS-N1"] = N, ["PS-N2"] = N, ["PS-N3"] = N, ["PS-N4"] = N,
	["REV-1"] = S, ["REV-2"] = S, ["REV-3"] = S, ["REV-4"] = S,
	TRL = N, CART = N, ["DROP-T"] = N, ["ST-R"] = N,
	-- wave 3
	["AN-04"] = S, ["AN-05"] = N, ["AN-11"] = S, ["AN-12"] = S,
	["W-IN"] = E, ["W-OUT"] = W, ["E-IN"] = W, ["E-OUT"] = E,
	["JN-IN"] = S, ["JN-OUT"] = N, ["JS-IN"] = N, ["JS-OUT"] = S,
	CutsceneMark1 = E, CutsceneMark2 = E, CutsceneMark3 = E, CutsceneMark4 = E,
	["SS-1"] = W, ["SS-2"] = W, ["SS-3"] = W, ["SS-4"] = W, ["WALT-1"] = E,
}

local TOPPING_KEYS = { "ketchup", "mustard", "cheese", "bacon", "potato_sticks", "cream_cheese" }

-- Per StationKind: actions with exact count (keyed), slot-attachment count, interactable slot range.
-- slots = nil -> taken from the vehicle (Vehicles[v].RailSlots / BoardSlots).
local STATION_RULES = {
	sausage_stock = { actions = { grill_place = 1, restock = 1 } },
	grill = { slotInteractables = 4 }, -- grill_collect with Slot 1..4 (DEC-201)
	rail = { slotsFrom = "RailSlots" },
	bun_crate = { actions = { bun_cut = 1, restock = 1 } },
	board = { actions = { board_add_sausage = 1 }, slotsFrom = "BoardSlots" }, -- DEC-190, DEC-215
	toppings = { perIngredient = { "topping_add", "restock" } },
	trash = { actions = { discard = 1 } },
	coffee_machine = { actions = { brew_coffee = 1, restock = 1 } }, -- §19.8
}
local VEHICLE_SPEC = {
	trailer = {
		wave = 2,
		kinds = { "sausage_stock", "grill", "rail", "bun_crate", "board", "toppings", "trash", "coffee_machine" },
		-- wave 3: service window button TRL-SHUTTER (DEC-221; Required.Wave3 of TASK-129); hide H1..H4 left
		own = { [2] = { answer_phone = 1, switch_light = 1 }, [3] = { shutter_toggle = 1 } },
		slots = { RailSlots = 8, BoardSlots = 3 },
		counter = { ids = { "TRL-G", "TRL-R", "TRL-B", "TRL-T", "TRL-K", "TRL-DRAWER" }, relY = 4.6 },
	},
}
local REQUIRED_PACKAGES = {
	"pack_sausages", "pack_buns", "pack_ketchup", "pack_mustard", "pack_cheese",
	"pack_bacon", "pack_potato_sticks", "pack_cream_cheese", "pack_coffee",
}
local REQUIRED_BENCH = { B1 = "bench_buy_upgrade", B2 = "bench_buy_upgrade", B3 = "bench_buy_upgrade", B4 = "bench_buy_upgrade", B5 = "bench_buy_upgrade", S1 = "bench_buy_item" }
local NEVER_TAGGED = { Prompt_Rail = true, Prompt_Serve = true, Prompt_Drawer = true, Prompt_Grill = true }
local COUNTER_TOL = 0.05

-- wave 2 light binding (MAP-01 §10.2, §5.6; content-data.md §6.4)
local ZONES = { -- ZoneId -> Group, shape
	["LZ-1"] = { group = "trailer_interior", shape = "Block" },
	["LZ-2"] = { group = "trailer_interior", shape = "Block" },
	["LZ-3"] = { group = "trailer_lights", shape = "Ball" },
	["LZ-4"] = { group = "mart", shape = "Block" },
	["LZ-5"] = { group = "mart", shape = "Ball" },
}
local POSTS = { -- PostId -> Order (Hush order: NL-01 first, P-01 last; Walker step = Order - 1 for Order 1..4)
	["NL-01"] = 1, ["NL-02"] = 2, ["NL-03"] = 3, ["NL-04"] = 4, ["P-01"] = 5,
}
local WALKER_POSTS = 4 -- Rules/ANM-007 Steps: Order 1..4 are Walker steps, WALKER-10 is the last one
local TRAILER_WINDOW = Vector3.new(41.5, 8.2, 36.6) -- MAP-01: centre of the service window, trailer on the Pad (§7.2)
local POST_GROUP = "juniper_posts"

-- MAP-01 rectangles -> world rectangles (MapFrame.box)
local ROADS = {
	MapFrame.box({ name = "Ninth", x0 = -136, x1 = 136, z0 = -16, z1 = 16 }),
	MapFrame.box({ name = "Juniper North", x0 = -12, x1 = 12, z0 = -152, z1 = -16 }),
	MapFrame.box({ name = "Juniper South", x0 = -12, x1 = 12, z0 = 16, z1 = 120 }),
}
local CROSSWALKS = {
	["CW-1"] = MapFrame.box({ x0 = -12, x1 = 12, z0 = 34, z1 = 42 }),
	["CW-2"] = MapFrame.box({ x0 = -24, x1 = -12, z0 = -16, z1 = 16 }),
	["CW-3"] = MapFrame.box({ x0 = 54, x1 = 60, z0 = -16, z1 = 16 }),
	["CW-4"] = MapFrame.box({ x0 = 12, x1 = 24, z0 = -16, z1 = 16 }),
}
local ROUTES_W1 = { -- blockout routes of §18.6, as A* queries
	{ "SP-A", "Q5", "ROUTE-SP-A" },
	{ "D1", "Q5", "ROUTE-D1-IN" },
	{ "Q1", "EX-E", "ROUTE-EXIT-E" },
	{ "Q1", "D1", "ROUTE-EXIT-D1" },
	-- MAP-01 §9.8 customer arrivals (Content.Flow.Spawns); they count as customer route nodes for rule 10
	{ "DR-APT", "Q5", "ROUTE-DR-APT" },
	{ "SP-S", "Q5", "ROUTE-SP-S" },
}
local ROUTES_W2 = { -- thief (MAP-01 §9.2): never a queue slot, never a crosswalk edge (AvoidCrossings)
	{ "ST-R", "L1", "THIEF-IN-L1" },
	{ "ST-R", "L2", "THIEF-IN-L2" },
	{ "ST-R", "L3", "THIEF-IN-L3" },
	{ "L1", "ST-R", "THIEF-OUT-L1" },
	{ "L2", "EX-E", "THIEF-OUT-L2" },
	{ "L3", "ST-R", "THIEF-OUT-L3" },
}
local MAX_EDGE = 40
local MAX_NODES = 80
-- MAP-01 §9.8 (2026-10-10, Provisional): spawn / despawn rules
local SPAWN_ROUTE_MAX = 130 -- studs spawn -> Q5 (10 s at 13 studs/s)
local SIGHT_VIEWERS = { "PS-1", "PS-2", "PS-3", "PS-4", "Q1", "Q2", "Q3", "Q4", "Q5", "MKT-DOOR", "SS" } -- Pad, queue, Mart
local SIGHT_EYE = 4.5 -- R6 eye over the floor point
local SIGHT_MAX = 200 -- studs: night fog end (MAP-01 §13); farther counts as out of sight
local SIGHT_SEE_THROUGH = 0.3 -- parts at least this transparent do not block (glass, ghosts)

-- Embedded Content keys (content-data.md v5 §3.3, §3.4, §3.6, §3.8, §3.18, §6.4, §6.9) for when Rojo has not
-- synced Content. WAVE2 = keys that a synced Content may still lack until TASK-047 lands (warning, not error).
local FALLBACK = {
	Stations = { "sausage_stock", "grill", "rail", "bun_crate", "board", "toppings", "trash", "coffee_machine" },
	Actions = {
		"open_sign", "grill_place", "grill_collect", "bun_cut", "board_add_sausage", "topping_add", "discard",
		"take_order", "serve", "refuse", "restock", "buy_package", "bench_buy_upgrade", "bench_buy_item",
		"brew_coffee", "give_coffee", "switch_light", "safe_spot", "pick_up_item",
		"answer_phone", "get_up", "shutter_toggle", -- "hide" left with DEC-221 (TASK-132)
	},
	Ingredients = { "bun", "sausage", "ketchup", "mustard", "cheese", "bacon", "potato_sticks", "cream_cheese", "coffee" },
	Packages = REQUIRED_PACKAGES,
	Vehicles = { "trailer" },
	LightGroups = { "mart", "trailer_interior", "trailer_lights", "juniper_posts" },
	Upgrades = { "grill", "cooler", "counter", "cash_drawer_lock", "trailer_lights" },
}
local WAVE2_KEYS = {
	Actions = { answer_phone = true, get_up = true, brew_coffee = true, switch_light = true },
	LightGroups = { mart = true, trailer_interior = true, trailer_lights = true, juniper_posts = true },
	Stations = { coffee_machine = true },
}

---------------------------------------------------------------------------------------------------
-- Report
---------------------------------------------------------------------------------------------------

local errs: { string } = {}
local warns: { string } = {}
local infos: { string } = {}

local function err(s: string)
	table.insert(errs, s)
end
local function warn_(s: string)
	table.insert(warns, s)
end
local function info(s: string)
	table.insert(infos, s)
end

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------

local function set(list: { string }): { [string]: boolean }
	local s = {}
	for _, v in list do
		s[v] = true
	end
	return s
end

local function concat(a: { any }, b: { any }): { any }
	local out = table.clone(a)
	for _, v in b do
		table.insert(out, v)
	end
	return out
end

local function fmtV(v: Vector3): string
	return ("(%.2f, %.2f, %.2f)"):format(v.X, v.Y, v.Z)
end

local function pos(a: Instance): Vector3
	if a:IsA("Attachment") then
		return a.WorldPosition
	elseif a:IsA("BasePart") then
		return a.Position
	elseif a:IsA("PVInstance") then
		return (a :: any):GetPivot().Position
	end
	return Vector3.zero
end

local function tagged(tag: string): { Instance }
	local out = {}
	for _, i in CollectionService:GetTagged(tag) do
		if i:IsDescendantOf(Workspace) then
			table.insert(out, i)
		end
	end
	table.sort(out, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)
	return out
end

local function ancestorWithTag(i: Instance, tag: string): Instance?
	local n = i.Parent
	while n and n ~= game do
		if CollectionService:HasTag(n, tag) then
			return n
		end
		n = n.Parent
	end
	return nil
end

local function ownerOf(i: Instance): Instance?
	local st = ancestorWithTag(i, "Station")
	if st then
		return st
	end
	local n = i.Parent
	while n and n ~= Workspace do
		if n:IsA("Model") then
			return n
		end
		n = n.Parent
	end
	return nil
end

local function name(i: Instance?): string
	return if i then i:GetFullName() else "?"
end

type Keys = { keys: { [string]: boolean }, fromContent: boolean }

local loadedContent: any = nil

local function loadContent(): ({ [string]: Keys }, string)
	local out = {}
	local src = {}
	local shared = ReplicatedStorage:FindFirstChild("shared")
	local folder = shared and shared:FindFirstChild("Content")
	local whole: any = nil
	if folder and folder:IsA("ModuleScript") then
		local ok, res = pcall(require, folder)
		if ok then
			whole = res
		end
	end
	loadedContent = whole
	for tbl, fallback in FALLBACK do
		local keys: { [string]: boolean }? = nil
		local t: any = whole and whole[tbl]
		if t == nil and folder then
			local m = folder:FindFirstChild(tbl)
			if m and m:IsA("ModuleScript") then
				local ok, res = pcall(require, m)
				if ok then
					t = res
				end
			end
		end
		if type(t) == "table" and type(t.ByKey) == "table" then
			keys = {}
			for k in t.ByKey do
				(keys :: any)[k] = true
			end
			table.insert(src, tbl .. "=Content")
			out[tbl] = { keys = keys :: any, fromContent = true }
		else
			table.insert(src, tbl .. "=embedded")
			out[tbl] = { keys = set(fallback), fromContent = false }
		end
	end
	return out, table.concat(src, ", ")
end

-- RailSlots / BoardSlots of a vehicle: Content when synced, else the embedded numbers.
local function vehicleSlots(v: string, field: string): number
	local c = loadedContent
	local row = c and c.Vehicles and c.Vehicles.ByKey and c.Vehicles.ByKey[v]
	if row and type(row[field]) == "number" then
		return row[field]
	end
	return (VEHICLE_SPEC :: any)[v].slots[field]
end

local function inRect(x: number, z: number, r: any): boolean
	local e = 0.01
	return x > r.x0 + e and x < r.x1 - e and z > r.z0 + e and z < r.z1 - e
end

-- sampled segment test (XZ): returns the road name it enters, plus whether every in-road sample is in `cw`
local function crossesRoad(a: Vector3, b: Vector3, cw: any?): (string?, boolean)
	local len = ((b - a) * Vector3.new(1, 0, 1)).Magnitude
	local steps = math.max(1, math.ceil(len / 0.25))
	local hitRoad: string? = nil
	local allInCw = true
	for i = 0, steps do
		local t = i / steps
		local x, z = a.X + (b.X - a.X) * t, a.Z + (b.Z - a.Z) * t
		for _, r in ROADS do
			if inRect(x, z, r) then
				hitRoad = hitRoad or r.name
				if not (cw and x >= cw.x0 - 0.01 and x <= cw.x1 + 0.01 and z >= cw.z0 - 0.01 and z <= cw.z1 + 0.01) then
					allInCw = false
				end
			end
		end
	end
	return hitRoad, allInCw
end

local function obstacle(a: Vector3, b: Vector3, exclude: { Instance }): Instance?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	for _, h in { 1.2, 2.6 } do
		local ex = table.clone(exclude)
		for _ = 1, 16 do
			params.FilterDescendantsInstances = ex
			local o = a + Vector3.new(0, h, 0)
			local hit = Workspace:Raycast(o, (b + Vector3.new(0, h, 0)) - o, params)
			if not hit then
				break
			end
			if hit.Instance.CanCollide then
				return hit.Instance
			end
			table.insert(ex, hit.Instance)
		end
	end
	return nil
end

local function djb2(s: string): number
	local h = 5381
	for i = 1, #s do
		h = (h * 33 + string.byte(s, i)) % 4294967296
	end
	return h
end

local function isHidden(m: Instance): boolean
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			return false
		end
	end
	return true
end

---------------------------------------------------------------------------------------------------
-- Checks
---------------------------------------------------------------------------------------------------

local WAVE = 3
local function editTags(): { string }
	if WAVE >= 3 then
		return concat(concat(EDIT_TAGS_W1, EDIT_TAGS_W2), EDIT_TAGS_W3)
	end
	return if WAVE >= 2 then concat(EDIT_TAGS_W1, EDIT_TAGS_W2) else EDIT_TAGS_W1
end

-- Adds the values of `extra` missing from `list`, keeping the order (Required.union).
local function union(list: { string }, extra: { string }): { string }
	local out = table.clone(list)
	local seen: { [string]: boolean } = {}
	for _, v in out do
		seen[v] = true
	end
	for _, v in extra do
		if not seen[v] then
			seen[v] = true
			table.insert(out, v)
		end
	end
	return out
end

-- Wave 3 names that are game data (Required.Wave3 derives them from Content; embedded copies otherwise).
local function cutscenePoints(): ({ string }, string)
	local c = loadedContent
	local cs = c and c.Cutscenes
	if not (type(cs) == "table" and type(cs.List) == "table") then
		return CUTSCENE_POINTS_EMBEDDED, "embedded"
	end
	local posts = set(STREET_POSTS)
	-- special targets of src/Cutscene/shared/Anchors.luau (same rule as Required.luau): "Sign" / "Poster" / "Phone"
	-- need no MapPoint; "a|b@f" / "a|b" needs only a and b
	local anchors = { Sign = true, Poster = true, Phone = true }
	local function pointsOf(target: string): { string }
		if anchors[target] or posts[target] then
			return {}
		end
		local a, rest = string.match(target, "^([^|]+)|(.+)$")
		if a ~= nil and rest ~= nil then
			return { a, string.match(rest, "^([^@]+)@") or rest }
		end
		return { target }
	end
	local out: { string } = {}
	for _, scene in cs.List do
		out = union(out, scene.Marks or {})
		for _, beat in scene.Beats or {} do
			if beat.Kind == "MoveTo" or beat.Kind == "LookAt" then
				if string.find(beat.Target, "{slot}", 1, true) then
					for slot = 1, 4 do
						out = union(out, pointsOf((string.gsub(beat.Target, "{slot}", tostring(slot)))))
					end
				else
					out = union(out, pointsOf(beat.Target))
				end
			end
		end
	end
	return out, "Content"
end

-- WalkPaths rows (Content only: the rows live in src/Shared/Content/WalkPaths.luau, TASK-098).
local function walkPaths(): { any }?
	local c = loadedContent
	local wp = c and c.WalkPaths
	if type(wp) == "table" and type(wp.List) == "table" then
		return wp.List
	end
	return nil
end

-- Traffic ids: { routes = { path, lane, stops = { { kind, line } }, conflicts }, lines, boxes, spawnMinDist }.
local function trafficSpec(): (any, string)
	local c = loadedContent
	local t = c and c.Traffic
	if not (type(t) == "table" and type(t.Routes) == "table" and type(t.Routes.List) == "table") then
		local out = table.clone(TRAFFIC_EMBEDDED)
		for _, r in out.routes do
			r.conflicts = r.conflicts or { "X-T" }
		end
		return out, "embedded"
	end
	local routes = {}
	local lines: { string } = {}
	local boxes: { string } = {}
	for _, r in t.Routes.List do
		local stops = {}
		for _, s in r.Stops do
			table.insert(stops, { s.Kind, s.Line })
			lines = union(lines, { s.Line })
		end
		local conflicts = {}
		for _, k in r.Conflicts or {} do
			local row = t.Conflicts and t.Conflicts.ByKey and t.Conflicts.ByKey[k]
			table.insert(conflicts, if row then row.Box else k)
		end
		table.insert(routes, { path = r.Path, lane = r.Lane, stops = stops, conflicts = conflicts })
	end
	for _, cw in (t.Crosswalks and t.Crosswalks.List) or {} do
		for _, l in cw.Lines do
			lines = union(lines, { l })
		end
		boxes = union(boxes, { cw.Box })
	end
	for _, k in (t.Conflicts and t.Conflicts.List) or {} do
		boxes = union(boxes, { k.Box })
	end
	local minDist = (t.Crossing and t.Crossing.SpawnMinDist) or TRAFFIC_EMBEDDED.spawnMinDist
	return { routes = routes, lines = lines, boxes = boxes, spawnMinDist = minDist }, "Content"
end

local function checkTags(): Instance?
	for _, t in editTags() do
		if #tagged(t) == 0 then
			err(("1: no instance with tag %s in the Workspace"):format(t))
		end
	end
	local roots = tagged("MapBinding")
	if #roots ~= 1 then
		err(("1: %d MapBinding roots in the Workspace (need exactly 1)"):format(#roots))
	end
	-- 5: nothing tagged outside the Workspace
	for _, t in concat(editTags(), OPTIONAL_TAGS) do
		for _, i in CollectionService:GetTagged(t) do
			if not i:IsDescendantOf(Workspace) then
				err(("5: %s tagged %s outside the Workspace"):format(name(i), t))
			end
		end
	end
	return roots[1]
end

local function checkPoints(root: Instance?): { [string]: Instance }
	local byId: { [string]: Instance } = {}
	for _, p in tagged("MapPoint") do
		local id = p:GetAttribute("PointId")
		if typeof(id) ~= "string" or id == "" then
			err(("2: MapPoint %s without PointId"):format(name(p)))
			continue
		end
		if byId[id] then
			err(("1: PointId %s duplicated (%s, %s)"):format(id, name(byId[id]), name(p)))
		end
		byId[id] = p
		if root and not p:IsDescendantOf(root) then
			err(("5: MapPoint %s outside the MapBinding root"):format(id))
		end
		if not p:IsA("BasePart") then
			err(("5: MapPoint %s is a %s (must be a Part)"):format(id, p.ClassName))
			continue
		end
		local bp = p :: BasePart
		if not bp.Anchored or bp.Transparency < 1 or bp.CanCollide or bp.CanQuery or bp.CanTouch then
			warn_(("MapPoint %s: must be Anchored, Transparency 1, CanCollide/CanQuery/CanTouch false"):format(id))
		end
		local look = bp.CFrame.LookVector
		if math.abs(look.Y) > 0.01 then
			err(("5: MapPoint %s LookVector not horizontal (%s)"):format(id, fmtV(look)))
		end
		local want = FACING[id]
		if want and look:Dot(want) < math.cos(math.rad(10)) then
			warn_(("MapPoint %s faces %s, expected %s (MAP-01 §5)"):format(id, fmtV(look), fmtV(want)))
		end
	end
	local req = if WAVE >= 2 then concat(POINTS_W1, POINTS_W2) else POINTS_W1
	if WAVE >= 3 then
		local cs, src = cutscenePoints()
		req = union(union(req, POINTS_W3), cs)
		info(("cutscene points from %s: %s"):format(src, table.concat(cs, ", ")))
	end
	for _, id in req do
		if not byId[id] then
			err(("2: required MapPoint %s missing"):format(id))
		end
	end
	return byId
end

local function checkContentValues(content: { [string]: Keys })
	local function bad(tbl: string, v: any): boolean
		local k = content[tbl]
		if k.keys[v] then
			return false
		end
		if k.fromContent and WAVE2_KEYS[tbl] and WAVE2_KEYS[tbl][v] then
			return false -- reported once below as "TASK-047 pending"
		end
		return true
	end
	local pending: { [string]: boolean } = {}
	local function validate(tag: string, attr: string, tbl: string)
		for _, i in tagged(tag) do
			local v = i:GetAttribute(attr)
			if v ~= nil then
				if bad(tbl, v) then
					err(("3: %s.%s = %s is not a key of Content.%s"):format(name(i), attr, tostring(v), tbl))
				elseif not content[tbl].keys[v] then
					pending[tbl .. "." .. tostring(v)] = true
				end
			end
		end
	end
	validate("Station", "StationKind", "Stations")
	validate("Station", "Ingredient", "Ingredients")
	validate("Interactable", "PromptAction", "Actions")
	validate("Interactable", "Ingredient", "Ingredients")
	validate("Interactable", "Package", "Packages")
	validate("Vehicle", "Vehicle", "Vehicles")
	validate("UpgradePiece", "Upgrade", "Upgrades")
	if WAVE >= 2 then
		validate("LightZone", "Group", "LightGroups")
		validate("StreetLight", "Group", "LightGroups")
	end
	for k in pending do
		warn_(("Content synced without wave-2 key %s (TASK-047 pending): accepted from the embedded list"):format(k))
	end
	for _, i in tagged("Interactable") do
		local b = i:GetAttribute("BenchSlot")
		if b ~= nil and not REQUIRED_BENCH[b] then
			err(("3: %s.BenchSlot = %s (valid: B1..B5, S1)"):format(name(i), tostring(b)))
		end
		if i:GetAttribute("PromptAction") == nil then
			err(("2: Interactable %s without PromptAction"):format(name(i)))
		end
		if NEVER_TAGGED[i.Name] then
			err(("2: %s must NOT be Interactable (§18.4)"):format(name(i)))
		end
		if i:IsA("BasePart") then
			if i.Transparency < 1 or i.CanCollide or i.CanQuery or i.CanTouch then
				err(("5: Interactable BasePart %s must be invisible, CanCollide/CanQuery/CanTouch false"):format(name(i)))
			end
		elseif not i:IsA("Attachment") then
			err(("5: Interactable %s is a %s (Attachment or BasePart only)"):format(name(i), i.ClassName))
		end
	end
	for _, s in tagged("Station") do
		if not s:IsA("Model") then
			err(("5: Station %s is a %s (must be a Model)"):format(name(s), s.ClassName))
		end
		if s:GetAttribute("StationKind") == nil then
			err(("2: Station %s without StationKind"):format(name(s)))
		end
	end
end

-- One vehicle: stations, slots, per-ingredient anchors, vehicle-level prompts, fittings.
local function checkVehicle(key: string, v: Instance)
	local spec = (VEHICLE_SPEC :: any)[key]
	local byKind: { [string]: { Instance } } = {}
	for _, s in tagged("Station") do
		local k = s:GetAttribute("StationKind")
		if typeof(k) == "string" and s:IsDescendantOf(v) then
			byKind[k] = byKind[k] or {}
			table.insert(byKind[k], s)
		end
	end
	local kinds = spec.kinds
	if WAVE < 2 then
		kinds = {}
		for _, k in spec.kinds do
			if k ~= "coffee_machine" then
				table.insert(kinds, k)
			end
		end
	end
	for _, kind in kinds do
		local list = byKind[kind] or {}
		if #list ~= 1 then
			err(("2: %d Station '%s' in the %s (need 1)"):format(#list, kind, key))
			continue
		end
		local st = list[1]
		local req = (STATION_RULES :: any)[kind]
		local acts: { [string]: number } = {}
		local slotInter: { [number]: number } = {}
		local perIng: { [string]: { [string]: number } } = {}
		for _, i in tagged("Interactable") do
			if ownerOf(i) == st then
				local a = i:GetAttribute("PromptAction") :: string
				acts[a] = (acts[a] or 0) + 1
				local sl = i:GetAttribute("Slot")
				if typeof(sl) == "number" then
					slotInter[sl] = (slotInter[sl] or 0) + 1
				end
				local ing = i:GetAttribute("Ingredient")
				if typeof(ing) == "string" then
					perIng[ing] = perIng[ing] or {}
					perIng[ing][a] = (perIng[ing][a] or 0) + 1
				end
			end
		end
		if req.actions then
			for a, n in req.actions do
				if (acts[a] or 0) ~= n then
					err(("2: %s %s (%s): %d anchor(s) %s, need %d"):format(key, kind, name(st), acts[a] or 0, a, n))
				end
			end
		end
		if req.slotInteractables then
			for sl = 1, req.slotInteractables do
				if slotInter[sl] ~= 1 then
					err(("2: %s grill: grill_collect with Slot %d found %d time(s), need 1"):format(key, sl, slotInter[sl] or 0))
				end
			end
			if (acts.grill_collect or 0) ~= req.slotInteractables then
				err(("2: %s grill: %d grill_collect anchors, need %d"):format(key, acts.grill_collect or 0, req.slotInteractables))
			end
		end
		if req.slotsFrom then
			local want = vehicleSlots(key, req.slotsFrom)
			local seen: { [number]: number } = {}
			for _, d in st:GetDescendants() do
				local sl = d:GetAttribute("Slot")
				if typeof(sl) == "number" and not CollectionService:HasTag(d, "Interactable") then
					seen[sl] = (seen[sl] or 0) + 1
					if not d:IsA("Attachment") then
						warn_(("%s %s: slot %s is a %s (Attachment preferred)"):format(key, kind, name(d), d.ClassName))
					end
				end
			end
			for sl = 1, want do
				if seen[sl] ~= 1 then
					err(("2: %s %s: slot Attachment with Slot %d found %d time(s), need 1"):format(key, kind, sl, seen[sl] or 0))
				end
			end
			for sl in seen do
				if sl > want then
					warn_(("%s %s: extra slot %d (vehicle has %d)"):format(key, kind, sl, want))
				end
			end
		end
		if req.perIngredient then
			for _, ing in TOPPING_KEYS do
				for _, a in req.perIngredient do
					local n = perIng[ing] and perIng[ing][a] or 0
					if n ~= 1 then
						err(("2: %s toppings: %s with Ingredient %s found %d time(s), need 1"):format(key, a, ing, n))
					end
				end
			end
		end
		-- named fittings (warn)
		local fittings = ({
			sausage_stock = { "Fill", "Lid", "VFX_Upgrade" },
			bun_crate = { "Fill" },
			trash = { "Lid" },
			coffee_machine = { "Bar_Brew", "Att_Cup", "VFX_Steam" },
		} :: any)[kind]
		if kind == "toppings" then
			fittings = {}
			for _, suf in { "Ketchup", "Mustard", "Cheese", "Bacon", "PotatoSticks", "CreamCheese" } do
				table.insert(fittings, "Bin_" .. suf) -- real bowl (DEC-156); anchors live on it
				table.insert(fittings, "Label_" .. suf) -- SurfaceGui icon plate
			end
		end
		for _, f in fittings or {} do
			if not st:FindFirstChild(f, true) then
				warn_(("%s %s: named fitting %s missing (visual, read by KitchenController)"):format(key, kind, f))
			end
		end
	end
	for k, list in byKind do
		if not table.find(kinds, k) then
			warn_(("%s: %d unexpected Station '%s' in wave %d"):format(key, #list, k, WAVE))
		end
	end

	-- vehicle-level prompts (owner is not a Station): phone, switch, purchase
	local own: { [string]: number } = {}
	for _, i in tagged("Interactable") do
		if i:IsDescendantOf(v) and not ancestorWithTag(i, "Station") then
			local a = i:GetAttribute("PromptAction")
			if typeof(a) == "string" then
				own[a] = (own[a] or 0) + 1
			end
		end
	end
	local wantOwn: { [string]: number } = {}
	for w, list in spec.own do
		if w <= WAVE then
			for a, n in list do
				wantOwn[a] = n
			end
		end
	end
	for a, n in wantOwn do
		if (own[a] or 0) ~= n then
			err(("2: %s: %d vehicle anchor(s) %s, need %d"):format(key, own[a] or 0, a, n))
		end
	end
	for a, n in own do
		if not wantOwn[a] then
			warn_(("%s: %d unexpected vehicle anchor(s) %s (wave %d)"):format(key, n, a, WAVE))
		end
	end
	if not v:FindFirstChild("Value_Anchor", true) then
		err(("2: Value_Anchor missing inside the %s Vehicle (TASK-024)"):format(key))
	end
	if not v:FindFirstChild("Zone_Center", true) then
		warn_(("%s: Zone_Center missing (thief radius 14, DEC-050)"):format(key))
	end
	for _, f in { "Bar_Thief", "VFX_Coins" } do
		if not v:FindFirstChild(f, true) then
			warn_(("%s: named fitting %s missing (drawer)"):format(key, f))
		end
	end
end

local function checkVehicles(): { [string]: Instance }
	local byKey: { [string]: { Instance } } = {}
	for _, v in tagged("Vehicle") do
		if not v:IsA("Model") then
			err(("5: Vehicle %s is a %s"):format(name(v), v.ClassName))
		end
		local k = v:GetAttribute("Vehicle")
		if typeof(k) ~= "string" then
			err(("2: Vehicle %s without attribute Vehicle"):format(name(v)))
		else
			byKey[k] = byKey[k] or {}
			table.insert(byKey[k], v)
		end
	end
	for _, s in tagged("Station") do
		if not ancestorWithTag(s, "Vehicle") then
			err(("5: Station %s is not a descendant of a Vehicle"):format(name(s)))
		end
	end
	local out: { [string]: Instance } = {}
	for key, spec in VEHICLE_SPEC do
		if spec.wave > WAVE then
			continue
		end
		local list = byKey[key] or {}
		if #list ~= 1 then
			err(("2: %d Vehicle '%s' in the Workspace (need 1)"):format(#list, key))
		else
			out[key] = list[1]
			checkVehicle(key, list[1])
		end
	end
	return out
end

local function checkMapAnchors()
	local opens = {}
	local pk: { [string]: { Instance } } = {}
	local bench: { [string]: { Instance } } = {}
	for _, i in tagged("Interactable") do
		local a = i:GetAttribute("PromptAction")
		if a == "open_sign" then
			table.insert(opens, i)
			if ancestorWithTag(i, "Vehicle") then
				err(("2: open_sign %s is inside a Vehicle (it stays on the map, MAP-01 §7.3)"):format(name(i)))
			end
		elseif a == "buy_package" then
			local p = i:GetAttribute("Package")
			if typeof(p) ~= "string" then
				err(("2: buy_package %s without Package"):format(name(i)))
			else
				pk[p] = pk[p] or {}
				table.insert(pk[p], i)
			end
		elseif a == "bench_buy_upgrade" or a == "bench_buy_item" then
			local b = i:GetAttribute("BenchSlot")
			if typeof(b) ~= "string" then
				err(("2: %s %s without BenchSlot"):format(a, name(i)))
			else
				if REQUIRED_BENCH[b] and REQUIRED_BENCH[b] ~= a then
					err(("2: BenchSlot %s has action %s, need %s"):format(b, a, REQUIRED_BENCH[b]))
				end
				bench[b] = bench[b] or {}
				table.insert(bench[b], i)
			end
		elseif a == "discard" and not ancestorWithTag(i, "Vehicle") then
			-- street bin (T60): anchor outside Station and Vehicle, inside a StreetBin model
			if ancestorWithTag(i, "Station") then
				err(("2: street discard %s is inside a Station (T60: no Station outside the vehicle)"):format(name(i)))
			elseif not ancestorWithTag(i, "StreetBin") then
				err(("2: discard %s is outside a Vehicle and outside a StreetBin model (T60)"):format(name(i)))
			end
		end
	end
	if #opens ~= 1 then
		err(("2: %d open_sign anchors (need 1)"):format(#opens))
	end
	for _, p in REQUIRED_PACKAGES do
		if #(pk[p] or {}) ~= 1 then
			err(("2: buy_package %s found %d time(s), need 1"):format(p, #(pk[p] or {})))
		end
	end
	for b in REQUIRED_BENCH do
		if #(bench[b] or {}) ~= 1 then
			err(("2: bench %s found %d time(s), need 1"):format(b, #(bench[b] or {})))
		end
	end
	-- 4: distances among shelves and among bench prompts
	local function pairs_(list: { Instance }, minErr: number, minWarn: number, label: string)
		for i = 1, #list do
			for j = i + 1, #list do
				local d = (pos(list[i]) - pos(list[j])).Magnitude
				if d < minErr then
					err(("4: %s: %s and %s %.2f apart (< %.1f)"):format(label, list[i].Name, list[j].Name, d, minErr))
				elseif d < minWarn then
					warn_(("%s: %s and %s %.2f apart (< %.1f, MAP-01 §7.4)"):format(label, list[i].Name, list[j].Name, d, minWarn))
				end
			end
		end
	end
	local shelves, benches = {}, {}
	for _, l in pk do
		for _, i in l do
			table.insert(shelves, i)
		end
	end
	for _, l in bench do
		for _, i in l do
			table.insert(benches, i)
		end
	end
	pairs_(shelves, SHELF_GAP - 0.01, SHELF_GAP - 0.01, "Mart shelves (MAP-01 §18.10: >= 4)")
	pairs_(benches, 2.5, 2.5, "Gear Stand")

	-- street bins (DEC-200; not in Required.Wave2, Q-166 b)
	if WAVE >= 2 then
		local bins = tagged("StreetBin")
		for _, b in bins do
			if not b:IsA("Model") then
				err(("5: StreetBin %s is a %s (must be a Model)"):format(name(b), b.ClassName))
			end
			if ancestorWithTag(b, "Vehicle") or ancestorWithTag(b, "Station") then
				err(("2: StreetBin %s inside a Vehicle/Station (T60)"):format(name(b)))
			end
			local n = 0
			for _, d in b:GetDescendants() do
				if CollectionService:HasTag(d, "Interactable") and d:GetAttribute("PromptAction") == "discard" then
					n += 1
				end
			end
			if n ~= 1 then
				warn_(("StreetBin %s has %d discard anchor(s) (expected 1)"):format(name(b), n))
			end
		end
		info(("street bins: %d StreetBin (Q-166 b, Provisional: all AST-034_TrashCan)"):format(#bins))
	end
end

local function checkVehicleDistances(vehicles: { [string]: Instance })
	for key, v in vehicles do
		local list = {}
		for _, i in tagged("Interactable") do
			if i:IsDescendantOf(v) then
				table.insert(list, i)
			end
		end
		local closest = math.huge
		for i = 1, #list do
			for j = i + 1, #list do
				local a, b = list[i], list[j]
				local oa, ob = ownerOf(a), ownerOf(b)
				local d = (pos(a) - pos(b)).Magnitude
				if oa ~= ob then
					closest = math.min(closest, d)
					-- the phone prompt only shows while it rings (answer_phone): the user put the phones next to the
					-- grill / cooler (2026-10-11), so it only has to keep 1.2 from the other prompts
					const phone = a.Name == "Prompt_Answer" or b.Name == "Prompt_Answer"
					if phone and d < 1.2 then
						err(("4: %s: %s / %s (phone vs other owner) %.2f apart (< 1.2)"):format(key, name(a), name(b), d))
					elseif not phone and d < 2.5 then
						err(("4: %s: %s / %s (different owners) %.2f apart (< 2.5)"):format(key, name(a), name(b), d))
					end
				elseif oa and oa:GetAttribute("StationKind") == "toppings" then
					local ia, ib = a:GetAttribute("Ingredient"), b:GetAttribute("Ingredient")
					if ia ~= ib and d < 2.0 - 0.01 then -- same-row bowls are exactly 2.0 apart in the model
						err(("4: %s toppings %s / %s %.2f apart (< 2.0)"):format(key, a.Name, b.Name, d))
					end
				end
			end
		end
		if closest < math.huge then
			info(("4: %s: closest pair of anchors of different owners: %.2f studs"):format(key, closest))
		end
	end
end

local function checkStreaming()
	local bad = {}
	for _, t in concat(editTags(), OPTIONAL_TAGS) do
		for _, i in tagged(t) do
			local n: Instance? = i
			while n and n ~= Workspace do
				if n:IsA("Model") and n.ModelStreamingMode ~= Enum.ModelStreamingMode.Persistent then
					bad[n] = true
				end
				n = n.Parent
			end
		end
	end
	for m in bad do
		err(("5: Model %s contains gameplay tags but ModelStreamingMode = %s (need Persistent)"):format(name(m), tostring(m.ModelStreamingMode)))
	end
end

local function checkPivots(vehicles: { [string]: Instance })
	local assets = Workspace:FindFirstChild("MAP01_Assets")
	if not assets then
		err("7: workspace.MAP01_Assets missing")
		return
	end
	for key, spec in VEHICLE_SPEC do
		local v = vehicles[key]
		if spec.wave > WAVE or not v then
			continue
		end
		local base = (v :: any):GetPivot().Position.Y
		for _, id in spec.counter.ids do
			local m: Instance? = nil
			for _, d in assets:GetDescendants() do
				if d:GetAttribute("MapId") == id then
					m = d
					break
				end
			end
			if not (m and m:IsA("PVInstance")) then
				err(("7: model %s not found"):format(id))
			else
				local y = (m :: any):GetPivot().Position.Y
				if spec.counter.absY then
					if math.abs(y - spec.counter.absY) > COUNTER_TOL then
						err(("7: %s pivot at y %.3f, need %.2f (DEC-157, Provisional until Q-153)"):format(id, y, spec.counter.absY))
					end
				elseif math.abs((y - base) - spec.counter.relY) > COUNTER_TOL then
					err(("7: %s pivot %.3f above the trailer pivot, need %.2f (floor +2, counter 2.6)"):format(id, y - base, spec.counter.relY))
				end
			end
		end
	end
end

-- wave 2: vehicle poses, tarp, light zones, street lights, DROP-T in the light
local function checkWave2(points: { [string]: Instance }, vehicles: { [string]: Instance })
	-- vehicle pose: the trailer is the only vehicle and stays at MapPoint TRL (user decision 2026-10-12)
	local function near(v: Instance?, pid: string, label: string)
		local p = points[pid]
		if not (v and p and p:IsA("BasePart")) then
			return
		end
		local vp = (v :: any):GetPivot() :: CFrame
		local cf = (p :: BasePart).CFrame
		if (vp.Position - cf.Position).Magnitude > 0.1 or vp.LookVector:Dot(cf.LookVector) < 0.999 then
			warn_(("%s pivot %s is not at MapPoint %s %s (run trailer_only_map.luau)"):format(label, fmtV(vp.Position), pid, fmtV(cf.Position)))
		end
	end
	near(vehicles.trailer, "TRL", "trailer")

	-- light zones (§19.6)
	local zones: { [string]: Instance } = {}
	for _, z in tagged("LightZone") do
		local id = z:GetAttribute("ZoneId")
		if typeof(id) ~= "string" or not ZONES[id] then
			err(("3: LightZone %s ZoneId = %s (valid LZ-1..LZ-5)"):format(name(z), tostring(id)))
			continue
		end
		if zones[id] then
			err(("1: ZoneId %s duplicated"):format(id))
		end
		zones[id] = z
		local want = ZONES[id]
		if z:GetAttribute("Group") ~= want.group then
			err(("3: LightZone %s Group = %s, need %s (content-data.md §6.4)"):format(id, tostring(z:GetAttribute("Group")), want.group))
		end
		if not z:IsA("BasePart") then
			err(("5: LightZone %s is a %s (must be a Part)"):format(id, z.ClassName))
			continue
		end
		local bp = z :: BasePart
		if bp.Transparency < 1 or bp.CanCollide or bp.CanQuery or bp.CanTouch then
			err(("5: LightZone %s must be invisible with CanCollide/CanQuery/CanTouch false"):format(id))
		end
		local isBall = bp:IsA("Part") and (bp :: Part).Shape == Enum.PartType.Ball
		if (want.shape == "Ball") ~= isBall then
			warn_(("LightZone %s shape is %s, MAP-01 §10.2 says %s"):format(id, if isBall then "Ball" else "Block", want.shape))
		end
		if ancestorWithTag(z, "Vehicle") then
			info(("LightZone %s is inside a Vehicle (moves with it; LightService must refresh on Swapped)"):format(id))
		end
	end
	for id in ZONES do
		if not zones[id] then
			err(("2: LightZone %s missing"):format(id))
		end
	end
	local function inZone(z: Instance?, p: Vector3): boolean
		if not (z and z:IsA("BasePart")) then
			return false
		end
		local bp = z :: BasePart
		if bp:IsA("Part") and (bp :: Part).Shape == Enum.PartType.Ball then
			return (p - bp.Position).Magnitude <= bp.Size.X / 2
		end
		local l = bp.CFrame:PointToObjectSpace(p)
		local h = bp.Size / 2
		return math.abs(l.X) <= h.X and math.abs(l.Y) <= h.Y and math.abs(l.Z) <= h.Z
	end
	-- DROP-T and PS-N lit by the trailer interior (standing HRP height = point + 3)
	for _, pid in { "DROP-T", "PS-N1", "PS-N2", "PS-N3", "PS-N4" } do
		local p = points[pid]
		if p and not inZone(zones["LZ-1"], pos(p) + Vector3.new(0, 3, 0)) then
			warn_(("%s is outside LZ-1 (trailer interior light)"):format(pid))
		end
	end
	-- DEC-196: no volume on the Pad <-> Mart route (sampled on the walking line Z 44, X -56..20, HRP height)
	for x = -56, 20, 2 do
		local p = F(Vector3.new(x, 3.4, 44))
		for id, z in zones do
			if id ~= "LZ-5" and id ~= "LZ-4" and inZone(z, p) then
				err(("2: LightZone %s covers the Pad <-> Mart route at %s (DEC-196)"):format(id, fmtV(p)))
				break
			end
		end
	end

	-- street lights (§19.6): one Model per post, PostId, Group, Order in Hush order
	local posts: { [string]: Instance } = {}
	local orders: { [number]: string } = {}
	for _, m in tagged("StreetLight") do
		local id = m:GetAttribute("PostId")
		if typeof(id) ~= "string" or POSTS[id] == nil then
			err(("3: StreetLight %s PostId = %s (valid NL-01..NL-04, P-01)"):format(name(m), tostring(id)))
			continue
		end
		if posts[id] then
			err(("1: PostId %s duplicated"):format(id))
		end
		posts[id] = m
		if not m:IsA("Model") then
			err(("5: StreetLight %s is a %s (must be a Model)"):format(id, m.ClassName))
		end
		if m:GetAttribute("Group") ~= POST_GROUP then
			err(("3: StreetLight %s Group = %s, need %s"):format(id, tostring(m:GetAttribute("Group")), POST_GROUP))
		end
		local o = m:GetAttribute("Order")
		if o ~= POSTS[id] then
			err(("2: StreetLight %s Order = %s, need %d (Hush NL-01 -> NL-04 -> P-01, MAP-01 §5.6)"):format(id, tostring(o), POSTS[id]))
		elseif typeof(o) == "number" then
			if orders[o] then
				err(("1: Order %d used by %s and %s"):format(o, orders[o], id))
			end
			orders[o] = id
		end
		local lit = false
		for _, d in m:GetDescendants() do
			if d:IsA("Light") and d.Enabled then
				lit = true
			end
		end
		if not lit then
			warn_(("StreetLight %s has no enabled Light inside (LightController T31 toggles it)"):format(id))
		end
	end
	for id in POSTS do
		if not posts[id] then
			err(("2: StreetLight %s missing"):format(id))
		end
	end
end

-- wave 3 helpers ---------------------------------------------------------------------------------

-- Every id once as `attr` on an instance tagged `tag` (Required.Wave3 Tagged). Returns id -> instance.
local function taggedIds(tag: string, attr: string, ids: { string }): { [string]: Instance }
	local byId: { [string]: Instance } = {}
	local count: { [string]: number } = {}
	local valid = set(ids)
	for _, i in tagged(tag) do
		local id = i:GetAttribute(attr)
		if typeof(id) ~= "string" or id == "" then
			err(("2: %s %s without %s"):format(tag, name(i), attr))
			continue
		end
		count[id] = (count[id] or 0) + 1
		byId[id] = byId[id] or i
		if not valid[id] then
			warn_(("%s %s: %s = %s is not in the list (%s)"):format(tag, name(i), attr, id, table.concat(ids, ",")))
		end
	end
	for _, id in ids do
		if count[id] ~= 1 then
			err(("2: %s %s = %s found %d time(s), need 1"):format(tag, attr, id, count[id] or 0))
		end
	end
	return byId
end

local function invisiblePart(i: Instance, label: string)
	if not i:IsA("BasePart") then
		err(("5: %s %s is a %s (must be a Part)"):format(label, name(i), i.ClassName))
		return
	end
	local bp = i :: BasePart
	if bp.Transparency < 1 or bp.CanCollide or bp.CanQuery or bp.CanTouch then
		err(("5: %s %s must be invisible with CanCollide/CanQuery/CanTouch false"):format(label, name(i)))
	end
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Along-path distance where the polyline crosses the plane of a stop line (normal = line LookVector, travelling
-- with it), within the line's width; nil when it never does.
local function crossAt(pts: { Vector3 }, line: BasePart): number?
	local cf = line.CFrame
	local look, right = flat(cf.LookVector).Unit, flat(cf.RightVector).Unit
	local o = flat(cf.Position)
	local half = line.Size.X / 2 + 0.5
	local acc = 0
	for k = 1, #pts - 1 do
		local a, b = flat(pts[k]), flat(pts[k + 1])
		local da, db = (a - o):Dot(look), (b - o):Dot(look)
		local seg = (b - a).Magnitude
		if da < 0 and db >= 0 then
			local t = da / (da - db)
			local c = a + (b - a) * t
			if math.abs((c - o):Dot(right)) <= half then
				return acc + seg * t
			end
		end
		acc += seg
	end
	return nil
end

local function insideBox(box: BasePart, p: Vector3): boolean
	local l = box.CFrame:PointToObjectSpace(Vector3.new(p.X, box.Position.Y, p.Z))
	local h = box.Size / 2
	return math.abs(l.X) <= h.X and math.abs(l.Z) <= h.Z
end

-- wave 3: service window, anomaly anchors, SS, traffic, cutscene chain
local function checkWave3(points: { [string]: Instance }, vehicles: { [string]: Instance })
	-- service window (DEC-221, TASK-132; architecture.md §19.14): shutter_toggle counted in checkVehicle (= 1) and
	-- its distance to other owners in rule 4; here the button, the hinge and the leftovers of the hide spots
	local trl = vehicles.trailer
	if trl then
		local switch: Instance? = nil
		for _, i in tagged("Interactable") do
			local a = i:GetAttribute("PromptAction")
			if a == "hide" or a == "get_up" then
				err(("2: %s still has PromptAction %s (hide spots left with DEC-221)"):format(name(i), tostring(a)))
			elseif a == "switch_light" and i:IsDescendantOf(trl) then
				switch = i
			end
		end
		for _, i in tagged("Interactable") do
			if i:IsDescendantOf(trl) and i:GetAttribute("PromptAction") == "shutter_toggle" then
				if i.Name ~= "Prompt_Shutter" then
					warn_(("shutter_toggle anchor %s is not named Prompt_Shutter (§19.14)"):format(name(i)))
				end
				local owner: Instance? = i.Parent
				while owner and owner ~= trl and owner:GetAttribute("MapId") == nil do
					owner = owner.Parent
				end
				if not (owner and owner:GetAttribute("MapId") == "TRL-SHUTTER") then
					warn_(("Prompt_Shutter %s is not inside the button model TRL-SHUTTER (MAP-01 §7.2)"):format(name(i)))
				end
				if switch then
					local d = (pos(i) - pos(switch)).Magnitude
					local dy = math.abs(pos(i).Y - pos(switch).Y)
					if d > 4 or dy > 1 then
						warn_(("Prompt_Shutter %.2f from Prompt_Switch (dy %.2f): MAP-01 §7.2 wants it next to the switch (~2.6, same height)"):format(d, dy))
					end
					info(("11: Prompt_Shutter at %s, %.2f from Prompt_Switch"):format(fmtV(pos(i)), d))
				end
			end
		end
		local hinges: { Instance } = {}
		for _, d in trl:GetDescendants() do
			if d.Name == "Shutter_Hinge" then
				table.insert(hinges, d)
			end
		end
		if #hinges == 0 then
			warn_("trailer: no Shutter_Hinge (VehicleController cannot animate the window flap; MAP-01 §7.2, P51)")
		elseif #hinges > 1 then
			warn_(("trailer: %d Shutter_Hinge (need 1; the client turns the piece that holds it)"):format(#hinges))
		end
		for _, h in hinges do
			if not (h:IsA("Attachment") and h.Parent and h.Parent:IsA("BasePart")) then
				warn_(("Shutter_Hinge %s must be an Attachment on the BasePart that turns (Awning or Shutter_Panel)"):format(name(h)))
			elseif typeof(h:GetAttribute("ClosedAngle")) ~= "number" then
				warn_(("Shutter_Hinge %s without ClosedAngle (degrees around its X axis, open -> closed)"):format(name(h)))
			else
				info(("11: Shutter_Hinge on %s, ClosedAngle %s"):format(name(h.Parent), tostring(h:GetAttribute("ClosedAngle"))))
			end
		end
		for _, d in trl:GetDescendants() do
			local id = d:GetAttribute("MapId")
			if (typeof(id) == "string" and string.match(id, "^H[1-4]$")) or d.Name == "Prompt_Hide" or d.Name == "Hide_Pose" then
				warn_(("%s left over from the hide spots (DEC-221): run Bind.run"):format(name(d)))
			end
		end
	end

	-- apartment windows (ANM-006)
	local wvIds = {}
	for id in WINDOWS_W3 do
		table.insert(wvIds, id)
	end
	table.sort(wvIds)
	local wv = taggedIds("AnomalyAnchor", "AnchorId", wvIds)
	local binding = Workspace:FindFirstChild("MapBinding")
	for id, a in wv do
		local x = WINDOWS_W3[id]
		if not x then
			continue
		end
		if not (a:IsA("BasePart") or a:IsA("Model")) then
			err(("5: AnomalyAnchor %s is a %s (Part or Model)"):format(id, a.ClassName))
			continue
		end
		local p = M(pos(a)) -- MAP-01
		if math.abs(p.X - x) > 2.5 or p.Y < 22 or p.Y > 31 or p.Z > -29 or p.Z < -40 then
			warn_(("AnomalyAnchor %s at %s, expected X %d, Y 24.6..28, facade Z ~-32 (MAP-01 §5.2)"):format(id, fmtV(p), x))
		end
		if binding and a:IsDescendantOf(binding) then
			warn_(("AnomalyAnchor %s is the fallback Part (AST-045 Window_Up_* missing: re-upload pending)"):format(id))
		end
	end

	-- SS inside LZ-5 (the safe spot counts as light, anomalies.md N10)
	local lz5: Instance? = nil
	for _, z in tagged("LightZone") do
		if z:GetAttribute("ZoneId") == "LZ-5" then
			lz5 = z
		end
	end
	local ss = points.SS
	if ss and lz5 and lz5:IsA("BasePart") then
		local d = flat(pos(ss) - (lz5 :: BasePart).Position).Magnitude
		if d > 0.5 then
			warn_(("SS is %.2f from the centre of LZ-5 (AnomalyService InZone(p, \"SS\", 6) and the light ball should match)"):format(d))
		end
	end

	-- traffic (§8.1; TASK-097 tags)
	local spec, src = trafficSpec()
	local pathIds = {}
	for _, r in spec.routes do
		table.insert(pathIds, r.path)
	end
	info(("11: traffic ids from %s: %d paths, %d lines, %d boxes"):format(src, #pathIds, #spec.lines, #spec.boxes))
	local paths = taggedIds("TrafficPath", "PathId", pathIds)
	local lines = taggedIds("TrafficLine", "LineId", spec.lines)
	local boxes = taggedIds("TrafficBox", "BoxId", spec.boxes)
	for _, l in lines do
		invisiblePart(l, "TrafficLine")
		if l:IsA("BasePart") and math.abs((l :: BasePart).CFrame.LookVector.Y) > 0.01 then
			err(("5: TrafficLine %s LookVector not horizontal"):format(name(l)))
		end
	end
	for _, b in boxes do
		invisiblePart(b, "TrafficBox")
	end
	local exits = {}
	for _, id in EXITS do
		if points[id] then
			table.insert(exits, pos(points[id]))
		end
	end
	for _, r in spec.routes do
		local f = paths[r.path]
		if not f then
			continue
		end
		local nodes = {}
		for _, c in f:GetChildren() do
			if c:IsA("BasePart") then
				local idx = c:GetAttribute("Index")
				if typeof(idx) ~= "number" then
					err(("11: TrafficPath %s node %s without Index"):format(r.path, name(c)))
				else
					table.insert(nodes, { idx = idx, p = c.Position, part = c })
				end
				invisiblePart(c, "TrafficPath node")
			end
		end
		table.sort(nodes, function(a, b)
			return a.idx < b.idx
		end)
		for k, n in nodes do
			if n.idx ~= k then
				err(("11: TrafficPath %s: Index %d where %d was expected (Index 1..n, no gaps)"):format(r.path, n.idx, k))
				break
			end
		end
		if #nodes < 2 then
			err(("11: TrafficPath %s has %d node(s) (need >= 2)"):format(r.path, #nodes))
			continue
		end
		local pts = {}
		local length = 0
		for k, n in nodes do
			pts[k] = n.p
			if k > 1 then
				length += flat(n.p - pts[k - 1]).Magnitude
			end
		end
		-- ends: spawn on the lane's entry point, despawn on an exit point
		local entry = points[r.lane]
		if entry and flat(pts[1] - pos(entry)).Magnitude > 1.5 then
			warn_(("TrafficPath %s starts at %s, %.1f from its entry %s"):format(r.path, fmtV(pts[1]), flat(pts[1] - pos(entry)).Magnitude, r.lane))
		end
		local nearExit = false
		for _, e in exits do
			if flat(pts[#pts] - e).Magnitude <= 1.5 then
				nearExit = true
			end
		end
		if not nearExit then
			warn_(("TrafficPath %s ends at %s, not on W/E/JN/JS-OUT"):format(r.path, fmtV(pts[#pts])))
		end
		-- stops in order, first crosswalk line far enough from the spawn
		local last = -1
		local firstCw: number? = nil
		local order = {}
		local prevLine: string? = nil
		for _, s in r.stops do
			local kind, lineId = s[1], s[2]
			-- one line, two roles (PARE + the crosswalk right after the X-T box): checked once
			local repeated = lineId == prevLine
			prevLine = lineId
			local l = lines[lineId]
			if repeated or not (l and l:IsA("BasePart")) then
				continue
			end
			local at = crossAt(pts, l :: BasePart)
			if not at then
				err(("11: TrafficPath %s never crosses its stop line %s (travel direction = line LookVector)"):format(r.path, lineId))
				continue
			end
			if at <= last then
				err(("11: TrafficPath %s crosses %s before the previous stop (Stops order of Content.Traffic)"):format(r.path, lineId))
			end
			last = at
			table.insert(order, ("%s@%.0f"):format(lineId, at))
			if kind == "Crosswalk" and firstCw == nil then
				firstCw = at
			end
			if at < spec.spawnMinDist then
				local msg = ("TrafficPath %s: %s %.0f studs from the spawn (SpawnMinDist %d)"):format(r.path, lineId, at, spec.spawnMinDist)
				if kind == "Crosswalk" then
					err("11: " .. msg)
				else
					warn_(msg)
				end
			end
		end
		-- other lines the path crosses in their direction (informative: the car only stops on its own Stops)
		local extra = {}
		for id, l in lines do
			local listed = false
			for _, s in r.stops do
				if s[2] == id then
					listed = true
				end
			end
			if not listed and l:IsA("BasePart") and crossAt(pts, l :: BasePart) then
				table.insert(extra, id)
			end
		end
		-- conflict boxes the route must pass
		for _, boxId in r.conflicts or {} do
			local b = boxes[boxId]
			if b and b:IsA("BasePart") then
				local inside = false
				for k = 1, #pts - 1 do
					local seg = flat(pts[k + 1] - pts[k]).Magnitude
					for s = 0, math.ceil(seg) do
						if insideBox(b :: BasePart, pts[k]:Lerp(pts[k + 1], s / math.max(1, math.ceil(seg)))) then
							inside = true
							break
						end
					end
					if inside then
						break
					end
				end
				if not inside then
					err(("11: TrafficPath %s never enters its conflict box %s"):format(r.path, boxId))
				end
			end
		end
		info(("11: %s %.0f studs, stops {%s}%s"):format(r.path, length, table.concat(order, ", "), if #extra > 0 then ", also crosses " .. table.concat(extra, ",") else ""))
	end

	-- cutscene walking chain of slot 1 (MAP-01 §11.1, P46): straight MoveTo segments vs carriageways
	local chain: { string } = { "CutsceneMark1", "CS-2", "CS-3", "CS-4", "CS-5", "CS-P1" }
	local cs = loadedContent and loadedContent.Cutscenes
	local intro = cs and cs.ByKey and cs.ByKey.intro
	if intro then
		chain = { intro.Marks[1] }
		for _, beat in intro.Beats do
			if beat.Kind == "MoveTo" then
				table.insert(chain, (string.gsub(beat.Target, "{slot}", "1")))
			end
		end
	end
	for k = 1, #chain - 1 do
		local a, b = points[chain[k]], points[chain[k + 1]]
		if a and b then
			local road, _ = crossesRoad(pos(a), pos(b), nil)
			if road then
				local ok = false
				for _, cw in CROSSWALKS do
					local _, inCw = crossesRoad(pos(a), pos(b), cw)
					if inCw then
						ok = true
					end
				end
				if not ok then
					warn_(("cutscene intro: MoveTo %s -> %s crosses the %s carriageway outside the stripes (MAP-01 P46: add CS-5W / CS-5E beats)"):format(chain[k], chain[k + 1], road))
				end
			end
		end
	end
end

-- 13 (MAP-01 §9.8): no NPC appears or vanishes in sight. For every MapPoint with Spawn / Despawn: line of sight from
-- the eyes of SIGHT_VIEWERS (Pad PS-1..4, queue Q1..Q5, Mart door, SS) to an R6 body on the point (3 heights x 3
-- lateral offsets = 9 rays per viewer), up to SIGHT_MAX. Blockers = any part with CanQuery that is less than
-- SIGHT_SEE_THROUGH transparent; the binding, the blockout Markers / Limits, NPCs and the two vehicles are ignored
-- (the cart / trailer move; worst case). Edge points seen = warning; door points seen = info (rule a: they appear
-- in the doorway while the AutoDoor leaf opens). Also: AutoDoor leaves present (info / warning).
local function sightClear(): (Vector3, Vector3, Instance?) -> boolean
	local exclude: { Instance } = {}
	local binding = Workspace:FindFirstChild("MapBinding")
	if binding then
		table.insert(exclude, binding)
	end
	local blockout = Workspace:FindFirstChild("MAP01_Blockout")
	if blockout then
		for _, n in { "Markers", "Limits" } do
			local f = blockout:FindFirstChild(n)
			if f then
				table.insert(exclude, f)
			end
		end
	end
	local npcs = Workspace:FindFirstChild("Npcs")
	if npcs then
		table.insert(exclude, npcs)
	end
	for _, v in tagged("Vehicle") do
		table.insert(exclude, v)
	end
	for _, c in Workspace:GetChildren() do
		if c:IsA("Model") and c:FindFirstChildOfClass("Humanoid") then
			table.insert(exclude, c)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	return function(a: Vector3, b: Vector3, skip: Instance?): boolean
		local ex = table.clone(exclude)
		if skip then
			table.insert(ex, skip)
		end
		for _ = 1, 24 do
			params.FilterDescendantsInstances = ex
			local hit = Workspace:Raycast(a, b - a, params)
			if not hit then
				return true
			end
			if hit.Instance.Transparency < SIGHT_SEE_THROUGH then
				return false
			end
			table.insert(ex, hit.Instance)
		end
		return true
	end
end

-- 14 (MAP-01 §5.6, 2026-10-10): the Walker has to be seen from the trailer window. Targets: posts Order 1..WALKER_POSTS
-- of the juniper_posts group (the figure stands under the lamp head: feet+1, waist, head, and the lamp itself) and
-- WALKER-10 (feet+1, waist, head). Window centre blocked = error; each PS-N eye blocked = warning.
local function checkWalkerSight(points: { [string]: Instance })
	local clear = sightClear()
	local targets: { { id: string, pts: { Vector3 }, skip: Instance? } } = {}
	local byOrder: { [number]: Instance } = {}
	for _, m in tagged("StreetLight") do
		local o = m:GetAttribute("Order")
		if m:GetAttribute("Group") == POST_GROUP and typeof(o) == "number" and o >= 1 and o <= WALKER_POSTS then
			byOrder[o] = m
		end
	end
	for o = 1, WALKER_POSTS do
		local m = byOrder[o]
		if not m then
			err(("14: Walker post Order %d missing (StreetLight, Group %s)"):format(o, POST_GROUP))
			continue
		end
		local head: Instance? = nil
		for _, d in m:GetDescendants() do
			if d:GetAttribute("Asset") == "AST-036_LampHead" then
				head = d
			end
		end
		-- the figure stands under the dome (LampHead box centre), on the ground of the post (its pivot height)
		local foot = pos(m)
		local dome = foot + Vector3.new(0, 13, 0)
		if head then
			local cf = if head:IsA("Model") then (head :: Model):GetBoundingBox() elseif head:IsA("BasePart") then (head :: BasePart).CFrame else nil
			if cf then
				dome = cf.Position
			end
		end
		local ground = Vector3.new(dome.X, foot.Y, dome.Z)
		table.insert(targets, {
			id = ("%s (Order %d)"):format(tostring(m:GetAttribute("PostId")), o),
			pts = { ground + Vector3.new(0, 1, 0), ground + Vector3.new(0, 3.5, 0), ground + Vector3.new(0, 6, 0), dome },
			skip = m,
		})
	end
	local w = points["WALKER-10"]
	if w then
		local p = pos(w)
		table.insert(targets, { id = "WALKER-10", pts = { p + Vector3.new(0, 1, 0), p + Vector3.new(0, 3.5, 0), p + Vector3.new(0, 6, 0) } })
	else
		err("14: MapPoint WALKER-10 missing")
	end
	local window = F(TRAILER_WINDOW)
	for _, t in targets do
		local function seenFrom(eye: Vector3): number
			local n = 0
			for _, q in t.pts do
				if clear(eye, q, t.skip) then
					n += 1
				end
			end
			return n
		end
		local nWin = seenFrom(window)
		if nWin == 0 then
			err(("14: Walker %s is NOT seen from the trailer window (MAP-01 §5.6: move the post or the blocker)"):format(t.id))
		else
			local blind: { string } = {}
			for _, vid in { "PS-N1", "PS-N2", "PS-N3", "PS-N4" } do
				local v = points[vid]
				if v and seenFrom(pos(v) + Vector3.new(0, SIGHT_EYE, 0)) == 0 then
					table.insert(blind, vid)
				end
			end
			if #blind > 0 then
				warn_(("14: Walker %s seen from the window (%d/%d rays) but not from %s"):format(t.id, nWin, #t.pts, table.concat(blind, ", ")))
			else
				info(("14: Walker %s seen from the window (%d/%d rays) and from PS-N1..4"):format(t.id, nWin, #t.pts))
			end
		end
	end
end

local function checkSpawnSight(points: { [string]: Instance })
	local clear = sightClear()

	local spawns: { string } = {}
	for id, p in points do
		if p:GetAttribute("Spawn") ~= nil or p:GetAttribute("Despawn") ~= nil then
			table.insert(spawns, id)
		end
	end
	table.sort(spawns)
	if #spawns == 0 then
		warn_("13: no MapPoint with Spawn / Despawn (binding older than MAP-01 §9.8: run Bind.run)")
		return
	end
	for _, id in spawns do
		local tp = pos(points[id])
		local kind = tostring(points[id]:GetAttribute("SpawnKind"))
		local seenBy: { string } = {}
		for _, vid in SIGHT_VIEWERS do
			local v = points[vid]
			if not v or vid == id then
				continue
			end
			local eye = pos(v) + Vector3.new(0, SIGHT_EYE, 0)
			local flatD = Vector3.new(tp.X - eye.X, 0, tp.Z - eye.Z)
			if flatD.Magnitude > SIGHT_MAX or flatD.Magnitude < 1 then
				continue
			end
			local side = Vector3.new(-flatD.Z, 0, flatD.X).Unit
			local seen = false
			for _, h in { 0.8, 2.5, 4.3 } do
				for _, o in { -0.8, 0, 0.8 } do
					if not seen and clear(eye, tp + Vector3.new(0, h, 0) + side * o) then
						seen = true
					end
				end
			end
			if seen then
				table.insert(seenBy, ("%s@%.0f"):format(vid, flatD.Magnitude))
			end
		end
		local roles = tostring(points[id]:GetAttribute("Spawn"))
		if #seenBy == 0 then
			info(("13: %s (%s, %s) out of sight of the Pad, the queue and the Mart"):format(id, kind, roles))
		elseif kind == "door" then
			info(("13: %s (door %s, %s) seen from %s: door rule (a), the NPC shows up in the doorway"):format(id, tostring(points[id]:GetAttribute("Door")), roles, table.concat(seenBy, ", ")))
		else
			warn_(("13: spawn/despawn %s (%s, %s) is IN SIGHT from %s (MAP-01 §9.8: move it behind a building or beyond the limits)"):format(id, kind, roles, table.concat(seenBy, ", ")))
		end
	end

	-- AutoDoor leaves (DoorController contract)
	local byDoor: { [string]: number } = {}
	for _, l in tagged("AutoDoor") do
		local d = tostring(l:GetAttribute("DoorId"))
		byDoor[d] = (byDoor[d] or 0) + 1
		if l:IsA("BasePart") and (l :: BasePart).CanCollide then
			warn_(("13: AutoDoor leaf %s still collides on the server (NPCs cannot pass)"):format(name(l)))
		end
	end
	for _, d in { "MKT-DOOR", "D1", "SP-B" } do
		if byDoor[d] then
			info(("13: AutoDoor %s: %d leaf / leaves"):format(d, byDoor[d]))
		else
			warn_(("13: AutoDoor %s: no tagged leaf (bind W8)"):format(d))
		end
	end
end

type Node = { id: string, inst: Instance, p: Vector3, links: { string }, cw: string? }

local function astar(nodes: { [string]: Node }, adj: { [string]: { [string]: boolean } }, from: string, to: string, noQueueMid: boolean, noCross: boolean?): ({ string }?, number)
	if not (nodes[from] and nodes[to]) then
		return nil, 0
	end
	local g: { [string]: number } = { [from] = 0 }
	local came: { [string]: string } = {}
	local open: { [string]: boolean } = { [from] = true }
	local closed: { [string]: boolean } = {}
	while next(open) do
		local best, bestF = nil, math.huge
		for id in open do
			local f = g[id] + (nodes[id].p - nodes[to].p).Magnitude
			if f < bestF - 1e-9 or (math.abs(f - bestF) <= 1e-9 and best and id < best) then
				best, bestF = id, f
			end
		end
		local cur = best :: string
		if cur == to then
			local path = { cur }
			while came[cur] do
				cur = came[cur]
				table.insert(path, 1, cur)
			end
			return path, g[to]
		end
		open[cur] = nil
		closed[cur] = true
		local isQ = string.match(cur, "^Q%d$") ~= nil
		if not (noQueueMid and isQ and cur ~= from) then
			for nb in adj[cur] or {} do
				local isCw = nodes[cur].cw ~= nil and nodes[cur].cw == nodes[nb].cw
				if not closed[nb] and not (noCross and isCw) then
					local ng = g[cur] + (nodes[cur].p - nodes[nb].p).Magnitude
					if g[nb] == nil or ng < g[nb] - 1e-9 then
						g[nb] = ng
						came[nb] = cur
						open[nb] = true
					end
				end
			end
		end
	end
	return nil, 0
end

local function checkGraph(root: Instance?)
	local nodes: { [string]: Node } = {}
	for _, n in tagged("NpcNode") do
		local isPoint = CollectionService:HasTag(n, "MapPoint")
		local nid = n:GetAttribute("NodeId")
		local pid = n:GetAttribute("PointId")
		if isPoint and nid ~= nil then
			warn_(("NpcNode %s is also a MapPoint: NodeId should be omitted (§18.2)"):format(name(n)))
		end
		local id = if isPoint then pid else nid
		if typeof(id) ~= "string" or id == "" then
			err(("2: NpcNode %s without NodeId/PointId"):format(name(n)))
			continue
		end
		if nodes[id] then
			err(("1: NodeId %s duplicated"):format(id))
		end
		if root and not n:IsDescendantOf(root) then
			err(("5: NpcNode %s outside the MapBinding root"):format(id))
		end
		local links = {}
		local raw = n:GetAttribute("Links")
		if typeof(raw) ~= "string" or raw == "" then
			err(("6: NpcNode %s without Links"):format(id))
		else
			if string.find(raw, "%s") then
				err(("6: NpcNode %s Links has spaces: '%s'"):format(id, raw))
			end
			for l in string.gmatch(raw, "[^,]+") do
				table.insert(links, (string.gsub(l, "%s", "")))
			end
		end
		local cw = n:GetAttribute("Crosswalk")
		if cw ~= nil and not CROSSWALKS[cw] then
			err(("6: NpcNode %s Crosswalk = %s (valid CW-1..CW-4)"):format(id, tostring(cw)))
		end
		nodes[id] = { id = id, inst = n, p = pos(n), links = links, cw = if typeof(cw) == "string" then cw else nil }
	end
	local count = 0
	for _ in nodes do
		count += 1
	end
	if count > MAX_NODES then
		err(("6: %d nodes (max %d, §12.3)"):format(count, MAX_NODES))
	end
	local reqNodes = if WAVE >= 2 then concat(NODES_W1, NODES_W2) else NODES_W1
	local paths = if WAVE >= 3 then walkPaths() else nil
	if WAVE >= 3 then
		if paths then
			for _, p in paths do
				reqNodes = union(reqNodes, p.Nodes)
			end
		else
			warn_("10: Content.WalkPaths not synced (Rojo): walk path nodes and rule 10 not checked")
		end
	end
	for _, id in reqNodes do
		if not nodes[id] then
			err(("6: required node %s missing"):format(id))
		end
	end

	-- symmetric adjacency
	local adj: { [string]: { [string]: boolean } } = {}
	for id, n in nodes do
		adj[id] = adj[id] or {}
		for _, l in n.links do
			if not nodes[l] then
				err(("6: %s links to unknown id %s"):format(id, l))
			elseif l == id then
				err(("6: %s links to itself"):format(id))
			else
				adj[id][l] = true
				adj[l] = adj[l] or {}
				adj[l][id] = true
			end
		end
	end

	-- edges: length, roads, obstacles
	local exclude: { Instance } = {}
	if root then
		table.insert(exclude, root)
	end
	local blockout = Workspace:FindFirstChild("MAP01_Blockout")
	if blockout and blockout:FindFirstChild("Markers") then
		table.insert(exclude, blockout.Markers)
	end
	-- review / demo scenes are not part of the map
	for _, c in Workspace:GetChildren() do
		if c.Name == "CrewDemo" or c.Name == "AssetReview" or c.Name == "KitDemo" or c.Name == "ItemsDemo" or string.sub(c.Name, 1, 10) == "__Preview_" then
			table.insert(exclude, c)
		end
	end
	local edges = 0
	local cwUse: { [string]: { string } } = {}
	for id, n in nodes do
		if n.cw then
			cwUse[n.cw] = cwUse[n.cw] or {}
			table.insert(cwUse[n.cw], id)
		end
		for nb in adj[id] do
			if id < nb then
				edges += 1
				local m = nodes[nb]
				local len = (n.p - m.p).Magnitude
				if len > MAX_EDGE then
					err(("6: edge %s-%s is %.1f studs (max %d)"):format(id, nb, len, MAX_EDGE))
				end
				local isCw = n.cw ~= nil and n.cw == m.cw
				local road, inCw = crossesRoad(n.p, m.p, if isCw then CROSSWALKS[n.cw :: string] else nil)
				if road and not isCw then
					err(("6: edge %s-%s crosses the %s carriageway outside a crosswalk"):format(id, nb, road))
				elseif road and isCw and not inCw then
					err(("6: crosswalk edge %s-%s leaves the %s stripes while on the road"):format(id, nb, n.cw :: string))
				end
				if isCw then
					for _, r in ROADS do
						if inRect(n.p.X, n.p.Z, r) or inRect(m.p.X, m.p.Z, r) then
							warn_(("crosswalk edge %s-%s: a curb node stands on the %s carriageway"):format(id, nb, r.name))
						end
					end
				end
				local hit = obstacle(n.p, m.p, exclude)
				if hit then
					local fn = hit:GetFullName()
					local why = if string.find(fn, "Limits") or string.find(fn, "BAR%-") or string.find(fn, "Barriers")
						then " (player limit: NPC must pass it via collision group, TASK-031)"
						else " (verify the edge is walkable)"
					warn_(("edge %s-%s blocked at knee/chest height by %s%s"):format(id, nb, fn, why))
				end
			end
		end
	end
	-- every NpcNode (MapPoint nodes too) is a Walker waypoint: its body column must be free of solid parts (the player-only
	-- Limits / Barriers pass through the NpcPass group at runtime, NpcService) and the floor under it must be at its Y.
	-- Playtest 2026-10-11: N-Z02-09, EX-E and N-Z08-01 stood in BAR-E / BAR-S / the AST-047 fence: stuck + snapped each walk.
	for id, n in nodes do
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = exclude
		local blocker: Instance? = nil
		for _, part in Workspace:GetPartBoundsInRadius(n.p + Vector3.new(0, 3, 0), 1.2, params) do
			local fn = part:GetFullName()
			if part.CanCollide and not string.find(fn, "Limits") and not string.find(fn, "BAR%-") and not string.find(fn, "Barriers") then
				blocker = part
				break
			end
		end
		if blocker then
			err(("6: waypoint %s at %s is inside solid geometry (%s)"):format(id, tostring(n.p), (blocker :: Instance):GetFullName()))
		end
		local rayParams = RaycastParams.new() -- the overlap params above cannot be passed to Raycast (2026-10-12 fix)
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = exclude
		local down = Workspace:Raycast(n.p + Vector3.new(0, 4, 0), Vector3.new(0, -8, 0), rayParams)
		if down == nil then
			warn_(("waypoint %s at %s has no floor under it"):format(id, tostring(n.p)))
		elseif math.abs(down.Position.Y - n.p.Y) > 0.35 then
			warn_(("waypoint %s: floor top y %.2f but the node is at y %.2f"):format(id, down.Position.Y, n.p.Y))
		end
	end
	for cw, ids in cwUse do
		if #ids ~= 2 then
			err(("6: Crosswalk %s on %d node(s) (need exactly the 2 curb nodes)"):format(cw, #ids))
		elseif not (adj[ids[1]] and adj[ids[1]][ids[2]]) then
			err(("6: Crosswalk %s curb nodes %s and %s are not linked"):format(cw, ids[1], ids[2]))
		end
	end

	-- connected
	local start = if nodes["SP-A"] then "SP-A" else next(nodes)
	if start then
		local seen = { [start] = true }
		local stack = { start }
		while #stack > 0 do
			local cur = table.remove(stack) :: string
			for nb in adj[cur] or {} do
				if not seen[nb] then
					seen[nb] = true
					table.insert(stack, nb)
				end
			end
		end
		for id in nodes do
			if not seen[id] then
				err(("6: node %s not connected to %s"):format(id, start))
			end
		end
	end

	-- queue chain (§18.6): Q5-Q4-Q3-Q2-Q1; Q2..Q4 only to neighbours
	for i = 1, 4 do
		local a, b = "Q" .. i, "Q" .. (i + 1)
		if nodes[a] and nodes[b] and not adj[a][b] then
			err(("6: queue chain broken: %s-%s not linked"):format(a, b))
		end
	end
	for i = 2, 4 do
		local q = "Q" .. i
		for nb in adj[q] or {} do
			if nb ~= "Q" .. (i - 1) and nb ~= "Q" .. (i + 1) then
				err(("6: %s links to %s (Q2..Q4 link only to neighbouring slots; arrivals only to Q5)"):format(q, nb))
			end
		end
	end

	-- routes (info) + queue shortcut (warn)
	local customerNodes: { [string]: string } = {}
	for _, r in ROUTES_W1 do
		local path, len = astar(nodes, adj, r[1], r[2], false)
		if not path then
			err(("6: no path %s -> %s (%s)"):format(r[1], r[2], r[3]))
		else
			for _, id in path do
				customerNodes[id] = r[3]
			end
			info(("route %s: %s (%.0f studs, ~%.0f s at 8 st/s)"):format(r[3], table.concat(path, " > "), len, len / 8))
			local viaQ = false
			for k = 2, #path - 1 do
				if string.match(path[k], "^Q%d$") then
					viaQ = true
				end
			end
			if viaQ then
				local alt, altLen = astar(nodes, adj, r[1], r[2], true)
				warn_(("route %s: plain A* walks THROUGH the queue slots. With 'Q nodes never intermediate' it is %s (%.0f studs). Rule for MapIndex.Path (AvoidQueue)"):format(r[3], if alt then table.concat(alt, " > ") else "impossible", altLen))
			end
		end
	end
	-- 12 (MAP-01 §9.8): customer spawn -> Q5 and Q1 -> customer despawn, AvoidQueue, <= SPAWN_ROUTE_MAX studs
	-- (10 s at 13 studs/s, the usual customer speed; the slowest type walks 9)
	if WAVE >= 3 then
		local flow = loadedContent and loadedContent.Flow and loadedContent.Flow.Spawns
		local arrivals: { string } = {}
		local exits: { string } = {}
		for id, n in nodes do
			local sp = n.inst:GetAttribute("Spawn")
			if typeof(sp) == "string" and string.find(sp, "customer", 1, true) then
				table.insert(arrivals, id)
			end
		end
		if flow then
			for _, list in { flow.Exits.Day, flow.Exits.Night } do
				for _, e in list do
					if e.Weight > 0 then
						exits = union(exits, { e.Point })
					end
				end
			end
			for _, list in { flow.Arrivals.Day, flow.Arrivals.Night } do
				for _, e in list do
					local n = nodes[e.Point]
					if not n then
						if e.Weight > 0 then
							err(("12: Content.Flow.Spawns arrival %s is not an NpcNode of the binding"):format(e.Point))
						end
					elseif e.Weight > 0 and not string.find(tostring(n.inst:GetAttribute("Spawn")), "customer", 1, true) then
						warn_(("12: %s is a Flow.Spawns arrival but its Spawn attribute (%s) does not list customer"):format(e.Point, tostring(n.inst:GetAttribute("Spawn"))))
					end
				end
			end
		else
			exits = { "EX-E", "D1" }
			warn_("12: Content.Flow.Spawns not synced (Rojo): exits checked from the embedded EX-E / D1")
		end
		table.sort(arrivals)
		for _, id in arrivals do
			local path, len = astar(nodes, adj, id, "Q5", true)
			if not path then
				err(("12: customer spawn %s has no route to Q5 (AvoidQueue)"):format(id))
			else
				local msg = ("12: spawn %s -> Q5 %.0f studs (%.1f s at 13, %.1f s at 9)"):format(id, len, len / 13, len / 9)
				if len > SPAWN_ROUTE_MAX then
					warn_(msg .. (": over %d studs (~10 s); fine only with Flow.Spawns weight 0"):format(SPAWN_ROUTE_MAX))
				else
					info(msg)
				end
				for _, nid in path do
					customerNodes[nid] = customerNodes[nid] or ("ROUTE-" .. id)
				end
			end
		end
		for _, id in exits do
			local path, len = astar(nodes, adj, "Q1", id, true)
			if not path then
				err(("12: no route Q1 -> exit %s"):format(id))
			else
				info(("12: exit Q1 -> %s %.0f studs (%.1f s at 13)"):format(id, len, len / 13))
			end
		end
	end
	-- thief routes (wave 2): AvoidQueue + AvoidCrossings must still find a path (MAP-01 §9.2)
	if WAVE >= 2 then
		for _, r in ROUTES_W2 do
			local path, len = astar(nodes, adj, r[1], r[2], true, true)
			if not path then
				err(("6: no thief path %s -> %s without queue slots and crosswalks (%s)"):format(r[1], r[2], r[3]))
			else
				info(("route %s: %s (%.0f studs)"):format(r[3], table.concat(path, " > "), len))
				local plain = astar(nodes, adj, r[1], r[2], true, false)
				if plain and #plain ~= #path then
					info(("route %s: without AvoidCrossings A* would take a crosswalk; the thief must pass AvoidCrossings = true"):format(r[3]))
				end
			end
		end
	end
	-- 10 (wave 3): pedestrian walk paths (Content.WalkPaths; architecture.md §19.17, T46; MAP-01 §9.3)
	if paths then
		for _, p in paths do
			local label = ("WalkPaths %s"):format(tostring(p.Key))
			local list = p.Nodes or {}
			local length = 0
			local crossings = {}
			for k, id in list do
				local n = nodes[id]
				if not n then
					continue -- already reported as a missing required node
				end
				if string.match(id, "^Q%d$") then
					err(("10: %s passes the queue slot %s (pedestrians never enter the queue)"):format(label, id))
				end
				if (p.Shift == "Night" or p.Shift == "Any") and customerNodes[id] then
					warn_(("%s (Shift %s) uses %s of the customer route %s: at night an NPC there reads as a customer (MAP-01 §9.1)"):format(label, p.Shift, id, customerNodes[id]))
				end
				local nextId = list[k + 1]
				if nextId == nil and p.Loop then
					nextId = list[1]
				end
				if nextId and nodes[nextId] then
					if not (adj[id] and adj[id][nextId]) then
						err(("10: %s: %s -> %s are not linked in the NpcNode graph"):format(label, id, nextId))
					else
						length += (n.p - nodes[nextId].p).Magnitude
						if n.cw ~= nil and n.cw == nodes[nextId].cw then
							table.insert(crossings, n.cw)
						end
					end
				end
			end
			info(("10: %s (%s, %s, weight %s): %d nodes, %.0f studs (~%.0f s at 8 st/s), crossings {%s}"):format(
				label,
				tostring(p.Shift),
				if p.Loop then "loop" else "one-way",
				tostring(p.Weight),
				#list,
				length,
				length / 8,
				table.concat(crossings, ",")
			))
		end
	end
	info(("6: graph %d nodes, %d edges"):format(count, edges))
end

-- 9 (TASK-085, §18.1, §18.2, §18.4 T38; DEC-052, DEC-184): upgrade pieces of every vehicle of this wave.
local function pieceRows(): ({ any }, string)
	local c = loadedContent
	local up = c and c.Upgrades
	if type(up) == "table" and type(up.List) == "table" then
		local rows = {}
		for _, u in up.List do
			for _, v in u.Vehicles or {} do
				for _, r in (u.Levels and u.Levels[v]) or {} do
					if type(r.Part) == "string" and r.Part ~= "" then
						table.insert(rows, { upgrade = u.Key, vehicle = v, level = r.Level, part = r.Part, start = u.StartLevel })
					end
				end
			end
		end
		return rows, "Content"
	end
	return PIECE_ROWS_EMBEDDED, "embedded"
end

local function checkPieces(vehicles: { [string]: Instance })
	local rows, src = pieceRows()
	local want: { [string]: any } = {}
	local starts: { [string]: number } = {}
	for _, r in rows do
		want[("%s|%s|%d"):format(r.vehicle, r.upgrade, r.level)] = r
		starts[r.vehicle .. "|" .. r.upgrade] = r.start
	end
	local seen: { [string]: { Instance } } = {}
	local visible: { [string]: { number } } = {}
	local ghostKeys: { [string]: boolean }? = nil
	local byVehicle: { [string]: number } = {}
	for _, p in tagged("UpgradePiece") do
		local label = name(p)
		if not p:IsA("Model") then
			err(("5: UpgradePiece %s is a %s (must be a Model)"):format(label, p.ClassName))
		end
		local up, lv = p:GetAttribute("Upgrade"), p:GetAttribute("Level")
		if typeof(up) ~= "string" or typeof(lv) ~= "number" or lv ~= math.floor(lv) or lv < 0 then
			err(("2: UpgradePiece %s without string Upgrade / integer Level (§18.2)"):format(label))
			continue
		end
		local veh = ancestorWithTag(p, "Vehicle")
		if not veh then
			err(("5: UpgradePiece %s outside a Vehicle (DEC-184: one instance per vehicle)"):format(label))
			continue
		end
		if ancestorWithTag(p, "UpgradePiece") then
			err(("5: UpgradePiece %s inside another UpgradePiece"):format(label))
		end
		local vk = tostring(veh:GetAttribute("Vehicle"))
		local fv = p:GetAttribute("ForVehicle")
		if fv ~= nil and fv ~= vk then
			warn_(("UpgradePiece %s: kit ForVehicle %s but it sits in the %s"):format(label, tostring(fv), vk))
		end
		local key = ("%s|%s|%d"):format(vk, up, lv)
		if not want[key] then
			err(("3: UpgradePiece %s: %s L%d is not a row of Content.Upgrades for the %s (Part ~= \"\")"):format(label, up, lv, vk))
		end
		seen[key] = seen[key] or {}
		table.insert(seen[key], p)
		byVehicle[vk] = (byVehicle[vk] or 0) + 1
		-- T38: nothing interactive inside a piece; hidden parts carry the UpgradeService attributes
		local raw = 0
		for _, d in p:GetDescendants() do
			for _, t in { "Interactable", "Station", "Vehicle", "MapPoint", "NpcNode", "UpgradePiece" } do
				if CollectionService:HasTag(d, t) then
					err(("5: %s tagged %s inside UpgradePiece %s (T38: anchors stay on the station root)"):format(name(d), t, label))
				end
			end
			if d:GetAttribute("Slot") ~= nil then
				err(("5: %s has Slot inside UpgradePiece %s (T38)"):format(name(d), label))
			end
			if d:IsA("Attachment") and (string.match(d.Name, "^Prompt_") or string.match(d.Name, "^Slot%d+$") or string.match(d.Name, "^Att_Slot%d+$")) then
				err(("5: anchor %s inside UpgradePiece %s (T38)"):format(name(d), label))
			end
			if d:IsA("BasePart") and d.Transparency >= 1 and not d:GetAttribute("UpgHidden") then
				raw += 1
			end
		end
		if raw > 0 then
			warn_(("UpgradePiece %s: %d invisible part(s) without UpgHidden: UpgradeService cannot show them (hide with bind_pieces / Pieces.luau attributes)"):format(label, raw))
		end
		if p:GetAttribute("NoVisual") then
			-- ghost piece (bind_pieces GHOST_UPGRADES, user 2026-10-10): hidden at every level until its model exists
			ghostKeys = ghostKeys or {}
			ghostKeys[vk .. "|" .. up] = true
		elseif not isHidden(p) then
			local k = vk .. "|" .. up
			visible[k] = visible[k] or {}
			table.insert(visible[k], lv)
		end
	end
	-- 2: exactly one piece per (vehicle, upgrade, level) of the vehicles of this wave
	for key, r in want do
		if vehicles[r.vehicle] then
			local n = #(seen[key] or {})
			if n ~= 1 then
				err(("2: %s: %d UpgradePiece %s L%d (%s), need 1 (run bind_pieces.luau)"):format(r.vehicle, n, r.upgrade, r.level, r.part))
			end
		end
	end
	-- authored state: only the StartLevel piece visible (warn)
	for k, start in starts do
		local vk = string.match(k, "^([^|]+)")
		if ghostKeys and ghostKeys[k] then
			info(("9: %s: pieces exist but have no visual (NoVisual ghost until the model exists; the upgrade still works)"):format(k))
		elseif vk and vehicles[vk] then
			local list = visible[k] or {}
			local hasStart = want[("%s|%d"):format(k, start)] ~= nil
			local ok = if hasStart then (#list == 1 and list[1] == start) else #list == 0
			if not ok then
				warn_(("%s: visible piece level(s) {%s}, authored state should be %s (UpgradeService fixes it at run time)"):format(k, table.concat(list, ","), if hasStart then "L" .. start .. " only" else "none (StartLevel " .. start .. ")"))
			end
		end
	end
	-- fixed equivalents still visible beside the pieces (warn)
	local function visibleOutside(m: Instance, what: string): number
		local n = 0
		local list: { Instance } = { m }
		for _, d in m:GetDescendants() do
			table.insert(list, d)
		end
		for _, d in list do
			if d:IsA("BasePart") and d.Transparency < 1 and (what == "all" or d.Name == what)
				and not CollectionService:HasTag(d, "UpgradePiece") and not ancestorWithTag(d, "UpgradePiece")
				and not CollectionService:HasTag(d, "Interactable")
			then
				n += 1
			end
		end
		return n
	end
	for vk, v in vehicles do
		if (byVehicle[vk] or 0) == 0 then
			continue
		end
		for _, f in PIECE_FIXED do
			local models: { Instance } = {}
			if f.kind then
				for _, s in tagged("Station") do
					if s:IsDescendantOf(v) and s:GetAttribute("StationKind") == f.kind then
						table.insert(models, s)
					end
				end
			else
				for _, d in v:GetDescendants() do
					if table.find(f.ids, d:GetAttribute("MapId")) and not ancestorWithTag(d, "UpgradePiece") then
						table.insert(models, d)
					end
				end
			end
			for _, m in models do
				local n = visibleOutside(m, f.what)
				if n > 0 then
					warn_(("%s: %s has %d visible fixed part(s)%s beside the upgrade pieces (run bind_pieces.luau)"):format(vk, name(m), n, if f.what == "all" then "" else " named " .. f.what))
				end
			end
		end
		-- grill slots on the kit anchors (DEC-201: same place at every level)
		for _, s in tagged("Station") do
			if s:IsDescendantOf(v) and s:GetAttribute("StationKind") == "grill" then
				local ref: Instance? = nil
				local refN = 0
				for _, p in tagged("UpgradePiece") do
					if p:IsDescendantOf(s) and p:GetAttribute("Upgrade") == "grill" then
						local k = 0
						while typeof(p:GetAttribute("Anchor_Slot" .. (k + 1))) == "Vector3" do
							k += 1
						end
						if k > refN then
							ref, refN = p, k
						end
					end
				end
				if ref then
					local pivot = (ref :: any):GetPivot() :: CFrame
					for _, i in tagged("Interactable") do
						if ownerOf(i) == s and i:GetAttribute("PromptAction") == "grill_collect" then
							local sl = i:GetAttribute("Slot")
							local a = if typeof(sl) == "number" then (ref :: Instance):GetAttribute("Anchor_Slot" .. sl) else nil
							if typeof(a) == "Vector3" then
								local d = (pos(i) - pivot:PointToWorldSpace(a)).Magnitude
								if d > 0.1 then
									warn_(("%s grill: Slot %s anchor %.2f from the kit Anchor_Slot%s of %s (run bind_pieces.luau)"):format(vk, tostring(sl), d, tostring(sl), ref.Name))
								end
							end
						end
					end
				else
					warn_(("%s grill: no grill UpgradePiece inside the station (pieces must sit under their station)"):format(vk))
				end
			end
		end
	end
	local parts = {}
	for vk, n in byVehicle do
		table.insert(parts, ("%s %d"):format(vk, n))
	end
	table.sort(parts)
	info(("9: UpgradePiece %s (rows from %s)"):format(table.concat(parts, ", "), src))
end

-- 16. Pad / Trailer tables (FEAT-037, Q-209; Content.Seating.Groups). Never an error (the tables are the owner's hand
-- work and SeatingService falls back): warnings for a SeatTable without TableIndex 1..9, a duplicated index, a
-- TableGroup attribute that disagrees with the index (Pad 1..5, Trailer 6..9), a table without Seat1..Seat4 BaseParts
-- (the Studio snippet tools/assetplace/trailer_tables.luau adds them), and a table with no NpcNode within 20 studs
-- (nobody can walk to it: add TBL-<n> next to it). Info: how many tables per group were found.
local function checkTables()
	local groups = {
		{ key = "Trailer", first = 1, last = 4 }, -- one group since 2026-10-12 (trailer only, TBL-1..4)
	}
	local byIndex: { [number]: { Instance } } = {}
	for _, m in tagged("SeatTable") do
		local idx = m:GetAttribute("TableIndex")
		if typeof(idx) ~= "number" or idx ~= math.floor(idx) or idx < 1 or idx > 4 then
			warn_(("16: SeatTable %s: TableIndex must be 1..4 (got %s)"):format(m:GetFullName(), tostring(idx)))
			continue
		end
		byIndex[idx] = byIndex[idx] or {}
		table.insert(byIndex[idx], m)
		for _, g in groups do
			local declared = m:GetAttribute("TableGroup")
			if idx >= g.first and idx <= g.last and typeof(declared) == "string" and declared ~= g.key then
				warn_(("16: SeatTable %s: TableGroup %s but TableIndex %d is the %s group"):format(m:GetFullName(), declared, idx, g.key))
			end
		end
		for seat = 1, 4 do
			local part = m:FindFirstChild("Seat" .. seat, true)
			if not (part and part:IsA("BasePart")) then
				warn_(("16: SeatTable %s (TBL-%d): no BasePart Seat%d"):format(m:GetFullName(), idx, seat))
			end
		end
		local nearest = math.huge
		for _, n in tagged("NpcNode") do
			nearest = math.min(nearest, (pos(n) - pos(m)).Magnitude)
		end
		if nearest > 20 then
			warn_(("16: TBL-%d is %.0f studs from the nearest NpcNode (> 20): add NpcNode TBL-%d next to it with an edge to the queue"):format(idx, nearest, idx))
		end
	end
	local counts = {}
	for _, g in groups do
		local n = 0
		for idx = g.first, g.last do
			local list = byIndex[idx]
			if list then
				n += 1
				if #list > 1 then
					warn_(("16: TableIndex %d is on %d tables"):format(idx, #list))
				end
			end
		end
		table.insert(counts, ("%s %d/%d"):format(g.key, n, g.last - g.first + 1))
	end
	info("16: SeatTable " .. table.concat(counts, ", "))
end

-- 15. Mart v2 Gear Stand (TASK-138; MAP-01 §18.3, §18.4, §18.10). Errors: pedestal / shutter count per Slot, shutter
-- without Slat_* / Door_Panel, bench prompt of a slot outside its pedestal. Warnings: Slot_ / Price_Anchor_ missing,
-- shutter without Roll, Att_Opal missing / off OP-1 / not facing the store, shelf heights, prompts out of reach of the
-- rail line, GEAR_WALL / checkout still placed.
local function checkMart(points: { [string]: Instance })
	local function bySlot(tag: string): { [string]: { Instance } }
		local out: { [string]: { Instance } } = {}
		for _, i in tagged(tag) do
			local s = i:GetAttribute("Slot")
			if typeof(s) ~= "string" then
				err(("15: %s %s without attribute Slot"):format(tag, name(i)))
				continue
			end
			out[s] = out[s] or {}
			table.insert(out[s], i)
		end
		return out
	end

	-- bench prompt anchors by BenchSlot
	local prompts: { [string]: Instance } = {}
	for _, i in tagged("Interactable") do
		local b = i:GetAttribute("BenchSlot")
		if typeof(b) == "string" then
			prompts[b] = i
		end
	end

	local peds = bySlot("GearPedestal")
	for _, slot in MART_PEDESTALS do
		local list = peds[slot] or {}
		if #list ~= 1 then
			err(("15: GearPedestal Slot %s found %d time(s), need 1"):format(slot, #list))
			continue
		end
		local p = list[1]
		if not p:FindFirstChild("Slot_" .. slot, true) then
			warn_(("15: GearPedestal %s: no Slot_%s (mini falls back on the column top)"):format(slot, slot))
		end
		if not (p:FindFirstChild("Price_Anchor_" .. slot, true) or p:FindFirstChild("Price_Anchor", true)) then
			warn_(("15: GearPedestal %s: no Price_Anchor_%s (plate hangs under the prompt)"):format(slot, slot))
		end
		local a = prompts[slot]
		if a and not a:IsDescendantOf(p) then
			err(("15: bench prompt %s (%s) is not inside its GearPedestal %s"):format(slot, name(a), name(p)))
		end
		if a then
			local m = M(pos(a))
			local reach = math.abs(m.X - KIOSK_STAND_X)
			if m.X < KIOSK_STAND_X - KIOSK_REACH then
				warn_(("15: bench prompt %s at MAP X %.2f is %.2f behind the rail line (X %.1f): reach from outside (§18.10)"):format(slot, m.X, reach, KIOSK_STAND_X))
			end
			local h = m.Y - MART_FLOOR
			if h < 3.5 or h > 5.0 then
				warn_(("15: bench prompt %s at h %.2f over the floor (MAP-01 §18.4: 4.2)"):format(slot, h))
			end
		end
	end
	for s, list in peds do
		if not table.find(MART_PEDESTALS, s) then
			err(("15: %d GearPedestal with unknown Slot %s"):format(#list, s))
		end
	end

	local shutters = bySlot("GearShutter")
	for _, key in MART_SHUTTERS do
		local list = shutters[key] or {}
		if #list ~= 1 then
			err(("15: GearShutter Slot %s found %d time(s), need 1"):format(key, #list))
			continue
		end
		local sh = list[1]
		if not sh:IsA("Model") then
			err(("15: GearShutter %s is a %s (must be a Model)"):format(key, sh.ClassName))
		end
		local slats, roll = 0, false
		for _, d in sh:GetDescendants() do
			if d:IsA("BasePart") then
				if string.sub(d.Name, 1, 5) == "Slat_" or d.Name == "Door_Panel" then
					slats += 1
				elseif d.Name == "Roll" or d.Name == "Door_Drum" then
					roll = true
				end
			end
		end
		if slats == 0 then
			err(("15: GearShutter %s has no Slat_* / Door_Panel part (the door would not move)"):format(key))
		end
		if not roll then
			warn_(("15: GearShutter %s has no Roll / Door_Drum part"):format(key))
		end
		info(("15: GearShutter %s: %d slat(s)%s"):format(key, slats, if roll then " + Roll" else ""))
	end
	for s, list in shutters do
		if not table.find(MART_SHUTTERS, s) then
			err(("15: %d GearShutter with unknown Slot %s"):format(#list, s))
		end
	end

	-- Att_Opal: same lookup as OpalController (Model ancestors of a GearPedestal, depth 4)
	local att: Instance? = nil
	for _, p in tagged("GearPedestal") do
		local node: Instance? = p.Parent
		local depth = 0
		while node and node ~= Workspace and depth < OPAL_SEARCH_DEPTH and not att do
			if node:IsA("Model") then
				local f = node:FindFirstChild("Att_Opal", true)
				if f and (f:IsA("Attachment") or f:IsA("BasePart")) then
					att = f
				end
			end
			node = node.Parent
			depth += 1
		end
		if att then
			break
		end
	end
	if not att then
		warn_("15: Att_Opal not found in the Model ancestors of a GearPedestal (Opal falls back on OP-1)")
	else
		local cf = if att:IsA("Attachment") then att.WorldCFrame else (att :: BasePart).CFrame
		local m = M(cf.Position)
		if (Vector3.new(m.X, 0, m.Z) - OPAL_AT).Magnitude > 0.5 then
			warn_(("15: Att_Opal at MAP %s, MAP-01 §18.4 says (%.1f, %.3f)"):format(fmtV(m), OPAL_AT.X, OPAL_AT.Z))
		end
		if cf.LookVector:Dot(E) < math.cos(math.rad(10)) then
			warn_(("15: Att_Opal faces %s, expected MAP east %s (the store)"):format(fmtV(cf.LookVector), fmtV(E)))
		end
		local op = points["OP-1"]
		if op and (pos(op) - cf.Position).Magnitude > 1.0 then
			warn_(("15: Att_Opal and MapPoint OP-1 are %.2f apart (same spot expected)"):format((pos(op) - cf.Position).Magnitude))
		end
	end

	-- shelf anchor heights (§18.10: 3.0 .. 4.5 above the floor)
	for _, i in tagged("Interactable") do
		if i:GetAttribute("PromptAction") == "buy_package" then
			local h = M(pos(i)).Y - MART_FLOOR
			if h < SHELF_H[1] - 0.05 or h > SHELF_H[2] + 0.05 then
				warn_(("15: shelf anchor %s at h %.2f (MAP-01 §18.10: %.1f .. %.1f)"):format(i.Name, h, SHELF_H[1], SHELF_H[2]))
			end
		end
	end

	-- what Mart v2 took out (MAP-01 §18.8)
	local assets = Workspace:FindFirstChild("MAP01_Assets")
	if assets then
		for _, d in assets:GetDescendants() do
			local id = d:GetAttribute("MapId")
			if id == "GEAR_WALL" or id == "OP-1" then
				warn_(("15: %s (%s) still in MAP01_Assets: Mart v2 takes it out (MAP-01 §18.8)"):format(id, tostring(d:GetAttribute("Asset"))))
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Entry point
---------------------------------------------------------------------------------------------------

function Check.run(opts: { write: boolean?, wave: number? }?): (string, number)
	table.clear(errs)
	table.clear(warns)
	table.clear(infos)
	local write = not (opts and opts.write == false)
	WAVE = if opts and opts.wave then opts.wave else 3

	local content, src = loadContent()
	info("Content keys: " .. src)
	info(("checking binding wave %d"):format(WAVE))

	local root = checkTags()
	local points = checkPoints(root)
	checkContentValues(content)
	local vehicles = checkVehicles()
	checkPieces(vehicles)
	checkMapAnchors()
	checkMart(points)
	checkTables()
	checkVehicleDistances(vehicles)
	checkStreaming()
	checkPivots(vehicles)
	if WAVE >= 2 then
		checkWave2(points, vehicles)
	end
	if WAVE >= 3 then
		checkWave3(points, vehicles)
	end
	checkGraph(root)
	if WAVE >= 3 then
		checkSpawnSight(points)
		checkWalkerSight(points)
	end

	local pc, nc, ic = #tagged("MapPoint"), #tagged("NpcNode"), #tagged("Interactable")
	local written = "not written (errors)"
	if #errs == 0 and root then
		-- 8: version + counts
		local sig = {}
		for _, t in concat(editTags(), OPTIONAL_TAGS) do
			for _, i in tagged(t) do
				local attrs = {}
				for k, v in i:GetAttributes() do
					if k ~= "BindingVersion" and k ~= "BindingHash" and k ~= "PointCount" and k ~= "NodeCount" and k ~= "InteractableCount" then
						table.insert(attrs, k .. "=" .. tostring(v))
					end
				end
				table.sort(attrs)
				local p = pos(i)
				table.insert(sig, ("%s|%s|%s|%.2f,%.2f,%.2f"):format(t, i:GetFullName(), table.concat(attrs, ";"), p.X, p.Y, p.Z))
			end
		end
		table.sort(sig)
		local hash = djb2(table.concat(sig, "\n"))
		if write then
			local v = root:GetAttribute("BindingVersion")
			local ver = if typeof(v) == "number" then v else 0
			if root:GetAttribute("BindingHash") ~= hash then
				ver += 1
			end
			root:SetAttribute("BindingVersion", ver)
			root:SetAttribute("BindingHash", hash)
			root:SetAttribute("PointCount", pc)
			root:SetAttribute("NodeCount", nc)
			root:SetAttribute("InteractableCount", ic)
			written = ("written: BindingVersion %d, PointCount %d, NodeCount %d, InteractableCount %d"):format(ver, pc, nc, ic)
		else
			written = "not written (opts.write = false)"
		end
	end

	local out = {}
	table.insert(out, ("check_map01 (wave %d): %s | errors %d | warnings %d"):format(WAVE, if #errs == 0 then "PASS" else "FAIL", #errs, #warns))
	table.insert(out, ("counts: MapPoint %d, NpcNode %d, Interactable %d; root %s"):format(pc, nc, ic, written))
	for _, s in errs do
		table.insert(out, "[ERR] " .. s)
	end
	for _, s in warns do
		table.insert(out, "[warn] " .. s)
	end
	for _, s in infos do
		table.insert(out, "[info] " .. s)
	end
	local text = table.concat(out, "\n")
	print(text)
	return text, #errs
end

return Check
