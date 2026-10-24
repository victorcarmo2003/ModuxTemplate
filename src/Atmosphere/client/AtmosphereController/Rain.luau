--!strict
-- Cartoon rain bound to the camera (TASK-275, ATM-4 / ATM-5; owner 2026-10-21: "gotas com cara de cartoon", then "troca"
-- the 3D drops for a ParticleEmitter). Local only (parts under the CurrentCamera, no collision, no query).
--   * Drops   a RainCells x RainCells grid of RainCell-stud cells follows the camera, snapped to the grid so it does
--             not swim. Each world cell casts five rays down (centre + corners; cached until the camera climbs or
--             CACHE_LIFE s pass): any surface above the camera (a roof, the trailer, an awning) turns the cell off, so a
--             cell half over the trailer never rains through its roof (owner 2026-10-21: "tá chovendo dentro do
--             trailer"); else drops fall from the cell top and die on the centre's surface. Texture T_VFX_RainDropCartoon (teardrop with outline and
--             shine), always upright (FacingCameraWorldUp) so it reads as a cartoon drop.
--   * Splash  an emitter on each open cell's ground pops T_VFX_RainSplashCartoon (a crown with droplets) that grows and
--             fades over SplashLife.
--   * Drips   the open service / drive-thru window flaps drip from their free edge (Shutter_Panel* parts of a
--             `Vehicle` model whose `Shutter` attribute, written by VehicleService, is not true): an emitter along the
--             edge drops swelling drips with gravity, and a splash emitter under it. Edges under a roof and farther
--             than DripRange do not drip. Rate = Settings.Drips per stud of edge per second.
-- Rates scale with the atmosphere blend (Step(alpha)).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)

type Settings = Content.AtmosphereRain
type Rules = typeof(Content.Atmospheres.Rules)

const ROOF_MARGIN = 1.5 -- studs: a surface this far above the camera counts as a roof
const CACHE_LIFE = 3 -- s a world cell's rays stay valid (doors, shutters and cars move)
const CACHE_CLIMB = 4 -- studs the camera may climb or drop before every cell is cast again
const AREA = 100 -- studs^2 the Rate / Splash densities are given for
const FALL_EXTRA = 60 -- studs below the camera the ray still looks for ground
const GRAVITY = 70 -- studs/s^2 of a drip
const DRIP_SLOTS = 4 -- window flaps that can drip at once
const DRIP_SIZE = 0.75 -- drip size against a rain drop
const DRIP_SPLASH = 0.6 -- drip splash size against a rain splash
const DRIP_REFRESH = 0.5 -- s between window flap scans
const DRIP_ROOF = 40 -- studs above a flap edge that count as a roof
const VEHICLE_TAG = "Vehicle"
const SHUTTER_ATTRIBUTE = "Shutter" -- true = closed (VehicleService)
const HINGE_NAME = "Shutter_Hinge"
const PANEL_NAME = "Shutter_Panel"
const PANEL_PREFIX = "Shutter_Panel_"

type Cell = {
	Drops: Part,
	Splash: Part,
	DropEmitter: ParticleEmitter,
	SplashEmitter: ParticleEmitter,
	Open: boolean,
	Ground: boolean, -- the ray hit something (a splash has a floor)
}

-- Rays of one world cell: highest surface under the five rays, the centre's surface (nil = no hit)
type Probe = { Roof: number, Floor: number? }

type Slot = {
	Edge: Part,
	Floor: Part,
	DripEmitter: ParticleEmitter,
	SplashEmitter: ParticleEmitter,
	Length: number, -- studs of edge (0 = slot unused)
}

export type Rain = {
	Settings: Settings,
	Rules: Rules,
	Folder: Folder,
	Cells: { Cell },
	Slots: { Slot },
	Panels: { [Instance]: { BasePart } },
	Probes: { [string]: Probe },
	ProbeTop: number, -- Y the cached rays were cast from
	ProbeAt: number, -- os.clock of the cache
	Params: RaycastParams,
	NextCheck: number,
	NextEdges: number,
	Alpha: number,
	Check: (self: Rain) -> (),
	Scan: (self: Rain) -> (),
	Rates: (self: Rain) -> (),
	Step: (self: Rain, alpha: number) -> (),
	Destroy: (self: Rain) -> (),
}

