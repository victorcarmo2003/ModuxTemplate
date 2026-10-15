--!nocheck
--[[
	fix_queue_spacing.luau - SURGICAL and IDEMPOTENT Studio patch (TASK-287, owner request 2026-10-14). NOT a Place.run:
	it only moves the live MapPoint/NpcNode Parts Q2..Q5 (MAP01_Assets.Extra.MapBinding.Points). Paste it in the Studio
	command bar / execute_luau (Edit mode, not Play), then save the place. Safe to run twice.

	Why: the queue points were 2.2 studs apart (fix_queue_points.luau, 2026-10-12) and the NPCs stood almost on top of
	each other. Q1 stays where it is (the ordering spot, next to the window); Q2..Q5 keep the line's current direction
	(Q1 -> Q2) and height, now SPACING studs apart. Measured in Studio 2026-10-14 (world): Q1 (-56.0, 0.45, 19.7), line
	running +X; free floor (PadFloor, no collidable part) up to X -36.
	The MapIndex caches positions at server start: stop Play and start again after running.
	Undo: Ctrl+Z (waypoints "fix_queue_spacing: before/after").
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local SPACING = 4 -- studs between neighbouring slots (was 2.2)
local DONE = "QueueSpacingV1"

local points: { [string]: BasePart } = {}
for _, part in CollectionService:GetTagged("MapPoint") do
	local id = part:GetAttribute("PointId")
	if part:IsA("BasePart") and typeof(id) == "string" and string.match(id, "^Q[1-5]$") and part:IsDescendantOf(Workspace) then
		points[id] = part
	end
end
local q1, q2 = points.Q1, points.Q2
if not q1 or not q2 then
	error("fix_queue_spacing: Q1/Q2 MapPoint not found (run bind_map01 first)")
end

local flat = Vector3.new(1, 0, 1)
local dir = ((q2.Position - q1.Position) * flat)
if dir.Magnitude < 0.1 then
	error("fix_queue_spacing: Q1 and Q2 on the same spot, no line direction")
end
dir = dir.Unit

ChangeHistoryService:SetWaypoint("fix_queue_spacing: before")
local moved = 0
for k = 2, 5 do
	local part = points[`Q{k}`]
	if not part then
		warn(`fix_queue_spacing: Q{k} missing`)
		continue
	end
	local base = q1.Position + dir * SPACING * (k - 1)
	local want = Vector3.new(base.X, part.Position.Y, base.Z)
	if (part.Position - want).Magnitude >= 0.01 then
		local from = part.Position
		part.CFrame = part.CFrame.Rotation + want -- same rotation and attributes, new position
		part:SetAttribute(DONE, true)
		moved += 1
		print(string.format("Q%d: (%.2f, %.2f) -> (%.2f, %.2f)", k, from.X, from.Z, want.X, want.Z))
	end
end
ChangeHistoryService:SetWaypoint("fix_queue_spacing: after")

local prev = q1.Position
for k = 2, 5 do
	local part = points[`Q{k}`]
	if part then
		print(string.format("  Q%d -> previous: %.2f studs", k, (part.Position - prev).Magnitude))
		prev = part.Position
	end
end
print(string.format("fix_queue_spacing: %d moved. Save the place; restart Play to reload the MapIndex.", moved))
