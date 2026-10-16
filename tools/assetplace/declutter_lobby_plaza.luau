--!nonstrict
--[[
	declutter_lobby_plaza.luau (owner request 2026-10-12: "the central pillar blocks the plaza, string lights cross the sky").
	Edit-mode Studio snippet, NOT gameplay code. Idempotent, surgical, NO Place.run, NOTHING is deleted: removed pieces are
	MOVED to ServerStorage.LOBBY_Backup_20261012 (attribute OrigFolder = where they came from). `UNDO = true` puts it all back.

	What it does (world coords, the lobby is x1.3 around the spawn (5, 0, -620)):
	  1. Mast pole / planter / soil / bush (LB-MAST-BUSH) and the 334 radial Wire + Bulb parts -> backup.
	  2. Floor emblem at (5, 0, -631), height <= 0.18, CanCollide false: the old Mast_Ring (flat mustard disc), a new INK disc,
	     and a flattened clone of one Mast_Topper hot dog (Floor_HotDogEmblem).
	  3. The two Mast_Topper neon hot dogs (back to back) become a low portico on top of Start_Board ("START SHIFT"), x 62.65,
	     z -620, facing plaza (-X) and street (+X), plus 2 small INK struts.
	  4. New string lights: 5 low spans between the perimeter street lights only (C-H, H-A, A-B, B-G, F-E), parabola sag,
	     Wire + Bulb clones of the originals (same colours / neon material), folder LobbyProcedural.LobbyDeclutter_V1.
	Not touched: floor, zones, MapPoint, SpawnLocation, PartyPlatform, lights (still 17), colliders other than the pole/planter/bush.
]]

local UNDO = false

local CHS = game:GetService("ChangeHistoryService")
local ST = game:GetService("ServerStorage")
local BK_NAME = "LOBBY_Backup_20261012"
local DECL = "LobbyDeclutter_V1"
local lobby = workspace:FindFirstChild("LOBBY_Assets")
if not lobby then
	return "[err] no LOBBY_Assets"
end
local proc = lobby.LobbyProcedural
local decor = lobby:FindFirstChild("LobbyDecor", true) :: Folder -- nested in Plaza since the 2026-10-16 regroup
local log = {}
pcall(function()
	CHS:SetWaypoint("declutter_lobby_plaza: before")
end)

local function folderByName(n)
	return if n == "LobbyDecor" then decor else proc
end

if UNDO then
	local bk = ST:FindFirstChild(BK_NAME)
	local n = 0
	if bk then
		for _, c in bk:GetChildren() do
			local p = folderByName(c:GetAttribute("OrigFolder"))
			local cf, sz, sc = c:GetAttribute("OrigCF"), c:GetAttribute("OrigSize"), c:GetAttribute("OrigScale")
			c.Parent = p
			if c:IsA("Model") and sc then
				c:ScaleTo(sc)
			end
			if cf then
				if c:IsA("Model") then
					c:PivotTo(cf)
				else
					c.CFrame = cf
				end
			end
			if sz then
				c.Size = sz
			end
			n += 1
		end
		bk:Destroy()
	end
	-- pieces that were reused in place (ring + the two hot dog neons): back to the original pose
	for _, c in proc:GetChildren() do
		local cf = c:GetAttribute("OrigCF")
		if cf and c.Parent == proc then
			local sz, sc = c:GetAttribute("OrigSize"), c:GetAttribute("OrigScale")
			if c:IsA("Model") then
				if sc then
					c:ScaleTo(sc)
				end
				c:PivotTo(cf)
			else
				c.Size = sz
				c.CFrame = cf
				c.CanCollide = false
			end
			n += 1
		end
	end
	local d = proc:FindFirstChild(DECL)
	if d then
		d:Destroy()
	end
	pcall(function()
		CHS:SetWaypoint("declutter_lobby_plaza: after UNDO")
	end)
	return ("UNDO: restored %d pieces, removed %s"):format(n, DECL)
end

if proc:FindFirstChild(DECL) then
	return "already applied (use UNDO = true to revert)"
