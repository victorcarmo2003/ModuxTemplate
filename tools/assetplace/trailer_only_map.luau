--!nonstrict
--[[
	trailer_only_map.luau (owner decision 2026-10-12: "migrate everything to the trailer"; Provisional).
	Edit-mode Studio snippet, NOT gameplay code. Idempotent, surgical, NO Place.run, NOTHING is deleted: what leaves the
	run is MOVED to ServerStorage.CART_Backup_20261012 (attribute OrigPath = where it came from, OrigTags = its tags;
	the tags are removed in the backup so no service scans a ghost). The owner's own ServerStorage."CARRINHO BACKUP" is
	left where it is (only neutralised the same way).

	The Food Trailer is the ONLY vehicle. Everything below is derived from the trailer's CURRENT pivot (the owner put it
	on the Pad: -44.92, 0.56, 9.10, turned 180 degrees, window facing world +Z); only if the model is still parked in the
	old sale lot (pivot Z > 60) it is moved to DEFAULT_POSE first.

	What it does:
	  1. Backup: MAP01_Blockout.Pad.CART, MAP01_Blockout.Trailer.TRL-SALE / SIGN-T, MapPoints TRL-SALE and SIGN-T, and the
	     buy_trailer anchor (Prompt_Buy) of the trailer.
	  2. MapPoints in the trailer frame: TRL = the pivot, CART (legacy name, kept for the cutscene / customers: the service
	     window front), Q1..Q5 (queue in front of the window, 3.4 studs from the drawer / counter edge), PS-1..4 = PS-N1..4
	     (inside, on the floor), DROP-T, AN-05, L3 (thief lurk moved out of the trailer to the east side), new TRL-OUT
	     (Exit Trailer landing on the west strip). LightZones LZ-1 / LZ-2 / LZ-3 follow the trailer.
	  3. NpcNodes: new N-PAD-1..3 (gate, row behind the tables, west exit) and TBL-1..4 (one behind each table); the Q chain
	     now enters / leaves through them (Q5 <-> N-PAD-2, Q1 <-> N-PAD-3); the thief lurk L3 links N-PAD-2 and N-Z01-04
	     (moved east of the trailer). N-Z01-02 / N-Z01-03 (old Pad west corner, through where table 1 stands) go to backup.
	  4. Tables: the 4 SeatTable Models of the Workspace are renumbered TableIndex 1..4 by X (west end = 1 = nearest to Q1),
	     MapId TTBL-n, TableGroup "Trailer". The copies in the backups lose their tags.
	  5. Queue marks Qn_AST-019_QueueMark move to the Q points.
	Run order: after a Place.run + Bind.run (see STUDIO_LAYER.md), or any time (idempotent). Returns a log.
]]

local CS = game:GetService("CollectionService")
local ST = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")
local BK_NAME = "CART_Backup_20261012"
local DEFAULT_POSE = CFrame.new(-44.9233, 0.56, 9.0997) * CFrame.Angles(0, math.pi, 0)
local TAGS_OFF = {
	"Vehicle", "VehicleCover", "Station", "Interactable", "SeatTable", "NpcNode", "MapPoint", "UpgradePiece",
	"LightZone", "AnomalyAnchor", "OpenSignBoard",
}
local log = {}
local function L(text)
	table.insert(log, text)
end
pcall(function()
	CHS:SetWaypoint("trailer_only_map: before")
end)

local function backupFolder()
	local f = ST:FindFirstChild(BK_NAME)
	if not f then
		f = Instance.new("Folder")
		f.Name = BK_NAME
		f.Parent = ST
	end
	return f
end

-- tags off in the whole subtree (recorded), so no service scans a ghost of the cart
local function strip(inst)
	local tags = CS:GetTags(inst)
	local n = 0
	for _, tag in tags do
		if table.find(TAGS_OFF, tag) then
			n += 1
		end
	end
	if n > 0 then
		if inst:GetAttribute("OrigTags") == nil then
			inst:SetAttribute("OrigTags", table.concat(tags, ","))
		end
		for _, tag in tags do
			if table.find(TAGS_OFF, tag) then
				CS:RemoveTag(inst, tag)
			end
		end
	end
	return n
