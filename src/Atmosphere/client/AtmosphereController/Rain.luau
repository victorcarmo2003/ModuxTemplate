--!strict
-- Cartoon rain bound to the camera (TASK-275, ATM-4 / ATM-5; owner 2026-10-21: "gotas com cara de cartoon"). Local
-- only (parts under the CurrentCamera, no collision, no query), moved with one BulkMoveTo per frame.
--   * Drops   a pool of Settings.Drops chunky light-blue stretched balls, tilted along their fall (Wind). Each one is
--             born in a disc of RainRadius around the camera, pushed RainLead along the look, RainHeight above the eye,
--             and casts one ray along its fall: the first surface above the camera (a roof, the trailer, an awning) =
--             that column is covered, the drop waits for the next frame; else it dies on the surface it hit.
--   * Splash  a landing drop pops one, Settings.Splash of the time: a flat disc that widens and fades + three tiny
--             droplets hopping out (pool of Rules.Splashes).
--   * Drips   the open service / drive-thru window flaps drip from their free edge (Shutter_Panel* parts of a
--             `Vehicle` model whose `Shutter` attribute, written by VehicleService, is not true): a drop swells on the
--             edge for DripGrow s, falls with gravity and splashes. Edges under a roof and farther than DripRange do
--             not drip. Rate = Settings.Drips per stud of edge per second.
-- The amount scales with the atmosphere blend (Step(alpha)).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)

type Settings = Content.AtmosphereRain
type Rules = typeof(Content.Atmospheres.Rules)

const ROOF_MARGIN = 1.5 -- studs: a surface this far above the camera covers the column
const FALL_EXTRA = 40 -- studs below the camera the ray still looks for ground
const SPAWN_BUDGET = 40 -- drop births (raycasts) per frame
const SPLASH_BASE = 0.35 -- transparency of a fresh splash
const SPLASH_BIT = 0.18 -- studs, splash droplet
const SPLASH_HOP = 7 -- studs/s up of a splash droplet
const SPLASH_OUT = 3.2 -- studs/s out of a splash droplet
const GRAVITY = 70 -- studs/s^2 of splash droplets and drips
const DRIP_POOL = 24
const DRIP_SCALE = 0.8 -- drip size against a rain drop
const DRIP_REFRESH = 0.5 -- s between window flap scans
const DRIP_ROOF = 40 -- studs above a flap edge that count as a roof
const VEHICLE_TAG = "Vehicle"
const SHUTTER_ATTRIBUTE = "Shutter" -- true = closed (VehicleService)
const HINGE_NAME = "Shutter_Hinge"
const PANEL_NAME = "Shutter_Panel"
const PANEL_PREFIX = "Shutter_Panel_"
const PARKED = CFrame.new(0, -10000, 0)

type Drop = {
	Part: Part,
	Live: boolean,
	Position: Vector3,
	Velocity: Vector3,
	Land: number, -- s left until it hits
	Splash: boolean,
}

type Splash = {
	Disc: Part,
	DiscMesh: SpecialMesh,
	Bits: { Part },
	Live: boolean,
	At: Vector3,
	Born: number,
	Scale: number, -- 1 = a rain splash, smaller for a drip
}

type Drip = {
	Part: Part,
	Mesh: SpecialMesh,
	Live: boolean,
	Position: Vector3,
	Born: number,
	Speed: number, -- studs/s down (0 while it swells)
	Ground: number,
}

type Edge = { From: Vector3, To: Vector3, Length: number, Debt: number }

export type Rain = {
	Settings: Settings,
	Rules: Rules,
	Folder: Folder,
	Drops: { Drop },
	Splashes: { Splash },
	Drips: { Drip },
	Edges: { Edge },
	Panels: { [Instance]: { BasePart } },
	Tilt: CFrame,
	Params: RaycastParams,
	Last: number,
	NextEdges: number,
	Parts: { BasePart }, -- BulkMoveTo buffers, reused every frame
	Frames: { CFrame },
	Spawn: (self: Rain, drop: Drop, eye: CFrame, first: boolean) -> (),
	Pop: (self: Rain, at: Vector3, scale: number, now: number) -> (),
	Scan: (self: Rain, eye: Vector3) -> (),
	Step: (self: Rain, alpha: number) -> (),
	Destroy: (self: Rain) -> (),
}