local function holder(name: string, size: Vector3, parent: Instance): Part
	const part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = size
	part.Parent = parent
	return part
end

local function dropEmitter(settings: Settings, rules: Rules, parent: Part, size: number): ParticleEmitter
	const emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Drops"
	emitter.Texture = rules.DropTexture
	emitter.Color = ColorSequence.new(settings.Color)
	emitter.LightEmission = 0.2
	emitter.LightInfluence = 0.5
	-- upright in the world whatever the camera does: the teardrop tip stays up
	emitter.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Speed = NumberRange.new(settings.Speed[1], settings.Speed[2])
	emitter.Acceleration = settings.Wind
	emitter.Size = NumberSequence.new(size)
	emitter.Transparency = NumberSequence.new(settings.Transparency)
	emitter.Rate = 0
	emitter.Parent = parent
	return emitter
end

local function splashEmitter(settings: Settings, rules: Rules, parent: Part, scale: number): ParticleEmitter
	const emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Splash"
	emitter.Texture = rules.SplashTexture
	emitter.Color = ColorSequence.new(settings.Color)
	emitter.LightEmission = 0.2
	emitter.LightInfluence = 0.6
	emitter.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Speed = NumberRange.new(0)
	emitter.Lifetime = NumberRange.new(rules.SplashLife)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, rules.SplashSize * scale * 0.3),
		NumberSequenceKeypoint.new(0.4, rules.SplashSize * scale),
		NumberSequenceKeypoint.new(1, rules.SplashSize * scale * 1.1),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, settings.Transparency),
		NumberSequenceKeypoint.new(0.5, settings.Transparency),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Rate = 0
	emitter.Parent = parent
	return emitter
end

local function isPanel(part: Instance): boolean
	return part:IsA("BasePart")
		and (part.Name == PANEL_NAME or string.sub(part.Name, 1, #PANEL_PREFIX) == PANEL_PREFIX)
		and part:FindFirstChild(HINGE_NAME) ~= nil
end

-- Free edge of a flap: of the four edges along the hinge axis, the lowest, nudged towards the one far from the hinge.
local function freeEdge(panel: BasePart): (Vector3?, Vector3?)
	const hinge = panel:FindFirstChild(HINGE_NAME)
	if hinge == nil or not hinge:IsA("Attachment") then
		return nil, nil
	end
	const cf = panel.CFrame
	const half = panel.Size / 2
	const axes = { cf.XVector, cf.YVector, cf.ZVector }
	const halves = { half.X, half.Y, half.Z }
	const hingeAxis = hinge.WorldCFrame.XVector
	local along = 1
	for index = 2, 3 do
		if math.abs(axes[index]:Dot(hingeAxis)) > math.abs(axes[along]:Dot(hingeAxis)) then
			along = index
		end
	end
	const others = { 1, 2, 3 }
	table.remove(others, along)
	const a, b = others[1], others[2]
	const hingeAt = hinge.WorldPosition
	local best: Vector3? = nil
	local bestScore = math.huge
	for _, sa in { -1, 1 } do
		for _, sb in { -1, 1 } do
			const mid = cf.Position + axes[a] * halves[a] * sa + axes[b] * halves[b] * sb
			const score = mid.Y - 0.25 * (mid - hingeAt).Magnitude
			if score < bestScore then
				bestScore = score
				best = mid
			end
		end
	end
	const mid = best :: Vector3
	const span = axes[along] * halves[along]
	return mid - span, mid + span
end

const Rain = {}
Rain.__index = Rain

function Rain.new(settings: Settings, rules: Rules): Rain
	const camera = Workspace.CurrentCamera
	const folder = Instance.new("Folder")
	folder.Name = "AtmosphereRain"
	folder.Parent = camera or Workspace

	const cells: { Cell } = {}
	const side = rules.RainCell
	for _ = 1, rules.RainCells * rules.RainCells do
		const drops = holder("Drops", Vector3.new(side, 0.2, side), folder)
		const splash = holder("Splash", Vector3.new(side, 0.1, side), folder)
		table.insert(cells, {
			Drops = drops,
			Splash = splash,
			DropEmitter = dropEmitter(settings, rules, drops, settings.Size),
			SplashEmitter = splashEmitter(settings, rules, splash, 1),
			Open = false,
			Ground = false,
		})
	end

	const slots: { Slot } = {}
	for _ = 1, DRIP_SLOTS do
		const edge = holder("DripEdge", Vector3.new(1, 0.1, 0.1), folder)
		const floor = holder("DripFloor", Vector3.new(1, 0.1, 0.4), folder)
		const drip = dropEmitter(settings, rules, edge, settings.Size * DRIP_SIZE)
		-- a drip swells on the edge, then gravity takes it
		drip.Speed = NumberRange.new(0)
		drip.Acceleration = Vector3.new(0, -GRAVITY, 0)
		drip.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(0.3, settings.Size * DRIP_SIZE),
			NumberSequenceKeypoint.new(1, settings.Size * DRIP_SIZE),
		})
		table.insert(slots, {
			Edge = edge,
			Floor = floor,
			DripEmitter = drip,
			SplashEmitter = splashEmitter(settings, rules, floor, DRIP_SPLASH),
			Length = 0,
		})
	end

	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = false

	return setmetatable({
		Settings = settings,
		Rules = rules,
		Folder = folder,
		Cells = cells,
		Slots = slots,
		Panels = setmetatable({}, { __mode = "k" }),
		Probes = {},
		ProbeTop = 0,
		ProbeAt = 0,
		Params = params,
		NextCheck = 0,
		NextEdges = 0,
		Alpha = 0,
	}, Rain) :: any
