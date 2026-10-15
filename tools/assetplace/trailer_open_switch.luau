--!nonstrict
--[[
	OBSOLETE for the red switch since TASK-284 (2026-10-14): trailer_remove_open_switch.luau took TRL-SWITCH-OPEN out; do not re-run.
	trailer_open_switch.luau (owner request 2026-10-12: "second switch in the trailer: Open Shop / Close Shop"; Provisional).
	Edit-mode Studio snippet, NOT gameplay code. Idempotent, surgical, NO Place.run, nothing deleted (backup in
	ServerStorage). Undo: run("trailer_open_switch", "undo").

	What it does:
	  1. Clones the light switch (TRL-SWITCH, AST-039 LightSwitch) as TRL-SWITCH-OPEN, 5.1 studs along the wall (toward
	     +X, past the yellow TRL-SHUTTER button). Its anchor Prompt_Open (tag Interactable) has PromptAction open_sign
	     (RoundService: Open Shop in Prep, Close Shop / Open Shop during the Open phase).
	  2. Colours: the OPEN switch is RED, the LIGHT switch BLUE (the Lever goes solid: TextureID cleared + Color, because
	     MeshPart.Color has no effect over a TextureID; MeshId untouched; Box and pilot lamp keep the atlas). The originals
	     are saved in the attributes OrigColor / OrigTexture.
	  3. The old serving-window prompt TRL-OPEN (Plate.Prompt_Open) leaves the trailer: tags off, model moved to
	     ServerStorage.Trailer_Backup_20261012 (OrigTags / OrigPath), so MapIndex counts a single open_sign.
	Returns a log.
]]

local CS = game:GetService("CollectionService")
local ST = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")
local UNDO = (...) == "undo"

local BK_NAME = "Trailer_Backup_20261012"
local LIGHT_ID, OPEN_ID = "TRL-SWITCH", "TRL-SWITCH-OPEN"
local OLD_OPEN = "TRL-OPEN"
local GAP = 5.1 -- studs from the light switch to the shop switch (the yellow TRL-SHUTTER button is at 2.6)
local RED = Color3.fromRGB(235, 70, 60)
local BLUE = Color3.fromRGB(70, 130, 245)
local TINTED = { "Lever" } -- MeshPart.Color is ignored while a TextureID is set: the lever becomes a solid colour
local log = {}
local function L(text)
	table.insert(log, text)
end
pcall(function()
	CHS:SetWaypoint("trailer_open_switch: before")
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
local function byMapId(id)
	for _, c in trailer:GetChildren() do
		if c:GetAttribute("MapId") == id then
			return c
		end
	end
end
local function tint(model, color)
	for _, name in TINTED do
		local part = model:FindFirstChild(name)
		if part and part:IsA("MeshPart") then
			if part:GetAttribute("OrigColor") == nil then
				part:SetAttribute("OrigColor", part.Color)
				part:SetAttribute("OrigTexture", part.TextureID)
			end
			part.TextureID = ""
			part.Color = color
		end
	end
end
local function untint(model)
	for _, name in TINTED do
		local part = model:FindFirstChild(name)
		local orig = part and part:GetAttribute("OrigColor")
		if orig then
			part.Color = orig
			part.TextureID = part:GetAttribute("OrigTexture") or ""
			part:SetAttribute("OrigColor", nil)
			part:SetAttribute("OrigTexture", nil)
		end
	end
end
local TAGS_OFF = { "Interactable" }
local function untag(inst)
	local off = {}
	for _, t in CS:GetTags(inst) do
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

local light = byMapId(LIGHT_ID)
if not light then
	return "[err] TRL-SWITCH (light switch) not found in the trailer"
end
local bk = ST:FindFirstChild(BK_NAME)

if UNDO then
	local made = byMapId(OPEN_ID)
	if made then
		made:Destroy()
		L("TRL-SWITCH-OPEN removed")
	end
	untint(light)
	L("light switch colours restored")
	local old = bk and bk:FindFirstChild(OLD_OPEN)
	if old and not trailer:FindFirstChild(OLD_OPEN) then
		old.Parent = trailer
		for _, d in old:GetDescendants() do
			retag(d)
		end
		L("TRL-OPEN restored")
	end
	return table.concat(log, "\n")
end

-- 1. the shop switch
local open = byMapId(OPEN_ID)
local box = light:FindFirstChild("Box")
if not box then
	return "[err] the light switch has no Box"
end
if not open then
	open = light:Clone()
	open.Name = "TRL-SWITCH-OPEN_AST-039_LightSwitch"
	open:SetAttribute("MapId", OPEN_ID)
	-- the clone must not answer to the light action
	local oldAnchor = open:FindFirstChild("Prompt_Switch", true)
	if oldAnchor then
		oldAnchor.Name = "Prompt_Open"
	end
	open.Parent = trailer
	L("clone created: " .. OPEN_ID)
end
-- along the wall to +X, same height and face (every run: idempotent)
do
	local dir = box.CFrame.RightVector
	if dir.X < 0 then
		dir = -dir
	end
	open:PivotTo(light:GetPivot() + dir * GAP)
end
local anchor = open:FindFirstChild("Prompt_Open", true)
if not anchor then
	return "[err] Prompt_Open missing in the clone"
end
anchor:SetAttribute("PromptAction", "open_sign")
anchor:SetAttribute("BindCreated", true)
anchor:SetAttribute("EntityId", nil)
anchor:SetAttribute("PromptEnabled", nil)
anchor:SetAttribute("PromptText", nil)
CS:AddTag(anchor, "Interactable")
open.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
-- the pivot of a MeshPart model
L(string.format("Prompt_Open at (%.2f, %.2f, %.2f)", anchor.WorldPosition.X, anchor.WorldPosition.Y, anchor.WorldPosition.Z))

-- 2. colours
tint(open, RED)
tint(light, BLUE)
L("open switch RED, light switch BLUE")

-- 3. the old serving-window prompt
local old = trailer:FindFirstChild(OLD_OPEN)
if old then
	if not bk then
		bk = Instance.new("Folder")
		bk.Name = BK_NAME
		bk.Parent = ST
	end
	old:SetAttribute("OrigPath", old:GetFullName())
	for _, d in old:GetDescendants() do
		untag(d)
	end
	untag(old)
	old.Parent = bk
	L("TRL-OPEN moved to the backup (tags off)")
end

pcall(function()
	CHS:SetWaypoint("trailer_open_switch: after")
end)
return table.concat(log, "\n")
