--!nocheck
--[[
	fix_mart_fridge.luau - SURGICAL and IDEMPOTENT Studio patch (2026-10-12). NOT a Place.run: it only touches the DAIRY
	fridges of the Mart (AST-030) and the display packs inside them. Paste in execute_luau / the command bar (Edit mode, not Play).
	Safe to run twice: a fridge that already has Fridge_Body is not swapped again; one that already carries the "ShelfPacks"
	folder is skipped (FORCE = true rebuilds the packs, e.g. after a BUY-* anchor moved). Does NOT hard-code positions: it finds
	the live instances (MeshId of the old AST-030, or a Fridge_Body) wherever the owner put them.

	Why (owner, 2026-10-12): the DAIRY fridge was a closed cabinet with a glass door and NOTHING inside, so the player could not
	see where Cheese / Cream Cheese are. New asset AST-030_FridgeDisplayShelves (id below), same bbox as the old one
	(4 x 2.5 x 7, same pivot, doors on local +Z), five MeshParts:
	  Fridge_Body     off-white cabinet, cream interior, floor, divider, back, dark plinth  (collision: Box)
	  Fridge_Trim     teal header band, door frames and handles                              (Color Teal, no collision)
	  Fridge_Doors    two glass panes                                  (Glass, Teal-light tint, Transparency 0.55)
	  Fridge_Shelves  2 steel boards per bay (3 levels per bay with the floor)
	  Fridge_Led      slim Neon strips under the shelves / header (pale cream-teal, discreet)
	  + a PointLight "Light_Inner" (low, warm-white, no shadows) inside.

	What it does, in order (asserts first; nothing changes if a LoadAsset fails):
	  1  LoadAsset: old AST-030, the new asset, PackCheese, PackCreamCheese
	  2  every live old fridge MeshPart: REPLACED by clones of the new MeshParts (MeshId is not scriptable): same CFrame / scale
	     (Size factor of the hand edit is kept), attributes / tags / children / welds / PrimaryPart moved onto Fridge_Body, Model
	     renamed ...AST-030_FridgeDisplayShelves (what a rebuild with the edited MAP-01_placements.luau produces)
	  3  each BUY-Cheese / BUY-CreamCheese (workspace MKT-SHELVES, made by bind_map01) is matched to the nearest fridge:
	     door 1 = Cheese, door 2 = Cream Cheese (both bays of that fridge get the product)
	  4  that fridge gets 3 x 2 packs per bay per level (3 levels x 2 bays = 36 packs), in a Folder "ShelfPacks" inside the Model
	     (Anchored, no collision / query / touch), bases on the boards, label facing the glass
	The BUY-* anchors are NOT moved (they already sit in front of the glass, Y 4.6 = upper row of the middle level); the report
	prints the world position of the glass front and of every level so you can refine bind_map01 SHELVES h.
	AFTER A REBUILD (Place.run + bind_map01): run this again. Undo: Ctrl+Z (waypoints "fix_mart_fridge: before/after").
]]

