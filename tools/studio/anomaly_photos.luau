--!nocheck
-- anomaly_photos: builds the flash-photo booth of the Anomaly Tablet (owner request 2026-10-17). One closed black cell per
-- page of Content.Journal, far from the map (workspace.DEV_PhotoBooth), staged with the REAL game pieces: CrewRig rigs
-- dressed with the game's expressions (Blank, EyesWhite, EyesClosed, Angry), the family A deformations of
-- Kit/OddCustomer done statically (neck, big head, float, stare), the family B monsters of Kit/Hide and the stalker of
-- ANM-006 (same Part recipes), Assets.Vehicles.LongCar, Assets.Items (BunBitten, SausageWrong, WrongToppings), the
-- restaurant BackDoor and TRL-BREAKER, and the street lamp of MAP-01. Joints are removed from the anchored copies (Studio
-- draws them as gizmos in the captures).
-- Idempotent: destroys and rebuilds the booth. Returns { { Key, Cam, Look } } for screen_capture; the flash look is
-- applied afterwards (scratchpad flash.py). Run: run_snippet("studio/anomaly_photos").
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)
local CrewLooks = require(ReplicatedStorage.shared.Crew.CrewLooks)

local ORIGIN = Vector3.new(6000, 400, 6000)
local SPACING = 50
local INK = Color3.fromHex("#2B2233")
local BODY = Color3.fromHex("#1E1A2B")
local EYE = Color3.fromHex("#F4F1E8")
local TOOTH = Color3.fromHex("#FFFFFF")

local old = workspace:FindFirstChild("DEV_PhotoBooth")
if old then
	old:Destroy()
end
local booth = Instance.new("Folder")
booth.Name = "DEV_PhotoBooth"

