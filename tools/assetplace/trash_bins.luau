--!nocheck
--[[
	trash_bins.luau: prepares the dumpsters the OWNER placed (2026-10-12, workspace.MAP01_Assets.Extra, two Parts named P2)
	so TrashController can throw the tray of a cleaned table into the nearest one. Studio snippet, Edit mode. Moves and
	deletes NOTHING: it tags, writes attributes and adds two Attachments per bin.

	Call (tools/studio/README.md, run_snippet):
		run("trash_bins")           -- report only (DRY_RUN): what it found and what it would write
		run("trash_bins", "apply")  -- tag + attributes + attachments (idempotent: marks `TrashBinsV1`)
		run("trash_bins", "undo")   -- removes tag, attributes and the attachments it created

	What it reads from Studio (nothing typed by hand, except the names below):
	  * bins = Parts named BIN_NAME under FOLDER, or already tagged TrashBin; BinId = BIN-1.. by X (west to east)
	  * front = the Part's LookVector (flat). The opening is the top; the dumpsters face the trailer (+Z)
	  * DropPoint  Attachment, world point 0.4 studs above the top surface (raycast down onto the Part itself), centred
	  * ApproachPoint  Attachment on the ground 1.8 studs in front of the bin (raycast down; for NPC routes)
	  * Lid: none today (the mesh is one piece). TrashController bumps the bin instead; add a `Lid` Part and an
	    Attachment `LidHinge` (back edge) and it opens by itself.
	MAP coordinates (bind_map01 / MapIndex): world = (-x, y, 67.887287 - z). Written as attributes `MapDrop` /
	`MapApproach` (Vector3 in MAP space) for the record; nothing reads them at runtime. Values are Provisional (Content.Trash).
]]

local CollectionService = game:GetService("CollectionService")
local MODE = (...) or "report"
local APPLY = MODE == "apply"
local UNDO = MODE == "undo"
local MARK = "TrashBinsV1"
local TAG = "TrashBin"
local BIN_NAME = "P2"
local DROP_LIFT = 0.4
local APPROACH_FRONT = 1.8
local Z0 = 67.887287

local out = {}
local function say(...)
	local parts = table.pack(...)
	for i = 1, parts.n do
		parts[i] = tostring(parts[i])
	end
	table.insert(out, table.concat(parts, " "))
end
local function f(v)
	return string.format("(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z)
end
local function toMap(v)
	return Vector3.new(-v.X, v.Y, Z0 - v.Z)
end

local bins = {}
local seen = {}
local folder = workspace:FindFirstChild("MAP01_Assets") and workspace.MAP01_Assets:FindFirstChild("Extra")
if folder then
	for _, inst in folder:GetChildren() do
		if inst.Name == BIN_NAME and inst:IsA("BasePart") then
			seen[inst] = true
			table.insert(bins, inst)
		end
	end
end
for _, inst in CollectionService:GetTagged(TAG) do
	if not seen[inst] and inst:IsA("BasePart") then
		table.insert(bins, inst)
	end
end
table.sort(bins, function(a, b)
	return a.Position.X < b.Position.X
end)
say("bins found:", #bins, "(mode " .. MODE .. ")")

local function groundBelow(origin, ignore)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(origin, Vector3.new(0, -20, 0), rp)
	return hit and hit.Position or nil
end

for index, bin in bins do
	local id = "BIN-" .. index
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { bin }
	local topHit = workspace:Raycast(bin.Position + Vector3.new(0, 20, 0), Vector3.new(0, -40, 0), rp)
	local top = topHit and topHit.Position.Y or (bin.Position.Y + bin.Size.Y / 2)
	local look = bin.CFrame.LookVector
	local front = Vector3.new(look.X, 0, look.Z)
	front = front.Magnitude > 1e-3 and front.Unit or Vector3.new(0, 0, 1)
	local drop = Vector3.new(bin.Position.X, top + DROP_LIFT, bin.Position.Z)
	local depth = math.abs(front:Dot(bin.CFrame.LookVector)) > 0.99 and bin.Size.Z or bin.Size.X
	local ahead = bin.Position + front * (depth / 2 + APPROACH_FRONT)
	local ground = groundBelow(Vector3.new(ahead.X, bin.Position.Y + 3, ahead.Z), { bin }) or Vector3.new(ahead.X, 0.45, ahead.Z)
	local approach = Vector3.new(ahead.X, ground.Y, ahead.Z)
	say(id, bin:GetFullName(), "top y", string.format("%.2f", top), "drop", f(drop), "approach", f(approach), "front", f(front),
		"mesh", bin:FindFirstChildOfClass("SpecialMesh") and "SpecialMesh" or "none", "lid", bin:FindFirstChild("Lid") and "yes" or "no")

	if UNDO then
		CollectionService:RemoveTag(bin, TAG)
		for _, name in { "DropPoint", "ApproachPoint" } do
			local a = bin:FindFirstChild(name)
			if a and a:GetAttribute(MARK) then
				a:Destroy()
			end
		end
		for _, name in { "BinId", "MapDrop", "MapApproach", MARK } do
			bin:SetAttribute(name, nil)
		end
	elseif APPLY then
		CollectionService:AddTag(bin, TAG)
		bin:SetAttribute("BinId", id)
		bin:SetAttribute("MapDrop", toMap(drop))
		bin:SetAttribute("MapApproach", toMap(approach))
		bin:SetAttribute(MARK, true)
		for name, world in { DropPoint = drop, ApproachPoint = approach } do
			local a = bin:FindFirstChild(name)
			if not (a and a:IsA("Attachment")) then
				a = Instance.new("Attachment")
				a.Name = name
				a.Parent = bin
			end
			a.WorldPosition = world
			a:SetAttribute(MARK, true)
		end
	end
end
if not APPLY and not UNDO then
	say("DRY RUN: nothing written. run(\"trash_bins\", \"apply\") to write; \"undo\" to remove.")
end
return table.concat(out, "\n")
