--!strict
-- ANM-021 The red fog, client look (owner 2026-10-18; server Anomalies/ANM-021; the directed layer - bell, bangs on the
-- glass, words, heart, bars, red grading - is Content.HorrorScenes anm_021_red_fog). Presentation only (T10).
--   * Fog: the Atmosphere turns thick and red over LightController's preset (ctx.Light.Applied), and banks of red fog
--     (particles) roll over the patio and the street, outside the service window. Rises over FOG_IN while the record is
--     Signal / Active, goes over FOG_OUT after (the last Atmosphere write is exactly the preset again).
--   * The runner (owner 2026-10-18: "um boneco todo preto com olhos vermelhos vindo correndo até ele"): a tall black
--     figure with red eyes appears at the end of the street at RUN_FROM s of the omen and RUNS to the service window,
--     reaching it the moment the fog does (Signal end); during the bangs it beats on the glass with both arms, lunging
--     on each blow of the scene; at the end it backs off into the fog and is gone.
--   * cue jumpscare: only the client whose UserId % 65536 = Entity shows the face (Kit/Jumpscare).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Effect = require(script.Parent.Parent.Effect)
local Jumpscare = require(script.Parent.Kit.Jumpscare)

const ENTITY_MOD = 65536
const FOG_IN = 8
const FOG_OUT = 4
const DENSITY = 0.66
const HAZE = 3
const COLOR = Color3.fromHex("#8A161C")
const DECAY = Color3.fromHex("#4A080C")
const PARTICLE = Color3.fromRGB(150, 26, 30)

-- fog volume over the patio and the street (world box; outside the window, Z > the counter front)
const FOG_CENTER = Vector3.new(-42, 1.4, 48)
const FOG_SIZE = Vector3.new(130, 2, 68)
const FOG_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
const FOG_RATES = { 46, 30 } -- particles/s per bank at full fog (owner 2026-10-18: "mais névoa vermelha")

-- the runner
const WINDOW_POINT = "SCENE-WINDOW-EYES" -- outside the service window (restaurant_bind)
const RUN_START = Vector3.new(-42.5, 0.45, 72) -- end of the street, in the fog
const RUN_FROM = 4 -- s into the omen it appears
const OMEN = 12 -- Rules/ANM-021 OmenFor
const STOP_OUT = 1.6 -- studs from the window point to its chest
const BLOWS = { 0, 0.6, 1.3, 8.5, 9, 9.4 } -- s into the bangs (the scene's window_slam steps)
const RUNNER_SCALE = 1.5 -- ~11 studs tall: reads from the counter down the street (owner 2026-10-18: "muito pequeno")
const BODY = Color3.fromHex("#08070B")
const EYE = Color3.fromRGB(255, 24, 24)

type Runner = { Model: Model, Root: BasePart, Arms: { BasePart }, Window: CFrame }

type State = {
	Alpha: number,
	Rising: boolean,
	Orphan: boolean,
	Done: boolean,
	Box: Part,
	Emitters: { ParticleEmitter },
	Runner: Runner?,
	Phase: string,
	PhaseAt: number, -- os.clock when this client saw the phase start (minus its elapsed)
	Connection: RBXScriptConnection?,
}

local function write(ctx: Effect.Context, alpha: number)
	const light = ctx.Light
	const atmosphere = light.Atmosphere
	const preset = light.Applied
	if atmosphere == nil or preset == nil then
		return
	end
	atmosphere.Density = preset.AtmDensity + (math.max(DENSITY, preset.AtmDensity) - preset.AtmDensity) * alpha
	atmosphere.Haze = preset.AtmHaze + (math.max(HAZE, preset.AtmHaze) - preset.AtmHaze) * alpha
	atmosphere.Color = preset.AtmColor:Lerp(COLOR, alpha)
	atmosphere.Decay = preset.AtmDecay:Lerp(DECAY, alpha)
end

local function fogBox(parent: Instance): (Part, { ParticleEmitter })
	const box = Instance.new("Part")
	box.Name = "RedFog"
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.CastShadow = false
	box.Transparency = 1
	box.Size = FOG_SIZE
	box.CFrame = CFrame.new(FOG_CENTER)
	const emitters: { ParticleEmitter } = {}
	for index, bank in { { 14, 20, 34, 0.42 }, { 22, 10, 18, 0.5 } } do
		const e = Instance.new("ParticleEmitter")
		e.Name = `Bank{index}`
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.Texture = FOG_TEXTURE
		e.Color = ColorSequence.new(PARTICLE)
		e.LightEmission = 0.4
		e.LightInfluence = 0.3
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, bank[2]),
			NumberSequenceKeypoint.new(1, bank[3]),
		})
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, bank[4]),
			NumberSequenceKeypoint.new(0.7, bank[4]),
			NumberSequenceKeypoint.new(1, 1),
		})
		e.Lifetime = NumberRange.new(7, 11)
		e.Speed = NumberRange.new(0.6, 1.6)
		e.SpreadAngle = Vector2.new(180, 10)
		e.RotSpeed = NumberRange.new(-8, 8)
		e.Rotation = NumberRange.new(0, 360)
		e.Rate = 0
		e.Parent = box
		table.insert(emitters, e)
	end
	box.Parent = parent
	return box, emitters
