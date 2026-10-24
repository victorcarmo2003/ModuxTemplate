--!nocheck
--[[
	walt_park_points.luau - SURGICAL and IDEMPOTENT Studio patch (TASK-645, DEC-369 / DEC-371 / DEC-374; level-designer,
	2026-10-23, all positions Provisional). NOT a Place.run: it only creates or moves MapPoint Parts in
	workspace.MapBinding.Points (tag MapPoint, attribute PointId), the folder the MapIndex and the cutscenes read.
	Edit mode. Load with tools/studio/README.md: run("assetplace/walt_park_points")            -- apply
	                                            run("assetplace/walt_park_points", "dry")     -- only print
	                                            run("assetplace/walt_park_points", "undo")    -- remove what it created
	Safe to run twice: a point already within 0.01 studs / 0.999 facing of its target is skipped.

	Points (MAP-01 coordinates: +X east, +Z south; world = (-x, y, K - z), K = 67.887287, tools/assetplace/map_frame.luau).
	Full table, sight lines and reasons: docs/levels/MAP-01-r4-restaurant.md §17.

	  id          MAP (x, z)          faces                     read by
	  WALT-PARK   (66, -46)           the counter (42.5, 56)     WaltWatch (Content.WaltWatch.Rules.Point, TASK-646/647)
	                                                             + post-credits: the player stands here (TASK-658)
	  DOG-1       (19, 6)             DOG-2                      post-credits: the dog starts on the CW-4 stripes
	  DOG-2       flyer + 3 studs     the flyer (P-01_Flyer)     post-credits: the dog stops and reads
	              (fallback (33.1, 17.8), same stand as the intro)
	  WALT-DAY-1  (14, -25)           east                       post-credits: day Walt, north sidewalk of the Ninth
	  WALT-DAY-2  (100, -25)          east                       (walks west -> east, in front of the parking lot)
	  PC-CAM      (24, y 6, 26)       yaw 40 deg E of N,         post-credits camera; attribute Fov = 40
	                                  pitch -8 deg

	Y: each ground point is raycast down (ignoring MapBinding, characters and non-collidable parts) and sits on what it hits;
	without a hit it uses the table floor. PC-CAM keeps its fixed Y (6).
	After the points: sight checks (raycasts, printed only, nothing is changed) from the counter poses and from PC-CAM.
	The MapIndex caches positions at start: stop Play and start again after running.
	Marker: attribute _WaltPark = true on every Part this snippet created (undo removes only those; moved points keep it too,
	undo does NOT move them back - use Ctrl+Z, waypoints "walt_park_points: before/after").
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local arg = (...)
local DRY = arg == "dry"
local UNDO = arg == "undo"
local MARK = "_WaltPark"
local CREATED = "_WaltParkCreated"

local K = 67.887287
local function F(x: number, y: number, z: number): Vector3 -- MAP point -> world
	return Vector3.new(-x, y, K - z)
end
local function FD(x: number, y: number, z: number): Vector3 -- MAP direction -> world
	return Vector3.new(-x, y, -z)
end

local COUNTER = Vector3.new(42.5, 0, 56) -- MAP, middle of the front counter (Walt looks at the shop)
local FLYER_STAND = 3 -- studs out of the flyer face (same as the intro stand CS-P*)

local binding = Workspace:FindFirstChild("MapBinding")
local pointsFolder = binding and binding:FindFirstChild("Points")
if not pointsFolder then
	error("walt_park_points: workspace.MapBinding.Points not found (run bind_map01 first)")
end

local existing: { [string]: BasePart } = {}
for _, part in CollectionService:GetTagged("MapPoint") do
	local id = part:GetAttribute("PointId")
	if part:IsA("BasePart") and typeof(id) == "string" and part:IsDescendantOf(Workspace) then
		existing[id] = part
	end
end

if UNDO then
	ChangeHistoryService:SetWaypoint("walt_park_points: before undo")
	local n = 0
	for _, part in pointsFolder:GetChildren() do
		if part:GetAttribute(CREATED) == true then
			part:Destroy()
			n += 1
		end
	end
	ChangeHistoryService:SetWaypoint("walt_park_points: after undo")
	print(("walt_park_points: undo removed %d created points"):format(n))
	return n
end

-- ground under a world XZ (ignores MapBinding, characters and parts players walk through)
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local ignore = { binding }
for _, p in Players:GetPlayers() do
	if p.Character then
		table.insert(ignore, p.Character)
	end
end
params.FilterDescendantsInstances = ignore
params.RespectCanCollide = true

local function ground(world: Vector3, fallbackY: number): number
	local hit = Workspace:Raycast(Vector3.new(world.X, 60, world.Z), Vector3.new(0, -120, 0), params)
	if hit then
		return hit.Position.Y
	end
	warn(("walt_park_points: no ground under (%.1f, %.1f), using y %.2f"):format(world.X, world.Z, fallbackY))
	return fallbackY
end

-- flat facing from a MAP point to a MAP point, as a world direction
local function faceTo(ax: number, az: number, bx: number, bz: number): Vector3
	return FD(bx - ax, 0, bz - az).Unit
end

-- DOG-2: in front of the flyer face (the owner moved it by hand; never hard-code it when it exists)
local dog2World: Vector3
local dog2Dir: Vector3
local flyer = Workspace:FindFirstChild("P-01_Flyer", true)
if flyer and flyer:IsA("BasePart") then
	local look = Vector3.new(flyer.CFrame.LookVector.X, 0, flyer.CFrame.LookVector.Z).Unit
	local stand = flyer.Position + look * FLYER_STAND
	dog2World = Vector3.new(stand.X, 0, stand.Z)
	dog2Dir = -look
	print(("flyer P-01_Flyer at world (%.1f, %.1f, %.1f); DOG-2 stand world (%.1f, %.1f)"):format(flyer.Position.X, flyer.Position.Y, flyer.Position.Z, stand.X, stand.Z))
else
	warn("walt_park_points: P-01_Flyer not found; DOG-2 uses the fallback MAP (33.1, 17.8) facing east")
	dog2World = F(33.1, 0, 17.8)
	dog2Dir = FD(1, 0, 0)
end

local dog2MapX, dog2MapZ = -dog2World.X, K - dog2World.Z

-- yaw 40 deg east of north (MAP north = -Z), pitch -8 deg
local yaw, pitch = math.rad(40), math.rad(-8)
local camDirMap = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch))

