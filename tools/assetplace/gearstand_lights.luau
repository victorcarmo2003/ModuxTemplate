--!nonstrict
--[[
	gearstand_lights.luau (owner request 2026-10-20: "a lojinha de upgrade está muito escura"; approved in Play the same day).
	Edit-mode Studio snippet, NOT gameplay code. Idempotent and reversible.
	run("assetplace/gearstand_lights", "dry" | "undo" | nil)

	The Gear Stand (Workspace.MAP01_Assets...GearStand, AST-104, front +Z) had no light of its own: at night it only got the
	trailer's spill. This adds, inside the GearStand model (so it moves with it), one Folder `GearLights` (marker _GSL_Created):
	  * 3 SpotLights under the roof (y 10.6, 0.4 in front of the stand centre), pointing down over the six pedestals;
	  * 1 PointLight 7 studs in front of the facade, for the shutters / sign.
	Positions are world-axis offsets from the Structure centre (the stand faces world +Z); a moved stand keeps fitting, a
	rotated one needs new offsets. No shadows (light budget).
	A Place.run rebuilds MAP01_Assets and drops the folder: run this snippet again after Place.run + Bind.run.
]]

local CHS = game:GetService("ChangeHistoryService")

local arg = (...)
local UNDO = arg == "undo"
local DRY = arg == "dry"

local FOLDER = "GearLights"
local MARK = "_GSL_Created"
local WARM = Color3.fromHex("FFE2B8")

-- offsets from the Structure centre (stand space: +Z = front), approved in Play 2026-10-20
local SPOTS = {
	{ Offset = Vector3.new(-7.5, 4.57, 1.6), Brightness = 2.2, Range = 12, Angle = 110 },
	{ Offset = Vector3.new(0, 4.57, 1.6), Brightness = 2.2, Range = 12, Angle = 110 },
	{ Offset = Vector3.new(7.5, 4.57, 1.6), Brightness = 2.2, Range = 12, Angle = 110 },
}
local FRONT = { Offset = Vector3.new(0, 3.47, 7), Brightness = 1.2, Range = 18 }

local stand = workspace:FindFirstChild("MAP01_Assets") and workspace.MAP01_Assets:FindFirstChild("GearStand", true)
if not stand then
	return "[err] no MAP01_Assets...GearStand"
end
local structure = stand:FindFirstChild("Structure")
if not structure or not structure:IsA("BasePart") then
	return "[err] GearStand has no Structure part"
end

local existing = stand:FindFirstChild(FOLDER)
if UNDO then
	if existing and existing:GetAttribute(MARK) then
		existing:Destroy()
		CHS:SetWaypoint("gearstand_lights undo")
		return "[ok] GearLights removed"
	end
	return "[ok] nothing to undo"
end
if DRY then
	return if existing then "[dry] GearLights present (would be rebuilt)" else "[dry] would create GearLights (3 spots + 1 front)"
end
if existing then
	existing:Destroy()
end

local base = CFrame.new(structure.Position) -- world axes: the stand faces world +Z (2026-10-20)
local folder = Instance.new("Folder")
folder.Name = FOLDER
folder:SetAttribute(MARK, true)

local function anchor(name: string, offset: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Locked = true
	part.CFrame = CFrame.new((base * CFrame.new(offset)).Position)
	part.Parent = folder
	return part
end

for i, row in SPOTS do
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = row.Angle
	light.Brightness = row.Brightness
	light.Range = row.Range
	light.Color = WARM
	light.Shadows = false
	light.Parent = anchor(`GearLight_Spot{i}`, row.Offset)
end
local front = Instance.new("PointLight")
front.Brightness = FRONT.Brightness
front.Range = FRONT.Range
front.Color = WARM
front.Shadows = false
front.Parent = anchor("GearLight_Front", FRONT.Offset)

folder.Parent = stand
CHS:SetWaypoint("gearstand_lights")
return "[ok] GearLights: 3 spots + 1 front in " .. stand:GetFullName()
