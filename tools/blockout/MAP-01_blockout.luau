--[[
	MAP-01 "Ninth & Juniper" - greybox blockout (technical prototype, Phase 0).

	Source of truth: docs/levels/MAP-01.md (rev. 3, final adjustment: DEC-130, no traffic lights;
	Juniper South open; Juniper posts every 8 studs, JL-09 at ~135 from the window; BAR-N at Z -76).
	Colours: docs/art/style-guide.md section 2 (basic palette only).

	HOW TO RUN: paste the whole file into the Roblox Studio Command Bar (or run it through the
	Studio MCP). Idempotent: deletes and rebuilds workspace.MAP01_Blockout and touches nothing else.

	Axes (MAP-01 section 2): origin = centre of the Juniper carriageway on the Ninth axis, ground Y = 0.
	+X = east, +Z = south (north = -Z). Document coordinates (X, Z) map 1:1 to world studs.
	Scale: R6 (character 5, eye 4.5), counter 3.5.

	This is NOT gameplay code: no scripts, no prompts, no behaviour. Every part is Anchored.
	Assets get swapped later; part names match the MAP-01 IDs so the swap can follow the doc.

	Night preview (optional): after running, type in the Command Bar
		_G.MAP01_NightPreview(true)   -- ClockTime 21, Juniper/P-01 SpotLights on
		_G.MAP01_NightPreview(false)  -- restores the previous ClockTime, lights off
]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local ROOT_NAME = "MAP01_Blockout"

do
	local old = Workspace:FindFirstChild(ROOT_NAME)
	if old then
		old:Destroy()
	end
end

---------------------------------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------------------------------

local Y_ROAD = 0 -- carriageway top
local Y_WALK = 0.4 -- sidewalk / plaza / Mart floor top (0.4 curb)
local Y_PAD = 0.45 -- Pad top (painted slab, a hair above the sidewalk)
local MARK_Y = 1.2 -- centre height of ground markers
local POLE_H = 14 -- street light height (L01-22)
local COUNTER_H = 3.5 -- station / counter height (style guide section 4)
local TRAILER_FLOOR = 2 -- trailer floor above ground (AST-027)

local NORTH = Vector3.new(0, 0, -1)
local SOUTH = Vector3.new(0, 0, 1)
local EAST = Vector3.new(1, 0, 0)
local WEST = Vector3.new(-1, 0, 0)

local NEON = Enum.Material.Neon
local PLASTIC = Enum.Material.SmoothPlastic
local CONCRETE = Enum.Material.Concrete
local ASPHALT = Enum.Material.Asphalt
local CYLINDER = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball

local function hex(s: string): Color3
	return Color3.fromHex(s)
end

local PAL = {
	-- street (style guide 2.2)
	asphalt = hex("4A4E58"),
	parking = hex("5A5F69"),
	sidewalk = hex("CFC8B8"),
	redCurb = hex("B8664F"),
	paint = hex("F1EEE6"),
	mustard = hex("F6C12B"),
	pad = hex("E8D9B5"),
	plaza = hex("E4DCCB"),
	ground = hex("7E8279"),
	-- buildings
	martWall = hex("A8C69F"),
	offWhite = hex("F1EEE6"),
	martAwning = hex("5FA36A"),
	glass = hex("9FD3E8"),
	brick = hex("B8664F"),
	cream = hex("FFF1D6"),
	peach = hex("F2B8A0"),
	butter = hex("F3DFA2"),
	lilac = hex("BFB2D9"),
	mintGray = hex("B7CFC6"),
	b1 = hex("D9A38B"),
	b3 = hex("C7A9B5"),
	b4 = hex("E6D3B3"),
	b5 = hex("C9D6B8"),
	filler = hex("BDB5A6"),
	-- props / food
	teal = hex("3FA7B5"),
	tealLight = hex("8FC9D1"),
	ketchup = hex("E2402E"),
	ketchupFaded = hex("C7685C"),
	aluminum = hex("E3E7EB"),
	steel = hex("C9D1D8"),
	dark = hex("2B2233"),
	wood = hex("C49A6C"),
	bun = hex("F4D9A0"),
	cheese = hex("FFD45A"),
	bacon = hex("C9533E"),
	potato = hex("F7D27A"),
	creamCheese = hex("FFF8EC"),
	coffee = hex("5A3A2A"),
	gold = hex("FFD86B"),
	money = hex("5FA36A"),
	skin = hex("E8B98F"),
	pole = hex("6B6F7A"),
	lampOff = hex("FFF1D6"),
	cone = hex("FF8A3D"),
	white = Color3.new(1, 1, 1),
	-- lights (style guide 2.3)
	sodium = hex("FFB25A"),
	coral = hex("FF8A65"),
	martLight = hex("D8FFE6"),
	warm = hex("FFE7C2"),
	-- marker categories (blockout only)
	mSpawn = hex("4CD964"),
	mSpawnNight = hex("1E9E50"),
	mQueue = hex("FFD45A"),
	mCustomer = hex("4FD1E8"),
	mThief = hex("6A5ACD"),
	mAmbulance = hex("3FA7B5"),
	mRevive = hex("FFFFFF"),
	mCutscene = hex("FF7AD9"),
	mAnomaly = hex("FF4D4D"),
	mHiddenSpawn = hex("9E1F1F"),
	mWalker = hex("7B5CFF"),
	mTraffic = hex("5A8DFF"),
	mPlayerRoute = hex("FFFFFF"),
	mLimit = hex("FF3B3B"),
}

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------

local root = Instance.new("Folder")
root.Name = ROOT_NAME

local function newFolder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function newModel(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Generic part factory. o: color, material, transparency, collide, query, touch, shadow, shape
local function mk(className: string, name: string, parent: Instance, size: Vector3, cf: CFrame, o: any?): BasePart
	local opt = o or {}
	local p = Instance.new(className) :: any
	p.Name = name
	if opt.shape then
		p.Shape = opt.shape
	end
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Material = opt.material or PLASTIC
	p.Color = opt.color or PAL.filler
	p.Transparency = opt.transparency or 0
	p.CanCollide = opt.collide ~= false
	p.CanQuery = opt.query ~= false
	p.CanTouch = opt.touch ~= false
	p.CastShadow = opt.shadow ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Axis-aligned box from world bounds.
local function box(name, parent, x0, x1, y0, y1, z0, z1, o)
	return mk(
		"Part",
		name,
		parent,
		Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)),
		CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		o
	)
end

-- Vertical cylinder (Roblox cylinders run along local X, so roll 90 degrees).
local VERTICAL = CFrame.Angles(0, 0, math.pi / 2)
local function cyl(name, parent, x, z, y0, y1, diameter, o)
	local opt = table.clone(o or {})
	opt.shape = CYLINDER
	return mk("Part", name, parent, Vector3.new(y1 - y0, diameter, diameter), CFrame.new(x, (y0 + y1) / 2, z) * VERTICAL, opt)
end

-- Horizontal bar from a to b (same Y), width w (local X), height h.
local function seg(name, parent, a: Vector3, b: Vector3, w, h, o)
	return mk("Part", name, parent, Vector3.new(w, h, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), o)
end

local function ghost(color: Color3, transparency: number?)
	return {
		color = color,
		material = NEON,
		transparency = transparency or 0.35,
		collide = false,
		query = false,
		touch = false,
		shadow = false,
	}
end

local function zone(color: Color3, transparency: number?)
	return {
		color = color,
		material = PLASTIC,
		transparency = transparency or 0.85,
		collide = false,
		query = false,
		touch = false,
		shadow = false,
	}
end

local function paintOpts(color: Color3, transparency: number?)
	return { color = color, transparency = transparency or 0, collide = false, query = false, shadow = false }
end

local function tag(p: Instance, text: string)
	local bb = Instance.new("BillboardGui")
	bb.Name = "IdTag"
	bb.Size = UDim2.fromOffset(90, 22)
	bb.StudsOffset = Vector3.new(0, 1.4, 0)
	bb.MaxDistance = 140
	bb.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = PAL.dark
	t.BackgroundTransparency = 0.35
	t.TextColor3 = PAL.white
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.Text = text
	t.Parent = bb
	bb.Parent = p
end

local function surfaceText(p: Instance, face: Enum.NormalId, text: string, fg: Color3)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 200
	g.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.TextColor3 = fg
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.Text = text
	t.Parent = g
	g.Parent = p
end

-- Local light counter (style guide 5.1 budget: <= 18 at night, <= 3 with shadows).
local function addLight(className: string, parent: Instance, props: { [string]: any })
	local l = Instance.new(className) :: any
	for k, v in props do
		l[k] = v
	end
	l.Parent = parent
	return l