end

local function part(model: Model, name: string, size: Vector3, offset: CFrame, color: Color3, neon: boolean): Part
	const p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = offset
	p.Color = color
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = not neon
	p.Parent = model
	return p
end

-- tall thin black figure, feet at the origin facing -Z, two red eyes; Root = the torso (everything moves with it)
local function buildRunner(parent: Instance, window: CFrame): Runner
	const model = Instance.new("Model")
	model.Name = "ANM-021_Runner"
	const root = part(model, "Torso", Vector3.new(1.6, 3.2, 0.9), CFrame.new(0, 4.6, 0), BODY, false)
	part(model, "Head", Vector3.new(1.3, 1.5, 1.2), CFrame.new(0, 6.95, -0.1), BODY, false)
	for _, x in { -0.32, 0.32 } do
		part(model, "Eye", Vector3.new(0.26, 0.14, 0.1), CFrame.new(x, 7.1, -0.72), EYE, true)
	end
	for _, x in { -0.45, 0.45 } do
		part(model, "Leg", Vector3.new(0.5, 3, 0.5), CFrame.new(x, 1.5, 0), BODY, false)
	end
	const arms: { BasePart } = {}
	for _, x in { -1.1, 1.1 } do
		table.insert(arms, part(model, "Arm", Vector3.new(0.42, 3.6, 0.42), CFrame.new(x, 4.4, 0), BODY, false))
	end
	const glow = Instance.new("PointLight")
	glow.Color = EYE
	glow.Brightness = 1.2
	glow.Range = 5
	glow.Parent = model:FindFirstChild("Head")
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p ~= root then
			const weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = p
			weld.Parent = p
		end
	end
	model.PrimaryPart = root
	-- pivot at the feet (the torso is 4.6 up): PivotTo on the ground stands it ON the ground, not waist-deep
	root.PivotOffset = CFrame.new(0, -root.Position.Y, 0)
	model:ScaleTo(RUNNER_SCALE)
	model.Parent = parent
	return { Model = model, Root = root, Arms = arms, Window = window }
end

local function pose(runner: Runner, at: CFrame)
	runner.Model:PivotTo(at)
end

-- MapPoint by name: ctx.Point first, else the tagged part (ctx.Point only knows the points MapIndex indexed)
local function pointOf(ctx: Effect.Context, id: string): CFrame?
	const known = ctx.Point(id)
	if known ~= nil then
		return known
	end
	for _, instance in CollectionService:GetTagged("MapPoint") do
		if instance.Name == id and instance:IsA("BasePart") then
			return instance.CFrame
		end
	end
	return nil
end

-- window spot: just outside the glass, facing in
local function windowCFrame(ctx: Effect.Context): CFrame?
	const point = pointOf(ctx, WINDOW_POINT)
	if point == nil then
		warn("[ANM-021] no MapPoint " .. WINDOW_POINT .. ": the runner is skipped")
		return nil
	end
	const kitchen = pointOf(ctx, "TRL")
	const spot = Vector3.new(point.Position.X, 0.45, point.Position.Z)
	const inward = if kitchen ~= nil then (kitchen.Position - spot) * Vector3.new(1, 0, 1) else Vector3.new(0, 0, -1)
	const dir = if inward.Magnitude > 1e-3 then inward.Unit else Vector3.new(0, 0, -1)
	const stand = spot - dir * STOP_OUT
	return CFrame.lookAt(stand, stand + dir)
end

