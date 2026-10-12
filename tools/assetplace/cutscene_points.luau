--!nocheck
--[[
	cutscene_points.luau - SURGICAL and IDEMPOTENT Studio patch (2026-10-12, owner decision D3 rev. 2: the intro starts on the
	sidewalk across from the trailer and CROSSES the Ninth on a crosswalk). NOT a Place.run: it only creates or moves MapPoint
	Parts in workspace.MapBinding.Points. Paste it in the Studio command bar / execute_luau (Edit mode, not Play), or load it with
	tools/studio/README.md (run_snippet("assetplace/cutscene_points")). Safe to run twice: a point already within 0.01 studs
	of its target is skipped. Set DRY_RUN = true to only print what it would do.

	Content.Cutscenes "intro" (src/Shared/Content/Cutscenes.luau) walks: start marks (north sidewalk of the Ninth, across from
	the trailer's Pad) -> CS-1 (north curb, at the crosswalk CW-4) -> straight across the stripes (CS-2 mid street, then a bend east) -> CS-3
	(south end of the stripes) -> the stand in front of the P-01 flyer (CS-P*, computed at runtime from the flyer face). CW-4 is
	the nearest crosswalk to the flyer and the widest one (stripes X -24..-12, Z 54.6..83.1: four avatars side by side fit; CW-3 is
	6 studs wide and has a street light pole at its north end). Measured in the place on 2026-10-12 (world coordinates):
	  north sidewalk Z 87.9..99.9 (top 0.4), south sidewalk Z 35.9..47.9 (top 0.4), road between (Ninth, 40 studs with the
	  parking lanes), CW-4 stripes X -24..-12 / Z 54.6..83.1, P-01 post (-18.7, 49.2) with the flyer at (-17.2, 4.5, 50.2) facing
	  (+0.71, -0.71): the stand is ~3 studs out of its face = (-15.1, 48.1). Obstacles measured (collidable parts in a 2.5 x 4 corridor
	  along every leg): the NE corner street sign at (-15, 87.7) and the P-01 pole at (-18.7, 51.2), so the walk crosses at X -21
	  on the north half and bends to X -15.5 before the south end (east of the pole), then goes straight to the stand.

	  point            world (x, y, z)        facing          use
	  CutsceneMark1    (-33, 0.4, 93.5)       +X (east)       party start slots, 2 x 2 (slot 1 = the player that made the party)
	  CutsceneMark2    (-33, 0.4, 90.5)       +X
	  CutsceneMark3    (-36, 0.4, 93.5)       +X
	  CutsceneMark4    (-36, 0.4, 90.5)       +X
	  CS-1             (-21, 0.4, 90)         -Z (south)      north curb, in line with the crosswalk (the walk turns here)
	  CS-2             (-21, 0.25, 66)        -Z              middle of the street (papers on the wind); the walk bends east here
	  CS-3             (-15.5, 0.3, 53.5)     -Z              south end of the stripes, east of the P-01 pole (then 5 studs to the stand)

	The old CS-P*, CS-4, CS-5, CS-5W, CS-5E, CS-6, CS-7 stay where they are (unused by the intro, harmless, delete when the finale
	is redone). CS-1..3 and the marks EXIST today (old positions): they are MOVED (same Part, same tags and attributes); a missing
	one is created (invisible, anchored, no collision/query/touch, tag MapPoint, attribute PointId). CS-1..3 and the marks are
	read only by the intro and by Ambience (PAPERS), checked with grep src/ 2026-10-12.

	The MapIndex caches positions at start: stop Play and start again after running. Undo: Ctrl+Z (waypoints
	"cutscene_points: before/after") or put the BEFORE values in TARGET and run again.
	Ordering: does not depend on the Pad's trailer (the end looks at TRL, not touched here).
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local DRY_RUN = false
local DONE = "CutsceneIntroD3b"
local EAST = Vector3.new(1, 0, 0) -- the walk direction along the north sidewalk (world +X)
local SOUTH = Vector3.new(0, 0, -1) -- the crossing direction (world -Z, towards the trailer's side)

local TARGET = {
	{ id = "CutsceneMark1", x = -33, y = 0.4, z = 93.5, dir = EAST },
	{ id = "CutsceneMark2", x = -33, y = 0.4, z = 90.5, dir = EAST },
	{ id = "CutsceneMark3", x = -36, y = 0.4, z = 93.5, dir = EAST },
	{ id = "CutsceneMark4", x = -36, y = 0.4, z = 90.5, dir = EAST },
	{ id = "CS-1", x = -21, y = 0.4, z = 90, dir = SOUTH },
	{ id = "CS-2", x = -21, y = 0.25, z = 66, dir = SOUTH },
	{ id = "CS-3", x = -15.5, y = 0.3, z = 53.5, dir = SOUTH },
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
	local want = Vector3.new(row.x, row.y, row.z)
	local cf = CFrame.lookAt(want, want + row.dir)
	local part = existing[row.id]
	if part then
		if (part.Position - want).Magnitude < 0.01 and part.CFrame.LookVector:Dot(row.dir) > 0.999 then
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

-- Sanity: TRL must exist (the end looks at it) and the flyer is the one measured above
local function exists(id: string): boolean
	local part = existing[id]
	return part ~= nil and part:IsDescendantOf(Workspace)
end
if not exists("TRL") then
	warn("cutscene_points: MapPoint TRL not found; the end of the intro has nothing to look at")
end
local flyer = Workspace:FindFirstChild("P-01_Flyer", true)
if flyer and flyer:IsA("BasePart") then
	local stand = flyer.Position + flyer.CFrame.LookVector * 3
	print(string.format("flyer P-01 at (%.1f, %.1f, %.1f); stand ~(%.1f, %.1f); CS-3 -> stand: %.1f studs", flyer.Position.X, flyer.Position.Y, flyer.Position.Z, stand.X, stand.Z, (Vector3.new(-15.5, 0, 53.5) - Vector3.new(stand.X, 0, stand.Z)).Magnitude))
else
	warn("cutscene_points: P-01_Flyer not found (the stand falls back to the P-01 post)")
end
print(string.format("cutscene_points: %d moved, %d created, %d already in place%s. Stop and restart Play to reload the MapIndex.", moved, created, skipped, if DRY_RUN then " (DRY RUN, nothing changed)" else ""))
