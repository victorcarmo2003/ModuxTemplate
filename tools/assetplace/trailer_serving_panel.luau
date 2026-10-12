--!nonstrict
--[[
	trailer_serving_panel.luau (owner request 2026-10-12: "open / close from the counter, not from the sign outside";
	Provisional). Edit-mode Studio snippet, NOT gameplay code. Idempotent, surgical, NO Place.run, nothing deleted.
	Undo: run("trailer_serving_panel", "undo").

	What it does:
	  1. Creates Model TRL-OPEN (MapId TRL-OPEN, BindCreated) inside the trailer Vehicle Model with an invisible plate and
	     the Attachment Prompt_Open (tag Interactable, PromptAction = open_sign) on the INNER face of the closed service flap
	     (Body-frame: the Shutter_Panel hangs down from Shutter_Hinge at the window plane when the shop is closed, VehicleController
	     lowers it while the shop is not selling and lifts it when the Open phase starts). The anchor is a fixed part: the flap
	     is moved on the client only, the server validates the distance against the fixed plate. Position = hinge + (0, -2.7, 0) - look * 0.3
	     (the middle of the hanging flap, 0.3 studs inside the window plane). Content.Actions open_sign: Hold 0.3, Radius 6.
	     Same action, same RoundService handler: no logic is duplicated. At night the existing button TRL-SHUTTER
	     (shutter_toggle, "Close Window") is untouched: the two prompts are on different anchors and different phases
	     (open_sign only in Prep; shutter_toggle only at night, any time the shift is on).
	  2. The Pad stand OPEN_AST-024_SignStand (and its Prompt_Open) -> ServerStorage.Trailer_Backup_20261012 with the gameplay
	     tags removed (OrigTags / OrigPath attributes), so no service scans a ghost and MapIndex counts a single open_sign.
	Returns a log.
]]

local CS = game:GetService("CollectionService")
local ST = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")
local UNDO = (...) == "undo"

local BK_NAME = "Trailer_Backup_20261012"
local MODEL = "TRL-OPEN"
local FLAP_DOWN = 2.7 -- studs under Shutter_Hinge: the middle of the hanging flap (flap height 5.4)
local INSIDE = 0.3 -- studs behind the window plane (toward the cook, against the trailer look direction)
local TAGS_OFF = { "Interactable", "OpenSignBoard" }
local log = {}
local function L(text)
	table.insert(log, text)
end
pcall(function()
	CHS:SetWaypoint("trailer_serving_panel: before")
end)

local trailer
for _, m in CS:GetTagged("Vehicle") do
	if m:IsDescendantOf(workspace) and m:GetAttribute("Vehicle") == "trailer" then
		trailer = m
	end
end
if not trailer then
	return "[err] no trailer Model in the Workspace"
end
local bk = ST:FindFirstChild(BK_NAME)

local function untag(inst)
	local tags = CS:GetTags(inst)
	local off = {}
	for _, t in tags do
		if table.find(TAGS_OFF, t) then
			table.insert(off, t)
		end
	end
	if #off > 0 then
		if inst:GetAttribute("OrigTags") == nil then
			inst:SetAttribute("OrigTags", table.concat(off, ","))
		end
		for _, t in off do
			CS:RemoveTag(inst, t)
		end
	end
end
local function retag(inst)
	local saved = inst:GetAttribute("OrigTags")
	if type(saved) == "string" then
		for t in string.gmatch(saved, "[^,]+") do
			CS:AddTag(inst, t)
		end
		inst:SetAttribute("OrigTags", nil)
	end
end

if UNDO then
	local made = trailer:FindFirstChild(MODEL)
	if made then
		made:Destroy()
		L("TRL-OPEN removed")
	end
	local stand = bk and bk:FindFirstChild("OPEN_AST-024_SignStand")
	if stand then
		stand.Parent = workspace
		for _, d in stand:GetDescendants() do
			retag(d)
		end
		retag(stand)
		L("stand restored to the Workspace")
	end
	return table.concat(log, "\n")
end

-- 1. the anchor on the closed flap
local hinge
for _, d in trailer:GetDescendants() do
	if d:IsA("Attachment") and d.Name == "Shutter_Hinge" then
		hinge = d
		break
	end
end
if not hinge then
	return "[err] Shutter_Hinge not found in the trailer"
end
-- the window faces the trailer pivot LookVector (world +Z with the trailer on the Pad); inside = against it
local pivot = trailer:GetPivot()
local at = hinge.WorldPosition + Vector3.new(0, -FLAP_DOWN, 0) - pivot.LookVector * INSIDE
local model = trailer:FindFirstChild(MODEL)
if not model then
	model = Instance.new("Model")
	model.Name = MODEL
	model:SetAttribute("MapId", MODEL)
	model:SetAttribute("BindCreated", true)
	-- Models with gameplay tags must be Persistent (check_map01 rule 5)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = trailer
	L("model created: " .. MODEL)
end
model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
local plate = model:FindFirstChild("Plate")
if not plate then
	plate = Instance.new("Part")
	plate.Name = "Plate"
	plate.Size = Vector3.new(0.4, 0.4, 0.1)
	plate.Transparency = 1
	plate.Anchored = true
	plate.CanCollide = false
	plate.CanQuery = false
	plate.CanTouch = false
	plate.CastShadow = false
	plate:SetAttribute("BindCreated", true)
	plate.Parent = model
end
plate.CFrame = CFrame.new(at) * (pivot - pivot.Position)
local anchor = plate:FindFirstChild("Prompt_Open")
if not anchor then
	anchor = Instance.new("Attachment")
	anchor.Name = "Prompt_Open"
	anchor:SetAttribute("BindCreated", true)
	anchor.Parent = plate
	L("anchor created: Prompt_Open")
end
anchor:SetAttribute("PromptAction", "open_sign")
CS:AddTag(anchor, "Interactable")
L(string.format("Prompt_Open at (%.2f, %.2f, %.2f)", at.X, at.Y, at.Z))

-- 2. the Pad stand -> backup
local stand = workspace:FindFirstChild("OPEN_AST-024_SignStand")
if stand then
	if not bk then
		bk = Instance.new("Folder")
		bk.Name = BK_NAME
		bk.Parent = ST
	end
	stand:SetAttribute("OrigPath", stand:GetFullName())
	for _, d in stand:GetDescendants() do
		untag(d)
	end
	untag(stand)
	stand.Parent = bk
	L("OPEN stand moved to the backup (tags off)")
end
pcall(function()
	CHS:SetWaypoint("trailer_serving_panel: after")
end)
return table.concat(log, "\n")
