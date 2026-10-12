--!nonstrict
--[[
	trailer_only_lights.luau (owner decision 2026-10-12: the string lights of the Pad must be CONNECTED to the trailer;
	Provisional). Edit-mode Studio snippet, NOT gameplay code. Idempotent, NO Place.run, nothing deleted.

	Before: 44 Wire + 39 Bulb parts at the Workspace root ran from the two front light poles of the Pad and ended in the
	air at the awning line. After: three low arcs (catenary-like sag), same Wire / Bulb parts (clones of the originals:
	same navy wire, same neon colours, NO new lights, the 17/18 light budget is untouched):
	  W   the west end of the trailer's own front string (TRL-LIGHTS, roof edge) -> top of the west Pad pole
	  E   the east end of the trailer's own front string                          -> top of the east Pad pole
	  F   west pole -> east pole along the front of the Pad (over the sidewalk gate, tables below)
	Lowest point of every arc >= 9.5 studs (>= 9 over the sidewalk), the west / east arcs stay outside the window flap and
	the queue (the flap is X -57.7..-35.2; the queue is below).
	The old parts are MOVED to ServerStorage.PadLights_Backup_20261012 (OrigPath attribute). New parts live in
	Workspace.MAP01_Assets.PadDecor.TrailerStringLights_V1 (rebuilt from scratch on every run). The anchors are read from
	the model (TRL-LIGHTS strip ends, Pad pole tops), so the arcs follow the trailer if it is moved; re-run after a move.
]]

local ST = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")
local BK_NAME = "PadLights_Backup_20261012"
local GROUP = "TrailerStringLights_V1"
local SEG = 1.6 -- studs per wire segment
local BULB_EVERY = 3.0 -- studs between bulbs
local SAG_SIDE = 0.8
local SAG_FRONT = 0.42
local PALETTE = {
	Color3.new(1, 0.956863, 0.839216), -- cream
	Color3.new(0.25098, 0.878431, 0.666667), -- mint
	Color3.new(1, 0.360784, 0.627451), -- pink
	Color3.new(1, 0.784314, 0.239216), -- yellow
}
local log = {}
local function L(text)
	table.insert(log, text)
end
pcall(function()
	CHS:SetWaypoint("trailer_only_lights: before")
end)

local trailer
for _, m in game:GetService("CollectionService"):GetTagged("Vehicle") do
	if m:IsDescendantOf(workspace) and m:GetAttribute("Vehicle") == "trailer" then
		trailer = m
	end
end
if not trailer then
	return "[err] no trailer Model in the Workspace"
end
local strip = trailer:FindFirstChild("TRL-LIGHTS_AST-023_TrailerLights")
if not strip then
	for _, d in trailer:GetChildren() do
		if string.find(d.Name, "TRL-LIGHTS", 1, true) then
			strip = d
			break
		end
	end
end
if not strip then
	return "[err] TRL-LIGHTS (the trailer's own string) not found"
end
-- the front strip: the TRL-LIGHTS Model whose bbox is wide (the other one is the roof mast piece)
local bestWide = 0
for _, d in trailer:GetChildren() do
	if d:IsA("Model") and string.find(d.Name, "TRL-LIGHTS", 1, true) then
		local _, size = d:GetBoundingBox()
		if size.X > bestWide then
			bestWide = size.X
			strip = d
		end
	end
end
local sCf, sSize = strip:GetBoundingBox()
local anchorY = sCf.Position.Y + 0.35
local anchorZ = sCf.Position.Z
local westA = Vector3.new(sCf.Position.X - sSize.X / 2 - 0.9, anchorY, anchorZ)
local eastA = Vector3.new(sCf.Position.X + sSize.X / 2 + 0.9, anchorY, anchorZ)

-- Pad poles (Workspace root, Part LightPole)
local poles = {}
for _, c in workspace:GetChildren() do
	if c:IsA("BasePart") and c.Name == "LightPole" and c.Position.Z > anchorZ then
		table.insert(poles, c)
	end
end
table.sort(poles, function(a, b)
	return a.Position.Z < b.Position.Z or (a.Position.Z == b.Position.Z and a.Position.X > b.Position.X)
end)
-- the two front poles = the two farthest from the trailer
local front = {}
for _, p in poles do
	if p.Position.Z > anchorZ + 10 then
		table.insert(front, p)
	end
