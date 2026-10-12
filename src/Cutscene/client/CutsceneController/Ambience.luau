--!strict
--[[
	Ambience: the living background of a cinematic scene (owner request 2026-10-12, PROVISIONAL), all client side, no
	data on the server, nothing the gameplay can touch (every part CanCollide / CanQuery / CanTouch off, no shadow).

	  * pollen / dust motes floating in the light and a few drifting leaves, around the camera (one emitter box that
	    follows it; the particles stay where they were born)
	  * steam over the trailer (MapPoint TRL, owner D3 2026-10-12: the cart is gone)
	  * paper sheets blown along the sidewalks by the wind
	  * flocks of pigeons and gulls crossing the sky (Content.Cutscenes.Rules.Flocks): 3 parts per bird, wings flapped
	  * background walkers (Rules.Extras): CrewRig animals walking the sidewalk, animated like the pedestrians

	Every element is a function of the scene's elapsed time (a late client sees the same sky), created when its time
	comes and destroyed with the module. Budget: particles <= PARTICLE_BUDGET alive by construction (rate x lifetime of
	every emitter, summed below); a low graphics level (SavedQualityLevel <= 3) gets none of it; a frame time average
	above Rules.Cinema.Quality.MaxFrameTime for FLAG_AFTER s switches the particles off for the rest of the scene.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)
local Anchors = require(ReplicatedStorage.shared.Cutscene.Anchors)
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)

export type Context = {
	-- AnimController:Bind(model, set)
	Bind: (model: Model, set: string) -> (),
}

export type Ambience = {
	Step: (elapsed: number, dt: number) -> (),
	Destroy: () -> (),
	-- particles are on (false on low graphics, or after a slow frame average)
	Particles: () -> boolean,
}

const SMOKE = "rbxasset://textures/particles/smoke_main.dds"
const LOW_QUALITY = 3 -- SavedQualityLevel 1..3 = low (Automatic counts as high)
const FLAG_AFTER = 1.5 -- s of slow frames before the particles go off
const PARTICLE_BUDGET = 150
const SPAWN_LIFT = Vector3.new(0, 3, 0) -- CrewRig pivot above the ground (Actors)
const WIND = Vector3.new(-1.8, -0.5, 0.6)
const BOX = Vector3.new(44, 12, 44) -- pollen / leaves volume around the camera
const POLLEN_RATE = 9
const POLLEN_LIFE = 6.5 -- mean s: 9 x 6.5 = ~59 alive
const LEAF_RATE = 1.5
const LEAF_LIFE = 8 -- ~12 alive
const STEAM_RATE = 5
const STEAM_LIFE = 2.8 -- ~14 alive
const PAPERS = { "CS-1", "CS-2", "CS-3" } -- along the sidewalk of the intro walk
const STEAM_POINT = "TRL"
const STEAM_LIFT = Vector3.new(0, 7, 0) -- PROVISIONAL: above the trailer counter, to be tuned in Play
const PAPER_PERIOD = 7
const PAPER_DRIFT = 28 -- studs along the wind in one period
const CREAM = Color3.fromHex("#FFF1D6")
const PIGEON = Color3.fromHex("#8D8A94")
const PIGEON_WING = Color3.fromHex("#B9B6C2")
const GULL = Color3.fromHex("#F4F1EA")
const GULL_WING = Color3.fromHex("#9AA2AD")

-- worst case alive at once, by construction (see the budget in the header)
assert(POLLEN_RATE * POLLEN_LIFE + LEAF_RATE * LEAF_LIFE + STEAM_RATE * STEAM_LIFE <= PARTICLE_BUDGET, "particle budget")

const Ambience = {}

local function lowQuality(): boolean
	const ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	if not ok or level == Enum.SavedQualitySetting.Automatic then
		return false
	end
	return level.Value <= LOW_QUALITY
end

local function holder(name: string, size: Vector3, parent: Instance): Part
	const p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function solid(name: string, size: Vector3, color: Color3, parent: Instance): Part
	const p = holder(name, size, parent)
	p.Transparency = 0
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	return p
end

