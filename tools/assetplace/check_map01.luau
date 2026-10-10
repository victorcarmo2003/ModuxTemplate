--[[
	MAP-01 binding check, waves 1 + 2 (TASK-005, TASK-083; docs/tech/architecture.md §18.7, §19.22). Edit-mode tool,
	NOT gameplay code. Status: Rascunho (level-designer, 2026-10-10). §18.7 calls this tool check_binding.luau; this is
	that tool for MAP-01. The runtime twin is MapIndex.Validate + src/Place/shared/MapIndex/Required.luau
	(Required.Wave1 / Wave2 from TASK-048): keep the lists below in sync with it (wave 2 list: MAP-01 §16.4).

	Reads only tags and attributes (never the bind script's data). Items of §18.7 (wave 1) + §19.22 (wave 2):
	  1. tags present (wave 1: MapBinding MapPoint NpcNode Vehicle Station Interactable UpgradePiece; wave 2: + LightZone
	     StreetLight VehicleCover); exactly one MapBinding; PointId / NodeId / ZoneId / PostId unique
	  2. every PointId / Station / Interactable required exists, per vehicle (cart; wave 2 also trailer with Rail 8,
	     board 3, coffee_machine) and vehicle-level prompts (answer_phone; trailer switch_light, buy_trailer)
	  3. StationKind, PromptAction, Ingredient, Package, Vehicle, BenchSlot, LightZone/StreetLight Group are valid
	     Content keys (ReplicatedStorage.shared.Content when Rojo has synced it, else the lists embedded below; a
	     wave-2 key missing from a synced Content is a warning "TASK-047 pending", not an error)
	  4. anchors of different owners in the same vehicle >= 2.5 apart; toppings grid >= 2.0 (same ingredient
	     exempt); Mart shelves >= 2.5 (warn under 3.0, MAP-01 §7.4); bench >= 2.5
	  5. Station under a Vehicle; every Model that is/contains a tagged instance is Persistent; nothing tagged
	     outside the Workspace; Interactable = Attachment or invisible non-colliding BasePart; LightZone invisible
	  6. graph: connected, Links resolve, no space in Links, edge <= 40, <= 80 nodes, no edge over a carriageway
	     except a crosswalk edge, queue chain Q5-Q4-Q3-Q2-Q1; wave 2: thief routes exist without queue slots and
	     without crosswalk edges (MAP-01 §9.2: never crosses a road)
	  7. pivots of the counter stations: cart at y 3.45 (DEC-157, Provisório until Q-153); trailer at pivot + 5.5
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
		Check.run({ wave = 2 })   -- prints and returns (report, errorCount); opts { wave = 1 | 2 (default 2), write = false }
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
local EDIT_TAGS_W2 = { "LightZone", "StreetLight", "VehicleCover" }
local OPTIONAL_TAGS = { "StreetBin" } -- DEC-200 / T60: checked, never required (Q-166 b)

-- Upgrade pieces expected per vehicle (copy of src/Shared/Content/Upgrades.luau rows with Part ~= ""; a synced
-- Content.Upgrades wins). start = StartLevel (the piece visible in the authored place).
local PIECE_ROWS_EMBEDDED = (function()
	local rows = {}
	for _, v in { "cart", "trailer" } do
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
	"TRL", "TRL-SALE", "CART",
	"SPEC-P", "SPEC-M",
	"DROP-T",
	"L1", "L2", "L3", "ST-R",
	"SIGN-T", -- level-designer proposal (MAP-01 §16): where VehicleController draws the sale sign
}
local NODES_W1 = { "SP-A", "D1", "EX-E", "Q1", "Q2", "Q3", "Q4", "Q5" }
local NODES_W2 = { "ST-R", "L1", "L2", "L3" }

local N, S, E, W = Vector3.new(0, 0, -1), Vector3.new(0, 0, 1), Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0)
local FACING = { -- expected LookVector of points (warn when > 10 degrees off)
	["PS-1"] = N, ["PS-2"] = N, ["PS-3"] = N, ["PS-4"] = N,
	Q1 = S, Q2 = E, Q3 = E, Q4 = E, Q5 = E,
	["OP-1"] = S,
	["PS-N1"] = N, ["PS-N2"] = N, ["PS-N3"] = N, ["PS-N4"] = N,
	["REV-1"] = S, ["REV-2"] = S, ["REV-3"] = S, ["REV-4"] = S,
	TRL = N, CART = N, ["TRL-SALE"] = S, ["SIGN-T"] = S, ["DROP-T"] = N, ["ST-R"] = N,
}
local _ = W

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
	cart = {
		wave = 1,
		kinds = { "sausage_stock", "grill", "rail", "bun_crate", "board", "toppings", "trash" },
		own = { [2] = { answer_phone = 1 } }, -- vehicle-level prompts (owner not a Station), by wave
		slots = { RailSlots = 6, BoardSlots = 2 },
		counter = { ids = { "CART-G", "CART-R", "CART-B", "CART-T", "CART-K", "DRAWER" }, absY = 3.45 },
	},
	trailer = {
		wave = 2,
		kinds = { "sausage_stock", "grill", "rail", "bun_crate", "board", "toppings", "trash", "coffee_machine" },
		own = { [2] = { answer_phone = 1, switch_light = 1, buy_trailer = 1 } },
		slots = { RailSlots = 8, BoardSlots = 3 },
		counter = { ids = { "TRL-G", "TRL-R", "TRL-B", "TRL-T", "TRL-K", "TRL-DRAWER" }, relY = 5.5 },
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
local POSTS = { -- PostId -> Order (Hush order: JL-09 first, P-01 last; Walker step = Order - 1)
	["JL-09"] = 1, ["JL-08"] = 2, ["JL-07"] = 3, ["JL-06"] = 4, ["JL-05"] = 5,
	["JL-04"] = 6, ["JL-03"] = 7, ["JL-02"] = 8, ["JL-01"] = 9, ["P-01"] = 10,
}
local POST_GROUP = "juniper_posts"

local ROADS = {
	{ name = "Ninth", x0 = -136, x1 = 136, z0 = -16, z1 = 16 },
	{ name = "Juniper North", x0 = -12, x1 = 12, z0 = -152, z1 = -16 },
	{ name = "Juniper South", x0 = -12, x1 = 12, z0 = 16, z1 = 120 },
}
local CROSSWALKS = {
	["CW-1"] = { x0 = -12, x1 = 12, z0 = 34, z1 = 42 },
	["CW-2"] = { x0 = -24, x1 = -12, z0 = -16, z1 = 16 },
	["CW-3"] = { x0 = 54, x1 = 60, z0 = -16, z1 = 16 },
	["CW-4"] = { x0 = 12, x1 = 24, z0 = -16, z1 = 16 },
}
local ROUTES_W1 = { -- blockout routes of §18.6, as A* queries
	{ "SP-A", "Q5", "ROUTE-SP-A" },
	{ "D1", "Q5", "ROUTE-D1-IN" },
	{ "Q1", "EX-E", "ROUTE-EXIT-E" },
	{ "Q1", "D1", "ROUTE-EXIT-D1" },
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

-- Embedded Content keys (content-data.md v5 §3.3, §3.4, §3.6, §3.8, §3.18, §6.4, §6.9) for when Rojo has not
-- synced Content. WAVE2 = keys that a synced Content may still lack until TASK-047 lands (warning, not error).
local FALLBACK = {
	Stations = { "sausage_stock", "grill", "rail", "bun_crate", "board", "toppings", "trash", "coffee_machine" },
	Actions = {
		"open_sign", "grill_place", "grill_collect", "bun_cut", "board_add_sausage", "topping_add", "discard",
		"take_order", "serve", "refuse", "restock", "buy_package", "bench_buy_upgrade", "bench_buy_item",
		"buy_trailer", "brew_coffee", "give_coffee", "switch_light", "hide", "safe_spot", "pick_up_item",
		"answer_phone", "get_up",
	},
	Ingredients = { "bun", "sausage", "ketchup", "mustard", "cheese", "bacon", "potato_sticks", "cream_cheese", "coffee" },
	Packages = REQUIRED_PACKAGES,
	Vehicles = { "cart", "trailer" },
	LightGroups = { "mart", "trailer_interior", "trailer_lights", "juniper_posts" },
	Upgrades = { "grill", "cooler", "counter", "cash_drawer_lock", "trailer_lights" },
}
local WAVE2_KEYS = {
	Actions = { answer_phone = true, get_up = true, buy_trailer = true, brew_coffee = true, switch_light = true },
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

local WAVE = 2
local function editTags(): { string }
	return if WAVE >= 2 then concat(EDIT_TAGS_W1, EDIT_TAGS_W2) else EDIT_TAGS_W1
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
	pairs_(shelves, 2.5, 3.0, "Mart shelves")
	pairs_(benches, 2.5, 2.5, "GEAR WALL")

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
		info(("street bins: %d StreetBin (Q-166 b, Provisório: all AST-034_TrashCan)"):format(#bins))
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
					if d < 2.5 then
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
						err(("7: %s pivot at y %.3f, need %.2f (DEC-157, Provisório until Q-153)"):format(id, y, spec.counter.absY))
					end
				elseif math.abs((y - base) - spec.counter.relY) > COUNTER_TOL then
					err(("7: %s pivot %.3f above the trailer pivot, need %.2f (floor +2, counter 3.5)"):format(id, y - base, spec.counter.relY))
				end
			end
		end
	end
end

-- wave 2: vehicle poses, tarp, light zones, street lights, DROP-T in the light
local function checkWave2(points: { [string]: Instance }, vehicles: { [string]: Instance })
	-- vehicle poses (T36): start of a run = cart at CART, trailer at TRL-SALE
	local function near(v: Instance?, pid: string, label: string)
		local p = points[pid]
		if not (v and p and p:IsA("BasePart")) then
			return
		end
		local vp = (v :: any):GetPivot() :: CFrame
		local cf = (p :: BasePart).CFrame
		if (vp.Position - cf.Position).Magnitude > 0.1 or vp.LookVector:Dot(cf.LookVector) < 0.999 then
			warn_(("%s pivot %s is not at MapPoint %s %s (start of a run: run Bind.run again)"):format(label, fmtV(vp.Position), pid, fmtV(cf.Position)))
		end
	end
	near(vehicles.cart, "CART", "cart")
	near(vehicles.trailer, "TRL-SALE", "trailer")
	local trlPt, salePt = points.TRL, points["TRL-SALE"]
	if trlPt and salePt and (pos(trlPt) - pos(salePt)).Magnitude < 20 then
		err("2: TRL and TRL-SALE are closer than 20 studs (wrong vehicle poses)")
	end

	-- tarp (DEC-199, T38)
	local covers = tagged("VehicleCover")
	if #covers ~= 1 then
		err(("2: %d VehicleCover (need 1)"):format(#covers))
	end
	for _, c in covers do
		if not c:IsA("Model") then
			err(("5: VehicleCover %s is a %s (must be a Model)"):format(name(c), c.ClassName))
		end
		if not (vehicles.cart and c:IsDescendantOf(vehicles.cart)) then
			warn_(("VehicleCover %s is not inside the cart Vehicle (it must travel with the cart, T36)"):format(name(c)))
		end
		if not isHidden(c) then
			warn_(("VehicleCover %s is visible in the place (authored hidden until the swap, §19.22)"):format(name(c)))
		end
		for _, d in c:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("OrigTransparency") == nil then
				warn_(("VehicleCover part %s without OrigTransparency/OrigCanCollide/OrigCanQuery (visible values for T38)"):format(name(d)))
			end
		end
	end

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
		local p = Vector3.new(x, 3.4, 44)
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
			err(("3: StreetLight %s PostId = %s (valid JL-01..JL-09, P-01)"):format(name(m), tostring(id)))
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
			err(("2: StreetLight %s Order = %s, need %d (Hush JL-09 -> JL-01 -> P-01, MAP-01 §5.6)"):format(id, tostring(o), POSTS[id]))
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
	for _, id in (if WAVE >= 2 then concat(NODES_W1, NODES_W2) else NODES_W1) do
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
	for _, r in ROUTES_W1 do
		local path, len = astar(nodes, adj, r[1], r[2], false)
		if not path then
			err(("6: no path %s -> %s (%s)"):format(r[1], r[2], r[3]))
		else
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
		if not isHidden(p) then
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
		if vk and vehicles[vk] then
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

---------------------------------------------------------------------------------------------------
-- Entry point
---------------------------------------------------------------------------------------------------

function Check.run(opts: { write: boolean?, wave: number? }?): (string, number)
	table.clear(errs)
	table.clear(warns)
	table.clear(infos)
	local write = not (opts and opts.write == false)
	WAVE = if opts and opts.wave then opts.wave else 2

	local content, src = loadContent()
	info("Content keys: " .. src)
	info(("checking binding wave %d"):format(WAVE))

	local root = checkTags()
	local points = checkPoints(root)
	checkContentValues(content)
	local vehicles = checkVehicles()
	checkPieces(vehicles)
	checkMapAnchors()
	checkVehicleDistances(vehicles)
	checkStreaming()
	checkPivots(vehicles)
	if WAVE >= 2 then
		checkWave2(points, vehicles)
	end
	checkGraph(root)

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
