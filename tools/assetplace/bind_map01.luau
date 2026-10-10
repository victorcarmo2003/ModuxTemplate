--[[
	MAP-01 binding (TASK-005). Edit-mode tool, same status as place_assets.luau: NOT gameplay code.
	Status: Rascunho (level-designer, 2026-10-10).

	Contract: docs/tech/architecture.md §18 (tags §18.1, attributes §18.2, anchors §18.3-§18.4, points §18.5,
	NpcNode graph §18.6). Layout: docs/levels/MAP-01.md §5.1, §5.3, §7.1, §7.4, §9.1. DEC-157 (cart counter at
	y 3.45), DEC-190 (board with 2 shared slots), DEC-201 (grill levels = more rollers, 2/3/4 slots).

	What it does, over workspace.MAP01_Assets (built by place_assets.luau) and workspace.MapBinding:
	  1. Clean slate: removes the §18.1 tags it owns and the §18.2 authored attributes from every descendant of
	     MAP01_Assets, so a re-run never leaves stale data (e.g. Prompt_Rail / Prompt_Serve stay untagged).
	  2. Cart: CART (AST-026) gets tag Vehicle + Vehicle = "cart"; CART-*, DRAWER and BIN-C models are re-parented
	     INSIDE the CART model (world positions unchanged), so stations find their vehicle by ancestry (§18.4, T36).
	  3. Stations S, G, R, B, T, K and BIN-C: tag Station + StationKind (+ Ingredient); anchors tagged Interactable
	     with PromptAction (+ Slot / Ingredient). Slots of grill (4), rail (6) and board (2: Att_Bun1/Att_Bun2).
	  4. Map anchors: OPEN sign (open_sign), 9 Mart shelf anchors in a new Model MKT-SHELVES (buy_package +
	     Package), GEAR WALL B1..B5 (bench_buy_upgrade) and S1 (bench_buy_item) + BenchSlot.
	  5. Named fittings the code reads but the .fbx may lack: DRAWER.Value_Anchor, CART.Zone_Center.
	  6. workspace.MapBinding (Model, tag MapBinding): MapPoint parts PS-1..4, Q1..Q5, D1, SP-A, EX-E, OP-1 and
	     the NpcNode graph SP-A / D1 -> Q5 -> ... -> Q1 -> EX-E / D1 (Links on both ends). Y by raycast to the floor.
	  7. ModelStreamingMode = Persistent on every Model that is, or contains, a tagged instance (§18.0 item 6).

	Anchor lookup (§18.3: "TASK-005 confere no place se os empties chegaram como Attachment"):
	  - Attachment with the expected name            -> used as is ("ok").
	  - BasePart with that name                       -> used as anchor, forced invisible / no collide ("ok part").
	  - other class with that name (Model, Folder...) -> renamed <name>_Src, Attachment created at its pivot ("conv").
	  - nothing                                       -> Attachment created at a fallback position ("new"), with
	                                                     attribute BindCreated = true. Fallbacks follow MAP-01 §7.1
	                                                     coordinates and are kept on re-runs (hand-tuning survives),
	                                                     unless opts.resetCreated = true.

	IMPORTANT: place_assets.luau Place.run() destroys and rebuilds MAP01_Assets. After every Place.run, run
	Bind.run() again (MapBinding lives outside MAP01_Assets and survives). Run with the DAY layer visible
	(Place.showLayer("day")): the cart set must be in the Workspace.

	Usage (edit mode, Command Bar or Studio MCP):
		local Bind = require(<this module>)     -- or: local Bind = loadstring(<source>)()
		print(Bind.run())                       -- opts: { resetCreated = false }
	Then run check_map01.luau (acceptance list of §18.7).
]]

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Bind = {}

local ASSETS_ROOT = "MAP01_Assets"
local BINDING_ROOT = "MapBinding"
local CREATED = "BindCreated"
local SRC_NAME = "SrcName"

local COUNTER_Y = 3.45 -- cart counter top (DEC-157; Provisório until Q-153)

local OWN_TAGS = { "MapBinding", "MapPoint", "NpcNode", "Vehicle", "Station", "Interactable" }
local AUTHORED_ATTRS = {
	"PointId",
	"NodeId",
	"Links",
	"Crosswalk",
	"Vehicle",
	"StationKind",
	"Ingredient",
	"PromptAction",
	"Slot",
	"Level",
	"Package",
	"BenchSlot",
}

local NORTH = Vector3.new(0, 0, -1)
local SOUTH = Vector3.new(0, 0, 1)
local EAST = Vector3.new(1, 0, 0)
local WEST = Vector3.new(-1, 0, 0)

---------------------------------------------------------------------------------------------------
-- DATA (MAP-01). x, z = world studs; floor = expected floor top (Pad 0.45, Ninth sidewalk / Mart 0.4,
-- Juniper sidewalk tiles 0.24); the raycast result is used when it is within 0.6 of it.
---------------------------------------------------------------------------------------------------

-- MapPoint (§18.5). node = true -> the same Part is also an NpcNode (NodeId omitted, PointId is the id).
local POINTS = {
	{ id = "PS-1", x = 32, z = 42, floor = 0.45, face = NORTH },
	{ id = "PS-2", x = 38, z = 42, floor = 0.45, face = NORTH },
	{ id = "PS-3", x = 44, z = 42, floor = 0.45, face = NORTH },
	{ id = "PS-4", x = 50, z = 42, floor = 0.45, face = NORTH },
	{ id = "Q1", x = 52, z = 33, floor = 0.45, face = SOUTH, node = true },
	{ id = "Q2", x = 46, z = 29, floor = 0.4, face = EAST, node = true },
	{ id = "Q3", x = 41, z = 29, floor = 0.4, face = EAST, node = true },
	{ id = "Q4", x = 36, z = 29, floor = 0.4, face = EAST, node = true },
	{ id = "Q5", x = 31, z = 29, floor = 0.4, face = EAST, node = true },
	-- D1: MAP-01 gives (64, 48) = the door plane on B1's west wall (X 64). Point 1 stud out, on the Pad, so an
	-- NPC never spawns inside the wall. Faces west (out of the door).
	{ id = "D1", x = 63, z = 48, floor = 0.45, face = WEST, node = true },
	{ id = "SP-A", x = 30, z = -104, floor = 0.24, face = WEST, node = true },
	{ id = "EX-E", x = 116, z = 24, floor = 0.4, face = EAST, node = true },
	-- Opal behind the checkout, back to the north glass, facing into the store (south).
	{ id = "OP-1", x = -75, z = 33.5, floor = 0.4, face = SOUTH },
}

