--[[
	HotDog Crew demo rig builder (technical prototype, Phase 0 - not gameplay code).

	Assembles an R6 character from the uploaded assets:
	  - body: AST-053_CrewTex (Torso, arms, legs, Cap, Apron; Head replaced by the animal head)
	  - animal: AST-053_Animal_<Animal> (Head_<Animal>, Ears_<Animal>, Tail_<Animal>, extras)
	  - outfit texture on body parts; fur colour = MeshPart.Color showing through the texture alpha
	Joints use the standard R6 Motor6D orientations; C1 is solved from the imported rest pose, so the
	default R6 animations work. Everything imported shares one origin (feet, front = -Z).

	Usage:
		local Crew = require(<this module>)
		local model = Crew.build({ ids = assetIds, tex = textureIds, animal = "Dog", outfit = "Crew", time = "Day",
			fur = Color3.fromHex("C98B5A"), cap = true, at = CFrame.new(...) })
]]

local InsertService = game:GetService("InsertService")

local Crew = {}

local cache: { [string]: Instance } = {}

local function load(id: any): Instance
	local key = tostring(id)
	if not cache[key] then
		local res = InsertService:LoadAsset(tonumber(id) :: number)
		local m = res:GetChildren()[1]
		m.Parent = nil
		res:Destroy()
		cache[key] = m
	end
	return cache[key]:Clone()
end

-- standard R6 joint frames (Part0 side), Part1 C1 solved from the rest pose
local R6 = {
	{ "RootJoint", "HumanoidRootPart", "Torso", CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0) },
	{ "Neck", "Torso", "Head", CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0) },
	{ "Right Shoulder", "Torso", "Right Arm", CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
	{ "Left Shoulder", "Torso", "Left Arm", CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0) },
	{ "Right Hip", "Torso", "Right Leg", CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
	{ "Left Hip", "Torso", "Left Leg", CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0) },
}

local BODY = { "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "Apron", "Cap" }

function Crew.build(o: { [string]: any }): Model
	local model = Instance.new("Model")
	model.Name = string.format("Crew_%s_%s_%s", o.animal, o.outfit, o.time)
	local body = load(o.ids["AST-053_CrewTex"])
	local animal = load(o.ids["AST-053_Animal_" .. o.animal])
	local parts: { [string]: BasePart } = {}
	for _, d in body:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Head" then
			parts[d.Name] = d
		end
	end
	for _, d in animal:GetDescendants() do
		if d:IsA("BasePart") then
			parts[d.Name] = d
		end
	end
	-- outfit texture (Cap only when wanted; ears-up animals use the cap with ear holes)
	local outfitKey = o.outfit == "Crew" and "Crew_Uniform" or ("Civil_" .. o.outfit)
	-- day-only outfits (e.g. Thief) fall back to the Day sheet
	local tex = o.tex[string.format("T_%s_%s", outfitKey, o.time)] or o.tex["T_" .. outfitKey .. "_Day"]
	for _, n in BODY do
		local p = parts[n]
		if p and p:IsA("MeshPart") then
			p.TextureID = tex
			p.Color = o.fur or Color3.fromHex("C98B5A")
		end
	end
	if (o.cap == false or o.earsUp or o.hat) and parts.Cap then
		parts.Cap:Destroy()
		parts.Cap = nil
	end
	-- animals with ears up wear the cap with ear holes (atlas-coloured)
	-- o.hat = asset name of a hat that replaces the cap (e.g. "AST-053_ThiefHat"); modelled at its final place on
	-- the round head, so it is not raised like the cap
	if o.hat then
		local hatModel = load(o.ids[o.hat])
		local hat = hatModel:FindFirstChildWhichIsA("BasePart", true)
		if hat then
			hat.Name = "Hat"
			parts.Hat = hat
		end
	elseif o.cap ~= false and o.earsUp and (o.outfit == "Crew" or o.cap == true) then
		-- the ear-hole cap is atlas-coloured (crew red): civilians with ears up go bare-headed unless cap = true
		local capModel = load(o.ids["AST-053_CrewCap_EarsUp"])
		local cap = capModel:FindFirstChildWhichIsA("BasePart", true)
		if cap then
			cap.Name = "Cap"
			parts.Cap = cap
		end
	end
	if o.outfit ~= "Crew" and parts.Apron then
		parts.Apron:Destroy()
		parts.Apron = nil
	end
	local head = parts["Head_" .. o.animal]
	head.Name = "Head"
	parts.Head = head
	-- the round heads (DEC-152) are 0.30 taller than the base head: the cap rides up with HatAttachment
	if parts.Cap then
		parts.Cap.CFrame += Vector3.new(0, o.capRaise or 0.30, 0)
	end
	-- textured head (animal markings; main fur = part Color through the alpha) + face shell (expression)
	local headTex = o.tex["T_Head_" .. o.animal .. (o.time == "Night" and "_Night" or "")] or o.tex["T_Head_" .. o.animal]
	if headTex and head:IsA("MeshPart") then
		head.TextureID = headTex
		head.Color = o.fur or head.Color
	end
	-- night: atlas-coloured pieces (ears, tail, shell, beak, cap with ear holes) swap to the night atlas
	local nightAtlas = o.tex.T_Atlas_Kitchen_Night
	if o.time == "Night" and nightAtlas then
		for name, p in parts do
			local own = p == head or string.find(name, "^Face_") ~= nil
			if not own and p:IsA("MeshPart") and p.TextureID ~= "" and p.TextureID ~= tex then
				p:SetAttribute("DayTextureID", p.TextureID)
				p.TextureID = nightAtlas
			end
		end
	end
	local face = parts["Face_" .. o.animal]
	if face then
		face.Name = "Face"
		parts["Face_" .. o.animal] = nil
		parts.Face = face
	end
	-- HumanoidRootPart
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 2, 1)
	hrp.Transparency = 1
	hrp.CanCollide = false
	hrp.CFrame = parts.Torso.CFrame
	parts.HumanoidRootPart = hrp
	for _, p in parts do
		p.Anchored = false
		p.CanCollide = false
		p.Parent = model
	end
	hrp.Anchored = true -- demo: stands still in edit mode
	-- joints
	for _, j in R6 do
		local m = Instance.new("Motor6D")
		m.Name = j[1]
		m.Part0 = parts[j[2]]
		m.Part1 = parts[j[3]]
		m.C0 = j[4]
		m.C1 = parts[j[3]].CFrame:ToObjectSpace(parts[j[2]].CFrame * j[4])
		m.Parent = parts[j[2]]
	end
	-- accessories: ears / tail / extras / cap / apron welded where they were modelled
	for name, p in parts do
		local isRig = name == "HumanoidRootPart" or name == "Torso" or name == "Head" or name == "Left Arm" or name == "Right Arm" or name == "Left Leg" or name == "Right Leg"
		if not isRig then
			local anchor = (string.find(name, "Tail") or string.find(name, "Shell") or name == "Apron") and parts.Torso or parts.Head
			local w = Instance.new("WeldConstraint")
			w.Part0 = anchor
			w.Part1 = p
			w.Parent = p
		end
	end
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R6
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = model
	model.PrimaryPart = hrp
	body:Destroy()
	animal:Destroy()
	-- o.at = CFrame of the HumanoidRootPart (ground Y + 3)
	if o.at then
		model:PivotTo(o.at)
	end
	model:SetAttribute("Animal", o.animal)
	model:SetAttribute("Outfit", o.outfit)
	model:SetAttribute("Time", o.time)
	if parts.Face then
		Crew.setExpression(model, o.expression or "Normal", o.tex)
	end
	return model
