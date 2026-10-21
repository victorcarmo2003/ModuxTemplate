--!nocheck
-- Halloween overlay of the lobby (DEC-346, TASK-628; docs/levels/LOBBY-halloween.md). Studio snippet, run in Edit
-- through the Studio MCP (execute_luau) or the command bar. Idempotent: it destroys workspace.HalloweenEvent and builds
-- it again from this table. NOTHING outside that folder is touched (P-HW4). Undo / turn the event off for good:
--   workspace.HalloweenEvent:Destroy()   (and Content.Events.Halloween.Enabled = false)
-- Assets: AST-167..176 (Assets/import/props/AST-1[67]*_HW_*.fbx, ids in Assets/import/_asset_ids.json), loaded with
-- InsertService:LoadAsset. Y: raycast down onto the lobby (ground or the top of what is there) unless `y` (absolute)
-- is given; `lift` adds to it. rot = yaw in degrees (model front = -Z; rot 0 faces the plaza from the north side).
-- Decoration only: Anchored, no collision / query / touch, no shadow; the one collider is the cauldron proxy.
-- Budget: 0 lights, 3 ParticleEmitters (cauldron mist, cauldron burst, fountain sparkle).

local InsertService = game:GetService("InsertService")

local IDS = {
	Cauldron = 103122336364861,
	PumpkinS = 135059097513885,
	PumpkinM = 128073677545863,
	PumpkinL = 140365537291135,
	FaceA = 93220104724749,
	FaceB = 121121531041116,
	FaceC = 95443265107738,
	LanternPost = 98175680482332,
	LanternHang = 109748952856215,
	Bucket = 138694442134843,
	Candy = 135699982688980,
	Crate = 122269345466970,
	Bat = 138648807310310,
	Cobweb = 70382029126381,
	Pennant = 121244127913748,
	Ghost = 95745353403698,
	HotdogSign = 134287652569241,
	Moon = 72917162974163,
	PhotoSign = 108170963780527,
	CrystalA = 114268236398777,
	CrystalB = 116423954556732,
}

-- Neon colour of the Glow_* parts (the atlas band under them is white, so Color is the glow)
local GLOW = {
	Glow_Liquid = Color3.fromRGB(95, 211, 141),
	Glow_Face = Color3.fromRGB(255, 170, 70),
	Glow_Lamp = Color3.fromRGB(255, 196, 120),
	Glow_Stars = Color3.fromRGB(255, 232, 170),
}
local TIPS = { CrystalA = Color3.fromRGB(190, 150, 255), CrystalB = Color3.fromRGB(255, 178, 90) }

local CS = 1.3 -- cauldron scale (landmark readable from the spawn)

local P = {}
local function add(zone, name, asset, x, z, rot, opts)
	opts = opts or {}
	table.insert(P, { Zone = zone, Name = name, Asset = asset, X = x, Z = z, Rot = rot or 0, Opts = opts })
end

-- Z-A cauldron landmark. Owner hand edit in Studio (2026-10-21, DEC-349): the whole group moved west, beside the food
-- court, and the two lanterns went to the squad gantry. Absolute values read back from the place (y included).
add("HW_Spawn", "Cauldron", "Cauldron", -35.03, -590.43, -20.6, { Role = "Cauldron", Scale = CS, y = -0.19 })
add("HW_Spawn", "Pumpkin_FaceA", "FaceA", -29.37, -590.73, -35.2, { y = 0.06 })
add("HW_Spawn", "Pumpkin_FaceC", "FaceC", -37.37, -596.07, -25.2, { y = 0.06 })
add("HW_Spawn", "Pumpkin_Large", "PumpkinL", -31.56, -584.48, -49.8, { y = 0.06 })
add("HW_Spawn", "Pumpkin_FaceB", "FaceB", -41.81, -589.34, -55.2, { y = 0.06 })
add("HW_Spawn", "Pumpkin_Small", "PumpkinS", -31.26, -593.02, -9.8, { y = 0.06 })
add("HW_Spawn", "Candy_Bucket", "Bucket", -33.72, -595.39, -35.2, { y = 0.06 })
add("HW_Spawn", "Candy_Cluster", "Candy", -31.42, -595.04, -54.8, { y = 0.06 })
add("HW_Spawn", "Lantern_1", "LanternPost", 22.18, -666.25, 134.6, { y = -0.19 })
add("HW_Spawn", "Lantern_2", "LanternPost", 24.99, -578.75, 34.6, { y = -0.19 })

