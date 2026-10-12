--!nocheck
--[[
	fix_queue_points.luau - SURGICAL and IDEMPOTENT Studio patch (2026-10-12). NOT a Place.run: it only moves the live
	MapPoint/NpcNode Parts Q2..Q5 (workspace.MapBinding.Points). Paste it in the Studio command bar / execute_luau (Edit mode,
	not Play). Safe to run twice: a point already within 0.01 of its target is skipped.

	Why (owner playtest 2026-10-12: "customers are too far from the proximity prompt"): the queue ran along Z 29, 5 studs
	apart, so from the counter (player at Z ~39.5) Q2..Q5 were 11..16 studs away, out of Take Order / Serve reach. Now Q2..Q5
	sit on the Pad lip behind Q1, 2.2 studs apart (MAP-01 §4 / bind_map01.luau POINTS; keep the three in step):

	  point   before (MAP-01 x, z)   after (MAP-01 x, z)
	  Q1      (52, 33)               unchanged (the trailer's folding counter, Z 33.5..34.5, forbids moving closer;
	                                  3.0 studs from the cart counter face at Z 36)
	  Q2      (46, 29)               (49.8, 31.5)
	  Q3      (41, 29)               (47.6, 31.5)
	  Q4      (36, 29)               (45.4, 31.5)
	  Q5      (31, 29)               (43.2, 31.5)

	Preserved: every attribute (PointId, Links, ...), tags, rotation (facing east) and the point's height (floor 0.4 -> the
	sidewalk; Z 31.5 is still off the Pad lip at Z 32). Nodes are the same Parts (NpcNode + PointId), so the graph follows.
	The MapIndex caches positions at server start: stop Play and start again after running.
	Undo: Ctrl+Z (waypoints "fix_queue_points: before/after") or copy the BEFORE values into TARGET and run again.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local K = 67.887287 -- MAP-01 -> world (map_frame.luau): world = (-x, y, K - z)
local DONE = "QueueCompactV1"

-- MAP-01 coordinates (x, z)
local TARGET = {
	Q2 = { 49.8, 31.5 },
	Q3 = { 47.6, 31.5 },
	Q4 = { 45.4, 31.5 },
	Q5 = { 43.2, 31.5 },
}
local BEFORE = {
	Q2 = { 46, 29 },
	Q3 = { 41, 29 },
	Q4 = { 36, 29 },
	Q5 = { 31, 29 },
}

local function world(xz: { number }, y: number): Vector3
	return Vector3.new(-xz[1], y, K - xz[2])
end

local moved, skipped, missing = 0, 0, {}
local points: { [string]: BasePart } = {}
for _, part in CollectionService:GetTagged("MapPoint") do
	local id = part:GetAttribute("PointId")
	if part:IsA("BasePart") and typeof(id) == "string" and TARGET[id] and part:IsDescendantOf(Workspace) then
		points[id] = part
	end
end

ChangeHistoryService:SetWaypoint("fix_queue_points: before")
for id, xz in TARGET do
	local part = points[id]
	if not part then
		table.insert(missing, id)
		continue
	end
	local want = world(xz, part.Position.Y)
	if (part.Position - want).Magnitude < 0.01 then
		skipped += 1
		print(string.format("%s already at (%.2f, %.2f, %.2f)", id, want.X, want.Y, want.Z))
		continue
	end
	local from = part.Position
	part.CFrame = part.CFrame.Rotation + want -- same rotation, new position
	part:SetAttribute(DONE, true)
	moved += 1
	print(string.format("%s: (%.2f, %.2f) -> (%.2f, %.2f) world (%.2f, %.2f, %.2f)", id, -from.X, K - from.Z, xz[1], xz[2], want.X, want.Y, want.Z))
end
ChangeHistoryService:SetWaypoint("fix_queue_points: after")

if #missing > 0 then
	warn("fix_queue_points: MapPoint(s) not found (run bind_map01 first): " .. table.concat(missing, ", "))
end
print(string.format("fix_queue_points: %d moved, %d already in place. Stop and restart Play to reload the MapIndex.", moved, skipped))

-- Sanity: spacing Q1..Q5 (MAP-01 frame), must be >= 2.2 between neighbours
local q1 = (function()
	for _, part in CollectionService:GetTagged("MapPoint") do
		if part:GetAttribute("PointId") == "Q1" and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end)()
if q1 then
	local prev = q1.Position
	for _, id in { "Q2", "Q3", "Q4", "Q5" } do
		local part = points[id]
		if part then
			print(string.format("  %s -> previous: %.2f studs", id, (part.Position - prev).Magnitude))
			prev = part.Position
		end
	end
end