local function step(ctx: Effect.Context, state: State, dt: number)
	if state.Rising and not state.Orphan then
		state.Alpha = math.min(1, state.Alpha + dt / FOG_IN)
	else
		state.Alpha = math.max(0, state.Alpha - dt / FOG_OUT)
	end
	for index, e in state.Emitters do
		e.Rate = FOG_RATES[index] * state.Alpha
	end
	write(ctx, state.Alpha)

	const runner = state.Runner
	if runner ~= nil then
		const t = os.clock() - state.PhaseAt
		const window = runner.Window
		if state.Phase == "Signal" then
			const run = math.clamp((t - RUN_FROM) / (OMEN - RUN_FROM), 0, 1)
			if t < RUN_FROM then
				runner.Model.Parent = nil
			else
				runner.Model.Parent = ctx.Folder()
				const from = Vector3.new(RUN_START.X, window.Position.Y, RUN_START.Z)
				const eased = run * run -- speeds up as it comes
				const at = from:Lerp(window.Position, eased)
				const bob = math.abs(math.sin(t * 13)) * 0.35
				const lean = CFrame.Angles(math.rad(-18), 0, 0)
				pose(runner, CFrame.lookAt(at, at + window.LookVector) * CFrame.new(0, bob, 0) * lean)
			end
		elseif state.Phase == "Active" then
			runner.Model.Parent = ctx.Folder()
			-- lunge on each blow, sway in between
			local lunge = 0
			for _, blow in BLOWS do
				const d = t - blow
				if d >= 0 and d < 0.35 then
					lunge = math.max(lunge, 1 - d / 0.35)
				end
			end
			const sway = math.sin(t * 2.3) * math.rad(5)
			pose(runner, window * CFrame.new(0, 0, -0.9 * lunge) * CFrame.Angles(math.rad(-10 - 18 * lunge), sway, 0))
		else
			-- backs off into the fog, then gone
			const back = math.clamp(t / 2.5, 0, 1)
			pose(runner, window * CFrame.new(0, 0, 9 * back))
			for _, p in runner.Model:GetDescendants() do
				if p:IsA("BasePart") then
					p.LocalTransparencyModifier = back
				end
			end
			if back >= 1 then
				runner.Model:Destroy()
				state.Runner = nil
			end
		end
	end

	if state.Alpha <= 0 and not state.Rising and state.Runner == nil then
		state.Done = true
		if state.Connection ~= nil then
			state.Connection:Disconnect()
			state.Connection = nil
		end
		write(ctx, 0)
		ctx.Audio:Loop("amb_fog", nil, false)
		state.Box:Destroy()
	end
end

return {
	Ref = "ANM-021",

	Mount = function(ctx: Effect.Context, occ: Effect.Occurrence)
		const record = Vide.untrack(occ.Record)
		const box, emitters = fogBox(ctx.Folder())
		const window = windowCFrame(ctx)
		const state: State = {
			Alpha = if record.Phase ~= "Signal" then 1 else math.clamp(occ.Elapsed() / FOG_IN, 0, 1),
			Rising = record.Phase == "Signal" or record.Phase == "Active",
			Orphan = false,
			Done = false,
			Box = box,
			Emitters = emitters,
			Runner = if window ~= nil then buildRunner(ctx.Folder(), window) else nil,
			Phase = record.Phase,
			PhaseAt = os.clock() - occ.Elapsed(),
			Connection = nil,
		}
		ctx.Audio:Loop("amb_fog", nil, true)
		state.Connection = RunService.RenderStepped:Connect(function(dt: number)
			if not state.Done then
				step(ctx, state, dt)
			end
		end)
		Vide.effect(function()
			const phase = occ.Record().Phase
			Vide.untrack(function()
				if phase ~= state.Phase then
					state.Phase = phase
					state.PhaseAt = os.clock() - occ.Elapsed()
				end
				state.Rising = phase == "Signal" or phase == "Active"
				if not state.Rising then
					ctx.Audio:Loop("amb_fog", nil, false)
				end
			end)
		end)
		Vide.cleanup(function()
			state.Orphan = true
			state.Rising = false
			if state.Phase == "Signal" or state.Phase == "Active" then
				state.Phase = "Resolved"
				state.PhaseAt = os.clock()
			end
			ctx.Audio:Loop("amb_fog", nil, false)
		end)
	end,

	Cue = function(ctx: Effect.Context, cue: Effect.Cue)
		if cue.Cue == "jumpscare" and cue.Entity == Players.LocalPlayer.UserId % ENTITY_MOD then
			Jumpscare.Show(ctx)
		end
	end,
} :: Effect.Module