local function ball(name: string, size: Vector3, color: Color3, transparency: number, parent: Instance): (Part, SpecialMesh)
	const part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Locked = true
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.Transparency = transparency
	part.Size = size
	part.CFrame = PARKED
	const mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	part.Parent = parent
	return part, mesh
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

	const dropSize = Vector3.new(settings.Width, settings.Length, settings.Width)
	const drops: { Drop } = {}
	for _ = 1, settings.Drops do
		const part = ball("Drop", dropSize, settings.Color, settings.Transparency, folder)
		table.insert(drops, {
			Part = part,
			Live = false,
			Position = Vector3.zero,
			Velocity = Vector3.zero,
			Land = 0,
			Splash = false,
		})
	end

	const splashes: { Splash } = {}
	for _ = 1, rules.Splashes do
		const disc, discMesh = ball("Splash", Vector3.new(1, 0.06, 1), settings.Color, 1, folder)
		const bits: { Part } = {}
		for _ = 1, 3 do
			table.insert(bits, (ball("SplashBit", Vector3.one * SPLASH_BIT, settings.Color, 1, folder)))
		end
		table.insert(splashes, {
			Disc = disc,
			DiscMesh = discMesh,
			Bits = bits,
			Live = false,
			At = Vector3.zero,
			Born = 0,
			Scale = 1,
		})
	end

	const drips: { Drip } = {}
	for _ = 1, DRIP_POOL do
		const part, mesh = ball("Drip", dropSize * DRIP_SCALE, settings.Color, settings.Transparency, folder)
		table.insert(drips, { Part = part, Mesh = mesh, Live = false, Position = Vector3.zero, Born = 0, Speed = 0, Ground = 0 })
	end

	-- every drop leans along the mean fall (the Y axis of the stretched ball points back up its path)
	const mean = (settings.Speed[1] + settings.Speed[2]) / 2
	const up = -Vector3.new(settings.Wind.X, -mean, settings.Wind.Z).Unit
	const right = up:Cross(Vector3.zAxis).Unit

	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = false

	return setmetatable({
		Settings = settings,
		Rules = rules,
		Folder = folder,
		Drops = drops,
		Splashes = splashes,
		Drips = drips,
		Edges = {},
		Panels = setmetatable({}, { __mode = "k" }),
		Tilt = CFrame.fromMatrix(Vector3.zero, right, up),
		Params = params,
		Last = os.clock(),
		NextEdges = 0,
		Parts = {},
		Frames = {},
	}, Rain) :: any
end

-- Births a drop above the camera; `first` spreads the first wave along the whole fall (no sheet at the top).
function Rain.Spawn(self: Rain, drop: Drop, eye: CFrame, first: boolean)
	const settings = self.Settings
	const rules = self.Rules
	const look = Vector3.new(eye.LookVector.X, 0, eye.LookVector.Z)
	const lead = if look.Magnitude > 1e-3 then look.Unit * rules.RainRadius * rules.RainLead else Vector3.zero
	const angle = math.random() * math.pi * 2
	const radius = rules.RainRadius * math.sqrt(math.random())
	const eyeY = eye.Position.Y
	const top = Vector3.new(
		eye.Position.X + lead.X + math.cos(angle) * radius,
		eyeY + rules.RainHeight,
		eye.Position.Z + lead.Z + math.sin(angle) * radius
	)
	const speed = settings.Speed[1] + math.random() * (settings.Speed[2] - settings.Speed[1])
	const velocity = Vector3.new(settings.Wind.X, -speed, settings.Wind.Z)
	const fall = (rules.RainHeight + FALL_EXTRA) * velocity.Magnitude / speed
	const hit = Workspace:Raycast(top, velocity.Unit * fall, self.Params)
	if hit and hit.Position.Y > eyeY + ROOF_MARGIN then
		return -- covered column: try again next frame
	end
	local time = (if hit then (hit.Position - top).Magnitude else fall) / velocity.Magnitude
	local start = top
	if first then
		const skip = math.random() * time
		start += velocity * skip
		time -= skip
	end
	drop.Live = true
	drop.Position = start
	drop.Velocity = velocity
	drop.Land = time
	drop.Splash = hit ~= nil and math.random() < settings.Splash
end

function Rain.Pop(self: Rain, at: Vector3, scale: number, now: number)
	for _, splash in self.Splashes do
		if not splash.Live then
			splash.Live = true
			splash.At = at
			splash.Born = now
			splash.Scale = scale
			splash.Disc.Transparency = SPLASH_BASE
			for _, bit in splash.Bits do
				bit.Transparency = SPLASH_BASE
			end
			return
		end
	end
end

-- Free edges of the open window flaps near the camera, not under a roof.
function Rain.Scan(self: Rain, eye: Vector3)
	const edges: { Edge } = {}
	const range = self.Rules.DripRange
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
			if panel.Parent == nil then
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
			table.insert(edges, { From = from, To = to, Length = (to - from).Magnitude, Debt = 0 })
		end
	end
	-- keep the drip debt of edges that did not move much (same flap, scan to scan)
	for _, edge in edges do
		for _, previous in self.Edges do
			if (previous.From - edge.From).Magnitude < 0.5 then
				edge.Debt = previous.Debt
				break
			end
		end
	end
	self.Edges = edges
end

