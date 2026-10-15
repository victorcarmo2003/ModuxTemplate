--!nonstrict
--[[
	trailer_remove_open_switch.luau (TASK-284, owner request 2026-10-14; Provisional).
	Edit-mode Studio snippet, NOT gameplay code. Idempotent, surgical, NO Place.run, nothing deleted.
	Undo: run("trailer_remove_open_switch", "undo").

	The red "Open Shop" switch (TRL-SWITCH-OPEN_AST-039_LightSwitch, anchor Prompt_Open, PromptAction open_sign) leaves the
	trailer: the service window lever TRL-SHUTTER next to the phone is the shop now. The model moves to
	ServerStorage.Trailer_Backup_20261014 with its tags taken off (saved in OrigTags, OrigPath on the model), so MapIndex
	and the clients see no open_sign anchor. The blue light switch (TRL-SWITCH) and TRL-SHUTTER are not touched.
	Do not run trailer_open_switch / trailer_door_switches again: they would put the red switch back.
	Returns a log.
]]

local CS = game:GetService("CollectionService")
local ST = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")
local UNDO = (...) == "undo"

local BK_NAME = "Trailer_Backup_20261014"
local OPEN_ID = "TRL-SWITCH-OPEN"
local log = {}
local function L(text)
	table.insert(log, text)
end
pcall(function()
	CHS:SetWaypoint("trailer_remove_open_switch: before")
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

local function untag(inst)
	local tags = CS:GetTags(inst)
	if #tags > 0 then
		inst:SetAttribute("OrigTags", table.concat(tags, ","))
		for _, t in tags do
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

local bk = ST:FindFirstChild(BK_NAME)

if UNDO then
	local saved = bk and bk:FindFirstChild("TRL-SWITCH-OPEN_AST-039_LightSwitch")
	if not saved then
		return "nothing to undo (no backup of TRL-SWITCH-OPEN)"
	end
	saved.Parent = trailer
	retag(saved)
	for _, d in saved:GetDescendants() do
		retag(d)
	end
	saved:SetAttribute("OrigPath", nil)
	L("TRL-SWITCH-OPEN back in the trailer")
	pcall(function()
		CHS:SetWaypoint("trailer_remove_open_switch: undo")
	end)
	return table.concat(log, "\n")
end

local found = {}
for _, c in trailer:GetChildren() do
	if c:GetAttribute("MapId") == OPEN_ID then
		table.insert(found, c)
	end
end
if #found == 0 then
	return "already done: no TRL-SWITCH-OPEN in the trailer" .. (if bk then " (backup in ServerStorage." .. BK_NAME .. ")" else "")
end
if not bk then
	bk = Instance.new("Folder")
	bk.Name = BK_NAME
	bk.Parent = ST
	L("created ServerStorage." .. BK_NAME)
end
for _, model in found do
	model:SetAttribute("OrigPath", model:GetFullName())
	untag(model)
	for _, d in model:GetDescendants() do
		untag(d)
	end
	model.Parent = bk
	L(model.Name .. " moved to ServerStorage." .. BK_NAME .. " (tags off)")
end
pcall(function()
	CHS:SetWaypoint("trailer_remove_open_switch: after")
end)
return table.concat(log, "\n")
