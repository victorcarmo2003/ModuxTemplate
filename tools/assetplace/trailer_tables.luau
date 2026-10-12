--!nonstrict
-- OBSOLETE since 2026-10-12 (trailer is the only vehicle, tables are TBL-1..4): use trailer_only_map.luau. Kept as history.
--[[
	trailer_tables.luau: Studio snippet (edit mode, run once, safe to run again) for the TRAILER tables (FEAT-037, UPG-011,
	Q-209). Paste it in the command bar / Studio MCP execute_luau. NEVER Place.run, never rewrites the map: it does not
	move, resize, rename or recolour anything the owner placed. It only adds what is missing:

	  - tag `SeatTable`, attributes TableIndex (6..9) and TableGroup = "Trailer", ModelStreamingMode Persistent;
	  - BaseParts Seat1..Seat4 (invisible, no collision) when the table has none. If a Pad table (TableIndex 1..5) has its
	    seats, the new seats copy THEIR pose relative to the table pivot (same model, same layout); otherwise they are
	    laid out around the table from its bounding box (Seat1 + Seat2 side by side on one long side, Seat3 + Seat4 on
	    the other: a lone diner uses 1, a pair face to face 1 + 3, a couple side by side 1 + 2).

	Which models: tables already tagged SeatTable with TableIndex 6..9 / TableGroup "Trailer" are kept as they are. New
	ones = Models under workspace.MAP01_Assets whose name has "table" or "mesa" (not "bench"/"counter"), not tagged yet,
	and farther than FAR studs (flat) from every Pad table (TableIndex 1..5). Not what you want? Fill ONLY with the full
	names (GetFullName) of your 4 tables and it uses exactly those. DRY = true only prints.

	Order of TableIndex (6 = first bought): nearest to Q1 first. Printed: every candidate with its distance, so you can
	check the choice before it writes (set DRY = true for a first look).

	The server hides them (Locked) until the trailer is the vehicle, shows the next one as a ghost with its price
	(UPG-011: $50 / $70 / $90 / $120) and makes it solid when bought. Prompt_BuyTable / Prompt_CleanTable / Tray_Anchor are
	optional: without them the server creates a prompt over the table top. For the customers to walk there, add an
	NpcNode "TBL-6".."TBL-9" next to each table linked to the queue (tools/assetplace/check_map01.luau rule 16 warns).
]]

