--!strict
-- TASK-272 (V2 family B "something is coming", DEC-254/255): creates the hiding spot behind the trailer, an invisible
-- Part `HideZone_Back` tagged `HideZone` (attribute HideZone = true) that AnomalyService/Anomalies/Kit/Hide.luau tests.
-- Run in Studio EDIT mode (command bar or MCP execute_luau) with the Rojo sync on, then save the place. Idempotent:
-- run again and the same Part is moved/resized (found by name), never duplicated.
--
-- Where (MAP-01, trailer TRL on the Pad, pivot (40, 41), window to the north, back door X 47..51 on the south wall
-- Z 47): the zone is centred BEHIND the trailer, BACK studs from the pivot on the side away from the window (towards
-- the south) and SIDE studs towards the back door (east), so leaving by the back door puts you in it in 1-2 s.
-- The window side is the direction TRL -> WALKER-10 (across the Ninth), the same rule the client uses for the path.
-- After running: look at it from the back door in Studio; the art-director can later dress it as crates / bins
-- (the Part stays invisible and keeps the tag). Size is Provisional (registered in the day's log).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)

local NAME = "HideZone_Back"
local TAG = "HideZone"
local BACK = 10.5 -- studs from the pivot to the zone centre (back wall ~6, zone 9 deep)
local SIDE = 6 -- studs towards the back door (east)
local SIZE = Vector3.new(14, 8, 9) -- along the back wall, height, depth

MapIndex.Refresh()
local trailer = MapIndex.FindPoint("TRL")
assert(trailer, "MapPoint TRL not found (bind MAP-01 first)")
local across = MapIndex.FindPoint("WALKER-10")
local out = if across then across.Position - trailer.Position else trailer.LookVector
out = Vector3.new(out.X, 0, out.Z).Unit
local side = out:Cross(Vector3.yAxis).Unit
local centre = trailer.Position - out * BACK + side * SIDE + Vector3.new(0, SIZE.Y / 2, 0)

local root = workspace:FindFirstChild("MapBinding") or workspace
local folder = root:FindFirstChild("Anomaly")
if folder == nil then
	folder = Instance.new("Folder")
	folder.Name = "Anomaly"
	folder.Parent = root
end

local zone = workspace:FindFirstChild(NAME, true)
if zone == nil or not zone:IsA("BasePart") then
	zone = Instance.new("Part")
	zone.Name = NAME
end
local part = zone :: BasePart
part.Size = SIZE
part.CFrame = CFrame.lookAt(centre, centre + out)
part.Anchored = true
part.CanCollide = false
part.CanQuery = false
part.CanTouch = false
part.CastShadow = false
part.Transparency = 1
part.Locked = true
part:SetAttribute("HideZone", true)
CollectionService:AddTag(part, TAG)
part.Parent = folder
return `{NAME} at {math.round(centre.X * 10) / 10}, {math.round(centre.Z * 10) / 10} ({SIZE.X} x {SIZE.Z}); save the place`
