--[[
	AST-028_MartWallDoor split swap (one-off, run in Studio with execute_luau / Command Bar, Edit mode).

	Replaces the single MeshPart "AST-028_MartWallDoor" of
	  workspace.MAP01_Assets.Mart["MKT-DOOR_AST-028_MartWallDoor"]
	by the three pieces of the re-exported model (asset 140495801903917):
	  Door_Frame (wall + frame + threshold, fixed), Door_Leaf_L, Door_Leaf_R (AutoDoor leaves).
	The pieces land where the old mesh was (the union of the three parts is aligned to the old part's CFrame, so
	any model pivot / rotation of the placement is kept). The same AutoDoor contract as bind_map01.luau (W8) is
	applied to the leaves: tag, DoorId, DoorLeaf, DoorHinge Left/Right, DoorAngle, DoorRadius, Door_Hinge attachment.
	Idempotent: when Door_Frame already exists nothing is swapped, only the leaves are (re)configured.
	The placeholder glass Part "Door_Leaf" is deleted.
]]
local InsertService = game:GetService("InsertService")
local CollectionService = game:GetService("CollectionService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local MODEL_ID = 140495801903917 -- Open Cloud id of Assets/import/market/AST-028_MartWallDoor.fbx (3 MeshParts)
local DOOR_ID = "MKT-DOOR"
local INWARD = Vector3.new(-1, 0, 1).Unit -- into the Mart (same as bind_map01 DOORS)
local OPEN_ANGLE = 90
local RADIUS = 8
-- bind_map01 W8 puts CanCollide false on the server leaf (NPCs walk through) and keeps the real value in
-- DoorOrigCanCollide (the client controller restores it when closed). Set true to leave the leaves solid.
local LEAF_COLLIDE = false

local COPY = { "Anchored", "CanQuery", "CanTouch", "CastShadow", "CollisionFidelity", "RenderFidelity", "Material", "Color", "Reflectance", "Transparency", "Locked" }

local model = workspace.MAP01_Assets.Mart:FindFirstChild("MKT-DOOR_AST-028_MartWallDoor")
assert(model, "model MKT-DOOR_AST-028_MartWallDoor not found")

ChangeHistoryService:SetWaypoint("Mart door split: before")

-- 1) placeholder glass leaf (bind-created Part) goes away
for _, c in model:GetChildren() do
	if c.Name == "Door_Leaf" and not c:IsA("MeshPart") then
		c:Destroy()
		print("removed placeholder Door_Leaf")
	end
end

-- 2) swap the single mesh for the three pieces
local frame = model:FindFirstChild("Door_Frame")
if not frame then
	local old = model:FindFirstChild("AST-028_MartWallDoor")
	assert(old and old:IsA("MeshPart"), "old MeshPart AST-028_MartWallDoor not found")
	local loaded = InsertService:LoadAsset(MODEL_ID)
	local pf = loaded:FindFirstChild("Door_Frame", true)
	local pl = loaded:FindFirstChild("Door_Leaf_L", true)
	local pr = loaded:FindFirstChild("Door_Leaf_R", true)
	assert(pf and pl and pr, "loaded asset lacks Door_Frame / Door_Leaf_L / Door_Leaf_R")
	local parts = { pf, pl, pr }

	-- union bounds of the loaded parts in the frame's space; its size must equal the old single mesh
	local ref = pf.CFrame.Rotation
	local mn, mx = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in parts do
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					local c = (CFrame.new(pf.Position) * ref):PointToObjectSpace(p.CFrame:PointToWorldSpace(p.Size / 2 * Vector3.new(x, y, z)))
					mn, mx = mn:Min(c), mx:Max(c)
				end
			end
		end
	end
	local union = CFrame.new(pf.Position) * ref * CFrame.new((mn + mx) / 2)
	local usize = mx - mn
	if (usize - old.Size).Magnitude > 0.1 or (pf.Size - old.Size).Magnitude > 0.1 then
		loaded:Destroy()
		error(("size mismatch: loaded union %s / frame %s vs old %s; nothing changed"):format(tostring(usize), tostring(pf.Size), tostring(old.Size)))
	end

	local pivot = model:GetPivot()
	local wasPrimary = model.PrimaryPart == old
	local oldTexture = old.TextureID
	for _, p in parts do
		local n = p:Clone()
		n.CFrame = old.CFrame * union:ToObjectSpace(p.CFrame)
		for _, prop in COPY do
			pcall(function()
				n[prop] = old[prop]
			end)
		end
		if n.TextureID == "" then
			n.TextureID = oldTexture -- same colormap atlas, UVs unchanged
		end
		n.Name = p.Name
		n.Parent = model
		print(("%s  MeshId %s  TextureID %s  Size %s"):format(n.Name, n.MeshId, n.TextureID, tostring(n.Size)))
	end
	loaded:Destroy()
	old:Destroy()
	frame = model:FindFirstChild("Door_Frame")
	if wasPrimary then
		model.PrimaryPart = frame
		frame.PivotOffset = frame.CFrame:ToObjectSpace(pivot)
	elseif model.PrimaryPart == nil then
		model.WorldPivot = pivot
	end
	print("swapped single mesh for Door_Frame + Door_Leaf_L + Door_Leaf_R")