end

-- Marker: small neon semi-transparent cube named after the MAP-01 ID.
-- o: y, size, color, face (Vector3 dir), lookAt (Vector3 target), text, label=false
local function marker(id: string, parent: Instance, x: number, z: number, o: any?)
	local opt = o or {}
	local pos = Vector3.new(x, opt.y or MARK_Y, z)
	local cf = CFrame.new(pos)
	if opt.lookAt then
		cf = CFrame.lookAt(pos, opt.lookAt)
	elseif opt.face then
		cf = CFrame.lookAt(pos, pos + Vector3.new(opt.face.X, 0, opt.face.Z))
	end
	local s = opt.size or 1
	local color = opt.color or PAL.white
	local p = mk("Part", id, parent, Vector3.new(s, s, s), cf, ghost(color))
	if opt.face or opt.lookAt then
		mk("Part", "Facing", p, Vector3.new(0.25, 0.25, 1.4), cf * CFrame.new(0, 0, -(s / 2 + 0.7)), ghost(color, 0.15))
	end
	if opt.label ~= false then
		tag(p, opt.text or id)
	end
	return p
end

-- Route: chain of thin neon bars between (x, z) waypoints.
local ROUTE_Y = 0.7
local function route(id: string, parent: Instance, pts: { { number } }, color: Color3)
	local f = newFolder(id, parent)
	for i = 1, #pts - 1 do
		local a = Vector3.new(pts[i][1], ROUTE_Y, pts[i][2])
		local b = Vector3.new(pts[i + 1][1], ROUTE_Y, pts[i + 1][2])
		local s = seg(("Seg%02d"):format(i), f, a, b, 0.5, 0.12, ghost(color, 0.45))
		if i == 1 then
			tag(s, id)
		end
	end
	return f
end

local function dirTo(x0, z0, x1, z1): Vector3
	return Vector3.new(x1 - x0, 0, z1 - z0)
end

---------------------------------------------------------------------------------------------------
-- Folders
---------------------------------------------------------------------------------------------------

local F = {}
for _, name in { "Ground", "Roads", "Sidewalks", "Crosswalks", "Buildings", "Mart", "Pad", "Trailer", "Parking", "StreetLights", "Signs", "Limits", "Markers" } do
	F[name] = newFolder(name, root)
end

---------------------------------------------------------------------------------------------------
-- Ground, roads, road paint (MAP-01 sections 3, 5.4; L01-20)
---------------------------------------------------------------------------------------------------

box("Ground", F.Ground, -140, 140, -2, -0.05, -156, 124, { color = PAL.ground, material = CONCRETE })

do
	local road = { color = PAL.asphalt, material = ASPHALT }
	box("NinthAvenue", F.Roads, -136, 136, -1, Y_ROAD, -16, 16, road) -- Z-03, 32 wide
	box("Juniper_North", F.Roads, -12, 12, -1, Y_ROAD, -136, -16, road) -- Z-07 + Z-13, 24 wide
	box("Juniper_South", F.Roads, -12, 12, -1, Y_ROAD, 16, 120, road) -- Z-08, curves out of view at ~112
	box("BackStreet", F.Roads, -136, 136, -1, Y_ROAD, -152, -136, road) -- visual only

	local mkf = newFolder("Markings", F.Roads)
	local yellow = paintOpts(PAL.mustard)
	local white = paintOpts(PAL.paint)
	local y0, y1 = Y_ROAD, Y_ROAD + 0.03
	-- Ninth double centre line (WB lane Z -10..0, EB lane Z 0..10), broken at the intersection box
	for _, span in { { -136, -24 }, { 24, 136 } } do
		local tagName = span[1] < 0 and "W" or "E"
		box("Ninth_Centre_" .. tagName .. "_N", mkf, span[1], span[2], y0, y1, -0.4, -0.15, yellow)
		box("Ninth_Centre_" .. tagName .. "_S", mkf, span[1], span[2], y0, y1, 0.15, 0.4, yellow)
		box("Ninth_ParkingLaneEdge_" .. tagName, mkf, span[1], span[2], y0, y1, -10.15, -9.85, white) -- PARK-N lane Z -16..-10
		box("Ninth_CurbLaneEdge_" .. tagName, mkf, span[1], span[2], y0, y1, 9.85, 10.15, white) -- south curb lane Z 10..16
	end
	-- Juniper double centre line (SB X -6, NB X 6)
	for _, span in { { -136, -24, "N" }, { 24, 120, "S" } } do
		box("Juniper_Centre_" .. span[3] .. "_W", mkf, -0.4, -0.15, y0, y1, span[1], span[2], yellow)
		box("Juniper_Centre_" .. span[3] .. "_E", mkf, 0.15, 0.4, y0, y1, span[1], span[2], yellow)
	end

	-- Stop lines (PARE) and crosswalk lines (cars stop only with an NPC reservation, Q-129 provisional)
	local stopLines = {
		-- id, x0, x1, z0, z1, isStop
		{ "SL-N", -12, 0, -20.6, -19.4, true }, -- Juniper SB, PARE
		{ "SL-S", 0, 12, 19.4, 20.6, true }, -- Juniper NB, PARE
		{ "SL-W", -28.4, -27.6, 0, 16, false }, -- Ninth EB, before CW-2
		{ "SL-E", 27.6, 28.4, -16, 0, false }, -- Ninth WB, before CW-4
		{ "SL-1N", -12, 0, 29.6, 30.4, false }, -- CW-1, SB
		{ "SL-1S", 0, 12, 45.6, 46.4, false }, -- CW-1, NB
		{ "SL-3W", 49.6, 50.4, 0, 16, false }, -- CW-3, EB
		{ "SL-3E", 63.6, 64.4, -16, 0, false }, -- CW-3, WB
	}
	for _, s in stopLines do
		local p = box(s[1], mkf, s[2], s[3], y0, Y_ROAD + 0.04, s[4], s[5], paintOpts(PAL.paint, s[6] and 0 or 0.35))
		tag(p, s[1])
	end
end

---------------------------------------------------------------------------------------------------
-- Sidewalks, plaza, red curb (Ninth sidewalks 16 wide, Juniper sidewalks 12 wide)
---------------------------------------------------------------------------------------------------

do
	local walk = { color = PAL.sidewalk, material = CONCRETE }
	local S = F.Sidewalks
	box("Z-06_NinthNorth_W", S, -136, -12, -1, Y_WALK, -32, -16, walk)
	box("Z-06_NinthNorth_E", S, 12, 136, -1, Y_WALK, -32, -16, walk)
	box("Z-02_NinthSouth_W", S, -136, -12, -1, Y_WALK, 16, 32, walk)
	box("Z-02_NinthSouth_E", S, 12, 136, -1, Y_WALK, 16, 32, walk)
	box("JuniperNorth_W", S, -24, -12, -1, Y_WALK, -136, -32, walk) -- JL-01..09 side
	box("JuniperNorth_E", S, 12, 24, -1, Y_WALK, -136, -32, walk) -- SP-A customer side
	box("JuniperSouth_W", S, -24, -12, -1, Y_WALK, 32, 120, walk)
	box("JuniperSouth_E", S, 12, 24, -1, Y_WALK, 32, 120, walk) -- thief side (ST-R)
	box("Z-12_MartPlaza", S, -64, -24, -1, Y_WALK, 32, 56, { color = PAL.plaza, material = CONCRETE })
	-- PARK-N no-parking red curb X -32..76 (keeps the view to the sale trailer, the clock and the Juniper)
	box("RedCurb_NoParking", S, -32, 76, Y_WALK, Y_WALK + 0.05, -16.6, -16, paintOpts(PAL.redCurb))
	-- Plaza low tables (<= 3 tall, outside the Mart -> cart sight band Z 30..47)
	for i, x in { -44, -34 } do
		cyl(("PlazaTable_%d"):format(i), S, x, 50, Y_WALK, Y_WALK + 2.5, 3, { color = PAL.offWhite })
	end
end

---------------------------------------------------------------------------------------------------
-- Crosswalks CW-1..CW-4 (painted, no traffic lights, DEC-130)
---------------------------------------------------------------------------------------------------