end
local function neutralize(root)
	local n = strip(root)
	for _, inst in root:GetDescendants() do
		n += strip(inst)
	end
	return n
end

local function toBackup(inst, why)
	if not inst or not inst.Parent or inst:IsDescendantOf(ST) then
		return false
	end
	inst:SetAttribute("OrigPath", inst:GetFullName())
	neutralize(inst)
	inst.Parent = backupFolder()
	L("backup: " .. inst.Name .. " (" .. why .. ")")
	return true
end

local pts = workspace:FindFirstChild("MapBinding") and workspace.MapBinding:FindFirstChild("Points")
local nodesFolder = workspace.MapBinding:FindFirstChild("Nodes")
local zones = workspace.MapBinding:FindFirstChild("LightZones")
if not (pts and nodesFolder and zones) then
	return "[err] MapBinding.Points / Nodes / LightZones missing"
end

-- 0. the trailer -------------------------------------------------------------------------------------------------------
local trailer
for _, m in CS:GetTagged("Vehicle") do
	if m:IsDescendantOf(workspace) and m:GetAttribute("Vehicle") == "trailer" then
		trailer = m
	end
end
if not trailer then
	return "[err] no Model tagged Vehicle with Vehicle = trailer in the Workspace"
end
if trailer:GetPivot().Position.Z > 60 then
	trailer:PivotTo(DEFAULT_POSE)
	L("trailer moved from the sale lot to DEFAULT_POSE")
end
local PIVOT = trailer:GetPivot()
local FRONT = PIVOT.LookVector -- the window side (world +Z)
-- trailer frame: x = lx along PIVOT.RightVector * -1 ... use W(lx, y, lz) = pivot * (lx, 0, lz), y absolute
local function W(lx, y, lz)
	local v = PIVOT:PointToWorldSpace(Vector3.new(lx, 0, lz))
	return Vector3.new(v.X, y, v.Z)
end
local function face(pos, dir)
	return CFrame.lookAt(pos, pos + dir)
end
local FLOOR = 2.6 -- trailer floor (Body.Floor top)
local GROUND = 0.45

-- 1. backups -----------------------------------------------------------------------------------------------------------
local blockout = workspace:FindFirstChild("MAP01_Blockout")
if blockout then
	local function underBlockout(name)
		for _, d in blockout:GetDescendants() do
			if d.Name == name and (d:IsA("Model") or d:IsA("Folder")) then
				return d
			end
		end
	end
	for _, n in { "CART", "TRL-SALE", "SIGN-T" } do
		toBackup(underBlockout(n), "blockout, the cart / sale lot left the run")
	end
end
for _, n in { "TRL-SALE", "SIGN-T" } do
	toBackup(pts:FindFirstChild(n), "MapPoint obsolete (no sale, no sign)")
end
for _, d in trailer:GetDescendants() do
	if d:IsA("Attachment") and d:GetAttribute("PromptAction") == "buy_trailer" then
		toBackup(d, "buy_trailer prompt of the trailer")
		break
	end
end
local owner = ST:FindFirstChild("CARRINHO BACKUP")
if owner then
	local n = neutralize(owner)
	if n > 0 then
		L("CARRINHO BACKUP neutralised: " .. n .. " tags off (OrigTags kept)")
	end
end
local bk = ST:FindFirstChild(BK_NAME)
if bk then
	neutralize(bk)
end

-- helpers for points and nodes -------------------------------------------------------------------------------------------
local function point(id)
	return pts:FindFirstChild(id)
end
local function setPoint(id, cf)
	local p = point(id)
	if not p then
		L("[warn] MapPoint " .. id .. " not found")
		return
	end
	p.CFrame = cf
end
local function nodePart(id)
	return nodesFolder:FindFirstChild(id) or pts:FindFirstChild(id)
end
local function linksOf(part)
	local t = {}
	for id in string.gmatch(tostring(part:GetAttribute("Links") or ""), "[^,]+") do
		table.insert(t, id)
	end
	return t