-- NpcNode-only parts (NodeId = N-<zone>-<nn>, §18.6). crosswalk = the two curb nodes of a crosswalk.
local NODES = {
	-- ROUTE-SP-A: Juniper North east sidewalk (X 18), CW-4, Ninth south sidewalk (LANE-E, Z 23)
	{ id = "N-Z13-01", x = 18, z = -104, floor = 0.24 },
	{ id = "N-Z13-02", x = 18, z = -84, floor = 0.24 },
	{ id = "N-Z07-01", x = 18, z = -62, floor = 0.24 },
	{ id = "N-Z07-02", x = 18, z = -40, floor = 0.24 },
	{ id = "N-Z06-01", x = 18, z = -17, floor = 0.4, crosswalk = "CW-4" },
	{ id = "N-Z02-01", x = 18, z = 17, floor = 0.4, crosswalk = "CW-4" },
	{ id = "N-Z02-02", x = 18, z = 23, floor = 0.4 },
	{ id = "N-Z02-03", x = 26, z = 23, floor = 0.4 }, -- shared by ROUTE-SP-A and ROUTE-D1-IN, last node before Q5
	-- ROUTE-D1-IN: D1 -> Pad east side -> LANE-W (Z 18) -> west -> up to Q5
	{ id = "N-Z01-01", x = 62, z = 33, floor = 0.45 },
	{ id = "N-Z02-06", x = 62, z = 18, floor = 0.4 },
	{ id = "N-Z02-05", x = 44, z = 18, floor = 0.4 },
	{ id = "N-Z02-04", x = 26, z = 18, floor = 0.4 },
	-- ROUTE-EXIT-E: Q1 -> LANE-E -> EX-E
	{ id = "N-Z02-07", x = 55, z = 23, floor = 0.4 },
	{ id = "N-Z02-08", x = 84, z = 23, floor = 0.4 },
	{ id = "N-Z02-09", x = 112, z = 23, floor = 0.4 },
	-- ROUTE-EXIT-D1: Q1 -> east of the cart -> D1
	{ id = "N-Z01-02", x = 58, z = 33, floor = 0.45 },
	{ id = "N-Z01-03", x = 58, z = 47, floor = 0.45 },
}

local EDGES = {
	-- ROUTE-SP-A
	{ "SP-A", "N-Z13-01" },
	{ "N-Z13-01", "N-Z13-02" },
	{ "N-Z13-02", "N-Z07-01" },
	{ "N-Z07-01", "N-Z07-02" },
	{ "N-Z07-02", "N-Z06-01" },
	{ "N-Z06-01", "N-Z02-01" }, -- CW-4 crosswalk edge (reservation in wave 2; free in wave 1)
	{ "N-Z02-01", "N-Z02-02" },
	{ "N-Z02-02", "N-Z02-03" },
	{ "N-Z02-03", "Q5" }, -- arrivals link only to Q5 (§18.6)
	-- ROUTE-D1-IN
	{ "D1", "N-Z01-01" },
	{ "N-Z01-01", "N-Z02-06" },
	{ "N-Z02-06", "N-Z02-05" },
	{ "N-Z02-05", "N-Z02-04" },
	{ "N-Z02-04", "N-Z02-03" },
	-- ROUTE-QUEUE
	{ "Q5", "Q4" },
	{ "Q4", "Q3" },
	{ "Q3", "Q2" },
	{ "Q2", "Q1" },
	-- ROUTE-EXIT-E
	{ "Q1", "N-Z02-07" },
	{ "N-Z02-07", "N-Z02-08" },
	{ "N-Z02-08", "N-Z02-09" },
	{ "N-Z02-09", "EX-E" },
	-- ROUTE-EXIT-D1
	{ "Q1", "N-Z01-02" },
	{ "N-Z01-02", "N-Z01-03" },
	{ "N-Z01-03", "D1" },
}

-- Ingredient key -> .fbx suffix (PascalCase rule of §18.4) and MAP-01 §7.1 grid cell (fallback XZ).
-- Front row (queue side, north) Ketchup / Mustard / Cheese; back row Bacon / Potato Sticks / Cream Cheese.
-- x, z are used ONLY when the real bowl Bin_<Suf> is missing (see bindToppings: anchors live on the bowls).
local TOPPINGS = {
	{ key = "ketchup", suf = "Ketchup", x = 45, z = 36.5 },
	{ key = "mustard", suf = "Mustard", x = 47, z = 36.5 },
	{ key = "cheese", suf = "Cheese", x = 49, z = 36.5 },
	{ key = "bacon", suf = "Bacon", x = 45, z = 38.5 },
	{ key = "potato_sticks", suf = "PotatoSticks", x = 47, z = 38.5 },
	{ key = "cream_cheese", suf = "CreamCheese", x = 49, z = 38.5 },
}

-- Mart shelf purchase points (MAP-01 §7.4), anchor ~4.5 above the floor (0.4).
local SHELVES = {
	{ name = "Sausages", package = "pack_sausages", x = -69, z = 40 },
	{ name = "Buns", package = "pack_buns", x = -69, z = 44 },
	{ name = "Ketchup", package = "pack_ketchup", x = -75, z = 40 },
	{ name = "Mustard", package = "pack_mustard", x = -75, z = 44 },
	{ name = "Cheese", package = "pack_cheese", x = -81, z = 40 },
	{ name = "Bacon", package = "pack_bacon", x = -81, z = 44 },
	{ name = "PotatoSticks", package = "pack_potato_sticks", x = -75, z = 48 },
	{ name = "CreamCheese", package = "pack_cream_cheese", x = -81, z = 48 },
	{ name = "Coffee", package = "pack_coffee", x = -68, z = 35 },
}
local MART_FLOOR = 0.4
local SHELF_ANCHOR_H = 4.5

