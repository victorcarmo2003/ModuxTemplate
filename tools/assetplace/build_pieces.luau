--!strict
--[[
	Upgrade pieces kit builder (TASK-084, bug B-02; architecture.md §18.4 "Peças de upgrade" T38, §18.9).
	EDIT MODE ONLY: Command Bar or Studio MCP. InsertService is allowed here because this is a tool (§18.9 rule 1).

	Builds, outside Rojo (§18.9 rule 5), ONLY ReplicatedStorage.Assets.Equipment.UpgradePieces
	(Assets.Crew, Assets.Items, Equipment.Padlock and the root KitVersion are left alone):
	  UpgradePieces                   Folder, attribute KitVersion = PIECES_VERSION
	    <vehicle>/<Part>              Model per Content.Upgrades row with Part ~= "" (Part = row.Part, e.g. Grill_L2)
	      cart     Grill_L1..L3, Cooler_L1..L3, Counter_L1..L3, DrawerLock_L1
	      trailer  the same + TrailerLights_L1 (DEC-184: the trailer piece is another instance)

	Piece conventions (consumed by TASK-085, which clones them into the vehicles; UpgradeService/Pieces.luau):
	  - attributes Upgrade (Content.Upgrades key), Level (int), ForVehicle, Asset, Tris (sum of the .fbx counts),
	    AxisFlip (convention detected on the upload, see below);
	  - NOT tagged UpgradePiece here: check_map01 rule 5 forbids tags outside the Workspace. TASK-085 tags the clone;
	    "ForVehicle" (not "Vehicle") so bind_map01's clean slate and the Vehicle tag attribute never collide;
	  - pivot (PrimaryPart.PivotOffset) = the asset origin, base centre, front = local -Z, exactly the frame that
	    place_assets.luau uses: TASK-085 puts the piece with the same CFrame as the station of MAP-01_placements;
	  - parts anchored, CanCollide/CanTouch/CanQuery false (cosmetic; the vehicle body collides), attribute Asset;
	  - T38: no Interactable and no slot/prompt Attachment inside a piece. Anchors that depend on the level
	    (Slot<n>, Prompt_*) travel as Vector3 attributes Anchor_<name> in piece space: TASK-085 creates the real
	    Attachments on the station root (with Level when the position changes). Visual fittings that are not
	    anchors (VFX_*, Light_*) are real Attachments inside the piece;
	  - Fill / Lid keep the station names (Stock.luau reads them by name: see the note in the board, TASK-084).

	Geometry facts (part boxes, empties, tris) were measured on 2026-10-10 by importing the uploaded .fbx files
	(Assets/import/equipment; AST-012 = the NEW Assets/models/equipment/AST-012_RollerGrill.fbx) into Blender and
	converting with the convention of build_items.luau ("M" below). Empties do not survive the FBX import, so
	attachments and anchors are rebuilt here from those points. Imported MeshParts sit at their bounding-box centre:
	the asset origin is recovered from a root part. MAP-01_placements.luau ("ORIENTATION FIX") measured in Studio
	that the modelled assets arrive turned 180 degrees about Y relative to M; each asset with an asymmetric part pair
	(probe) detects it on the real upload (AxisFlip), the others use DEFAULT_FLIP.

	AST-012 (new roller grill, Grill_L1..L3, DEC-201) is NOT uploaded yet: the id in _asset_ids.json is the old
	6-slot model. The build reports it and check() fails until the new .fbx is uploaded and the id updated.

	Usage (repo served at http://127.0.0.1:8772/, e.g. `python -m http.server 8772` at the repo root):
		local Http = game:GetService("HttpService")
		local was = Http.HttpEnabled
		Http.HttpEnabled = true
		local ms = Instance.new("ModuleScript")
		ms.Source = Http:GetAsync("http://127.0.0.1:8772/tools/assetplace/build_pieces.luau")
		Http.HttpEnabled = was
		local Pieces = require(ms)
		print(Pieces.run({ baseUrl = "http://127.0.0.1:8772/" }))              -- build + check
		print(Pieces.run({ baseUrl = "http://127.0.0.1:8772/", demo = true })) -- + workspace.PiecesDemo
		print(table.concat(Pieces.check(), "\n"))                              -- check only (after a build)
		Pieces.clearDemo()
	Without the server: Pieces.run({ ids = <_asset_ids table>, content = <Content table> }).
	Content is taken from opts.content, else ReplicatedStorage.shared.Content (rojo serve), else the server.
	Save the place afterwards (Ctrl+S): the place is not in git, this script is the recipe.
]]

local HttpService = game:GetService("HttpService")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

type Ids = { [string]: any }
type Box = { min: Vector3, max: Vector3 }
type PartSpec = { box: Box, tris: number }
type AssetSpec = {
	parts: { [string]: PartSpec },
	root: string, -- origin is recovered from this part
	probe: string?, -- asymmetric part used to detect the axis convention
}
type Use = {
	asset: string,
	parts: { string },
	at: CFrame?, -- where the asset origin goes, in piece space (default: the piece origin)
	scale: Vector3?, -- per-axis scale about the asset origin (MeshPart.Size is scaled)
	sub: string?, -- sub-Model name inside the piece (pieces with parts in two places)
}
type Fitting = { name: string, use: number?, pos: Vector3, light: string? } -- pos in M, asset space of the use
type PieceSpec = {
	part: string, -- Content.Upgrades Level.Part
	upgrade: string,
	level: number,
	vehicle: string,
	budget: number,
	uses: { Use },
	atts: { Fitting }?,
	anchors: { Fitting }?,
}
type Loaded = { byName: { [string]: BasePart }, origin: CFrame, flip: boolean }
export type Options = {
	baseUrl: string?,
	ids: Ids?,
	content: any?,
	reload: boolean?, -- drop cached assets and load them again
	demo: boolean?, -- also build workspace.PiecesDemo for a visual check
}

local Kit = {}

const PIECES_VERSION = 1
const CACHE_NAME = "__AssetCache" -- shared with place_assets.luau / build_kits.luau / build_items.luau
const DEMO_NAME = "PiecesDemo"
const KIT_NAME = "UpgradePieces"
const SIZE_TOL = 0.05
const PROBE_TOL = 0.05
-- MAP-01_placements.luau ORIENTATION FIX: modelled assets face local -Z in Studio (M has them at +Z).
-- Provisional: only used by assets without a probe pair (single symmetric meshes).
const DEFAULT_FLIP = true
-- T38: names that are anchors (stay outside the piece) and tags that must never be inside a kit piece
const ANCHOR_PATTERNS = { "^Slot%d+$", "^Att_Slot%d+$", "^Prompt_" }
const FORBIDDEN_TAGS = { "UpgradePiece", "Interactable", "Station", "Vehicle", "MapPoint" }

local function box(x0: number, y0: number, z0: number, x1: number, y1: number, z1: number): Box
	return { min = Vector3.new(x0, y0, z0), max = Vector3.new(x1, y1, z1) }
end

local function centre(b: Box): Vector3
	return (b.min + b.max) / 2
end

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

-- Assets (M = measured on the uploaded .fbx, base centre origin, 1 unit = 1 stud) ---------------------------------

const ASSETS: { [string]: AssetSpec } = {
	-- AST-012 new roller grill (modeler-3d 2026-10-10, In review): 3 overlapping variants on one origin
	["AST-012_RollerGrill"] = {
		parts = {
			Grill_L1 = { box = box(-0.457, 0, -1.15, 2.257, 0.78, 1.21), tris = 688 },
			Grill_L2 = { box = box(-1.357, 0, -1.15, 2.257, 0.78, 1.21), tris = 824 },
			Grill_L3 = { box = box(-2.257, 0, -1.15, 2.257, 0.78, 1.21), tris = 960 },
		},
		root = "Grill_L3",
		probe = "Grill_L1",
	},
	-- AST-018 L1 / L2 (DEC-141), L3 = KP fridge_A (pack edit, one mesh)
	["AST-018_CoolerL1"] = {
		parts = {
			Body = { box = box(-1.5, 0, -1.155, 1.5, 1.42, 1.245), tris = 340 },
			Lid = { box = box(-1.3, 1.329, -1.255, 1.3, 1.6, 1.155), tris = 126 },
			Fill = { box = box(-1.09, 0.55, -0.945, 1.09, 1.154, 0.945), tris = 202 },
		},
		root = "Body",
		probe = "Lid",
	},
	["AST-018_CoolerL2"] = {
		parts = {
			Body = { box = box(-1.5, 0, -1.33, 1.5, 2.02, 1.395), tris = 570 },
			Lid_L = { box = box(0.01, 1.929, -1.405, 1.39, 2.2, 1.305), tris = 126 },
			Lid_R = { box = box(-1.39, 1.929, -1.405, -0.01, 2.2, 1.305), tris = 126 },
			Fill = { box = box(-1.19, 0.75, -1.095, 1.19, 1.734, 1.095), tris = 284 },
		},
		root = "Body",
		probe = "Lid_L",
	},
	["AST-018_CoolerL3"] = {
		parts = { ["AST-018_CoolerL3"] = { box = box(-1.5, 0, -1.5, 1.5, 3, 1.5), tris = 614 } },
		root = "AST-018_CoolerL3",
	},
	-- AST-019 counter modules (KP kitchencounter_straight_A / outercorner, chair_stool with flat seat)
	["AST-019_CounterStraight"] = {
		parts = { ["AST-019_CounterStraight"] = { box = box(-1.5, 0, -1.5, 1.5, 3.5, 1.5), tris = 168 } },
		root = "AST-019_CounterStraight",
	},
	["AST-019_CounterCorner"] = {
		parts = { ["AST-019_CounterCorner"] = { box = box(-1.5, 0, -1.5, 1.5, 3.5, 1.5), tris = 38 } },
		root = "AST-019_CounterCorner",
	},
	["AST-019_Stool"] = {
		parts = { Stool = { box = box(-0.7, 0, -0.7, 0.7, 2.3, 0.7), tris = 270 } },
		root = "Stool",
	},
	-- AST-020 register: only Lock goes into the kit (DrawerLock_L1); Register / DeliveryStand give origin + probe
	["AST-020_CashRegister"] = {
		parts = {
			Register = { box = box(-1.96, 0, -0.7, -0.383, 1.351, 0.52), tris = 460 },
			DeliveryStand = { box = box(0, 0, -0.75, 2, 0.66, 0.75), tris = 168 },
			Lock = { box = box(-1.771, 0.038, 0.4, -1.529, 0.49, 0.839), tris = 200 },
		},
		root = "Register",
		probe = "DeliveryStand",
	},
	-- AST-023 trailer lights: mast and string share the origin in the .fbx (placed twice in MAP-01_placements)
	["AST-023_TrailerLights"] = {
		parts = {
			Lights_Mast = { box = box(-1.4, 0, -0.6, 1.4, 5.048, 0.6), tris = 320 },
			Lights_Mast_Lamps = { box = box(-1.29, 4.372, 0.084, 1.29, 4.739, 0.358), tris = 36 },
			Lights_String = { box = box(-11.51, -0.856, -0.11, 11.51, 0.11, 0.11), tris = 198 },
			Lights_String_Bulbs = { box = box(-9.804, -1.256, -0.182, 9.804, -0.339, 0.182), tris = 288 },
		},
		root = "Lights_Mast",
		probe = "Lights_Mast_Lamps",
	},
}

-- Pieces ----------------------------------------------------------------------------------------------------------

-- Budgets = asset-list fichas (tris per level).
const BUDGET = { grill = 1200, cooler = 1200, counter = 900, cash_drawer_lock = 200, trailer_lights = 1100 }

-- Grill (AST-012, DEC-201): slot n sits at the same place on every level; L1 = slots 1-2, L2 = 1-3, L3 = 1-4.
const GRILL_SLOT_X = { 1.35, 0.45, -0.45, -1.35 } -- M; 0.9 between centres
const GRILL_SLOT_Y = 0.52
const GRILL_STEAM_Y = 0.72
local function grill(level: number, vehicle: string): PieceSpec
	local atts: { Fitting } = {}
	local anchors: { Fitting } = { { name = "Prompt_Grill", pos = v(0.9, 0.5, 1.4) } }
	for n = 1, level + 1 do
		table.insert(atts, { name = "VFX_Steam" .. n, pos = v(GRILL_SLOT_X[n], GRILL_STEAM_Y, 0) })
		table.insert(anchors, { name = "Slot" .. n, pos = v(GRILL_SLOT_X[n], GRILL_SLOT_Y, 0) })
	end
	return {
		part = "Grill_L" .. level,
		upgrade = "grill",
		level = level,
		vehicle = vehicle,
		budget = BUDGET.grill,
		uses = { { asset = "AST-012_RollerGrill", parts = { "Grill_L" .. level } } },
		atts = atts,
		anchors = anchors,
	}
end

-- Cooler (AST-018). Prompt anchors move with the level (T38: station root + Level, TASK-085).
-- Provisional: L3 (KP fridge, no empties) prompts and VFX_Upgrade placed by the box (front = +Z in M).
local function cooler(level: number, vehicle: string): PieceSpec
	local spec: PieceSpec = {
		part = "Cooler_L" .. level,
		upgrade = "cooler",
		level = level,
		vehicle = vehicle,
		budget = BUDGET.cooler,
		uses = {},
	}
	if level == 1 then
		spec.uses = { { asset = "AST-018_CoolerL1", parts = { "Body", "Lid", "Fill" } } }
		spec.atts = { { name = "VFX_Upgrade", pos = v(0, 1.1, 0) } }
		spec.anchors = {
			{ name = "Prompt_Take", pos = v(0, 1.7, 1.355) },
			{ name = "Prompt_Restock", pos = v(-0.9, 1.0, 1.355) },
		}
	elseif level == 2 then
		spec.uses = { { asset = "AST-018_CoolerL2", parts = { "Body", "Lid_L", "Lid_R", "Fill" } } }
		spec.atts = { { name = "VFX_Upgrade", pos = v(0, 1.5, 0) } }
		spec.anchors = {
			{ name = "Prompt_Take", pos = v(0, 2.3, 1.505) },
			{ name = "Prompt_Restock", pos = v(-1.0, 1.2, 1.505) },
		}
	else
		spec.uses = { { asset = "AST-018_CoolerL3", parts = { "AST-018_CoolerL3" } } }
		spec.atts = { { name = "VFX_Upgrade", pos = v(0, 1.5, 0) } }
		spec.anchors = {
			{ name = "Prompt_Take", pos = v(0, 3.2, 1.6) },
			{ name = "Prompt_Restock", pos = v(-1.0, 1.5, 1.6) },
		}
	end
	return spec
end

-- Counter (AST-019; the trailer uses it until AST-078). Provisional composition (art-director to confirm):
--   L1 "balcão curto"         one straight module, 3 L
--   L2 "estendido + banquinhos" two modules, 6 L, + 2 stools on the queue side (-Z)
--   L3 "em L com toldo"       two modules + outer corner as the return of the L (towards the queue);
--                             the awning (toldo) is not modelled yet, no stools (budget 900: 2 stools = 540)
-- Modules are scaled to COUNTER_DEPTH and to the counter top of the vehicle: cart 3.0 (DEC-157), trailer 3.5.
-- Piece origin = base centre of the row of modules, front (queue) = -Z.
const COUNTER_TOP: { [string]: number } = { cart = 3.0, trailer = 3.5 }
const COUNTER_DEPTH = 1.0
const MODULE = 3 -- AST-019 module is 3 x 3.5 x 3
const STOOL_Z = -(COUNTER_DEPTH / 2 + 0.8)
local function counter(level: number, vehicle: string): PieceSpec
	const k = Vector3.new(1, COUNTER_TOP[vehicle] / 3.5, COUNTER_DEPTH / MODULE)
	local uses: { Use } = {}
	if level == 1 then
		table.insert(uses, { asset = "AST-019_CounterStraight", parts = { "AST-019_CounterStraight" }, scale = k })
	else
		for _, x in { -MODULE / 2, MODULE / 2 } do
			table.insert(uses, {
				asset = "AST-019_CounterStraight",
				parts = { "AST-019_CounterStraight" },
				at = CFrame.new(x, 0, 0),
				scale = k,
			})
		end
	end
	if level == 2 then
		for _, x in { -MODULE / 2, MODULE / 2 } do
			table.insert(uses, { asset = "AST-019_Stool", parts = { "Stool" }, at = CFrame.new(x, 0, STOOL_Z) })
		end
	elseif level == 3 then
		-- return of the L at the +X end: corner module COUNTER_DEPTH wide, 2 deep, from the row towards the queue
		table.insert(uses, {
			asset = "AST-019_CounterCorner",
			parts = { "AST-019_CounterCorner" },
			at = CFrame.new(MODULE + COUNTER_DEPTH / 2, 0, COUNTER_DEPTH / 2 - 1),
			scale = Vector3.new(COUNTER_DEPTH / MODULE, k.Y, 2 / MODULE),
		})
	end
	return {
		part = "Counter_L" .. level,
		upgrade = "counter",
		level = level,
		vehicle = vehicle,
		budget = BUDGET.counter,
		uses = uses,
	}
end

-- Drawer Lock (AST-020 Lock = Quaternius Padlock + hasp, DEC-155). Origin = the register origin, so the piece
-- lands on the drawer when placed with the DRAWER CFrame. TASK-085 removes Lock from the placed DRAWER model.
local function drawerLock(vehicle: string): PieceSpec
	return {
		part = "DrawerLock_L1",
		upgrade = "cash_drawer_lock",
		level = 1,
		vehicle = vehicle,
		budget = BUDGET.cash_drawer_lock,
		uses = { { asset = "AST-020_CashRegister", parts = { "Lock" } } },
	}
end

-- Trailer Lights (AST-023): one piece, pivot = mast origin (TRL-LIGHTS mast row of MAP-01_placements); the string
-- sits at the offset between the two TRL-LIGHTS rows (both rotY 0): (41.25, 11.05, 34.9) - (40, 11.45, 41).
-- Lights start Enabled; the switch (AST-039, FEAT-020) is wave 2 code.
const STRING_OFFSET = Vector3.new(1.25, -0.4, -6.1)
local function trailerLights(vehicle: string): PieceSpec
	return {
		part = "TrailerLights_L1",
		upgrade = "trailer_lights",
		level = 1,
		vehicle = vehicle,
		budget = BUDGET.trailer_lights,
		uses = {
			{ asset = "AST-023_TrailerLights", parts = { "Lights_Mast", "Lights_Mast_Lamps" }, sub = "Mast" },
			{
				asset = "AST-023_TrailerLights",
				parts = { "Lights_String", "Lights_String_Bulbs" },
				at = CFrame.new(STRING_OFFSET),
				sub = "String",
			},
		},
		atts = {
			{ name = "Light_Main", use = 1, pos = v(0, 4.538, 0.246), light = "spot" },
			{ name = "Light_String1", use = 2, pos = v(5.7, -1.125, 0), light = "point" },
			{ name = "Light_String2", use = 2, pos = v(-5.7, -1.125, 0), light = "point" },
		},
	}
end

local function allPieces(): { PieceSpec }
	local list: { PieceSpec } = {}
	for _, vehicle in { "cart", "trailer" } do
		for level = 1, 3 do
			table.insert(list, grill(level, vehicle))
			table.insert(list, cooler(level, vehicle))
			table.insert(list, counter(level, vehicle))
		end
		table.insert(list, drawerLock(vehicle))
	end
	table.insert(list, trailerLights("trailer"))
	return list
end

const PIECES = allPieces()

-- HTTP / Content --------------------------------------------------------------------------------------------------

local function httpGet(url: string): string
	local was = HttpService.HttpEnabled
	HttpService.HttpEnabled = true
	local ok, res = pcall(function()
		return HttpService:GetAsync(url, true)
	end)
	HttpService.HttpEnabled = was
	if not ok then
		error("GET " .. url .. " failed: " .. tostring(res))
	end
	return res :: string
end

local function join(base: string, path: string): string
	if string.sub(base, -1) ~= "/" then
		base ..= "/"
	end
	return base .. path
end

-- src/Shared/Content over HTTP: the directory listing of `python -m http.server` gives the file names.
local function contentFromServer(baseUrl: string): any
	const dir = join(baseUrl, "src/Shared/Content/")
	local root = Instance.new("ModuleScript")
	root.Name = "Content"
	root.Source = httpGet(dir .. "init.luau")
	for name in string.gmatch(httpGet(dir), 'href="([%w_]+)%.luau"') do
		if name ~= "init" then
			local ms = Instance.new("ModuleScript")
			ms.Name = name
			ms.Source = httpGet(dir .. name .. ".luau")
			ms.Parent = root
		end
	end
	return (require :: any)(root)
end

local contentCache: any = nil
local function resolveContent(opts: Options?): any
	if opts and opts.content then
		contentCache = opts.content
		return contentCache
	end
	if contentCache then
		return contentCache
	end
	local shared = ReplicatedStorage:FindFirstChild("shared")
	local mod = shared and shared:FindFirstChild("Content")
	if mod and mod:IsA("ModuleScript") then
		local ok, res = pcall(require, mod)
		if ok then
			contentCache = res
			return res
		end
	end
	if opts and opts.baseUrl then
		local ok, res = pcall(contentFromServer, opts.baseUrl)
		if ok then
			contentCache = res
			return res
		end
		warn("build_pieces: Content over HTTP failed: " .. tostring(res))
	end
	return nil
end

-- Asset loading (InsertService, cached like build_items.luau) ----------------------------------------------------

local function cacheFolder(): Folder
	local f = ServerStorage:FindFirstChild(CACHE_NAME)
	if not f then
		f = Instance.new("Folder")
		f.Name = CACHE_NAME
		f.Parent = ServerStorage
	end
	return f :: Folder
end

local function template(name: string, ids: Ids, reload: boolean?): Instance
	local id = ids[name]
	if id == nil then
		error("no asset id for " .. name .. " in _asset_ids.json")
	end
	local cache = cacheFolder()
	local hit = cache:FindFirstChild(name)
	if hit and (reload or hit:GetAttribute("AssetId") ~= tostring(id)) then
		hit:Destroy()
		hit = nil
	end
	if hit then
		return hit
	end
	local num = tonumber(id)
	if not num then
		error("bad asset id for " .. name .. ": " .. tostring(id))
	end
	local ok, res = pcall(function()
		return InsertService:LoadAsset(num)
	end)
	if not ok then
		error("LoadAsset failed for " .. name .. ": " .. tostring(res))
	end
	local container = res :: Model
	local model = container:GetChildren()[1]
	if not model then
		container:Destroy()
		error("empty asset " .. name)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("PackageLink") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	model.Name = name
	model:SetAttribute("AssetId", tostring(id))
	model.Parent = cache
	container:Destroy()
	return model
end

local function near(a: Vector3, b: Vector3, tol: number): boolean
	return math.abs(a.X - b.X) <= tol and math.abs(a.Y - b.Y) <= tol and math.abs(a.Z - b.Z) <= tol
end

local function fmt(p: Vector3): string
	return string.format("(%.3f, %.3f, %.3f)", p.X, p.Y, p.Z)
end

-- M -> asset space of the upload (180 degrees about Y when flipped)
local function toAsset(p: Vector3, flip: boolean): Vector3
	return if flip then Vector3.new(-p.X, p.Y, -p.Z) else p
end

const NEW_GRILL_HINT = "the id in _asset_ids.json is the old 6-slot upload: export the new "
	.. "Assets/models/equipment/AST-012_RollerGrill.fbx to Assets/import/equipment, upload it and update the id"

-- Fresh clone of an asset: parts by name (flattened, unparented), asset origin and axis convention.
-- Returns nil (with problems written) when the upload does not match the measured spec.
local function load(asset: string, ids: Ids, reload: boolean?, problems: { string }): Loaded?
	local spec = ASSETS[asset]
	assert(spec, "build_pieces: no ASSETS entry for " .. asset)
	local clone = template(asset, ids, reload):Clone()
	local byName: { [string]: BasePart } = {}
	local all: { BasePart } = {}
	for _, d in clone:GetDescendants() do
		if d:IsA("BasePart") then
			byName[d.Name] = d
			table.insert(all, d)
		end
	end
	local count = 0
	local only: string? = nil
	for name in spec.parts do
		count += 1
		only = name
	end
	if count == 1 and only and not byName[only] and #all == 1 then
		table.insert(problems, string.format("note: %s: part %q taken as %s", asset, all[1].Name, only))
		byName[only] = all[1]
	end
	local missing: { string } = {}
	for name in spec.parts do
		if not byName[name] then
			table.insert(missing, name)
		end
	end
	if #missing > 0 then
		table.sort(missing)
		local msg = string.format("%s (id %s): missing part(s) %s", asset, tostring(ids[asset]), table.concat(missing, ", "))
		if asset == "AST-012_RollerGrill" then
			msg ..= " - " .. NEW_GRILL_HINT
		end
		table.insert(problems, msg)
		clone:Destroy()
		return nil
	end
	-- sizes (catches a wrong upload)
	for name, ps in spec.parts do
		const size = ps.box.max - ps.box.min
		if not near(byName[name].Size, size, SIZE_TOL) then
			table.insert(problems, string.format("%s.%s: size %s, .fbx %s", asset, name, fmt(byName[name].Size), fmt(size)))
		end
	end
	-- axis convention from the probe pair
	local root = byName[spec.root]
	local flip = DEFAULT_FLIP
	if spec.probe then
		const expected = centre(spec.parts[spec.probe].box) - centre(spec.parts[spec.root].box)
		const rel = root.CFrame:VectorToObjectSpace(byName[spec.probe].Position - root.Position)
		if near(rel, toAsset(expected, true), PROBE_TOL) then
			flip = true
		elseif near(rel, toAsset(expected, false), PROBE_TOL) then
			flip = false
		else
			table.insert(
				problems,
				string.format("%s: %s at %s from %s, .fbx %s (axis convention unknown; default used)", asset, spec.probe, fmt(rel), spec.root, fmt(expected))
			)
		end
	end
	const origin = root.CFrame * CFrame.new(-toAsset(centre(spec.parts[spec.root].box), flip))
	-- the imported Model pivot is what place_assets.luau uses: report when it is not the asset origin
	if clone:IsA("Model") then
		const pivot = clone:GetPivot()
		if not near(pivot.Position, origin.Position, SIZE_TOL) then
			table.insert(
				problems,
				string.format("note: %s: imported Model pivot %s is not the asset origin %s (MAP-01 CFrames use the Model pivot)", asset, fmt(origin:PointToObjectSpace(pivot.Position)), fmt(Vector3.zero))
			)
		end
	end
	for _, p in all do
		p.Parent = nil
		for _, d in p:GetDescendants() do
			if d:IsA("PackageLink") or d:IsA("JointInstance") or d:IsA("WeldConstraint") then
				d:Destroy()
			end
		end
	end
	clone:Destroy()
	return { byName = byName, origin = origin, flip = flip }
end

-- Builders --------------------------------------------------------------------------------------------------------

local function cosmetic(p: BasePart, asset: string, tris: number)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p:SetAttribute("Asset", asset)
	p:SetAttribute("Tris", tris)
end

local function addLight(att: Attachment, kind: string)
	const warm = Color3.fromHex("#FFE7C2") -- AST-023 bulbs
	if kind == "spot" then
		local l = Instance.new("SpotLight")
		l.Face = Enum.NormalId.Bottom
		l.Angle = 120
		l.Range = 18 -- AST-023: visual reach aligned with the LightZone radius 18 (UPG-005)
		l.Brightness = 2
		l.Shadows = true
		l.Color = warm
		l.Parent = att
	else
		local l = Instance.new("PointLight")
		l.Range = 8
		l.Brightness = 0.6
		l.Shadows = false
		l.Color = warm
		l.Parent = att
	end
end

function Kit.buildPiece(spec: PieceSpec, ids: Ids, reload: boolean?, parent: Instance, problems: { string }): Model?
	local m = Instance.new("Model")
	m.Name = spec.part
	m:SetAttribute("Upgrade", spec.upgrade)
	m:SetAttribute("Level", spec.level)
	m:SetAttribute("ForVehicle", spec.vehicle)
	local assets: { string } = {}
	local tris = 0
	local root: BasePart? = nil
	local hosts: { BasePart } = {} -- first part of each use (attachment host)
	local frames: { CFrame } = {} -- asset origin of each use, piece space
	local flips: { boolean } = {}
	for i, use in spec.uses do
		local loaded = load(use.asset, ids, reload, problems)
		if not loaded then
			m:Destroy()
			return nil
		end
		if not table.find(assets, use.asset) then
			table.insert(assets, use.asset)
		end
		local container: Instance = m
		if use.sub then
			container = m:FindFirstChild(use.sub) or Instance.new("Model")
			container.Name = use.sub
			container.Parent = m
		end
		const at = use.at or CFrame.identity
		frames[i] = at
		flips[i] = loaded.flip
		for _, name in use.parts do
			local p = loaded.byName[name]
			local rel = loaded.origin:ToObjectSpace(p.CFrame)
			if use.scale then
				rel = CFrame.new(rel.Position * use.scale) * rel.Rotation
				p.Size *= use.scale
			end
			p.CFrame = at * rel
			const t = ASSETS[use.asset].parts[name].tris
			tris += t
			cosmetic(p, use.asset, t)
			p.Parent = container
			if not hosts[i] then
				hosts[i] = p
			end
			if not root then
				root = p
			end
		end
		for _, p in loaded.byName do
			if p.Parent == nil then
				p:Destroy()
			end
		end
		if use.sub and container:IsA("Model") then
			container.PrimaryPart = hosts[i]
		end
	end
	local rootPart = root :: BasePart
	m.PrimaryPart = rootPart
	rootPart.PivotOffset = rootPart.CFrame:ToObjectSpace(CFrame.identity) -- pivot = piece origin
	-- visual fittings (real Attachments)
	for _, f in spec.atts or {} do
		const i = f.use or 1
		const host = hosts[i]
		local a = Instance.new("Attachment")
		a.Name = f.name
		a.CFrame = host.CFrame:ToObjectSpace(frames[i] * CFrame.new(toAsset(f.pos, flips[i])))
		a.Parent = host
		if f.light then
			addLight(a, f.light)
		end
	end
	-- anchors (T38: attributes only, piece space)
	for _, f in spec.anchors or {} do
		const i = f.use or 1
		m:SetAttribute("Anchor_" .. f.name, (frames[i] * CFrame.new(toAsset(f.pos, flips[i]))).Position)
	end
	m:SetAttribute("Asset", table.concat(assets, ","))
	m:SetAttribute("Tris", tris)
	m:SetAttribute("AxisFlip", flips[1])
	m.Parent = parent
	return m
end

function Kit.build(ids: Ids, reload: boolean?, problems: { string }): Folder
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		assets = Instance.new("Folder")
		assets.Name = "Assets"
		assets.Parent = ReplicatedStorage
		table.insert(problems, "note: ReplicatedStorage.Assets created here; KitVersion is written by build_kits.luau")
	end
	local equipment = (assets :: Instance):FindFirstChild("Equipment")
	if not equipment then
		equipment = Instance.new("Folder")
		equipment.Name = "Equipment"
		equipment.Parent = assets
	end
	local old = (equipment :: Instance):FindFirstChild(KIT_NAME)
	if old then
		old:Destroy()
	end
	local kit = Instance.new("Folder")
	kit.Name = KIT_NAME
	kit:SetAttribute("KitVersion", PIECES_VERSION)
	for i, spec in PIECES do
		local folder = kit:FindFirstChild(spec.vehicle)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = spec.vehicle
			folder.Parent = kit
		end
		local ok, err = pcall(Kit.buildPiece, spec, ids, reload, folder :: Instance, problems)
		if not ok then
			table.insert(problems, string.format("%s/%s: %s", spec.vehicle, spec.part, tostring(err)))
		end
		if i % 6 == 0 then
			task.wait()
		end
	end
	kit.Parent = equipment
	return kit
end

-- Check (TASK-084 acceptance) ------------------------------------------------------------------------------------

local function specOf(vehicle: string, part: string): PieceSpec?
	for _, s in PIECES do
		if s.vehicle == vehicle and s.part == part then
			return s
		end
	end
	return nil
end

function Kit.check(ids: Ids?, content: any?): { string }
	local problems: { string } = {}
	local c = content or resolveContent(nil)
	-- ids exist (and are numbers) for every asset this script uses
	if ids then
		local names: { string } = {}
		for asset in ASSETS do
			table.insert(names, asset)
		end
		table.sort(names)
		for _, asset in names do
			if ids[asset] == nil then
				local msg = "no id in _asset_ids.json: " .. asset
				if asset == "AST-012_RollerGrill" then
					msg ..= " (upload Assets/models/equipment/AST-012_RollerGrill.fbx)"
				end
				table.insert(problems, msg)
			elseif tonumber(ids[asset]) == nil then
				table.insert(problems, "bad id in _asset_ids.json: " .. asset .. " = " .. tostring(ids[asset]))
			end
		end
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local equipment = assets and assets:FindFirstChild("Equipment")
	local kit = equipment and equipment:FindFirstChild(KIT_NAME)
	if not kit then
		table.insert(problems, "ReplicatedStorage.Assets.Equipment." .. KIT_NAME .. " missing")
		return problems
	end
	if kit:GetAttribute("KitVersion") ~= PIECES_VERSION then
		table.insert(problems, KIT_NAME .. ".KitVersion ~= " .. PIECES_VERSION)
	end

	-- expected (vehicle, Part) rows: Content.Upgrades when available, else this script's table
	type Row = { vehicle: string, part: string, upgrade: string, level: number }
	local rows: { Row } = {}
	if c then
		for _, up in c.Upgrades.List do
			for _, vehicle in up.Vehicles do
				for _, row in (up.Levels[vehicle] or {}) do
					if row.Part ~= "" then
						table.insert(rows, { vehicle = vehicle, part = row.Part, upgrade = up.Key, level = row.Level })
					end
				end
			end
		end
		for _, s in PIECES do
			local found = false
			for _, r in rows do
				if r.vehicle == s.vehicle and r.part == s.part then
					found = true
					if r.upgrade ~= s.upgrade or r.level ~= s.level then
						table.insert(problems, string.format("%s/%s: spec says %s L%d, Content.Upgrades says %s L%d", s.vehicle, s.part, s.upgrade, s.level, r.upgrade, r.level))
					end
				end
			end
			if not found then
				table.insert(problems, string.format("%s/%s: not a Part of Content.Upgrades (orphan piece spec)", s.vehicle, s.part))
			end
		end
	else
		table.insert(problems, "note: Content not found (no rojo serve / baseUrl): rows from this script")
		for _, s in PIECES do
			table.insert(rows, { vehicle = s.vehicle, part = s.part, upgrade = s.upgrade, level = s.level })
		end
	end

	for _, r in rows do
		local label = r.vehicle .. "/" .. r.part
		local folder = kit:FindFirstChild(r.vehicle)
		local m = folder and folder:FindFirstChild(r.part)
		if not (m and m:IsA("Model")) then
			table.insert(problems, string.format("%s missing (%s L%d)", label, r.upgrade, r.level))
			continue
		end
		if m:GetAttribute("Upgrade") ~= r.upgrade then
			table.insert(problems, label .. ": Upgrade ~= " .. r.upgrade)
		end
		if m:GetAttribute("Level") ~= r.level then
			table.insert(problems, label .. ": Level ~= " .. r.level)
		end
		if not m.PrimaryPart then
			table.insert(problems, label .. ": no PrimaryPart (pivot)")
		end
		local spec = specOf(r.vehicle, r.part)
		if spec then
			local tris = m:GetAttribute("Tris") :: number? or 0
			if tris > spec.budget then
				table.insert(problems, string.format("%s: %d tris > %d", label, tris, spec.budget))
			end
			for _, f in spec.atts or {} do
				if not m:FindFirstChild(f.name, true) then
					table.insert(problems, label .. ": attachment " .. f.name .. " missing")
				end
			end
			for _, f in spec.anchors or {} do
				if typeof(m:GetAttribute("Anchor_" .. f.name)) ~= "Vector3" then
					table.insert(problems, label .. ": attribute Anchor_" .. f.name .. " missing")
				end
			end
		else
			table.insert(problems, label .. ": no spec in build_pieces.luau")
		end
	end

	-- T38 and kit hygiene
	for _, d in kit:GetDescendants() do
		if d:IsA("PackageLink") then
			table.insert(problems, "PackageLink left in " .. d:GetFullName())
		elseif d:IsA("BasePart") and d:GetAttribute("Asset") == nil then
			table.insert(problems, "no Asset attribute: " .. d:GetFullName())
		elseif d:IsA("Attachment") then
			for _, pat in ANCHOR_PATTERNS do
				if string.match(d.Name, pat) then
					table.insert(problems, "T38: anchor " .. d:GetFullName() .. " inside a piece (use Anchor_* attributes)")
				end
			end
		end
		for _, t in FORBIDDEN_TAGS do
			if CollectionService:HasTag(d, t) then
				table.insert(problems, "tag " .. t .. " on " .. d:GetFullName() .. " (TASK-085 tags the clone in the Workspace)")
			end
		end
	end
	return problems
end

-- Demo --------------------------------------------------------------------------------------------------------------
-- workspace.PiecesDemo (anchored copies, visual check only): one row per vehicle, one column per upgrade, levels
-- stacked in depth; small red balls mark the Anchor_* points (where TASK-085 puts the prompts and slots).

function Kit.clearDemo()
	local old = workspace:FindFirstChild(DEMO_NAME)
	if old then
		old:Destroy()
	end
end

const DEMO_COLUMNS = { "grill", "cooler", "counter", "cash_drawer_lock", "trailer_lights" }
const DEMO_COLUMN_X = { 0, 9, 18, 30, 44 }

function Kit.demo(): { string }
	Kit.clearDemo()
	local problems: { string } = {}
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local kit = assets and assets:FindFirstChild("Equipment") and (assets :: any).Equipment:FindFirstChild(KIT_NAME)
	if not kit then
		return { "demo: " .. KIT_NAME .. " missing" }
	end
	local root = Instance.new("Model")
	root.Name = DEMO_NAME
	const origin = CFrame.new(0, 0, -140) * CFrame.Angles(0, math.pi, 0) -- front (-Z) towards the default camera
	for row, vehicle in { "cart", "trailer" } do
		local folder = kit:FindFirstChild(vehicle)
		if not folder then
			table.insert(problems, "demo: " .. vehicle .. " folder missing")
			continue
		end
		for _, m in folder:GetChildren() do
			if not m:IsA("Model") then
				continue
			end
			const col = table.find(DEMO_COLUMNS, m:GetAttribute("Upgrade") :: string) or #DEMO_COLUMNS + 1
			const level = m:GetAttribute("Level") :: number? or 0
			local c = m:Clone()
			c.Name = vehicle .. "_" .. m.Name
			const at = origin * CFrame.new(DEMO_COLUMN_X[col] or 60, 0, (row - 1) * 30 + (level - 1) * 7)
			c:PivotTo(at)
			for name, value in m:GetAttributes() do
				if string.sub(name, 1, 7) == "Anchor_" and typeof(value) == "Vector3" then
					local ball = Instance.new("Part")
					ball.Name = name
					ball.Shape = Enum.PartType.Ball
					ball.Size = Vector3.new(0.2, 0.2, 0.2)
					ball.Color = Color3.new(1, 0, 0)
					ball.Material = Enum.Material.Neon
					ball.Anchored = true
					ball.CanCollide = false
					ball.CanQuery = false
					ball.CFrame = at * CFrame.new(value)
					ball.Parent = c
				end
			end
			c.Parent = root
		end
	end
	root.Parent = workspace
	return problems
end

-- Entry point -----------------------------------------------------------------------------------------------------

function Kit.run(opts: Options): string
	local ids: Ids? = opts.ids
	if not ids and opts.baseUrl then
		ids = HttpService:JSONDecode(httpGet(join(opts.baseUrl, "Assets/import/_asset_ids.json")))
	end
	assert(ids, "asset ids missing: pass opts.ids or opts.baseUrl")
	local content = resolveContent(opts)
	local problems: { string } = {}
	local kit = Kit.build(ids, opts.reload, problems)
	for _, p in Kit.check(ids, content) do
		table.insert(problems, p)
	end
	if opts.demo then
		for _, p in Kit.demo() do
			table.insert(problems, p)
		end
	end
	local errors = 0
	for _, p in problems do
		if string.sub(p, 1, 6) ~= "note: " then
			errors += 1
		end
	end
	local lines: { string } = {}
	local count = 0
	for _, folder in kit:GetChildren() do
		for _, m in folder:GetChildren() do
			count += 1
			table.insert(
				lines,
				string.format("%s/%s %s L%s %d tris", folder.Name, m.Name, tostring(m:GetAttribute("Upgrade")), tostring(m:GetAttribute("Level")), m:GetAttribute("Tris") :: number? or -1)
			)
		end
	end
	table.sort(lines)
	local msg = string.format("upgrade pieces kit v%d: %d / %d pieces; %d problem(s)\n%s", PIECES_VERSION, count, #PIECES, errors, table.concat(lines, "\n"))
	if #problems > 0 then
		msg ..= "\n" .. table.concat(problems, "\n")
	end
	return msg
end

return Kit