end
local function setLinks(part, list)
	part:SetAttribute("Links", table.concat(list, ","))
end
local function addLink(a, b)
	local pa, pb = nodePart(a), nodePart(b)
	if not (pa and pb) then
		L("[warn] link " .. a .. " <-> " .. b .. ": node missing")
		return
	end
	for _, pair in { { pa, b }, { pb, a } } do
		local list = linksOf(pair[1])
		if not table.find(list, pair[2]) then
			table.insert(list, pair[2])
			setLinks(pair[1], list)
		end
	end
end
local function dropLink(a, b)
	for _, pair in { { a, b }, { b, a } } do
		local part = nodePart(pair[1])
		if part then
			local list = linksOf(part)
			local at = table.find(list, pair[2])
			if at then
				table.remove(list, at)
				setLinks(part, list)
			end
		end
	end
end
local template = nodesFolder:FindFirstChild("N-Z02-05")
local function ensureNode(id, pos)
	local part = nodesFolder:FindFirstChild(id)
	if not part then
		part = template:Clone()
		part.Name = id
		part:SetAttribute("NodeId", id)
		part:SetAttribute("Links", "")
		part.Parent = nodesFolder
		L("node created: " .. id)
	end
	part.CFrame = CFrame.new(pos)
	return part
end

-- 2. MapPoints in the trailer frame --------------------------------------------------------------------------------------
setPoint("TRL", PIVOT)
-- queue in front of the window: world Z of the row = 7.5 in front of the pivot, 3.4 from the drawer (Z 13.2)
local QROW = -7.5
local Q_LX = { 11.08, 8.88, 6.68, 4.48, 2.28 }
for i = 1, 5 do
	local pos = W(Q_LX[i], GROUND, QROW)
	-- Q1 faces the trailer (back, -FRONT); the others face the head of the line (Q1 side, world -X)
	local dir = if i == 1 then -FRONT else Vector3.new(-1, 0, 0)
	setPoint("Q" .. i, face(pos, dir))
end
setPoint("CART", face(W(1.5, GROUND, -6.5), FRONT)) -- legacy: cutscene focus / customers face the service window
for i = 1, 4 do
	local lx = ({ -8, -2, 4, 10 })[i]
	local cf = face(W(lx, FLOOR, 0), FRONT)
	setPoint("PS-" .. i, cf)
	setPoint("PS-N" .. i, cf)
end
setPoint("DROP-T", face(W(11.5, FLOOR, 3.5), FRONT))
setPoint("AN-05", face(W(9.0, 7.45, 5.5), FRONT))
-- thief lurk out of the trailer: east of the east wall, 17 studs from the zone centre
setPoint("L3", face(W(-17.4, GROUND, -3.9), FRONT))
local ptOut = point("TRL-OUT")
if not ptOut then
	ptOut = point("DROP-T"):Clone()
	ptOut.Name = "TRL-OUT"
	ptOut:SetAttribute("PointId", "TRL-OUT")
	ptOut.Parent = pts
	L("MapPoint created: TRL-OUT")
end
ptOut.CFrame = face(W(16.3, GROUND, -0.2), FRONT)
-- light zones follow
zones["LZ-1"].Position = Vector3.new(PIVOT.X, zones["LZ-1"].Position.Y, PIVOT.Z)
zones["LZ-3"].Position = Vector3.new(PIVOT.X, zones["LZ-3"].Position.Y, PIVOT.Z)
local lz2 = W(7.1, zones["LZ-2"].Position.Y, -8.5)
zones["LZ-2"].Position = lz2
zones["LZ-2"].Size = Vector3.new(14, zones["LZ-2"].Size.Y, 5)

-- 3. tables (renumber 1..4 by X) ----------------------------------------------------------------------------------------
local list = {}
for _, t in CS:GetTagged("SeatTable") do
	if t:IsDescendantOf(workspace) and t:IsA("Model") then
		table.insert(list, t)
	end