end

--[[ Expressions. The face shell needs real transparency (SurfaceAppearance AlphaMode Transparency); a plain
	TextureID would paint its transparent texels with the part Color and hide the head markings.
	SurfaceAppearance.ColorMap cannot be set by game scripts at runtime, so one ready-made SurfaceAppearance per
	expression lives in ReplicatedStorage.CrewExpressions (built here in edit mode) and swapping = cloning it.
	tex keys "T_Expr_<Name>" (+ "T_Expr_<Name>_Night" preferred for Night variants). ]]
function Crew.ensureExpressions(tex: { [string]: string }): Folder
	local RS = game:GetService("ReplicatedStorage")
	local folder = RS:FindFirstChild("CrewExpressions")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "CrewExpressions"
		folder.Parent = RS
	end
	for key, id in tex do
		local name = string.match(key, "^T_Expr_(.+)$")
		if name and not folder:FindFirstChild(name) then
			local sa = Instance.new("SurfaceAppearance")
			sa.Name = name
			sa.ColorMap = id
			sa.AlphaMode = Enum.AlphaMode.Transparency
			sa.Parent = folder
		end
	end
	return folder :: Folder
end

function Crew.setExpression(model: Model, name: string, tex: { [string]: string }?): boolean
	local face = model:FindFirstChild("Face")
	if not face or not face:IsA("MeshPart") then
		return false
	end
	local folder = game:GetService("ReplicatedStorage"):FindFirstChild("CrewExpressions")
	if not folder and tex then
		folder = Crew.ensureExpressions(tex)
	end
	if not folder then
		return false
	end
	local night = model:GetAttribute("Time") == "Night"
	local tpl = (night and folder:FindFirstChild(name .. "_Night")) or folder:FindFirstChild(name)
	if not tpl then
		return false
	end
	local old = face:FindFirstChildOfClass("SurfaceAppearance")
	if old then
		old:Destroy()
	end
	tpl:Clone().Parent = face
	face.TextureID = ""
	model:SetAttribute("Expression", name)
	return true
end

return Crew
