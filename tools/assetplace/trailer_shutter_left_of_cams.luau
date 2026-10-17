--!nonstrict
--[[
	trailer_shutter_left_of_cams.luau (TASK-354; owner request 2026-10-17, Provisional). Edit-mode Studio snippet, NOT gameplay
	code. Idempotent, surgical, reversible, NO Place.run. run("assetplace/trailer_shutter_left_of_cams", "dry" | "undo" | nil).

	Moves the service window lever box (Model MapId TRL-SHUTTER inside the trailer Vehicle, with its Prompt_Shutter) from the
	east wall to the back wall, LEFT of the CCTV monitor (Workspace.SecurityCams.CCTV) as seen from inside the trailer, so the
	camera screen has the corner to itself. Nothing is rebuilt or renamed: one PivotTo of the whole Model, so Prompt_Shutter
	(child of Box) and every attribute / tag go with it; no code changes.

	Where: the lever's plate is flush with the back wall (raycast from inside, the CCTV and the lever excluded), GAP studs from the
	monitor's left edge, at the lever's current height. The box faces into the trailer (its old -X front becomes +Z).
	Everything is derived from the CCTV and the trailer at run time; nothing hard-coded except GAP and the facing turn.

	Marker (for undo): _SHL_OrigPivot (CFrame of the Model before the first run). A second run recomputes from the same marker,
	so it is idempotent. Undo: back to _SHL_OrigPivot, marker removed.
	Persists like trailer_door_switches.luau (STUDIO_LAYER.md): Place.run / Bind.run would recreate TRL-SHUTTER on the east wall;
	run this again after them. Save the place (Ctrl+S) after running.
]]

local CS = game:GetService("CollectionService")
local CHS = game:GetService("ChangeHistoryService")
local arg = (...)
local UNDO = arg == "undo"
local DRY = arg == "dry"

local SHUTTER_ID = "TRL-SHUTTER"
local MARK = "_SHL_OrigPivot"
local GAP = 0.6 -- studs between the CCTV's left edge and the lever plate
local TURN = CFrame.Angles(0, math.pi / 2, 0) -- old front (-X, east wall) -> +Z (back wall, into the trailer)

local lines = {}
local function log(kind, text)
	table.insert(lines, ("[%s] %s"):format(kind, text))
end

local trailer
for _, m in CS:GetTagged("Vehicle") do
	if m:IsDescendantOf(workspace) and m:GetAttribute("Vehicle") == "trailer" then
		trailer = m
	end
end
if not trailer then
	return "[err] no trailer Model (tag Vehicle, Vehicle = trailer) in the Workspace"
end
local shutter
for _, c in trailer:GetChildren() do
	if c:GetAttribute("MapId") == SHUTTER_ID then
		shutter = c
	end
end
local plate = shutter and shutter:FindFirstChild("Plate")
if not (shutter and plate and plate:IsA("BasePart")) then
	return "[err] TRL-SHUTTER (with its Plate) not found in the trailer"
end
local folder = workspace:FindFirstChild("SecurityCams")
local cctv = folder and folder:FindFirstChild("CCTV")
if not (cctv and cctv:IsA("Model")) then
	return "[err] Workspace.SecurityCams.CCTV not found (run security_cams.luau first)"
end

if UNDO then
	local orig = shutter:GetAttribute(MARK)
	if typeof(orig) ~= "CFrame" then
		return "[ok] nothing to undo (no " .. MARK .. ")"
	end
	CHS:SetWaypoint("trailer_shutter_left_of_cams: before undo")
	shutter:PivotTo(orig)
	shutter:SetAttribute(MARK, nil)
	CHS:SetWaypoint("trailer_shutter_left_of_cams: undo")
	return "[ok] TRL-SHUTTER back to " .. tostring(orig.Position)
end

-- the pose the lever had before this snippet ever ran (idempotent)
local origPivot = shutter:GetAttribute(MARK)
if typeof(origPivot) ~= "CFrame" then
	origPivot = shutter:GetPivot()
end

