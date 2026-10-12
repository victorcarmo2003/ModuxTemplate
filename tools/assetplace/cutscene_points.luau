--!nocheck
--[[
	cutscene_points.luau - SURGICAL and IDEMPOTENT Studio patch (2026-10-12, owner decision D3: short intro that starts on
	the sidewalk in front of the trailer's Pad). NOT a Place.run: it only creates or moves MapPoint Parts in
	workspace.MapBinding.Points. Paste it in the Studio command bar / execute_luau (Edit mode, not Play). Safe to run twice:
	a point already within 0.01 studs of its target is skipped. Set DRY_RUN = true to only print what it would do.

	Content.Cutscenes "intro" (src/Shared/Content/Cutscenes.luau) now walks LEFT (world +X) along the Ninth's south
	sidewalk, in front of the Pad (Pad edge Z 36, sidewalk Z 36..47.5, curb at 47.5), from the planter at its right end
	(world -X, the Planter at (-76, 37)) to the P-01 post with the Help Wanted flyer at (-17.2, 50.2), then calls Walt and ends
	looking at the trailer (MapPoint TRL, read from the map: not touched here). Coordinates are WORLD coordinates (the
	MAP-01 frame is world = (-x, y, K - z); these are measured in the place, not derived).

	  point            world (x, y, z)        facing          use
	  CS-1             (-68, 0.4, 43)         +X (east walk)  start of the walk, right end of the sidewalk
	  CS-2             (-42, 0.4, 43)         +X              middle of the walk, in front of the Pad (papers on the wind)
	  CS-3             (-24, 0.4, 43)         +X              only waypoint of the route: the walk bends 25 degrees to the stand
	  CutsceneMark1    (-68, 0.4, 45)         +X              party start slots, 2 x 2 (slot 1 = the player that made the party)
	  CutsceneMark2    (-68, 0.4, 41)         +X
	  CutsceneMark3    (-71, 0.4, 45)         +X
	  CutsceneMark4    (-71, 0.4, 41)         +X

	The stand in front of the flyer (CS-P1..4) is computed at runtime from the flyer's face (Rules.Stand); the old
	CS-P*, CS-4, CS-5, CS-5W, CS-5E, CS-6, CS-7 stay where they are (unused by the intro, harmless, delete when the finale is
	redone). CS-1, CS-2, CS-3 and CutsceneMark1..4 EXIST today on the north sidewalk: they are MOVED here (same Part, same
	tags and attributes); a missing one is created (invisible, anchored, no collision/query/touch, tag MapPoint, attribute
	PointId). CS-1..3 and the marks are not read by anything else (checked: grep src/ 2026-10-12).

	The MapIndex caches positions at start: stop Play and start again after running. Undo: Ctrl+Z (waypoints
	"cutscene_points: before/after") or put the BEFORE values in TARGET and run again.
	Ordering: run it once the Pad's trailer is in place or not, it does not depend on it (the end looks at TRL).
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local DRY_RUN = false
local DONE = "CutsceneIntroD3"
local EAST = Vector3.new(1, 0, 0) -- the walk direction (world +X = the party's left looking at the street)
local Y = 0.4 -- sidewalk top (measured: raycast at X -68..-15, Z 36..47)

local TARGET = {
	{ id = "CS-1", x = -68, z = 43 },
	{ id = "CS-2", x = -42, z = 43 },
	{ id = "CS-3", x = -24, z = 43 },
	{ id = "CutsceneMark1", x = -68, z = 45 },
	{ id = "CutsceneMark2", x = -68, z = 41 },
	{ id = "CutsceneMark3", x = -71, z = 45 },
	{ id = "CutsceneMark4", x = -71, z = 41 },
}

local binding = Workspace:FindFirstChild("MapBinding")
local pointsFolder = binding and binding:FindFirstChild("Points")
if not pointsFolder then
	error("cutscene_points: workspace.MapBinding.Points not found (run bind_map01 first)")
end

local existing: { [string]: BasePart } = {}
for _, part in CollectionService:GetTagged("MapPoint") do
	local id = part:GetAttribute("PointId")
	if part:IsA("BasePart") and typeof(id) == "string" and part:IsDescendantOf(Workspace) then
		existing[id] = part
	end
end

if not DRY_RUN then
	ChangeHistoryService:SetWaypoint("cutscene_points: before")
end

local moved, created, skipped = 0, 0, 0
for _, row in TARGET do
	local want = Vector3.new(row.x, Y, row.z)
	local cf = CFrame.lookAt(want, want + EAST)
	local part = existing[row.id]
	if part then
		if (part.Position - want).Magnitude < 0.01 and part.CFrame.LookVector:Dot(EAST) > 0.999 then
			skipped += 1
			print(string.format("%s already at (%.2f, %.2f, %.2f)", row.id, want.X, want.Y, want.Z))
		else
			print(string.format("%s: (%.2f, %.2f, %.2f) -> (%.2f, %.2f, %.2f)%s", row.id, part.Position.X, part.Position.Y, part.Position.Z, want.X, want.Y, want.Z, if DRY_RUN then " [dry run]" else ""))
			if not DRY_RUN then
				part.CFrame = cf -- same Part: tags and attributes stay
				part:SetAttribute(DONE, true)
			end
			moved += 1
		end
	else
		print(string.format("%s: created at (%.2f, %.2f, %.2f)%s", row.id, want.X, want.Y, want.Z, if DRY_RUN then " [dry run]" else ""))
		if not DRY_RUN then
			local p = Instance.new("Part")
			p.Name = row.id
			p.Size = Vector3.one
			p.CFrame = cf
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Transparency = 1
			p.Parent = pointsFolder
			CollectionService:AddTag(p, "MapPoint")
			p:SetAttribute("PointId", row.id)
			p:SetAttribute(DONE, true)
		end
		created += 1
	end
end

if not DRY_RUN then
	ChangeHistoryService:SetWaypoint("cutscene_points: after")
end

-- Sanity: the three waypoints and the flyer must be reachable on the sidewalk; TRL must exist (the end looks at it)
local function exists(id: string): boolean
	local part = existing[id]
	return part ~= nil and part:IsDescendantOf(Workspace)
end
if not exists("TRL") then
	warn("cutscene_points: MapPoint TRL not found; the end of the intro has nothing to look at")
end
local flyer = Workspace:FindFirstChild("P-01_Flyer", true)
if flyer and flyer:IsA("BasePart") then
	print(string.format("flyer P-01 at (%.1f, %.1f, %.1f); CS-3 -> flyer: %.1f studs", flyer.Position.X, flyer.Position.Y, flyer.Position.Z, (Vector3.new(-24, Y, 43) - flyer.Position).Magnitude))
else
	warn("cutscene_points: P-01_Flyer not found (the stand falls back to the P-01 post)")
end
print(string.format("cutscene_points: %d moved, %d created, %d already in place%s. Stop and restart Play to reload the MapIndex.", moved, created, skipped, if DRY_RUN then " (DRY RUN, nothing changed)" else ""))