function Rain.Step(self: Rain, alpha: number)
	const camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	const now = os.clock()
	const dt = math.min(now - self.Last, 0.1)
	self.Last = now
	const eye = camera.CFrame
	const settings = self.Settings
	const rules = self.Rules
	const parts = self.Parts
	const frames = self.Frames
	table.clear(parts)
	table.clear(frames)

	const ignore: { Instance } = { self.Folder }
	const character = Players.LocalPlayer.Character
	if character then
		table.insert(ignore, character)
	end
	self.Params.FilterDescendantsInstances = ignore

	-- drops
	const wanted = math.floor(#self.Drops * alpha + 0.5)
	local budget = SPAWN_BUDGET
	for index, drop in self.Drops do
		if drop.Live then
			drop.Land -= dt
			if drop.Land <= 0 then
				drop.Live = false
				if drop.Splash then
					self:Pop(drop.Position + drop.Velocity * (dt + drop.Land), 1, now)
				end
			else
				drop.Position += drop.Velocity * dt
			end
		end
		if not drop.Live and index <= wanted and budget > 0 then
			budget -= 1
			self:Spawn(drop, eye, drop.Land == 0) -- 0 = never fell yet
		end
		if drop.Live then
			table.insert(parts, drop.Part)
			table.insert(frames, self.Tilt + drop.Position)
		elseif drop.Part.CFrame ~= PARKED then
			table.insert(parts, drop.Part)
			table.insert(frames, PARKED)
		end
	end

	-- window drips
	if now >= self.NextEdges then
		self.NextEdges = now + DRIP_REFRESH
		self:Scan(eye.Position)
	end
	if settings.Drips > 0 then
		for _, edge in self.Edges do
			edge.Debt += settings.Drips * edge.Length * alpha * dt
			while edge.Debt >= 1 do
				edge.Debt -= 1
				for _, drip in self.Drips do
					if not drip.Live then
						const at = edge.From:Lerp(edge.To, math.random()) - Vector3.new(0, 0.1, 0)
						const hit = Workspace:Raycast(at, Vector3.new(0, -FALL_EXTRA, 0), self.Params)
						drip.Live = true
						drip.Position = at
						drip.Born = now
						drip.Speed = 0
						drip.Ground = if hit then hit.Position.Y else at.Y - FALL_EXTRA
						break
					end
				end
			end
		end
	end
	const half = settings.Length * DRIP_SCALE / 2
	for _, drip in self.Drips do
		if not drip.Live then
			if drip.Part.CFrame ~= PARKED then
				table.insert(parts, drip.Part)
				table.insert(frames, PARKED)
			end
			continue
		end
		const age = now - drip.Born
		if age < rules.DripGrow then
			-- swells on the edge, hanging from it
			const grow = 0.25 + 0.75 * (age / rules.DripGrow)
			drip.Mesh.Scale = Vector3.new(grow, grow, grow)
			table.insert(parts, drip.Part)
			table.insert(frames, CFrame.new(drip.Position - Vector3.new(0, half * grow, 0)))
			continue
		end
		drip.Mesh.Scale = Vector3.one
		drip.Speed += GRAVITY * dt
		drip.Position -= Vector3.new(0, drip.Speed * dt, 0)
		if drip.Position.Y - half <= drip.Ground then
			drip.Live = false
			self:Pop(Vector3.new(drip.Position.X, drip.Ground, drip.Position.Z), 0.6, now)
			table.insert(parts, drip.Part)
			table.insert(frames, PARKED)
		else
			table.insert(parts, drip.Part)
			table.insert(frames, CFrame.new(drip.Position - Vector3.new(0, half, 0)))
		end
	end

	-- splashes: a widening disc + three droplets hopping out
	const life = rules.SplashLife
	for _, splash in self.Splashes do
		if not splash.Live then
			continue
		end
		const age = now - splash.Born
		const t = age / life
		if t >= 1 then
			splash.Live = false
			splash.Disc.Transparency = 1
			table.insert(parts, splash.Disc)
			table.insert(frames, PARKED)
			for _, bit in splash.Bits do
				bit.Transparency = 1
				table.insert(parts, bit)
				table.insert(frames, PARKED)
			end
			continue
		end
		const out = 1 - (1 - t) * (1 - t)
		const width = rules.SplashSize * splash.Scale * (0.2 + 0.8 * out)
		splash.DiscMesh.Scale = Vector3.new(width, 1, width)
		const fade = SPLASH_BASE + (1 - SPLASH_BASE) * t
		splash.Disc.Transparency = fade
		table.insert(parts, splash.Disc)
		table.insert(frames, CFrame.new(splash.At + Vector3.new(0, 0.04, 0)))
		const hop = SPLASH_HOP * splash.Scale
		const height = math.max(0, hop * age - 0.5 * GRAVITY * age * age)
		for index, bit in splash.Bits do
			const turn = (index / #splash.Bits) * math.pi * 2 + splash.Born
			const reach = SPLASH_OUT * splash.Scale * age
			bit.Transparency = fade
			table.insert(parts, bit)
			table.insert(
				frames,
				CFrame.new(splash.At + Vector3.new(math.cos(turn) * reach, 0.05 + height, math.sin(turn) * reach))
			)
		end
	end

	if #parts > 0 then
		Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function Rain.Destroy(self: Rain)
	self.Folder:Destroy()
	table.clear(self.Drops)
	table.clear(self.Splashes)
	table.clear(self.Drips)
	table.clear(self.Edges)
end

return Rain
