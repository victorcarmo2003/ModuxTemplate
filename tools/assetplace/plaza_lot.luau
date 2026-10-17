--!nonstrict
--[[
	plaza_lot.luau (2026-10-17, owner's decision: the empty Mart lot becomes a small PLAZA + PARKING LOT). Edit-mode Studio
	snippet, NOT gameplay code. No shop, no purchase point, no gameplay tag. NO Place.run.

	run("assetplace/plaza_lot", mode)
	  "dry"        report only (what exists, what would be built), writes nothing
	  nil/"apply"  builds / rewrites workspace.MAP01_PlazaLot (Folder, outside MAP01_Assets so a Place.run never wipes it)
	  "undo"       moves workspace.MAP01_PlazaLot to ServerStorage.PlazaLot_Undone (nothing destroyed)

	Idempotent: every piece is found by name and rewritten (2 runs = same instance count). WORLD coordinates (the lot is
	world X 61..104, Z 3.5..38; MAP = (-x, y, 67.887287 - z)). The Mart itself stays in ServerStorage.Mart (owner).
	Pack assets come from ServerStorage.__AssetCache (Kenney / KayKit families already uploaded): cars AST-035, bench /
	trees / planters / trash can AST-034, bushes AST-100 / AST-102, street light AST-036 (pole + head). The floor, paint
	lines, wheel stops, kiosk and P sign are Parts. Lights: 2 SpotLights, no shadow (style-guide §5.1: they reuse the
	2-3 lights of the Mart, which left the map).

	Layout (world):
	  plaza   X 61..74  : pavers (same tile texture as the restaurant patio), 4 benches, 2 trees, planters on the edge
	                      with a gap in front of the parking aisle, 2 trash cans, a closed kiosk (shutter down), 1 lamp
	  parking X 74..104 : asphalt; row A Z 3.5..17.5 (3 stalls of 10, cars nose north), aisle Z 17.5..24.5,
	                      row B Z 24.5..38 (3 stalls of 7.33, cars nose south), driveway X 96..104 to the sidewalk
	                      (Z 38) and the road; 5 parked cars, 1 lamp, "P" sign at the driveway
]]

local MODE = ... or "apply"
local DRY = MODE == "dry"
local UNDO = MODE == "undo"

local SS = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")
local ROOT = "MAP01_PlazaLot"
local CACHE = SS:FindFirstChild("__AssetCache")

local log = {}
local function L(s)
	table.insert(log, s)
end

if UNDO then
	local f = workspace:FindFirstChild(ROOT)
	if not f then
		return "undo: nothing to do"
	end
	local bk = SS:FindFirstChild("PlazaLot_Undone") or Instance.new("Folder")
	bk.Name = "PlazaLot_Undone"
	bk.Parent = SS
	local old = bk:FindFirstChild(ROOT)
	if old then
		old.Name = ROOT .. "_" .. os.time()
	end
	f.Parent = bk
	pcall(function()
		CHS:SetWaypoint("plaza_lot: undo")
	end)
	return "undo: workspace." .. ROOT .. " -> ServerStorage.PlazaLot_Undone"
end

if DRY then
	local f = workspace:FindFirstChild(ROOT)
	L("existing " .. ROOT .. ": " .. (if f then #f:GetDescendants() .. " instances" else "none"))
	L("asset cache: " .. tostring(CACHE ~= nil))
	local hits = 0
	for _, p in workspace:GetPartBoundsInBox(CFrame.new(82.5, 6, 20.75), Vector3.new(43, 11, 34.5)) do
		if not (f and p:IsDescendantOf(f)) and p.Transparency < 1 and p.Size.Magnitude < 200 then
			hits += 1
			L("occupied by " .. p:GetFullName())
		end
	end
	L("other parts in the lot: " .. hits)
	return table.concat(log, "\n")
end

-- colours / textures (same as restaurant_bind)
local PAVER = Color3.fromRGB(226, 220, 205)
local ASPHALT = Color3.fromRGB(74, 78, 88)
local PAINT = Color3.fromRGB(236, 236, 228)
local CONCRETE = Color3.fromRGB(190, 186, 178)
local TEAL = Color3.fromRGB(63, 167, 181)
local CREAM = Color3.fromRGB(255, 241, 214)
local KETCHUP = Color3.fromRGB(226, 64, 46)
local STEEL = Color3.fromRGB(201, 209, 216)
local STEEL_DARK = Color3.fromRGB(124, 135, 146)
local TEX_PAVE_LIGHT = "rbxassetid://119408403372428"
local SODIUM = Color3.fromRGB(255, 178, 90) -- style-guide §5.1 street lights

local Y0 = -0.3 -- city ground top
local PLAZA_TOP = 0.41
local LOT_TOP = 0.36
local PAINT_TOP = LOT_TOP + 0.02

local root = workspace:FindFirstChild(ROOT)
if not root then
	root = Instance.new("Folder")
	root.Name = ROOT
	root.Parent = workspace
end
root:SetAttribute("Note", "plaza + parking on the former Mart lot (owner 2026-10-17); tools/assetplace/plaza_lot.luau")

local function ensure(parent, name, class)
	local x = parent:FindFirstChild(name)
	if x and x.ClassName ~= class then
		x = nil
	end
	if not x then
		x = Instance.new(class)
		x.Name = name
		x.Parent = parent
	end
	return x
end
local function folder(parent, name)
	return ensure(parent, name, "Folder")
end
-- axis-aligned box from world bounds
local function box(parent, name, x0, x1, y0, y1, z0, z1, props)
	local p = ensure(parent, name, "Part")
	p.Anchored = true
	p.Shape = Enum.PartType.Block
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.CanTouch = false
	p.CanCollide = true
	p.CanQuery = true
	p.CastShadow = true
	p.Transparency = 0
	p.Size = Vector3.new(math.abs(x1 - x0), y1 - y0, math.abs(z1 - z0))
	p.CFrame = CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	for k, v in props or {} do
		p[k] = v
	end
	p:SetAttribute("PlazaLot", true)
	return p
end
local function face(pos, dir)
	return CFrame.lookAt(pos, pos + dir)
end
-- pack clone, base centre at pos, LookVector = dir; the bbox bottom is put on y
local function pack(parent, name, asset, x, y, z, dir)
	local m = parent:FindFirstChild(name)
	if not m then
		local tpl = CACHE and CACHE:FindFirstChild(asset)
		if not tpl then
			L("[warn] __AssetCache." .. asset .. " missing: " .. name .. " skipped")
			return nil
		end
		m = tpl:Clone()
		m.Name = name
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		m.Parent = parent
	end
	m:SetAttribute("Asset", asset)
	m:SetAttribute("PlazaLot", true)
	m:PivotTo(face(Vector3.new(x, y, z), dir))
	local cf, size = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + Vector3.new(x - cf.X, y - (cf.Y - size.Y / 2), z - cf.Z))
	return m
end
local function label(part, text, faceId, color, bg)
	local g = ensure(part, "Label", "SurfaceGui")
	g.Face = faceId
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 200 -- owner 2026-10-17: sharper signs (was 50)
	g.LightInfluence = 0.6
	local t = ensure(g, "Text", "TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = if bg then 0 else 1
	t.BackgroundColor3 = bg or Color3.new(1, 1, 1)
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = color
	return g
end

local N, S, E, W = Vector3.new(0, 0, -1), Vector3.new(0, 0, 1), Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0) -- world

-- 1. floors -------------------------------------------------------------------------------------------------------------
local ground = folder(root, "Ground")
local plaza = box(ground, "Plaza_Pavers", 61, 74, Y0 - 0.2, PLAZA_TOP, 3.5, 38, { Color = PAVER })
local tex = ensure(plaza, "Tex_Tile", "Texture")
tex.Texture = TEX_PAVE_LIGHT
tex.Face = Enum.NormalId.Top
tex.StudsPerTileU = 4
tex.StudsPerTileV = 4
tex.Color3 = Color3.fromRGB(236, 232, 222)
box(ground, "Lot_Asphalt", 74, 104, Y0 - 0.2, LOT_TOP, 3.5, 38, { Color = ASPHALT, Material = Enum.Material.Asphalt })
-- curb between the plaza and the lot (0.05 over the pavers, with a walking gap in front of the aisle)
box(ground, "Curb_N", 73.8, 74.2, LOT_TOP - 0.1, PLAZA_TOP + 0.05, 3.55, 17.5, { Color = CONCRETE, Material = Enum.Material.Concrete })
box(ground, "Curb_S", 73.8, 74.2, LOT_TOP - 0.1, PLAZA_TOP + 0.05, 24.5, 37.95, { Color = CONCRETE, Material = Enum.Material.Concrete })

-- 2. parking paint, wheel stops, cars ----------------------------------------------------------------------------------------
local park = folder(root, "Parking")
local lines = folder(park, "Lines")
local function paint(name, x0, x1, z0, z1, color)
	return box(lines, name, x0, x1, LOT_TOP - 0.05, PAINT_TOP, z0, z1, { Color = color or PAINT, CanCollide = false, CanQuery = false, CastShadow = false })
end
-- row A: stall dividers at X 74.6 / 84 / 94 / 103.4, Z 4.5..17.2
for i, x in { 74.6, 84, 94, 103.4 } do
	paint("A_Line" .. i, x - 0.125, x + 0.125, 4.5, 17.2)
end
-- row B: dividers at X 74.6 / 81.73 / 88.87 / 96, Z 24.8..37.4
for i, x in { 74.6, 81.73, 88.87, 96 } do
	paint("B_Line" .. i, x - 0.125, x + 0.125, 24.8, 37.4)
end
-- aisle centre dashes and the driveway arrow (block arrow: shaft + head)
for i = 0, 5 do
	local x0 = 76 + i * 4.6
	paint("Aisle_Dash" .. (i + 1), x0, x0 + 2.2, 20.9, 21.1)
end
paint("Arrow_Shaft", 99.6, 100.4, 28, 33.5)
paint("Arrow_Head_A", 98.7, 101.3, 33.5, 34.2)
paint("Arrow_Head_B", 99.3, 100.7, 34.2, 34.9)
-- row A stall 3 stays free with a teal stripe (staff stall); no real-world signage symbols
paint("A3_Staff", 95, 102.4, 16.2, 16.8, TEAL)
-- wheel stops (concrete, 0.3 high)
local stops = folder(park, "WheelStops")
for i, xc in { 79.3, 89, 98.7 } do
	box(stops, "Stop_A" .. i, xc - 2.2, xc + 2.2, LOT_TOP, LOT_TOP + 0.3, 4.6, 5.2, { Color = CONCRETE, Material = Enum.Material.Concrete })
end
for i, xc in { 78.17, 85.3, 92.43 } do
	box(stops, "Stop_B" .. i, xc - 2.2, xc + 2.2, LOT_TOP, LOT_TOP + 0.3, 36.8, 37.4, { Color = CONCRETE, Material = Enum.Material.Concrete })
end
-- 5 parked cars (row A stall 3 stays free: the staff stall)
local cars = folder(park, "Cars")
pack(cars, "Car_A1_Sedan", "AST-035_CarSedan", 79.3, LOT_TOP, 11.6, N)
pack(cars, "Car_A2_Pickup", "AST-035_CarPickup", 89, LOT_TOP, 12.4, N)
pack(cars, "Car_B1_Van", "AST-035_CarVan", 78.17, LOT_TOP, 30.1, S)
pack(cars, "Car_B2_Hatch", "AST-035_CarHatch", 85.3, LOT_TOP, 29.9, S)
pack(cars, "Car_B3_Sedan", "AST-035_CarSedan", 92.43, LOT_TOP, 30.6, S)
for _, c in cars:GetChildren() do
	for _, d in c:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = true
			d.CanTouch = false
		end
	end
end

-- 3. plaza furniture -------------------------------------------------------------------------------------------------------
local pz = folder(root, "Plaza")
pack(pz, "Tree_Large", "AST-034_TreeLarge", 66.5, PLAZA_TOP, 8.5, S)
pack(pz, "Tree_Small", "AST-034_TreeSmall", 66.5, PLAZA_TOP, 27, S)
pack(pz, "Bush_1", "AST-102_Bush", 70.2, PLAZA_TOP, 4.6, S)
pack(pz, "Bush_2", "AST-102_BushLarge", 62.4, PLAZA_TOP, 35.6, S)
-- benches: two facing east on the west edge, two facing west in the middle, around the trees
pack(pz, "Bench_1", "AST-034_ParkBench", 62.4, PLAZA_TOP, 14, E)
pack(pz, "Bench_2", "AST-034_ParkBench", 62.4, PLAZA_TOP, 21, E)
pack(pz, "Bench_3", "AST-034_ParkBench", 70.2, PLAZA_TOP, 9, W)
pack(pz, "Bench_4", "AST-034_ParkBench", 70.2, PLAZA_TOP, 27.5, W)
-- planters on the curb line, gap in front of the aisle (Z 17.5..24.5)
for i, z in { 6, 11, 15.6 } do
	pack(pz, "Planter_N" .. i, "AST-100_PlanterBushes", 72.9, PLAZA_TOP, z, W)
end
for i, z in { 26.4, 31, 35.6 } do
	pack(pz, "Planter_S" .. i, "AST-100_PlanterBushes", 72.9, PLAZA_TOP, z, W)
end
pack(pz, "Planter_Box_1", "AST-034_Planter", 66.5, PLAZA_TOP, 17.2, S)
pack(pz, "Trash_1", "AST-034_TrashCan", 62.3, PLAZA_TOP, 17.5, E)
pack(pz, "Trash_2", "AST-034_TrashCan", 72.6, PLAZA_TOP, 23.3, W)

-- closed kiosk (no shop: shutter down, no prompt), Parts: body, roof, shutter with slats, counter lip, sign
do
	local k = ensure(pz, "Kiosk_Closed", "Model")
	k:SetAttribute("PlazaLot", true)
	k:SetAttribute("Note", "decor only, always closed (owner: no shop on the lot)")
	local x0, x1, z0, z1 = 64.8, 69.8, 30.8, 35.3
	box(k, "Body", x0, x1, PLAZA_TOP + 0.1, PLAZA_TOP + 6.2, z0, z1, { Color = CREAM }) -- bottom inside the base (no coplanar floor face)
	box(k, "Roof", x0 - 0.6, x1 + 0.6, PLAZA_TOP + 6.2, PLAZA_TOP + 6.6, z0 - 0.9, z1 + 0.6, { Color = KETCHUP })
	box(k, "Base", x0 - 0.1, x1 + 0.1, PLAZA_TOP, PLAZA_TOP + 0.5, z0 - 0.1, z1 + 0.1, { Color = STEEL_DARK, Material = Enum.Material.Metal })
	-- shutter on the north face (toward the plaza centre), 0.08 proud of the body
	box(k, "Shutter", x0 + 0.4, x1 - 0.4, PLAZA_TOP + 1.6, PLAZA_TOP + 5.0, z0 - 0.08, z0, { Color = STEEL, Material = Enum.Material.DiamondPlate, CanCollide = false })
	for i = 1, 4 do
		local y = PLAZA_TOP + 1.6 + i * 0.68
		box(k, "Slat" .. i, x0 + 0.45, x1 - 0.45, y - 0.04, y + 0.04, z0 - 0.12, z0 - 0.08, { Color = STEEL_DARK, Material = Enum.Material.Metal, CanCollide = false, CanQuery = false })
	end
	box(k, "Counter", x0 + 0.2, x1 - 0.2, PLAZA_TOP + 1.42, PLAZA_TOP + 1.6, z0 - 0.5, z0, { Color = STEEL_DARK, Material = Enum.Material.Metal })
	local sign = box(k, "Sign", x0 + 0.5, x1 - 0.5, PLAZA_TOP + 5.25, PLAZA_TOP + 6.05, z0 - 0.14, z0 - 0.04, { Color = TEAL, CanCollide = false, CanQuery = false })
	label(sign, "CLOSED", Enum.NormalId.Front, CREAM) -- north face = world -Z = Front
end

-- "P" sign at the driveway (post + panel)
do
	local s = ensure(park, "Sign_P", "Model")
	s:SetAttribute("PlazaLot", true)
	box(s, "Post", 102.9, 103.1, LOT_TOP, LOT_TOP + 6.2, 37.1, 37.3, { Color = STEEL_DARK, Material = Enum.Material.Metal })
	local panel = box(s, "Panel", 102, 104, LOT_TOP + 4.4, LOT_TOP + 6.4, 37.32, 37.42, { Color = TEAL, CanCollide = false })
	label(panel, "P", Enum.NormalId.Back, CREAM) -- faces the road (world +Z)
end

-- 4. lamps (AST-036 pole + head; foot F, arm direction d: pole bbox centre = F + 1.815 d, head pivot = F)
local lamps = folder(root, "Lamps")
local function lamp(name, fx, fy, fz, d)
	local m = ensure(lamps, name, "Model")
	m:SetAttribute("PlazaLot", true)
	local rot = CFrame.lookAt(Vector3.zero, -d) -- local +Z = d
	local pole = m:FindFirstChild("Pole")
	if not pole then
		local tpl = CACHE and CACHE:FindFirstChild("AST-036_StreetLightCurved")
		pole = tpl and tpl:Clone()
		if pole then
			pole.Name = "Pole"
			pole.Parent = m
		end
	end
	local head = m:FindFirstChild("Head")
	if not head then
		local tpl = CACHE and CACHE:FindFirstChild("AST-036_LampHead")
		head = tpl and tpl:Clone()
		if head then
			head.Name = "Head"
			head.Parent = m
		end
	end
	if not (pole and head) then
		L("[warn] AST-036 pieces missing in __AssetCache: " .. name)
		return
	end
	for _, d2 in m:GetDescendants() do
		if d2:IsA("BasePart") then
			d2.Anchored = true
		end
	end
	local F = Vector3.new(fx, fy, fz)
	pole:PivotTo(rot + F)
	local cf, size = pole:GetBoundingBox()
	local want = F + d * 1.815 + Vector3.new(0, size.Y / 2, 0)
	pole:PivotTo(pole:GetPivot() + (want - cf.Position))
	head:PivotTo(rot + F)
	-- the light hangs under the dome (local z 2.63..4.63 from the foot, y 13.0)
	local bulb = box(m, "Bulb", 0, 0.6, 0, 0.2, 0, 0.6, { Color = Color3.fromRGB(255, 214, 160), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CastShadow = false })
	bulb.CFrame = (rot + F) * CFrame.new(0, 12.85, 3.63)
	local light = ensure(bulb, "Light", "SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = 18
	light.Angle = 100
	light.Brightness = 1.6
	light.Color = SODIUM
	light.Shadows = false
	m:SetAttribute("Decor", true)
end
lamp("Lamp_Plaza", 62.0, PLAZA_TOP, 4.6, E)
lamp("Lamp_Lot", 103.4, LOT_TOP, 21, W)

-- 5. report -------------------------------------------------------------------------------------------------------------
local nParts, nLights = 0, 0
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then
		nParts += 1
	elseif d:IsA("Light") then
		nLights += 1
	end
end
L(string.format("%s: %d instances, %d parts, %d lights", ROOT, #root:GetDescendants(), nParts, nLights))
pcall(function()
	CHS:SetWaypoint("plaza_lot: after")
end)
return table.concat(log, "\n")