end
table.sort(list, function(a, b)
	return a:GetPivot().Position.X < b:GetPivot().Position.X
end)
for i, t in list do
	if i > 4 then
		L("[warn] extra SeatTable " .. t:GetFullName() .. " left alone (more than 4 in the Workspace)")
		continue
	end
	t:SetAttribute("TableIndex", i)
	t:SetAttribute("MapId", "TTBL-" .. i)
	t:SetAttribute("TableGroup", "Trailer")
end
L("tables renumbered: " .. math.min(#list, 4))

-- nodes behind the tables -----------------------------------------------------------------------------------------------
if #list >= 4 then
	local tz = list[1]:GetPivot().Position.Z
	local x2, x3 = list[2]:GetPivot().Position.X, list[3]:GetPivot().Position.X
	local gapX = (x2 + x3) / 2
	ensureNode("N-PAD-1", Vector3.new(gapX, GROUND, tz + 4.2)) -- gate between tables 2 and 3, sidewalk side
	ensureNode("N-PAD-2", Vector3.new(gapX, GROUND, tz - 5.6)) -- row behind the tables
	ensureNode("N-PAD-3", Vector3.new(list[1]:GetPivot().Position.X - 0.7, GROUND, tz - 8.3)) -- west exit of Q1
	for i = 1, 4 do
		ensureNode("TBL-" .. i, Vector3.new(list[i]:GetPivot().Position.X, GROUND, tz - 5.6))
	end
	-- queue <-> Pad
	setLinks(nodePart("Q1"), { "Q2", "N-PAD-3" })
	setLinks(nodePart("Q5"), { "N-PAD-2", "Q4" })
	-- unlink the old sidewalk entries of the queue
	dropLink("Q5", "N-Z02-03")
	dropLink("Q1", "N-Z02-07")
	dropLink("Q1", "N-Z01-02")
	for _, id in { "N-PAD-1", "N-PAD-2", "N-PAD-3", "TBL-1", "TBL-2", "TBL-3", "TBL-4" } do
		local part = nodePart(id)
		-- keep only links that were set above, rebuilt idempotently below
		setLinks(part, {})
	end
	addLink("Q1", "N-PAD-3")
	addLink("Q5", "N-PAD-2")
	addLink("N-PAD-3", "N-PAD-2")
	addLink("N-PAD-3", "TBL-1")
	addLink("N-PAD-2", "N-PAD-1")
	addLink("N-PAD-2", "TBL-2")
	addLink("N-PAD-2", "TBL-3")
	addLink("TBL-1", "TBL-2")
	addLink("TBL-3", "TBL-4")
	addLink("N-PAD-1", "N-Z02-05")
	addLink("N-PAD-1", "N-Z02-07")
	-- thief lurk
	local n04 = nodePart("N-Z01-04")
	if n04 then
		n04.CFrame = CFrame.new(W(-18.4, GROUND, 1.1))
	end
	addLink("L3", "N-PAD-2")
	-- old Pad west corner
	for _, id in { "N-Z01-02", "N-Z01-03" } do
		local part = nodesFolder:FindFirstChild(id)
		if part then
			for _, other in linksOf(part) do
				dropLink(id, other)
			end
			toBackup(part, "old Pad west corner node (table 1 stands on its edge)")
		end
	end
	local z01 = nodesFolder:FindFirstChild("N-Z01-01")
	if z01 then
		for _, other in linksOf(z01) do
			if other == "N-Z01-02" then
				dropLink("N-Z01-01", other)
			end
		end
	end
end

-- 4. queue marks ---------------------------------------------------------------------------------------------------------
for i = 1, 5 do
	local mark = workspace:FindFirstChild("Q" .. i .. "_AST-019_QueueMark")
	local p = point("Q" .. i)
	if mark and p then
		local cf = mark:GetPivot()
		mark:PivotTo(CFrame.new(p.Position.X, cf.Position.Y, p.Position.Z) * (cf - cf.Position))
	end
end
L("queue marks moved to Q1..Q5")
pcall(function()
	CHS:SetWaypoint("trailer_only_map: after")
end)
return table.concat(log, "\n")