local TARGET = {
	{ id = "WALT-PARK", pos = F(66, 0, -46), floor = 0.02, dir = faceTo(66, -46, COUNTER.X, COUNTER.Z) },
	{ id = "DOG-1", pos = F(19, 0, 6), floor = 0.25, dir = faceTo(19, 6, dog2MapX, dog2MapZ) },
	{ id = "DOG-2", pos = dog2World, floor = 0.3, dir = dog2Dir },
	{ id = "WALT-DAY-1", pos = F(14, 0, -25), floor = 0.4, dir = FD(1, 0, 0) },
	{ id = "WALT-DAY-2", pos = F(100, 0, -25), floor = 0.4, dir = FD(1, 0, 0) },
	{ id = "PC-CAM", pos = F(24, 6, 26), fixedY = true, dir = FD(camDirMap.X, camDirMap.Y, camDirMap.Z).Unit, fov = 40 },
}

if not DRY then
	ChangeHistoryService:SetWaypoint("walt_park_points: before")
end

local moved, created, skipped = 0, 0, 0
local final: { [string]: Vector3 } = {}
for _, row in TARGET do
	local want = row.pos
	if not row.fixedY then
		want = Vector3.new(want.X, ground(want, row.floor), want.Z)
	end
	final[row.id] = want
	local cf = CFrame.lookAt(want, want + row.dir)
	local part = existing[row.id]
	if part then
		if (part.Position - want).Magnitude < 0.01 and part.CFrame.LookVector:Dot(row.dir) > 0.999 then
			skipped += 1
			print(("%s already at (%.2f, %.2f, %.2f)"):format(row.id, want.X, want.Y, want.Z))
		else
			print(("%s: (%.2f, %.2f, %.2f) -> (%.2f, %.2f, %.2f)%s"):format(row.id, part.Position.X, part.Position.Y, part.Position.Z, want.X, want.Y, want.Z, if DRY then " [dry]" else ""))
			if not DRY then
				part.CFrame = cf -- same Part: tags and attributes stay
				part:SetAttribute(MARK, true)
				if row.fov then
					part:SetAttribute("Fov", row.fov)
				end
			end
			moved += 1
		end
	else
		print(("%s: created at (%.2f, %.2f, %.2f)%s"):format(row.id, want.X, want.Y, want.Z, if DRY then " [dry]" else ""))
		if not DRY then
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
			p:SetAttribute(MARK, true)
			p:SetAttribute(CREATED, true)
			if row.fov then
				p:SetAttribute("Fov", row.fov)
			end
		end
		created += 1
	end
end

if not DRY then
	ChangeHistoryService:SetWaypoint("walt_park_points: after")
end

-- Sight checks (print only). A hit names the first collider/queryable part between the eye and the target.
local sight = RaycastParams.new()
sight.FilterType = Enum.RaycastFilterType.Exclude
sight.FilterDescendantsInstances = ignore

local function check(label: string, from: Vector3, to: Vector3)
	local hit = Workspace:Raycast(from, to - from, sight)
	if hit then
		print(("  [blocked] %s: %s at %.1f of %.1f studs"):format(label, hit.Instance:GetFullName(), (hit.Position - from).Magnitude, (to - from).Magnitude))
	else
		print(("  [clear]   %s (%.1f studs)"):format(label, (to - from).Magnitude))
	end
end

local park = final["WALT-PARK"]
print("Sight to WALT-PARK (eye 4.95 over the kitchen floor; the figure at 3 and 6 over its ground):")
for _, pose in { { "PICKUP pose", 36, 56.6 }, { "counter middle", 45, 56.6 }, { "TAB-1 pose", 56.5, 56.6 }, { "tip jar pose", 27.5, 56.6 } } do
	local eye = F(pose[2], 4.95, pose[3])
	check(pose[1] .. " -> WALT-PARK chest", eye, park + Vector3.new(0, 3, 0))
	check(pose[1] .. " -> WALT-PARK head", eye, park + Vector3.new(0, 6, 0))
end
local cam = final["PC-CAM"]
print("Sight from PC-CAM:")
for _, id in { "WALT-PARK", "DOG-1", "DOG-2", "WALT-DAY-1", "WALT-DAY-2" } do
	check("PC-CAM -> " .. id, cam, final[id] + Vector3.new(0, 2.5, 0))
end
if flyer and flyer:IsA("BasePart") then
	check("PC-CAM -> flyer", cam, flyer.Position)
end
-- distances the design relies on (MAP-01-r4 §17.3)
print(("WALT-PARK -> counter middle: %.1f studs (>= 25)"):format((Vector3.new(park.X, 0, park.Z) - Vector3.new(F(45, 0, 56).X, 0, F(45, 0, 56).Z)).Magnitude))

print(("walt_park_points: %d moved, %d created, %d already in place%s. Stop and restart Play to reload the MapIndex."):format(moved, created, skipped, if DRY then " (DRY RUN, nothing changed)" else ""))
return { moved = moved, created = created, skipped = skipped }