local function block(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.CFrame = cf
	p.Color = color or Color3.new(0.02, 0.02, 0.025)
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function cell(index, key)
	local model = Instance.new("Model")
	model.Name = key
	local base = ORIGIN + Vector3.new((index - 1) * SPACING, 0, 0)
	local W, H = 40, 26
	block(model, "Floor", Vector3.new(W, 1, W), CFrame.new(base + Vector3.new(0, -0.5, 0)))
	block(model, "Ceil", Vector3.new(W, 1, W), CFrame.new(base + Vector3.new(0, H + 0.5, 0)))
	block(model, "N", Vector3.new(W, H, 1), CFrame.new(base + Vector3.new(0, H / 2, -W / 2)))
	block(model, "S", Vector3.new(W, H, 1), CFrame.new(base + Vector3.new(0, H / 2, W / 2)))
	block(model, "E", Vector3.new(1, H, W), CFrame.new(base + Vector3.new(W / 2, H / 2, 0)))
	block(model, "W", Vector3.new(1, H, W), CFrame.new(base + Vector3.new(-W / 2, H / 2, 0)))
	model.Parent = booth
	return model, base
end

local function anchorAll(model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
end

local function dropJoints(model)
	for _, d in model:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Constraint") then
			d:Destroy()
		end
	end
end

-- parts connected to the Head through joints, the Neck excluded (ears, hats, face shell)
local function headGroup(rig)
	local head = rig:FindFirstChild("Head", true)
	local links = {}
	local function link(a, b)
		if a and b then
			links[a] = links[a] or {}
			links[b] = links[b] or {}
			table.insert(links[a], b)
			table.insert(links[b], a)
		end
	end
	for _, d in rig:GetDescendants() do
		if d:IsA("JointInstance") and d.Name ~= "Neck" then
			link(d.Part0, d.Part1)
		elseif d:IsA("WeldConstraint") then
			link(d.Part0, d.Part1)
		end
	end
	local seen, queue = { [head] = true }, { head }
	while #queue > 0 do
		local p = table.remove(queue)
		for _, q in links[p] or {} do
			-- never walk into the torso through a stray weld
			if not seen[q] and q.Name ~= "Torso" and q.Name ~= "HumanoidRootPart" then
				seen[q] = true
				table.insert(queue, q)
			end
		end
	end
	local list = {}
	for p in seen do
		table.insert(list, p)
	end
	return head, list
end

-- a real customer rig standing at `at` (feet), facing +Z (the camera)
local function rig(parent, at, species, outfit, expression, blank)
	local model = CrewRig.Build(species, outfit, { LookPack = "Day", Name = species })
	CrewRig.Dress(model, "Day", expression, blank == true)
	anchorAll(model)
	model:PivotTo(CFrame.new(at) * CFrame.Angles(0, math.pi, 0))
	local cf, size = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + Vector3.new(0, at.Y - (cf.Position.Y - size.Y / 2), 0))
	model.Parent = parent
	return model
end

local function headShot(model)
	local head = model:FindFirstChild("Head", true)
	local h = head.Position
	return h + Vector3.new(0.1, 0.02, 5.2), h - Vector3.new(0, 0.38, 0)
end

local function transformHead(model, fn)
	local head, group = headGroup(model)
	local neck = head.Position - Vector3.new(0, head.Size.Y / 2, 0)
	for _, p in group do
		fn(p, neck)
	end
end

-- Kit/Hide part recipe (same shapes and colours)
local function hpart(model, name, shape, size, at, color)
	local p = block(model, name, size, at, color, (color == EYE or color == TOOTH) and Enum.Material.Neon or Enum.Material.SmoothPlastic, shape)
	return p
end
local function heyes(model, head, radius, size)
	for _, x in { -1, 1 } do
		hpart(model, "Eye", Enum.PartType.Ball, Vector3.one * size, head * CFrame.new(x * radius * 0.42, radius * 0.15, -radius * 0.82), EYE)
	end
end
local function hgrin(model, head, radius)
	local width = radius * 1.3
	hpart(model, "Mouth", Enum.PartType.Block, Vector3.new(width, radius * 0.32, 0.3), head * CFrame.new(0, -radius * 0.38, -radius * 0.9), INK)
	local teeth = 6
	for index = 1, teeth do
		local x = (index - (teeth + 1) / 2) * (width / teeth)
		hpart(model, "Tooth", Enum.PartType.Block, Vector3.new(width / teeth * 0.7, radius * 0.18, 0.2), head * CFrame.new(x, -radius * 0.3, -radius * 0.98), TOOTH)
	end
end
local MONSTERS = {
	Walk = function(m)
		hpart(m, "Coat", Enum.PartType.Block, Vector3.new(2.6, 5, 1.6), CFrame.new(0, 2.5, 0), BODY)
		hpart(m, "Shoulders", Enum.PartType.Cylinder, Vector3.new(1.8, 1.8, 3.2), CFrame.new(0, 5, 0) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(0, math.rad(90), 0), BODY)
		local head = CFrame.new(0, 6.3, 0)
		hpart(m, "Head", Enum.PartType.Ball, Vector3.one * 1.9, head, BODY)
		heyes(m, head, 0.95, 0.42)
		hpart(m, "Brim", Enum.PartType.Cylinder, Vector3.new(0.15, 3.4, 3.4), CFrame.new(0, 7.1, 0) * CFrame.Angles(0, 0, math.rad(90)), INK)
		hpart(m, "Crown", Enum.PartType.Cylinder, Vector3.new(1, 1.7, 1.7), CFrame.new(0, 7.6, 0) * CFrame.Angles(0, 0, math.rad(90)), INK)
		return 6.3
	end,
	Crawl = function(m)
		hpart(m, "Body", Enum.PartType.Cylinder, Vector3.new(4.2, 1.6, 1.6), CFrame.new(0, 1.7, 0.4) * CFrame.Angles(0, math.rad(90), 0), BODY)
		for _, x in { -0.7, 0.7 } do
			for _, z in { -1.3, 1.9 } do
				hpart(m, "Leg", Enum.PartType.Block, Vector3.new(0.35, 1.8, 0.35), CFrame.new(x, 0.9, z) * CFrame.Angles(0, 0, x * 0.4), BODY)
			end
		end
		local head = CFrame.new(0, 2.2, -2.2)
		hpart(m, "Head", Enum.PartType.Ball, Vector3.one * 1.8, head, BODY)
		heyes(m, head, 0.9, 0.5)
		return 2.2
	end,
	Grin = function(m)
		local head = CFrame.new(0, 6.5, 0)
		hpart(m, "Head", Enum.PartType.Ball, Vector3.one * 7, head, BODY)
		heyes(m, head, 3.5, 1.5)
		hgrin(m, head, 3.5)
		hpart(m, "Neck", Enum.PartType.Block, Vector3.new(1.6, 3.5, 1.6), CFrame.new(0, 1.75, 0), BODY)
		return 6.5
	end,
	Roof = function(m)
		hpart(m, "Body", Enum.PartType.Block, Vector3.new(1.4, 3.2, 1), CFrame.new(0, 3.9, 0), BODY)
		for _, x in { -0.45, 0.45 } do
			hpart(m, "Leg", Enum.PartType.Block, Vector3.new(0.4, 2.4, 0.4), CFrame.new(x, 1.2, 0), BODY)
		end
		for _, x in { -1, 1 } do
			hpart(m, "Arm", Enum.PartType.Block, Vector3.new(0.35, 3.6, 0.35), CFrame.new(x, 3.4, -0.3) * CFrame.Angles(math.rad(-15), 0, x * 0.15), BODY)
		end
		local head = CFrame.new(0, 5.9, -0.2)
		hpart(m, "Head", Enum.PartType.Ball, Vector3.one * 1.5, head, BODY)
		heyes(m, head, 0.75, 0.4)
		return 5.9
	end,
}
-- builds a monster (feet at the origin, facing -Z) and turns it to face +Z at `at`; returns the head height
local function monster(parent, style, at)
	local m = Instance.new("Model")
	m.Name = style
	local headY = MONSTERS[style](m)
	m.WorldPivot = CFrame.new()
	m:PivotTo(CFrame.new(at) * CFrame.Angles(0, math.pi, 0))
	m.Parent = parent
	return headY
end

-- ANM-006 stalker placeholder (same recipe), facing +Z
local function stalker(parent, at, scale)
	local m = Instance.new("Model")
	m.Name = "Stalker"
	local s = scale or 1
	local function p(name, size, cf, color, shape)
		return block(m, name, size * s, CFrame.new(cf.Position * s) * cf.Rotation, color, Enum.Material.SmoothPlastic, shape)
	end
	p("Body", Vector3.new(1.6, 5.6, 1), CFrame.new(0, 4.6, 0), INK)
	p("LegL", Vector3.new(0.5, 2.2, 0.5), CFrame.new(-0.45, 1.1, 0), INK)
	p("LegR", Vector3.new(0.5, 2.2, 0.5), CFrame.new(0.45, 1.1, 0), INK)
	p("ArmL", Vector3.new(0.4, 4.8, 0.4), CFrame.new(-1.1, 4.4, 0) * CFrame.Angles(0, 0, math.rad(-6)), INK)
	p("ArmR", Vector3.new(0.4, 4.8, 0.4), CFrame.new(1.1, 4.4, 0) * CFrame.Angles(0, 0, math.rad(6)), INK)
	p("Head", Vector3.new(2, 2, 2), CFrame.new(0, 8.4, 0), INK, Enum.PartType.Ball)
	for _, side in { -1, 1 } do
		local eye = p("Eye", Vector3.new(0.55, 0.7, 0.2), CFrame.new(0.42 * side, 8.55, -0.92), EYE, Enum.PartType.Ball)
		eye.Material = Enum.Material.Neon
	end
	m.WorldPivot = CFrame.new()
	m:PivotTo(CFrame.new(at) * CFrame.Angles(0, math.pi, 0))
	m.Parent = parent
	return 8.4 * s
end

local function cloneOf(path)
	local node = game
	for part in string.gmatch(path, "[^%.]+") do
		node = node and node:FindFirstChild(part)
	end
	return node and node:Clone() or nil
end

local function placeModel(model, parent, cf)
	anchorAll(model)
	dropJoints(model)
	model:PivotTo(cf)
	model.Parent = parent
	return model
end

local function lightsOff(model)
	for _, d in model:GetDescendants() do
		if d:IsA("Light") then
			d.Enabled = false
		elseif d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			d.Material = Enum.Material.SmoothPlastic
			d.Color = Color3.fromRGB(70, 66, 60)
		end
	end
end

local shots = {}
-- the flash: a spot and a fill light sitting on the camera, aimed at the subject
local function shot(key, cam, look, extra)
	local cellModel = booth:FindFirstChild(key)
	if cellModel then
		local f = block(cellModel, "Flash", Vector3.new(0.2, 0.2, 0.2), CFrame.lookAt(cam + Vector3.new(0.25, 0.35, 0.3), look), Color3.new(1, 1, 1))
		f.Transparency = 1
		f.CastShadow = false
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Angle = 50
		spot.Brightness = 40
		spot.Range = math.max((look - cam).Magnitude * 2.2, 10)
		spot.Color = Color3.fromRGB(235, 240, 255)
		spot.Shadows = true
		spot.Parent = f
		local fill = Instance.new("PointLight")
		fill.Brightness = 8
		fill.Range = math.max((look - cam).Magnitude * 1.6, 8)
		fill.Color = Color3.fromRGB(240, 245, 255)
		fill.Parent = f
	end
	table.insert(shots, { Key = key, Cam = { cam.X, cam.Y, cam.Z }, Look = { look.X, look.Y, look.Z }, Post = extra })
end

local index = 0
local function nextCell(key)
	index += 1
	return cell(index, key)
end

-- Family A: customers ---------------------------------------------------------------------------------------------
do
	local c, base = nextCell("anm_001_blank_folks")
	local r = rig(c, base + Vector3.new(0, 0, -3), "dog", "civil_a", "Blank", true)
	dropJoints(r)
	shot(c.Name, headShot(r))
end
do
	local c, base = nextCell("anm_004_copies")
	local a = rig(c, base + Vector3.new(-1.9, 0, -3), "cat", "civil_b", "Normal")
	local b = rig(c, base + Vector3.new(1.9, 0, -3), "cat", "civil_b", "EyesWhite")
	local sheets = CrewLooks.Outfits["civil_b_mirror"]
	local sheet = sheets and sheets[CrewRig.EffectivePack("civil_b", "Day")]
	if sheet then
		for _, child in b:GetChildren() do
			if child:IsA("MeshPart") and child:GetAttribute("OutfitPart") then
				child.TextureID = sheet
			end
		end
	end
	dropJoints(a)
	dropJoints(b)
	local h = a:FindFirstChild("Head", true).Position
	shot(c.Name, base + Vector3.new(0.1, h.Y - base.Y - 0.3, 6.6), base + Vector3.new(0, h.Y - base.Y - 1.2, -3))
end
do
	local c, base = nextCell("anm_005_raincoat_lady")
	local r = rig(c, base + Vector3.new(0, 0, -3), "rabbit", "civil_c", "EyesClosed")
	-- the placeholder raincoat of Effects/ANM-005 (dressCoat), same sizes and offsets
	local COAT, BOOTS, LIFT = Color3.fromHex("#F2C230"), Color3.fromHex("#5FA36A"), 0.14
	local torso = r:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		local size = torso.Size
		local height = size.Y * 1.5
		block(c, "Raincoat", Vector3.new(size.X * 1.14, height, size.Z * 1.24), torso.CFrame * CFrame.new(0, size.Y / 2 + LIFT - height / 2, 0), COAT)
	end
	for _, side in { "Left", "Right" } do
		local arm = r:FindFirstChild(side .. " Arm")
		if arm and arm:IsA("BasePart") then
			local size = arm.Size
			local height = size.Y * 0.86
			block(c, "RaincoatSleeve", Vector3.new(size.X * 1.2, height, size.Z * 1.2), arm.CFrame * CFrame.new(0, size.Y / 2 + LIFT + 0.02 - height / 2, 0), COAT)
		end
		local leg = r:FindFirstChild(side .. " Leg")
		if leg and leg:IsA("BasePart") then
			local size = leg.Size
			block(c, "RaincoatBoot", Vector3.new(size.X * 1.12, size.Y * 0.35, size.Z * 1.15), leg.CFrame * CFrame.new(0, -size.Y * 0.325, 0), BOOTS)
		end
	end
	-- a few drops falling off her
	for i = 1, 14 do
		local x, y, z = (i * 37 % 23) / 23 - 0.5, (i * 53 % 29) / 29, (i * 17 % 13) / 13 - 0.5
		local d = block(c, "Drop", Vector3.new(0.07, 0.2, 0.07), CFrame.new(r:GetPivot().Position + Vector3.new(x * 2.6, -1.5 + y * 3.5, 0.6 + z)), Color3.fromHex("#6FB6EA"), Enum.Material.Glass)
		d.Transparency = 0.25
	end
	dropJoints(r)
	shot(c.Name, headShot(r))
end
do
	local c, base = nextCell("anm_011_shaker")
	local r = rig(c, base + Vector3.new(0, 0, -3), "fox", "civil_d", "Angry")
	dropJoints(r)
	local cam, look = headShot(r)
	shot(c.Name, cam, look, "shake")
end
do
	local c, base = nextCell("anm_012_turned_neck")
	local r = rig(c, base + Vector3.new(0, 0, -3), "panda", "civil_e", "Normal")
	transformHead(r, function(p, neck)
		local axis = CFrame.new(neck)
		p.CFrame = axis * CFrame.Angles(0, math.pi, math.rad(8)) * axis:Inverse() * p.CFrame
	end)
	dropJoints(r)
	shot(c.Name, headShot(r))
end
do
	local c, base = nextCell("anm_013_white_eyes")
	local r = rig(c, base + Vector3.new(0, 0, -3), "bear", "civil_f", "EyesWhite")
	dropJoints(r)
	shot(c.Name, headShot(r))
end
do
	local c, base = nextCell("anm_014_big_head")
	local r = rig(c, base + Vector3.new(0, 0, -3), "hamster", "civil_g", "Normal")
	local k = 1.9
	transformHead(r, function(p, neck)
		local offset = p.Position - neck
		p.Size = p.Size * k
		p.CFrame = CFrame.new(neck + offset * k) * p.CFrame.Rotation
	end)
	dropJoints(r)
	local head = r:FindFirstChild("Head", true).Position
	shot(c.Name, head + Vector3.new(0.1, -0.4, 8.2), head - Vector3.new(0, 1.2, 0))
end
do
	local c, base = nextCell("anm_015_floater")
	-- a pale floor so the gap under the feet reads (no shadow: the sign of the page)
	block(c, "Ground", Vector3.new(14, 0.2, 14), CFrame.new(base + Vector3.new(0, 0.1, -3)), Color3.fromRGB(120, 116, 112), Enum.Material.Concrete).CastShadow = false
	local r = rig(c, base + Vector3.new(0, 0.2, -3), "penguin", "civil_h", "Normal")
	r:PivotTo(r:GetPivot() + Vector3.new(0, 1.1, 0))
	for _, d in r:GetDescendants() do
		if d:IsA("BasePart") then
			d.CastShadow = false
		end
	end
	dropJoints(r)
	shot(c.Name, base + Vector3.new(0.1, 1.6, 4.6), Vector3.new(base.X, base.Y + 1.7, base.Z - 3))
end
do
	local c, base = nextCell("anm_016_starer")
	local r = rig(c, base + Vector3.new(0, 0, -3), "owl", "civil_a", "Normal")
	-- the body turns away, the head keeps looking at the camera
	r:PivotTo(r:GetPivot() * CFrame.Angles(0, math.rad(70), 0))
	transformHead(r, function(p, neck)
		local axis = CFrame.new(neck)
		p.CFrame = axis * CFrame.Angles(0, math.rad(-70), 0) * axis:Inverse() * p.CFrame
	end)
	dropJoints(r)
	shot(c.Name, headShot(r))
end

-- Family B and the stalker: the monsters ---------------------------------------------------------------------------
do
	local c, base = nextCell("anm_007_walker")
	local y = monster(c, "Walk", base + Vector3.new(0, 0, -4))
	shot(c.Name, base + Vector3.new(0.2, y - 0.6, 4.5), base + Vector3.new(0, y - 1.2, -4))
end
do
	local c, base = nextCell("anm_017_crawler")
	local y = monster(c, "Crawl", base + Vector3.new(0, 0, -4))
	shot(c.Name, base + Vector3.new(0.3, y + 0.6, 2.8), base + Vector3.new(0, y - 0.3, -1.8))
end
do
	local c, base = nextCell("anm_018_grin")
	local y = monster(c, "Grin", base + Vector3.new(0, 0, -6))
	shot(c.Name, base + Vector3.new(0, y, 5), base + Vector3.new(0, y - 0.4, -6))
end
do
	local c, base = nextCell("anm_019_roof_walker")
	-- looking up at it: it crouches on the edge of a dark roof
	block(c, "Roof", Vector3.new(14, 1, 8), CFrame.new(base + Vector3.new(0, 9, -6)), Color3.fromRGB(28, 26, 32))
	local y = monster(c, "Roof", base + Vector3.new(0, 9.5, -4.5))
	shot(c.Name, base + Vector3.new(0.4, 4, 4), base + Vector3.new(0, 9.5 + y - 1, -4.5))
end
do
	local c, base = nextCell("anm_006_stalker")
	local y = stalker(c, base + Vector3.new(2, 0, -14))
	shot(c.Name, base + Vector3.new(-1, 5, 8), base + Vector3.new(2, y - 2.5, -14))
end

-- The world ones --------------------------------------------------------------------------------------------------
do
	local c, base = nextCell("anm_002_wrong_food")
	block(c, "Counter", Vector3.new(6, 3, 3), CFrame.new(base + Vector3.new(0, 1.5, -2)), Color3.fromRGB(150, 150, 158), Enum.Material.Metal)
	local top = base.Y + 3
	local items = {
		{ "ReplicatedStorage.Assets.Items.Food.BunBitten", Vector3.new(-0.8, 0, -2) },
		{ "ReplicatedStorage.Assets.Items.Food.SausageWrong", Vector3.new(0.7, 0, -2.1) },
		{ "ReplicatedStorage.Assets.Items.WrongToppings.Wrong_Worms", Vector3.new(-0.7, 0.25, -2) },
		{ "ReplicatedStorage.Assets.Items.WrongToppings.Wrong_Roach", Vector3.new(1.2, 0, -1.5) },
	}
	for _, it in items do
		local m = cloneOf(it[1])
		if m then
			if m:IsA("BasePart") then
				local w = Instance.new("Model")
				m.Parent = w
				m = w
			end
			anchorAll(m)
			dropJoints(m)
			local cf, size = m:GetBoundingBox()
			local at = Vector3.new(base.X, top, base.Z) + it[2]
			m:PivotTo(m:GetPivot() + (at - Vector3.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z)))
			m.Parent = c
		end
	end
	shot(c.Name, Vector3.new(base.X + 0.1, top + 1.6, base.Z + 0.6), Vector3.new(base.X, top + 0.1, base.Z - 2))