local function flat(v: Vector3): Vector3
	const f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.new(0, 0, -1)
end

local function pointOf(id: string): CFrame?
	return Anchors.Point(id)
end

-- Particles ---------------------------------------------------------------------------------------------------------

local function pollenEmitter(parent: Instance): ParticleEmitter
	const e = Instance.new("ParticleEmitter")
	e.Name = "Pollen"
	e.Texture = SMOKE
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Rate = POLLEN_RATE
	e.Lifetime = NumberRange.new(POLLEN_LIFE - 1.5, POLLEN_LIFE + 1.5)
	e.Speed = NumberRange.new(0.2, 0.6)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(-0.25, 0.1, 0.08)
	e.Drag = 0.8
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0.18) })
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.4),
		NumberSequenceKeypoint.new(0.8, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Color = ColorSequence.new(Color3.fromRGB(255, 240, 190))
	e.LightEmission = 0.9
	e.LightInfluence = 0
	e.Parent = parent
	return e
end

local function leafEmitter(parent: Instance): ParticleEmitter
	const e = Instance.new("ParticleEmitter")
	e.Name = "Leaves"
	e.Texture = SMOKE
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Rate = LEAF_RATE
	e.Lifetime = NumberRange.new(LEAF_LIFE - 2, LEAF_LIFE + 2)
	e.Speed = NumberRange.new(0.6, 1.4)
	e.SpreadAngle = Vector2.new(60, 60)
	e.EmissionDirection = Enum.NormalId.Back
	e.Acceleration = WIND
	e.Drag = 0.5
	e.RotSpeed = NumberRange.new(-160, 160)
	e.Rotation = NumberRange.new(0, 360)
	e.Size = NumberSequence.new(0.34)
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0.1),
		NumberSequenceKeypoint.new(0.9, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(226, 160, 70)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(176, 120, 62)),
	})
	e.LightEmission = 0
	e.LightInfluence = 0.5
	e.Parent = parent
	return e
end

local function steamEmitter(parent: Instance): ParticleEmitter
	const e = Instance.new("ParticleEmitter")
	e.Name = "Steam"
	e.Texture = SMOKE
	e.Rate = STEAM_RATE
	e.Lifetime = NumberRange.new(STEAM_LIFE - 0.4, STEAM_LIFE + 0.4)
	e.Speed = NumberRange.new(1.1, 1.7)
	e.SpreadAngle = Vector2.new(14, 14)
	e.Acceleration = Vector3.new(-0.5, 0.4, 0.2)
	e.RotSpeed = NumberRange.new(-30, 30)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2.2) })
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Color = ColorSequence.new(Color3.fromRGB(255, 252, 244))
	e.LightEmission = 0.15
	e.LightInfluence = 0.6
	e.Parent = parent
	return e
end

-- Birds -------------------------------------------------------------------------------------------------------------

type Bird = {
	Body: Part,
	Left: Part,
	Right: Part,
	Scale: number,
	Delay: number,
	Phase: number,
	Offset: Vector3,
	Rate: number,
}

type FlockState = { Row: Content.CutsceneFlock, Birds: { Bird }, Origin: CFrame? }

local function newBird(gull: boolean, random: Random, parent: Instance): Bird
	const scale = if gull then 1.7 else 0.9
	const body = solid("Bird", Vector3.new(0.4, 0.38, 0.95) * scale, if gull then GULL else PIGEON, parent)
	const wing = if gull then GULL_WING else PIGEON_WING
	return {
		Body = body,
		Left = solid("Wing", Vector3.new(1.1, 0.06, 0.55) * scale, wing, parent),
		Right = solid("Wing", Vector3.new(1.1, 0.06, 0.55) * scale, wing, parent),
		Scale = scale,
		Delay = random:NextNumber(0, 1.4),
		Phase = random:NextNumber(0, 6.28),
		Offset = Vector3.new(random:NextNumber(-4, 4), random:NextNumber(-2.5, 2.5), random:NextNumber(-4, 4)),
		Rate = if gull then random:NextNumber(3, 4) else random:NextNumber(8, 10),
	}
