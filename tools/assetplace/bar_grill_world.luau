--!nocheck
-- bar_grill_world.luau (Studio snippet, idempotent; owner request 2026-10-14, Provisional)
-- The trailer grill IS the bar grill of the 3D prep (src/Prep/client/PrepController/World/GrillRig.luau): the same slab, Cream edge, 7 bars,
-- drip tray and burner, built here as static Parts INSIDE the three upgrade pieces of TRL-G_AST-012_RollerGrill (Grill_L1 2 slots,
-- Grill_L2 3 slots, Grill_L3 4 slots), so the piece system (UpgradeService/Pieces) shows the one of the current level and the grill
-- gets WIDER with each upgrade. The old roller mesh of each piece is made invisible. In the prep mode the rig draws its own copy
-- (with the heat) and hides this model locally: keep the numbers below equal to GrillRig (Margin, BarGap, BarRadius, Tray, SAUSAGE).
-- Geometry in world studs: the slots run along world X (Att_Slot1..4, 0.9 apart), the sausage lies along world Z, the food foot is
-- the Att_Slot height. Parts are named like AST-120 (Base, Frame, Bar_n, Tray, Burner, Stand). No Place.run recreates this:
-- run it AFTER bind_pieces (see STUDIO_LAYER.md). Run: run("assetplace/bar_grill_world") or paste in the command bar.
local trailer = workspace.MAP01_Assets.Night_Trailer:FindFirstChild("TRL_AST-027_OpenLateTrailer")
	or workspace.MAP01_Assets.Night_Trailer:FindFirstChild("TRL-AST-027_OpenLateTrailer")
assert(trailer, "bar_grill_world: trailer model not found")
local roller = trailer:FindFirstChild("TRL-G_AST-012_RollerGrill")
local pieces = roller and roller:FindFirstChild("UpgradePieces")
assert(pieces, "bar_grill_world: UpgradePieces not found")
local fixed = roller:FindFirstChild("Fixed_Grill_L1")

-- the slot line: read from the Att_Slot attachments (first slot X, spacing, Z of the line, foot height)
local slotAt = {}
for _, d in roller:GetDescendants() do
	if d:IsA("Attachment") then
		local slot = d:GetAttribute("Slot")
		if type(slot) == "number" and slot % 1 == 0 and slot >= 1 then
			slotAt[slot] = d.WorldPosition
		end
	end
end
assert(slotAt[1] and slotAt[2], "bar_grill_world: Att_Slot1/2 not found")
local gap = slotAt[2].X - slotAt[1].X
local lineZ, foot = slotAt[1].Z, slotAt[1].Y

-- GrillRig numbers
local SAUSAGE, MARGIN, BAR_GAP, BAR_R = 1.0, 0.3, 0.25, 0.035
local TRAY_DEPTH, TRAY_DROP = 0.34, 0.1
local SLAB_H, EDGE, STAND_H = 0.12, 0.07, 0.24
local COLD, SLAB = Color3.fromHex("#5A5F6B"), Color3.fromHex("#2B2233")
local CREAM, MUSTARD, SLATE = Color3.fromHex("#FFF1D6"), Color3.fromHex("#F6C12B"), Color3.fromHex("#8A8FA3")

local LEVEL_SLOTS = { Grill_L1 = 2, Grill_L2 = 3, Grill_L3 = 4 }

local function block(parent, name, size, color, material, center)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.Position = center
	part.Parent = parent
	return part
end

