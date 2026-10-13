--!nonstrict
--[[
	trailer_door_switches.luau (owner request 2026-10-12; Provisional). Edit-mode Studio snippet, NOT gameplay code.
	Idempotent, surgical, NO Place.run, nothing deleted (the old shutter button goes to ServerStorage.Trailer_Backup_20261012).
	Everything it touches is marked with the attribute MovedBy = "trailer_door_switches".
	Undo: run("trailer_door_switches", "undo") (open switch back to +5.1, old yellow button back, new shutter box and the door
	prompt / tag removed).

	What it does (all inside the trailer Vehicle Model):
	  1. SHUTTER (shutter_toggle, DEC-221). The yellow block (TRL-SHUTTER.Button, 0.5 x 0.7 x 0.15 plate next to the light
	     switch) was the shutter button. It leaves the back wall and is rebuilt as a small control box on the EAST wall next to
	     the service window (where the cooks stand): Steel plate, a Cream window icon with three Mustard slats on top, and below
	     it the same Box / Lever / PilotLamp meshes of the AST-039 light switch (Lever Mustard, lamp Teal), so it reads as part of
	     the same family of switches. Same Model name / MapId (TRL-SHUTTER), same Attachment Prompt_Shutter (Interactable,
	     PromptAction shutter_toggle) 0.83 studs in front of the box, so nothing in the code changes.
	  2. OPEN / CLOSE SHOP switch (open_sign, TRL-SWITCH-OPEN) takes the place of the yellow block: 2.6 studs from the light
	     switch (same height, same wall), as the shutter button had been.
	  3. TRAILER DOOR. The leaf Body.Door_Back (with Door_Glass) gets the tag ScriptedDoor and the attributes DoorHinge =
	     "Right" (the west edge, away from the switches) and DoorAngle = 80: DoorController swings it while TrailerDoorService
	     sets DoorOpen on the trailer Model. The authored Attachment Prompt_ExitTrailer (Interactable, PromptAction
	     trailer_exit) sits inside the door, on Body (it never moves with the leaf). Prompt_EnterTrailer stays runtime-made by
	     TrailerDoorService (outside, west strip: nothing of the trailer is there to hang it on).
	Returns a log.
]]

local CS = game:GetService("CollectionService")
local ST = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")
local UNDO = (...) == "undo"

local MARK = "trailer_door_switches"
local BK_NAME = "Trailer_Backup_20261012"
local LIGHT_ID, OPEN_ID, SHUTTER_ID = "TRL-SWITCH", "TRL-SWITCH-OPEN", "TRL-SHUTTER"
local OPEN_GAP = 2.6 -- studs from the light switch: the old yellow block's spot
local OLD_OPEN_GAP = 5.1
local MUSTARD = Color3.fromRGB(246, 193, 43) -- #F6C12B
local CREAM = Color3.fromRGB(255, 241, 214) -- #FFF1D6
local STEEL = Color3.fromRGB(201, 209, 216) -- #C9D1D8
local TEAL = Color3.fromRGB(63, 167, 181) -- #3FA7B5
-- Shutter box: east wall, next to the window end. Local frame of the box: front (+Z) = world -X (into the trailer).
local WALL_CENTER = Vector3.new(-32.3, 4.93, 12.6) -- plate centre (plate depth 0.5: front face at x = -32.55)
local FACE = CFrame.Angles(0, -math.pi / 2, 0)
-- Door_Back: centre (-53.92, 4.22, 5.92), 0.75 thick (faces at z 6.30 inside / 5.55 outside). Prompts hug the leaf at
-- mid height (radius 1.4 in Content.Actions): one on each face, both children of Body (the leaf moves on the client only)
local DOOR_PROMPT = Vector3.new(-53.92, 4.3, 6.45)
local DOOR_PROMPT_OUT = Vector3.new(-53.92, 4.3, 5.4)
local log = {}
local function L(text)
	table.insert(log, text)