do
	local stripe = paintOpts(PAL.paint)
	-- Across the Ninth: stripes run east-west, stacked north-south
	local function acrossNinth(id, x0, x1)
		local m = newModel(id, F.Crosswalks)
		local i = 0
		for z = -14.5, 14.5, 3 do
			i += 1
			box(("Stripe%02d"):format(i), m, x0, x1, Y_ROAD, Y_ROAD + 0.05, z - 0.75, z + 0.75, stripe)
		end
		tag(m:FindFirstChild("Stripe01") :: Instance, id)
	end
	acrossNinth("CW-2", -24, -12) -- west of the intersection (SP-B, cutscene)
	acrossNinth("CW-4", 12, 24) -- east of the intersection (SP-A)
	acrossNinth("CW-3", 54, 60) -- mid-block, Pad <-> parking lot

	-- CW-1 across the Juniper South (trailer <-> Mart): stripes run north-south, stacked east-west
	local m = newModel("CW-1", F.Crosswalks)
	local i = 0
	for x = -10.5, 10.5, 3 do
		i += 1
		box(("Stripe%02d"):format(i), m, x - 0.75, x + 0.75, Y_ROAD, Y_ROAD + 0.05, 34, 42, stripe)
	end
	tag(m:FindFirstChild("Stripe01") :: Instance, "CW-1")
end

---------------------------------------------------------------------------------------------------
-- Buildings (facades, not enterable). Heights are blockout guesses.
---------------------------------------------------------------------------------------------------

do
	local B = F.Buildings
	local plain = {
		-- id, x0, x1, z0, z1, height, color
		{ "B3", -136, -72, -64, -32, 20, PAL.b3 }, -- north-west, "NO HELP WANTED" window at X -92
		{ "B4", 104, 136, -136, -32, 22, PAL.b4 }, -- north-east, east of the parking lot
		{ "B5", -64, -24, 56, 120, 18, PAL.b5 }, -- south-west, behind the plaza
		{ "Fill_NW", -136, -36, -136, -64, 26, PAL.filler }, -- leaves alley X -36..-24 (AS-3)
		{ "Fill_N_BankRear", 24, 52, -88, -64, 26, PAL.filler },
		{ "Fill_N_ParkingRear", 32, 104, -136, -88, 24, PAL.filler }, -- leaves alley X 24..32 (SP-A)
		{ "Fill_SW_West", -136, -100, 32, 120, 24, PAL.filler },
		{ "Fill_SW_MartRear", -100, -64, 64.5, 120, 20, PAL.filler },
		{ "Fill_SE_B1Rear", 24, 136, 88, 120, 26, PAL.filler },
		{ "Fill_E", 120, 136, 32, 88, 26, PAL.filler }, -- leaves alley X 112..120 (EX-E turns here)
	}
	for _, b in plain do
		box(b[1], B, b[2], b[3], 0, b[6], b[4], b[5], { color = b[7] })
	end

	-- B3 window (cutscene CS-2)
	local w3 = box("Window_NoHelpWanted_X-92", B, -95, -89, 2.5, 7, -31.95, -31.8, { color = PAL.glass })
	surfaceText(w3, Enum.NormalId.Back, "NO HELP WANTED", PAL.dark)

	-- B1: behind the Pad, 3 floors, door D1 on the west face (Z-09)
	local b1 = newModel("B1", B)
	box("Block_East", b1, 64, 112, 0, 30, 32, 88, { color = PAL.b1 })
	box("Block_Rear", b1, 24, 64, 0, 30, 64, 88, { color = PAL.b1 })
	local d1 = box("Door_D1", b1, 63.7, 64, Y_PAD, Y_PAD + 7.5, 46, 50, { color = PAL.dark })
	tag(d1, "D1 door")

	-- B2 laundry (Z-10), door SP-B / AN-10
	local b2 = newModel("B2", B)
	box("Block", b2, -72, -24, 0, 14, -64, -32, { color = PAL.mintGray })
	box("Awning", b2, -72, -24, 9, 9.6, -32, -30, { color = PAL.lilac, shadow = false })
	box("Door_SP-B", b2, -42, -38, 0, 7.5, -31.95, -31.75, { color = PAL.dark })
	for _, x in { -56, -32 } do
		local w = box(("Window_NoHelpWanted_X%d"):format(x), b2, x - 3, x + 3, 2.5, 7, -31.95, -31.8, { color = PAL.glass })
		surfaceText(w, Enum.NormalId.Back, "NO HELP WANTED", PAL.dark)
	end

	-- Bellmoor Savings + apartments (Z-11, AST-044 + AST-045): lot 28 wide, ground floor ~18, total ~30
	local bank = newModel("BellmoorSavings", B)
	box("Bank_GroundFloor", bank, 24, 52, 0, 18, -64, -32, { color = PAL.brick })
	box("Apartments", bank, 24, 52, 18, 30, -64, -32, { color = PAL.peach })
	box("Cornice", bank, 23.5, 52.5, 18, 18.6, -64.5, -31.5, { color = PAL.cream })
	box("BankDoor", bank, 30, 34, 0, 7.5, -31.9, -31.6, { color = PAL.dark })
	local sign = box("BankSign", bank, 28, 50, 7.5, 9.5, -31.8, -31.5, { color = PAL.cream })
	surfaceText(sign, Enum.NormalId.Back, "BELLMOOR SAVINGS", PAL.dark)
	-- C-01 clock: diameter 6, centre at ~14, south facade, faces the Pad (ANM-003 / AN-11)
	local clock = mk("Part", "C-01", bank, Vector3.new(0.6, 6, 6), CFrame.new(39, 14, -31.6) * CFrame.Angles(0, math.pi / 2, 0), {
		shape = CYLINDER,
		color = PAL.cream,
	})
	tag(clock, "C-01 clock")
	box("C-01_MinuteHand", bank, 38.85, 39.15, 14, 16.6, -31.25, -31.15, { color = PAL.dark })
	box("C-01_HourHand", bank, 39, 40.8, 13.85, 14.15, -31.25, -31.15, { color = PAL.dark })
	-- WV-1..3 apartment windows (ANM-006 / AN-04): X 28..48, heights 19..28
	for i, x in { 31, 38, 45 } do
		local w = box(("WV-%d"):format(i), bank, x - 2, x + 2, 20, 27, -31.95, -31.75, { color = PAL.glass })
		tag(w, ("WV-%d"):format(i))
	end
end

---------------------------------------------------------------------------------------------------
-- Ninth Street Mart (Z-04): X -100..-64, Z 32..64, ceiling 12, door on the chamfered NE corner.
-- Glass on the north facade and on the east facade Z 36..56 (MAP-01 7.4).
---------------------------------------------------------------------------------------------------