local CollectionService = game:GetService("CollectionService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local DRY = false
local FAR = 40
local ONLY = {} -- e.g. { "Workspace.MAP01_Assets.PadDecor.Table_A", ... }; empty = automatic

local TRAILER_FIRST, TRAILER_LAST = 6, 9
local TAG = "SeatTable"
local lines = {}
local function say(text)
	table.insert(lines, text)
end

local assets = workspace:FindFirstChild("MAP01_Assets")
assert(assets, "workspace.MAP01_Assets not found")

local function flat(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function hasPart(model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			return true
		end
	end
	return false
end

-- Q1 (MapPoint PointId Q1), fallback = the centre of the Pad tables
local q1
for _, point in CollectionService:GetTagged("MapPoint") do
	if point:GetAttribute("PointId") == "Q1" then
		q1 = if point:IsA("Attachment") then point.WorldPosition elseif point:IsA("BasePart") then point.Position else nil
	end
end

local padTables, trailerTagged, byIndex = {}, {}, {}
for _, m in CollectionService:GetTagged(TAG) do
	if m:IsA("Model") and m:IsDescendantOf(workspace) then
		local idx = m:GetAttribute("TableIndex")
		if typeof(idx) == "number" and idx >= TRAILER_FIRST and idx <= TRAILER_LAST then
			table.insert(trailerTagged, m)
			byIndex[idx] = m
		elseif typeof(idx) == "number" and idx >= 1 and idx < TRAILER_FIRST then
			table.insert(padTables, m)
		elseif m:GetAttribute("TableGroup") == "Trailer" then
			table.insert(trailerTagged, m)
		end
	end
end
if not q1 then
	local sum = Vector3.zero
	for _, m in padTables do
		sum += m:GetPivot().Position
	end
	q1 = if #padTables > 0 then sum / #padTables else Vector3.zero
end

local function nearPad(model)
	for _, pad in padTables do
		if flat(pad:GetPivot().Position, model:GetPivot().Position) <= FAR then
			return true
		end
	end
	return false
end

-- candidates
local fresh = {}
if #ONLY > 0 then
	for _, full in ONLY do
		local found
		for _, d in assets:GetDescendants() do
			if d:IsA("Model") and d:GetFullName() == full then
				found = d
				break
			end
		end
		assert(found, "ONLY: not found " .. full)
		if not CollectionService:HasTag(found, TAG) or not found:GetAttribute("TableIndex") then
			table.insert(fresh, found)
		end
	end
else
	for _, d in assets:GetDescendants() do
		if d:IsA("Model") and not CollectionService:HasTag(d, TAG) then
			local name = string.lower(d.Name)
			if (string.find(name, "table") or string.find(name, "mesa")) and not string.find(name, "bench") and not string.find(name, "counter") then
				-- a table nested in another table candidate is a part of it
				local nested = false
				for _, other in fresh do
					if d:IsDescendantOf(other) then
						nested = true
					end
				end
				local insideTagged = false
				for _, t in CollectionService:GetTagged(TAG) do
					if d:IsDescendantOf(t) then
						insideTagged = true
					end
				end
				if not nested and not insideTagged and hasPart(d) and not nearPad(d) then
					table.insert(fresh, d)
				end
			end
		end
	end
end
table.sort(fresh, function(a, b)
	return flat(a:GetPivot().Position, q1) < flat(b:GetPivot().Position, q1)
end)

say(("Q1 = (%.1f, %.1f, %.1f); Pad tables %d; trailer tables already tagged %d; new candidates %d"):format(q1.X, q1.Y, q1.Z, #padTables, #trailerTagged, #fresh))
for _, m in fresh do
	say(("  candidate %s  (%.0f studs from Q1)"):format(m:GetFullName(), flat(m:GetPivot().Position, q1)))
end

-- next free TableIndex 6..9
local function freeIndex()
	for i = TRAILER_FIRST, TRAILER_LAST do
		if byIndex[i] == nil then
			return i
		end
	end
	return nil
end

-- reference seat poses relative to the pivot of a Pad table that has Seat1..4
local reference
for _, pad in padTables do
	local poses = {}
	for n = 1, 4 do
		local seat = pad:FindFirstChild("Seat" .. n, true)
		if seat and seat:IsA("BasePart") then
			poses[n] = pad:GetPivot():ToObjectSpace(seat.CFrame)
		end
	end
	if poses[1] and poses[2] and poses[3] and poses[4] then
		reference = poses
		say("  seats copied from the pose of " .. pad:GetFullName())
		break
	end
end

local function makeSeat(model, n, cf)
	local part = Instance.new("Part")
	part.Name = "Seat" .. n
	part.Size = Vector3.new(1, 1, 1)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CFrame = cf
	part.Parent = model
	return part
end

local function seatsFor(model)
	local missing = {}
	for n = 1, 4 do
		local seat = model:FindFirstChild("Seat" .. n, true)
		if not (seat and seat:IsA("BasePart")) then
			table.insert(missing, n)
		end
	end
	if #missing == 0 then
		return 0
	end
	local pivot = model:GetPivot()
	local frame, size = model:GetBoundingBox()
	for _, n in missing do
		local cf
		if reference then
			cf = pivot * reference[n]
		else
			-- long axis = the larger of the bounding box X / Z, seats 1.0 stud beyond each long side
			local alongX = size.X >= size.Z
			local long = if alongX then size.X else size.Z
			local wide = if alongX then size.Z else size.X
			local u = if n <= 2 then 1 else -1 -- side
			local v = if n % 2 == 1 then -1 else 1 -- along
			local y = -size.Y / 2 + 2.9 -- torso of a seated R6 diner over the floor
			local lx = if alongX then v * long / 4 else u * (wide / 2 + 1)
			local lz = if alongX then u * (wide / 2 + 1) else v * long / 4
			local at = Vector3.new(lx, y, lz)
			local toward = if alongX then Vector3.new(lx, y, 0) else Vector3.new(0, y, lz)
			cf = CFrame.lookAt(frame:PointToWorldSpace(at), frame:PointToWorldSpace(toward))
		end
		makeSeat(model, n, cf)
	end
	return #missing
end

local touched = 0
local function bind(model, index)
	byIndex[index] = model
	local changes = {}
	if not CollectionService:HasTag(model, TAG) then
		table.insert(changes, "tag")
	end
	if model:GetAttribute("TableIndex") ~= index then
		table.insert(changes, "TableIndex=" .. index)
	end
	if model:GetAttribute("TableGroup") ~= "Trailer" then
		table.insert(changes, "TableGroup=Trailer")
	end
	if model.ModelStreamingMode ~= Enum.ModelStreamingMode.Persistent then
		table.insert(changes, "Persistent")
	end
	local seatsMissing = 0
	for n = 1, 4 do
		local seat = model:FindFirstChild("Seat" .. n, true)
		if not (seat and seat:IsA("BasePart")) then
			seatsMissing += 1
		end
	end
	if seatsMissing > 0 then
		table.insert(changes, seatsMissing .. " seat(s)")
	end
	say(("  TBL-%d  %s  %s"):format(index, model:GetFullName(), if #changes == 0 then "(already bound)" else "+ " .. table.concat(changes, ", ")))
	if DRY or #changes == 0 then
		return
	end
	touched += 1
	CollectionService:AddTag(model, TAG)
	model:SetAttribute("TableIndex", index)
	model:SetAttribute("TableGroup", "Trailer")
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	seatsFor(model)
end

if not DRY then
	ChangeHistoryService:SetWaypoint("trailer_tables: before")
end
-- already tagged: complete what is missing (index kept)
for _, m in trailerTagged do
	local idx = m:GetAttribute("TableIndex")
	if typeof(idx) == "number" and idx >= TRAILER_FIRST and idx <= TRAILER_LAST then
		bind(m, idx)
	else
		local free = freeIndex()
		if free then
			bind(m, free)
		else
			say("  no free TableIndex 6..9 for " .. m:GetFullName())
		end
	end
end
for _, m in fresh do
	local free = freeIndex()
	if free == nil then
		say("  more than 4 trailer tables: " .. m:GetFullName() .. " left alone (Seating.Groups[Trailer].Count = 4)")
		continue
	end
	bind(m, free)
end
if not DRY then
	ChangeHistoryService:SetWaypoint("trailer_tables: after")
end

local count = 0
for i = TRAILER_FIRST, TRAILER_LAST do
	if byIndex[i] then
		count += 1
	end
end
say(("trailer tables bound: %d/4%s; models changed: %d"):format(count, if DRY then " (DRY, nothing written)" else "", touched))
if count < 4 then
	say("  fewer than 4 found: set ONLY to the full names of the missing tables, or lower FAR if they sit close to the Pad tables")
end
print(table.concat(lines, "\n"))
return table.concat(lines, "\n")