-- Z-B Hot Dogs (HQ cart + food court)
add("HW_HotDogs", "HotdogPumpkinSign", "HotdogSign", 17.8, -549.4, 0, { y = 11.2, Scale = 2.0 }) -- on the facade, beside the CORNER DOGS board
add("HW_HotDogs", "StackE_Large", "PumpkinL", 24.0, -575.5, 15)
add("HW_HotDogs", "StackE_Top", "FaceC", 24.0, -575.5, -10, { Stack = 2.25 })
add("HW_HotDogs", "StackE_Small", "PumpkinS", 25.9, -573.8, 0)
add("HW_HotDogs", "StackW_Large", "PumpkinL", -23.0, -569.8, -10)
add("HW_HotDogs", "StackW_FaceB", "FaceB", -20.9, -571.4, 0)
add("HW_HotDogs", "StackW_Small", "PumpkinS", -21.6, -573.6, 30)
add("HW_HotDogs", "Lantern_ClassesW", "LanternPost", -17.2, -571.5, 0)
add("HW_HotDogs", "Lantern_ClassesE", "LanternPost", 14.5, -571.5, 0)
add("HW_HotDogs", "Crate_1", "Crate", -66.0, -568.6, 10)
add("HW_HotDogs", "Crate_2", "Crate", -66.0, -568.6, -12, { Stack = 1.6, Scale = 0.8 })
add("HW_HotDogs", "Crate_3", "Crate", -63.3, -568.4, -4)
add("HW_HotDogs", "Bucket_Crate", "Bucket", -63.3, -568.4, 20, { Stack = 1.6 })
add("HW_HotDogs", "Bucket_Bin", "Bucket", -31.4, -568.6, -15)

-- Z-C fountain (nothing of the fountain changes: props on the planters, lanterns by the benches, one sparkle emitter)
add("HW_Fountain", "Planter_NE", "PumpkinS", -23, -647, 10)
add("HW_Fountain", "Planter_SE", "PumpkinS", -23, -683, 70)
add("HW_Fountain", "Planter_NW", "PumpkinS", -69, -646, -40)
add("HW_Fountain", "Planter_SW", "PumpkinS", -69, -683, 120)
add("HW_Fountain", "Lantern_N", "LanternPost", -39.8, -641.2, 0)
add("HW_Fountain", "Lantern_S", "LanternPost", -49.6, -686.6, 180)

-- Z-D Gem Shop / Codes
add("HW_GemShop", "Crystal_N", "CrystalA", -47.2, -605.2, 20, { Scale = 1.2 })
add("HW_GemShop", "Crystal_S", "CrystalB", -47.2, -634.8, -30, { Scale = 1.2 })
add("HW_GemShop", "Cobweb_N", "Cobweb", -45.5, -603.6, 90, { y = 13.6 })
add("HW_GemShop", "Cobweb_S", "Cobweb", -45.5, -636.4, -90, { y = 13.6 })
add("HW_GemShop", "Pumpkin_N", "FaceA", -44.6, -600.6, -70)
add("HW_GemShop", "Pumpkin_N2", "PumpkinS", -42.6, -600.3, -20)
add("HW_GemShop", "Pumpkin_S", "FaceC", -42.0, -639.6, -110)
add("HW_Codes", "Lantern_W", "LanternPost", -13.2, -683.4, 180)
add("HW_Codes", "Lantern_E", "LanternPost", 10.0, -683.4, 180)
add("HW_Codes", "Bat_W", "Bat", -4.9, -681.0, 180, { y = 7.6 })
add("HW_Codes", "Bat_E", "Bat", 3.6, -681.0, 165, { y = 7.3 })
add("HW_Codes", "Ghost_Peek", "Ghost", 7.6, -684.8, 200, { lift = 0.3, Scale = 0.9 })
add("HW_Codes", "Cobweb_Board", "Cobweb", -6.0, -680.9, 0, { y = 9.0 })