do
	local M = F.Mart
	local Y0 = Y_WALK
	local TOP = Y0 + 12
	local wall = { color = PAL.martWall }
	local trim = { color = PAL.offWhite }
	local glass = { color = PAL.glass, transparency = 0.5, shadow = false }

	local shell = newModel("MKT_Shell", M)
	box("Floor", shell, -100, -64, -1, Y0, 32, 64, { color = PAL.offWhite, material = CONCRETE })
	box("Wall_W", shell, -101, -100, Y0, TOP, 31.5, 64.5, wall)
	box("Wall_S", shell, -101, -63.5, Y0, TOP, 64, 64.5, wall)
	-- north facade (glass X -100..-68; the corner X -68..-64 is chamfered)
	box("North_Base", shell, -100, -68, Y0, Y0 + 1, 31.5, 32, trim)
	box("North_Glass", shell, -100, -68, Y0 + 1, Y0 + 9, 31.6, 31.9, glass)
	box("North_Header", shell, -100, -68, Y0 + 9, TOP, 31.5, 32, wall)
	box("North_Awning", shell, -100, -68, Y0 + 9, Y0 + 9.5, 29.5, 31.5, { color = PAL.martAwning, shadow = false })
	-- east facade (glass Z 36..56, solid Z 56..64)
	box("East_Base", shell, -64, -63.5, Y0, Y0 + 1, 36, 56, trim)
	box("East_Glass", shell, -63.9, -63.6, Y0 + 1, Y0 + 9, 36, 56, glass)
	box("East_Header", shell, -64, -63.5, Y0 + 9, TOP, 36, 56, wall)
	box("East_Solid", shell, -64, -63.5, Y0, TOP, 56, 64.5, wall)
	-- chamfered NE corner (-68, 32) -> (-64, 36) with a 4 x 7.5 doorway
	local A = Vector3.new(-68, 0, 32)
	local Bp = Vector3.new(-64, 0, 36)
	local dir = (Bp - A).Unit
	local L = (Bp - A).Magnitude
	local jamb = (L - 4) / 2
	local function diag(name, t0, t1, y0, y1, o)
		local a = A + dir * t0
		local b = A + dir * t1
		local ym = (y0 + y1) / 2
		return seg(name, shell, Vector3.new(a.X, ym, a.Z), Vector3.new(b.X, ym, b.Z), 0.5, y1 - y0, o)
	end
	diag("Corner_JambN", 0, jamb, Y0, Y0 + 7.5, wall)
	diag("Corner_JambE", L - jamb, L, Y0, Y0 + 7.5, wall)
	diag("Corner_Header", 0, L, Y0 + 7.5, TOP, wall)
	diag("Door", jamb, L - jamb, Y0, Y0 + 7.5, { color = PAL.glass, transparency = 0.85, collide = false, query = false, shadow = false })
	box("Roof", shell, -101, -63.5, TOP, TOP + 0.8, 31.5, 64.5, { color = PAL.offWhite })

	-- Marquee with the "OPEN 24 HOURS" sign over the safe spot (landmark, never turns off)
	local mq = newModel("Marquee_OPEN24", M)
	box("Canopy", mq, -66, -50, Y0 + 10, Y0 + 10.6, 22, 38, trim)
	cyl("Post_N", mq, -51, 23, Y0, Y0 + 10, 0.5, { color = PAL.pole })
	cyl("Post_S", mq, -51, 37, Y0, Y0 + 10, 0.5, { color = PAL.pole })
	local sN = box("Sign_North", mq, -64, -52, Y0 + 10.6, Y0 + 12.6, 22, 22.4, { color = PAL.coral, material = NEON })
	surfaceText(sN, Enum.NormalId.Front, "OPEN 24 HOURS", PAL.white)
	local sE = box("Sign_East", mq, -50.4, -50, Y0 + 10.6, Y0 + 12.6, 24, 36, { color = PAL.coral, material = NEON })
	surfaceText(sE, Enum.NormalId.Right, "OPEN 24 HOURS", PAL.white)
	local lp = box("SignLight", mq, -58.3, -57.7, Y0 + 9.5, Y0 + 9.9, 29.7, 30.3, { transparency = 1, collide = false, query = false, shadow = false })
	addLight("PointLight", lp, { Range = 14, Brightness = 1.5, Color = PAL.coral, Shadows = false })

	-- SS safe spot floor marking under the sign: centre (-58, 30), radius 6 (AST-067)
	local ss = cyl("SS", M, -58, 30, Y_WALK, Y_WALK + 0.06, 12, { color = PAL.mustard, collide = false, shadow = false })
	tag(ss, "SS safe spot")

	-- Interior
	local int = newFolder("Interior", M)
	local ceiling = box("CeilingLightPanel", int, -96, -68, TOP - 0.2, TOP, 36, 60, { color = PAL.martLight, material = NEON, shadow = false })
	addLight("SurfaceLight", ceiling, { Face = Enum.NormalId.Bottom, Range = 16, Angle = 90, Brightness = 1.2, Color = PAL.martLight, Shadows = false })

	-- Fresh produce display (AST-050), scenery only, against the north glass
	-- WedgePart: slope rotated to face south (into the store).
	mk("WedgePart", "ProduceDisplay", int, Vector3.new(8, COUNTER_H, 3), CFrame.new(-92, Y0 + COUNTER_H / 2, 35.5) * CFrame.Angles(0, math.pi, 0), {
		color = PAL.wood,
	})
	for i, f in { { -95, PAL.ketchup }, { -93, hex("FF9F43") }, { -91, hex("6DBE6A") }, { -89, PAL.cheese } } do
		mk("Part", ("Fruit%d"):format(i), int, Vector3.new(1, 1, 1), CFrame.new(f[1], Y0 + 2.6, 35.8), { shape = BALL, color = f[2] })
	end
	local ps = box("ProduceSign", int, -96, -88, Y0 + 4.5, Y0 + 6, 33.2, 33.4, { color = PAL.martAwning })
	surfaceText(ps, Enum.NormalId.Back, "FRESH PRODUCE", PAL.white)

	-- Checkout counter (AST-031) and Opal OP-1 (CHR-003), back to the north glass
	box("CheckoutCounter", int, -80, -70, Y0, Y0 + COUNTER_H, 34, 37, { color = PAL.teal })
	box("CoffeeRack", int, -70, -68.5, Y0, Y0 + COUNTER_H, 34.5, 36.5, { color = PAL.coffee })
	local opal = newModel("OP-1", int)
	box("Legs", opal, -76, -74, Y0, Y0 + 2, 33, 34, { color = PAL.dark })
	box("Torso", opal, -76, -74, Y0 + 2, Y0 + 4, 33, 34, { color = PAL.martAwning })
	local head = box("Head", opal, -75.5, -74.5, Y0 + 4, Y0 + 5, 33, 34, { color = PAL.skin })
	tag(head, "OP-1 Opal")

	-- Gondolas (east-west), low fridges at the west end, back shelves on the south wall
	box("GondolaN_Fridge", int, -84, -78, Y0, Y0 + COUNTER_H, 41, 43, { color = PAL.white })
	box("GondolaN_Shelf", int, -78, -66, Y0, Y0 + 5, 41, 43, { color = PAL.butter })
	box("GondolaS_Fridge", int, -84, -78, Y0, Y0 + COUNTER_H, 49, 51, { color = PAL.white })
	box("GondolaS_Shelf", int, -78, -66, Y0, Y0 + 5, 49, 51, { color = PAL.butter })
	box("BackShelves", int, -100, -64, Y0, Y0 + 7, 62, 64, { color = PAL.butter })

	-- 9 purchase points (one prompt each later)
	local buy = newFolder("PurchasePoints", int)
	for _, b in {
		{ "Sausages", -69, 40 },
		{ "Buns", -69, 44 },
		{ "Ketchup", -75, 40 },
		{ "Mustard", -75, 44 },
		{ "Cheese", -81, 40 },
		{ "Bacon", -81, 44 },
		{ "PotatoSticks", -75, 48 },
		{ "CreamCheese", -81, 48 },
		{ "Coffee", -68, 35 },
	} do
		marker("BUY-" .. b[1], buy, b[2], b[3], { y = Y0 + 4.5, size = 0.6, color = PAL.mQueue })
	end

	-- GEAR WALL upgrade bench (AST-049) on the west ("back") wall: X -100..-98, Z 39..57, 3.5 tall,
	-- panel 18 x 6 above; six 3-stud positions, player stands at X ~ -96 facing west.
	local gw = newModel("GEAR_WALL", int)
	box("Bench", gw, -100, -98, Y0, Y0 + COUNTER_H, 39, 57, { color = PAL.dark })
	box("BenchTopTrim", gw, -100, -98, Y0 + COUNTER_H, Y0 + COUNTER_H + 0.1, 39, 57, { color = PAL.mustard })
	box("Panel", gw, -100, -99.6, Y0 + COUNTER_H, Y0 + COUNTER_H + 6, 39, 57, { color = PAL.dark })
	local title = box("Title", gw, -99.6, -99.5, Y0 + COUNTER_H + 4.5, Y0 + COUNTER_H + 6, 39, 57, { color = PAL.mustard })
	surfaceText(title, Enum.NormalId.Right, "GEAR WALL", PAL.dark)
	box("S1_Vitrine", gw, -99.6, -98.2, Y0 + COUNTER_H, Y0 + COUNTER_H + 3, 45.1, 47.9, { color = PAL.gold, transparency = 0.3 })
	for _, slot in { { "B1", 40.5 }, { "B2", 43.5 }, { "S1", 46.5 }, { "B3", 49.5 }, { "B4", 52.5 }, { "B5", 55.5 } } do
		marker(slot[1], gw, -98, slot[2], { y = Y0 + COUNTER_H + 1, size = 0.6, color = PAL.mustard, text = "GEAR " .. slot[1] })
	end
end

---------------------------------------------------------------------------------------------------
-- The Pad (Z-01, L01-21): X 24..64, Z 32..64 (40 x 32) + cart tier 1 (AST-026)
---------------------------------------------------------------------------------------------------

