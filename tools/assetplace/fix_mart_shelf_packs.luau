--!nocheck
--[[
	fix_mart_shelf_packs.luau - SURGICAL and IDEMPOTENT Studio patch (2026-10-12). NOT a Place.run: it only touches the
	Mart gondolas (AST-029) and adds display packs on them. Paste in execute_luau / the command bar (Edit mode, not Play).
	Safe to run twice: a gondola that already carries the "ShelfPacks" folder is skipped (FORCE = true rebuilds it).

	Why (owner, 2026-10-12): on the SAUCES / SNACKS / COFFEE gondolas the Ketchup and the Mustard shelves showed the same
	blue-white gable carton (a MILK carton). It was never a product: AST-029_GondolaBoxes / AST-029_GondolaBags are the Mini
	Market shelves WITH THE KENNEY STOCK BAKED INTO THE MESH (colormap u 0.3 / 0.6 / 0.8 faces: blue+white gable cartons on
	the low tier, orange boxes on the top tier, orange/red bags on the Bags variant). Nothing in the repo placed AST-011 packs.

	Fix (assets, already exported + uploaded):
	  AST-029_GondolaBoxesBare  (Assets/blender/market/AST-029_GondolaBoxesBare.blend, same 4.5 x 2.5 footprint, bottom at 0,
	                             top 6.0 -> 5.647 because the stock stuck out above the frame, 156 tris, no stock)
	  + one row of 3 AST-011 packs (the REAL product model) per shelf tier, per face, scaled up to read from the aisle.

	What it does, in order (asserts first; nothing changes if a LoadAsset fails):
	  1  LoadAsset: old Boxes, old Bags, Bare, and the packs in PRODUCTS (reads MeshId / TextureID / Size)
	  2  every gondola MeshPart in workspace (name AST-029_GondolaBoxes|Bags, or MeshId of those): the part is REPLACED by a
	     clone of the Bare MeshPart (MeshId is not scriptable): same CFrame (bottom stays on the floor: centre drops by half
	     the height difference), Size scaled by the same factor the hand edit had, properties / attributes / tags / children
	     / welds / PrimaryPart moved over, the Model keeps its pivot. Part + Model are renamed ...GondolaBoxesBare (what a
	     rebuild with the edited MAP-01_placements.luau produces); the Bags variant becomes the Boxes shelf (Bags has no
	     shelf boards once its bag bins are removed)
	  3  each BUY-<Product> anchor (workspace MKT-SHELVES, made by bind_map01) is matched to the nearest gondola (inside its
	     footprint) and to the FACE it is on (sign of the anchor on the gondola's local Z)
	  4  that face gets 3 packs x 2 tiers of its product, in a Folder "ShelfPacks" inside the gondola Model (Anchored,
	     no collision, no query; they move with the Model). Packs face outwards, bases on the shelf boards.
	NOT TOUCHED: GondolaEnd (still has its baked stock: none placed in the current Mart), FridgeDisplay (Cheese / Cream Cheese packs inside the
	glass fridge: tools/assetplace/fix_mart_fridge.luau), MeatCase (modelled
	sausage / bacon trays, no milk), BunDisplay (loose AST-001 buns).
	AFTER A REBUILD (Place.run + bind_map01): run this again (it is idempotent) to put the packs back.
	Undo: Ctrl+Z (waypoints "fix_mart_shelf_packs: before/after").
]]

local InsertService = game:GetService("InsertService")
local CollectionService = game:GetService("CollectionService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local FORCE = false -- true: destroy and rebuild the ShelfPacks folders (e.g. after BUY-* anchors moved)

-- Open Cloud ids (Assets/import/_asset_ids.json)
local ID_BOXES, ID_BAGS = 81790019432073, 96145737156743
local ID_BARE = 71997536682298 -- AST-029_GondolaBoxesBare
local BARE_NAME = "AST-029_GondolaBoxesBare"
local MINIMARKET_TEXTURE = "rbxassetid://131566103531055" -- _texture_ids.json MiniMarket_colormap (if the upload has none)

-- Shelf geometry in the mesh frame (floor = 0): board tops at 1.24 and 3.88, lane = y 0.18..0.89 (0.535 centre) per face,
-- between the lips; item width 3.9 inner. Measured on the exported FBX (tools: Blender, see asset-list AST-029).
local TIER_Y = { 1.24, 3.88 }
local LANE_Z = 0.535
local SLOT_X = { -1.25, 0, 1.25 }
local FIT_W, FIT_D, FIT_H, MAX_S = 1.05, 0.68, 1.9, 2.2 -- display box of one pack; MAX_S caps the up-scale

-- product -> pack asset (key of _asset_ids.json), anchor, where it is shown
local PRODUCTS = {
	Ketchup = { id = 125674740343523, where = "gondola" }, -- AST-011_PackKetchup
	Mustard = { id = 136778166284061, where = "gondola" }, -- AST-011_PackMustard
	PotatoSticks = { id = 86909796753605, where = "gondola" }, -- AST-011_PackPotatoSticks
	Coffee = { id = 76927154867260, where = "gondola" }, -- AST-011_PackCoffee
	Buns = { id = 95424608926436, where = "BunDisplay (AST-050, loose AST-001 buns on the rack): no pack on the shelf" },
	Sausages = { id = 100612169234352, where = "MeatCase (AST-107, modelled sausage trays): no pack on the shelf" },
	Bacon = { id = 135662389576379, where = "MeatCase (AST-107, modelled bacon trays): no pack on the shelf" },
	Cheese = { id = 92483463477733, where = "FridgeDisplay (AST-030Shelves): packs placed by fix_mart_fridge.luau, not here" },
	CreamCheese = { id = 83310847413801, where = "FridgeDisplay (AST-030Shelves): packs placed by fix_mart_fridge.luau, not here" },
}
local PRODUCT_ORDER = { "Ketchup", "Mustard", "PotatoSticks", "Coffee", "Buns", "Sausages", "Bacon", "Cheese", "CreamCheese" }

local COPY = { "Anchored", "CanCollide", "CanQuery", "CanTouch", "CastShadow", "Massless", "Locked", "Material", "Color",
	"Reflectance", "Transparency", "CollisionFidelity", "RenderFidelity", "DoubleSided", "EnableFluidForces" }

local report: { string } = {}
local function say(...)
	local s = string.format(...)
	table.insert(report, s)
	print(s)
end
local function fv(v: Vector3): string
	return string.format("(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z)
end

-- ---------------------------------------------------------------- 1. load the reference assets
local loaded: { Instance } = {}
local function loadMesh(id: number, what: string): MeshPart
	local ok, res = pcall(function()
		return InsertService:LoadAsset(id)
	end)
	assert(ok and res, ("LoadAsset %d (%s) failed: %s (HttpEnabled / asset permission / not owned by the place group?)"):format(id, what, tostring(res)))
	table.insert(loaded, res)
	local mp = res:FindFirstChildWhichIsA("MeshPart", true)
	assert(mp, ("asset %d (%s) has no MeshPart"):format(id, what))
	return mp
end

local oldBoxes, oldBags = loadMesh(ID_BOXES, "GondolaBoxes"), loadMesh(ID_BAGS, "GondolaBags")
local bare = loadMesh(ID_BARE, BARE_NAME)
assert(math.abs(bare.Size.X - oldBoxes.Size.X) < 0.01 and math.abs(bare.Size.Z - oldBoxes.Size.Z) < 0.01,
	"Bare footprint differs from the old gondola")
assert(math.abs(oldBags.Size.X - oldBoxes.Size.X) < 0.01 and math.abs(oldBags.Size.Z - oldBoxes.Size.Z) < 0.01,
	"Bags footprint differs from Boxes")
say("ref old Boxes size %s, Bags %s, Bare %s (MeshId %s)", fv(oldBoxes.Size), fv(oldBags.Size), fv(bare.Size), bare.MeshId)

local packTpl: { [string]: MeshPart } = {}
for name, p in PRODUCTS do
	if p.where == "gondola" then
		packTpl[name] = loadMesh(p.id, "Pack" .. name)
		say("ref pack %-12s size %s", name, fv(packTpl[name].Size))
	end
end

-- ---------------------------------------------------------------- helpers
local function isOld(d: Instance): boolean
	return d:IsA("MeshPart") and (d.MeshId == oldBoxes.MeshId or d.MeshId == oldBags.MeshId)
end
local function isBare(d: Instance): boolean
	return d:IsA("MeshPart") and d.MeshId == bare.MeshId
end
local function isGondola(d: Instance): boolean
	if not d:IsA("MeshPart") then
		return false
	end
	if d:FindFirstAncestor("__AssetCache") then
		return false
	end
	return isOld(d) or isBare(d) or d.Name == "AST-029_GondolaBoxes" or d.Name == "AST-029_GondolaBags" or d.Name == BARE_NAME
end

ChangeHistoryService:SetWaypoint("fix_mart_shelf_packs: before")

-- ---------------------------------------------------------------- 2. swap the gondola meshes
local function swap(g: MeshPart): MeshPart
	local oldMesh = if g.MeshId == oldBags.MeshId or g.Name == "AST-029_GondolaBags" then oldBags else oldBoxes
	local k = Vector3.new(g.Size.X / oldMesh.Size.X, g.Size.Y / oldMesh.Size.Y, g.Size.Z / oldMesh.Size.Z)
	local dyLocal = (bare.Size.Y - oldMesh.Size.Y) / 2 * k.Y -- bottom stays on the floor, the centre drops
	local n = bare:Clone()
	for _, c in n:GetChildren() do
		if not c:IsA("SurfaceAppearance") then
			c:Destroy()
		end
	end
	n.Name = BARE_NAME
	n.Size = Vector3.new(bare.Size.X * k.X, bare.Size.Y * k.Y, bare.Size.Z * k.Z)
	n.CFrame = g.CFrame * CFrame.new(0, dyLocal, 0)
	for _, prop in COPY do
		pcall(function()
			n[prop] = g[prop]
		end)
	end
	if n.TextureID == "" then
		n.TextureID = if g.TextureID ~= "" then g.TextureID else MINIMARKET_TEXTURE -- same colormap atlas
	end
	for key, value in g:GetAttributes() do
		n:SetAttribute(key, value)
	end
	for _, tag in CollectionService:GetTags(g) do
		CollectionService:AddTag(n, tag)
	end
	local model = g.Parent
	local pivot = if model and model:IsA("Model") then model:GetPivot() else nil
	local wasPrimary = model and model:IsA("Model") and model.PrimaryPart == g
	for _, c in g:GetChildren() do
		if c:IsA("Attachment") then
			c.Position -= Vector3.new(0, dyLocal, 0) -- keep the world place
		end
		c.Parent = n
	end
	if model then
		for _, d in model:GetDescendants() do
			if d:IsA("WeldConstraint") or d:IsA("Weld") or d:IsA("ManualWeld") then
				if d.Part0 == g then
					d.Part0 = n
				end
				if d.Part1 == g then
					d.Part1 = n
				end
			end
		end
	end
	n.Parent = model
	g:Destroy()
	if model and model:IsA("Model") then
		if wasPrimary then
			model.PrimaryPart = n
			n.PivotOffset = n.CFrame:ToObjectSpace(pivot)
		elseif model.PrimaryPart == nil then
			model.WorldPivot = pivot
		end
		local base = string.gsub(model.Name, "AST%-029_Gondola%a+$", BARE_NAME)
		model.Name = base
		if string.find(tostring(model:GetAttribute("Asset")), "AST-029_Gondola", 1, true) then
			model:SetAttribute("Asset", BARE_NAME)
		end
	end
	return n
end

local gondolas: { MeshPart } = {}
local swapped = 0
for _, d in workspace:GetDescendants() do
	if isGondola(d) then
		local g = d :: MeshPart
		if isBare(g) then
			table.insert(gondolas, g)
			say("gondola %s: already the Bare mesh", g:GetFullName())
		elseif isOld(g) or g.Name == "AST-029_GondolaBoxes" or g.Name == "AST-029_GondolaBags" then
			local n = swap(g)
			swapped += 1
			table.insert(gondolas, n)
			say("gondola %s: stock mesh -> Bare, size %s, centre %s", n:GetFullName(), fv(n.Size), fv(n.Position))
		end
	end
end
say("%d gondola part(s) found, %d swapped", #gondolas, swapped)

-- ---------------------------------------------------------------- 3. anchors -> gondola + face
local shelvesModel = workspace:FindFirstChild("MKT-SHELVES", true)
local faceProduct: { [MeshPart]: { [number]: string } } = {}
for _, name in PRODUCT_ORDER do
	local info = PRODUCTS[name]
	local anchor = if shelvesModel then shelvesModel:FindFirstChild("BUY-" .. name) else nil
	if info.where ~= "gondola" then
		say("product %-12s -> %s", name, info.where)
	elseif not (anchor and anchor:IsA("BasePart")) then
		say("product %-12s: anchor BUY-%s not found (run bind_map01 first), skipped", name, name)
	else
		local best, bestD, bestLocal = nil, math.huge, nil
		for _, g in gondolas do
			local l = g.CFrame:PointToObjectSpace(anchor.Position)
			local half = g.Size / 2
			local d = Vector2.new(l.X, l.Z).Magnitude
			if math.abs(l.X) <= half.X + 1 and math.abs(l.Z) <= half.Z + 1.6 and d < bestD then
				best, bestD, bestLocal = g, d, l
			end
		end
		if not best then
			say("product %-12s: no gondola under BUY-%s %s (bring the shelf there or move the anchor), skipped", name, name, fv(anchor.Position))
		else
			local side = if bestLocal.Z >= 0 then 1 else -1
			faceProduct[best] = faceProduct[best] or {}
			if faceProduct[best][side] then
				say("product %-12s: face %d of %s already holds %s, skipped", name, side, best.Parent.Name, faceProduct[best][side])
			else
				faceProduct[best][side] = name
				say("product %-12s -> %s face %s (anchor local %s)", name, best.Parent.Name, if side > 0 then "+Z" else "-Z", fv(bestLocal))
			end
		end
	end
end

-- ---------------------------------------------------------------- 4. the packs
local function fillFace(g: MeshPart, folder: Folder, side: number, name: string): number
	local tpl = packTpl[name]
	local k = Vector3.new(g.Size.X / bare.Size.X, g.Size.Y / bare.Size.Y, g.Size.Z / bare.Size.Z)
	local kk = (k.X + k.Y + k.Z) / 3
	local s = math.min(MAX_S, FIT_W / tpl.Size.X, FIT_D / tpl.Size.Z, FIT_H / tpl.Size.Y)
	local size = tpl.Size * s * kk
	local yaw = if side > 0 then CFrame.Angles(0, math.pi, 0) else CFrame.identity -- label (local -Z) faces outwards
	local count = 0
	for tier, ty in TIER_Y do
		for i, sx in SLOT_X do
			local p = tpl:Clone()
			for _, c in p:GetChildren() do
				if not c:IsA("SurfaceAppearance") then
					c:Destroy()
				end
			end
			p.Name = ("ShelfPack_%s_%d_%d"):format(name, tier, i)
			p.Size = size
			local base = g.CFrame * CFrame.new(sx * k.X, ty * k.Y - g.Size.Y / 2 + 0.01, side * LANE_Z * k.Z) * yaw
			p.CFrame = base * CFrame.new(0, size.Y / 2, 0)
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
			p:SetAttribute("ShelfPack", name)
			p.Parent = folder
			count += 1
		end
	end
	say("  %s: %d packs, scale %.2f (pack size %s)", name, count, s * kk, fv(size))
	return count
end

local made = 0
for _, g in gondolas do
	local model = g.Parent
	local holder = if model and model:IsA("Model") then model else g
	local folder = holder:FindFirstChild("ShelfPacks")
	if folder and not FORCE then
		say("gondola %s: ShelfPacks already there, skipped (FORCE = true rebuilds)", g:GetFullName())
	elseif not faceProduct[g] then
		say("gondola %s: no BUY anchor on it, no packs", g:GetFullName())
	else
		if folder then
			folder:Destroy()
		end
		folder = Instance.new("Folder")
		folder.Name = "ShelfPacks"
		say("gondola %s:", g:GetFullName())
		for side, name in faceProduct[g] do
			made += fillFace(g, folder, side, name)
		end
		folder.Parent = holder
	end
end

-- ---------------------------------------------------------------- leftovers to look at
for _, d in workspace:GetDescendants() do
	if d:IsA("MeshPart") and (d.Name == "AST-029_GondolaEnd" or d.Name == "AST-030_FridgeDisplay") and not d:FindFirstAncestor("__AssetCache") then
		say("note %s (%s): not touched by this patch", d:GetFullName(), d.Name)
	end
end

for _, l in loaded do
	l:Destroy()
end
ChangeHistoryService:SetWaypoint("fix_mart_shelf_packs: after")
say("done: %d gondola(s) swapped, %d pack(s) placed. Save the place (Ctrl+S).", swapped, made)
return table.concat(report, "\n")