end

frame.CanCollide = true
frame.Anchored = true

-- 3) AutoDoor contract on the leaves (same maths as bind_map01 bindAutoDoors)
local leaves = { model.Door_Leaf_L :: BasePart, model.Door_Leaf_R :: BasePart }
local centre = (leaves[1].Position + leaves[2].Position) / 2
for _, p in leaves do
	local right = p.CFrame.RightVector
	local axis, w = right, p.Size.X
	if math.abs(p.CFrame.LookVector.Y) < 0.9 and p.Size.Z > p.Size.X then
		axis, w = p.CFrame.LookVector, p.Size.Z
	end
	axis = Vector3.new(axis.X, 0, axis.Z).Unit
	local e1, e2 = p.Position + axis * (w / 2), p.Position - axis * (w / 2)
	local edge = if (e1 - centre).Magnitude >= (e2 - centre).Magnitude then e1 else e2 -- outer edge

	local old = p:FindFirstChild("Door_Hinge")
	if old then
		old:Destroy()
	end
	local a = Instance.new("Attachment")
	a.Name = "Door_Hinge"
	a.Parent = p
	a.WorldCFrame = CFrame.new(Vector3.new(edge.X, p.Position.Y - p.Size.Y / 2, edge.Z))

	local h = a.WorldPosition
	local r = p.Position - h
	local flat = Vector3.new(r.X, 0, r.Z)
	local turned = CFrame.Angles(0, math.rad(OPEN_ANGLE), 0):VectorToWorldSpace(flat)
	local sign = if (turned - flat):Dot(INWARD) >= 0 then 1 else -1
	local side = if (h - p.Position):Dot(p.CFrame.RightVector) >= 0 then "Right" else "Left"

	p:SetAttribute("DoorOrigCanCollide", true)
	p.Anchored = true
	p.CanCollide = LEAF_COLLIDE
	CollectionService:AddTag(p, "AutoDoor")
	p:SetAttribute("DoorId", DOOR_ID)
	p:SetAttribute("DoorLeaf", true)
	p:SetAttribute("DoorHinge", side)
	p:SetAttribute("DoorAngle", sign * OPEN_ANGLE)
	p:SetAttribute("DoorRadius", RADIUS)
	print(("%s: DoorHinge %s, DoorAngle %d, Door_Hinge at %s, width %.2f"):format(p.Name, side, sign * OPEN_ANGLE, tostring(h), w))
end

ChangeHistoryService:SetWaypoint("Mart door split: after")
print("done (save the place with Ctrl+S)")