do
	local P = F.Pad
	box("PadFloor", P, 24, 64, -1, Y_PAD, 32, 64, { color = PAL.pad, material = CONCRETE })
	local border = paintOpts(PAL.mustard)
	box("Border_N", P, 24, 64, Y_PAD, Y_PAD + 0.03, 32, 32.6, border)
	box("Border_S", P, 24, 64, Y_PAD, Y_PAD + 0.03, 63.4, 64, border)
	box("Border_W", P, 24, 24.6, Y_PAD, Y_PAD + 0.03, 32, 64, border)
	box("Border_E", P, 63.4, 64, Y_PAD, Y_PAD + 0.03, 32, 64, border)

	-- CART: station line X 28..54, Z 36..39, height 3.5; worker corridor Z 39..45 facing north.
	-- Order (DEC-016), left to right: stock -> grill -> rest -> bun -> board -> toppings -> delivery + drawer
	local cart = newModel("CART", P)
	local baseTop = Y_PAD + 0.8
	box("Base", cart, 27.5, 54.5, Y_PAD, baseTop, 35.5, 39.5, { color = PAL.ketchup })
	local stations = {
		{ "1_S_Stock", 28, 31, PAL.teal },
		{ "2_G_Grill", 31, 36, PAL.dark },
		{ "3_R_Rest", 36, 39, PAL.steel },
		{ "4_B_Bun", 39, 41, PAL.bun },
		{ "5_T_Board", 41, 44, PAL.wood },
		{ "6_K_Toppings", 44, 50, PAL.cream },
		{ "7_H_Delivery", 50, 54, PAL.mustard },
	}
	local stTop = Y_PAD + COUNTER_H
	for _, s in stations do
		local p = box(s[1], cart, s[2], s[3], baseTop, stTop, 36, 39, { color = s[4] })
		tag(p, s[1])
	end
	box("GrillPlate", cart, 31.2, 35.8, stTop, stTop + 0.1, 36.2, 38.8, { color = PAL.steel })
	-- toppings grid 3 x 2 (front row faces the queue / north)
	for _, t in {
		{ "Lid_Ketchup", 45, 36.75, PAL.ketchup },
		{ "Lid_Mustard", 47, 36.75, PAL.mustard },
		{ "Lid_Cheese", 49, 36.75, PAL.cheese },
		{ "Lid_Bacon", 45, 38.25, PAL.bacon },
		{ "Lid_PotatoSticks", 47, 38.25, PAL.potato },
		{ "Lid_CreamCheese", 49, 38.25, PAL.creamCheese },
	} do
		box(t[1], cart, t[2] - 0.8, t[2] + 0.8, stTop, stTop + 0.3, t[3] - 0.6, t[3] + 0.6, { color = t[4] })
	end
	local drawer = box("DRAWER", cart, 51, 53, stTop, stTop + 0.6, 36.5, 37.5, { color = PAL.money })
	tag(drawer, "DRAWER")
	-- two umbrellas at 9
	for i, x in { 32, 48 } do
		cyl(("UmbrellaPole_%d"):format(i), cart, x, 37.5, stTop, Y_PAD + 9, 0.25, { color = PAL.steel })
		cyl(("Umbrella_%d"):format(i), cart, x, 37.5, Y_PAD + 9, Y_PAD + 9.4, 9, {
			color = i == 1 and PAL.ketchup or PAL.cream,
			shadow = true,
		})
	end
	tag(cart:FindFirstChild("Base") :: Instance, "CART (tier 1)")

	-- OPEN/CLOSED sign (<= 3 tall), bin, Pad bench (L3)
	local open = box("OPEN", P, 24.4, 25.6, Y_PAD, Y_PAD + 2.5, 34.8, 35.2, { color = PAL.cream })
	surfaceText(open, Enum.NormalId.Front, "OPEN", PAL.ketchup)
	tag(open, "OPEN sign")
	local bin = cyl("BIN-C", P, 56, 42, Y_PAD, Y_PAD + 3, 2, { color = PAL.teal })
	tag(bin, "BIN-C")
	box("PadBench_L3", P, 56, 60, Y_PAD, Y_PAD + 1.6, 57.25, 58.75, { color = PAL.wood })

	-- Night trailer footprint (TRL, DEC-086): hull X 26..54, Z 35..47, ~11 tall, hitch to X 22. Ghost only.
	local trl = box("TRL", P, 26, 54, Y_PAD, Y_PAD + 11, 35, 47, zone(PAL.aluminum, 0.92))
	tag(trl, "TRL (night footprint)")
	box("TRL_Hitch", P, 22, 26, Y_PAD + 0.8, Y_PAD + 1.2, 40.7, 41.3, zone(PAL.aluminum, 0.8))

	-- Test spawn (covers PS-1..4, facing north)
	local sp = Instance.new("SpawnLocation")
	sp.Name = "SpawnLocation_PS"
	sp.Size = Vector3.new(20, 0.2, 3)
	sp.CFrame = CFrame.new(41, Y_PAD + 0.1, 42)
	sp.Anchored = true
	sp.Neutral = true
	sp.Duration = 0
	sp.CanCollide = false
	sp.Transparency = 0.6
	sp.Color = PAL.mSpawn
	sp.Material = PLASTIC
	sp.TopSurface = Enum.SurfaceType.Smooth
	sp.Parent = P
end

---------------------------------------------------------------------------------------------------
-- Food Trailer (AST-027): hull 28 x 12, floor +2, ceiling 8.5, outside ~11.
-- Built in local space (Pad orientation: service window on local -Z) and placed by CFrame.
---------------------------------------------------------------------------------------------------

local function buildTrailer(id: string, parent: Instance, cf: CFrame)
	local m = newModel(id, parent)
	local function lb(name, x0, x1, y0, y1, z0, z1, o)
		return mk(
			"Part",
			name,
			m,
			Vector3.new(x1 - x0, y1 - y0, z1 - z0),
			cf * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
			o
		)
	end
	local hull = { color = PAL.aluminum }
	local FL = TRAILER_FLOOR
	local CEIL = FL + 8.5
	local stripe = { color = PAL.ketchupFaded }

	lb("Floor", -14, 14, 1.2, FL, -6, 6, { color = PAL.steel })
	-- front wall: service window X -10..13 (world 30..53 on the Pad), sill 3.5, top 8 above the floor
	lb("Front_Lower", -14, 14, FL, FL + 3.5, -6, -5.6, hull)
	lb("Front_Left", -14, -10, FL + 3.5, FL + 8, -6, -5.6, hull)
	lb("Front_Right", 13, 14, FL + 3.5, FL + 8, -6, -5.6, hull)
	lb("Front_Top", -14, 14, FL + 8, CEIL, -6, -5.6, hull)
	lb("WindowAwning", -10, 13, FL + 8, FL + 8.3, -7.2, -6, stripe)
	-- back wall: door X 7..11 (world 47..51), 4 x 7.5
	lb("Back_Left", -14, 7, FL, CEIL, 5.6, 6, hull)
	lb("Back_Right", 11, 14, FL, CEIL, 5.6, 6, hull)
	lb("Back_OverDoor", 7, 11, FL + 7.5, CEIL, 5.6, 6, hull)
	lb("Side_W", -14, -13.6, FL, CEIL, -5.6, 5.6, hull)
	lb("Side_E", 13.6, 14, FL, CEIL, -5.6, 5.6, hull)
	lb("Roof", -14.2, 14.2, CEIL, CEIL + 0.5, -6.2, 6.2, hull)
	lb("Stripe_Front", -14, 14, FL + 1.2, FL + 2.2, -6.1, -6, stripe)
	lb("Stripe_Back", -14, 14, FL + 1.2, FL + 2.2, 6, 6.1, stripe)
	-- stations, same order and X as the cart (grill 6 wide): local X = world X - 40 on the Pad
	for _, s in {
		{ "1_S_Stock", -13, -10, PAL.teal },
		{ "2_G_Grill", -10, -4, PAL.dark },
		{ "3_R_Rest", -4, -1, PAL.steel },
		{ "4_B_Bun", -1, 1, PAL.bun },
		{ "5_T_Board", 1, 4, PAL.wood },
		{ "6_K_Toppings", 4, 10, PAL.cream },
		{ "7_H_Delivery", 10, 13, PAL.mustard },
	} do
		lb(s[1], s[2], s[3], FL, FL + COUNTER_H, -5.6, -2, { color = s[4] })
	end
	lb("BackBench_Seat", -13.6, -4, FL, FL + 1.5, 2, 5, { color = PAL.wood }) -- AST-040, scenery
	lb("BackBench_Back", -13.6, -4, FL + 1.5, FL + 3.5, 5, 5.6, { color = PAL.wood })
	lb("CoffeeMaker", -1.5, 1.5, FL, FL + COUNTER_H, 1.5, 4.5, { color = PAL.teal })
	lb("Bin", 2.7, 4.3, FL, FL + 2, 2.2, 3.8, { color = PAL.dark })
	lb("LightSwitch", 5.6, 6.4, FL + 3.5, FL + 4.7, 5.4, 5.6, { color = PAL.mustard })
	lb("Steps", 7, 11, 0, 1, 6, 7.5, { color = PAL.steel })
	lb("Hitch", -18, -14, 1.2, 1.6, -0.3, 0.3, { color = PAL.steel })
	lb("HitchJack", -17.6, -17, 0, 1.2, -0.3, 0.3, { color = PAL.steel })
	for _, z in { -6.4, 6.4 } do
		mk("Part", z < 0 and "Wheel_Front" or "Wheel_Back", m, Vector3.new(0.8, 2.2, 2.2), cf * CFrame.new(0, 1.1, z) * CFrame.Angles(0, math.pi / 2, 0), {
			shape = CYLINDER,
			color = PAL.dark,
		})
	end
	return m
