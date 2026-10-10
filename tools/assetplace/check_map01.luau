--[[
	MAP-01 binding check (TASK-005 acceptance, docs/tech/architecture.md §18.7). Edit-mode tool, NOT gameplay code.
	Status: Rascunho (level-designer, 2026-10-10). §18.7 calls this tool check_binding.luau; this is that tool for
	MAP-01. The runtime twin is MapIndex.Validate + src/Place/shared/MapIndex/Required.luau (TASK-010): keep the
	REQUIRED lists below in sync with it.

	Reads only tags and attributes (never the bind script's data). Items of §18.7:
	  1. tags of §18.1 (wave 1, edit-time ones) present; exactly one MapBinding; PointId / NodeId unique
	  2. every PointId / Station / Interactable / Slot required by §18.4-§18.6 exists
	  3. StationKind, PromptAction, Ingredient, Package, Vehicle, BenchSlot are valid Content keys
	     (ReplicatedStorage.shared.Content when Rojo has synced it, else the lists embedded below)
	  4. anchors of different stations >= 2.5 apart; inside the toppings grid >= 2.0 (same ingredient exempt);
	     Mart shelves >= 2.5 (warn under 3.0, MAP-01 §7.4); bench >= 2.5
	  5. Station under a Vehicle; every Model that is/contains a tagged instance is Persistent; nothing tagged
	     outside the Workspace; Interactable = Attachment or invisible non-colliding BasePart
	  6. graph: connected, Links resolve, no space in Links, edge <= 40, <= 80 nodes, no edge over a carriageway
	     except a crosswalk edge (both ends with the same Crosswalk), queue chain Q5-Q4-Q3-Q2-Q1
	  7. pivots of the cart counter stations (G, R, B, T, K, DRAWER) at y 3.45 (DEC-157, Provisório until Q-153)
	  8. zero errors -> writes on the MapBinding root: BindingVersion (+1 when the binding hash changes),
	     PointCount, NodeCount, InteractableCount (+ BindingHash, tool metadata)
	Warnings (do not block): missing named fittings, obstacles on edges (knee/chest raycast), MapPoint off the
	floor / wrong facing, A* routes that shortcut through the queue.

	"Carriageway" rects (item 6) = the asphalt of Z-03 / Z-07 / Z-08 (MAP-01 §4 zones include the sidewalks, which
	NPCs must walk on): Ninth X -136..136 Z -16..16, Juniper North X -12..12 Z -152..-16, Juniper South X -12..12
	Z 16..120.

	Usage (edit mode):
		local Check = require(<this module>)   -- or: local Check = loadstring(<source>)()
		Check.run()                            -- prints and returns (report, errorCount); opts { write = false }
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Check = {}

---------------------------------------------------------------------------------------------------
-- Required (keep in sync with MapIndex/Required.luau)
---------------------------------------------------------------------------------------------------

local EDIT_TAGS = { "MapBinding", "MapPoint", "NpcNode", "Vehicle", "Station", "Interactable" }
local PENDING_TAGS = { "UpgradePiece" } -- wave 1 per §18.1 but no model yet (Cooler L2/L3, grill levels)

local REQUIRED_POINTS = { "PS-1", "PS-2", "PS-3", "PS-4", "Q1", "Q2", "Q3", "Q4", "Q5", "D1", "SP-A", "EX-E", "OP-1" }
local REQUIRED_NODES = { "SP-A", "D1", "EX-E", "Q1", "Q2", "Q3", "Q4", "Q5" }
local FACING = { -- expected LookVector of points (warn when > 10 degrees off)
	["PS-1"] = Vector3.new(0, 0, -1),
	["PS-2"] = Vector3.new(0, 0, -1),
	["PS-3"] = Vector3.new(0, 0, -1),
	["PS-4"] = Vector3.new(0, 0, -1),
	Q1 = Vector3.new(0, 0, 1),
	Q2 = Vector3.new(1, 0, 0),
	Q3 = Vector3.new(1, 0, 0),
	Q4 = Vector3.new(1, 0, 0),
	Q5 = Vector3.new(1, 0, 0),
	["OP-1"] = Vector3.new(0, 0, 1),
}

local TOPPING_KEYS = { "ketchup", "mustard", "cheese", "bacon", "potato_sticks", "cream_cheese" }

-- Per StationKind: actions with exact count (keyed), slot-attachment count, interactable slot range.
local REQUIRED_STATIONS = {
	sausage_stock = { actions = { grill_place = 1, restock = 1 } },
	grill = { slotInteractables = 4 }, -- grill_collect with Slot 1..4 (DEC-201)
	rail = { slots = 6 },
	bun_crate = { actions = { bun_cut = 1, restock = 1 } },
	board = { actions = { board_add_sausage = 1 }, slots = 2 }, -- DEC-190
	toppings = { perIngredient = { "topping_add", "restock" } },
	trash = { actions = { discard = 1 } },
}
local CART_STATION_KINDS = { "sausage_stock", "grill", "rail", "bun_crate", "board", "toppings", "trash" }
local REQUIRED_PACKAGES = {
	"pack_sausages",
	"pack_buns",
	"pack_ketchup",
	"pack_mustard",
	"pack_cheese",
	"pack_bacon",
	"pack_potato_sticks",
	"pack_cream_cheese",
	"pack_coffee",
}
local REQUIRED_BENCH = { B1 = "bench_buy_upgrade", B2 = "bench_buy_upgrade", B3 = "bench_buy_upgrade", B4 = "bench_buy_upgrade", B5 = "bench_buy_upgrade", S1 = "bench_buy_item" }
local NEVER_TAGGED = { Prompt_Rail = true, Prompt_Serve = true, Prompt_Drawer = true, Prompt_Grill = true }
local COUNTER_STATIONS = { "CART-G", "CART-R", "CART-B", "CART-T", "CART-K", "DRAWER" } -- by MapId (tool metadata)
local COUNTER_Y = 3.45

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
local ROUTES = { -- blockout routes of §18.6, as A* queries
	{ "SP-A", "Q5", "ROUTE-SP-A" },
	{ "D1", "Q5", "ROUTE-D1-IN" },
	{ "Q1", "EX-E", "ROUTE-EXIT-E" },
	{ "Q1", "D1", "ROUTE-EXIT-D1" },
}
local MAX_EDGE = 40
local MAX_NODES = 80

-- Embedded Content keys (content-data.md v4 §3.3, §3.4, §3.6, §3.8, §3.18) for when Rojo has not synced Content.
local FALLBACK = {
	Stations = { "sausage_stock", "grill", "rail", "bun_crate", "board", "toppings", "trash", "coffee_machine" },
	Actions = {
		"open_sign", "grill_place", "grill_collect", "bun_cut", "board_add_sausage", "topping_add", "discard",
		"take_order", "serve", "refuse", "restock", "buy_package", "bench_buy_upgrade", "bench_buy_item",
		"buy_trailer", "brew_coffee", "give_coffee", "switch_light", "hide", "safe_spot", "pick_up_item",
	},
	Ingredients = { "bun", "sausage", "ketchup", "mustard", "cheese", "bacon", "potato_sticks", "cream_cheese", "coffee" },
	Packages = REQUIRED_PACKAGES,
	Vehicles = { "cart", "trailer" },
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

local function loadContent(): ({ [string]: { [string]: boolean } }, string)
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
		end
		if not keys then
			keys = set(fallback)
			table.insert(src, tbl .. "=embedded")
		end
		out[tbl] = keys :: any
	end
	return out, table.concat(src, ", ")
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

---------------------------------------------------------------------------------------------------
-- Checks
---------------------------------------------------------------------------------------------------

local function checkTags(): Instance?
	for _, t in EDIT_TAGS do
		if #tagged(t) == 0 then
			err(("1: no instance with tag %s in the Workspace"):format(t))
		end
	end
	for _, t in PENDING_TAGS do
		if #tagged(t) == 0 then
			info(("1: tag %s absent (pending: upgrade pieces not modelled yet; owner TASK-035 / modeler-3d)"):format(t))
		end
	end
	local roots = tagged("MapBinding")
	if #roots ~= 1 then
		err(("1: %d MapBinding roots in the Workspace (need exactly 1)"):format(#roots))
	end
	-- 5: nothing tagged outside the Workspace
	for _, t in EDIT_TAGS do
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
	for _, id in REQUIRED_POINTS do
		if not byId[id] then
			err(("2: required MapPoint %s missing"):format(id))
		end
	end
	return byId
end

local function checkContentValues(content: any)
	local function validate(tag: string, attr: string, tbl: string)
		for _, i in tagged(tag) do
			local v = i:GetAttribute(attr)
			if v ~= nil and not content[tbl][v] then
				err(("3: %s.%s = %s is not a key of Content.%s"):format(name(i), attr, tostring(v), tbl))
			end
		end
	end
	validate("Station", "StationKind", "Stations")
	validate("Station", "Ingredient", "Ingredients")
	validate("Interactable", "PromptAction", "Actions")
	validate("Interactable", "Ingredient", "Ingredients")
	validate("Interactable", "Package", "Packages")
	validate("Vehicle", "Vehicle", "Vehicles")
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

local function checkStations(): Instance?
	local carts = {}
	for _, v in tagged("Vehicle") do
		if not v:IsA("Model") then
			err(("5: Vehicle %s is a %s"):format(name(v), v.ClassName))
		end
		if v:GetAttribute("Vehicle") == "cart" then
			table.insert(carts, v)
		elseif v:GetAttribute("Vehicle") == nil then
			err(("2: Vehicle %s without attribute Vehicle"):format(name(v)))
		end
	end
	if #carts ~= 1 then
		err(("2: %d Vehicle 'cart' in the Workspace (need 1)"):format(#carts))
	end
	local cart = carts[1]

	local byKind: { [string]: { Instance } } = {}
	for _, s in tagged("Station") do
		local k = s:GetAttribute("StationKind")
		if typeof(k) == "string" then
			byKind[k] = byKind[k] or {}
			table.insert(byKind[k], s)
		end
		if not ancestorWithTag(s, "Vehicle") then
			err(("5: Station %s is not a descendant of a Vehicle"):format(name(s)))
		end
	end
	for _, kind in CART_STATION_KINDS do
		local list = byKind[kind] or {}
		local inCart = {}
		for _, s in list do
			if cart and s:IsDescendantOf(cart) then
				table.insert(inCart, s)
			end
		end
		if #inCart ~= 1 then
			err(("2: %d Station '%s' in the cart (need 1)"):format(#inCart, kind))
			continue
		end
		local st = inCart[1]
		local req = (REQUIRED_STATIONS :: any)[kind]
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
					err(("2: %s (%s): %d anchor(s) %s, need %d"):format(kind, name(st), acts[a] or 0, a, n))
				end
			end
		end
		if req.slotInteractables then
			for sl = 1, req.slotInteractables do
				if slotInter[sl] ~= 1 then
					err(("2: grill: grill_collect with Slot %d found %d time(s), need 1"):format(sl, slotInter[sl] or 0))
				end
			end
			if (acts.grill_collect or 0) ~= req.slotInteractables then
				err(("2: grill: %d grill_collect anchors, need %d"):format(acts.grill_collect or 0, req.slotInteractables))
			end
		end
		if req.slots then
			local seen: { [number]: number } = {}
			for _, d in st:GetDescendants() do
				local sl = d:GetAttribute("Slot")
				if typeof(sl) == "number" and not CollectionService:HasTag(d, "Interactable") then
					seen[sl] = (seen[sl] or 0) + 1
					if not d:IsA("Attachment") then
						warn_(("%s: slot %s is a %s (Attachment preferred)"):format(kind, name(d), d.ClassName))
					end
				end
			end
			for sl = 1, req.slots do
				if seen[sl] ~= 1 then
					err(("2: %s: slot Attachment with Slot %d found %d time(s), need 1"):format(kind, sl, seen[sl] or 0))
				end
			end
		end
		if req.perIngredient then
			for _, ing in TOPPING_KEYS do
				for _, a in req.perIngredient do
					local n = perIng[ing] and perIng[ing][a] or 0
					if n ~= 1 then
						err(("2: toppings: %s with Ingredient %s found %d time(s), need 1"):format(a, ing, n))
					end
				end
			end
		end
		-- named fittings (warn)
		local fittings = ({
			sausage_stock = { "Fill", "Lid", "VFX_Upgrade" },
			bun_crate = { "Fill" },
			trash = { "Lid" },
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
				warn_(("%s: named fitting %s missing (visual, read by KitchenController)"):format(kind, f))
			end
		end
	end
	if cart then
		if not cart:FindFirstChild("Value_Anchor", true) then
			err("2: Value_Anchor missing inside the cart Vehicle (TASK-024)")
		end
		if not cart:FindFirstChild("Zone_Center", true) then
			warn_("cart: Zone_Center missing (thief radius 14, DEC-050)")
		end
		for _, f in { "Bar_Thief", "VFX_Coins" } do
			if not cart:FindFirstChild(f, true) then
				warn_(("cart: named fitting %s missing (DRAWER)"):format(f))
			end
		end
	end
	return cart
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
end

local function checkCartDistances(cart: Instance?)
	if not cart then
		return
	end
	local list = {}
	for _, i in tagged("Interactable") do
		if i:IsDescendantOf(cart) then
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
					err(("4: %s / %s (different stations) %.2f apart (< 2.5)"):format(name(a), name(b), d))
				end
			elseif oa and oa:GetAttribute("StationKind") == "toppings" then
				local ia, ib = a:GetAttribute("Ingredient"), b:GetAttribute("Ingredient")
				if ia ~= ib and d < 2.0 - 0.01 then -- same-row bowls are exactly 2.0 apart in the model
					err(("4: toppings %s / %s %.2f apart (< 2.0)"):format(a.Name, b.Name, d))
				end
			end
		end
	end
	if closest < math.huge then
		info(("4: closest pair of anchors of different cart stations: %.2f studs"):format(closest))
	end
end

local function checkStreaming()
	local bad = {}
	for _, t in EDIT_TAGS do
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

local function checkPivots()
	local assets = Workspace:FindFirstChild("MAP01_Assets")
	if not assets then
		err("7: workspace.MAP01_Assets missing")
		return
	end
	for _, id in COUNTER_STATIONS do
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
			if math.abs(y - COUNTER_Y) > 0.05 then
				err(("7: %s pivot at y %.3f, need %.2f (DEC-157, Provisório until Q-153)"):format(id, y, COUNTER_Y))
			end
		end
	end
end

type Node = { id: string, inst: Instance, p: Vector3, links: { string }, cw: string? }

local function astar(nodes: { [string]: Node }, adj: { [string]: { [string]: boolean } }, from: string, to: string, noQueueMid: boolean): ({ string }?, number)
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
				if not closed[nb] then
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
	for _, id in REQUIRED_NODES do
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
	-- review / demo scenes are not part of the map (CrewDemo, AssetReview, __Preview_*)
	for _, c in Workspace:GetChildren() do
		if c.Name == "CrewDemo" or c.Name == "AssetReview" or string.sub(c.Name, 1, 10) == "__Preview_" then
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
	for _, r in ROUTES do
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
				warn_(("route %s: plain A* walks THROUGH the queue slots. With 'Q nodes never intermediate' it is %s (%.0f studs). Rule for MapIndex.Path / TASK-031, see report"):format(r[3], if alt then table.concat(alt, " > ") else "impossible", altLen))
			end
		end
	end
	info(("6: graph %d nodes, %d edges"):format(count, edges))
end

---------------------------------------------------------------------------------------------------
-- Entry point
---------------------------------------------------------------------------------------------------

function Check.run(opts: { write: boolean? }?): (string, number)
	table.clear(errs)
	table.clear(warns)
	table.clear(infos)
	local write = not (opts and opts.write == false)

	local content, src = loadContent()
	info("Content keys: " .. src)

	local root = checkTags()
	checkPoints(root)
	checkContentValues(content)
	local cart = checkStations()
	checkMapAnchors()
	checkCartDistances(cart)
	checkStreaming()
	checkPivots()
	checkGraph(root)

	local pc, nc, ic = #tagged("MapPoint"), #tagged("NpcNode"), #tagged("Interactable")
	local written = "not written (errors)"
	if #errs == 0 and root then
		-- 8: version + counts
		local sig = {}
		for _, t in EDIT_TAGS do
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
	table.insert(out, ("check_map01: %s | errors %d | warnings %d"):format(if #errs == 0 then "PASS" else "FAIL", #errs, #warns))
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
