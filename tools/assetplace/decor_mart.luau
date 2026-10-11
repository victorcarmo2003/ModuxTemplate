--[[
	Mart dressing pass (user 2026-10-11: "the Mart looks dead / disguised in the map").
	FROZEN 2026-10-11: the user edited MartDecor / PadDecor by hand in Studio (deleted the carts, baskets, bottle
	return, tables, bushes, barrel; moved and duplicated pieces). The place holds the result now. Decor.run / runPad
	refuse to touch an existing folder unless called with force = true (that would bring back what the user deleted).
	Originally: rebuilds workspace.MAP01_Assets.MartDecor and re-applies the surface details. Run after
	place_assets / bind_map01 (it only adds, never moves an entry of the placements):
		local Decor = require(<this module>)
		Decor.run()
	Positions are WORLD coordinates (the Mart corner of this place, after MAP_FRAME). Edits made by hand inside
	MartDecor are lost on the next run: change this file instead.

	What it does
	  1. Sidewalk slabs: Texture on the top face of every AST-032 sidewalk tile (AST-032_sidewalk_slabs.png).
	  2. Mart name plates (AST-028_SignName): SurfaceGui "NINTH ST. MART" on the blank plates, glowing.
	  3. Corner blade sign "MART" with neon edges at the street corner, neon strips under the awnings.
	  4. Inner corner columns (Mini Market column) over the wall seams.
	  5. Upgrade wall: header sign, accent backdrop and spot lights.
	  6. Entrance: lights under the marquee and inside the door, welcome mat.
	  7. Props: carts by the door, basket stack at the checkout, bottle return, window posters.
]]

local InsertService = game:GetService("InsertService")

local Decor = {}

local ROOT = "MAP01_Assets"
local FOLDER = "MartDecor"

-- uploads (Assets/import/_asset_ids.json, textures in docs/art/credits.md)
local SLAB_TEXTURE = "rbxassetid://75057777594291"
local MM_COLORMAP = "rbxassetid://131566103531055"
local IDS = {
	Column = 104820510687289,
	Cart = 134171497255586,
	Basket = 132192060315515,
	BottleReturn = 121569884138504,
}

local INK = Color3.fromRGB(43, 36, 64)
local MUSTARD = Color3.fromRGB(255, 200, 61)
local PINK = Color3.fromRGB(255, 92, 160)
local MINT = Color3.fromRGB(64, 224, 170)
local CREAM = Color3.fromRGB(255, 244, 214)
local FONT = Font.fromEnum(Enum.Font.FredokaOne)

local folder: Folder
local cache: { [string]: Instance } = {}

local function asset(key: string): Instance?
	if cache[key] then
		return cache[key]
	end
	local ok, model = pcall(function()
		return InsertService:LoadAsset(IDS[key])
	end)
	if not ok or not model then
		warn("[decor_mart] could not load " .. key .. ": " .. tostring(model))
		return nil
	end
	local inner = model:GetChildren()[1]
	for _, d in inner:GetDescendants() do
		if d:IsA("MeshPart") then
			d.TextureID = MM_COLORMAP
			d.Anchored = true
		end
	end
	if inner:IsA("MeshPart") then
		inner.TextureID = MM_COLORMAP
		inner.Anchored = true
	end
	cache[key] = inner
	return inner
end

-- clone of a Mini Market prop, its base on `floor`, scaled to `height` studs (nil = as uploaded)
local function prop(key: string, at: CFrame, height: number?): Instance?
	local tpl = asset(key)
	if not tpl then
		return nil
	end
	local m = tpl:Clone()
	local model: Model
	if m:IsA("Model") then
		model = m
	else
		model = Instance.new("Model")
		model.Name = m.Name
		m.Parent = model
	end
	model.Name = "Decor_" .. key
	if height then
		local _, size0 = model:GetBoundingBox()
		model:ScaleTo(height / size0.Y)
	end
	-- turn first, then put the box bottom centre on `at`
	model:PivotTo(CFrame.new(model:GetPivot().Position) * at.Rotation)
	local cf, size = model:GetBoundingBox()
	local bottom = cf.Position - Vector3.new(0, size.Y / 2, 0)
	model:PivotTo(model:GetPivot() + (at.Position - bottom))
	model.Parent = folder
	return model
end

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = material ~= Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = folder
	return p
end

local function label(on: BasePart, face: Enum.NormalId, text: string, color: Color3, stroke: Color3, glow: boolean?)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "DecorText"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 200
	gui.LightInfluence = if glow then 0 else 0.6
	gui.Brightness = if glow then 2 else 1
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(0.92, 0.84)
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5, 0.5)
	t.BackgroundTransparency = 1
	t.FontFace = FONT
	t.Text = text
	t.TextScaled = true
	t.TextColor3 = color
	local s = Instance.new("UIStroke")
	s.Color = stroke
	s.Thickness = 3
	s.Parent = t
	t.Parent = gui
	gui.Parent = on
end

local function light(cf: CFrame, kind: string, color: Color3, brightness: number, range: number, angle: number?)
	local p = part("LightAnchor", Vector3.new(0.2, 0.2, 0.2), cf, color)
	p.Transparency = 1
	local l: Light
	if kind == "Spot" then
		local s = Instance.new("SpotLight")
		s.Angle = angle or 60
		s.Face = Enum.NormalId.Front
		l = s
	else
		l = Instance.new("PointLight")
	end
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = p
end


-- Neon tube lettering (user 2026-10-11: real 3D letters, not SurfaceGui, so the sign can flicker by switching the
-- material Neon <-> SmoothPlastic). Stroke font on a 2 x 3 grid (y up); every stroke is a chain of Cylinder parts with
-- Ball joints, like bent glass tubes. Each sign is a Model tagged "NeonSign" (attribute Color = its lit colour).
local GLYPHS: { [string]: { { number } } } = {
	A = { { 0, 0, 1, 3, 2, 0 }, { 0.4, 1.2, 1.6, 1.2 } },
	C = { { 2, 2.6, 1.5, 3, 0.5, 3, 0, 2.4, 0, 0.6, 0.5, 0, 1.5, 0, 2, 0.4 } },
	D = { { 0, 0, 0, 3, 1.2, 3, 2, 2.2, 2, 0.8, 1.2, 0, 0, 0 } },
	E = { { 2, 3, 0, 3, 0, 0, 2, 0 }, { 0, 1.5, 1.4, 1.5 } },
	G = { { 2, 2.6, 1.5, 3, 0.5, 3, 0, 2.4, 0, 0.6, 0.5, 0, 1.5, 0, 2, 0.5, 2, 1.3, 1.1, 1.3 } },
	H = { { 0, 0, 0, 3 }, { 2, 0, 2, 3 }, { 0, 1.5, 2, 1.5 } },
	I = { { 1, 0, 1, 3 }, { 0.4, 3, 1.6, 3 }, { 0.4, 0, 1.6, 0 } },
	L = { { 0, 3, 0, 0, 2, 0 } },
	M = { { 0, 0, 0, 3, 1, 1.5, 2, 3, 2, 0 } },
	N = { { 0, 0, 0, 3, 2, 0, 2, 3 } },
	O = { { 0.5, 0, 0, 0.6, 0, 2.4, 0.5, 3, 1.5, 3, 2, 2.4, 2, 0.6, 1.5, 0, 0.5, 0 } },
	P = { { 0, 0, 0, 3, 1.5, 3, 2, 2.5, 2, 2, 1.5, 1.5, 0, 1.5 } },
	Q = { { 0.5, 0, 0, 0.6, 0, 2.4, 0.5, 3, 1.5, 3, 2, 2.4, 2, 0.6, 1.5, 0, 0.5, 0 }, { 1.2, 0.8, 2.2, -0.2 } },
	F = { { 2, 3, 0, 3, 0, 0 }, { 0, 1.5, 1.4, 1.5 } },
	B = { { 0, 0, 0, 3, 1.4, 3, 1.9, 2.6, 1.9, 1.9, 1.4, 1.5, 0, 1.5 }, { 1.4, 1.5, 2, 1.1, 2, 0.4, 1.5, 0, 0, 0 } },
	R = { { 0, 0, 0, 3, 1.5, 3, 2, 2.5, 2, 2, 1.5, 1.5, 0, 1.5 }, { 1, 1.5, 2, 0 } },
	S = { { 2, 2.6, 1.5, 3, 0.5, 3, 0, 2.5, 0, 2, 0.5, 1.5, 1.5, 1.5, 2, 1, 2, 0.5, 1.5, 0, 0.5, 0, 0, 0.4 } },
	T = { { 0, 3, 2, 3 }, { 1, 3, 1, 0 } },
	U = { { 0, 3, 0, 0.6, 0.5, 0, 1.5, 0, 2, 0.6, 2, 3 } },
	W = { { 0, 3, 0.5, 0, 1, 1.8, 1.5, 0, 2, 3 } },
	["2"] = { { 0, 2.5, 0.5, 3, 1.5, 3, 2, 2.5, 2, 1.9, 0, 0, 2, 0 } },
	["4"] = { { 1.6, 0, 1.6, 3 }, { 1.6, 3, 0, 1, 2, 1 } },
	["7"] = { { 0, 3, 2, 3, 0.7, 0 } },
	["/"] = { { 0, 0, 2, 3 } },
	["."] = { { 0.9, 0, 1.1, 0 } },
}
local ADVANCE = 2.7 -- glyph width 2 + gap

