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
	gui.PixelsPerStud = 60
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

return Decor