-- GEAR WALL (AST-049) prompts (MAP-01 §7.4): bench X -100..-98, top 3.5 above the Mart floor.
local BENCH = {
	{ slot = "B1", action = "bench_buy_upgrade", z = 40.5 },
	{ slot = "B2", action = "bench_buy_upgrade", z = 43.5 },
	{ slot = "S1", action = "bench_buy_item", z = 46.5 },
	{ slot = "B3", action = "bench_buy_upgrade", z = 49.5 },
	{ slot = "B4", action = "bench_buy_upgrade", z = 52.5 },
	{ slot = "B5", action = "bench_buy_upgrade", z = 55.5 },
}

-- Grill (AST-012): the .fbx has 6 slot empties; DEC-201 uses 4 (L1 1-2, L2 1-3, L3 1-4). Pick = the 4 central
-- ones after sorting left -> right as seen from the corridor (+X). Same positions at every level (no Level attr).
local GRILL_SLOTS = 4
local GRILL_FALLBACK_DX = { -1.35, -0.45, 0.45, 1.35 } -- 0.9 between centres (asset-list AST-012)
local RAIL_SLOTS = 6
local BUN_SLOT_HALF = 0.55 -- Att_Bun1/Att_Bun2 = Att_Bun -/+ this along its local X (verify visually, TASK-030)

---------------------------------------------------------------------------------------------------
-- Report
---------------------------------------------------------------------------------------------------

local report: { string } = {}
local counts = { ok = 0, new = 0, conv = 0, warn = 0, err = 0 }

local function log(kind: string, msg: string)
	counts[kind] = (counts[kind] or 0) + 1
	table.insert(report, ("[%s] %s"):format(kind, msg))
end

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------

local function fmtV(v: Vector3): string
	return ("(%.2f, %.2f, %.2f)"):format(v.X, v.Y, v.Z)
end

local function anchorPos(a: Instance): Vector3
	if a:IsA("Attachment") then
		return a.WorldPosition
	elseif a:IsA("BasePart") then
		return a.Position
	elseif a:IsA("PVInstance") then
		return (a :: any):GetPivot().Position
	end
	return Vector3.zero
end

local function setPersistent(m: Instance)
	if m:IsA("Model") and m.ModelStreamingMode ~= Enum.ModelStreamingMode.Persistent then
		m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end
end

local function makeInvisible(p: BasePart)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Anchored = true
end

-- First model under `root` with MapId = id (and Asset = asset, if given).
local function byMapId(root: Instance, id: string, asset: string?): Instance?
	for _, d in root:GetDescendants() do
		if d:GetAttribute("MapId") == id and (asset == nil or d:GetAttribute("Asset") == asset) then
			return d
		end
	end
	return nil
end

-- Descendant by name; prefers an Attachment when several share the name.
local function findNamed(model: Instance, name: string): Instance?
	local first: Instance? = nil
	for _, d in model:GetDescendants() do
		if d.Name == name then
			if d:IsA("Attachment") then
				return d
			end
			first = first or d
		end
	end
	return first
end

-- BasePart that hosts created Attachments: PrimaryPart, else the largest BasePart (name breaks ties).
local function hostPart(model: Instance): BasePart?
	if model:IsA("Model") and model.PrimaryPart then
		return model.PrimaryPart
	end
	if model:IsA("BasePart") then
		return model
	end
	local best: BasePart? = nil
	local bestV = -1
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if v > bestV or (v == bestV and best and d.Name < best.Name) then
				best, bestV = d, v
			end
		end
	end
	return best
end

-- World bounding box of the BaseParts of `model` that pass `keep` (all when nil): min, max.
local function partsBox(model: Instance, keep: ((BasePart) -> boolean)?): (Vector3?, Vector3?)
	local mn, mx = nil, nil
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 and (keep == nil or keep(d)) then
			local cf, s = d.CFrame, d.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local p = cf:PointToWorldSpace(Vector3.new(s.X * sx, s.Y * sy, s.Z * sz))
						mn = if mn then mn:Min(p) else p
						mx = if mx then mx:Max(p) else p
					end
				end
			end
		end
	end
	return mn, mx
end

local function topY(model: Instance): number
	local _, mx = partsBox(model)
	return if mx then mx.Y else COUNTER_Y
end