-- one tube segment from a to b (world), diameter d
local function tube(model: Model, a: Vector3, b: Vector3, d: number, color: Color3)
	local len = (b - a).Magnitude
	if len < 1e-3 then
		return
	end
	local p = Instance.new("Part")
	p.Name = "Tube"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(len, d, d)
	p.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Parent = model
end
local function joint(model: Model, at: Vector3, d: number, color: Color3)
	local p = Instance.new("Part")
	p.Name = "Joint"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(d, d, d)
	p.CFrame = CFrame.new(at)
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Parent = model
end

-- Free strokes (icons) in a sign plane, same tubes as the letters; points are { u, v } pairs in grid units of k,
-- u to the reader's right. With `parent`, the tubes go into that model (several colours in one sign).
local function neonShape(name: string, strokes: { { number } }, cf: CFrame, k: number, color: Color3, d: number?, parent: Model?): Model
	local model = parent or Instance.new("Model")
	model.Name = name
	local dd = d or math.max(0.12, k * 0.3)
	local function at(u: number, v: number): Vector3
		return (cf * CFrame.new(-u * k, v * k, 0)).Position
	end
	for _, st in strokes do
		local prev: Vector3? = nil
		for j = 1, #st, 2 do
			local q = at(st[j], st[j + 1])
			if prev then
				tube(model, prev, q, dd, color)
			end
			joint(model, q, dd, color)
			prev = q
		end
	end
	if not parent then
		model:SetAttribute("Color", color)
		game:GetService("CollectionService"):AddTag(model, "NeonSign")
		model.Parent = folder
	end
	return model
end