local InsertService = game:GetService("InsertService")
local CollectionService = game:GetService("CollectionService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local FORCE = false

local ID_OLD, ID_NEW = 94945118932974, 88641043119484 -- AST-030_FridgeDisplay, AST-030_FridgeDisplayShelves
local NEW_NAME = "AST-030_FridgeDisplayShelves"
local MINIMARKET_TEXTURE = "rbxassetid://131566103531055" -- Mini Market colormap (if the upload has none)
local PRODUCTS = {
	Cheese = 92483463477733, -- AST-011_PackCheese        (door 1)
	CreamCheese = 83310847413801, -- AST-011_PackCreamCheese (door 2)
}

-- Asset frame (Blender source: doors on -Y; Roblox local = (x, z - 3.5, -y) around the bbox centre)
local LEVELS = { 0.9, 2.9, 4.9 } -- tops of the floor and of the 2 boards per bay
local BAY_X = { -0.95, 0.95 }
local CELL_X = { -0.52, 0, 0.52 }
local ROW_Y = { -0.2, 0.55 }
local CENTER_Z = 3.5
local FIT_W, FIT_D, FIT_H, MAX_S = 0.46, 0.64, 1.5, 2.2

local TEAL, GLASS_TINT, LED = Color3.fromRGB(63, 167, 181), Color3.fromRGB(143, 201, 209), Color3.fromRGB(222, 243, 236)
local STYLE = {
	Fridge_Body = function(p)
		p.Material = Enum.Material.SmoothPlastic
		p.CollisionFidelity = Enum.CollisionFidelity.Box
	end,
	Fridge_Trim = function(p)
		p.Material, p.Color, p.CanCollide = Enum.Material.SmoothPlastic, TEAL, false
	end,
	Fridge_Doors = function(p)
		p.Material, p.Color, p.Transparency, p.Reflectance = Enum.Material.Glass, GLASS_TINT, 0.55, 0.08
		p.CastShadow = false
		p.CollisionFidelity = Enum.CollisionFidelity.Box
	end,
	Fridge_Shelves = function(p)
		p.Material, p.CanCollide = Enum.Material.SmoothPlastic, false
	end,
	Fridge_Led = function(p)
		p.Material, p.Color, p.CanCollide, p.CastShadow = Enum.Material.Neon, LED, false, false
	end,
}
local COPY = { "Anchored", "CanCollide", "CanQuery", "CanTouch", "Massless", "Locked" }

local report: { string } = {}
local function say(...)
	local s = string.format(...)
	table.insert(report, s)
	print(s)
end
local function fv(v: Vector3): string
	return string.format("(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z)
end

-- ---------------------------------------------------------------- 1. load
local loaded: { Instance } = {}
local function load(id: number, what: string): Instance
	local ok, res = pcall(function()
		return InsertService:LoadAsset(id)
	end)
	assert(ok and res, ("LoadAsset %d (%s) failed: %s (HttpEnabled / asset permission?)"):format(id, what, tostring(res)))
	table.insert(loaded, res)
	return res
end
local function firstMesh(res: Instance, what: string): MeshPart
	local mp = res:FindFirstChildWhichIsA("MeshPart", true)
	assert(mp, what .. " has no MeshPart")
	return mp
end

local oldMesh = firstMesh(load(ID_OLD, "old AST-030"), "old AST-030")
local newRes = load(ID_NEW, NEW_NAME)
local tpl: { [string]: MeshPart } = {}
for name in STYLE do
	local p = newRes:FindFirstChild(name, true)
	assert(p and p:IsA("MeshPart"), ("%s missing in %s (re-upload?)"):format(name, NEW_NAME))
	tpl[name] = p
end
-- assembly bbox (axis aligned in the loaded model) must equal the old mesh: then the old CFrame is the assembly centre
local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
for _, p in tpl do
	local h = p.Size / 2
	lo = Vector3.new(math.min(lo.X, p.Position.X - h.X), math.min(lo.Y, p.Position.Y - h.Y), math.min(lo.Z, p.Position.Z - h.Z))
	hi = Vector3.new(math.max(hi.X, p.Position.X + h.X), math.max(hi.Y, p.Position.Y + h.Y), math.max(hi.Z, p.Position.Z + h.Z))
end
local center = (lo + hi) / 2
assert(((hi - lo) - oldMesh.Size).Magnitude < 0.06, ("new bbox %s differs from the old mesh %s"):format(fv(hi - lo), fv(oldMesh.Size)))
local rel: { [string]: CFrame } = {}
for name, p in tpl do
	rel[name] = CFrame.new(center):ToObjectSpace(p.CFrame)
end
local doorSide = if rel.Fridge_Doors.Position.Z - rel.Fridge_Body.Position.Z > 0 then 1 else -1
say("ref old %s, new bbox %s, doors on local %sZ", fv(oldMesh.Size), fv(hi - lo), if doorSide > 0 then "+" else "-")

local packTpl: { [string]: MeshPart } = {}
for name, id in PRODUCTS do
	packTpl[name] = firstMesh(load(id, "Pack" .. name), "Pack" .. name)
	say("ref pack %-12s size %s", name, fv(packTpl[name].Size))
end

ChangeHistoryService:SetWaypoint("fix_mart_fridge: before")

-- ---------------------------------------------------------------- 2. swap the old fridges
local function stripChildren(p: Instance)
	for _, c in p:GetChildren() do
		if not c:IsA("SurfaceAppearance") then
			c:Destroy()
		end
	end
end

local function swap(g: MeshPart): MeshPart
	local k = Vector3.new(g.Size.X / oldMesh.Size.X, g.Size.Y / oldMesh.Size.Y, g.Size.Z / oldMesh.Size.Z)
	local model = g.Parent
	local isModel = model ~= nil and model:IsA("Model")
	local holder: Instance
	local pivot = if isModel then model:GetPivot() else g.CFrame
	local wasPrimary = isModel and model.PrimaryPart == g
	if isModel then
		holder = model
	else
		holder = Instance.new("Model") -- the part was the placed instance itself: wrap it, same name / attributes / tags
		holder.Name = g.Name
		for key, value in g:GetAttributes() do
			holder:SetAttribute(key, value)
		end
		for _, tag in CollectionService:GetTags(g) do
			CollectionService:AddTag(holder, tag)
		end
		holder.Parent = g.Parent
	end
	local parts: { [string]: MeshPart } = {}
	for name, t in tpl do
		local n = t:Clone()
		stripChildren(n)
		n.Size = Vector3.new(t.Size.X * k.X, t.Size.Y * k.Y, t.Size.Z * k.Z)
		local r = rel[name]
		n.CFrame = g.CFrame * CFrame.new(r.Position * k) * r.Rotation
		for _, prop in COPY do
			pcall(function()
				n[prop] = g[prop]
			end)
		end
		if n.TextureID == "" then
			n.TextureID = if g.TextureID ~= "" then g.TextureID else MINIMARKET_TEXTURE
		end
		STYLE[name](n)
		parts[name] = n
	end
	local body = parts.Fridge_Body
	for key, value in g:GetAttributes() do
		body:SetAttribute(key, value)
	end
	for _, tag in CollectionService:GetTags(g) do
		CollectionService:AddTag(body, tag)
	end
	for _, c in g:GetChildren() do
		c.Parent = body
	end
	for _, d in holder:GetDescendants() do
		if d:IsA("WeldConstraint") or d:IsA("Weld") or d:IsA("ManualWeld") then
			if d.Part0 == g then
				d.Part0 = body
			end
			if d.Part1 == g then
				d.Part1 = body
			end
		end
	end
	for name, n in parts do
		n.Parent = holder
		if name ~= "Fridge_Body" and not g.Anchored then
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1, w.Parent = body, n, n
		end
	end
	g:Destroy()
	if wasPrimary or not isModel then
		holder.PrimaryPart = body
	end
	if holder.PrimaryPart ~= nil then
		body.PivotOffset = body.CFrame:ToObjectSpace(pivot)
	else
		holder.WorldPivot = pivot
	end
	holder.Name = (string.gsub(holder.Name, "AST%-030_FridgeDisplay$", NEW_NAME))
	if holder:GetAttribute("Asset") == "AST-030_FridgeDisplay" then
		holder:SetAttribute("Asset", NEW_NAME)
	end
	-- discreet inner light (no shadows) at the assembly centre
	local att = Instance.new("Attachment")
	att.Name = "Light_Inner"
	att.Position = -rel.Fridge_Body.Position * k
	att.Parent = body
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Shadows = Color3.fromRGB(232, 246, 238), 0.6, 9, false
	light.Parent = att
	return body
end

local fridges: { MeshPart } = {}
local swapped = 0
for _, d in workspace:GetDescendants() do
	if d:IsA("MeshPart") and not d:FindFirstAncestor("__AssetCache") then
		if d.Name == "Fridge_Body" then
			table.insert(fridges, d)
			say("fridge %s: already the Shelves asset", d:GetFullName())
		elseif d.MeshId == oldMesh.MeshId or d.Name == "AST-030_FridgeDisplay" then
			local n = swap(d)
			swapped += 1
			table.insert(fridges, n)
			say("fridge %s: closed cabinet -> Shelves asset, body centre %s", n:GetFullName(), fv(n.Position))
		end
	end
end
say("%d fridge(s) found, %d swapped", #fridges, swapped)

-- ---------------------------------------------------------------- 3. anchors -> fridge
local shelvesModel = workspace:FindFirstChild("MKT-SHELVES", true)
local assign: { [MeshPart]: string } = {}
local pairsList = {}
for name in PRODUCTS do
	local anchor = if shelvesModel then shelvesModel:FindFirstChild("BUY-" .. name) else nil
	if not (anchor and anchor:IsA("BasePart")) then
		say("product %-12s: anchor BUY-%s not found (run bind_map01 first), skipped", name, name)
	else
		for _, f in fridges do
			local d = Vector3.new(f.Position.X - anchor.Position.X, 0, f.Position.Z - anchor.Position.Z).Magnitude
			table.insert(pairsList, { name = name, fridge = f, d = d, anchor = anchor })
		end
	end
end
table.sort(pairsList, function(a, b)
	return a.d < b.d
end)
local taken: { [string]: boolean } = {}
for _, p in pairsList do
	if not taken[p.name] and not assign[p.fridge] then
		taken[p.name], assign[p.fridge] = true, p.name
		say("product %-12s -> fridge %s (anchor %s, %.1f studs away on the floor plane)", p.name, p.fridge.Parent.Name, fv(p.anchor.Position), p.d)
	end
end

-- ---------------------------------------------------------------- 4. packs
local function fill(body: MeshPart, folder: Folder, name: string): number
	local t = packTpl[name]
	local k = Vector3.new(body.Size.X / tpl.Fridge_Body.Size.X, body.Size.Y / tpl.Fridge_Body.Size.Y, body.Size.Z / tpl.Fridge_Body.Size.Z)
	local kk = (k.X + k.Y + k.Z) / 3
	local s = math.min(MAX_S, FIT_W / t.Size.X, FIT_D / t.Size.Z, FIT_H / t.Size.Y)
	local size = t.Size * s * kk
	local yaw = if doorSide > 0 then CFrame.Angles(0, math.pi, 0) else CFrame.identity -- label (local -Z) faces the glass
	local centreCF = body.CFrame * CFrame.new(-rel.Fridge_Body.Position * k) -- assembly centre in the world
	local count = 0
	for li, top in LEVELS do
		for _, bx in BAY_X do
			for ci, cx in CELL_X do
				for ri, ry in ROW_Y do
					local p = t:Clone()
					stripChildren(p)
					p.Name = ("ShelfPack_%s_%d_%d_%d"):format(name, li, if bx < 0 then 1 else 2, (ci - 1) * 2 + ri)
					p.Size = size
					local at = centreCF * CFrame.new((bx + cx) * k.X, (top - CENTER_Z) * k.Y, -doorSide * ry * k.Z) * yaw
					p.CFrame = at * CFrame.new(0, size.Y / 2 + 0.01, 0)
					p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
					p:SetAttribute("ShelfPack", name)
					p.Parent = folder
					count += 1
				end
			end
		end
	end
	local floorY = centreCF.Y - 3.5 * k.Y
	say("  %s: %d packs, scale %.2f (pack %s); level tops (world Y) %.2f / %.2f / %.2f; glass front centre %s", name, count, s * kk, fv(size),
		floorY + LEVELS[1] * k.Y, floorY + LEVELS[2] * k.Y, floorY + LEVELS[3] * k.Y,
		fv((centreCF * CFrame.new(0, 0, doorSide * 0.93 * k.Z)).Position))
	return count
end

local made = 0
for _, body in fridges do
	local holder = body.Parent
	local folder = holder:FindFirstChild("ShelfPacks")
	if folder and not FORCE then
		say("fridge %s: ShelfPacks already there, skipped (FORCE = true rebuilds)", holder:GetFullName())
	elseif not assign[body] then
		say("fridge %s: no BUY anchor assigned, no packs", holder:GetFullName())
	else
		if folder then
			folder:Destroy()
		end
		folder = Instance.new("Folder")
		folder.Name = "ShelfPacks"
		made += fill(body, folder, assign[body])
		folder.Parent = holder
	end
end

for _, l in loaded do
	l:Destroy()
end
ChangeHistoryService:SetWaypoint("fix_mart_fridge: after")
say("done: %d fridge(s) swapped, %d pack(s) placed. Save the place (Ctrl+S).", swapped, made)
return table.concat(report, "\n")