end

do
	local T = F.Trailer
	-- TRL-SALE (78, -58): service window faces south, toward the Pad (DEC-047). Rotated 180 degrees.
	local sale = buildTrailer("TRL-SALE", T, CFrame.new(78, 0, -58) * CFrame.Angles(0, math.pi, 0))
	tag(sale:FindFirstChild("Roof") :: Instance, "TRL-SALE (for sale)")
	-- SIGN-T "Available on Day 5" (78, -40), 4 x 5, read-only, faces south
	local sign = newModel("SIGN-T", T)
	box("LegW", sign, 76.3, 76.6, 0, 3, -40.15, -39.85, { color = PAL.steel })
	box("LegE", sign, 79.4, 79.7, 0, 3, -40.15, -39.85, { color = PAL.steel })
	local board = box("Board", sign, 76, 80, 2, 5, -40.2, -39.8, { color = PAL.mustard })
	surfaceText(board, Enum.NormalId.Back, "AVAILABLE ON DAY 5", PAL.dark)
	tag(board, "SIGN-T")
end

---------------------------------------------------------------------------------------------------
-- Parking lot (Z-05) X 52..104, Z -88..-32 + parked cars (PARK-N, lot), van, TRUCK
---------------------------------------------------------------------------------------------------

local function parkedCar(name: string, parent: Instance, cx: number, cz: number, alongX: boolean, color: Color3, len: number?, wid: number?, h: number?)
	local L, W, H = len or 11, wid or 6, h or 4.5
	local m = newModel(name, parent)
	local hx = (alongX and L or W) / 2
	local hz = (alongX and W or L) / 2
	local y0 = Y_ROAD + 0.4
	box("Body", m, cx - hx, cx + hx, y0, y0 + H * 0.55, cz - hz, cz + hz, { color = color })
	local cx0 = alongX and hx * 0.55 or hx * 0.9
	local cz0 = alongX and hz * 0.9 or hz * 0.55
	box("Cabin", m, cx - cx0, cx + cx0, y0 + H * 0.55, y0 + H, cz - cz0, cz + cz0, { color = PAL.glass })
	return m
end

do
	local K = F.Parking
	box("Z-05_ParkingLot", K, 52, 104, -1, 0.02, -88, -32, { color = PAL.parking, material = ASPHALT })
	for _, x in { 56, 64, 72 } do
		box(("StallLine_X%d"):format(x), K, x - 0.15, x + 0.15, 0.02, 0.05, -88, -76, paintOpts(PAL.paint))
	end
	-- low fence (<= 3) along the Ninth, entrance X 64..76 (AN-12 at its mouth)
	box("Fence_W", K, 52, 64, 0.02, 2.5, -33, -32.7, { color = PAL.offWhite })
	box("Fence_E", K, 76, 104, 0.02, 2.5, -33, -32.7, { color = PAL.offWhite })

	-- lot cars + van (AS-1 hides behind the van, NE corner)
	parkedCar("LotCar_1", K, 60, -81, false, PAL.peach)
	parkedCar("LotCar_2", K, 68, -81, false, PAL.lilac)
	parkedCar("LotCar_3", K, 100, -48, false, PAL.tealLight)
	local van = parkedCar("Van_AS-1_Cover", K, 92, -72.5, false, PAL.mintGray, 12, 7, 7)
	tag(van:FindFirstChild("Body") :: Instance, "VAN")

	-- PARK-N: north parking lane of the Ninth (Z -16..-10), never on the red curb X -32..76
	local pn = newFolder("PARK-N", K)
	for i, c in { { -104, PAL.butter }, { -90, PAL.peach }, { -62, PAL.tealLight }, { -44, PAL.lilac }, { 84, PAL.mintGray }, { 98, PAL.butter } } do
		parkedCar(("ParkN_Car_%d"):format(i), pn, c[1], -13, true, c[2])
	end

	-- TRUCK: south curb lane X 88..108, Z 10..16 (AN-02, covers AS-2)
	local truck = newModel("TRUCK", K)
	box("Cargo", truck, 88, 102, 0.8, 9, 10, 16, { color = PAL.cream })
	box("Cab", truck, 102, 108, 0.8, 7, 10, 16, { color = PAL.teal })
	box("Chassis", truck, 88, 108, 0.2, 0.8, 10.5, 15.5, { color = PAL.dark })
	tag(truck:FindFirstChild("Cargo") :: Instance, "TRUCK")
end

---------------------------------------------------------------------------------------------------
-- Street lights (L01-22): JL-01..09 (Juniper west sidewalk, X -16, every 8 studs) + P-01.
-- These 10 carry a SpotLight (night only -> Enabled = false here). Ninth posts stay dark (no light).
---------------------------------------------------------------------------------------------------

local function streetLight(id: string, parent: Instance, x: number, z: number, dx: number, dz: number, lit: boolean)
	local m = newModel(id, parent)
	local top = Y_WALK + POLE_H
	cyl("Pole", m, x, z, Y_WALK, top, 0.6, { color = PAL.pole })
	local d = Vector3.new(dx, 0, dz).Unit
	local a = Vector3.new(x, top - 0.2, z)
	local b = a + d * 3
	seg("Arm", m, a, b, 0.3, 0.3, { color = PAL.pole })
	local head = mk("Part", "Lamp", m, Vector3.new(1.4, 0.4, 1.4), CFrame.new(b - Vector3.new(0, 0.35, 0)), { color = PAL.lampOff, shadow = false })
	if lit then
		head:SetAttribute("NightLamp", true)
		addLight("SpotLight", head, {
			Face = Enum.NormalId.Bottom,
			Range = 18,
			Angle = 30,
			Brightness = 2,
			Color = PAL.sodium,
			Shadows = false,
			Enabled = false,
		})
	end
	tag(m:FindFirstChild("Pole") :: Instance, id)
	return m
end

do
	local SL = F.StreetLights
	local jlZ = { -24, -32, -40, -48, -56, -64, -72, -80, -88 }
	for i, z in jlZ do
		streetLight(("JL-%02d"):format(i), SL, -16, z, 1, 0, true)
	end
	streetLight("P-01", SL, 20, 20, -1, -1, true) -- SE corner, flyer, last post of the Hush
	-- Dark Ninth posts (visual only; the Pad <-> Mart route stays dark at night, MAP-01 10.1)
	streetLight("Post_NinthS_W1", SL, -40, 18, 0, -1, false)
	streetLight("Post_NinthS_W2", SL, -90, 18, 0, -1, false)
	streetLight("Post_NinthN_W1", SL, -76, -18, 0, 1, false)
	streetLight("Post_NinthN_E1", SL, 108, -18, 0, 1, false)
	streetLight("Post_L2", SL, 84, 18, 0, -1, false) -- "poste leste" next to L2
end

---------------------------------------------------------------------------------------------------
-- Signs: PARE-N / PARE-S (Q-129 provisional), SIDEWALK CLOSED at BAR-N / BAR-S, P-01 flyer
---------------------------------------------------------------------------------------------------