-- Neon text centred on `cf`, readable by someone standing on the cf.LookVector side looking back at it.
-- vertical = letters stacked top to bottom.
local function neonText(name: string, text: string, cf: CFrame, height: number, color: Color3, vertical: boolean?): Model
	local model = Instance.new("Model")
	model.Name = name
	local k = height / 3
	local d = math.max(0.12, height * 0.09)
	local n = #text
	local width = (n * ADVANCE - (ADVANCE - 2)) * k
	for i = 1, n do
		local ch = string.upper(string.sub(text, i, i))
		local strokes = GLYPHS[ch]
		if strokes then
			-- glyph origin (bottom-left) in the sign plane: u to the reader's right (-X local: the reader faces -LookVector), v up
			local u0, v0
			if vertical then
				u0, v0 = -1 * k, height * (n / 2) * 1.25 - (i * 1.25 * height)
			else
				u0, v0 = -width / 2 + (i - 1) * ADVANCE * k, -height / 2
			end
			local function at(u: number, v: number): Vector3
				return (cf * CFrame.new(-(u0 + u * k), v0 + v * k, 0)).Position
			end
			for _, s in strokes do
				local prev: Vector3? = nil
				for j = 1, #s, 2 do
					local q = at(s[j], s[j + 1])
					if prev then
						tube(model, prev, q, d, color)
					end
					if j > 1 and j < #s - 1 then
						joint(model, q, d, color)
					end
					prev = q
				end
				joint(model, at(s[1], s[2]), d, color)
				joint(model, at(s[#s - 1], s[#s]), d, color)
			end
		end
	end
	model:SetAttribute("Color", color)
	game:GetService("CollectionService"):AddTag(model, "NeonSign")
	model.Parent = folder
	return model
end

-- 1. sidewalk slabs ------------------------------------------------------------------------------------------------
local function sidewalks(root: Instance): number
	local n = 0
	local walks = root:FindFirstChild("Sidewalks")
	for _, d in (if walks then walks:GetDescendants() else {}) do
		if d:IsA("BasePart") then
			local old = d:FindFirstChild("SlabTexture")
			if old then
				old:Destroy()
			end
			local t = Instance.new("Texture")
			t.Name = "SlabTexture"
			t.Texture = SLAB_TEXTURE
			t.Face = Enum.NormalId.Top
			t.StudsPerTileU = 8
			t.StudsPerTileV = 8
			t.Parent = d
			n += 1
		end
	end
	return n
end

-- 2. name plates ---------------------------------------------------------------------------------------------------
local function namePlates(root: Instance): number
	local n = 0
	local mart = root:FindFirstChild("Mart")
	for _, m in (if mart then mart:GetChildren() else {}) do
		if m:GetAttribute("Asset") == "AST-028_SignName" then
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					local old = d:FindFirstChild("DecorText")
					if old then
						old:Destroy()
					end
					label(d, Enum.NormalId.Front, "NINTH ST. MART", MUSTARD, INK, true)
					n += 1
					break
				end
			end
		end
	end
	return n
end

-- marquee fascia (SS_AST-028_Marquee.Sign_Open24, dark L plate): the two street faces get the shop name
local function marqueeFascia(root: Instance): number
	local mart = root:FindFirstChild("Mart")
	local mq = mart and mart:FindFirstChild("SS_AST-028_Marquee")
	local plate = mq and mq:FindFirstChild("Sign_Open24", true)
	if not plate or not plate:IsA("BasePart") then
		return 0
	end
	for _, g in plate:GetChildren() do
		if g.Name == "DecorText" then
			g:Destroy()
		end
	end
	-- centre of each street face of the L plate, 0.25 stud proud. World axes on purpose: the plate model is
	-- turned in the place, the street faces are world -X (west) and world +Z (north).
	local p0 = plate.Position
	local half = plate.Size.X / 2
	local west = Vector3.new(p0.X - half - 0.25, p0.Y, p0.Z)
	local north = Vector3.new(p0.X, p0.Y, p0.Z + half + 0.25)
	neonText("Neon_MartName", "NINTH ST MART", CFrame.lookAt(west, west + Vector3.new(-1, 0, 0)), 0.95, MUSTARD)
	neonText("Neon_Open247", "OPEN 24/7", CFrame.lookAt(north, north + Vector3.new(0, 0, 1)), 1.1, PINK)
	return 2
end

function Decor.run(force: boolean?): string
	local root = workspace:FindFirstChild(ROOT)
	if not root then
		return "[err] no workspace." .. ROOT
	end
	if root:FindFirstChild(FOLDER) and not force then
		return "[skip] MartDecor exists and was edited by hand: Decor.run(true) to rebuild it anyway"
	end
	local old = root:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = FOLDER
	folder.Parent = root
	local log = {}

	table.insert(log, ("sidewalk tiles textured: %d"):format(sidewalks(root)))
	table.insert(log, ("name plates lettered: %d"):format(namePlates(root)))
	table.insert(log, ("marquee faces lettered: %d"):format(marqueeFascia(root)))

	-- 3. corner blade sign at the street corner (outer corner of the marquee), facing the crossing
	local corner = CFrame.new(47.4, 0, 48.6) * CFrame.Angles(0, math.rad(45), 0)
	local blade = part("BladeSign", Vector3.new(0.6, 7, 2.8), corner * CFrame.new(0, 17.6, 0), INK)
	local bc = blade.CFrame
	local blink = neonText("Neon_BladeA", "MART", bc * CFrame.new(-0.45, 0, 0) * CFrame.Angles(0, math.rad(90), 0), 1.25, MUSTARD, true)
	blink:SetAttribute("Flicker", true)
	neonText("Neon_BladeB", "MART", bc * CFrame.new(0.45, 0, 0) * CFrame.Angles(0, math.rad(-90), 0), 1.25, MUSTARD, true)
	for _, sx in { -1, 1 } do
		part("BladeNeon", Vector3.new(0.7, 7.2, 0.18), corner * CFrame.new(0, 17.6, sx * 1.45), PINK, Enum.Material.Neon)
	end
	part("BladeNeonTop", Vector3.new(0.7, 0.18, 3.1), corner * CFrame.new(0, 21.15, 0), PINK, Enum.Material.Neon)
	part("BladeNeonBottom", Vector3.new(0.7, 0.18, 3.1), corner * CFrame.new(0, 14.05, 0), PINK, Enum.Material.Neon)
	part("BladePost", Vector3.new(0.45, 1.4, 0.45), corner * CFrame.new(0, 13.4, 0), INK)
	light(corner * CFrame.new(0, 17.6, 0), "Point", PINK, 1.2, 14)

	-- neon strips along the awning fronts (north face Z 40.7, west face X 59.3)
	part("AwningNeonNorth", Vector3.new(33, 0.18, 0.18), CFrame.new(84, 6.15, 41.55), MINT, Enum.Material.Neon)
	part("AwningNeonWest", Vector3.new(0.18, 0.18, 25), CFrame.new(58.45, 6.15, 19.8), MINT, Enum.Material.Neon)

	-- 4. inner corner pillars over the wall seams (slim; the Mini Market column scaled to the wall height is too fat)
	local cols = 0
	for _, c in { Vector3.new(99.4, 0.4, 4.5), Vector3.new(99.4, 0.4, 35.3), Vector3.new(64.6, 0.4, 4.5) } do
		part("CornerPillar", Vector3.new(1.6, 11.8, 1.6), CFrame.new(c + Vector3.new(0, 5.9, 0)), Color3.fromRGB(118, 130, 196))
		part("CornerPillarBand", Vector3.new(1.7, 0.5, 1.7), CFrame.new(c + Vector3.new(0, 4.2, 0)), MINT)
		part("CornerPillarFoot", Vector3.new(1.8, 0.6, 1.8), CFrame.new(c + Vector3.new(0, 0.3, 0)), CREAM)
		cols += 1
	end
	table.insert(log, ("columns: %d"):format(cols))

	-- 5. upgrade wall (GEAR_WALL on the east wall, faces -X): header, backdrop, spots
	local face = CFrame.new(100.1, 0, 19.9) * CFrame.Angles(0, math.rad(90), 0) -- -Z of this frame points into the store
	local back = part("UpgradeBackdrop", Vector3.new(20, 10.5, 0.15), face * CFrame.new(0, 5.6, 0.2), Color3.fromRGB(70, 196, 170))
	back.Material = Enum.Material.SmoothPlastic
	local header = part("UpgradeHeader", Vector3.new(12, 1.8, 0.4), face * CFrame.new(0, 10.9, -0.4), INK)
	neonText("Neon_Upgrades", "UPGRADES", header.CFrame * CFrame.new(0, 0, -0.3), 1.1, MUSTARD)
	part("UpgradeHeaderNeon", Vector3.new(12.4, 0.16, 0.2), face * CFrame.new(0, 9.9, -0.55), MUSTARD, Enum.Material.Neon)
	for _, z in { -6, 0, 6 } do
		light(face * CFrame.new(z, 11.6, -3) * CFrame.Angles(math.rad(-35), 0, 0), "Spot", Color3.fromRGB(255, 236, 200), 2.2, 14, 55)
	end

	-- 6. entrance: warm light under the marquee and inside the door, welcome mat
	light(CFrame.new(60.5, 9.5, 39.5), "Point", Color3.fromRGB(255, 226, 180), 1.6, 16)
	light(CFrame.new(67, 10, 32), "Point", Color3.fromRGB(255, 240, 220), 1.2, 14)
	local mat = part("WelcomeMat", Vector3.new(4.2, 0.06, 2.6), CFrame.new(66.4, 0.43, 33.4) * CFrame.Angles(0, math.rad(45), 0), PINK)
	label(mat, Enum.NormalId.Top, "WELCOME!", CREAM, INK)

	-- 7. props
	for i = 0, 2 do
		prop("Cart", CFrame.new(65.8, 0.4, 29.2 - i * 0.9) * CFrame.Angles(0, math.rad(180), 0), 3.4)
	end
	for i = 0, 2 do
		prop("Basket", CFrame.new(72.4, 0.4 + i * 0.55, 31.2) * CFrame.Angles(0, math.rad(i * 8), 0), 0.9)
	end
	prop("BottleReturn", CFrame.new(63.5, 0.4, 28.5) * CFrame.Angles(0, math.rad(-90), 0), 5)

	-- window posters (inside the front windows, facing out to the Ninth)
	local posters = {
		{ CFrame.new(80, 4.4, 37.6), "FRESH\nDAILY!", MINT },
		{ CFrame.new(88, 4.4, 37.6), "OPEN\nLATE", PINK },
		{ CFrame.new(96, 4.4, 37.6), "HOT DOG\nBUNS\n2x1", MUSTARD },
	}
	for _, p in posters do
		local card = part("WindowPoster", Vector3.new(2.6, 3.2, 0.06), p[1] * CFrame.Angles(0, math.rad(180), 0), CREAM)
		label(card, Enum.NormalId.Front, p[2], p[3], INK)
		part("WindowPosterNeon", Vector3.new(2.8, 3.4, 0.04), p[1] * CFrame.new(0, 0, -0.06), p[3], Enum.Material.Neon)
	end

	return "decor_mart: " .. table.concat(log, ", ")
end

--[[ Decor.runPad(): the empty strip behind the cart / trailer pad (user 2026-10-11: the area behind the stand looks
	empty). Pad X -64..-24, Z 3.9 (back wall of B1) .. 35.9, WORLD coordinates. Kept clear on purpose: the thief lane
	N-Z01-04 -> L3 (Z 9..14), the player stations PS-1..4 / PS-N (Z 24..28) and the queue. Rebuilds MAP01_Assets.PadDecor. ]]
function Decor.runPad(force: boolean?): string
	local root = workspace:FindFirstChild(ROOT)
	if not root then
		return "[err] no workspace." .. ROOT
	end
	if root:FindFirstChild("PadDecor") and not force then
		return "[skip] PadDecor exists and was edited by hand: Decor.runPad(true) to rebuild it anyway"
	end
	local old = root:FindFirstChild("PadDecor")
	if old then
		old:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "PadDecor"
	folder.Parent = root
	local WALL_Z = 3.95
	local WOOD = Color3.fromRGB(196, 132, 84)
	local WOOD_D = Color3.fromRGB(150, 92, 58)
	local KETCHUP = Color3.fromRGB(235, 70, 60)
	local log = {}

	-- pad floor: slab texture (the floor colour gives the tint)
	local blockout = workspace:FindFirstChild("MAP01_Blockout")
	local padGroup = blockout and blockout:FindFirstChild("Pad")
	local padFloor = padGroup and padGroup:FindFirstChild("PadFloor")
	if padFloor and padFloor:IsA("BasePart") then
		local t = padFloor:FindFirstChild("SlabTexture") or Instance.new("Texture")
		t.Name = "SlabTexture"
		;(t :: Texture).Texture = SLAB_TEXTURE
		;(t :: Texture).Face = Enum.NormalId.Top
		;(t :: Texture).StudsPerTileU = 6
		;(t :: Texture).StudsPerTileV = 6
		t.Parent = padFloor
	end

	-- 1. back wall neon: CORNER DOGS + hot dog icon, on a dark raceway board
	local wallCF = CFrame.lookAt(Vector3.new(-44, 0, WALL_Z), Vector3.new(-44, 0, WALL_Z + 1)) -- LookVector +Z: faces the pad
	local board = part("SignBoard", Vector3.new(26, 4.6, 0.3), wallCF * CFrame.new(0, 11.2, -0.15), INK)
	board.CastShadow = false
	neonText("Neon_CornerDogs", "CORNER DOGS", wallCF * CFrame.new(3.2, 11.2, -0.45), 2.2, MUSTARD)
	local icon = Instance.new("Model")
	local icf = wallCF * CFrame.new(-8.8, 10.1, -0.45)
	neonShape("Neon_HotDog", {
		{ 0, 0.6, 0.5, 0.1, 1.5, 0, 4.5, 0, 5.5, 0.1, 6, 0.6 },
		{ 0, 1.9, 0.5, 2.4, 1.5, 2.5, 4.5, 2.5, 5.5, 2.4, 6, 1.9 },
	}, icf, 0.55, Color3.fromRGB(255, 176, 80), 0.2, icon)
	neonShape("Neon_HotDog", {
		{ -0.4, 1.25, 0.2, 0.75, 1, 0.65, 5, 0.65, 5.8, 0.75, 6.4, 1.25, 5.8, 1.75, 5, 1.85, 1, 1.85, 0.2, 1.75, -0.4, 1.25 },
	}, icf, 0.55, KETCHUP, 0.2, icon)
	neonShape("Neon_HotDog", {
		{ 0.8, 1.2, 1.4, 1.5, 2, 1, 2.6, 1.5, 3.2, 1, 3.8, 1.5, 4.4, 1, 5, 1.4 },
	}, icf, 0.55, MUSTARD, 0.14, icon)
	icon.Name = "Neon_HotDog"
	icon:SetAttribute("Color", KETCHUP)
	icon:SetAttribute("Flicker", true)
	game:GetService("CollectionService"):AddTag(icon, "NeonSign")
	icon.Parent = folder
	light(wallCF * CFrame.new(0, 10.5, -3), "Point", Color3.fromRGB(255, 200, 120), 1.4, 18)

	-- 2. menu board on the wall (chalkboard) at the east end
	local menu = part("MenuBoard", Vector3.new(5.5, 4, 0.25), wallCF * CFrame.new(16.5, 5.2, -0.3), Color3.fromRGB(52, 70, 60))
	part("MenuFrame", Vector3.new(5.9, 4.4, 0.18), wallCF * CFrame.new(16.5, 5.2, -0.1), WOOD_D)
	label(menu, Enum.NormalId.Front, "MENU\nHOT DOG ... $5\nTOPPINGS +$1\nCOFFEE ... $3", CREAM, Color3.fromRGB(30, 40, 35))

	-- 3. string lights: swags from the wall to two poles at Z 21 (behind the stations)
	local bulbs = 0
	for _, p in { Vector3.new(-30, 0.4, 21), Vector3.new(-58, 0.4, 21) } do
		part("LightPole", Vector3.new(0.35, 9.6, 0.35), CFrame.new(p + Vector3.new(0, 4.8, 0)), INK)
		part("LightPoleFoot", Vector3.new(1.2, 0.3, 1.2), CFrame.new(p + Vector3.new(0, 0.15, 0)), INK)
	end
	local spans = {
		{ Vector3.new(-30, 10, 21), Vector3.new(-30, 10, WALL_Z + 0.2) },
		{ Vector3.new(-30, 10, 21), Vector3.new(-58, 10, 21) },
		{ Vector3.new(-58, 10, 21), Vector3.new(-58, 10, WALL_Z + 0.2) },
		{ Vector3.new(-30, 10, 21), Vector3.new(-44, 10.5, WALL_Z + 0.2) },
		{ Vector3.new(-58, 10, 21), Vector3.new(-44, 10.5, WALL_Z + 0.2) },
	}
	local bulbColors = { MUSTARD, CREAM, PINK, MINT }
	for _, sp in spans do
		local a, b = sp[1], sp[2]
		local n = math.max(4, math.floor((b - a).Magnitude / 2.2))
		local prev = a
		for i = 1, n do
			local t = i / n
			local q = a:Lerp(b, t) - Vector3.new(0, math.sin(t * math.pi) * 1.1, 0)
			local w = part("Wire", Vector3.new((q - prev).Magnitude, 0.06, 0.06), CFrame.lookAt((q + prev) / 2, q) * CFrame.Angles(0, math.rad(90), 0), INK)
			w.CastShadow = false
			if i < n then
				local bulb = part("Bulb", Vector3.new(0.32, 0.32, 0.32), CFrame.new(q - Vector3.new(0, 0.22, 0)), bulbColors[(i % #bulbColors) + 1], Enum.Material.Neon)
				bulb.Shape = Enum.PartType.Ball
				bulb:SetAttribute("Emissive", true)
				bulbs += 1
			end
			prev = q
		end
	end
	light(CFrame.new(-44, 8, 14), "Point", Color3.fromRGB(255, 214, 160), 1, 20)
	table.insert(log, ("bulbs: %d"):format(bulbs))

	-- 4. seating (west, Z 15..21, clear of the thief lane): two picnic tables with small parasols
	for _, c in { Vector3.new(-60, 0.4, 18.2), Vector3.new(-52.5, 0.4, 18.2) } do
		local top = part("TableTop", Vector3.new(4.6, 0.25, 2.2), CFrame.new(c + Vector3.new(0, 2.5, 0)), WOOD)
		top.CanCollide = true
		for _, sz in { -1.55, 1.55 } do
			part("TableSeat", Vector3.new(4.6, 0.22, 0.8), CFrame.new(c + Vector3.new(0, 1.5, sz)), WOOD)
		end
		for _, sx in { -1.9, 1.9 } do
			part("TableLeg", Vector3.new(0.25, 2.5, 3.6), CFrame.new(c + Vector3.new(sx, 1.25, 0)), WOOD_D)
		end
		part("ParasolPole", Vector3.new(0.18, 5.2, 0.18), CFrame.new(c + Vector3.new(0, 2.6, 0)), CREAM)
		local shade = part("ParasolTop", Vector3.new(0.4, 4.4, 4.4), CFrame.new(c + Vector3.new(0, 5.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), KETCHUP)
		shade.Shape = Enum.PartType.Cylinder
		part("ParasolTip", Vector3.new(0.4, 0.4, 0.4), CFrame.new(c + Vector3.new(0, 5.6, 0)), CREAM)
		for _, cup in { Vector3.new(-1.2, 2.75, 0.4), Vector3.new(0.9, 2.75, -0.5) } do
			local k = part("Cup", Vector3.new(0.4, 0.25, 0.25), CFrame.new(c + cup) * CFrame.Angles(0, 0, math.rad(90)), MUSTARD)
			k.Shape = Enum.PartType.Cylinder
		end
	end

	-- 5. supply corner (east, against the wall): crates and a barrel
	local crates = {
		{ Vector3.new(-27.2, 0.4, 5.6), "BUNS", 4 },
		{ Vector3.new(-29.6, 0.4, 5.6), "DOGS", -3 },
		{ Vector3.new(-28.4, 2.4, 5.6), "MUSTARD", 2 },
	}
	for _, c in crates do
		local box = part("Crate", Vector3.new(2.2, 2, 2.2), CFrame.new(c[1] + Vector3.new(0, 1, 0)) * CFrame.Angles(0, math.rad(c[3]), 0), WOOD)
		box.CanCollide = true
		part("CrateBand", Vector3.new(2.3, 0.25, 2.3), box.CFrame * CFrame.new(0, 0.6, 0), WOOD_D)
		label(box, Enum.NormalId.Back, c[2], CREAM, WOOD_D)
	end
	local barrel = part("Barrel", Vector3.new(2.6, 1.8, 1.8), CFrame.new(-25.2, 1.7, 6.6) * CFrame.Angles(0, 0, math.rad(90)), KETCHUP)
	barrel.Shape = Enum.PartType.Cylinder
	barrel.CanCollide = true

	-- 6. planters along the wall
	for _, x in { -36, -52 } do
		local pot = part("Planter", Vector3.new(3.4, 1.2, 1.4), CFrame.new(x, 1, WALL_Z + 0.9), WOOD_D)
		pot.CanCollide = true
		for i = -1, 1 do
			local bush = part("Bush", Vector3.new(1.3, 1.3, 1.3), CFrame.new(x + i * 1.05, 2.05 + (if i == 0 then 0.25 else 0), WALL_Z + 0.9), MINT)
			bush.Shape = Enum.PartType.Ball
		end
	end

	return "decor_pad: " .. table.concat(log, ", ")
end

--[[ Decor.runDetails() (user 2026-10-11): street names on the blank street sign blades, the hot dog logo (DEC-206,
	AST-072_logo_hotdog.png) on the customer side of the cart and of the trailer, OPEN / CLOSED faces on the Pad sign
	stand (OpenSignController switches them), a bulb string along the trailer window. Idempotent: every piece is named
	"Detail_*" and carries BindCreated = true (Place.diff / capture ignore it); a run removes the old ones first. The
	pieces live inside their vehicle models, so they travel with the cart / trailer. ]]
local LOGO = "rbxassetid://94237270233660"

local function detailPart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3?, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = "Detail_" .. name
	p.Size = size
	p.CFrame = cf
	p.Color = color or Color3.new(1, 1, 1)
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = if color then 0 else 1
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p:SetAttribute("BindCreated", true)
	p.Parent = parent
	return p
end

local function clearDetails(root: Instance)
	for _, d in root:GetDescendants() do
		if string.sub(d.Name, 1, 7) == "Detail_" then
			d:Destroy()
		end
	end
end

local function streetText(on: BasePart, text: string)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Detail_Text"
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 200
		gui.LightInfluence = 0.5
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(0.94, 0.8)
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Position = UDim2.fromScale(0.5, 0.5)
		t.BackgroundTransparency = 1
		t.FontFace = FONT
		t.Text = text
		t.TextScaled = true
		t.TextColor3 = Color3.new(1, 1, 1)
		local s = Instance.new("UIStroke")
		s.Color = Color3.fromRGB(20, 80, 60)
		s.Thickness = 2
		s.Parent = t
		t.Parent = gui
		gui.Parent = on
	end
end

-- FROZEN 2026-10-11: the user resized / centred the street sign blades, moved the cart logo and rebuilt the OPEN sign
-- faces on a "Borda" proxy part by hand. runDetails refuses while any Detail_* exists unless force = true.
function Decor.runDetails(force: boolean?): string
	local root = workspace:FindFirstChild(ROOT)
	if not root then
		return "[err] no workspace." .. ROOT
	end
	if not force then
		for _, d in root:GetDescendants() do
			if string.sub(d.Name, 1, 7) == "Detail_" then
				return "[skip] Detail_* pieces exist and were edited by hand: Decor.runDetails(true) to rebuild them anyway"
			end
		end
	end
	clearDetails(root)
	local log = {}

	-- 1. street signs: lower blade runs along the model X (RightVector), upper blade along the model Z
	local n = 0
	for _, m in root:GetDescendants() do
		if m:IsA("Model") and m:GetAttribute("Asset") == "AST-034_StreetSign" then
			local base = m:GetPivot()
			local function name(dir: Vector3): string
				return if math.abs(dir.X) > math.abs(dir.Z) then "NINTH AVE" else "JUNIPER ST"
			end
			local lower = detailPart(m, "BladeLower", Vector3.new(3.3, 0.7, 0.5), base * CFrame.new(0, 7.35, -1.385))
			streetText(lower, name(base.RightVector))
			local upper = detailPart(m, "BladeUpper", Vector3.new(3.2, 0.7, 0.5), base * CFrame.new(1.385, 8.55, 0.1) * CFrame.Angles(0, math.rad(90), 0))
			streetText(upper, name(base.LookVector))
			n += 1
		end
	end
	table.insert(log, ("street signs: %d"):format(n))

	-- 2. cart logo on the customer face of the body (body front = local -Z)
	local cart = root:FindFirstChild("CART_AST-026_CornerCart", true)
	local body = cart and cart:FindFirstChild("Body", true)
	if body and body:IsA("BasePart") then
		local plate = detailPart(cart :: Instance, "Logo", Vector3.new(4.4, 2.75, 0.05), body.CFrame * CFrame.new(0, 0.05, -body.Size.Z / 2 - 0.04))
		local decal = Instance.new("Decal")
		decal.Name = "Detail_LogoDecal"
		decal.Texture = LOGO
		decal.Face = Enum.NormalId.Front
		decal.Parent = plate
		table.insert(log, "cart logo")
	end

	-- 3. trailer: logo under the counter and a bulb string along the window top (trailer frame: window side local -Z)
	local trl = root:FindFirstChild("TRL_AST-027_OpenLateTrailer", true)
	if trl and trl:IsA("Model") then
		local pv = trl:GetPivot()
		local plate = detailPart(trl, "Logo", Vector3.new(5.2, 3.25, 0.05), pv * CFrame.new(-6, 3.6, -6.2))
		local decal = Instance.new("Decal")
		decal.Name = "Detail_LogoDecal"
		decal.Texture = LOGO
		decal.Face = Enum.NormalId.Front
		decal.Parent = plate
		local colors = { MUSTARD, CREAM, PINK, MINT }
		local hooks = {}
		for x = -13, 12, 3.125 do
			table.insert(hooks, pv * CFrame.new(x, 11.15, -6.25))
		end
		local bulbs = 0
		for i = 1, #hooks - 1 do
			local a, b = hooks[i].Position, hooks[i + 1].Position
			local prev = a
			for k = 1, 4 do
				local t = k / 4
				local q = a:Lerp(b, t) - Vector3.new(0, math.sin(t * math.pi) * 0.35, 0)
				detailPart(trl, "Wire", Vector3.new((q - prev).Magnitude, 0.05, 0.05), CFrame.lookAt((q + prev) / 2, q) * CFrame.Angles(0, math.rad(90), 0), INK)
				if k < 4 then
					local bulb = detailPart(trl, "Bulb", Vector3.new(0.28, 0.28, 0.28), CFrame.new(q - Vector3.new(0, 0.18, 0)), colors[(bulbs % #colors) + 1], Enum.Material.Neon)
					bulb.Shape = Enum.PartType.Ball
					bulb:SetAttribute("Emissive", true)
					bulbs += 1
				end
				prev = q
			end
		end
		local glow = detailPart(trl, "BulbLight", Vector3.new(0.2, 0.2, 0.2), pv * CFrame.new(0, 10.6, -7))
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 214, 160)
		l.Brightness = 0.9
		l.Range = 16
		l.Parent = glow
		table.insert(log, ("trailer bulbs: %d"):format(bulbs))
	end

	-- 4. OPEN / CLOSED faces on the Pad sign stand (OpenSignController shows one by the shop phase)
	local stand = root:FindFirstChild("OPEN_AST-024_SignStand", true)
	local board = stand and stand:FindFirstChildWhichIsA("BasePart", true)
	if board then
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local gui = Instance.new("SurfaceGui")
			gui.Name = "Detail_OpenSign"
			gui.Face = face
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 200
			gui.LightInfluence = 0.3
			for _, state in { "Open", "Closed" } do
				local t = Instance.new("TextLabel")
				t.Name = state
				t.Size = UDim2.fromScale(0.86, 0.36)
				t.AnchorPoint = Vector2.new(0.5, 0.5)
				t.Position = UDim2.fromScale(0.5, 0.5)
				t.BackgroundTransparency = 1
				t.FontFace = FONT
				t.Text = if state == "Open" then "OPEN" else "CLOSED"
				t.TextScaled = true
				t.TextColor3 = if state == "Open" then Color3.fromRGB(46, 170, 90) else Color3.fromRGB(220, 60, 60)
				t.Visible = state == "Closed"
				local s = Instance.new("UIStroke")
				s.Color = CREAM
				s.Thickness = 3
				s.Parent = t
				t.Parent = gui
			end
			local sub = Instance.new("TextLabel")
			sub.Name = "Brand"
			sub.Size = UDim2.fromScale(0.86, 0.14)
			sub.AnchorPoint = Vector2.new(0.5, 0)
			sub.Position = UDim2.fromScale(0.5, 0.72)
			sub.BackgroundTransparency = 1
			sub.FontFace = FONT
			sub.Text = "CORNER DOGS"
			sub.TextScaled = true
			sub.TextColor3 = INK
			sub.Parent = gui
			gui.Parent = board
		end
		game:GetService("CollectionService"):AddTag(board, "OpenSignBoard")
		table.insert(log, "open sign")
	end

	-- 5. Mart v2 section signs (AST-106): text on Face_Front / Face_Back (MAP-01 §18.6)
	local SIGN_TEXT = {
		["AST-106_SignBakery"] = { "BAKERY", "BAKERY", Color3.fromRGB(196, 120, 40) },
		["AST-106_SignProduce"] = { "FRESH PRODUCE", "FRESH PRODUCE", Color3.fromRGB(46, 150, 90) },
		["AST-106_SignMeatDeli"] = { "MEAT & DELI", "MEAT & DELI", Color3.fromRGB(200, 50, 50) },
		["AST-106_SignSaucesSnacks"] = { "SAUCES", "SNACKS · COFFEE", Color3.fromRGB(200, 140, 20) },
		["AST-106_WallSignDairy"] = { "DAIRY", nil, Color3.fromRGB(30, 140, 150) },
	}
	local signs = 0
	for _, m in root:GetDescendants() do
		local spec = m:IsA("Model") and SIGN_TEXT[m:GetAttribute("Asset")]
		if spec then
			for i, faceName in { "Face_Front", "Face_Back" } do
				local text = spec[i]
				local face = m:FindFirstChild(faceName, true)
				if text and face and face:IsA("BasePart") then
					-- the SurfaceGui goes on the face part's widest side that looks the way of the model front / back
					local gui = Instance.new("SurfaceGui")
					gui.Name = "Detail_SignText"
					local look = m:GetPivot().LookVector * (if i == 1 then 1 else -1)
					local best, bestDot = Enum.NormalId.Front, -2
					for _, nid in Enum.NormalId:GetEnumItems() do
						local dot = face.CFrame:VectorToWorldSpace(Vector3.fromNormalId(nid)):Dot(look)
						if dot > bestDot then
							best, bestDot = nid, dot
						end
					end
					gui.Face = best
					gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
					gui.PixelsPerStud = 200
					gui.LightInfluence = 0.4
					local t = Instance.new("TextLabel")
					t.Size = UDim2.fromScale(0.9, 0.78)
					t.AnchorPoint = Vector2.new(0.5, 0.5)
					t.Position = UDim2.fromScale(0.5, 0.5)
					t.BackgroundTransparency = 1
					t.FontFace = FONT
					t.Text = text
					t.TextScaled = true
					t.TextColor3 = spec[3]
					local st = Instance.new("UIStroke")
					st.Color = CREAM
					st.Thickness = 2
					st.Parent = t
					t.Parent = gui
					gui.Parent = face
					signs += 1
				end
			end
		end
	end
	table.insert(log, ("section sign faces: %d"):format(signs))

	return "details: " .. table.concat(log, ", ")
end

--[[ Decor.runLobby(force?) (2026-10-11, LOBBY v2): procedural pieces of the lobby (docs/levels/LOBBY.md §V2-10, §V2-12):
	HQ / GEM SHOP / START SHIFT / CODES / PHOTO neon, class stage 20 x 7, 8 squad platforms (tag PartyPlatform, attribute
	Party), codes board, queue aprons, string-light mast + radial "tent" of string lights, floor arrows from the spawn,
	spawn medallion, fountain, photo booth, 14 local lights (6 of them under the AST-036 lamp heads of the placements)
	and the invisible walls. WORLD coordinates. Rebuilds workspace.LOBBY_Assets.LobbyProcedural; refuses when it exists
	unless force (hand edits). MapPoints are the binding's job (bind_map01 bindLobby). ]]
function Decor.runLobby(force: boolean?): string
	local lobby = workspace:FindFirstChild("LOBBY_Assets")
	if not lobby then
		return "[err] no workspace.LOBBY_Assets: run Place.runInto(LOBBY_v2_placements) first"
	end
	if lobby:FindFirstChild("LobbyProcedural") and not force then
		return "[skip] LobbyProcedural exists: Decor.runLobby(true) to rebuild it"
	end
	local old = lobby:FindFirstChild("LobbyProcedural")
	if old then
		old:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "LobbyProcedural"
	folder.Parent = lobby
	local CS = game:GetService("CollectionService")
	local KETCHUP = Color3.fromRGB(235, 70, 60)
	local WOOD = Color3.fromRGB(196, 132, 84)
	local WOOD_D = Color3.fromRGB(150, 92, 58)
	local PAD = Color3.fromHex("E8D9B5")
	local WARM = Color3.fromHex("FFE7C2")
	local TEAL = Color3.fromRGB(63, 167, 181)
	local SODIUM = Color3.fromHex("FFB25A")
	local BUN = Color3.fromRGB(255, 176, 80)
	local function face(pos: Vector3, dir: Vector3): CFrame
		return CFrame.lookAt(pos, pos + dir)
	end
	local function solid(p: Part): Part
		p.CanCollide = true
		p.CanQuery = true
		return p
	end
	-- vertical-axis cylinder (a disc when h is small)
	local function cyl(name: string, dia: number, h: number, pos: Vector3, color: Color3, material: Enum.Material?): Part
		local p = part(name, Vector3.new(h, dia, dia), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, material)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	-- cylinder rod from a to b
	local function rod(name: string, a: Vector3, b: Vector3, dia: number, color: Color3, material: Enum.Material?): Part
		local p = part(name, Vector3.new((b - a).Magnitude, dia, dia), CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0), color, material)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	local function spot(at: Vector3, target: Vector3, color: Color3, brightness: number, range: number, angle: number, shadows: boolean?)
		local p = part("LightAnchor", Vector3.new(0.2, 0.2, 0.2), CFrame.lookAt(at, target), color)
		p.Transparency = 1
		local s = Instance.new("SpotLight")
		s.Face = Enum.NormalId.Front
		s.Angle = angle
		s.Color = color
		s.Brightness = brightness
		s.Range = range
		s.Shadows = shadows == true
		s.Parent = p
	end
	local function point(at: Vector3, color: Color3, brightness: number, range: number)
		light(CFrame.new(at), "Point", color, brightness, range)
	end
	-- neon hot dog icon (the HQ strokes: bun, sausage, mustard); origin = bottom-left of the stroke grid
	local function hotDog(origin: CFrame, k: number, flicker: boolean): Model
		local icon = Instance.new("Model")
		local d = 0.2 * k / 0.55
		neonShape("Neon_HotDog", { { 0, 0.6, 0.5, 0.1, 1.5, 0, 4.5, 0, 5.5, 0.1, 6, 0.6 }, { 0, 1.9, 0.5, 2.4, 1.5, 2.5, 4.5, 2.5, 5.5, 2.4, 6, 1.9 } }, origin, k, BUN, d, icon)
		neonShape("Neon_HotDog", { { -0.4, 1.25, 0.2, 0.75, 1, 0.65, 5, 0.65, 5.8, 0.75, 6.4, 1.25, 5.8, 1.75, 5, 1.85, 1, 1.85, 0.2, 1.75, -0.4, 1.25 } }, origin, k, KETCHUP, d, icon)
		neonShape("Neon_HotDog", { { 0.8, 1.2, 1.4, 1.5, 2, 1, 2.6, 1.5, 3.2, 1, 3.8, 1.5, 4.4, 1, 5, 1.4 } }, origin, k, MUSTARD, 0.14 * k / 0.55, icon)
		icon.Name = "Neon_HotDog"
		icon:SetAttribute("Color", KETCHUP)
		icon:SetAttribute("Flicker", flicker)
		CS:AddTag(icon, "NeonSign")
		icon.Parent = folder
		return icon
	end
	-- the same icon centred on `centre` (grid centre u 3, v 1.25), readable from the `dir` side
	local function hotDogAt(centre: Vector3, dir: Vector3, k: number): Model
		return hotDog(face(centre, dir) * CFrame.new(3 * k, -1.25 * k, 0), k, false)
	end
	-- floor apron (queue area): flat pad, no collision, neon edge in the zone colour
	local function apron(name: string, sx: number, sz: number, cx: number, cz: number, edge: Color3)
		part(name, Vector3.new(sx, 0.04, sz), CFrame.new(cx, 0.02, cz), PAD)
		local hx, hz = sx / 2 - 0.05, sz / 2 - 0.05
		local edges = {
			{ Vector3.new(cx, 0.025, cz - hz), Vector3.new(sx, 0.05, 0.1) },
			{ Vector3.new(cx, 0.025, cz + hz), Vector3.new(sx, 0.05, 0.1) },
			{ Vector3.new(cx - hx, 0.025, cz), Vector3.new(0.1, 0.05, sz) },
			{ Vector3.new(cx + hx, 0.025, cz), Vector3.new(0.1, 0.05, sz) },
		}
		for _, e in edges do
			part(name .. "_Edge", e[2], CFrame.new(e[1]), edge, Enum.Material.Neon)
		end
	end

	-- V2-12.1 HQ sign on BK4 (v1 + 5 in Z; check the wall plane by raycast)
	part("HQ_SignBoard", Vector3.new(26, 4.8, 0.3), face(Vector3.new(0, 11.6, -564.6), Vector3.new(0, 0, -1)), INK)
	for _, t in { { Vector3.new(0, 14.1, -564.78), Vector3.new(26.4, 0.2, 0.2) }, { Vector3.new(0, 9.1, -564.78), Vector3.new(26.4, 0.2, 0.2) }, { Vector3.new(-13.1, 11.6, -564.78), Vector3.new(0.2, 5.2, 0.2) }, { Vector3.new(13.1, 11.6, -564.78), Vector3.new(0.2, 5.2, 0.2) } } do
		part("HQ_SignTrim", t[2], CFrame.new(t[1]), MUSTARD, Enum.Material.Neon)
	end
	neonText("Neon_CornerDogs", "CORNER DOGS", face(Vector3.new(0, 12.5, -564.95), Vector3.new(0, 0, -1)), 2.0, MUSTARD)
	neonText("Neon_HQ", "HQ", face(Vector3.new(0, 10.15, -564.95), Vector3.new(0, 0, -1)), 1.4, CREAM)
	local plate = part("HQ_TopPlate", Vector3.new(9, 1.2, 0.2), face(Vector3.new(0, 14.75, -564.6), Vector3.new(0, 0, -1)), CREAM)
	label(plate, Enum.NormalId.Front, "BRAMBLE'S", KETCHUP, INK)
	for i, x in { -8.42, 11.48 } do
		hotDog(face(Vector3.new(x, 9.46, -564.95), Vector3.new(0, 0, -1)), 0.55, i == 2)
	end

	-- V2-12.2 gem shop (AST-104 at (-37.5, -620), front +X)
	neonText("Neon_GemShop", "GEM SHOP", face(Vector3.new(-34.0, 9.75, -620), Vector3.new(1, 0, 0)), 1.1, MINT)
	for _, z in { -609.5, -630.5 } do
		neonShape("Neon_Gem", { { 0, 2, 1, 3, 3, 3, 4, 2, 2, 0, 0, 2 }, { 0, 2, 4, 2 }, { 1, 3, 1.4, 2, 2, 0 }, { 3, 3, 2.6, 2, 2, 0 } }, face(Vector3.new(-34.0, 9.3, z + 0.6), Vector3.new(1, 0, 0)), 0.3, MINT)
	end
	for i, z in { -610, -613, -616, -624, -627, -630 } do
		local s = if i == 6 then 1.2 else 0.9
		local g = part(if i == 6 then "Gem_S1" else "Gem_P" .. i, Vector3.new(s, s, s), CFrame.new(-36.375, 4.2, z) * CFrame.Angles(math.rad(45), 0, math.rad(35.26)), if i == 6 then MUSTARD else MINT, Enum.Material.Neon)
		g:SetAttribute("Spin", true)
	end

	-- V2-12.3 squad platforms x 8: near row 1..4 at X 16, far row 5..8 at X 34 (pitch 18 = 10 between edges)
	local pads = { { 16, -647 }, { 16, -629 }, { 16, -611 }, { 16, -593 }, { 34, -647 }, { 34, -629 }, { 34, -611 }, { 34, -593 } }
	for n, c in pads do
		local xc, zc = c[1], c[2]
		local pad = solid(cyl("SquadPad_" .. n, 8, 0.3, Vector3.new(xc, 0.15, zc), CREAM))
		CS:AddTag(pad, "PartyPlatform")
		pad:SetAttribute("Party", n)
		cyl("SquadPadRim_" .. n, 8.5, 0.2, Vector3.new(xc, 0.1, zc), KETCHUP, Enum.Material.Neon)
		local numberPlate = part("SquadPadNumber_" .. n, Vector3.new(3.2, 0.02, 3.2), CFrame.new(xc, 0.31, zc) * CFrame.Angles(0, math.rad(-90), 0), CREAM)
		numberPlate.Transparency = 1
		label(numberPlate, Enum.NormalId.Top, tostring(n), KETCHUP, CREAM)
	end

	-- V2-12.4 START SHIFT on the curb
	for _, z in { -630.5, -609.5 } do
		solid(part("Start_Post", Vector3.new(0.4, 11.8, 0.4), CFrame.new(49.4, 5.9, z), INK))
	end
	part("Start_Board", Vector3.new(0.3, 4.4, 21), CFrame.new(49.4, 9.4, -620), INK)
	neonText("Neon_StartShift", "START SHIFT", face(Vector3.new(49.2, 10.2, -620), Vector3.new(-1, 0, 0)), 2.0, KETCHUP)
	neonShape("Neon_StartArrow", { { 0, 1, 3, 1 }, { 2, 2, 3, 1, 2, 0 } }, face(Vector3.new(49.2, 7.6, -617.5), Vector3.new(-1, 0, 0)), 0.6, MUSTARD)

	-- V2-12.5 codes board
	for _, x in { -15.4, -4.6 } do
		solid(part("Codes_Post", Vector3.new(0.6, 6.6, 0.6), CFrame.new(x, 3.3, -655.6), WOOD))
	end
	part("Codes_Frame", Vector3.new(10.6, 5.0, 0.3), CFrame.new(-10, 3.7, -655.75), WOOD_D)
	local board = part("Codes_Board", Vector3.new(10, 4.4, 0.4), face(Vector3.new(-10, 3.7, -655.6), Vector3.new(0, 0, 1)), Color3.fromRGB(205, 160, 110))
	label(board, Enum.NormalId.Front, "SECRET CODES\nCheck our socials!", INK, CREAM)
	part("Codes_Roof", Vector3.new(11.4, 0.4, 1.4), CFrame.new(-10, 6.8, -655.6), KETCHUP)
	part("Codes_SignBack", Vector3.new(7.0, 1.8, 0.2), CFrame.new(-10, 7.8, -655.6), INK)
	neonText("Neon_Codes", "CODES", face(Vector3.new(-10, 7.8, -655.4), Vector3.new(0, 0, 1)), 1.4, CREAM)

	-- V2-12.6 class stage 20 x 7 (X -10..10, Z -579..-572, top Y 1.0)
	solid(part("Stage_Body", Vector3.new(20, 0.9, 7), CFrame.new(0, 0.45, -575.5), KETCHUP))
	solid(part("Stage_Top", Vector3.new(20.2, 0.1, 7.2), CFrame.new(0, 0.95, -575.5), PAD))
	part("Stage_Edge", Vector3.new(20.2, 0.08, 0.08), CFrame.new(0, 0.96, -579.14), MUSTARD, Enum.Material.Neon)
	cyl("Stage_SpotRing", 3.9, 0.03, Vector3.new(0, 0.995, -575.5), CREAM, Enum.Material.Neon)
	cyl("Stage_Spot", 3.6, 0.04, Vector3.new(0, 1.0, -575.5), MUSTARD)
	local ropePrev = Vector3.new(-10.6, 2.0, -579.7)
	for i = 1, 4 do
		local t = i / 4
		local q = Vector3.new(-10.6 + 21.2 * t, 2.0 - math.sin(t * math.pi) * 0.35, -579.7)
		rod("Stage_Rope", ropePrev, q, 0.15, KETCHUP)
		ropePrev = q
	end
	local stageAim = Vector3.new(0, 3.6, -575.5)
	for _, x in { -9.2, 9.2 } do
		-- standing on the stage top (y 1.0), front corners (out of the class camera frame)
		local headY = if x < 0 then 8.0 else 6.6
		part("StageLight_Pole", Vector3.new(0.35, headY - 1.0, 0.35), CFrame.new(x, (headY + 1.0) / 2, -578.6), INK)
		part("StageLight_Foot", Vector3.new(1.2, 0.3, 1.2), CFrame.new(x, 1.15, -578.6), INK)
		local head = part("StageLight_Head", Vector3.new(1.0, 0.8, 1.2), CFrame.lookAt(Vector3.new(x, headY, -578.6), stageAim), INK)
		part("StageLight_Lens", Vector3.new(0.7, 0.5, 0.05), head.CFrame * CFrame.new(0, 0, -0.62), CREAM, Enum.Material.Neon)
	end

	-- V2-10 lights (14 local, 1 with shadow): 8 here + 6 under the lamp heads (below)
	spot(Vector3.new(-9.2, 8.0, -578.6), stageAim, WARM, 4, 16, 45, true) -- L-KEY
	spot(Vector3.new(9.2, 6.6, -578.6), stageAim, CREAM, 1.5, 14, 55) -- L-FILL
	spot(Vector3.new(0, 6.8, -572.0), Vector3.new(0, 4.2, -575.5), TEAL, 1.2, 8, 60) -- L-RIM
	point(Vector3.new(0, 10.5, -567.5), Color3.fromRGB(255, 200, 120), 1.4, 18) -- L-HQ
	point(Vector3.new(-36.5, 8.0, -620), WARM, 1.2, 16) -- L-SHOP
	spot(Vector3.new(-10, 7.0, -653.6), Vector3.new(-10, 3.7, -655.4), CREAM, 1.5, 9, 70) -- L-CODES
	point(Vector3.new(-36, 7.0, -579.0), WARM, 1.2, 16) -- L-TRUCK
	point(Vector3.new(-34, 2.0, -654), TEAL, 1.0, 12) -- L-FOUNTAIN
	-- L-SL-A, B, C, F, G, H: SpotLight under each placed AST-036_LampHead, pointing down (D and E stay Neon only)
	local lamps = 0
	local lit: { [string]: boolean } = { ["LB-SL-A"] = true, ["LB-SL-B"] = true, ["LB-SL-C"] = true, ["LB-SL-F"] = true, ["LB-SL-G"] = true, ["LB-SL-H"] = true }
	for _, d in lobby:GetDescendants() do
		local mapId = d:GetAttribute("MapId")
		if d:GetAttribute("Asset") ~= "AST-036_LampHead" or type(mapId) ~= "string" or not lit[mapId] then
			continue
		end
		local cf: CFrame, size: Vector3
		if d:IsA("Model") then
			cf, size = d:GetBoundingBox()
		elseif d:IsA("BasePart") then
			cf, size = d.CFrame, d.Size
		else
			continue
		end
		local anchor = part("Light_" .. mapId, Vector3.new(0.2, 0.2, 0.2), CFrame.new(cf.Position - Vector3.new(0, size.Y / 2 + 0.1, 0)), SODIUM)
		anchor.Transparency = 1
		local s = Instance.new("SpotLight")
		s.Face = Enum.NormalId.Bottom
		s.Angle = 100
		s.Color = SODIUM
		s.Brightness = 1.2
		s.Range = 18
		s.Shadows = false
		s.Parent = anchor
		lamps += 1
	end

	-- V2-12.9 string-light mast (marker at the centre of the plaza, behind the spawn)
	local MAST = Vector3.new(5, 0, -628.5)
	solid(cyl("Mast_Planter", 4, 1.2, MAST + Vector3.new(0, 0.6, 0), WOOD_D))
	cyl("Mast_Soil", 3.6, 0.1, MAST + Vector3.new(0, 1.2, 0), Color3.fromRGB(95, 70, 50))
	solid(cyl("Mast_Pole", 0.8, 17.3, MAST + Vector3.new(0, 9.85, 0), INK))
	cyl("Mast_Ring", 2.4, 0.25, MAST + Vector3.new(0, 16.0, 0), MUSTARD, Enum.Material.Neon)
	-- double-faced topper, back to back (readable from +Z and -Z), bottom at y 18.8, centred on the pole axis
	local topY = 18.8 + 1.25 * 0.55
	hotDogAt(Vector3.new(5, topY, -628.4), Vector3.new(0, 0, 1), 0.55).Name = "Mast_Topper"
	hotDogAt(Vector3.new(5, topY, -628.6), Vector3.new(0, 0, -1), 0.55).Name = "Mast_Topper"

	-- V2-12.7 string lights: radial "tent" from the mast ring (y 16) to the axis of each lamp post (y 11.5)
	local colors = { MUSTARD, CREAM, KETCHUP, MINT }
	local feet = {
		Vector3.new(-52, 11.5, -671), -- V-A
		Vector3.new(44, 11.5, -671), -- V-B
		Vector3.new(-52, 11.5, -600), -- V-C
		Vector3.new(-19, 11.5, -569), -- V-D
		Vector3.new(19, 11.5, -569), -- V-E
		Vector3.new(44, 11.5, -602), -- V-F
		Vector3.new(44, 11.5, -638), -- V-G
		Vector3.new(-52, 11.5, -640), -- V-H
	}
	local ring = MAST + Vector3.new(0, 16.0, 0)
	local bulbs = 0
	for _, b in feet do
		local a = ring + Vector3.new(b.X - ring.X, 0, b.Z - ring.Z).Unit * 1.2 -- tied to the ring's edge
		local n = math.max(4, math.floor((b - a).Magnitude / 2.6))
		local prev = a
		for i = 1, n do
			local t = i / n
			local q = a:Lerp(b, t) - Vector3.new(0, math.sin(t * math.pi) * 2.5, 0)
			local w = part("Wire", Vector3.new((q - prev).Magnitude, 0.06, 0.06), CFrame.lookAt((q + prev) / 2, q) * CFrame.Angles(0, math.rad(90), 0), INK)
			w.CastShadow = false
			if i < n then
				local bulb = part("Bulb", Vector3.new(0.32, 0.32, 0.32), CFrame.new(q - Vector3.new(0, 0.22, 0)), colors[(i % #colors) + 1], Enum.Material.Neon)
				bulb.Shape = Enum.PartType.Ball
				bulbs += 1
			end
			prev = q
		end
	end

	-- V2-12.8 queue aprons
	apron("Apron_Classes", 18, 13, 0, -586.5, MUSTARD)
	apron("Apron_Shop", 10, 24, -29, -620, MINT)
	apron("Apron_Codes", 12, 9, -10, -650.5, CREAM)

	-- V2-12.10 floor chevrons from the spawn (5, -620)
	local routes = {
		{ MUSTARD, { Vector2.new(3.50, -610.11), Vector2.new(2.75, -605.17), Vector2.new(2.00, -600.22), Vector2.new(1.25, -595.28) }, Vector2.new(-0.150, 0.989), "CLASSES", Vector2.new(4.01, -613.47) },
		{ KETCHUP, { Vector2.new(16, -620), Vector2.new(21, -620), Vector2.new(25, -620), Vector2.new(30, -620), Vector2.new(35, -620), Vector2.new(40, -620) }, Vector2.new(1, 0), "SQUAD UP", Vector2.new(11.6, -620) },
		{ MINT, { Vector2.new(-5, -620), Vector2.new(-10, -620), Vector2.new(-15, -620), Vector2.new(-20, -620) }, Vector2.new(-1, 0), "GEM SHOP", Vector2.new(-1.6, -620) },
		{ CREAM, { Vector2.new(0.15, -629.87), Vector2.new(-2.06, -634.35), Vector2.new(-4.26, -638.84), Vector2.new(-6.47, -643.32) }, Vector2.new(-0.441, -0.897), "CODES", Vector2.new(2.09, -625.92) },
	}
	for _, r in routes do
		local dir = Vector3.new(r[3].X, 0, r[3].Y).Unit
		for _, tip in r[2] do
			local tipPos = Vector3.new(tip.X, 0.025, tip.Y)
			for _, side in { -1, 1 } do
				local arm = (CFrame.lookAt(Vector3.zero, -dir) * CFrame.Angles(0, math.rad(40 * side), 0)).LookVector
				local c = tipPos + arm * 0.7
				part("Chevron", Vector3.new(0.28, 0.05, 1.4), CFrame.lookAt(c, c + arm), r[1], Enum.Material.Neon)
			end
		end
		local lab = part("RouteLabel", Vector3.new(4.5, 0.04, 1.1), CFrame.lookAt(Vector3.new(r[5].X, 0.03, r[5].Y), Vector3.new(r[5].X, 0.03, r[5].Y) + dir) * CFrame.Angles(0, math.rad(90), 0), r[1])
		lab.Transparency = 1
		label(lab, Enum.NormalId.Top, r[4], r[1], INK)
	end

	-- V2-12.11 spawn medallion (D 8; LobbyService spreads +-3 inside it)
	cyl("SpawnRing", 8.4, 0.02, Vector3.new(5, 0.01, -620), MUSTARD, Enum.Material.Neon)
	cyl("SpawnMedallion", 8, 0.04, Vector3.new(5, 0.02, -620), CREAM)
	local medLabel = part("SpawnLabel", Vector3.new(5, 0.02, 2), CFrame.new(5, 0.045, -620) * CFrame.Angles(0, math.rad(180), 0), CREAM)
	medLabel.Transparency = 1
	label(medLabel, Enum.NormalId.Top, "SELL HOTDOGS!", KETCHUP, INK)

	-- V2-12.12 fountain at (-34, -654): basin D 12, floor y 0.3, water y 0.85
	local FOUNT = Vector3.new(-34, 0, -654)
	solid(cyl("Fountain_Floor", 12, 0.3, FOUNT + Vector3.new(0, 0.15, 0), Color3.fromRGB(200, 190, 170)))
	for i = 0, 11 do
		local ang = math.rad(i * 30)
		local wallPos = FOUNT + Vector3.new(math.cos(ang), 0, math.sin(ang)) * 5.6
		-- local X tangent to the circle, local Z radial
		solid(part("Fountain_Wall", Vector3.new(3.1, 1.2, 0.8), CFrame.lookAt(wallPos + Vector3.new(0, 0.6, 0), FOUNT + Vector3.new(0, 0.6, 0)), PAD))
		solid(part("Fountain_Cap", Vector3.new(3.3, 0.2, 1.0), CFrame.lookAt(wallPos + Vector3.new(0, 1.3, 0), FOUNT + Vector3.new(0, 1.3, 0)), CREAM))
	end
	local water = cyl("Fountain_Water", 10.6, 0.1, FOUNT + Vector3.new(0, 0.85, 0), TEAL)
	water.Transparency = 0.35
	water.Reflectance = 0.1
	water:SetAttribute("Ripple", false) -- reserved for an optional client animation (P-L20)
	solid(cyl("Fountain_Column", 1.6, 3.4, FOUNT + Vector3.new(0, 2.0, 0), PAD))
	solid(cyl("Fountain_Bowl", 5, 0.5, FOUNT + Vector3.new(0, 3.95, 0), PAD))
	local bowlWater = cyl("Fountain_BowlWater", 4.4, 0.06, FOUNT + Vector3.new(0, 4.21, 0), TEAL)
	bowlWater.Transparency = 0.35
	for _, d in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		local a = FOUNT + d * 2.2 + Vector3.new(0, 4.3, 0)
		local b = FOUNT + d * 4.4 + Vector3.new(0, 1.0, 0)
		local jet = part("Fountain_Jet", Vector3.new(0.25, 0.25, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), Color3.fromRGB(150, 230, 235), Enum.Material.Neon)
		jet.Transparency = 0.4
	end
	hotDogAt(FOUNT + Vector3.new(0.1, 4.9, 0), Vector3.new(1, 0, 0), 0.4).Name = "Fountain_Icon"
	hotDogAt(FOUNT + Vector3.new(-0.1, 4.9, 0), Vector3.new(-1, 0, 0), 0.4).Name = "Fountain_Icon"

	-- V2-12.13 photo booth at (31, -571), front -Z (decoration only, P-L19)
	solid(part("PB_Floor", Vector3.new(6, 0.3, 4.4), CFrame.new(31, 0.15, -571), INK))
	solid(part("PB_Back", Vector3.new(6, 7.2, 0.4), CFrame.new(31, 3.9, -569.0), KETCHUP))
	for _, x in { 28.2, 33.8 } do
		solid(part("PB_Side", Vector3.new(0.4, 7.2, 4.4), CFrame.new(x, 3.9, -571), KETCHUP))
	end
	part("PB_Roof", Vector3.new(6.6, 0.4, 5.0), CFrame.new(31, 7.7, -571), CREAM)
	part("PB_Lintel", Vector3.new(6, 1.2, 0.4), CFrame.new(31, 6.9, -573.0), KETCHUP)
	part("PB_Curtain", Vector3.new(2.6, 5.2, 0.1), CFrame.new(29.7, 3.6, -573.1), MINT, Enum.Material.Fabric)
	solid(part("PB_Seat", Vector3.new(4.6, 1.4, 1.2), CFrame.new(31, 1.0, -569.8), WOOD))
	local screen = part("PB_Screen", Vector3.new(2.4, 1.6, 0.1), face(Vector3.new(31, 4.6, -569.15), Vector3.new(0, 0, -1)), INK)
	label(screen, Enum.NormalId.Front, "SMILE!", CREAM, INK, true)
	local flash = part("PB_Flash", Vector3.new(0.6, 0.6, 0.1), CFrame.new(31, 5.8, -569.15), CREAM, Enum.Material.Neon)
	flash:SetAttribute("Flicker", true)
	part("PB_SignBack", Vector3.new(7, 1.8, 0.3), CFrame.new(31, 9.0, -572.9), INK)
	neonText("Neon_Photo", "PHOTO", face(Vector3.new(31, 9.0, -573.1), Vector3.new(0, 0, -1)), 1.2, CREAM)
	local sticker = part("PB_FloorSticker", Vector3.new(3, 0.04, 3), CFrame.new(31, 0.03, -576) * CFrame.Angles(0, math.rad(180), 0), CREAM)
	label(sticker, Enum.NormalId.Top, "SAY CHEESE!", KETCHUP, INK)

	-- V2-12.14 invisible walls (height 30)
	local walls = {
		{ "LW-N", Vector3.new(-2.8, 15, -564.5), Vector3.new(108.4, 30, 1) },
		{ "LW-S", Vector3.new(-2.8, 15, -675.5), Vector3.new(108.4, 30, 1) },
		{ "LW-W", Vector3.new(-56.5, 15, -620), Vector3.new(1, 30, 112) },
		{ "LW-E", Vector3.new(50.9, 15, -620), Vector3.new(1, 30, 112) },
		{ "LW-STAGE", Vector3.new(0, 15, -572.5), Vector3.new(32, 30, 15) },
		{ "LW-SHOP", Vector3.new(-37.65, 15, -620), Vector3.new(6.7, 30, 26) },
		{ "LW-TRUCK", Vector3.new(-36, 15, -571.5), Vector3.new(40, 30, 13) },
	}
	for _, w in walls do
		local p = part("LobbyWall_" .. w[1], w[3], CFrame.new(w[2]), INK)
		p.Transparency = 1
		p.CanCollide = true
		p.CastShadow = false
	end
	return ("lobby v2 decor: bulbs %d, lamp lights %d/6"):format(bulbs, lamps)
end

return Decor