end

local pole, planter, soil, ring = proc:FindFirstChild("Mast_Pole"), proc:FindFirstChild("Mast_Planter"), proc:FindFirstChild("Mast_Soil"), proc:FindFirstChild("Mast_Ring")
local bush = decor:FindFirstChild("LB-MAST-BUSH_AST-102_Bush")
local board = proc:FindFirstChild("Start_Board")
local toppers = {}
for _, c in proc:GetChildren() do
	if c.Name == "Mast_Topper" and c:IsA("Model") then
		table.insert(toppers, c)
	end
end
if not (pole and planter and ring and board and #toppers == 2) then
	return "[err] mast pieces not found (already moved by hand?)"
end
table.sort(toppers, function(a, b)
	return a:GetPivot().Position.Z > b:GetPivot().Position.Z -- A = larger Z = faces +Z originally
end)
local topA, topB = toppers[1], toppers[2]

-- templates (cloned BEFORE anything is moved)
local wireT
local bulbTs, seen = {}, {}
for _, c in proc:GetChildren() do
	if c.Name == "Wire" and not wireT then
		wireT = c:Clone()
	elseif c.Name == "Bulb" and c:IsA("BasePart") then
		local k = tostring(c.Color)
		if not seen[k] then
			seen[k] = true
			table.insert(bulbTs, c:Clone())
		end
	end
end
if not wireT or #bulbTs == 0 then
	return "[err] no Wire/Bulb templates"
end
local floorHD = topA:Clone()

local bk = Instance.new("Folder")
bk.Name = BK_NAME
bk.Parent = ST
local function stash(inst, folderName)
	inst:SetAttribute("OrigFolder", folderName)
	inst.Parent = bk
end

-- 1. old mast + radial string lights -> backup
local moved = 0
for _, p in { pole, planter, soil } do
	if p then
		stash(p, "LobbyProcedural")
		moved += 1
	end
end
if bush then
	stash(bush, "LobbyDecor")
	moved += 1
end
local wb = 0
for _, c in proc:GetChildren() do
	if (c.Name == "Wire" or c.Name == "Bulb") and c:IsA("BasePart") then
		stash(c, "LobbyProcedural")
		wb += 1
	end
end
table.insert(log, ("moved to backup: %d mast pieces + %d wires/bulbs"):format(moved, wb))

local folder = Instance.new("Folder")
folder.Name = DECL
folder.Parent = proc

local INK = wireT.Color
local function flat(name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = folder
	return p
end

-- 2. floor emblem (center of the plaza where the pillar stood)
local EC = Vector3.new(5, 0, -631)
ring:SetAttribute("OrigFolder", "LobbyProcedural")
ring:SetAttribute("OrigCF", ring.CFrame)
ring:SetAttribute("OrigSize", ring.Size)
ring.Size = Vector3.new(0.08, 6.6, 6.6)
ring.CFrame = CFrame.new(EC.X, 0.06, EC.Z) * CFrame.Angles(0, 0, math.pi / 2) -- cylinder axis (X) -> vertical
ring.CanCollide = false
ring.CanQuery = false
ring.CastShadow = false
local disc = flat("Emblem_Disc", Vector3.new(0.04, 5.9, 5.9), CFrame.new(EC.X, 0.12, EC.Z) * CFrame.Angles(0, 0, math.pi / 2), INK, Enum.Material.SmoothPlastic)
disc.Shape = Enum.PartType.Cylinder
floorHD.Name = "Floor_HotDogEmblem"
floorHD:SetAttribute("Flicker", false)
floorHD:ScaleTo(1.1)
for _, d in floorHD:GetDescendants() do
	if d:IsA("BasePart") then
		d.Size = Vector3.new(d.Size.X, d.Size.Y, 0.04) -- flatten along the (future vertical) depth axis
		d.CanCollide = false
		d.CanQuery = false
		d.CastShadow = false
	end
end
floorHD:PivotTo(CFrame.new(EC.X, 0.16, EC.Z) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(-math.pi / 2, 0, 0))
floorHD.Parent = folder
table.insert(log, "floor emblem built at (5, -631): ring + ink disc + flat hot dog (top <= 0.18, CanCollide false)")

-- 3. portico on the START SHIFT board
for _, t in { topA, topB } do
	t:SetAttribute("OrigFolder", "LobbyProcedural")
	t:SetAttribute("OrigCF", t:GetPivot())
	t:SetAttribute("OrigScale", t:GetScale())
end
local bx, bz = board.Position.X, board.Position.Z
local top = board.Position.Y + board.Size.Y / 2
topA:ScaleTo(1.7)
topB:ScaleTo(1.7)
local cy = top + 2.5
topA:PivotTo(CFrame.new(bx - 0.2, cy, bz) * CFrame.Angles(0, -math.pi / 2, 0)) -- reads from the plaza (-X)
topB:PivotTo(CFrame.new(bx + 0.2, cy, bz) * CFrame.Angles(0, math.pi / 2, 0)) -- reads from the street (+X)
for _, t in { topA, topB } do
	t:SetAttribute("OrigParentNote", "moved from the mast top to Start_Board")
end
topA.Parent = proc
topB.Parent = proc
for _, dz in { -1.2, 1.2 } do
	flat("Portico_Strut", Vector3.new(0.3, 1.2, 0.3), CFrame.new(bx, top + 0.6, bz + dz), INK, Enum.Material.SmoothPlastic)
end
table.insert(log, ("portico: hot dog neon on Start_Board (x %.1f, y %.1f, z %.1f)"):format(bx, cy, bz))

-- 4. string lights: perimeter poles only
local FOOT = {
	A = Vector3.new(-69.1, 0, -686.3),
	B = Vector3.new(55.7, 0, -686.3),
	C = Vector3.new(-69.1, 0, -594),
	E = Vector3.new(23.2, 0, -553.7),
	F = Vector3.new(55.7, 0, -596.6),
	G = Vector3.new(55.7, 0, -643.4),
	H = Vector3.new(-69.1, 0, -646),
}
local ATTACH_Y = 16.2
local SPANS = { { "C", "H", 2.6 }, { "H", "A", 2.6 }, { "A", "B", 4.2 }, { "B", "G", 2.6 }, { "F", "E", 2.8 } }
local colorIdx = 0
local nWire, nBulb, minY = 0, 0, 1e9
for _, s in SPANS do
	local a, b, sag = FOOT[s[1]], FOOT[s[2]], s[3]
	local len = (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
	local n = math.max(2, math.ceil(len / 3.4))
	local pts = {}
	for i = 0, n do
		local t = i / n
		local y = ATTACH_Y - sag * 4 * t * (1 - t)
		pts[i] = Vector3.new(a.X + (b.X - a.X) * t, y, a.Z + (b.Z - a.Z) * t)
		minY = math.min(minY, y)
	end
	for i = 0, n - 1 do
		local p0, p1 = pts[i], pts[i + 1]
		local w = wireT:Clone()
		w.Size = Vector3.new(0.1, 0.1, (p1 - p0).Magnitude + 0.02)
		w.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
		w.Parent = folder
		nWire += 1
	end
	for i = 1, n - 1 do
		colorIdx += 1
		local bu = bulbTs[(colorIdx - 1) % #bulbTs + 1]:Clone()
		bu.CFrame = CFrame.new(pts[i] - Vector3.new(0, 0.3, 0))
		bu.Parent = folder
		nBulb += 1
	end
end
table.insert(log, ("new string lights: %d spans, %d wires, %d bulbs, lowest wire y %.1f"):format(#SPANS, nWire, nBulb, minY))

local lights = 0
for _, d in lobby:GetDescendants() do
	if d:IsA("Light") and d.Enabled then
		lights += 1
	end
end
table.insert(log, ("local lights: %d (max 18)"):format(lights))
wireT:Destroy()
for _, t in bulbTs do
	t:Destroy()
end
pcall(function()
	CHS:SetWaypoint("declutter_lobby_plaza: after")
end)
return table.concat(log, "\n")