do
	local G = F.Signs
	local function stopSign(id, x, z, face)
		local m = newModel(id, G)
		cyl("Pole", m, x, z, Y_WALK, Y_WALK + 7.2, 0.3, { color = PAL.pole })
		local plate = box("Plate", m, x - 1.2, x + 1.2, Y_WALK + 5.2, Y_WALK + 7.6, z - 0.1, z + 0.1, { color = PAL.ketchup })
		surfaceText(plate, face, "STOP", PAL.white)
		tag(plate, id)
	end
	stopSign("PARE-N", -14, -20, Enum.NormalId.Front) -- faces north (SB traffic)
	stopSign("PARE-S", 13, 17, Enum.NormalId.Back) -- faces south (NB traffic)

	local function sawhorse(id, x, z, face)
		local m = newModel(id, G)
		box("LegW", m, x - 1.9, x - 1.6, Y_WALK, Y_WALK + 3, z - 0.6, z + 0.6, { color = PAL.offWhite })
		box("LegE", m, x + 1.6, x + 1.9, Y_WALK, Y_WALK + 3, z - 0.6, z + 0.6, { color = PAL.offWhite })
		local b = box("Board", m, x - 2, x + 2, Y_WALK + 2, Y_WALK + 3.2, z - 0.12, z + 0.12, { color = PAL.cone })
		surfaceText(b, face, "SIDEWALK CLOSED", PAL.white)
	end
	sawhorse("SidewalkClosed_BAR-N_W", -18, -74.8, Enum.NormalId.Back)
	sawhorse("SidewalkClosed_BAR-N_E", 18, -74.8, Enum.NormalId.Back)
	sawhorse("SidewalkClosed_BAR-S_W", -18, 78.8, Enum.NormalId.Front)
	sawhorse("SidewalkClosed_BAR-S_E", 18, 78.8, Enum.NormalId.Front)

	local cones = newFolder("Cones_AST-047", G)
	for _, c in { { -22, -75 }, { -14, -75 }, { 14, -75 }, { 22, -75 }, { -22, 79 }, { -14, 79 }, { 14, 79 }, { 22, 79 } } do
		cyl(("Cone_%d_%d"):format(c[1], c[2]), cones, c[1], c[2], Y_WALK, Y_WALK + 1.4, 0.8, { color = PAL.cone })
	end

	-- P-01 flyer on the SW face of the pole (AN-03, cutscene CS-6), ~4.5 high
	local sw = Vector3.new(-1, 0, 1).Unit
	local pos = Vector3.new(20, 4.5, 20) + sw * 0.36
	local flyer = mk("Part", "P-01_Flyer", G, Vector3.new(1.2, 1.6, 0.05), CFrame.lookAt(pos, pos + sw), { color = PAL.cream, shadow = false })
	surfaceText(flyer, Enum.NormalId.Front, "HELP WANTED", PAL.ketchup)
end

---------------------------------------------------------------------------------------------------
-- Player limits (walls for characters only in the real game; here: collidable translucent walls)
---------------------------------------------------------------------------------------------------

do
	local Lm = F.Limits
	local wallO = { color = PAL.mLimit, transparency = 0.88, query = false, shadow = false }
	tag(box("BAR-N", Lm, -36, 24, 0, 30, -76.25, -75.75, wallO), "BAR-N Z-76") -- extended west to close alley X -36..-24
	tag(box("BAR-S", Lm, -24, 24, 0, 30, 79.75, 80.25, wallO), "BAR-S Z80")
	tag(box("BAR-W", Lm, -112.25, -111.75, 0, 30, -32, 32, wallO), "BAR-W")
	tag(box("BAR-E", Lm, 111.75, 112.25, 0, 30, -32, 32, wallO), "BAR-E")
end

---------------------------------------------------------------------------------------------------
-- Markers (CanCollide/CanQuery false, neon, named after MAP-01 IDs)
---------------------------------------------------------------------------------------------------

