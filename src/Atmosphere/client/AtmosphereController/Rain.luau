--!strict
-- Rain bound to the camera (TASK-275, ATM-4 / ATM-5). Local only (parts under the CurrentCamera, no collision, no
-- query). A RainCells x RainCells grid of RainCell-stud cells follows the camera, snapped to the grid so it does not
-- swim. Every RoofCheck seconds each cell casts one ray down from RainHeight above the camera:
--   * the first surface is above the camera (a roof, the trailer, an awning) -> the cell is off (no rain indoors)
--   * else drops fall from the cell top and die at that surface; a splash emitter sits on it
-- Rates scale with the atmosphere blend (Step(alpha)).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)

type Settings = Content.AtmosphereRain
type Rules = typeof(Content.Atmospheres.Rules)

const ROOF_MARGIN = 1.5 -- studs: a surface this far above the camera counts as a roof
const FALL_EXTRA = 60 -- studs below the camera the ray still looks for ground
const SQUASH = 2.5 -- narrows the streak (ParticleEmitter.Squash, positive = taller and thinner)
const SPLASH_LIFE = 0.25
const SPLASH_SIZE = 0.9

type Cell = {
	Drops: Part,
	Splash: Part,
	DropEmitter: ParticleEmitter,
	SplashEmitter: ParticleEmitter,
	Open: boolean,
}

export type Rain = {
	Settings: Settings,
	Rules: Rules,
	Folder: Folder,
	Cells: { Cell },
	Params: RaycastParams,
	NextCheck: number,
	Alpha: number,
	Check: (self: Rain) -> (),
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

local function dropEmitter(settings: Settings, rules: Rules, parent: Part): ParticleEmitter
	const emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Drops"
	emitter.Texture = rules.RainTexture
	emitter.Color = ColorSequence.new(settings.Color)
	emitter.LightEmission = 0.15
	emitter.LightInfluence = 0.6
	emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Speed = NumberRange.new(settings.Speed[1], settings.Speed[2])
	emitter.Acceleration = settings.Wind
	emitter.Size = NumberSequence.new(settings.Length)
	emitter.Squash = NumberSequence.new(SQUASH)
	emitter.Transparency = NumberSequence.new(settings.Transparency)
	emitter.Rate = 0
	emitter.Parent = parent
	return emitter
end

local function splashEmitter(settings: Settings, rules: Rules, parent: Part): ParticleEmitter
	const emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Splash"
	emitter.Texture = rules.SplashTexture
	emitter.Color = ColorSequence.new(settings.Color)
	emitter.LightInfluence = 0.7
	-- flat on the ground: a tiny upward velocity, faced perpendicular to it
	emitter.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Speed = NumberRange.new(0.01)
	emitter.Lifetime = NumberRange.new(SPLASH_LIFE)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, SPLASH_SIZE),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Rate = 0
	emitter.Parent = parent
	return emitter
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
			DropEmitter = dropEmitter(settings, rules, drops),
			SplashEmitter = splashEmitter(settings, rules, splash),
			Open = false,
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
		Params = params,
		NextCheck = 0,
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

	const fastest = settings.Speed[2]
	const slowest = settings.Speed[1]
	local index = 0
	for i = -half, half do
		for j = -half, half do
			index += 1
			const cell = self.Cells[index]
			const x = originX + i * side
			const z = originZ + j * side
			const hit = Workspace:Raycast(
				Vector3.new(x, top, z),
				Vector3.new(0, -(rules.RainHeight + FALL_EXTRA), 0),
				self.Params
			)
			const groundY = if hit then hit.Position.Y else eye.Y - FALL_EXTRA
			const open = groundY <= eye.Y + ROOF_MARGIN
			cell.Open = open
			if open then
				const fall = top - groundY
				cell.Drops.CFrame = CFrame.new(x, top, z)
				cell.DropEmitter.Lifetime = NumberRange.new(fall / fastest, fall / slowest)
				cell.Splash.CFrame = CFrame.new(x, groundY + 0.05, z)
			end
			cell.SplashEmitter.Enabled = open and hit ~= nil
		end
	end
end

function Rain.Step(self: Rain, alpha: number)
	const now = os.clock()
	if now >= self.NextCheck then
		self.NextCheck = now + self.Rules.RoofCheck
		self:Check()
		self.Alpha = -1 -- rates below refresh after a check
	end
	if alpha == self.Alpha then
		return
	end
	self.Alpha = alpha
	const settings = self.Settings
	for _, cell in self.Cells do
		cell.DropEmitter.Rate = if cell.Open then settings.Rate * alpha else 0
		cell.SplashEmitter.Rate = if cell.Open then settings.Splash * alpha else 0
	end
end

function Rain.Destroy(self: Rain)
	self.Folder:Destroy()
	table.clear(self.Cells)
end

return Rain