end

local function poseBird(bird: Bird, position: Vector3, direction: Vector3, elapsed: number)
	const frame = CFrame.lookAt(position, position + direction)
	const s = bird.Scale
	const flap = math.sin(elapsed * bird.Rate + bird.Phase) * 0.75
	bird.Body.CFrame = frame
	bird.Left.CFrame = frame * CFrame.new(-0.2 * s, 0.1 * s, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(-0.55 * s, 0, 0)
	bird.Right.CFrame = frame * CFrame.new(0.2 * s, 0.1 * s, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(0.55 * s, 0, 0)
end

local function showBird(bird: Bird, visible: boolean, parent: Instance)
	const target = if visible then parent else nil
	if bird.Body.Parent ~= target then
		bird.Body.Parent = target
		bird.Left.Parent = target
		bird.Right.Parent = target
	end
end

-- Walkers ----------------------------------------------------------------------------------------------------------

type Walker = {
	Row: Content.CutsceneExtra,
	Model: Model?,
	From: Vector3?,
	Direction: Vector3?,
	Length: number,
	Failed: boolean,
}

local function buildWalker(walker: Walker, context: Context, folder: Instance)
	const row = walker.Row
	const a = pointOf(row.From)
	const b = pointOf(row.To)
	if a == nil or b == nil then
		return -- not streamed in yet: tried again next frame
	end
	const direction = flat(b.Position - a.Position)
	const side = direction:Cross(Vector3.yAxis) * row.Lateral
	walker.From = a.Position + side
	walker.Direction = direction
	walker.Length = (b.Position - a.Position).Magnitude
	const options: CrewRig.BuildOptions = {
		Name = "Extra",
		CFrame = CFrame.lookAt(a.Position + side, a.Position + side + direction) + SPAWN_LIFT,
		Anchored = true,
		Tag = false,
		LookPack = "Day",
		Cap = false,
	}
	const ok, result = pcall(function(): Model
		return CrewRig.Build(row.Species, row.Outfit, options)
	end)
	if not ok then
		walker.Failed = true
		warn(`[CutsceneController] could not build the extra {row.Species}: {result}`)
		return
	end
	const model = result :: Model
	const humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid:Destroy()
	end
	model.Parent = folder
	CrewRig.Dress(model, "Day", "Normal")
	context.Bind(model, "npc")
	walker.Model = model
end

-- Module ------------------------------------------------------------------------------------------------------------

function Ambience.new(context: Context): Ambience
	const rules = Content.Cutscenes.Rules
	const folder = Instance.new("Folder")
	folder.Name = "CutsceneAmbience"
	folder.Parent = Workspace

	const low = lowQuality()
	local particles = not low
	local slowFor = 0
	local average = 1 / 60
	local destroyed = false

	-- emitters
	local follow: Part? = nil
	local pollen: ParticleEmitter? = nil
	local leaves: ParticleEmitter? = nil
	local steam: ParticleEmitter? = nil
	if not low then
		follow = holder("AmbienceBox", BOX, folder)
		pollen = pollenEmitter(follow :: Part)
		leaves = leafEmitter(follow :: Part)
		-- the steam rises where the trailer stands (MapPoint TRL), above its grill side
		const trailer = pointOf(STEAM_POINT)
		if trailer ~= nil then
			const spot = holder("TrailerSteam", Vector3.new(1.2, 0.2, 1.2), folder)
			spot.CFrame = CFrame.new(trailer.Position + STEAM_LIFT)
			steam = steamEmitter(spot)
		end
	end

	-- papers on the wind
	const papers: { { Part: Part, Point: string, Offset: number } } = {}
	if not low then
		for index, id in PAPERS do
			papers[index] = {
				Part = solid("Paper", Vector3.new(0.7, 0.02, 0.5), CREAM, folder),
				Point = id,
				Offset = index * 1.9,
			}
			papers[index].Part.Parent = nil
		end
	end

	-- flocks (built when their time comes)
	const flocks: { FlockState } = {}
	for index, row in rules.Flocks do
		flocks[index] = { Row = row, Birds = {}, Origin = nil }
	end

	-- walkers
	const walkers: { Walker } = {}
	if not low then
		for _, row in rules.Extras do
			table.insert(walkers, { Row = row, Model = nil, From = nil, Direction = nil, Length = 0, Failed = false })
		end
	end

	local function setParticles(on: boolean)
		for _, emitter in { pollen, leaves, steam } do
			if emitter ~= nil then
				emitter.Enabled = on
			end
		end
	end

	local function step(elapsed: number, dt: number)
		if destroyed then
			return
		end
		-- frame time guard
		if particles and dt > 0 then
			average += (dt - average) * 0.1
			if average > rules.Cinema.Quality.MaxFrameTime then
				slowFor += dt
				if slowFor >= FLAG_AFTER then
					particles = false
					setParticles(false)
				end
			else
				slowFor = 0
			end
		end

		const camera = Workspace.CurrentCamera
		const box = follow
		if box ~= nil and camera ~= nil then
			box.CFrame = CFrame.new(camera.CFrame.Position + camera.CFrame.LookVector * 14 - Vector3.new(0, 1, 0))
		end

		-- papers: tumble along the wind and fade in and out of the loop
		for _, paper in papers do
			const origin = pointOf(paper.Point)
			if origin == nil or not particles then
				paper.Part.Parent = nil
				continue
			end
			const phase = ((elapsed + paper.Offset) % PAPER_PERIOD) / PAPER_PERIOD
			const wind = Vector3.new(WIND.X, 0, WIND.Z).Unit
			const lift = 0.35 + math.abs(math.sin(phase * 9 + paper.Offset)) * 1.1
			paper.Part.CFrame = CFrame.new(origin.Position + wind * phase * PAPER_DRIFT + Vector3.new(0, lift, 0))
				* CFrame.Angles(elapsed * 3 + paper.Offset, elapsed * 2.1, elapsed * 4.2)
			paper.Part.Transparency = 1 - math.clamp(math.min(phase, 1 - phase) * 10, 0, 1)
			paper.Part.Parent = folder
		end

		-- flocks
		for index, flock in flocks do
			const row = flock.Row
			if elapsed < row.At or elapsed > row.At + row.Time + 3 then
				for _, bird in flock.Birds do
					showBird(bird, false, folder)
				end
				continue
			end
			if flock.Origin == nil then
				flock.Origin = pointOf(row.Point)
				if flock.Origin == nil then
					continue
				end
				const random = Random.new(1000 + index)
				for _ = 1, row.Count do
					table.insert(flock.Birds, newBird(row.Gull, random, folder))
				end
			end
			const origin = (flock.Origin :: CFrame).Position
			const direction = (row.End - row.Start).Unit
			for _, bird in flock.Birds do
				const f = (elapsed - row.At - bird.Delay) / row.Time
				if f < 0 or f > 1 then
					showBird(bird, false, folder)
					continue
				end
				const position = origin + row.Start:Lerp(row.End, f) + bird.Offset + Vector3.new(0, math.sin(elapsed * 0.9 + bird.Phase) * 0.6, 0)
				poseBird(bird, position, direction, elapsed)
				showBird(bird, true, folder)
			end
		end

		-- walkers
		for _, walker in walkers do
			if walker.Failed or elapsed < walker.Row.Start then
				continue
			end
			if walker.Model == nil then
				buildWalker(walker, context, folder)
			end
			const model = walker.Model
			const from = walker.From
			const direction = walker.Direction
			if model ~= nil and from ~= nil and direction ~= nil then
				const travelled = math.min((elapsed - walker.Row.Start) * walker.Row.Speed, walker.Length)
				const position = from + direction * travelled
				model:PivotTo(CFrame.lookAt(position, position + direction) + SPAWN_LIFT)
			end
		end
	end

	return {
		Step = step,
		Destroy = function()
			destroyed = true
			folder:Destroy()
			follow = nil
		end,
		Particles = function(): boolean
			return particles
		end,
	}
end

return table.freeze(Ambience)
