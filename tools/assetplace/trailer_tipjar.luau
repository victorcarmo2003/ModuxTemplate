--!nonstrict
--[[
	OBSOLETE (owner 2026-10-22): the tip jar left the game (tips go straight to Cash; TipJarService, Content.TipJar and the
	collect_tips action are gone) and Walt's notes paper (HINT-NOTE) took its spot. Do NOT run this snippet.

	trailer_tipjar.luau (owner decision 2026-10-13, DEC-239, Provisional: "the register leaves, a TIP JAR that fills with
	money takes its place"). Edit-mode Studio snippet, NOT gameplay code. Idempotent, surgical, NO Place.run.
	Undo: run("trailer_tipjar", "undo").   AST-121 (docs/art/asset-list.md).

	What it does (inside the trailer Vehicle Model; never touches anything by coordinate, finds by MapId):
	  1. Old register: Model MapId TRL-DRAWER (AST-020 POS) -> ServerStorage.Trailer_Backup_20261013 (OrigPath / OrigTags
	     attributes, the gameplay tag Interactable removed so no service scans a ghost). Its bounding box tells where the jar goes
	     (centre XZ, floor = the lowest Y of the box = the counter top).
	  2. New Model TRL-TIPJAR (MapId, Persistent, BindCreated) built from Parts (no mesh upload needed):
	       Base      Steel disc under the glass
	       Glass     cylinder, Transparency 0.45, Material Glass
	       Rim_01..10  ten Steel blocks around the mouth (an open ring: the bills are seen from above)
	       Label     Cream plate on the glass front with the SurfaceGui text "TIPS" (Ink), facing the customers
	       Fill_Volume  invisible, the room the client heap may use (EconomyController/TipJar.luau reads it, 0.9 x 1.0 x 0.9)
	       Pivot     invisible, on the counter top, centre of the jar (PrimaryPart: the model pivot = the floor, check_map01 rule 7)
	       Mount     invisible 0.2 part on top holding the Attachments Value_Anchor and Prompt_Collect
	     The jar faces the trailer pivot LookVector (the customers' side, same rule as trailer_serving_panel).
	  3. Attachments: Value_Anchor (the "$N" over the jar) and Prompt_Collect (TipJarService tags and uses it; Content.Actions
	     collect_tips "Collect Tips").
	If TRL-TIPJAR already exists (made earlier or edited by hand) its geometry is NOT touched: only missing pieces/fittings are added.
	Returns a log.
]]

local CS = game:GetService("CollectionService")
local ST = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")
local UNDO = (...) == "undo"

local BK_NAME = "Trailer_Backup_20261013"
local OLD_ID = "TRL-DRAWER"
local MODEL = "TRL-TIPJAR"
local TAGS_OFF = { "Interactable" }

-- jar geometry (studs), bottom centre = jarCF
local BASE_H, BASE_D = 0.1, 1.15
local GLASS_H, GLASS_D = 1.2, 1.1
local RIM_R, RIM_N = 0.57, 10
local FILL = Vector3.new(0.9, 1.0, 0.9)

local STEEL = Color3.fromHex("#9AA5AF")
local GLASS = Color3.fromRGB(205, 230, 238)
local CREAM = Color3.fromHex("#FFF1D6")
local INK = Color3.fromHex("#2B2118")

local log = {}
local function L(text)
	table.insert(log, text)
end
pcall(function()
	CHS:SetWaypoint("trailer_tipjar: before")
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

local function byMapId(root, id)
	for _, d in root:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("MapId") == id then
			return d
		end
	end
end
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

local bk = ST:FindFirstChild(BK_NAME)

if UNDO then
	local made = byMapId(trailer, MODEL)
	if made then
		made:Destroy()
		L("TRL-TIPJAR removed")
	end
	local old = bk and bk:FindFirstChild("TRL-DRAWER_Backup")
	if old then
		old.Parent = trailer
		for _, d in old:GetDescendants() do
			retag(d)
		end
		retag(old)
		old.Name = old:GetAttribute("OrigName") or "TRL-DRAWER"
		L("old register restored")
	end
	return table.concat(log, "\n")
end

local pivot = trailer:GetPivot()
local look = pivot.LookVector
local model = byMapId(trailer, MODEL)
local jarCF

-- 1. where the old register stands (read BEFORE it moves)
local old = byMapId(trailer, OLD_ID)
if not model then
	if old then
		local cf, size = old:GetBoundingBox()
		-- floor of the box: the counter top (the POS stands on it)
		jarCF = CFrame.lookAt(Vector3.new(cf.X, cf.Y - size.Y / 2, cf.Z), Vector3.new(cf.X, cf.Y - size.Y / 2, cf.Z) + look)
	else
		return "[err] neither TRL-TIPJAR nor TRL-DRAWER found in the trailer: nothing to place the jar on"
	end
end

-- 2. the old register -> backup
if old then
	if not bk then
		bk = Instance.new("Folder")
		bk.Name = BK_NAME
		bk.Parent = ST
	end
	old:SetAttribute("OrigPath", old:GetFullName())
	old:SetAttribute("OrigName", old.Name)
	for _, d in old:GetDescendants() do
		untag(d)
	end
	untag(old)
	old.Name = "TRL-DRAWER_Backup"
	old.Parent = bk
	L("old TRL-DRAWER moved to ServerStorage." .. BK_NAME .. " (tags off)")
end

-- 3. the jar
local function part(parent, name, size, cf, color, material, transparency)
	local p = parent:FindFirstChild(name)
	if p then
		return p, false
	end
	p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p:SetAttribute("BindCreated", true)
	p.Parent = parent
	return p, true
end

if not model then
	model = Instance.new("Model")
	model.Name = MODEL
	model:SetAttribute("MapId", MODEL)
	model:SetAttribute("BindCreated", true)
	-- Models with gameplay tags must be Persistent (check_map01 rule 5)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = trailer
	L("model created: " .. MODEL)

	local sideways = CFrame.Angles(0, 0, math.pi / 2) -- a Part cylinder has its axis on X
	local base = part(model, "Base", Vector3.new(BASE_H, BASE_D, BASE_D), jarCF * CFrame.new(0, BASE_H / 2, 0) * sideways, STEEL, Enum.Material.Metal)
	local glassY = BASE_H + GLASS_H / 2
	local glass = part(model, "Glass", Vector3.new(GLASS_H, GLASS_D, GLASS_D), jarCF * CFrame.new(0, glassY, 0) * sideways, GLASS, Enum.Material.Glass, 0.45)
	base.Shape = Enum.PartType.Cylinder
	glass.Shape = Enum.PartType.Cylinder
	local rimY = BASE_H + GLASS_H
	for i = 1, RIM_N do
		local a = (i - 1) / RIM_N * math.pi * 2
		local pos = Vector3.new(math.sin(a) * RIM_R, rimY, math.cos(a) * RIM_R)
		part(model, string.format("Rim_%02d", i), Vector3.new(0.38, 0.1, 0.14), jarCF * CFrame.new(pos) * CFrame.Angles(0, a, 0), STEEL, Enum.Material.Metal)
	end
	-- label on the front of the glass (front = -Z of jarCF = the customers' side)
	local label = part(model, "Label", Vector3.new(0.7, 0.3, 0.02), jarCF * CFrame.new(0, BASE_H + 0.5, -(GLASS_D / 2 + 0.012)), CREAM, Enum.Material.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Detail_TipLabel"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 120
	gui.Parent = label
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "TIPS"
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = INK
	text.Parent = gui
	-- fill volume (the client heap)
	local fill = part(model, "Fill_Volume", FILL, jarCF * CFrame.new(0, BASE_H + 0.05 + FILL.Y / 2, 0), STEEL, Enum.Material.SmoothPlastic, 1)
	fill.Name = "Fill_Volume"
	-- mount with the fittings
	local mount = part(model, "Mount", Vector3.new(0.2, 0.2, 0.2), jarCF * CFrame.new(0, BASE_H + GLASS_H + 0.25, 0), STEEL, Enum.Material.SmoothPlastic, 1)
	-- the model pivot sits on the counter top (check_map01 rule 7: pivot 4.6 above the trailer pivot)
	local pivotPart = part(model, "Pivot", Vector3.new(0.1, 0.1, 0.1), jarCF, STEEL, Enum.Material.SmoothPlastic, 1)
	model.PrimaryPart = pivotPart
	L("jar parts built")
end

-- fittings (also for a hand-edited jar): only what is missing
local mount = model:FindFirstChild("Mount") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
if mount then
	if not model:FindFirstChild("Value_Anchor", true) then
		local a = Instance.new("Attachment")
		a.Name = "Value_Anchor"
		a.Position = Vector3.new(0, 0.5, 0)
		a:SetAttribute("BindCreated", true)
		a.Parent = mount
		L("fitting created: Value_Anchor")
	end
	if not model:FindFirstChild("Prompt_Collect", true) then
		local a = Instance.new("Attachment")
		a.Name = "Prompt_Collect"
		a.Position = Vector3.new(0, 0, 0)
		a:SetAttribute("BindCreated", true)
		a.Parent = mount
		L("fitting created: Prompt_Collect")
	end
end
if not model:FindFirstChild("Fill_Volume", true) then
	L("[warn] Fill_Volume missing (hand edit?): the client draws no heap, only the number")
end
model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

pcall(function()
	CHS:SetWaypoint("trailer_tipjar: after")
end)
return table.concat(log, "\n")