-- Z-E edges, rooflines, windows
add("HW_Edges", "W1_Large", "PumpkinL", -76.4, -588.0, 30)
add("HW_Edges", "W1_Small", "PumpkinS", -75.0, -590.4, -10)
add("HW_Edges", "W2_Medium", "FaceA", -76.4, -633.0, -80)
add("HW_Edges", "W2_FaceB", "FaceB", -75.6, -635.8, -90)
add("HW_Edges", "S1_Medium", "FaceB", -60.0, -692.4, 170)
add("HW_Edges", "S1_Small", "PumpkinS", -57.8, -692.0, 40)
add("HW_Edges", "S2_Large", "PumpkinL", 28.0, -692.2, -20)
add("HW_Edges", "S2_FaceC", "FaceC", 25.2, -691.0, 180)
add("HW_Edges", "Bat_N1", "Bat", -35.0, -547.0, 0, { y = 36, Flap = true })
add("HW_Edges", "Bat_N2", "Bat", -30.5, -548.0, 10, { y = 38.5, Scale = 0.8 })
add("HW_Edges", "Bat_W1", "Bat", -76.0, -612.0, -90, { y = 38, Flap = true })
add("HW_Edges", "Bat_W2", "Bat", -76.5, -617.0, -80, { y = 35, Scale = 0.8 })
add("HW_Edges", "Bat_S1", "Bat", 10.0, -690.0, 180, { y = 40, Flap = true })
add("HW_Edges", "Bat_S2", "Bat", 15.0, -689.5, 190, { y = 37.5, Scale = 0.8 })
add("HW_Edges", "Cobweb_Photo", "Cobweb", 42.2, -559.3, 180, { y = 9.7 })
add("HW_Edges", "Pennant_1", "Pennant", 28.2, -666.0, 90, { y = 15.3 })
add("HW_Edges", "Pennant_2", "Pennant", 28.2, -654.0, 90, { y = 15.3 })
add("HW_Edges", "Pennant_3", "Pennant", 28.2, -642.0, 90, { y = 15.3 })
add("HW_Edges", "Pennant_4", "Pennant", 28.2, -606.0, 90, { y = 15.3 })
add("HW_Edges", "Pennant_5", "Pennant", 28.2, -594.0, 90, { y = 15.3 })
add("HW_Edges", "Pennant_6", "Pennant", 28.2, -582.0, 90, { y = 15.3 })

-- Z-F photo corner (east of the existing PHOTO booth)
add("HW_Photo", "MoonArch", "Moon", 49.5, -562.5, 0, { Glow = "MoonArch" })
add("HW_Photo", "Ghost", "Ghost", 44.8, -565.0, 0, { lift = 0.8, Scale = 1.1 })
add("HW_Photo", "Pumpkin_FaceA", "FaceA", 54.3, -561.5, -15)
add("HW_Photo", "Pumpkin_Medium", "FaceB", 53.6, -564.4, 10)
add("HW_Photo", "Pumpkin_Small", "PumpkinS", 52.2, -565.6, -50)
add("HW_Photo", "SpookySign", "PhotoSign", 30.5, -563.0, 0, { Scale = 1.2, Label = "SPOOKY SNAPSHOT" })

-- Window eyes (DEC-289 L6 idea, Mild): two Neon dots in a dark window, the client blinks them (attribute HW_Blink)
local EYES = {
	{ Name = "Eyes_HQ", Center = Vector3.new(2.9, 26.3, -541.4), Normal = Vector3.new(0, 0, -1), D = 0.9, Gap = 1.1 },
	{ Name = "Eyes_West", Center = Vector3.new(-80.2, 17.6, -650.3), Normal = Vector3.new(1, 0, 0), D = 1.1, Gap = 1.6 },
}

local function decorate(model, opts)
	for _, d in model:GetDescendants() do
		if d:IsA("PackageLink") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			d.Locked = true
			local glow = GLOW[d.Name]
			if d.Name == "Glow_Tips" then
				glow = TIPS[opts.Asset]
			end
			if glow then
				d.Material = Enum.Material.Neon
				d.Color = glow
				if d:IsA("MeshPart") then
					d.TextureID = "" -- the white band adds nothing; Color alone drives the Neon
				end
			end
		end
	end
end