end
do
	local c, base = nextCell("anm_003_stopped_clock")
	-- the street lamp that dies on the first ring, seen from below
	local post = cloneOf("Workspace.MAP01_Assets.StreetLights.Model")
	local height = 12
	if post then
		lightsOff(post)
		anchorAll(post)
		dropJoints(post)
		post.Parent = c
		local bcf, bsize = post:GetBoundingBox()
		post:PivotTo(post:GetPivot() + Vector3.new(base.X - bcf.Position.X, base.Y - (bcf.Position.Y - bsize.Y / 2), base.Z - 6 - bcf.Position.Z))
		height = bsize.Y
	end
	shot(c.Name, base + Vector3.new(3, 3, 6), base + Vector3.new(0, height * 0.8, -6))
end
do
	local c, base = nextCell("anm_010_hush")
	local post = cloneOf("Workspace.MAP01_Assets.StreetLights.Model")
	if post then
		lightsOff(post)
		anchorAll(post)
		dropJoints(post)
		post.Parent = c
		local bcf, bsize = post:GetBoundingBox()
		post:PivotTo(post:GetPivot() + Vector3.new(base.X - bcf.Position.X, base.Y - (bcf.Position.Y - bsize.Y / 2), base.Z - 8 - bcf.Position.Z))
	end
	-- the fog is added in post (flash.py "fog")
	shot(c.Name, base + Vector3.new(1, 3, 8), base + Vector3.new(0, 5, -8), "fog")