do
	local Mk = F.Markers

	-- Landmarks
	local lm = newFolder("Landmarks", Mk)
	marker("MKT-DOOR", lm, -62, 34, { color = PAL.coral, face = EAST })

	-- Player spawns (5.1)
	local ps = newFolder("PlayerSpawns", Mk)
	for i, x in { 32, 38, 44, 50 } do
		marker(("PS-%d"):format(i), ps, x, 42, { y = Y_PAD + 0.8, color = PAL.mSpawn, face = NORTH })
		marker(("PS-N%d"):format(i), ps, x, 41, { y = Y_PAD + TRAILER_FLOOR + 0.8, color = PAL.mSpawnNight, face = NORTH, size = 0.7 })
	end
	for i, x in { 31, 37, 43, 49 } do -- trailer hide spots (night)
		marker(("H%d"):format(i), ps, x, 39.5, { y = Y_PAD + TRAILER_FLOOR + 0.5, color = PAL.mSpawnNight, size = 0.5 })
	end

	-- Queue Q1..Q5
	local q = newFolder("Queue", Mk)
	marker("Q1", q, 52, 33, { color = PAL.mQueue, face = SOUTH })
	for i, x in { 46, 41, 36, 31 } do
		marker(("Q%d"):format(i + 1), q, x, 29, { color = PAL.mQueue, face = EAST })
	end

	-- Customers: spawns, exits, routes (5.3, 9.1). LANE-E Z ~23 (eastbound), LANE-W Z ~18 (westbound)
	local cu = newFolder("Customers", Mk)
	marker("SP-A", cu, 30, -104, { color = PAL.mCustomer })
	marker("SP-B", cu, -40, -32, { color = PAL.mCustomer })
	marker("D1", cu, 64, 48, { color = PAL.mCustomer })
	marker("EX-E", cu, 116, 24, { color = PAL.mCustomer })
	local cr = newFolder("Routes", cu)
	route("ROUTE-SP-A", cr, { { 30, -104 }, { 18, -104 }, { 18, 23 }, { 26, 23 }, { 31, 29 } }, PAL.mCustomer)
	route("ROUTE-SP-B", cr, { { -40, -32 }, { -40, -24 }, { -18, -24 }, { -18, 38 }, { 18, 38 }, { 18, 23 }, { 26, 23 }, { 31, 29 } }, PAL.mCustomer)
	route("ROUTE-D1-IN", cr, { { 64, 48 }, { 62, 48 }, { 62, 18 }, { 26, 18 }, { 26, 29 }, { 31, 29 } }, PAL.mCustomer)
	route("ROUTE-QUEUE", cr, { { 31, 29 }, { 36, 29 }, { 41, 29 }, { 46, 29 }, { 52, 33 } }, PAL.mQueue)
	route("ROUTE-EXIT-E", cr, { { 52, 33 }, { 55, 23 }, { 112, 23 }, { 116, 24 } }, PAL.mCustomer)
	route("ROUTE-EXIT-D1", cr, { { 52, 33 }, { 58, 33 }, { 58, 47 }, { 64, 47 } }, PAL.mCustomer)

	-- Thief (9.2): lurk spots L1..L3, spawn ST-R, routes along the Juniper South east sidewalk only
	local th = newFolder("Thief", Mk)
	marker("L1", th, 20, 20, { color = PAL.mThief })
	marker("L2", th, 84, 22, { color = PAL.mThief })
	marker("L3", th, 58, 58, { y = Y_PAD + 2.4, color = PAL.mThief })
	marker("ST-R", th, 18, 92, { color = PAL.mThief })
	route("THIEF-L1", th, { { 18, 92 }, { 18, 24 }, { 20, 20 } }, PAL.mThief)
	route("THIEF-L2", th, { { 18, 26 }, { 84, 22 } }, PAL.mThief)
	route("THIEF-L3", th, { { 18, 58 }, { 58, 58 } }, PAL.mThief)
	route("THIEF-FLEE-E", th, { { 84, 22 }, { 116, 24 } }, PAL.mThief)

	-- Ambulance, revive, spectator (5.5). AMB-IN = W-IN, AMB-OUT = E-OUT. Ambulance 18 x 7.5 x 8.5.
	local am = newFolder("Ambulance", Mk)
	box("AMB-M_Footprint", am, -59, -41, 0, 8.5, 9.25, 16.75, zone(PAL.mAmbulance, 0.85))
	box("AMB-P_Footprint", am, 35, 53, 0, 8.5, 9.25, 16.75, zone(PAL.mAmbulance, 0.85)) -- rear doors at X 35
	marker("AMB-M", am, -50, 13, { y = 9.3, color = PAL.mAmbulance, face = EAST })
	marker("AMB-P", am, 44, 13, { y = 9.3, color = PAL.mAmbulance, face = EAST })
	for i, x in { 38, 42, 46, 50 } do
		marker(("REV-%d"):format(i), am, x, 20, { color = PAL.mRevive, face = SOUTH })
	end
	marker("SPEC-P", am, 66, 28, { y = 20, color = PAL.mAmbulance, lookAt = Vector3.new(46, 2, 30) })
	marker("SPEC-M", am, -48, 40, { y = 14, color = PAL.mAmbulance, lookAt = Vector3.new(-54, 1, 22) })

	-- Opening cutscene (11.1) and ending (11.3)
	local cs = newFolder("Cutscene", Mk)
	marker("CS-1", cs, -100, -24, { color = PAL.mCutscene, face = EAST })
	marker("CS-2", cs, -60, -24, { color = PAL.mCutscene, face = EAST })
	marker("CS-3", cs, -18, -22, { color = PAL.mCutscene, face = SOUTH })
	marker("CS-4", cs, -18, 22, { color = PAL.mCutscene, face = SOUTH })
	marker("CS-5", cs, 0, 38, { color = PAL.mCutscene, face = EAST }) -- mid CW-1 (path W sidewalk -> CW-1 -> P-01)
	marker("CS-6", cs, 18, 25, { y = 2.4, color = PAL.mCutscene, face = dirTo(18, 25, 20, 20) }) -- flyer close-up
	marker("CS-7", cs, 18, 25, { y = 3.6, color = PAL.mCutscene, face = dirTo(18, 25, 41, 40) }) -- look SE at the cart
	for i, p in { { 16, 25 }, { 19, 27 }, { 23, 26 }, { 13, 22 } } do
		marker(("CS-P%d"):format(i), cs, p[1], p[2], { color = PAL.mCutscene, size = 0.7, face = dirTo(p[1], p[2], 20, 20) })
	end
	route("ROUTE-CUTSCENE", cs, { { -100, -24 }, { -60, -24 }, { -18, -22 }, { -18, 22 }, { -18, 38 }, { 18, 38 }, { 18, 25 } }, PAL.mCutscene)
	for i, p in { { -54, 26 }, { -52, 30 }, { -54, 34 }, { -56, 23 } } do
		marker(("SS-%d"):format(i), cs, p[1], p[2], { color = PAL.mCutscene, size = 0.7, face = WEST })
	end
	marker("WALT-1", cs, -60, 30, { color = PAL.mCutscene, face = EAST })
	marker("RL-1", cs, -100, -22, { color = PAL.mCutscene, face = EAST })
	marker("RL-END", cs, -76, -22, { color = PAL.mCutscene })

	-- Anomaly anchors AN-xx (10.3; AN-08 retired, ID not reused) and hidden actor spawns AS-1..4
	local an = newFolder("Anomaly", Mk)
	for _, a in {
		{ "AN-01", 78, -58, 13 }, -- sale trailer spot (tarp cart at night)
		{ "AN-02", 98, 13, 10.5 }, -- truck
		{ "AN-03", 20, 20, 6 }, -- P-01 + flyer
		{ "AN-04", 38, -31, 23.5 }, -- WV-1..3
		{ "AN-05", 49, 47, Y_PAD + TRAILER_FLOOR + 5.5 }, -- trailer back door (Pad trailer)
		{ "AN-06", 40, 37.5, Y_PAD + TRAILER_FLOOR + 4.5 }, -- trailer interior objects
		{ "AN-07", 41, 29, 3.5 }, -- queue Q1..Q5
		{ "AN-09", -16, -56, 17 }, -- JL-09 -> JL-01 -> P-01 chain (Walker, Hush)
		{ "AN-10", -40, -32, 9 }, -- laundry door
		{ "AN-11", 39, -30.8, 14 }, -- C-01 clock
		{ "AN-12", 70, -22, MARK_Y }, -- parking entrance mouth, long car faces south
	} do
		marker(a[1], an, a[2], a[3], { y = a[4], color = PAL.mAnomaly, face = a[1] == "AN-12" and SOUTH or nil })
	end
	for _, a in { { "AS-1", 92, -80 }, { "AS-2", 100, 18 }, { "AS-3", -30, -104 }, { "AS-4", -40, -36 } } do
		marker(a[1], an, a[2], a[3], { color = PAL.mHiddenSpawn })
	end

	-- Walker steps 0..10 (5.6). Step 10 fixed at (28, 29).
	local wk = newFolder("Walker", Mk)
	local steps = { { -16, -88 }, { -16, -80 }, { -16, -72 }, { -16, -64 }, { -16, -56 }, { -16, -48 }, { -16, -40 }, { -16, -32 }, { -16, -24 }, { 20, 20 }, { 28, 29 } }
	for i, p in steps do
		marker(("WALKER-%d"):format(i - 1), wk, p[1], p[2], { y = 3, size = 1.2, color = PAL.mWalker })
	end
	route("ROUTE-WALKER", wk, steps, PAL.mWalker)

	-- Traffic spawns / despawns (5.4)
	local tr = newFolder("Traffic", Mk)
	for _, t in {
		{ "W-IN", -136, 5, EAST, "W-IN / AMB-IN" },
		{ "W-OUT", -136, -5, WEST },
		{ "E-IN", 136, -5, WEST },
		{ "E-OUT", 136, 5, EAST, "E-OUT / AMB-OUT" },
		{ "JN-IN", -6, -140, SOUTH },
		{ "JN-OUT", 6, -140, NORTH },
		{ "JS-IN", 6, 116, NORTH },
		{ "JS-OUT", -6, 116, SOUTH },
	} do
		marker(t[1], tr, t[2], t[3], { y = 2, size = 1.4, color = PAL.mTraffic, face = t[4], text = t[5] })
	end

	-- Player routes (3, 6): Mart door <-> cart (one crossing, CW-1), trailer back door -> SS, Pad -> sale trailer (CW-3)
	local pr = newFolder("PlayerRoutes", Mk)
	route("ROUTE-PAD-MART", pr, { { 28, 42 }, { 24, 40 }, { 12, 38 }, { -12, 38 }, { -24, 36 }, { -62, 34 } }, PAL.mPlayerRoute)
	route("ROUTE-TRL-SS", pr, { { 49, 48 }, { 24, 48 }, { 12, 40 }, { -12, 39 }, { -52, 31 }, { -58, 30 } }, PAL.coral)
	route("ROUTE-PAD-SALE", pr, { { 55, 42 }, { 57, 30 }, { 57, -18 }, { 70, -30 }, { 78, -50 } }, PAL.mustard)

	-- Light zones LZ-1..LZ-5 (10.2): sanity "light" volumes, separate from visual lighting
	local lz = newFolder("LightZones", Mk)
	tag(box("LZ-1", lz, 27, 53, Y_PAD + TRAILER_FLOOR, Y_PAD + TRAILER_FLOOR + 8.5, 36, 46, zone(PAL.warm, 0.9)), "LZ-1")
	tag(box("LZ-2", lz, 44, 56, Y_PAD, Y_PAD + 6, 30, 35, zone(PAL.warm, 0.85)), "LZ-2")
	tag(cyl("LZ-3", lz, 40, 41, 0.5, 0.56, 36, zone(PAL.warm, 0.8)), "LZ-3 r18")
	tag(box("LZ-4", lz, -100, -64, Y_WALK, Y_WALK + 12, 32, 64, zone(PAL.martLight, 0.95)), "LZ-4")
	tag(cyl("LZ-5", lz, -58, 30, Y_WALK, Y_WALK + 8, 12, zone(PAL.coral, 0.8)), "LZ-5 SS r6")
end

---------------------------------------------------------------------------------------------------
-- Optional night preview (does not run by default; Lighting is left untouched)
---------------------------------------------------------------------------------------------------

local function setNightPreview(on: boolean)
	local r = Workspace:FindFirstChild(ROOT_NAME)
	if not r then
		return
	end
	if on then
		if r:GetAttribute("SavedClockTime") == nil then
			r:SetAttribute("SavedClockTime", Lighting.ClockTime)
		end
		Lighting.ClockTime = 21
	else
		local saved = r:GetAttribute("SavedClockTime")
		if saved ~= nil then
			Lighting.ClockTime = saved
			r:SetAttribute("SavedClockTime", nil)
		end
	end
	for _, d in r:GetDescendants() do
		if d:IsA("SpotLight") and d.Parent and d.Parent:GetAttribute("NightLamp") then
			d.Enabled = on
			local lamp = d.Parent :: BasePart
			lamp.Material = on and NEON or PLASTIC
			lamp.Color = on and PAL.sodium or PAL.lampOff
		end
	end
end
_G.MAP01_NightPreview = setNightPreview

---------------------------------------------------------------------------------------------------
-- Commit + report
---------------------------------------------------------------------------------------------------

root.Parent = Workspace
-- setNightPreview(true)

local parts, lights, nightLights, tags = 0, 0, 0, 0
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	elseif d:IsA("Light") then
		lights += 1
		if d:IsA("SpotLight") then
			nightLights += 1
		end
	elseif d:IsA("BillboardGui") then
		tags += 1
	end
end
print(
	("[MAP01_Blockout] built: %d parts | %d local lights (%d night-only SpotLights, off by default; budget <= 18) | %d ID tags"):format(
		parts,
		lights,
		nightLights,
		tags
	)
)