local function groundY(x, z, exclude)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { exclude }
	local boundary = workspace:FindFirstChild("LOBBY_Assets") and workspace.LOBBY_Assets:FindFirstChild("Boundary")
	if boundary then
		table.insert(ignore, boundary)
	end
	for _ = 1, 12 do
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -120, 0), params)
		if not hit then
			return 0, "none"
		end
		if hit.Instance.Transparency < 0.95 then
			return hit.Position.Y, hit.Instance:GetFullName()
		end
		table.insert(ignore, hit.Instance)
	end
	return 0, "none"
end

local old = workspace:FindFirstChild("HalloweenEvent")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "HalloweenEvent"
root:SetAttribute("Event", "Halloween2026")
root:SetAttribute("EndsAt", 1793934000)
local zones = {}
local function zoneFolder(name)
	if not zones[name] then
		local z = Instance.new("Folder")
		z.Name = name
		z.Parent = root
		zones[name] = z
	end
	return zones[name]
end

local cache = {}
local report = {}
for _, p in P do
	local template = cache[p.Asset]
	if not template then
		local holder = InsertService:LoadAsset(IDS[p.Asset])
		template = holder:FindFirstChildWhichIsA("Model") or holder
		template.Parent = nil
		cache[p.Asset] = template
	end
	local model = template:Clone()
	model.Name = p.Name
	local o = p.Opts
	o.Asset = p.Asset
	decorate(model, o)
	local y, hit = 0, "abs"
	if o.y then
		y = o.y
	else
		y, hit = groundY(p.X, p.Z, root)
	end
	y += (o.lift or 0) + (o.Stack or 0)
	-- pivot = base centre of the FBX (origin, where LoadAsset leaves it): scale about it, then put it on the ground point
	model.WorldPivot = CFrame.new(0, 0, 0)
	if o.Scale then
		model:ScaleTo(o.Scale)
	end
	model:PivotTo(CFrame.new(p.X, y, p.Z) * CFrame.Angles(0, math.rad(p.Rot), 0))
	if o.Role then
		model:SetAttribute("HW_Role", o.Role)
	end
	if o.Glow then -- a whole body that glows softly at night (the photo moon); its atlas texture is kept under the Neon
		local body = model:FindFirstChild(o.Glow, true)
		if body then
			body.Material = Enum.Material.Neon
			body.Color = Color3.fromRGB(215, 195, 145)
		end
	end
	local liquid = model:FindFirstChild("Glow_Liquid", true)
	if liquid then -- dome it up so the potion shows over the rim at eye height
		local k = o.Scale or 1
		liquid.Size = Vector3.new(liquid.Size.X, liquid.Size.Y * 4, liquid.Size.Z)
		liquid.Position += Vector3.new(0, 0.45 * k, 0)
	end
	if o.Flap then
		model:SetAttribute("HW_Flap", true)
	end
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- like the lobby root (P-L9): never streams out
	model.Parent = zoneFolder(p.Zone)
	table.insert(report, string.format("%-18s %-11s (%.1f, %.2f, %.1f) on %s", p.Name, p.Asset, p.X, y, p.Z, hit))

	if o.Label then -- text on the photo sign board (front = -Z)
		local s = o.Scale or 1
		local label = Instance.new("Part")
		label.Name = "SignLabel"
		label.Size = Vector3.new(4.9 * s, 1.25 * s, 0.05)
		label.Transparency = 1
		label.Anchored, label.CanCollide, label.CanQuery, label.CanTouch, label.Locked = true, false, false, false, true
		label.CFrame = CFrame.new(p.X, y, p.Z) * CFrame.Angles(0, math.rad(p.Rot), 0) * CFrame.new(0, 2.75 * s, -0.2 * s)
		label.Parent = model
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 60
		gui.LightInfluence = 0.2
		gui.Parent = label
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.Text = o.Label
		text.TextColor3 = Color3.fromRGB(255, 243, 220)
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(242, 140, 40)
		stroke.Thickness = 3
		stroke.Parent = text
		text.Parent = gui
	end

	if o.Role == "Cauldron" then
		local proxy = Instance.new("Part") -- the one collider of the overlay: players walk around the cauldron
		proxy.Name = "CollisionProxy"
		proxy.Shape = Enum.PartType.Cylinder
		local k = o.Scale or 1
		proxy.Size = Vector3.new(4.6, 7.0, 7.0) * k
		proxy.CFrame = CFrame.new(p.X, y + 2.3 * k, p.Z) * CFrame.Angles(0, 0, math.rad(90))
		proxy.Transparency = 1
		proxy.Anchored, proxy.CanCollide, proxy.CanQuery, proxy.CanTouch, proxy.Locked = true, true, false, false, true
		proxy.Parent = model
		local mist = Instance.new("Part") -- emitters 1 and 2: purple mist (always) and the burst sparkle (client Emit)
		mist.Name = "HW_FxAnchor"
		mist.Size = Vector3.new(4.6 * k, 0.2, 4.6 * k)
		mist.CFrame = CFrame.new(p.X, y + 4.2 * k, p.Z)
		mist.Transparency = 1
		mist.Anchored, mist.CanCollide, mist.CanQuery, mist.CanTouch, mist.Locked = true, false, false, false, true
		mist.Parent = model
		local e = Instance.new("ParticleEmitter")
		e.Name = "HW_Mist"
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(150, 100, 220), Color3.fromRGB(90, 60, 160))
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.6), NumberSequenceKeypoint.new(1, 1) })
		e.Size = NumberSequence.new(2.2, 4.2)
		e.Lifetime = NumberRange.new(2.5, 3.5)
		e.Rate = 3
		e.Speed = NumberRange.new(0.6, 1.2)
		e.SpreadAngle = Vector2.new(15, 15)
		e.EmissionDirection = Enum.NormalId.Top
		e.LightEmission = 0.3
		e.Parent = mist
		local b = Instance.new("ParticleEmitter")
		b.Name = "HW_Burst"
		b.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		b.Color = ColorSequence.new(Color3.fromRGB(140, 255, 190), Color3.fromRGB(200, 160, 255))
		b.Size = NumberSequence.new(0.5, 0.1)
		b.Lifetime = NumberRange.new(0.8, 1.4)
		b.Rate = 0
		b.Speed = NumberRange.new(3, 6)
		b.SpreadAngle = Vector2.new(35, 35)
		b.EmissionDirection = Enum.NormalId.Top
		b.LightEmission = 0.6
		b.Parent = mist
	end