end
do
	local c, base = nextCell("anm_008_long_car")
	local car = cloneOf("ReplicatedStorage.Assets.Vehicles.LongCar")
	if car then
		anchorAll(car)
		dropJoints(car)
		car.Parent = c
		local bcf, bsize = car:GetBoundingBox()
		-- the long side across the room, the nose towards the camera side
		if bsize.X > bsize.Z then
			car:PivotTo(car:GetPivot() * CFrame.Angles(0, math.rad(90), 0))
		end
		-- the nose towards the camera (the tail lights away)
		car:PivotTo(car:GetPivot() * CFrame.Angles(0, math.pi, 0))
		bcf, bsize = car:GetBoundingBox()
		car:PivotTo(car:GetPivot() + Vector3.new(base.X - bcf.Position.X, base.Y - (bcf.Position.Y - bsize.Y / 2), base.Z - 4 - bcf.Position.Z))
		bcf, bsize = car:GetBoundingBox()
		-- headlights on, glaring at the camera
		for _, x in { -1, 1 } do
			local hl = block(c, "Headlight", Vector3.new(1, 0.6, 0.2), CFrame.new(bcf.Position + Vector3.new(x * bsize.X * 0.32, -bsize.Y * 0.12, bsize.Z / 2 + 0.05)), Color3.fromRGB(255, 250, 225), Enum.Material.Neon)
			local l = Instance.new("SpotLight")
			l.Face = Enum.NormalId.Back
			l.Brightness = 10
			l.Range = 30
			l.Angle = 50
			l.Parent = hl
		end
		shot(c.Name, base + Vector3.new(-5, 2.5, bsize.Z / 2 + 4), bcf.Position)
	end
