--!nonstrict
--[[
	trailer_ground.luau (owner request 2026-10-12: "trailer flush with the ground, customers in the queue could not see the
	player's face through the window"; Provisional). Edit-mode Studio snippet, NOT gameplay code. Idempotent, surgical, NO
	Place.run, NOTHING is deleted: what leaves the model is MOVED to ServerStorage.Trailer_Backup_20261012 (attribute OrigPath).
	Undo: run it with the argument "undo" (run("trailer_ground", "undo")): the model goes back up and the parts back to the Body.

	Before: the AST-027 box stood on a chassis with two wheels and a tow arm; the trailer floor (Body.Floor) was at y 2.56 over
	the Pad (0.45), so the cook's eye sat ~2.1 studs above a customer's. After: the floor is DROP studs lower (0.48, a hair over
	the Pad so the floor mesh does not z-fight it), the counter top (2.6 over the floor) is at 3.08 and the window sill is level
	with a customer's chest.

	What it does (every step marked, so a second run changes nothing):
	  1. Body.Wheel_DoorSide, Body.Wheel_WindowSide, Body.Chassis (tow arm included) and Body.Steps (back step) -> backup.
	     Nothing else of the hitch / support exists in the model (checked 2026-10-12: Body children list).
	  2. The whole Vehicle Model PivotTo -DROP in Y (stations, counters, anchors, prompt attachments, Shutter_Panel / hinge,
	     Awning, lights, door, benches, shelves). Zone_Center (Thief zone centre) stays at its world height.
	  3. The MapPoints that sat at trailer level follow: TRL (= the pivot), PS-1..4, PS-N1..4, DROP-T, AN-05; LightZone LZ-1.
	     Q1..Q5 / CART / TRL-OUT / L3 / NpcNodes stand on the Pad and do not move.
	  4. The Body box now spans Y 0.08 .. 9.93 over the Pad top 0.45, so its lower edge is buried; only the two wheel arches
	     (a shallow notch in the valance on each long side) would show the dark inside, so each gets a thin skirt Part
	     (Skirt_Arch_Front / Skirt_Arch_Back, 2.8 x 0.5 x 0.3, y 0.45 .. 0.95, flush with the wall, valance colour, no collision).
	Run order: after trailer_only_map.luau (see STUDIO_LAYER.md), before trailer_only_lights.luau (re-reads the strip ends).
	Returns a log.
]]

local CS = game:GetService("CollectionService")
local ST = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")
local UNDO = (...) == "undo"

local DROP = 2.08 -- studs: Body.Floor 2.56 -> 0.48 (Pad top 0.45)
local BK_NAME = "Trailer_Backup_20261012"
local MARK = "TrailerGroundV1"
local REMOVE = { "Wheel_DoorSide", "Wheel_WindowSide", "Chassis", "Steps" }
local POINTS = { "TRL", "PS-1", "PS-2", "PS-3", "PS-4", "PS-N1", "PS-N2", "PS-N3", "PS-N4", "DROP-T", "AN-05" }
local ZONES = { "LZ-1" }
local SKIRT_COLOR = Color3.fromRGB(226, 221, 210) -- the light valance band of AST-027
local SKIRT_Y = 0.7 -- centre: Pad top 0.45 + half the height
local ZONE_CENTER_Y = 0.66 -- world height of Body.Zone_Center before and after (ThiefService reads flat distance only)

local log = {}
local function L(text)
	table.insert(log, text)
end
pcall(function()
	CHS:SetWaypoint("trailer_ground: before")
end)

local trailer
for _, m in CS:GetTagged("Vehicle") do
	if m:IsDescendantOf(workspace) and m:GetAttribute("Vehicle") == "trailer" then
		trailer = m
	end
end
if not trailer then
	return "[err] no Model tagged Vehicle with Vehicle = trailer in the Workspace"
end
local body = trailer:FindFirstChild("Body")
local binding = workspace:FindFirstChild("MapBinding")
local pts = binding and binding:FindFirstChild("Points")
local zones = binding and binding:FindFirstChild("LightZones")
if not (body and pts and zones) then
	return "[err] Body / MapBinding.Points / LightZones missing"
end
local bk = ST:FindFirstChild(BK_NAME)

local function shift(inst, dy, flag)
	-- one move per object: the attribute says "already lowered" (undo clears it)
	if (inst:GetAttribute(MARK) == true) == (dy < 0) then
		return false
	end
	inst.Position = inst.Position + Vector3.new(0, dy, 0)
	inst:SetAttribute(MARK, if dy < 0 then true else nil)
	return true
end

if UNDO then
	if bk then
		for _, part in bk:GetChildren() do
			if part:GetAttribute("OrigParent") == "Body" then
				part.Parent = body
				part:SetAttribute("OrigParent", nil)
				part:SetAttribute("OrigPath", nil)
				L("restored to the Body: " .. part.Name)
			end
		end
	end
	for _, n in { "Skirt_Arch_Front", "Skirt_Arch_Back" } do
		local s = trailer:FindFirstChild(n)
		if s then
			s:Destroy()
			L("skirt removed: " .. n)
		end
	end
	if trailer:GetAttribute(MARK) == true then
		trailer:PivotTo(trailer:GetPivot() + Vector3.new(0, DROP, 0))
		trailer:SetAttribute(MARK, nil)
		L("trailer raised by " .. DROP)
	end
	for _, id in POINTS do
		local p = pts:FindFirstChild(id)
		if p and shift(p, DROP) then
			L("point up: " .. id)
		end
	end
	for _, id in ZONES do
		local z = zones:FindFirstChild(id)
		if z and shift(z, DROP) then
			L("zone up: " .. id)
		end
	end
	local zc = body:FindFirstChild("Zone_Center")
	if zc then
		zc.WorldPosition = Vector3.new(zc.WorldPosition.X, ZONE_CENTER_Y, zc.WorldPosition.Z)
	end
	pcall(function()
		CHS:SetWaypoint("trailer_ground: undo")
	end)
	return table.concat(log, "\n")
end

-- 1. wheels, chassis (tow arm), steps -> backup
local arches = {} -- world (x, z) of each wheel, to put the skirt where the arch is
for _, name in REMOVE do
	local part = body:FindFirstChild(name)
	if part then
		if string.sub(name, 1, 6) == "Wheel_" then
			table.insert(arches, part.Position)
		end
		if not bk then
			bk = Instance.new("Folder")
			bk.Name = BK_NAME
			bk.Parent = ST
		end
		part:SetAttribute("OrigPath", part:GetFullName())
		part:SetAttribute("OrigParent", "Body")
		part.Parent = bk
		L("backup: " .. name)
	end
end

if #arches == 0 and bk then
	for _, part in bk:GetChildren() do
		if part:GetAttribute("OrigParent") == "Body" and string.sub(part.Name, 1, 6) == "Wheel_" then
			table.insert(arches, part.Position)
		end
	end
end

-- 2. lower the whole model
if trailer:GetAttribute(MARK) ~= true then
	trailer:PivotTo(trailer:GetPivot() - Vector3.new(0, DROP, 0))
	trailer:SetAttribute(MARK, true)
	L("trailer lowered by " .. DROP .. " (pivot y " .. string.format("%.2f", trailer:GetPivot().Position.Y) .. ")")
else
	L("trailer already lowered (attribute " .. MARK .. ")")
end
local zc = body:FindFirstChild("Zone_Center")
if zc then
	zc.WorldPosition = Vector3.new(zc.WorldPosition.X, ZONE_CENTER_Y, zc.WorldPosition.Z)
end

-- 3. points and zones that sat at trailer level
for _, id in POINTS do
	local p = pts:FindFirstChild(id)
	if not p then
		L("[warn] MapPoint " .. id .. " not found")
	elseif shift(p, -DROP) then
		L(string.format("point down: %s y %.2f", id, p.Position.Y))
	end
end
for _, id in ZONES do
	local z = zones:FindFirstChild(id)
	if z and shift(z, -DROP) then
		L(string.format("zone down: %s y %.2f", id, z.Position.Y))
	end
end
-- TRL must say what the pivot says (VehicleService:CheckPose warns otherwise)
local trl = pts:FindFirstChild("TRL")
if trl then
	local pv = trailer:GetPivot()
	trl.CFrame = pv
end
-- 4. skirts under the two arches (flush with the long walls: depth 6.0 from the pivot, Body 12.2 deep)
local pv = trailer:GetPivot()
for _, w in arches do
	local dir = if w.Z > pv.Position.Z then 1 else -1
	local name = if dir > 0 then "Skirt_Arch_Front" else "Skirt_Arch_Back"
	if not trailer:FindFirstChild(name) then
		local s = Instance.new("Part")
		s.Name = name
		s.Size = Vector3.new(2.8, 0.5, 0.3)
		s.CFrame = CFrame.new(w.X, SKIRT_Y, pv.Position.Z + dir * (6.0 - 0.15))
		s.Color = SKIRT_COLOR
		s.Material = Enum.Material.SmoothPlastic
		s.Anchored, s.CanCollide, s.CanTouch, s.CanQuery = true, false, false, false
		s.Parent = trailer
		L("skirt created: " .. name)
	end
end
pcall(function()
	CHS:SetWaypoint("trailer_ground: after")
end)
return table.concat(log, "\n")
