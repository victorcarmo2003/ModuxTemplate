--!strict
--[[
	Items and food kit builder (TASK-007; architecture.md §18.9.1, §18.9.5). EDIT MODE ONLY: Command Bar or Studio MCP.
	InsertService is allowed here because this is a tool (§18.9 rule 1: never in src/).

	Builds, outside Rojo (§18.9 rule 5), ONLY ReplicatedStorage.Assets.Items (Assets.Crew, Assets.Equipment and the
	root KitVersion of build_kits.luau are left alone):
	  Items                     Folder, attribute KitVersion = ITEMS_VERSION (items kit only)
	    Tools/<Content.Items key>   Tool: Handle (+ welded parts), Att_Hand, Grip, attribute Item = key
	      hot_dog                   AST-003 Tool without sauce: Handle (open bun) + Sausage; Att_Topping1, Att_Serve
	      coffee                    AST-010 cup; VFX_Steam
	      pack_*  (9)               AST-011 one mesh per package (AST-011_Pack<Name>), label texture T_PackLabels embedded
	      revive_kit                AST-051 first-aid kit (grip = top of the arch handle); VFX_Rare, VFX_Use
	      altered_item              AST-061 default variant (= Variants/altered_item/Sausage), attribute Variant
	    Variants/altered_item/<V>   TASK-099 (Provisional): Tool per ITM-020 variant, Item = "altered_item",
	                                Variant = V: Sausage (Sausage_Wrong), Bun (Bun_Bitten; Att_Sausage)
	    Toppings/<ingredient key>   Model, pivot = Att_Topping of the .fbx, attribute TopHeight (measured here)
	    Food/SausageRaw, SausageGrilled (AST-002), BunClosed, BunOpen (AST-001)   Model, pivot = base centre
	    WrongToppings/Wrong_Roach|Beetle|Worms|SlimeGreen|SlimeRed   Model, pivot = piece origin (AST-061 rev. 2026-10-14)
	    Food/SausageWrong, BunBitten (AST-061)   rail / board visual of the altered item (TASK-110) and the part a
	                                hot dog with Altered = true shows instead of its sausage / bun (same boxes)

	Geometry facts below (part boxes, attachment points, tris) were measured in the approved .blend sources
	(Assets/blender/food, market) on 2026-10-10, in Roblox axes (x = -X, y = Z, z = Y of Blender; exporter
	convention). Empties do NOT survive the FBX import, so attachments are rebuilt here from those points.
	Imported MeshParts sit at their bounding-box centre: the asset origin is recovered from the root part
	(origin = root.CFrame * -centre) and every other part is checked against it (catches a wrong upload).

	Kit conventions (consumed by ItemService TASK-022, HotDogVisual TASK-023, KitchenController):
	  - attribute Asset = "AST-###_<name>" on every Tool/Model and BasePart (§18.9 rule 7); Tris = .blend count;
	  - Tools: parts unanchored, Massless, welded to Handle (WeldConstraint), CanCollide/CanTouch/CanQuery false
	    (ItemService turns collision on for a dropped Tool, FEAT-036); CanBeDropped = false; Grip = Att_Hand
	    (C1 of the R6 RightGrip; item upright, front -Z, lower right third in 1st person);
	  - Toppings/Food: anchored, no collision/query/touch, PrimaryPart + PivotOffset = pivot.
	Not built here: bottles, slices, piles and the jar (station visuals, map), HotDog_Display and Coffee_Pair
	(vitrine / cutscene).

	Usage (repo served at http://127.0.0.1:8772/, e.g. `python -m http.server 8772` at the repo root):
		local Http = game:GetService("HttpService")
		local was = Http.HttpEnabled
		Http.HttpEnabled = true
		local ms = Instance.new("ModuleScript")
		ms.Source = Http:GetAsync("http://127.0.0.1:8772/tools/assetplace/build_items.luau")
		Http.HttpEnabled = was
		local Items = require(ms)
		print(Items.run({ baseUrl = "http://127.0.0.1:8772/" }))              -- build + check
		print(Items.run({ baseUrl = "http://127.0.0.1:8772/", demo = true })) -- + workspace.ItemsDemo
		print(Items.check())                                                   -- check only (after a build)
		Items.clearDemo()
	Without the server: Items.run({ ids = <_asset_ids table>, content = <Content table> }).
	Content is taken from opts.content, else ReplicatedStorage.shared.Content (rojo serve), else the server.
	Save the place afterwards (Ctrl+S): the place is not in git, this script is the recipe.
]]

local HttpService = game:GetService("HttpService")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

type Ids = { [string]: any }
type Box = { min: Vector3, max: Vector3 }
type PartSpec = { name: string, box: Box, tris: number }
type Piece = {
	asset: string, -- key in _asset_ids.json
	parts: { PartSpec }, -- first = root (Handle / PrimaryPart); the others are welded/kept, the rest is dropped
	atts: { [string]: Vector3 }?, -- asset space
}
type ToolSpec = Piece & {
	hand: Vector3?, -- asset space grip point (default: base centre along `up`)
	up: Vector3?, -- handle-space direction that is up in the hand (default +Y)
	right: Vector3?, -- handle-space direction that points right in the hand (default +X)
	color: Color3?, -- flat recolor (clears TextureID)
	budget: number,
}
type PivotSpec = Piece & { pivot: Vector3, budget: number }
export type Options = {
	baseUrl: string?,
	ids: Ids?,
	content: any?,
	reload: boolean?, -- drop cached item assets and load them again
	demo: boolean?, -- also build workspace.ItemsDemo for a visual check
}

local Items = {}

const ITEMS_VERSION = 3 -- 2: altered_item, Variants, Food SausageWrong / BunBitten (TASK-099); 3: AST-061 revision 2026-10-14 (bitten bun 245 tris, WrongToppings)
const CACHE_NAME = "__AssetCache" -- shared with place_assets.luau / build_kits.luau
const DEMO_NAME = "ItemsDemo"
const SIZE_TOL = 0.05
const TOP_TOL = 0.01
const HOT_DOG_BUDGET = 900 -- AST-003: assembled with 3 toppings
const MAX_TOPPINGS = 3 -- DEC-071

local function box(x0: number, y0: number, z0: number, x1: number, y1: number, z1: number): Box
	return { min = Vector3.new(x0, y0, z0), max = Vector3.new(x1, y1, z1) }
end

local function centre(b: Box): Vector3
	return (b.min + b.max) / 2
end

-- Tools (key = Content.Items key) -------------------------------------------------------------------------------

local function pack(name: string, sizeBox: Box, tris: number, lying: boolean?): ToolSpec
	return {
		asset = "AST-011_Pack" .. name,
		parts = { { name = "AST-011_Pack" .. name, box = sizeBox, tris = tris } },
		-- lying: the long axis (Y of the piece) goes across the hand, +X of the piece goes down
		up = if lying then Vector3.new(-1, 0, 0) else nil,
		right = if lying then Vector3.new(0, 1, 0) else nil,
		budget = 300, -- AST-011
	}
end

-- AST-011 packages (2026-10-10): Kenney Food Kit shapes (CC0) with their own colour and label (product drawing from
-- AST-071 + English name) from one texture, Assets/textures/props/T_PackLabels.png (embedded in each FBX). Base centre
-- at the origin; label faces to the front/back. Measured in Assets/blender/food/AST-011_Pack*.blend.
-- "caixa baixa" (Cheese) = carton-small lying down.
const BAG = box(-0.2746, 0, -0.1468, 0.2746, 0.8, 0.1468)
const BAG_FLAT = box(-0.4, 0, -0.2877, 0.4, 0.2345, 0.2877)
const CAN = box(-0.2344, 0, -0.2344, 0.2344, 0.5, 0.2344)
const CAN_SMALL = box(-0.28, 0, -0.28, 0.28, 0.3008, 0.28)
const CARTON = box(-0.1558, 0, -0.1558, 0.1558, 0.8, 0.1558)
const CARTON_SMALL = box(-0.162, 0, -0.162, 0.162, 0.55, 0.162)

const TOOLS: { [string]: ToolSpec } = {
	hot_dog = {
		asset = "AST-003_HotDog",
		parts = {
			{ name = "Handle", box = box(-0.5, 0, -0.225, 0.5, 0.345, 0.225), tris = 152 }, -- open bun
			{ name = "Sausage", box = box(-0.6, 0.21, -0.12, 0.6, 0.45, 0.12), tris = 164 },
		},
		atts = {
			Att_Hand = Vector3.new(0, 0, 0),
			Att_Serve = Vector3.new(0, 0.225, 0),
			Att_Topping1 = Vector3.new(0, 0.45, 0), -- top of the sausage; Att_Topping2/3 unused (DEC-142)
		},
		hand = Vector3.new(0, 0, 0),
		budget = HOT_DOG_BUDGET,
	},
	coffee = {
		asset = "AST-010_Coffee",
		parts = { { name = "Handle", box = box(-0.166, 0, -0.175, 0.166, 0.55, 0.175), tris = 260 } },
		atts = { Att_Hand = Vector3.new(0, 0.265, 0), VFX_Steam = Vector3.new(0, 0.55, 0) },
		hand = Vector3.new(0, 0.265, 0),
		budget = 300, -- AST-010
	},
	revive_kit = {
		asset = "AST-051_ReviveKit",
		parts = { { name = "Handle", box = box(-0.4, -0.68, -0.2, 0.4, 0.039, 0.2), tris = 172 } },
		atts = {
			Att_Hand = Vector3.new(0, 0, 0), -- centre of the arch handle; the box hangs below the hand
			VFX_Rare = Vector3.new(0, -0.43, 0),
			VFX_Use = Vector3.new(0, 0.12, 0),
		},
		hand = Vector3.new(0, 0, 0),
		budget = 400, -- AST-051
	},
	pack_sausages = pack("Sausages", CARTON, 90, true),
	pack_buns = pack("Buns", BAG, 44),
	pack_ketchup = pack("Ketchup", CAN, 156),
	pack_mustard = pack("Mustard", CAN, 156),
	pack_cheese = pack("Cheese", CARTON_SMALL, 70, true),
	pack_bacon = pack("Bacon", BAG_FLAT, 110),
	pack_potato_sticks = pack("PotatoSticks", BAG, 44),
	pack_cream_cheese = pack("CreamCheese", CAN_SMALL, 154),
	pack_coffee = pack("Coffee", BAG, 44),
}

-- Content.Items keys deliberately not built by this script (check reports them as notes).
const DEFERRED: { [string]: string } = {}

-- ITM-020 altered item (AST-061_WrongFood, measured in the .blend 2026-10-10). One Content key, two looks: each
-- variant is a Tool under Variants/altered_item/<V>; Tools/altered_item is a copy of ALTERED_DEFAULT so that every
-- Content.Items key still has a Tool. Provisional (TASK-099): ItemService picks the variant (Tool attribute Variant).
const WRONG_SAUSAGE_BOX = box(-0.6, 0, -0.82, 0.6, 0.24, -0.58)
-- measured in Studio on the 2026-10-14 upload (AST-061_WrongFood 92999301453162, normals fixed): bite widens the bun to 1.02 x 0.365 x 0.472
const BITTEN_BUN_BOX = box(-0.52, 0, -0.225, 0.5, 0.365, 0.247)
const ALTERED_DEFAULT = "Sausage"
const ALTERED_ORDER = { "Sausage", "Bun" }
const ALTERED: { [string]: ToolSpec } = {
	Sausage = {
		asset = "AST-061_WrongFood",
		parts = { { name = "Sausage_Wrong", box = WRONG_SAUSAGE_BOX, tris = 164 } },
		atts = { Att_Hand = Vector3.new(0, 0, -0.7) },
		hand = Vector3.new(0, 0, -0.7), -- base centre of the sausage
		budget = 250, -- AST-061
	},
	Bun = {
		-- Bun_Bitten is the asset root (origin = base centre of the bun, like AST-001 Bun_Open)
		asset = "AST-061_WrongFood",
		parts = { { name = "Bun_Bitten", box = BITTEN_BUN_BOX, tris = 245 } },
		atts = { Att_Hand = Vector3.zero, Att_Sausage = Vector3.new(0, 0.33, 0) },
		hand = Vector3.zero,
		budget = 250, -- AST-061
	},
}

-- Toppings (key = Content.Ingredients key; pivot = asset origin = Att_Topping) ----------------------------------

local function topping(asset: string, part: string, b: Box, tris: number, budget: number): PivotSpec
	return { asset = asset, parts = { { name = part, box = b, tris = tris } }, pivot = Vector3.zero, budget = budget }
end

const TOPPINGS: { [string]: PivotSpec } = {
	ketchup = topping("AST-004_KetchupTopping", "Ketchup_Topping", box(-0.5092, -0.0157, -0.0592, 0.5092, 0.031, 0.0592), 66, 100),
	mustard = topping("AST-005_MustardTopping", "Mustard_Topping", box(-0.5102, -0.0162, -0.0588, 0.5102, 0.0269, 0.0588), 86, 100),
	cheese = topping("AST-006_Cheese", "Cheese_Topping", box(-0.5, -0.2518, -0.245, 0.5, 0.0256, 0.245), 148, 150),
	bacon = topping("AST-007_Bacon", "Bacon_Topping", box(-0.3911, -0.1069, -0.1854, 0.3911, 0.1147, 0.1854), 160, 240), -- 2 strips x 120
	potato_sticks = topping("AST-008_PotatoSticks", "PotatoSticks_Topping", box(-0.479, 0.002, -0.1545, 0.4611, 0.119, 0.1736), 240, 250),
	cream_cheese = topping("AST-009_CreamCheese", "CreamCheese_Topping", box(-0.4802, -0.0243, -0.0982, 0.4802, 0.068, 0.0982), 126, 150),
}

-- Food (station visuals; pivot = base centre, §18.9.5) -----------------------------------------------------------

const FOOD: { [string]: PivotSpec } = {
	SausageRaw = {
		asset = "AST-002_Sausage",
		parts = { { name = "Sausage_Raw", box = box(-0.6, 0, -0.72, 0.6, 0.24, -0.48), tris = 92 } },
		atts = {
			Bar_Cook = Vector3.new(0, 1.24, -0.6),
			VFX_Ready = Vector3.new(0, 0.12, -0.6),
			VFX_Steam = Vector3.new(0, 0.24, -0.6),
		},
		pivot = Vector3.new(0, 0, -0.6),
		budget = 200,
	},
	SausageGrilled = {
		asset = "AST-002_Sausage",
		parts = { { name = "Sausage_Grilled", box = box(-0.6, 0, -0.12, 0.6, 0.24, 0.12), tris = 164 } },
		atts = {
			Bar_Cook = Vector3.new(0, 1.24, 0),
			VFX_Ready = Vector3.new(0, 0.12, 0),
			VFX_Steam = Vector3.new(0, 0.24, 0),
		},
		pivot = Vector3.zero,
		budget = 200,
	},
	BunClosed = {
		asset = "AST-001_Bun",
		parts = { { name = "Bun_Closed", box = box(-0.5, 0, -1.025, 0.5, 0.35, -0.575), tris = 128 } },
		atts = { Att_Hand = Vector3.new(0, 0, -0.8), Att_Sausage = Vector3.new(0, 0.33, -0.8) },
		pivot = Vector3.new(0, 0, -0.8),
		budget = 250,
	},
	BunOpen = {
		asset = "AST-001_Bun",
		parts = { { name = "Bun_Open", box = box(-0.5, 0, -0.225, 0.5, 0.345, 0.225), tris = 152 } },
		atts = { Att_Hand = Vector3.zero, Att_Sausage = Vector3.new(0, 0.33, 0) },
		pivot = Vector3.zero,
		budget = 250,
	},
	-- AST-061 (ITM-020): same boxes and attachments as SausageGrilled / BunOpen, so they swap 1:1
	SausageWrong = {
		asset = "AST-061_WrongFood",
		parts = { { name = "Sausage_Wrong", box = WRONG_SAUSAGE_BOX, tris = 164 } },
		atts = {
			Bar_Cook = Vector3.new(0, 1.24, -0.7),
			VFX_Ready = Vector3.new(0, 0.12, -0.7),
			VFX_Steam = Vector3.new(0, 0.24, -0.7),
		},
		pivot = Vector3.new(0, 0, -0.7),
		budget = 250,
	},
	BunBitten = {
		asset = "AST-061_WrongFood",
		parts = { { name = "Bun_Bitten", box = BITTEN_BUN_BOX, tris = 245 } },
		atts = { Att_Hand = Vector3.zero, Att_Sausage = Vector3.new(0, 0.33, 0) },
		pivot = Vector3.zero,
		budget = 250,
	},
}

-- AST-061 "wrong" toppings (revision 2026-10-14, Provisional): one Model per piece in Items/WrongToppings, pivot = the
-- piece's own origin (base centre in the .blend; Att_Topping_<Name>), no TopHeight-stack rules touched. The five pieces
-- sit 1.4 stud apart in the file; extract() recovers each origin from the part's bbox centre, so the box centres below
-- are the part centre relative to that origin, measured in Studio on upload 118293514249309 (AST-061_WrongToppings, normals fixed).
-- Provisional map normal -> wrong: ketchup=SlimeRed, mustard=SlimeGreen, cheese=Worms, bacon=Roach, potato_sticks=Beetle,
-- cream_cheese=SlimeGreen (asset-list.md AST-061). Not wired to gameplay here.
local function wrongTopping(name: string, c: Vector3, s: Vector3, tris: number): PivotSpec
	return {
		asset = "AST-061_WrongToppings",
		parts = { { name = "Wrong_" .. name, box = { min = c - s / 2, max = c + s / 2 }, tris = tris } },
		atts = { ["Att_Topping_" .. name] = Vector3.zero },
		pivot = Vector3.zero,
		budget = 180,
	}
end

const WRONG_TOPPINGS: { [string]: PivotSpec } = {
	Wrong_Roach = wrongTopping("Roach", Vector3.new(0.181, 0.056, 0), Vector3.new(0.829, 0.149, 0.588), 156),
	Wrong_Beetle = wrongTopping("Beetle", Vector3.new(0.12, 0.085, 0), Vector3.new(0.621, 0.21, 0.651), 144),
	Wrong_Worms = wrongTopping("Worms", Vector3.new(0.001, 0.097, 0), Vector3.new(0.824, 0.166, 0.566), 144),
	Wrong_SlimeGreen = wrongTopping("SlimeGreen", Vector3.new(0.032, 0.025, 0), Vector3.new(0.756, 0.45, 0.33), 88),
	Wrong_SlimeRed = wrongTopping("SlimeRed", Vector3.new(0.032, 0.025, 0), Vector3.new(0.756, 0.45, 0.33), 88),
}

-- HTTP / Content ------------------------------------------------------------------------------------------------

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
		warn("build_items: Content over HTTP failed: " .. tostring(res))
	end
	return nil
end

-- Asset loading (InsertService, cached like build_kits.luau) ------------------------------------------------------

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

local function fmt(v: Vector3): string
	return string.format("(%.3f, %.3f, %.3f)", v.X, v.Y, v.Z)
end

-- Parts of a fresh clone named in `piece.parts` (flattened, unparented) and the asset origin in world space.
-- A single-part piece also takes a lone part with another name (import renamed it; reported as a note).
local function extract(piece: Piece, ids: Ids, reload: boolean?, problems: { string }): ({ BasePart }?, CFrame)
	local clone = template(piece.asset, ids, reload):Clone()
	local byName: { [string]: BasePart } = {}
	local all: { BasePart } = {}
	for _, d in clone:GetDescendants() do
		if d:IsA("BasePart") then
			byName[d.Name] = d
			table.insert(all, d)
		end
	end
	local out: { BasePart } = {}
	for i, spec in piece.parts do
		local p = byName[spec.name]
		if not p and #piece.parts == 1 and #all == 1 then
			p = all[1]
			table.insert(problems, string.format("note: %s: part %q taken as %s", piece.asset, all[1].Name, spec.name))
		end
		if not p then
			table.insert(problems, string.format("%s: missing part %s", piece.asset, spec.name))
			clone:Destroy()
			return nil, CFrame.identity
		end
		out[i] = p
	end
	local root = out[1]
	local origin = root.CFrame * CFrame.new(-centre(piece.parts[1].box))
	for i, spec in piece.parts do
		local p = out[i]
		local size = spec.box.max - spec.box.min
		if not near(p.Size, size, SIZE_TOL) then
			table.insert(problems, string.format("%s.%s: size %s, .blend %s", piece.asset, spec.name, fmt(p.Size), fmt(size)))
		end
		if i > 1 then
			local at = origin:PointToObjectSpace(p.Position)
			if not near(at, centre(spec.box), SIZE_TOL) then
				table.insert(problems, string.format("%s.%s: at %s, .blend %s", piece.asset, spec.name, fmt(at), fmt(centre(spec.box))))
			end
		end
	end
	for _, p in out do
		p.Parent = nil
		for _, d in p:GetDescendants() do
			if d:IsA("PackageLink") or d:IsA("JointInstance") or d:IsA("WeldConstraint") then
				d:Destroy()
			end
		end
	end
	clone:Destroy()
	return out, origin
end

local function addAtts(part: BasePart, origin: CFrame, atts: { [string]: Vector3 }?)
	if not atts then
		return
	end
	for name, pos in atts do
		local a = Instance.new("Attachment")
		a.Name = name
		a.CFrame = part.CFrame:ToObjectSpace(origin * CFrame.new(pos))
		a.Parent = part
	end
end

local function sumTris(piece: Piece): number
	local n = 0
	for _, s in piece.parts do
		n += s.tris
	end
	return n
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Builders --------------------------------------------------------------------------------------------------------

function Items.buildTool(key: string, spec: ToolSpec, ids: Ids, reload: boolean?, parent: Instance, problems: { string })
	local parts, origin = extract(spec, ids, reload, problems)
	if not parts then
		return
	end
	local handle = parts[1]
	const size = spec.parts[1].box.max - spec.parts[1].box.min
	local up = spec.up or Vector3.yAxis
	local right = spec.right or Vector3.xAxis
	-- grip point in handle space: the .blend Att_Hand, else the base centre along `up`
	local gripPos = if spec.hand
		then handle.CFrame:PointToObjectSpace(origin * spec.hand)
		else -up * math.abs(up:Dot(size)) / 2
	local grip = CFrame.fromMatrix(gripPos, right, up)

	local tool = Instance.new("Tool")
	tool.Name = key
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = grip
	tool:SetAttribute("Item", key)
	tool:SetAttribute("Asset", spec.asset)
	tool:SetAttribute("Tris", sumTris(spec))
	handle.Name = "Handle"
	for i, p in parts do
		p.Anchored = false
		p.Massless = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p:SetAttribute("Asset", spec.asset)
		p:SetAttribute("Tris", spec.parts[i].tris)
		p.Parent = tool
		if p ~= handle then
			local w = Instance.new("WeldConstraint")
			w.Part0 = handle
			w.Part1 = p
			w.Parent = handle
		end
	end
	if spec.color then
		if handle:IsA("MeshPart") then
			handle.TextureID = ""
		end
		handle.Color = spec.color
		handle:SetAttribute("Recolor", "Provisional")
	end
	addAtts(handle, origin, spec.atts)
	if not handle:FindFirstChild("Att_Hand") then
		local a = Instance.new("Attachment")
		a.Name = "Att_Hand"
		a.CFrame = grip
		a.Parent = handle
	end
	tool.Parent = parent
end

-- Highest point of the model's parts above the pivot, along the pivot's up axis.
local function topAbove(m: Model): number
	local pivot = m:GetPivot()
	local top = -math.huge
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			local h = p.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local w = p.CFrame:PointToWorldSpace(Vector3.new(sx * h.X, sy * h.Y, sz * h.Z))
						top = math.max(top, pivot:PointToObjectSpace(w).Y)
					end
				end
			end
		end
	end
	return top
end

function Items.buildPivoted(
	name: string,
	spec: PivotSpec,
	ids: Ids,
	reload: boolean?,
	parent: Instance,
	problems: { string }
): Model?
	local parts, origin = extract(spec, ids, reload, problems)
	if not parts then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("Asset", spec.asset)
	m:SetAttribute("Tris", sumTris(spec))
	for i, p in parts do
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p:SetAttribute("Asset", spec.asset)
		p:SetAttribute("Tris", spec.parts[i].tris)
		p.Parent = m
	end
	local root = parts[1]
	m.PrimaryPart = root
	root.PivotOffset = root.CFrame:ToObjectSpace(origin * CFrame.new(spec.pivot))
	addAtts(root, origin, spec.atts)
	m.Parent = parent
	return m
end

-- AST-061 revision only (non-destructive): replaces Food/SausageWrong + Food/BunBitten and (re)creates
-- Items/WrongToppings. Leaves Tools / Variants / Toppings and the other Food untouched (hand edits survive).
function Items.buildWrong(ids: Ids, reload: boolean?, problems: { string })
	local items = (ReplicatedStorage :: any).Assets.Items :: Folder
	local food = items:FindFirstChild("Food") :: Folder
	for _, n in { "SausageWrong", "BunBitten" } do
		local old = food:FindFirstChild(n)
		if old then
			old:Destroy()
		end
		Items.buildPivoted(n, FOOD[n], ids, reload, food, problems)
	end
	local oldW = items:FindFirstChild("WrongToppings")
	if oldW then
		oldW:Destroy()
	end
	local wt = folder(items, "WrongToppings")
	for name, spec in WRONG_TOPPINGS do
		Items.buildPivoted(name, spec, ids, reload, wt, problems)
	end
end

function Items.build(ids: Ids, reload: boolean?, problems: { string }): Folder
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		assets = Instance.new("Folder")
		assets.Name = "Assets"
		assets.Parent = ReplicatedStorage
		table.insert(problems, "note: ReplicatedStorage.Assets created here; KitVersion is written by build_kits.luau")
	end
	local old = (assets :: Instance):FindFirstChild("Items")
	if old then
		old:Destroy()
	end
	local items = Instance.new("Folder")
	items.Name = "Items"
	items:SetAttribute("KitVersion", ITEMS_VERSION)
	local tools = folder(items, "Tools")
	local variants = folder(folder(items, "Variants"), "altered_item")
	local toppings = folder(items, "Toppings")
	local food = folder(items, "Food")

	local function guarded(label: string, fn: () -> ())
		local ok, err = pcall(fn)
		if not ok then
			table.insert(problems, label .. ": " .. tostring(err))
		end
	end
	local keys = {}
	for k in TOOLS do
		table.insert(keys, k)
	end
	table.sort(keys)
	for _, k in keys do
		guarded("Tools." .. k, function()
			Items.buildTool(k, TOOLS[k], ids, reload, tools, problems)
		end)
	end
	-- ITM-020: one Tool per variant (named after the variant), plus Tools.altered_item = the default variant
	for _, v in ALTERED_ORDER do
		guarded("Variants.altered_item." .. v, function()
			Items.buildTool("altered_item", ALTERED[v], ids, reload, variants, problems)
			local t = variants:FindFirstChild("altered_item")
			if t then
				t.Name = v
				t:SetAttribute("Variant", v)
			end
		end)
	end
	guarded("Tools.altered_item", function()
		Items.buildTool("altered_item", ALTERED[ALTERED_DEFAULT], ids, reload, tools, problems)
		local t = tools:FindFirstChild("altered_item")
		if t then
			t:SetAttribute("Variant", ALTERED_DEFAULT)
		end
	end)
	for k, spec in TOPPINGS do
		guarded("Toppings." .. k, function()
			local m = Items.buildPivoted(k, spec, ids, reload, toppings, problems)
			if m then
				m:SetAttribute("Ingredient", k)
				m:SetAttribute("TopHeight", math.round(topAbove(m) * 1000) / 1000) -- DEC-142, measured
			end
		end)
	end
	for name, spec in FOOD do
		guarded("Food." .. name, function()
			Items.buildPivoted(name, spec, ids, reload, food, problems)
		end)
	end
	local wrongToppings = folder(items, "WrongToppings")
	for name, spec in WRONG_TOPPINGS do
		guarded("WrongToppings." .. name, function()
			Items.buildPivoted(name, spec, ids, reload, wrongToppings, problems)
		end)
	end
	items.Parent = assets
	return items
end

-- Check (TASK-007 acceptance) -----------------------------------------------------------------------------------

function Items.check(ids: Ids?, content: any?): { string }
	local problems: { string } = {}
	local c = content or resolveContent(nil)
	-- ids exist (and are numbers) for every piece this script uses
	if ids then
		local seen: { [string]: boolean } = {}
		local function need(asset: string)
			if seen[asset] then
				return
			end
			seen[asset] = true
			if ids[asset] == nil then
				table.insert(problems, "no id in _asset_ids.json: " .. asset)
			elseif tonumber(ids[asset]) == nil then
				table.insert(problems, "bad id in _asset_ids.json: " .. asset .. " = " .. tostring(ids[asset]))
			end
		end
		for _, s in TOOLS do
			need(s.asset)
		end
		for _, s in TOPPINGS do
			need(s.asset)
		end
		for _, s in FOOD do
			need(s.asset)
		end
		for _, s in WRONG_TOPPINGS do
			need(s.asset)
		end
		for _, s in ALTERED do
			need(s.asset)
		end
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local items = assets and assets:FindFirstChild("Items")
	if not items then
		table.insert(problems, "ReplicatedStorage.Assets.Items missing")
		return problems
	end
	if items:GetAttribute("KitVersion") ~= ITEMS_VERSION then
		table.insert(problems, "Assets.Items.KitVersion ~= " .. ITEMS_VERSION)
	end
	local tools = items:FindFirstChild("Tools")
	local toppings = items:FindFirstChild("Toppings")
	local food = items:FindFirstChild("Food")

	-- the item / topping key lists: Content when available, else this script's tables
	local itemKeys: { string } = {}
	local toppingKeys: { string } = {}
	if c then
		for _, row in c.Items.List do
			table.insert(itemKeys, row.Key)
		end
		for _, k in c.Ingredients.ToppingKeys do
			table.insert(toppingKeys, k)
		end
		for k in TOOLS do
			if not c.Items.ByKey[k] then
				table.insert(problems, "Tools." .. k .. " is not a Content.Items key")
			end
		end
		for k in TOPPINGS do
			if not table.find(toppingKeys, k) then
				table.insert(problems, "Toppings." .. k .. " is not in Content.Ingredients.ToppingKeys")
			end
		end
		for _, row in c.Packages.List do
			if not TOOLS[row.Item] then
				table.insert(problems, "Content.Packages." .. row.Key .. ": Tool " .. row.Item .. " has no spec")
			end
		end
	else
		table.insert(problems, "note: Content not found (no rojo serve / baseUrl): key lists from this script")
		for k in TOOLS do
			table.insert(itemKeys, k)
		end
		for k in TOPPINGS do
			table.insert(toppingKeys, k)
		end
	end

	-- every item has a Tool with Handle, Att_Hand and Grip
	for _, k in itemKeys do
		local t = tools and tools:FindFirstChild(k)
		if DEFERRED[k] and not t then
			table.insert(problems, "note: Tools." .. k .. " not built: " .. DEFERRED[k])
			continue
		end
		if not (t and t:IsA("Tool")) then
			table.insert(problems, "Tools." .. k .. " missing")
			continue
		end
		local handle = t:FindFirstChild("Handle")
		if not (handle and handle:IsA("BasePart")) then
			table.insert(problems, "Tools." .. k .. ".Handle missing")
			continue
		end
		if not handle:FindFirstChild("Att_Hand") then
			table.insert(problems, "Tools." .. k .. ".Handle.Att_Hand missing")
		end
		if t:GetAttribute("Item") ~= k then
			table.insert(problems, "Tools." .. k .. ": attribute Item ~= key")
		end
		local spec = TOOLS[k]
		if spec and spec.budget ~= HOT_DOG_BUDGET and (t:GetAttribute("Tris") :: number? or 0) > spec.budget then
			table.insert(problems, string.format("Tools.%s: %s tris > %d", k, tostring(t:GetAttribute("Tris")), spec.budget))
		end
	end
	local hotDog = tools and tools:FindFirstChild("hot_dog")
	local hdHandle = hotDog and hotDog:FindFirstChild("Handle")
	for _, n in { "Att_Topping1", "Att_Serve" } do
		if not (hdHandle and hdHandle:FindFirstChild(n)) then
			table.insert(problems, "Tools.hot_dog.Handle." .. n .. " missing")
		end
	end
	if hotDog and not hotDog:FindFirstChild("Sausage") then
		table.insert(problems, "Tools.hot_dog.Sausage missing")
	end

	-- ITM-020: one Tool per variant (Item = altered_item, Variant = name), Tools.altered_item = default variant
	local altered = tools and tools:FindFirstChild("altered_item")
	if altered and altered:GetAttribute("Variant") ~= ALTERED_DEFAULT then
		table.insert(problems, "Tools.altered_item: attribute Variant ~= " .. ALTERED_DEFAULT)
	end
	local variantsRoot = items:FindFirstChild("Variants")
	local variants = variantsRoot and variantsRoot:FindFirstChild("altered_item")
	for _, v in ALTERED_ORDER do
		local t = variants and variants:FindFirstChild(v)
		if not (t and t:IsA("Tool")) then
			table.insert(problems, "Variants.altered_item." .. v .. " missing")
			continue
		end
		local handle = t:FindFirstChild("Handle")
		if not (handle and handle:IsA("BasePart") and handle:FindFirstChild("Att_Hand")) then
			table.insert(problems, "Variants.altered_item." .. v .. ".Handle.Att_Hand missing")
		end
		if t:GetAttribute("Item") ~= "altered_item" or t:GetAttribute("Variant") ~= v then
			table.insert(problems, "Variants.altered_item." .. v .. ": attributes Item / Variant wrong")
		end
		if (t:GetAttribute("Tris") :: number? or 0) > ALTERED[v].budget then
			table.insert(problems, string.format("Variants.altered_item.%s: tris > %d", v, ALTERED[v].budget))
		end
	end
	local bitten = variants and variants:FindFirstChild("Bun")
	local bittenHandle = bitten and bitten:FindFirstChild("Handle")
	if bittenHandle and not bittenHandle:FindFirstChild("Att_Sausage") then
		table.insert(problems, "Variants.altered_item.Bun.Handle.Att_Sausage missing")
	end

	-- every topping has a Model with pivot and a measured TopHeight that matches the .blend
	local heaviest: { number } = {}
	for _, k in toppingKeys do
		local m = toppings and toppings:FindFirstChild(k)
		if not (m and m:IsA("Model") and m.PrimaryPart) then
			table.insert(problems, "Toppings." .. k .. " missing (or no PrimaryPart)")
			continue
		end
		local h = m:GetAttribute("TopHeight")
		local spec = TOPPINGS[k]
		if type(h) ~= "number" then
			table.insert(problems, "Toppings." .. k .. ": no TopHeight")
		elseif spec and math.abs(h - spec.parts[1].box.max.Y) > TOP_TOL then
			table.insert(problems, string.format("Toppings.%s: TopHeight %.3f, .blend %.3f", k, h, spec.parts[1].box.max.Y))
		end
		local tris = m:GetAttribute("Tris") :: number? or 0
		if spec and tris > spec.budget then
			table.insert(problems, string.format("Toppings.%s: %d tris > %d", k, tris, spec.budget))
		end
		table.insert(heaviest, tris)
	end
	-- AST-003: hot dog + the 3 heaviest toppings <= 900
	if hotDog then
		table.sort(heaviest, function(a: number, b: number): boolean
			return a > b
		end)
		local total = hotDog:GetAttribute("Tris") :: number? or 0
		for i = 1, math.min(MAX_TOPPINGS, #heaviest) do
			total += heaviest[i]
		end
		if total > HOT_DOG_BUDGET then
			table.insert(problems, string.format("hot_dog + 3 heaviest toppings = %d tris > %d", total, HOT_DOG_BUDGET))
		end
	end

	for name, spec in FOOD do
		local m = food and food:FindFirstChild(name)
		if not (m and m:IsA("Model") and m.PrimaryPart) then
			table.insert(problems, "Food." .. name .. " missing (or no PrimaryPart)")
		elseif (m:GetAttribute("Tris") :: number? or 0) > spec.budget then
			table.insert(problems, string.format("Food.%s: tris > %d", name, spec.budget))
		end
	end

	for _, d in items:GetDescendants() do
		if d:IsA("PackageLink") then
			table.insert(problems, "PackageLink left in " .. d:GetFullName())
		elseif d:IsA("BasePart") and d:GetAttribute("Asset") == nil then
			table.insert(problems, "no Asset attribute: " .. d:GetFullName())
		end
	end
	-- AST-061 WrongToppings: every piece is a Model with PrimaryPart, its Att_Topping_<Name> and a size matching the box
	local wt = items:FindFirstChild("WrongToppings")
	for name, spec in WRONG_TOPPINGS do
		local m = wt and wt:FindFirstChild(name)
		if not (m and m:IsA("Model") and m.PrimaryPart) then
			table.insert(problems, "WrongToppings." .. name .. " missing")
			continue
		end
		local want = spec.parts[1].box.max - spec.parts[1].box.min
		if not near(m.PrimaryPart.Size, want, SIZE_TOL) then
			table.insert(problems, string.format("WrongToppings.%s: size %s, want %s", name, fmt(m.PrimaryPart.Size), fmt(want)))
		end
		if not m.PrimaryPart:FindFirstChildWhichIsA("Attachment") then
			table.insert(problems, "WrongToppings." .. name .. ": no Att_Topping")
		end
	end
	return problems
end

-- Demo ----------------------------------------------------------------------------------------------------------
-- workspace.ItemsDemo (anchored copies, visual check only): row 1 Tools as held (grip frame on the ground line),
-- row 2 Toppings and Food, row 3 hot dogs with stacked toppings (the TASK-023 rule), row 4 the crew body
-- holding each Tool with the R6 hold pose (RightGrip C0 = (0, -1, 0) * Rx(-90), shoulder raised 90 degrees).

const COMBOS: { { string } } = {
	{ "ketchup" },
	{ "mustard" },
	{ "cheese" },
	{ "bacon" },
	{ "potato_sticks" },
	{ "cream_cheese" },
	{ "ketchup", "cheese" },
	{ "mustard", "bacon" },
	{ "potato_sticks", "bacon", "cheese" }, -- heaviest (tris)
	{ "cream_cheese", "cheese", "ketchup" },
	{ "mustard", "potato_sticks", "cream_cheese" },
	{ "bacon", "ketchup", "mustard" },
}

-- Visual order (DEC-142): BeforeCords (cheese) first, the rest in assembly order.
function Items.stackOrder(assembly: { string }, content: any?): { string }
	local first: { string } = {}
	local rest: { string } = {}
	for _, k in assembly do
		local row = content and content.Ingredients.ByKey[k]
		local stack = if row then row.Stack else (if k == "cheese" then "BeforeCords" else "InOrder")
		table.insert(if stack == "BeforeCords" then first else rest, k)
	end
	for _, k in rest do
		table.insert(first, k)
	end
	return first
end

-- Anchored Model copy of a Tool placed so that its grip frame sits at `at`.
local function toolCopy(tool: Tool, at: CFrame, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = tool.Name
	local handle = tool:FindFirstChild("Handle") :: BasePart
	local handleAt = at * tool.Grip:Inverse()
	for _, p in tool:GetChildren() do
		if p:IsA("BasePart") then
			local q = p:Clone()
			for _, w in q:GetChildren() do
				if w:IsA("WeldConstraint") then
					w:Destroy()
				end
			end
			q.Anchored = true
			q.CFrame = handleAt * handle.CFrame:ToObjectSpace(p.CFrame)
			q.Parent = m
			if p == handle then
				m.PrimaryPart = q
			end
		end
	end
	m.Parent = parent
	return m
end

local function stacked(items: Instance, combo: { string }, at: CFrame, parent: Instance, content: any?): { string }
	local missing: { string } = {}
	local tool = items:FindFirstChild("Tools") and (items :: any).Tools:FindFirstChild("hot_dog")
	if not tool then
		return { "Tools.hot_dog" }
	end
	local m = toolCopy(tool, at, parent)
	m.Name = "hot_dog_" .. table.concat(combo, "+")
	local att = m.PrimaryPart and m.PrimaryPart:FindFirstChild("Att_Topping1") :: Attachment?
	if not att then
		return { "Att_Topping1" }
	end
	local cursor = att.WorldCFrame
	for _, k in Items.stackOrder(combo, content) do
		local tpl = (items :: any).Toppings:FindFirstChild(k) :: Model?
		if not tpl then
			table.insert(missing, "Toppings." .. k)
			continue
		end
		local t = tpl:Clone()
		t:PivotTo(cursor)
		t.Parent = m
		cursor *= CFrame.new(0, t:GetAttribute("TopHeight") :: number? or 0, 0)
	end
	return missing
end

-- Crew body + first animal, right arm raised, holding `tool`.
local function holder(tool: Tool, at: CFrame, parent: Instance): string?
	local crew = ReplicatedStorage:FindFirstChild("Assets") and (ReplicatedStorage :: any).Assets:FindFirstChild("Crew")
	local body = crew and crew:FindFirstChild("Body")
	if not body then
		return "Assets.Crew.Body (run build_kits.luau first)"
	end
	local m = Instance.new("Model")
	m.Name = "Crew_" .. tool.Name
	local parts: { [string]: BasePart } = {}
	local function take(src: Instance?)
		if src then
			for _, p in src:GetChildren() do
				if p:IsA("BasePart") then
					parts[p.Name] = p:Clone()
				end
			end
		end
	end
	take(body)
	local animals = crew:FindFirstChild("Animals")
	take(animals and (animals:FindFirstChild("Dog") or animals:GetChildren()[1]))
	local torso = parts.Torso
	local arm = parts["Right Arm"]
	if not (torso and arm) then
		m:Destroy()
		return "Crew.Body.Torso / Right Arm"
	end
	-- rest pose -> character at `at` (HumanoidRootPart at ground + 3, like the Torso)
	local toWorld = at * CFrame.new(0, 3, 0) * torso.CFrame:Inverse()
	for _, p in parts do
		p.Anchored = true
		p.CFrame = toWorld * p.CFrame
		p.Parent = m
	end
	-- Right Shoulder: joint at torso (1, 0.5, 0), axis = torso X; tool pose = arm straight forward
	local shoulder = torso.CFrame * CFrame.new(1, 0.5, 0)
	arm.CFrame = shoulder * CFrame.Angles(math.pi / 2, 0, 0) * shoulder:ToObjectSpace(arm.CFrame)
	local gripFrame = arm.CFrame * CFrame.new(0, -1, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
	toolCopy(tool, gripFrame, m)
	m.Parent = parent
	return nil
end

function Items.clearDemo()
	local old = workspace:FindFirstChild(DEMO_NAME)
	if old then
		old:Destroy()
	end
end

function Items.demo(content: any?): { string }
	Items.clearDemo()
	local problems: { string } = {}
	local items: any = (ReplicatedStorage :: any).Assets:FindFirstChild("Items")
	if not items then
		return { "demo: Assets.Items missing" }
	end
	local root = Instance.new("Model")
	root.Name = DEMO_NAME
	const origin = CFrame.new(0, 0, -100) * CFrame.Angles(0, math.pi, 0) -- facing the default camera
	local tools = items.Tools:GetChildren()
	table.sort(tools, function(a: Instance, b: Instance)
		return a.Name < b.Name
	end)
	local variants = items:FindFirstChild("Variants") and items.Variants:FindFirstChild("altered_item")
	if variants then
		for _, v in ALTERED_ORDER do
			local t = variants:FindFirstChild(v)
			if t then
				table.insert(tools, t)
			end
		end
	end
	local row = Instance.new("Model")
	row.Name = "Tools"
	for i, t in tools do
		if t:IsA("Tool") then
			toolCopy(t, origin * CFrame.new((i - 1) * 1.5, 1, 0), row)
		end
	end
	row.Parent = root
	row = Instance.new("Model")
	row.Name = "ToppingsAndFood"
	local i = 0
	for _, f in { items.Toppings, items.Food } do
		for _, m in f:GetChildren() do
			if m:IsA("Model") then
				local c = m:Clone()
				c:PivotTo(origin * CFrame.new(i * 1.5, 0.5, 3))
				c.Parent = row
				i += 1
			end
		end
	end
	row.Parent = root
	row = Instance.new("Model")
	row.Name = "Stacks"
	for j, combo in COMBOS do
		for _, miss in stacked(items, combo, origin * CFrame.new((j - 1) * 1.5, 0.5, 6), row, content) do
			table.insert(problems, "demo stack " .. table.concat(combo, "+") .. ": missing " .. miss)
		end
	end
	row.Parent = root
	row = Instance.new("Model")
	row.Name = "Held"
	for j, t in tools do
		if t:IsA("Tool") then
			local miss = holder(t, origin * CFrame.new((j - 1) * 4, 0, 12), row)
			if miss then
				table.insert(problems, "note: demo held: missing " .. miss)
				break
			end
		end
	end
	row.Parent = root
	root.Parent = workspace
	return problems
end

-- Entry point -----------------------------------------------------------------------------------------------------

function Items.run(opts: Options): string
	local ids: Ids? = opts.ids
	if not ids and opts.baseUrl then
		ids = HttpService:JSONDecode(httpGet(join(opts.baseUrl, "Assets/import/_asset_ids.json")))
	end
	assert(ids, "asset ids missing: pass opts.ids or opts.baseUrl")
	local content = resolveContent(opts)
	local problems: { string } = {}
	local items: any = Items.build(ids, opts.reload, problems)
	for _, p in Items.check(ids, content) do
		table.insert(problems, p)
	end
	if opts.demo then
		for _, p in Items.demo(content) do
			table.insert(problems, p)
		end
	end
	local errors = 0
	for _, p in problems do
		if string.sub(p, 1, 6) ~= "note: " then
			errors += 1
		end
	end
	local heights: { string } = {}
	for _, m in items.Toppings:GetChildren() do
		table.insert(heights, string.format("%s %.3f", m.Name, m:GetAttribute("TopHeight") :: number? or -1))
	end
	table.sort(heights)
	local msg = string.format(
		"items kit v%d: %d tools, %d toppings, %d food; %d problem(s)\nTopHeight: %s",
		ITEMS_VERSION,
		#items.Tools:GetChildren(),
		#items.Toppings:GetChildren(),
		#items.Food:GetChildren(),
		errors,
		table.concat(heights, ", ")
	)
	if #problems > 0 then
		msg ..= "\n" .. table.concat(problems, "\n")
	end
	return msg
end

return Items