end
pcall(function()
	CHS:SetWaypoint("trailer_door_switches: before")
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
local bk = ST:FindFirstChild(BK_NAME)
if not bk then
	bk = Instance.new("Folder")
	bk.Name = BK_NAME
	bk.Parent = ST
end
local function untag(inst)
	local off = {}
	for _, t in CS:GetTags(inst) do
		if t == "Interactable" then
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
local open = byMapId(OPEN_ID)
local body = trailer:FindFirstChild("Body")
local door = body and body:FindFirstChild("Door_Back")
if not (light and open and body and door) then
	return "[err] light switch / open switch / Body / Door_Back missing in the trailer"
end
local lightBox = light:FindFirstChild("Box")
local function place(model, gap)
	local dir = lightBox.CFrame.RightVector
	if dir.X < 0 then
		dir = -dir
	end
	model:PivotTo(light:GetPivot() + dir * gap)
end

if UNDO then
	place(open, OLD_OPEN_GAP)
	open:SetAttribute("MovedBy", nil)
	L("open switch back at +" .. OLD_OPEN_GAP)
	local mine = byMapId(SHUTTER_ID)
	if mine and mine:GetAttribute("MovedBy") == MARK then
		mine:Destroy()
		L("new shutter box removed")
	end
	local old = bk:FindFirstChild("TRL-SHUTTER_OLD")
	if old and not byMapId(SHUTTER_ID) then
		old.Name = "TRL-SHUTTER"
		old.Parent = trailer
		for _, d in old:GetDescendants() do
			retag(d)
		end
		L("old yellow button restored")
	end
	for _, n in { "Prompt_ExitTrailer", "Prompt_EnterTrailer" } do
		local prompt = body:FindFirstChild(n)
		if prompt and prompt:GetAttribute("MovedBy") == MARK then
			prompt:Destroy()
			L(n .. " removed")
		end
	end
	CS:RemoveTag(door, "ScriptedDoor")
	door:SetAttribute("DoorHinge", nil)
	door:SetAttribute("DoorAngle", nil)
	L("Door_Back: tag and attributes removed")
	return table.concat(log, ", ")
end

-- 2. open switch where the yellow block was (every run: idempotent)
place(open, OPEN_GAP)
open:SetAttribute("MovedBy", MARK)
L(string.format("open switch at x %.2f (light switch at x %.2f)", open:GetPivot().X, light:GetPivot().X))

-- 1. the shutter box
local shutter = byMapId(SHUTTER_ID)
if shutter and shutter:GetAttribute("MovedBy") ~= MARK then
	-- the old yellow block: tags off, to the backup
	shutter:SetAttribute("OrigPath", shutter:GetFullName())
	for _, d in shutter:GetDescendants() do
		untag(d)
	end
	untag(shutter)
	shutter.Name = "TRL-SHUTTER_OLD"
	shutter.Parent = bk
	L("old yellow shutter button moved to ServerStorage." .. BK_NAME)
	shutter = nil
end
if shutter then
	shutter:Destroy() -- rebuilt below with the current numbers (idempotent)
end
do
	local model = Instance.new("Model")
	model.Name = SHUTTER_ID
	model:SetAttribute("MapId", SHUTTER_ID)
	model:SetAttribute("BindCreated", true)
	model:SetAttribute("MovedBy", MARK)
	local base = CFrame.new(WALL_CENTER) * FACE
	local function part(name, size, offset, color, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = base * CFrame.new(offset)
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Parent = model
		return p
	end
	part("Plate", Vector3.new(0.95, 1.35, 0.5), Vector3.new(0, 0, 0), STEEL)
	part("IconFrame", Vector3.new(0.72, 0.38, 0.05), Vector3.new(0, 0.46, 0.26), CREAM)
	for i = -1, 1 do
		part("Slat" .. (i + 2), Vector3.new(0.58, 0.07, 0.02), Vector3.new(0, 0.46 + i * 0.12, 0.3), MUSTARD)
	end
	-- canonical frame of the light switch: world axes at the Box centre (front = world +Z, toward the cook)
	local lightFrame = CFrame.new(lightBox.Position)
	local boxLocal = Vector3.new(0, -0.22, 0.25)
	for _, name in { "Box", "Lever", "PilotLamp" } do
		local src = light:FindFirstChild(name)
		if src then
			local c = src:Clone()
			c:ClearAllChildren()
			local rel = lightFrame:ToObjectSpace(src.CFrame)
			c.CFrame = base * CFrame.new(boxLocal) * rel
			c.Anchored = true
			c.CanCollide = false
			if name == "Lever" then
				c.TextureID = ""
				c.Color = MUSTARD
			elseif name == "PilotLamp" then
				c.TextureID = ""
				c.Color = TEAL
			end
			c.Parent = model
		end
	end
	local box = model:FindFirstChild("Box")
	local anchor = Instance.new("Attachment")
	anchor.Name = "Prompt_Shutter"
	anchor:SetAttribute("BindCreated", true)
	anchor:SetAttribute("PromptAction", "shutter_toggle")
	anchor.Parent = box or model:FindFirstChildWhichIsA("BasePart")
	anchor.WorldCFrame = base * CFrame.new(boxLocal + Vector3.new(0, 0, 0.83))
	CS:AddTag(anchor, "Interactable")
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = trailer
	L(string.format("shutter box built, Prompt_Shutter at (%.2f, %.2f, %.2f)", anchor.WorldPosition.X, anchor.WorldPosition.Y, anchor.WorldPosition.Z))
end

-- 3. the door
CS:AddTag(door, "ScriptedDoor")
door:SetAttribute("DoorHinge", "Right")
door:SetAttribute("DoorAngle", 80)
door:SetAttribute("MovedBy", MARK)
for _, spec in { { "Prompt_ExitTrailer", "trailer_exit", DOOR_PROMPT }, { "Prompt_EnterTrailer", "trailer_enter", DOOR_PROMPT_OUT } } do
	local prompt = body:FindFirstChild(spec[1])
	if not prompt then
		prompt = Instance.new("Attachment")
		prompt.Name = spec[1]
		prompt.Parent = body
	end
	prompt:SetAttribute("PromptAction", spec[2])
	prompt:SetAttribute("BindCreated", true)
	prompt:SetAttribute("MovedBy", MARK)
	prompt.WorldPosition = spec[3]
	CS:AddTag(prompt, "Interactable")
	L(string.format("%s at (%.2f, %.2f, %.2f)", spec[1], spec[3].X, spec[3].Y, spec[3].Z))
end

pcall(function()
	CHS:SetWaypoint("trailer_door_switches: after")
end)
return table.concat(log, ", ")
