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
	local tex = o.tex[string.format("T_%s_%s", o.outfit == "Crew" and "Crew_Uniform" or ("Civil_" .. o.outfit), o.time)]
	for _, n in BODY do
		local p = parts[n]
		if p and p:IsA("MeshPart") then
			p.TextureID = tex
			p.Color = o.fur or Color3.fromHex("C98B5A")
		end
	end
	if (o.cap == false or o.earsUp) and parts.Cap then
		parts.Cap:Destroy()
		parts.Cap = nil
	end
	-- animals with ears up wear the cap with ear holes (atlas-coloured)
	if o.cap ~= false and o.earsUp then
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
	return model
end

return Crew