end

-- Re-centres the grid on the camera and finds the roof / ground of every cell.
function Rain.Check(self: Rain)
	const camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	const settings = self.Settings
	const rules = self.Rules
	const side = rules.RainCell
	const half = (rules.RainCells - 1) / 2
	const eye = camera.CFrame.Position
	const originX = math.floor(eye.X / side + 0.5) * side
	const originZ = math.floor(eye.Z / side + 0.5) * side
	const top = eye.Y + rules.RainHeight

	const ignore: { Instance } = { self.Folder }
	const character = Players.LocalPlayer.Character
	if character then
		table.insert(ignore, character)
	end
	self.Params.FilterDescendantsInstances = ignore

	const now = os.clock()
	if now - self.ProbeAt > CACHE_LIFE or math.abs(top - self.ProbeTop) > CACHE_CLIMB then
		table.clear(self.Probes)
		self.ProbeAt = now
		self.ProbeTop = top
	end
	const castTop = self.ProbeTop
	const reach = Vector3.new(0, -(castTop - eye.Y + FALL_EXTRA), 0)
	const inset = side / 2 - 0.25

	const fastest = settings.Speed[2]
	const slowest = settings.Speed[1]
	-- the splash sprite stands on the ground: its centre a bit above the hit
	const lift = rules.SplashSize * 0.35
	local index = 0
	for i = -half, half do
		for j = -half, half do
			index += 1
			const cell = self.Cells[index]
			const x = originX + i * side
			const z = originZ + j * side
			const key = `{x}:{z}`
			local probe = self.Probes[key]
			if probe == nil then
				const centre = Workspace:Raycast(Vector3.new(x, castTop, z), reach, self.Params)
				local roof = if centre then centre.Position.Y else -math.huge
				for _, corner in { Vector2.new(-1, -1), Vector2.new(-1, 1), Vector2.new(1, -1), Vector2.new(1, 1) } do
					const hit = Workspace:Raycast(Vector3.new(x + corner.X * inset, castTop, z + corner.Y * inset), reach, self.Params)
					if hit then
						roof = math.max(roof, hit.Position.Y)
					end
				end
				probe = { Roof = roof, Floor = if centre then centre.Position.Y else nil }
				self.Probes[key] = probe
			end
			const floor = (probe :: Probe).Floor
			const groundY = floor or eye.Y - FALL_EXTRA
			const open = (probe :: Probe).Roof <= eye.Y + ROOF_MARGIN
			cell.Open = open
			cell.Ground = floor ~= nil
			if open then
				const fall = top - groundY
				cell.Drops.CFrame = CFrame.new(x, top, z)
				cell.DropEmitter.Lifetime = NumberRange.new(fall / fastest, fall / slowest)
				cell.Splash.CFrame = CFrame.new(x, groundY + lift, z)
			end
		end
	end