end

do -- emitter 3: fountain sparkle (the fountain itself is untouched)
	local anchor = Instance.new("Part")
	anchor.Name = "HW_FountainSparkle"
	anchor.Size = Vector3.new(8, 0.2, 8)
	anchor.CFrame = CFrame.new(-45.7, 2.4, -664.2)
	anchor.Transparency = 1
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch, anchor.Locked = true, false, false, false, true
	anchor.Parent = zoneFolder("HW_Fountain")
	local e = Instance.new("ParticleEmitter")
	e.Name = "HW_Sparkle"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(180, 140, 255), Color3.fromRGB(110, 230, 230))
	e.Size = NumberSequence.new(0.35, 0.05)
	e.Lifetime = NumberRange.new(1.5, 2.5)
	e.Rate = 3
	e.Speed = NumberRange.new(0.4, 1)
	e.EmissionDirection = Enum.NormalId.Top
	e.LightEmission = 0.5
	e.Parent = anchor
end

for _, eye in EYES do
	local model = Instance.new("Model")
	model.Name = eye.Name
	model:SetAttribute("HW_Blink", true)
	local side = Vector3.new(0, 1, 0):Cross(eye.Normal).Unit
	for i, s in { -1, 1 } do
		local ball = Instance.new("Part")
		ball.Name = "Eye" .. i
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(eye.D, eye.D, eye.D)
		ball.Material = Enum.Material.Neon
		ball.Color = Color3.fromRGB(255, 236, 190)
		ball.Position = eye.Center + eye.Normal * (0.1 + eye.D / 2 - 0.25) + side * s * eye.Gap / 2
		ball.Anchored, ball.CanCollide, ball.CanQuery, ball.CanTouch, ball.CastShadow, ball.Locked = true, false, false, false, false, true
		ball.Parent = model
	end
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = zoneFolder("HW_Edges")
	table.insert(report, eye.Name)
end

for _, t in cache do
	t:Destroy()
end
root.Parent = workspace

local count, tris = 0, 0
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then
		count += 1
	end
end
table.insert(report, "parts: " .. count)
return table.concat(report, "\n")