end
table.sort(front, function(a, b)
	return a.Position.X > b.Position.X -- east (-X is west in the world... lower X = west end of the window) first = higher X
end)
if #front < 2 then
	return "[err] the two front Pad poles (Part LightPole) were not found"
end
local poleE, poleW = front[1], front[#front]
local function top(p)
	return Vector3.new(p.Position.X, p.Position.Y + p.Size.Y / 2 - 0.02, p.Position.Z)
end

-- templates and backup -----------------------------------------------------------------------------------------------------
local bk = ST:FindFirstChild(BK_NAME)
if not bk then
	bk = Instance.new("Folder")
	bk.Name = BK_NAME
	bk.Parent = ST
end
local wireT, bulbT
local oldN = 0
for _, c in workspace:GetChildren() do
	if c:IsA("BasePart") and (c.Name == "Wire" or c.Name == "Bulb") then
		if c.Name == "Wire" and not wireT then
			wireT = c:Clone()
		elseif c.Name == "Bulb" and not bulbT then
			bulbT = c:Clone()
		end
		c:SetAttribute("OrigPath", c:GetFullName())
		c.Parent = bk
		oldN += 1
	end
end
if oldN > 0 then
	L("old Pad string lights moved to backup: " .. oldN .. " parts")
end
if not wireT or not bulbT then
	for _, c in bk:GetChildren() do
		if c:IsA("BasePart") and c.Name == "Wire" and not wireT then
			wireT = c:Clone()
		elseif c:IsA("BasePart") and c.Name == "Bulb" and not bulbT then
			bulbT = c:Clone()
		end
	end
end
if not wireT or not bulbT then
	return "[err] no Wire / Bulb template (workspace root and backup are empty)"
end
for _, t in { wireT, bulbT } do
	t:ClearAllChildren()
end

local padDecor = workspace.MAP01_Assets:FindFirstChild("PadDecor")
local old = padDecor:FindFirstChild(GROUP)
if old then
	old:Destroy() -- generated by this snippet
end
local group = Instance.new("Folder")
group.Name = GROUP
group.Parent = padDecor

-- one arc -------------------------------------------------------------------------------------------------------------------
local bulbIndex = 0
local function arc(a, b, sag, label)
	local dist = (b - a).Magnitude
	local n = math.max(2, math.ceil(dist / SEG))
	local pointsList = {}
	for i = 0, n do
		local t = i / n
		local p = a:Lerp(b, t)
		table.insert(pointsList, Vector3.new(p.X, p.Y - sag * 4 * t * (1 - t), p.Z))
	end
	local lowest = math.huge
	local sinceBulb = BULB_EVERY * 0.5
	for i = 1, n do
		local p0, p1 = pointsList[i], pointsList[i + 1]
		local len = (p1 - p0).Magnitude
		local wire = wireT:Clone()
		wire.Name = "Wire"
		wire.Size = Vector3.new(0.1, 0.1, len + 0.04)
		wire.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
		wire.Parent = group
		lowest = math.min(lowest, p0.Y, p1.Y)
		sinceBulb += len
		if sinceBulb >= BULB_EVERY and i < n then
			sinceBulb = 0
			bulbIndex += 1
			local bulb = bulbT:Clone()
			bulb.Name = "Bulb"
			bulb.Color = PALETTE[(bulbIndex - 1) % #PALETTE + 1]
			bulb.CFrame = CFrame.new(p1.X, p1.Y - 0.2, p1.Z)
			bulb.Parent = group
		end
	end
	L(string.format("arc %s: %.1f studs, %d segments, lowest y %.2f", label, dist, n, lowest))
	return lowest
end
local lowW = arc(westA, top(poleW), SAG_SIDE, "W (trailer -> west pole)")
local lowE = arc(eastA, top(poleE), SAG_SIDE, "E (trailer -> east pole)")
local lowF = arc(top(poleW), top(poleE), SAG_FRONT, "F (pole -> pole)")
group:SetAttribute("Lowest", math.min(lowW, lowE, lowF))
L(string.format("anchors: west %s, east %s, poles %s %s", tostring(westA), tostring(eastA), tostring(top(poleW)), tostring(top(poleE))))
pcall(function()
	CHS:SetWaypoint("trailer_only_lights: after")
end)
return table.concat(log, "\n")