end

-- Free edges of the open window flaps near the camera, not under a roof, one per slot.
function Rain.Scan(self: Rain)
	const camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	const eye = camera.CFrame.Position
	const range = self.Rules.DripRange
	const lift = self.Rules.SplashSize * DRIP_SPLASH * 0.35
	local used = 0
	for _, model in CollectionService:GetTagged(VEHICLE_TAG) do
		if model:GetAttribute(SHUTTER_ATTRIBUTE) == true then
			continue
		end
		local panels = self.Panels[model]
		if panels == nil then
			const found: { BasePart } = {}
			for _, descendant in model:GetDescendants() do
				if isPanel(descendant) then
					table.insert(found, descendant :: BasePart)
				end
			end
			panels = found
			self.Panels[model] = found
		end
		for _, panel in panels :: { BasePart } do
			if used >= #self.Slots or panel.Parent == nil then
				continue
			end
			const from, to = freeEdge(panel)
			if from == nil or to == nil then
				continue
			end
			const mid = (from + to) / 2
			if (mid - eye).Magnitude > range then
				continue
			end
			const ignore = table.clone(self.Params.FilterDescendantsInstances)
			table.insert(ignore, panel)
			const params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = ignore
			if Workspace:Raycast(mid + Vector3.new(0, 0.3, 0), Vector3.new(0, DRIP_ROOF, 0), params) then
				continue
			end
			const floor = Workspace:Raycast(mid - Vector3.new(0, 0.2, 0), Vector3.new(0, -FALL_EXTRA, 0), params)
			const groundY = if floor then floor.Position.Y else mid.Y - FALL_EXTRA
			used += 1
			const slot = self.Slots[used]
			const length = (to - from).Magnitude
			const flat = CFrame.lookAt(mid, mid + Vector3.new(to.X - from.X, 0, to.Z - from.Z))
			slot.Length = length
			slot.Edge.Size = Vector3.new(0.1, 0.1, length)
			slot.Edge.CFrame = flat - Vector3.new(0, 0.15, 0)
			slot.Floor.Size = Vector3.new(0.4, 0.1, length)
			slot.Floor.CFrame = flat - Vector3.new(0, mid.Y - groundY - lift, 0)
			slot.DripEmitter.Lifetime = NumberRange.new(math.sqrt(2 * math.max(mid.Y - groundY, 0.5) / GRAVITY))
			slot.SplashEmitter.Enabled = floor ~= nil
		end
	end
	for index = used + 1, #self.Slots do
		self.Slots[index].Length = 0
	end
end

function Rain.Rates(self: Rain)
	const settings = self.Settings
	const alpha = self.Alpha
	const area = self.Rules.RainCell * self.Rules.RainCell / AREA
	for _, cell in self.Cells do
		cell.DropEmitter.Rate = if cell.Open then settings.Rate * area * alpha else 0
		cell.SplashEmitter.Rate = if cell.Open and cell.Ground then settings.Splash * area * alpha else 0
	end
	for _, slot in self.Slots do
		const rate = settings.Drips * slot.Length * alpha
		slot.DripEmitter.Rate = rate
		slot.SplashEmitter.Rate = rate
	end
end

function Rain.Step(self: Rain, alpha: number)
	const now = os.clock()
	local dirty = alpha ~= self.Alpha
	self.Alpha = alpha
	if now >= self.NextCheck then
		self.NextCheck = now + self.Rules.RoofCheck
		self:Check()
		dirty = true
	end
	if now >= self.NextEdges then
		self.NextEdges = now + DRIP_REFRESH
		self:Scan()
		dirty = true
	end
	if dirty then
		self:Rates()
	end
end

function Rain.Destroy(self: Rain)
	self.Folder:Destroy()
	table.clear(self.Cells)
	table.clear(self.Slots)
end

return Rain
