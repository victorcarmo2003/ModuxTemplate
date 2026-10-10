--!strict
--[[
	Vehicle kit builder (TASK-099; architecture.md §8.1, §18.9, §19.17). EDIT MODE ONLY: Command Bar or Studio MCP.
	InsertService is allowed here because this is a tool (§18.9 rule 1: never in src/).

	Builds, outside Rojo (§18.9 rule 5), ONLY ReplicatedStorage.Assets.Vehicles (Crew / Items / Equipment and the root
	KitVersion are left alone). Folder name and tree are Provisional (§18.9.1 has no vehicle entry yet; proposal for the
	architect in the TASK-099 row):
	  Vehicles                      Folder, KitVersion = VEHICLES_VERSION; attributes Shapes, Paints (fixed order)
	    Cars/<Shape>                AST-035 (Sedan, Hatch, Van, Pickup): Model, PrimaryPart Body
	      Body                      Hit_Front, VFX_Honk, Beam_L/R + Beam_L/R_End (short cone for a Beam, no real light)
	      Headlights                Neon Cream at night is applied by the consumer (style guide §2.3: no real light)
	      Wheel_FL/FR/RL/RR         Axle attachment at the wheel centre (spin about Axle X; attribute WheelRadius)
	      Paints/<Color>            Peach, Butter, Lilac, MintGray, TealLight: MeshParts already in place
	    LongCar                     AST-065 (ANM-008): Body, Glass, Headlights, Wheel_*; Body: Hit_Front,
	                                Light_HighL/R (SpotLight #F4F7FF, Range 30, no shadow, Enabled = false) + _End

	Choosing a paint (the consumer, e.g. TrafficController TASK-105):
		local car = Vehicles.Cars[shape]:Clone()
		local paint = car.Paints[color]; paint.Name = "Paint"; paint.Parent = car
		car.Paints:Destroy()
		car:PivotTo(cf) -- pivot = base centre; LookVector = front of the car

	Kit conventions:
	  - pivot = base centre (wheels touch Y 0 of the pivot); pivot LookVector (-Z) = FRONT of the car. The imported FBX
	    has its front at +Z (MAP-01_placements.luau fact 1), so the pivot is turned 180 degrees here, once;
	  - attachments facing forward (Hit_Front, VFX_Honk, Beam_*, Light_*) have LookVector = front;
	  - every part Anchored, CanCollide / CanQuery / CanTouch false (§8.1: local car, hit tested by box in the client);
	  - attribute Asset = "AST-###_<name>" on every Model and BasePart (§18.9 rule 7); Tris = .blend count;
	    Model attributes Size (Vector3, pivot-space extents) and WheelRadius;
	  - the 5 paints share the geometry of the main asset's Paint part: each one is aligned on it (no origin maths).
	Empties do NOT survive the FBX import: attachments are rebuilt from the points below (Roblox axes of the imported
	FBX: x = -X, y = Z, z = Y of Blender), measured in the approved .blend sources on 2026-10-10.

	Usage (repo served at http://127.0.0.1:8772/, e.g. `python -m http.server 8772` at the repo root):
		local Http = game:GetService("HttpService")
		local was = Http.HttpEnabled
		Http.HttpEnabled = true
		local ms = Instance.new("ModuleScript")
		ms.Source = Http:GetAsync("http://127.0.0.1:8772/tools/assetplace/build_vehicles.luau")
		Http.HttpEnabled = was
		local Vehicles = require(ms)
		print(Vehicles.run({ baseUrl = "http://127.0.0.1:8772/" }))              -- build + check
		print(Vehicles.run({ baseUrl = "http://127.0.0.1:8772/", demo = true })) -- + workspace.VehiclesDemo
		print(Vehicles.check())                                                   -- check only (after a build)
		Vehicles.clearDemo()
	Without the server: Vehicles.run({ ids = <_asset_ids table> }).
	Save the place afterwards (Ctrl+S): the place is not in git, this script is the recipe.
]]

local HttpService = game:GetService("HttpService")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

type Ids = { [string]: any }
type Box = { min: Vector3, max: Vector3 }
type PartSpec = { name: string, box: Box, tris: number }
type VehicleSpec = {
	asset: string, -- key in _asset_ids.json
	parts: { PartSpec }, -- first = Body (root)
	atts: { [string]: Vector3 }, -- on Body, asset space, facing front
	paints: string?, -- key of the _Paints asset (cars only)
	defaultPaint: string?, -- colour of the Paint part inside the main asset
	budget: number,
}
export type Options = {
	baseUrl: string?,
	ids: Ids?,
	reload: boolean?, -- drop cached vehicle assets and load them again
	demo: boolean?, -- also build workspace.VehiclesDemo for a visual check
}

local Vehicles = {}

const VEHICLES_VERSION = 1
const CACHE_NAME = "__AssetCache" -- shared with place_assets / build_kits / build_items
const DEMO_NAME = "VehiclesDemo"
const SIZE_TOL = 0.05
const FRONT = CFrame.Angles(0, math.pi, 0) -- asset +Z (front) -> LookVector
const SHAPES = { "Sedan", "Hatch", "Van", "Pickup" } -- order = Shapes attribute (index for Look, TASK-104)
const PAINTS = { "Peach", "Butter", "Lilac", "MintGray", "TealLight" } -- AST-035, style guide §2.2
const WHEELS = { "Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR" }
const CAR_BUDGET = 2000 -- AST-035 ceiling
const LONG_BUDGET = 2500 -- AST-065
-- Short cone of the traffic headlights (style guide §2.3: Beam, no real light). Provisional length.
const BEAM_LENGTH = 8
const BEAM_INSET = 0.4 -- lamp centre inside each end of the Headlights strip
-- AST-065 high beam (Provisional values except colour / range / shadows, which come from the sheet)
const HIGH_BEAM_COLOR = Color3.fromHex("#F4F7FF")
const HIGH_BEAM_RANGE = 30
const HIGH_BEAM_ANGLE = 45
const HIGH_BEAM_BRIGHTNESS = 3
const LONG_GLASS_TRANSPARENCY = 0.15 -- "vidros embaçados (translúcido escuro)", Provisional

local function box(x0: number, y0: number, z0: number, x1: number, y1: number, z1: number): Box
	return { min = Vector3.new(x0, y0, z0), max = Vector3.new(x1, y1, z1) }
end

local function centre(b: Box): Vector3
	return (b.min + b.max) / 2
end

-- Wheels: left = +X (the car faces +Z in the imported FBX)
local function wheels(x0: number, x1: number, r: number, fz0: number, fz1: number, rz0: number, rz1: number): { PartSpec }
	return {
		{ name = "Wheel_FL", box = box(x0, 0, fz0, x1, r, fz1), tris = 164 },
		{ name = "Wheel_FR", box = box(-x1, 0, fz0, -x0, r, fz1), tris = 164 },
		{ name = "Wheel_RL", box = box(x0, 0, rz0, x1, r, rz1), tris = 164 },
		{ name = "Wheel_RR", box = box(-x1, 0, rz0, -x0, r, rz1), tris = 164 },
	}
end

local function car(
	name: string,
	defaultPaint: string,
	body: PartSpec,
	headlights: PartSpec,
	paint: PartSpec,
	wheelParts: { PartSpec },
	hit: Vector3,
	honk: Vector3
): VehicleSpec
	local parts = { body, headlights, paint }
	for _, w in wheelParts do
		table.insert(parts, w)
	end
	local hl = headlights.box
	local bx = hl.max.X - BEAM_INSET
	local by = (hl.min.Y + hl.max.Y) / 2
	return {
		asset = "AST-035_Car" .. name,
		parts = parts,
		atts = {
			Hit_Front = hit,
			VFX_Honk = honk,
			Beam_L = Vector3.new(bx, by, hl.max.Z),
			Beam_R = Vector3.new(-bx, by, hl.max.Z),
			Beam_L_End = Vector3.new(bx, 0.1, hl.max.Z + BEAM_LENGTH),
			Beam_R_End = Vector3.new(-bx, 0.1, hl.max.Z + BEAM_LENGTH),
		},
		paints = "AST-035_Car" .. name .. "_Paints",
		defaultPaint = defaultPaint,
		budget = CAR_BUDGET,
	}
end

const CARS: { [string]: VehicleSpec } = {
	Sedan = car(
		"Sedan",
		"Peach",
		{ name = "Body", box = box(-3.529, 0.706, -6, 3.529, 5.75, 6), tris = 562 },
		{ name = "Headlights", box = box(-2.588, 2.824, 5.059, 2.588, 3.373, 5.529), tris = 8 },
		{ name = "Paint", box = box(-3.529, 2.353, -5.765, 3.529, 6.118, 5.529), tris = 134 },
		wheels(1.176, 2.824, 2.824, 1.847, 4.6, -4.365, -1.612),
		Vector3.new(0, 1.5529, 5.4),
		Vector3.new(0, 3.7929, 4.4)
	),
	Hatch = car(
		"Hatch",
		"Butter",
		{ name = "Body", box = box(-3.059, 0.706, -6.706, 3.059, 5.176, 6.706), tris = 584 },
		{ name = "Headlights", box = box(-2.588, 2.353, 5.765, 2.588, 2.824, 6.235), tris = 8 },
		{ name = "Paint", box = box(-3.059, 0.941, -6, 3.059, 5.176, 6.235), tris = 168 },
		wheels(1.176, 2.824, 2.824, 2.553, 5.306, -5.07, -2.318),
		Vector3.new(0, 1.5529, 6.1059),
		Vector3.new(0, 3.2094, 5.1059)
	),
	Van = car(
		"Van",
		"MintGray",
		{ name = "Body", box = box(-3.529, 0.706, -6.471, 3.529, 5.681, 6.471), tris = 584 },
		{ name = "Headlights", box = box(-2.588, 2.824, 5.529, 2.588, 3.412, 6), tris = 14 },
		{ name = "Paint", box = box(-3.529, 2.353, -6.235, 3.529, 6.353, 6), tris = 156 },
		wheels(1.176, 2.824, 2.824, 2.318, 5.07, -4.835, -2.082),
		Vector3.new(0, 1.5529, 5.8706),
		Vector3.new(0, 3.9388, 4.8706)
	),
	Pickup = car(
		"Pickup",
		"Lilac",
		{ name = "Body", box = box(-3.529, 0.706, -6.941, 3.529, 5.75, 6.941), tris = 588 },
		{ name = "Headlights", box = box(-2.588, 2.353, 6.235, 2.588, 3.333, 6.471), tris = 8 },
		{ name = "Paint", box = box(-3.529, 2.353, -6.706, 3.529, 6.118, 6.471), tris = 158 },
		wheels(1.176, 2.824, 2.824, 2.788, 5.541, -4.835, -2.082),
		Vector3.new(0, 1.5529, 6.3412),
		Vector3.new(0, 3.7929, 5.3412)
	),
}

const LONG_CAR: VehicleSpec = (function(): VehicleSpec
	local parts: { PartSpec } = {
		{ name = "Body", box = box(-3.55, 0.5647, -9.75, 3.55, 4, 9.75), tris = 686 },
		{ name = "Glass", box = box(-2.6033, 2.7751, -5.0463, 2.6033, 3.8087, 4.988), tris = 10 },
		{ name = "Headlights", box = box(-2.6033, 2.2588, 7.5304, 2.6033, 2.5709, 8.6402), tris = 8 },
	}
	for _, w in wheels(1.5224, 2.84, 2.2588, 4.3011, 6.5033, -5.9484, -3.7462) do
		table.insert(parts, w)
	end
	return {
		asset = "AST-065_LongCar",
		parts = parts,
		atts = {
			Hit_Front = Vector3.new(0, 1.2424, 9.15),
			Light_HighL = Vector3.new(2.0827, 2.3996, 8.6402),
			Light_HighR = Vector3.new(-2.0827, 2.3996, 8.6402),
			Light_HighL_End = Vector3.new(2.0827, 0.1, 8.6402 + HIGH_BEAM_RANGE),
			Light_HighR_End = Vector3.new(-2.0827, 0.1, 8.6402 + HIGH_BEAM_RANGE),
		},
		budget = LONG_BUDGET,
	}
end)()

-- HTTP ------------------------------------------------------------------------------------------------------------

local function httpGet(url: string): string
	local was = HttpService.HttpEnabled
	HttpService.HttpEnabled = true
	local ok, res = pcall(function()
		return HttpService:GetAsync(url, true)
	end)
	HttpService.HttpEnabled = was
	if not ok then
		error("GET " .. url .. " failed: " .. tostring(res))
	end
	return res :: string
end

local function join(base: string, path: string): string
	if string.sub(base, -1) ~= "/" then
		base ..= "/"
	end
	return base .. path
end

-- Asset loading (InsertService, cached like build_items.luau) -----------------------------------------------------

local function cacheFolder(): Folder
	local f = ServerStorage:FindFirstChild(CACHE_NAME)
	if not f then
		f = Instance.new("Folder")
		f.Name = CACHE_NAME
		f.Parent = ServerStorage
	end
	return f :: Folder
end

local function template(name: string, ids: Ids, reload: boolean?): Instance
	local id = ids[name]
	if id == nil then
		error("no asset id for " .. name .. " in _asset_ids.json")
	end
	local cache = cacheFolder()
	local hit = cache:FindFirstChild(name)
	if hit and (reload or hit:GetAttribute("AssetId") ~= tostring(id)) then
		hit:Destroy()
		hit = nil
	end
	if hit then
		return hit
	end
	local num = tonumber(id)
	if not num then
		error("bad asset id for " .. name .. ": " .. tostring(id))
	end
	local ok, res = pcall(function()
		return InsertService:LoadAsset(num)
	end)
	if not ok then
		error("LoadAsset failed for " .. name .. ": " .. tostring(res))
	end
	local container = res :: Model
	local model = container:GetChildren()[1]
	if not model then
		container:Destroy()
		error("empty asset " .. name)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("PackageLink") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	model.Name = name
	model:SetAttribute("AssetId", tostring(id))
	model.Parent = cache
	container:Destroy()
	return model
end

local function near(a: Vector3, b: Vector3, tol: number): boolean
	return math.abs(a.X - b.X) <= tol and math.abs(a.Y - b.Y) <= tol and math.abs(a.Z - b.Z) <= tol
end

local function fmt(v: Vector3): string
	return string.format("(%.3f, %.3f, %.3f)", v.X, v.Y, v.Z)
end

-- Every BasePart of a fresh clone, by name (flattened, unparented); the caller destroys what it does not keep.
local function partsOf(name: string, ids: Ids, reload: boolean?): { [string]: BasePart }
	local clone = template(name, ids, reload):Clone()
	local byName: { [string]: BasePart } = {}
	for _, d in clone:GetDescendants() do
		if d:IsA("BasePart") then
			byName[d.Name] = d
		end
	end
	for _, p in byName do
		p.Parent = nil
		for _, d in p:GetDescendants() do
			if d:IsA("PackageLink") or d:IsA("JointInstance") or d:IsA("WeldConstraint") then
				d:Destroy()
			end
		end
	end
	clone:Destroy()
	return byName
end

local function kitPart(p: BasePart, asset: string, tris: number, parent: Instance)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p:SetAttribute("Asset", asset)
	p:SetAttribute("Tris", tris)
	p.Parent = parent
end

local function attach(part: BasePart, name: string, cf: CFrame): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = part.CFrame:ToObjectSpace(cf)
	a.Parent = part
	return a
end

local function sumTris(spec: VehicleSpec): number
	local n = 0
	for _, s in spec.parts do
		n += s.tris
	end
	return n
end

-- Builders --------------------------------------------------------------------------------------------------------

-- Model of `spec` with the asset origin at world identity (front +Z) and the pivot turned to face the front.
function Vehicles.buildVehicle(name: string, spec: VehicleSpec, ids: Ids, reload: boolean?, problems: { string }): Model?
	local byName = partsOf(spec.asset, ids, reload)
	local root = byName[spec.parts[1].name]
	if not root then
		table.insert(problems, spec.asset .. ": missing part " .. spec.parts[1].name)
		for _, p in byName do
			p:Destroy()
		end
		return nil
	end
	-- asset origin from the root part (imported MeshParts sit at their bounding-box centre)
	local origin = root.CFrame * CFrame.new(-centre(spec.parts[1].box))
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("Asset", spec.asset)
	m:SetAttribute("Tris", sumTris(spec))
	local keep: { [BasePart]: boolean } = {}
	for _, s in spec.parts do
		local p = byName[s.name]
		if not p then
			table.insert(problems, spec.asset .. ": missing part " .. s.name)
			continue
		end
		keep[p] = true
		local size = s.box.max - s.box.min
		if not near(p.Size, size, SIZE_TOL) then
			table.insert(problems, string.format("%s.%s: size %s, .blend %s", spec.asset, s.name, fmt(p.Size), fmt(size)))
		end
		local at = origin:PointToObjectSpace(p.Position)
		if not near(at, centre(s.box), SIZE_TOL) then
			table.insert(problems, string.format("%s.%s: at %s, .blend %s", spec.asset, s.name, fmt(at), fmt(centre(s.box))))
		end
		p.CFrame = origin:ToObjectSpace(p.CFrame) -- asset origin -> world identity
		kitPart(p, spec.asset, s.tris, m)
	end
	for _, p in byName do
		if not keep[p] then
			table.insert(problems, "note: " .. spec.asset .. ": dropped extra part " .. p.Name)
			p:Destroy()
		end
	end
	m.PrimaryPart = root
	root.PivotOffset = root.CFrame:ToObjectSpace(FRONT)
	for attName, pos in spec.atts do
		attach(root, attName, CFrame.new(pos) * FRONT)
	end
	-- wheels: Axle at the centre (Axis = asset X), radius for the spin speed
	local radius = 0
	for _, w in WHEELS do
		local p = m:FindFirstChild(w) :: BasePart?
		if p then
			attach(p, "Axle", CFrame.new(p.Position))
			radius = math.max(radius, p.Size.Y / 2)
		end
	end
	m:SetAttribute("WheelRadius", math.round(radius * 1000) / 1000)
	local _, size = m:GetBoundingBox()
	m:SetAttribute("Size", Vector3.new(math.round(size.X * 100) / 100, math.round(size.Y * 100) / 100, math.round(size.Z * 100) / 100))
	return m
end

-- Paints/<Color> inside a car: the 5 Paint_<Color> parts of the _Paints asset, aligned on the main Paint part.
-- Without the _Paints id the folder keeps only the default colour (the main asset's Paint) and a problem is reported.
local function buildPaints(m: Model, spec: VehicleSpec, ids: Ids, reload: boolean?, problems: { string })
	local main = m:FindFirstChild("Paint") :: BasePart?
	local folder = Instance.new("Folder")
	folder.Name = "Paints"
	folder.Parent = m
	if not main then
		return
	end
	local paintSpec = spec.parts[3]
	local paintsAsset = spec.paints :: string
	local byName: { [string]: BasePart }? = nil
	if ids[paintsAsset] ~= nil then
		local ok, res = pcall(partsOf, paintsAsset, ids, reload)
		if ok then
			byName = res
		else
			table.insert(problems, tostring(res))
		end
	else
		table.insert(problems, "note: " .. paintsAsset .. " has no id: only the default paint was built")
	end
	if byName then
		local size = paintSpec.box.max - paintSpec.box.min
		for _, color in PAINTS do
			local p = byName["Paint_" .. color]
			if not p then
				table.insert(problems, paintsAsset .. ": missing part Paint_" .. color)
				continue
			end
			byName["Paint_" .. color] = nil
			if not near(p.Size, size, SIZE_TOL) then
				table.insert(problems, string.format("%s.Paint_%s: size %s, .blend %s", paintsAsset, color, fmt(p.Size), fmt(size)))
			end
			p.CFrame = main.CFrame
			p.Name = color
			kitPart(p, paintsAsset, paintSpec.tris, folder)
		end
		for _, p in byName do
			table.insert(problems, "note: " .. paintsAsset .. ": dropped extra part " .. p.Name)
			p:Destroy()
		end
	end
	if not folder:FindFirstChild(spec.defaultPaint :: string) then
		main.Name = spec.defaultPaint :: string
		main.Parent = folder
	else
		main:Destroy()
	end
	m:SetAttribute("DefaultPaint", spec.defaultPaint)
end

local function highBeam(att: Attachment)
	local l = Instance.new("SpotLight")
	l.Name = "HighBeam"
	l.Face = Enum.NormalId.Front -- attachment LookVector = front of the car
	l.Color = HIGH_BEAM_COLOR
	l.Range = HIGH_BEAM_RANGE
	l.Angle = HIGH_BEAM_ANGLE
	l.Brightness = HIGH_BEAM_BRIGHTNESS
	l.Shadows = false
	l.Enabled = false -- turned on by the ANM-008 effect (HighBeam / Blink2x states)
	l.Parent = att
end

function Vehicles.build(ids: Ids, reload: boolean?, problems: { string }): Folder
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		assets = Instance.new("Folder")
		assets.Name = "Assets"
		assets.Parent = ReplicatedStorage
		table.insert(problems, "note: ReplicatedStorage.Assets created here; KitVersion is written by build_kits.luau")
	end
	local old = (assets :: Instance):FindFirstChild("Vehicles")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Vehicles"
	root:SetAttribute("KitVersion", VEHICLES_VERSION)
	root:SetAttribute("Shapes", table.concat(SHAPES, ","))
	root:SetAttribute("Paints", table.concat(PAINTS, ","))
	local cars = Instance.new("Folder")
	cars.Name = "Cars"
	cars.Parent = root

	local function guarded(label: string, fn: () -> ())
		local ok, err = pcall(fn)
		if not ok then
			table.insert(problems, label .. ": " .. tostring(err))
		end
	end
	for _, shape in SHAPES do
		guarded("Cars." .. shape, function()
			local spec = CARS[shape]
			local m = Vehicles.buildVehicle(shape, spec, ids, reload, problems)
			if not m then
				return
			end
			m:SetAttribute("Shape", shape)
			buildPaints(m, spec, ids, reload, problems)
			m.Parent = cars
		end)
	end
	guarded("LongCar", function()
		local m = Vehicles.buildVehicle("LongCar", LONG_CAR, ids, reload, problems)
		if not m then
			return
		end
		local body = m.PrimaryPart :: BasePart
		for _, n in { "Light_HighL", "Light_HighR" } do
			local a = body:FindFirstChild(n) :: Attachment?
			if a then
				highBeam(a)
			end
		end
		local glass = m:FindFirstChild("Glass") :: BasePart?
		if glass then
			glass.Transparency = LONG_GLASS_TRANSPARENCY
			glass.CastShadow = false
		end
		m.Parent = root
	end)
	root.Parent = assets
	return root
end

-- Check (TASK-099 acceptance) -------------------------------------------------------------------------------------

local function checkVehicle(label: string, m: Instance?, spec: VehicleSpec, problems: { string })
	if not (m and m:IsA("Model") and m.PrimaryPart) then
		table.insert(problems, label .. " missing (or no PrimaryPart)")
		return
	end
	local model = m :: Model
	for _, s in spec.parts do
		if s.name ~= "Paint" and not model:FindFirstChild(s.name) then
			table.insert(problems, label .. "." .. s.name .. " missing")
		end
	end
	local body = model.PrimaryPart :: BasePart
	for attName in spec.atts do
		if not body:FindFirstChild(attName) then
			table.insert(problems, label .. ".Body." .. attName .. " missing")
		end
	end
	local pivot = model:GetPivot()
	-- front: the Headlights sit ahead of the pivot along LookVector (-Z in pivot space)
	local hl = model:FindFirstChild("Headlights") :: BasePart?
	if hl and pivot:PointToObjectSpace(hl.Position).Z > -1 then
		table.insert(problems, label .. ": Headlights not at the front (pivot LookVector)")
	end
	for _, w in WHEELS do
		local p = model:FindFirstChild(w) :: BasePart?
		if not p then
			continue
		end
		if not p:FindFirstChild("Axle") then
			table.insert(problems, label .. "." .. w .. ".Axle missing")
		end
		local bottom = pivot:PointToObjectSpace(p.Position).Y - p.Size.Y / 2
		if math.abs(bottom) > SIZE_TOL then
			table.insert(problems, string.format("%s.%s: bottom at %.3f (pivot Y 0 expected)", label, w, bottom))
		end
	end
	local tris = model:GetAttribute("Tris") :: number? or 0
	if tris > spec.budget then
		table.insert(problems, string.format("%s: %d tris > %d", label, tris, spec.budget))
	end
end

function Vehicles.check(ids: Ids?): { string }
	local problems: { string } = {}
	if ids then
		local function need(asset: string)
			if ids[asset] == nil then
				table.insert(problems, "no id in _asset_ids.json: " .. asset)
			elseif tonumber(ids[asset]) == nil then
				table.insert(problems, "bad id in _asset_ids.json: " .. asset .. " = " .. tostring(ids[asset]))
			end
		end
		for _, shape in SHAPES do
			need(CARS[shape].asset)
			need(CARS[shape].paints :: string)
		end
		need(LONG_CAR.asset)
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local root = assets and assets:FindFirstChild("Vehicles")
	if not root then
		table.insert(problems, "ReplicatedStorage.Assets.Vehicles missing")
		return problems
	end
	if root:GetAttribute("KitVersion") ~= VEHICLES_VERSION then
		table.insert(problems, "Assets.Vehicles.KitVersion ~= " .. VEHICLES_VERSION)
	end
	local cars = root:FindFirstChild("Cars")
	for _, shape in SHAPES do
		local m = cars and cars:FindFirstChild(shape)
		checkVehicle("Cars." .. shape, m, CARS[shape], problems)
		if not m then
			continue
		end
		local paints = m:FindFirstChild("Paints")
		if m:FindFirstChild("Paint") then
			table.insert(problems, "Cars." .. shape .. ": a Paint part outside Paints (the consumer adds it)")
		end
		for _, color in PAINTS do
			local p = paints and paints:FindFirstChild(color)
			if not (p and p:IsA("BasePart")) then
				table.insert(problems, "Cars." .. shape .. ".Paints." .. color .. " missing")
			end
		end
	end
	local long = root:FindFirstChild("LongCar")
	checkVehicle("LongCar", long, LONG_CAR, problems)
	local longBody = if long and long:IsA("Model") then long.PrimaryPart else nil
	if longBody then
		for _, n in { "Light_HighL", "Light_HighR" } do
			local a = longBody:FindFirstChild(n)
			local l = a and a:FindFirstChild("HighBeam")
			if not (l and l:IsA("SpotLight") and not l.Shadows) then
				table.insert(problems, "LongCar.Body." .. n .. ".HighBeam (SpotLight, no shadow) missing")
			end
		end
	end
	for _, d in root:GetDescendants() do
		if d:IsA("PackageLink") then
			table.insert(problems, "PackageLink left in " .. d:GetFullName())
		elseif d:IsA("BasePart") then
			if d:GetAttribute("Asset") == nil then
				table.insert(problems, "no Asset attribute: " .. d:GetFullName())
			end
			if d.CanCollide or d.CanQuery or d.CanTouch or not d.Anchored then
				table.insert(problems, "collision/query/touch on or not anchored: " .. d:GetFullName())
			end
		end
	end
	return problems
end

-- Demo: workspace.VehiclesDemo = every shape x every paint (row per shape) + the long car with the high beam on ---

function Vehicles.clearDemo()
	local old = workspace:FindFirstChild(DEMO_NAME)
	if old then
		old:Destroy()
	end
end

function Vehicles.demo(): { string }
	Vehicles.clearDemo()
	local problems: { string } = {}
	local root: any = (ReplicatedStorage :: any).Assets:FindFirstChild("Vehicles")
	if not root then
		return { "demo: Assets.Vehicles missing" }
	end
	local demo = Instance.new("Model")
	demo.Name = DEMO_NAME
	-- cars face the default camera (+Z of the world)
	const origin = CFrame.new(-40, 0, -160) * CFrame.Angles(0, math.pi, 0)
	for row, shape in SHAPES do
		local tpl = root.Cars:FindFirstChild(shape)
		if not tpl then
			table.insert(problems, "demo: Cars." .. shape .. " missing")
			continue
		end
		for col, color in PAINTS do
			local m = tpl:Clone()
			local paint = m.Paints:FindFirstChild(color)
			if paint then
				paint.Name = "Paint"
				paint.Parent = m
			else
				table.insert(problems, "note: demo " .. shape .. " " .. color .. ": paint missing")
			end
			m.Paints:Destroy()
			m.Name = shape .. "_" .. color
			m:PivotTo(origin * CFrame.new((col - 1) * 10, 0, (row - 1) * 18))
			m.Parent = demo
		end
	end
	local long = root:FindFirstChild("LongCar")
	if long then
		local m = long:Clone()
		for _, d in m:GetDescendants() do
			if d:IsA("SpotLight") then
				d.Enabled = true
			end
		end
		m:PivotTo(origin * CFrame.new(60, 0, 27))
		m.Parent = demo
	end
	demo.Parent = workspace
	return problems
end

-- Entry point -----------------------------------------------------------------------------------------------------

function Vehicles.run(opts: Options): string
	local ids: Ids? = opts.ids
	if not ids and opts.baseUrl then
		ids = HttpService:JSONDecode(httpGet(join(opts.baseUrl, "Assets/import/_asset_ids.json")))
	end
	assert(ids, "asset ids missing: pass opts.ids or opts.baseUrl")
	local problems: { string } = {}
	local root: any = Vehicles.build(ids, opts.reload, problems)
	for _, p in Vehicles.check(ids) do
		table.insert(problems, p)
	end
	if opts.demo then
		for _, p in Vehicles.demo() do
			table.insert(problems, p)
		end
	end
	local errors = 0
	for _, p in problems do
		if string.sub(p, 1, 6) ~= "note: " then
			errors += 1
		end
	end
	local msg = string.format(
		"vehicles kit v%d: %d cars x %d paints, long car %s; %d problem(s)",
		VEHICLES_VERSION,
		#root.Cars:GetChildren(),
		#PAINTS,
		if root:FindFirstChild("LongCar") then "ok" else "MISSING",
		errors
	)
	if #problems > 0 then
		msg ..= "\n" .. table.concat(problems, "\n")
	end
	return msg
end

return Vehicles