local function newAttachment(host: BasePart, name: string, worldPos: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Parent = host
	a.WorldCFrame = CFrame.new(worldPos)
	a:SetAttribute(CREATED, true)
	return a
end

type AnchorOpts = { resetCreated: boolean? }

-- Finds or creates the anchor `name` inside `model`. fallback() = world position used when it must be created.
local function ensureAnchor(model: Instance, name: string, fallback: () -> Vector3, opts: AnchorOpts, label: string): Instance?
	local found = findNamed(model, name)
	if found then
		if found:IsA("Attachment") then
			if found:GetAttribute(CREATED) then
				if opts.resetCreated then
					found.WorldCFrame = CFrame.new(fallback())
				end
				log("new", ("%s: %s kept (created by binding) at %s"):format(label, name, fmtV(found.WorldPosition)))
			else
				log("ok", ("%s: %s (Attachment from .fbx) at %s"):format(label, name, fmtV(found.WorldPosition)))
			end
			return found
		elseif found:IsA("BasePart") then
			makeInvisible(found)
			log("ok", ("%s: %s is a BasePart, used as anchor (made invisible) at %s"):format(label, name, fmtV(found.Position)))
			return found
		else
			local host = hostPart(model)
			if not host then
				log("err", ("%s: %s exists as %s and the model has no BasePart to host an Attachment"):format(label, name, found.ClassName))
				return nil
			end
			local pos = if found:IsA("PVInstance") then (found :: any):GetPivot().Position else fallback()
			found.Name = name .. "_Src"
			local a = newAttachment(host, name, pos)
			log("conv", ("%s: %s came as %s -> Attachment created at its pivot %s (original renamed %s_Src)"):format(label, name, found.ClassName, fmtV(pos), name))
			return a
		end
	end
	local host = hostPart(model)
	if not host then
		log("err", ("%s: %s missing and the model has no BasePart to host it"):format(label, name))
		return nil
	end
	local a = newAttachment(host, name, fallback())
	log("new", ("%s: %s not in the .fbx -> created at %s (fallback, verify in Studio)"):format(label, name, fmtV(a.WorldPosition)))
	return a
end

local function interactable(anchor: Instance?, action: string, attrs: { [string]: any }?)
	if not anchor then
		return
	end
	CollectionService:AddTag(anchor, "Interactable")
	anchor:SetAttribute("PromptAction", action)
	if attrs then
		for k, v in attrs do
			anchor:SetAttribute(k, v)
		end
	end
end

-- Floor height under (x, z) by raycast; returns expected when the hit is missing or too far from it.
local function floorY(x: number, z: number, expected: number, exclude: { Instance }): (number, string?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex = table.clone(exclude)
	for _ = 1, 16 do
		params.FilterDescendantsInstances = ex
		local hit = Workspace:Raycast(Vector3.new(x, expected + 3, z), Vector3.new(0, -6, 0), params)
		if not hit then
			return expected, "no floor hit, used expected Y"
		end
		local p = hit.Instance
		if p:IsA("BasePart") and p.CanCollide then
			if math.abs(hit.Position.Y - expected) <= 0.6 then
				return hit.Position.Y, nil
			end
			return expected, ("hit %s at Y %.2f (expected %.2f), used expected Y"):format(p:GetFullName(), hit.Position.Y, expected)
		end
		table.insert(ex, p)
	end
	return expected, "too many non-colliding hits, used expected Y"
end

---------------------------------------------------------------------------------------------------
-- Steps
---------------------------------------------------------------------------------------------------

local function cleanSlate(root: Instance)
	local n = 0
	for _, d in root:GetDescendants() do
		for _, t in OWN_TAGS do
			if CollectionService:HasTag(d, t) then
				CollectionService:RemoveTag(d, t)
				n += 1
			end
		end
		for _, a in AUTHORED_ATTRS do
			if d:GetAttribute(a) ~= nil then
				d:SetAttribute(a, nil)
			end
		end
	end
	log("ok", ("clean slate: %d old tag(s) removed under %s"):format(n, root.Name))
end

-- Grill: pick 4 of the slot empties (Att_SlotN / SlotN), or create fallbacks.
local function bindGrill(model: Instance, opts: AnchorOpts)
	local src, created = {}, {}
	for _, d in model:GetDescendants() do
		local n = d:GetAttribute(SRC_NAME) or d.Name
		if typeof(n) == "string" and (string.match(n, "^Att_Slot%d+$") or string.match(n, "^Slot%d+$")) then
			if d:GetAttribute(CREATED) then
				table.insert(created, d)
			elseif d:IsA("Attachment") or d:IsA("BasePart") then
				table.insert(src, d)
			end
		end
	end
	if #src >= GRILL_SLOTS then
		for _, c in created do
			c:Destroy()
		end
		local minP, maxP = Vector3.one * math.huge, -Vector3.one * math.huge
		for _, d in src do
			local p = anchorPos(d)
			minP, maxP = minP:Min(p), maxP:Max(p)
		end
		local alongX = (maxP.X - minP.X) >= (maxP.Z - minP.Z)
		table.sort(src, function(a, b)
			local pa, pb = anchorPos(a), anchorPos(b)
			if alongX then
				if math.abs(pa.X - pb.X) > 1e-3 then
					return pa.X < pb.X
				end
				return pa.Z < pb.Z
			end
			if math.abs(pa.Z - pb.Z) > 1e-3 then
				return pa.Z < pb.Z
			end
			return pa.X < pb.X
		end)
		local first = math.floor((#src - GRILL_SLOTS) / 2) + 1
		local spare = 0
		for i, d in src do
			if d:GetAttribute(SRC_NAME) == nil then
				d:SetAttribute(SRC_NAME, d.Name)
			end
			if d:IsA("BasePart") then
				makeInvisible(d)
			end
			local slot = i - first + 1
			if slot >= 1 and slot <= GRILL_SLOTS then
				d.Name = "Att_Slot" .. slot
				interactable(d, "grill_collect", { Slot = slot })
				log("ok", ("CART-G: %s (.fbx %s) -> Slot %d at %s"):format(d.Name, tostring(d:GetAttribute(SRC_NAME)), slot, fmtV(anchorPos(d))))
			else
				spare += 1
				d.Name = "Att_SlotSpare" .. spare
			end
		end
		if not alongX then
			log("warn", "CART-G: slot empties spread along Z, not X; ordered north -> south. Check the slot order")
		end
		log("ok", ("CART-G: %d slot empties found, central %d used (DEC-201), %d spare left untagged"):format(#src, GRILL_SLOTS, spare))
		return
	end
	if #src > 0 then
		log("warn", ("CART-G: only %d slot empties found (need %d); using fallback slots"):format(#src, GRILL_SLOTS))
	end
	local host = hostPart(model)
	if not host then
		log("err", "CART-G: no BasePart to host slot Attachments")
		return
	end
	local mn, mx = partsBox(model)
	local centre = if mn and mx then (mn + mx) / 2 else Vector3.new(33.5, 0, 37.5)
	local top = if mx then mx.Y else COUNTER_Y
	for slot = 1, GRILL_SLOTS do
		local name = "Att_Slot" .. slot
		local existing: Instance? = nil
		for _, c in created do
			if c.Name == name then
				existing = c
			end
		end
		local pos = Vector3.new(centre.X + GRILL_FALLBACK_DX[slot], top + 0.2, centre.Z)
		local a: Instance
		if existing then
			a = existing
			if opts.resetCreated and a:IsA("Attachment") then
				a.WorldCFrame = CFrame.new(pos)
			end
		else
			a = newAttachment(host, name, pos)
		end
		interactable(a, "grill_collect", { Slot = slot })
		log("new", ("CART-G: %s fallback -> Slot %d at %s (verify on the rollers)"):format(name, slot, fmtV(anchorPos(a))))
	end
end

-- Rail: Slot1..6 (or Att_Slot1..6) get Slot = n; missing numbers are created along the rail.
local function bindRail(model: Instance, opts: AnchorOpts)
	local byNum: { [number]: { Instance } } = {}
	for _, d in model:GetDescendants() do
		local n = string.match(d.Name, "^Slot(%d+)$") or string.match(d.Name, "^Att_Slot(%d+)$")
		if n and (d:IsA("Attachment") or d:IsA("BasePart")) then
			local k = tonumber(n) :: number
			byNum[k] = byNum[k] or {}
			table.insert(byNum[k], d)
		end
	end
	local mn, mx = partsBox(model)
	local centre = if mn and mx then (mn + mx) / 2 else Vector3.new(37.5, COUNTER_Y, 37.5)
	local top = if mx then mx.Y else COUNTER_Y + 0.5
	local host = hostPart(model)
	for slot = 1, RAIL_SLOTS do
		local list = byNum[slot]
		local a: Instance? = nil
		if list and #list > 0 then
			a = list[1]
			if #list > 1 then
				log("warn", ("CART-R: %d instances named Slot%d (Rail_6 and Rail_8 empties?); used %s"):format(#list, slot, list[1]:GetFullName()))
			end
			if a and a:IsA("BasePart") then
				makeInvisible(a)
			end
			if a and a:GetAttribute(CREATED) and opts.resetCreated and a:IsA("Attachment") then
				a.WorldCFrame = CFrame.new(centre.X - 1 + 0.4 * (slot - 1), top, centre.Z)
			end
		elseif host then
			a = newAttachment(host, "Slot" .. slot, Vector3.new(centre.X - 1 + 0.4 * (slot - 1), top, centre.Z))
		end
		if a then
			a:SetAttribute("Slot", slot)
			log(if a:GetAttribute(CREATED) then "new" else "ok", ("CART-R: %s -> Slot %d at %s"):format(a.Name, slot, fmtV(anchorPos(a))))
		else
			log("err", ("CART-R: cannot create Slot%d (no BasePart)"):format(slot))
		end
	end
	local rp = findNamed(model, "Prompt_Rail")
	if rp then
		log("ok", "CART-R: Prompt_Rail left WITHOUT tag (Add Sausage is on the board, §18.4)")
	end
end

-- Board: Att_Bun -> Att_Bun1 / Att_Bun2 (Slot 1 = the one more to the west, DEC-190).
local function bindBoard(model: Instance, opts: AnchorOpts)
	local mn, mx = partsBox(model)
	local centre = if mn and mx then (mn + mx) / 2 else Vector3.new(42.5, COUNTER_Y, 37.5)
	local top = if mx then mx.Y else COUNTER_Y + 0.2
	local base = ensureAnchor(model, "Att_Bun", function()
		return Vector3.new(centre.X, top + 0.05, centre.Z)
	end, opts, "CART-T")
	if not base then
		return
	end
	local baseCF = if base:IsA("Attachment") then base.WorldCFrame else (base :: BasePart).CFrame
	local host = if base:IsA("Attachment") then base.Parent :: BasePart else hostPart(model)
	local pA = (baseCF * CFrame.new(-BUN_SLOT_HALF, 0, 0)).Position
	local pB = (baseCF * CFrame.new(BUN_SLOT_HALF, 0, 0)).Position
	if pB.X < pA.X then
		pA, pB = pB, pA
	end
	for slot, pos in { pA, pB } do
		local name = "Att_Bun" .. slot
		local a = findNamed(model, name)
		if a and a:IsA("Attachment") then
			if a:GetAttribute(CREATED) and opts.resetCreated then
				a.WorldCFrame = CFrame.new(pos) * baseCF.Rotation
			end
		elseif host then
			a = newAttachment(host :: BasePart, name, pos)
			;(a :: Attachment).WorldCFrame = CFrame.new(pos) * baseCF.Rotation
		end
		if a then
			a:SetAttribute("Slot", slot)
			log(if a:GetAttribute(CREATED) then "new" else "ok", ("CART-T: %s -> Slot %d at %s (shared slot, DEC-190)"):format(name, slot, fmtV(anchorPos(a))))
		end
	end
end

--[[ Toppings grid (AST-017, bowls of DEC-156). Anchors sit on the REAL bowl of each ingredient (MeshPart
	Bin_<Suf>), parented to it, and are always re-derived from it on every run.
	The two real rows are 1.5 apart in Z (operator row low, back row 0.3 higher), under the 2.0 of §18.7 item 4.
	Fix without changing any game rule: the anchors of each row are pushed OUT of the grid so the billboards are
	>= 2.0 apart: operator row -> towards the corridor (+Z) and slightly up; back row -> straight up. With the
	measured bowls (Z 38.1 / 36.6, Y 3.9 / 4.2) this gives Z 38.5 / 36.6 and Y 4.25 / 5.45 -> 2.25 studs.
	Use and Restock of the same bowl share the position (one action visible at a time: "Add" needs a Hot Dog in
	hand, "Restock" needs the package; §18.7 item 4 already exempts the same ingredient). ]]
local TOPPING_OPERATOR_OFFSET = Vector3.new(0, 0.35, 0.4)
local TOPPING_BACK_OFFSET = Vector3.new(0, 1.25, 0)
local TOPPING_MIN_GAP = 2.05 -- back row is raised further if the measured rows still end up closer than this

local function bindToppings(model: Instance, opts: AnchorOpts)
	local bins: { [string]: BasePart } = {}
	local zs: { number } = {}
	for _, t in TOPPINGS do
		local b = findNamed(model, "Bin_" .. t.suf)
		if b and b:IsA("BasePart") then
			bins[t.key] = b
			table.insert(zs, b.Position.Z)
		else
			log("err", ("CART-K: bowl Bin_%s not found (MeshPart of AST-017): anchor falls back to MAP-01 §7.1"):format(t.suf))
		end
	end
	-- operator row = the bowls nearest the corridor (largest Z, operator faces north)
	local maxZ, minZ = -math.huge, math.huge
	for _, z in zs do
		maxZ, minZ = math.max(maxZ, z), math.min(minZ, z)
	end
	local splitZ = (maxZ + minZ) / 2

	local wanted: { [string]: Vector3 } = {}
	for _, t in TOPPINGS do
		local b = bins[t.key]
		if b then
			local isOperator = b.Position.Z >= splitZ
			wanted[t.key] = b.Position + (if isOperator then TOPPING_OPERATOR_OFFSET else TOPPING_BACK_OFFSET)
		else
			wanted[t.key] = Vector3.new(t.x, topY(model) + 0.3, t.z)
		end
	end
	-- safety: raise the back row until every pair of different bowls is >= TOPPING_MIN_GAP apart
	for _ = 1, 20 do
		local worst = math.huge
		for _, a in TOPPINGS do
			for _, c in TOPPINGS do
				local ba, bc = bins[a.key], bins[c.key]
				-- only pairs across the two rows (same-row spacing is the model's, 2.0 between bowls)
				if ba and bc and (ba.Position.Z >= splitZ) ~= (bc.Position.Z >= splitZ) then
					worst = math.min(worst, (wanted[a.key] - wanted[c.key]).Magnitude)
				end
			end
		end
		if worst >= TOPPING_MIN_GAP then
			break
		end
		for _, t in TOPPINGS do
			local b = bins[t.key]
			if b and b.Position.Z < splitZ then
				wanted[t.key] += Vector3.new(0, 0.1, 0)
			end
		end
	end

	for _, t in TOPPINGS do
		local p = wanted[t.key]
		local host: BasePart? = bins[t.key] or hostPart(model)
		for _, spec in { { "Prompt_Use_" .. t.suf, "topping_add" }, { "Prompt_Restock_" .. t.suf, "restock" } } do
			local a = findNamed(model, spec[1])
			if a and a:IsA("Attachment") and not a:GetAttribute(CREATED) then
				log("ok", ("CART-K: %s (Attachment from .fbx) kept at %s"):format(spec[1], fmtV(a.WorldPosition)))
			else
				if a and not a:IsA("Attachment") then
					a.Name = spec[1] .. "_Src"
					a = nil
				end
				if not a and host then
					a = newAttachment(host, spec[1], p)
				end
				if a and host then
					a.Parent = host
					;(a :: Attachment).WorldCFrame = CFrame.new(p)
				end
				log("new", ("CART-K: %s on %s at %s"):format(spec[1], if bins[t.key] then "Bin_" .. t.suf else "MAP-01 cell", fmtV(p)))
			end
			interactable(a, spec[2], { Ingredient = t.key })
		end
	end
	-- layout note: MAP-01 §7.1 puts Ketchup/Mustard/Cheese (W -> E) on the queue side; the real grid differs
	local k, c = bins.ketchup, bins.cheese
	if k and c and (k.Position.X > c.Position.X or k.Position.Z >= splitZ) then
		log("warn", ("CART-K: real grid = Ketchup X %.1f Z %.1f, Cheese X %.1f; MAP-01 §7.1 says Ketchup/Mustard/Cheese W->E on the queue side. Doc to update (level-designer)"):format(k.Position.X, k.Position.Z, c.Position.X))
	end
end

local function bindStation(cart: Instance, mapId: string, kind: string, ingredient: string?): Instance?
	local m = byMapId(cart, mapId)
	if not m then
		log("err", ("%s not found inside the CART model (run place_assets with the day layer)"):format(mapId))
		return nil
	end
	CollectionService:AddTag(m, "Station")
	m:SetAttribute("StationKind", kind)
	if ingredient then
		m:SetAttribute("Ingredient", ingredient)
	end
	setPersistent(m)
	log("ok", ("%s: Station %s%s"):format(mapId, kind, if ingredient then " / " .. ingredient else ""))
	return m
end

local function bindCart(assets: Instance, opts: AnchorOpts): Instance?
	local cart = byMapId(assets, "CART", "AST-026_CornerCart")
	if not cart then
		log("err", "CART (AST-026_CornerCart) not found in MAP01_Assets. Run Place.run / Place.showLayer('day') first")
		return nil
	end
	CollectionService:AddTag(cart, "Vehicle")
	cart:SetAttribute("Vehicle", "cart")
	setPersistent(cart)
	log("ok", ("CART: Vehicle 'cart' (%s)"):format(cart:GetFullName()))

	-- re-parent every cart piece into the vehicle (T36: one PivotTo moves the set)
	local moved = 0
	for _, d in assets:GetDescendants() do
		local id = d:GetAttribute("MapId")
		if d ~= cart and typeof(id) == "string" and not d:IsDescendantOf(cart) then
			if string.sub(id, 1, 5) == "CART-" or id == "DRAWER" or id == "BIN-C" then
				d.Parent = cart
				moved += 1
			end
		end
	end
	log("ok", ("CART: %d model(s) moved inside the vehicle (CART-*, DRAWER, BIN-C)"):format(moved))

	-- S: sausage stock (cooler, low in the cart body)
	local s = bindStation(cart, "CART-S", "sausage_stock", "sausage")
	if s then
		local y = math.max(topY(s), COUNTER_Y) + 0.3
		interactable(ensureAnchor(s, "Prompt_Take", function()
			return Vector3.new(28.9, y, 38.4)
		end, opts, "CART-S"), "grill_place")
		interactable(ensureAnchor(s, "Prompt_Restock", function()
			return Vector3.new(29.6, y, 37.0)
		end, opts, "CART-S"), "restock")
	end
	-- G: grill
	local g = bindStation(cart, "CART-G", "grill")
	if g then
		bindGrill(g, opts)
		local pg = findNamed(g, "Prompt_Grill")
		if pg then
			log("ok", "CART-G: Prompt_Grill left WITHOUT tag (placing is on the cooler, Prompt_Take -> grill_place)")
		end
	end
	-- R: rest rail
	local r = bindStation(cart, "CART-R", "rail")
	if r then
		bindRail(r, opts)
	end
	-- B: bun crate (the .fbx has no empties)
	local b = bindStation(cart, "CART-B", "bun_crate", "bun")
	if b then
		local y = topY(b) + 0.3
		interactable(ensureAnchor(b, "Prompt_Take", function()
			return Vector3.new(39.7, y, 38.4)
		end, opts, "CART-B"), "bun_cut")
		interactable(ensureAnchor(b, "Prompt_Restock", function()
			return Vector3.new(39.7, y, 36.9)
		end, opts, "CART-B"), "restock")
	end
	-- T: cutting board, one prompt + 2 shared slots
	local t = bindStation(cart, "CART-T", "board")
	if t then
		local y = topY(t) + 0.3
		interactable(ensureAnchor(t, "Prompt_Board", function()
			return Vector3.new(42.3, y, 38.4)
		end, opts, "CART-T"), "board_add_sausage")
		bindBoard(t, opts)
	end
	-- K: toppings grid
	local k = bindStation(cart, "CART-K", "toppings")
	if k then
		bindToppings(k, opts)
	end
	-- BIN-C: trash
	local bin = bindStation(cart, "BIN-C", "trash")
	if bin then
		local y = topY(bin) + 0.3
		interactable(ensureAnchor(bin, "Prompt_Discard", function()
			return Vector3.new(56, y, 42)
		end, opts, "BIN-C"), "discard")
	end
	-- DRAWER: not a Station; Value_Anchor on top of the POS (drawer half, X >= 52.2)
	local drawer = byMapId(cart, "DRAWER")
	if drawer then
		setPersistent(drawer)
		ensureAnchor(drawer, "Value_Anchor", function()
			local mn, mx = partsBox(drawer, function(p)
				return p.Position.X >= 52.2
			end)
			if not (mn and mx) then
				mn, mx = partsBox(drawer)
			end
			if mn and mx then
				local c = (mn + mx) / 2
				return Vector3.new(c.X, mx.Y + 0.4, c.Z)
			end
			return Vector3.new(53.2, COUNTER_Y + 1.6, 37)
		end, opts, "DRAWER")
		for _, n in { "Prompt_Serve", "Prompt_Drawer", "Prompt_TakeOrder", "Prompt_Refuse" } do
			if findNamed(drawer, n) then
				log("ok", ("DRAWER: %s left WITHOUT tag (Serve is on the customer, DEC-190)"):format(n))
			end
		end
		for _, n in { "Bar_Thief", "VFX_Coins" } do
			if not findNamed(drawer, n) then
				log("warn", ("DRAWER: fitting %s missing (read by TASK-024 / thief, wave 2)"):format(n))
			end
		end
	else
		log("err", "DRAWER (AST-020) not found inside the CART model")
	end
	-- Zone_Center (thief radius 14, DEC-050): from the .fbx or created at the cart centre (41, 40)
	ensureAnchor(cart, "Zone_Center", function()
		return Vector3.new(41, 0.55, 40)
	end, opts, "CART")
	return cart
end

local function bindOpenSign(assets: Instance, opts: AnchorOpts)
	local m = byMapId(assets, "OPEN", "AST-024_SignStand")
	if not m then
		log("err", "OPEN sign (AST-024_SignStand, MapId OPEN) not found")
		return
	end
	setPersistent(m)
	local a = ensureAnchor(m, "Prompt_Open", function()
		local mn, mx = partsBox(m)
		if mn and mx then
			return (mn + mx) / 2
		end
		return Vector3.new(25, 2, 35)
	end, opts, "OPEN")
	interactable(a, "open_sign")
	-- the sale-trailer sign uses the same asset: its Prompt_Open must stay untagged (clean slate does it)
end

local function bindMart(assets: Instance, opts: AnchorOpts)
	-- Shelves: invisible anchor Parts in a Model MKT-SHELVES (gondolas/fridges have no empties)
	local parent = assets:FindFirstChild("MartInterior") or assets
	local shelves = assets:FindFirstChild("MKT-SHELVES", true)
	if not (shelves and shelves:IsA("Model")) then
		shelves = Instance.new("Model")
		shelves.Name = "MKT-SHELVES"
		shelves:SetAttribute(CREATED, true)
		shelves.Parent = parent
	end
	setPersistent(shelves :: Instance)
	for _, sh in SHELVES do
		local name = "BUY-" .. sh.name
		local p = (shelves :: Instance):FindFirstChild(name)
		local pos = Vector3.new(sh.x, MART_FLOOR + SHELF_ANCHOR_H, sh.z)
		if not (p and p:IsA("BasePart")) then
			local part = Instance.new("Part")
			part.Name = name
			part.Size = Vector3.one
			part.CFrame = CFrame.new(pos)
			part:SetAttribute(CREATED, true)
			part.Parent = shelves
			p = part
		elseif opts.resetCreated then
			(p :: BasePart).CFrame = CFrame.new(pos)
		end
		makeInvisible(p :: BasePart)
		interactable(p, "buy_package", { Package = sh.package })
		log("ok", ("MKT-SHELVES: %s -> buy_package %s at %s"):format(name, sh.package, fmtV((p :: BasePart).Position)))
	end

	-- GEAR WALL (AST-049): Prompt_Buy_<slot>
	local gw = byMapId(assets, "GEAR_WALL", "AST-049_GearWall")
	if not gw then
		log("err", "GEAR_WALL (AST-049_GearWall) not found")
		return
	end
	setPersistent(gw)
	for _, b in BENCH do
		local a = ensureAnchor(gw, "Prompt_Buy_" .. b.slot, function()
			return Vector3.new(-97.8, MART_FLOOR + 3.5 + 1.0, b.z)
		end, opts, "GEAR_WALL")
		interactable(a, b.action, { BenchSlot = b.slot })
		for _, n in { "Price_Anchor_" .. b.slot, "PriceTag_" .. b.slot, "Slot_" .. b.slot } do
			if not findNamed(gw, n) then
				log("warn", ("GEAR_WALL: fitting %s missing (read by MarketController, TASK-037)"):format(n))
			end
		end
	end
end

local function bindPoints(): Instance
	local root = Workspace:FindFirstChild(BINDING_ROOT)
	if not (root and root:IsA("Model")) then
		if root then
			log("warn", ("workspace.%s was a %s; replaced by a Model"):format(BINDING_ROOT, root.ClassName))
			root:Destroy()
		end
		root = Instance.new("Model")
		root.Name = BINDING_ROOT
		root.Parent = Workspace
	end
	CollectionService:AddTag(root, "MapBinding")
	setPersistent(root)
	for _, child in (root :: Instance):GetChildren() do
		child:Destroy()
	end
	local pts = Instance.new("Folder")
	pts.Name = "Points"
	pts.Parent = root
	local nodes = Instance.new("Folder")
	nodes.Name = "Nodes"
	nodes.Parent = root

	local exclude: { Instance } = { root :: Instance }
	local blockout = Workspace:FindFirstChild("MAP01_Blockout")
	if blockout and blockout:FindFirstChild("Markers") then
		table.insert(exclude, blockout.Markers)
	end
	-- review / demo scenes are not part of the map
	for _, c in Workspace:GetChildren() do
		if c.Name == "CrewDemo" or c.Name == "AssetReview" or string.sub(c.Name, 1, 10) == "__Preview_" then
			table.insert(exclude, c)
		end
	end

	local links: { [string]: { string } } = {}
	for _, e in EDGES do
		links[e[1]] = links[e[1]] or {}
		links[e[2]] = links[e[2]] or {}
		table.insert(links[e[1]], e[2])
		table.insert(links[e[2]], e[1])
	end

	local function place(name: string, x: number, z: number, floor: number, face: Vector3?, parent: Instance): Part
		local y, why = floorY(x, z, floor, exclude)
		if why then
			log("warn", ("%s: %s"):format(name, why))
		end
		local pos = Vector3.new(x, y, z)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = Vector3.one
		p.CFrame = if face then CFrame.lookAt(pos, pos + face) else CFrame.new(pos)
		makeInvisible(p)
		p.Parent = parent
		return p
	end

	for _, pt in POINTS do
		local p = place(pt.id, pt.x, pt.z, pt.floor, pt.face, pts)
		CollectionService:AddTag(p, "MapPoint")
		p:SetAttribute("PointId", pt.id)
		if pt.node then
			CollectionService:AddTag(p, "NpcNode")
			p:SetAttribute("Links", table.concat(links[pt.id] or {}, ","))
		end
		log("ok", ("MapPoint %s at %s%s"):format(pt.id, fmtV(p.Position), if pt.node then " (+ NpcNode)" else ""))
	end
	for _, nd in NODES do
		local p = place(nd.id, nd.x, nd.z, nd.floor, nil, nodes)
		CollectionService:AddTag(p, "NpcNode")
		p:SetAttribute("NodeId", nd.id)
		p:SetAttribute("Links", table.concat(links[nd.id] or {}, ","))
		if nd.crosswalk then
			p:SetAttribute("Crosswalk", nd.crosswalk)
		end
	end
	local pointNodes = 0
	for _, pt in POINTS do
		if pt.node then
			pointNodes += 1
		end
	end
	log("ok", ("NpcNode graph: %d node-only parts + %d point nodes, %d edges"):format(#NODES, pointNodes, #EDGES))
	return root :: Instance
end

-- Persistent on every Model that is, or contains, a tagged instance (§18.0 item 6).
local function persistAll(): number
	local n = 0
	for _, tag in OWN_TAGS do
		for _, inst in CollectionService:GetTagged(tag) do
			if inst:IsDescendantOf(Workspace) then
				local node: Instance? = inst
				while node and node ~= Workspace do
					if node:IsA("Model") and node.ModelStreamingMode ~= Enum.ModelStreamingMode.Persistent then
						node.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
						n += 1
					end
					node = node.Parent
				end
			end
		end
	end
	return n
end

---------------------------------------------------------------------------------------------------
-- Entry point
---------------------------------------------------------------------------------------------------

function Bind.run(opts: AnchorOpts?): string
	local o: AnchorOpts = opts or {}
	table.clear(report)
	for k in counts do
		counts[k] = 0
	end

	local assets = Workspace:FindFirstChild(ASSETS_ROOT)
	if not assets then
		return "[err] workspace." .. ASSETS_ROOT .. " not found: run place_assets.luau Place.run first"
	end
	if not assets:FindFirstChild("Cart") and not byMapId(assets, "CART") then
		return "[err] the cart set is not in the Workspace (night layer active?). Run Place.showLayer('day') first"
	end

	cleanSlate(assets)
	bindCart(assets, o)
	bindOpenSign(assets, o)
	bindMart(assets, o)
	bindPoints()
	local p = persistAll()
	log("ok", ("ModelStreamingMode = Persistent set on %d more model(s)"):format(p))

	local tagCounts = {}
	for _, tag in OWN_TAGS do
		local c = 0
		for _, inst in CollectionService:GetTagged(tag) do
			if inst:IsDescendantOf(Workspace) then
				c += 1
			end
		end
		table.insert(tagCounts, ("%s=%d"):format(tag, c))
	end

	local head = ("bind_map01: ok %d | new %d | conv %d | warn %d | err %d\ntags in Workspace: %s\n"):format(
		counts.ok,
		counts.new,
		counts.conv,
		counts.warn,
		counts.err,
		table.concat(tagCounts, ", ")
	)
	local body = table.concat(report, "\n")
	return head .. body .. "\nNext: run check_map01.luau (Check.run())."
end

return Bind