-- CCTV: its screen faces into the trailer; "left" for someone looking at it = the CCTV's own -RightVector seen from the
-- front. Front of the monitor = towards the trailer interior: the side of the wall where the trailer's centre is.
local camCf, camSize = cctv:GetBoundingBox()
local trailerCf = trailer:GetBoundingBox()
local toInside = trailerCf.Position - camCf.Position
local wallNormal = Vector3.new(0, 0, if toInside.Z >= 0 then 1 else -1) -- the back wall runs along X
local viewerRight = wallNormal:Cross(Vector3.yAxis) * -1 -- viewer looks along -wallNormal; right = look x up
local halfWidth = math.abs(camSize.X) / 2
-- plate extents in the world BEFORE the move (its depth runs along X on the east wall); the turn swaps X and Z
local function extent(part: BasePart, axis: Vector3): number
	local cf = part.CFrame
	return math.abs(cf.RightVector:Dot(axis)) * part.Size.X
		+ math.abs(cf.UpVector:Dot(axis)) * part.Size.Y
		+ math.abs(cf.LookVector:Dot(axis)) * part.Size.Z
end
local moved = typeof(shutter:GetAttribute(MARK)) == "CFrame"
local depthAlongOldNormal = if moved then extent(plate, Vector3.zAxis) else extent(plate, Vector3.xAxis)
local widthAlongWall = if moved then extent(plate, Vector3.xAxis) else extent(plate, Vector3.zAxis)

local centerAlongWall = camCf.Position - viewerRight * (halfWidth + GAP + widthAlongWall / 2)

-- wall surface: raycast from inside towards the wall, ignoring the lever and the monitor
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { shutter, cctv }
local from = Vector3.new(centerAlongWall.X, plate.Position.Y, camCf.Position.Z) + wallNormal * 3
local hit = workspace:Raycast(from, -wallNormal * 6, params)
if not hit then
	return ("[err] no wall found behind %s (raycast from %s)"):format(tostring(centerAlongWall), tostring(from))
end
local wallZ = hit.Position.Z

-- new plate centre: flush with the wall; the pivot keeps its old offset from the plate (turned with the Model)
local newPlateCenter = Vector3.new(centerAlongWall.X, plate.Position.Y, wallZ + wallNormal.Z * depthAlongOldNormal / 2)
local newRot = TURN * origPivot.Rotation
-- plate centre in the frame of the ORIGINAL pivot (the plate moved with the Model, so read it through the current pivot)
local platePosOld = shutter:GetPivot():PointToObjectSpace(plate.Position)
-- the pivot position that puts the turned plate on newPlateCenter
local pivotPos = newPlateCenter - newRot:VectorToWorldSpace(platePosOld)
local target = CFrame.new(pivotPos) * newRot

log("info", ("wall hit %s on %s; CCTV centre %s, width %.2f"):format(tostring(hit.Position), hit.Instance:GetFullName(), tostring(camCf.Position), camSize.X))
log("info", ("TRL-SHUTTER pivot %s -> %s"):format(tostring(shutter:GetPivot().Position), tostring(target.Position)))

-- something else already on that spot of the wall? (report only)
local box = OverlapParams.new()
box.FilterType = Enum.RaycastFilterType.Exclude
box.FilterDescendantsInstances = { shutter, cctv, hit.Instance }
local around = workspace:GetPartBoundsInBox(CFrame.new(newPlateCenter + wallNormal * 0.4), Vector3.new(widthAlongWall + 0.2, 1.5, 0.8), box)
for _, p in around do
	log("warn", "overlaps " .. p:GetFullName())
end

if DRY then
	return table.concat(lines, "\n")
end
CHS:SetWaypoint("trailer_shutter_left_of_cams: before")
if shutter:GetAttribute(MARK) == nil then
	shutter:SetAttribute(MARK, origPivot)
end
shutter:PivotTo(target)
local prompt = shutter:FindFirstChild("Prompt_Shutter", true)
if prompt and prompt:IsA("Attachment") then
	log("ok", "Prompt_Shutter now at " .. tostring(prompt.WorldPosition))
end
CHS:SetWaypoint("trailer_shutter_left_of_cams: moved")
log("ok", "moved; save the place (Ctrl+S)")
return table.concat(lines, "\n")