end
do
	local c, base = nextCell("anm_009_knock")
	local door = cloneOf("Workspace.MAP01_Restaurant.TRL.Shell.BackDoor") or cloneOf("ServerStorage.TrailerBackup.Retired.BackDoor")
	block(c, "Wall", Vector3.new(16, 12, 0.6), CFrame.new(base + Vector3.new(0, 6, -6)), Color3.fromRGB(205, 200, 190))
	if door then
		door.Anchored = true
		door.Parent = c
		door.CFrame = CFrame.new(base + Vector3.new(0, door.Size.Y / 2, -5.6)) * door.CFrame.Rotation
	end
	-- a thin line of cold light under the door: someone stands outside
	block(c, "UnderLight", Vector3.new(3.2, 0.06, 0.1), CFrame.new(base + Vector3.new(0, 0.05, -5.35)), Color3.fromRGB(200, 215, 255), Enum.Material.Neon)
	-- two feet cut the line
	for _, x in { -0.45, 0.45 } do
		block(c, "Feet", Vector3.new(0.5, 0.08, 0.12), CFrame.new(base + Vector3.new(x, 0.05, -5.3)), Color3.new(0, 0, 0))
	end
	shot(c.Name, base + Vector3.new(0.6, 4.5, 4), base + Vector3.new(0, 3.5, -6))
end
do
	local c, base = nextCell("anm_020_blackout")
	local breaker = cloneOf("Workspace.MAP01_Restaurant.TRL.Kitchen.TRL-BREAKER")
	block(c, "Wall", Vector3.new(16, 12, 0.6), CFrame.new(base + Vector3.new(0, 6, -6)), Color3.fromRGB(80, 78, 84))
	if breaker then
		anchorAll(breaker)
		dropJoints(breaker)
		breaker.Parent = c
		local bcf, bsize = breaker:GetBoundingBox()
		breaker:PivotTo(breaker:GetPivot() + (base + Vector3.new(-2.2, 4.5, -5.5) - bcf.Position))
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromHex("#F2C230")
		glow.Brightness = 2
		glow.Range = 5
		glow.Parent = breaker:FindFirstChildWhichIsA("BasePart", true)
	end
	-- the shape at the corner of the eye
	stalker(c, base + Vector3.new(4.2, 0, -4.8), 0.75)
	shot(c.Name, base + Vector3.new(-1.2, 4.5, 5), base + Vector3.new(0.6, 4.2, -6))
end

booth.Parent = workspace
return shots