local built = 0
for levelName, count in LEVEL_SLOTS do
	local piece = pieces:FindFirstChild(levelName)
	assert(piece, "bar_grill_world: missing " .. levelName)
	-- the old roller mesh of the piece goes invisible for good (the piece system restores UpgOrigTransparency, so that is set too)
	local pieceHidden = false
	for _, child in piece:GetChildren() do
		if child:IsA("MeshPart") then
			pieceHidden = pieceHidden or child:GetAttribute("UpgHidden") == true
			child.Transparency = 1
			child:SetAttribute("UpgOrigTransparency", 1)
		end
	end
	-- a previous run is replaced
	local old = piece:FindFirstChild("BarGrill")
	if old then
		old:Destroy()
	end
	local model = Instance.new("Folder")
	model.Name = "BarGrill"

	local first, last = slotAt[1].X, slotAt[1].X + gap * (count - 1)
	local centreX = (first + last) / 2
	local spanZ = (last - first) + 2 * MARGIN + 0.55 -- along the line (world X)
	local spanX = SAUSAGE + 2 * MARGIN -- along the sausage (world Z)
	local c = Vector3.new(centreX, foot, lineZ)

	-- Stand: the dark housing from the counter up to the slab (not in GrillRig's old build: added there too)
	local slabTop = foot - 0.16
	local slabBottom = slabTop - SLAB_H
	block(model, "Stand", Vector3.new(spanZ - 0.1, STAND_H, spanX - 0.1), SLAB, Enum.Material.SmoothPlastic, Vector3.new(c.X, slabBottom - STAND_H / 2, c.Z))
	block(model, "Base", Vector3.new(spanZ, SLAB_H, spanX), SLAB, Enum.Material.SmoothPlastic, Vector3.new(c.X, slabTop - SLAB_H / 2, c.Z))
	-- the Cream edge: two strips along the line, two across it
	local edgeY = foot - 0.16 - SLAB_H + EDGE * 0.6
	for index = 1, 4 do
		local along = index <= 2
		local side = index % 2 == 1 and 1 or -1
		if along then
			block(model, "Frame", Vector3.new(spanZ + EDGE, EDGE * 1.2, EDGE), CREAM, Enum.Material.SmoothPlastic, Vector3.new(c.X, edgeY, c.Z + side * (spanX / 2)))
		else
			block(model, "Frame", Vector3.new(EDGE, EDGE * 1.2, spanX + EDGE), CREAM, Enum.Material.SmoothPlastic, Vector3.new(c.X + side * (spanZ / 2), edgeY, c.Z))
		end
	end
	-- the bars: along the line, side by side across the sausage, the foot of the sausage rests on them
	local barCount = math.clamp(math.floor((spanX - 0.1) / BAR_GAP) + 1, 2, 28)
	for index = 1, barCount do
		local offset = -((barCount - 1) * BAR_GAP) / 2 + (index - 1) * BAR_GAP
		block(model, "Bar_" .. index, Vector3.new(spanZ - 0.1, BAR_R * 2, BAR_R * 2), COLD, Enum.Material.Neon, Vector3.new(c.X, foot - BAR_R, c.Z + offset))
	end
	-- the tray on the side the camera looks from (south, toward the player) and the burner housing on the other
	block(model, "Tray", Vector3.new(spanZ, 0.07, TRAY_DEPTH), MUSTARD, Enum.Material.SmoothPlastic, Vector3.new(c.X, foot - 0.16 - TRAY_DROP, c.Z - (spanX / 2 + TRAY_DEPTH / 2 - 0.02)))
	block(model, "Burner", Vector3.new(spanZ * 0.8, 0.16, TRAY_DEPTH * 0.8), SLATE, Enum.Material.SmoothPlastic, Vector3.new(c.X, foot - 0.22, c.Z + (spanX / 2 + TRAY_DEPTH * 0.4)))
	-- a piece of a level not reached yet is stored hidden, the way UpgradeService/Pieces keeps it (shown again with these attributes)
	if pieceHidden then
		for _, part in model:GetChildren() do
			part:SetAttribute("UpgHidden", true)
			part:SetAttribute("UpgOrigTransparency", 0)
			part:SetAttribute("UpgOrigCanCollide", false)
			part:SetAttribute("UpgOrigCanQuery", false)
			part.Transparency = 1
		end
	end
	model.Parent = piece
	built += 1
end
return `bar_grill_world: {built} levels built (slot gap {gap}, line z {lineZ}, foot {foot})`
