--!strict
--[[
	ANM-006 The stalker, client effect (DEC-260, replaces The wavers; TASK-351; server: AnomalyService/Anomalies/
	ANM-006.luau). Presents only: the stare clock, the steps, the leap and the faint are the server's (T10).

	  Signal    the figure fades in on the far sidewalk (shared/Anomaly/StalkerPath step 0, TrailerFront frame: the same
	            line the server measures the gaze on), facing the service window, perfectly still.
	  Step      record Step k: it WALKS on toward step k at a steady pace (WALK_RATE steps/s, legs swinging, a
	            footstep every STEP_SOUND_EVERY s), and stops dead when the record stops climbing (nobody watching).
	            Its head tilts a little more as it comes. Eyes glow (Neon + a small light) so a glance catches it.
	  Active    at the window (Step = Steps): it presses against the glass, trembling.
	  Leap      cue stalker_leap: it jumps through the service window into the trailer and vanishes (the jumpscare
	            and the faint of the nearest player come with the cue `jumpscare`, Entity = UserId % 65536).
	  Bang      cue stalker_bang: the window was closed: two bangs on it, then it backs off and fades.
	  Resolved  it fades out where it stands.
	A late joiner mounts with the current record: the figure stands at its step, no intro.

	PROVISIONAL (TASK-351): placeholder made of Parts (tall dark body, long arms, round head with two big white eyes;
	cartoon and Mild, DEC-172/DEC-256: no blood, no alert red). A Model named ASSET under ReplicatedStorage.Assets
	(pivot at the feet, facing -Z) replaces it when the art exists.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local TrailerFront = require(ReplicatedStorage.shared.Anomaly.TrailerFront)
local StalkerPath = require(ReplicatedStorage.shared.Anomaly.StalkerPath)
local Effect = require(script.Parent.Parent.Effect)
local Jumpscare = require(script.Parent.Kit.Jumpscare)

const REF = "ANM-006"
const ASSET = "AST-Stalker"
const TRAILER_POINT = "TRL"
const ACROSS_POINT = "WALKER-10"
const LANE_POINT = "E-IN"
const ENTITY_MOD = 65536
const STEPS = 20 -- Rules/ANM-006 Steps (the client never reads the rule: same number, Provisional)
const WALK_RATE = 1 / 0.6 -- steps per second = 1 / Rules StepEvery (keeps pace with the server)
const STEP_SOUND_EVERY = 0.42 -- s between two footsteps while walking
const LEG_SWING = 28 -- degrees
const EYE_GLOW_RANGE = 6
const EYE_GLOW_BRIGHTNESS = 1.6
const FADE_IN = 1.2
const FADE_OUT = 0.9
const TILT_MAX = 40 -- degrees the head leans at the window
const TREMBLE = 0.08 -- studs of shake at the window
const LEAP_TIME = 0.45
const STEP_SOUND = "walker_step"
const LEAP_SOUND = "shadow_whoosh"
const BANG_SOUND = "window_slam"

const INK = Color3.fromHex("#2B2233")
const EYE = Color3.fromHex("#FFF6E6")

type Figure = {
	Model: Model,
	Head: BasePart?,
	Parts: { BasePart },
	Front: TrailerFront.Front,
	Base: Vector3,
	Ground: number,
	Step: number, -- current shown step (fractional while walking)
	Target: number, -- record Step it walks to
	Phase: number, -- walk cycle (radians)
	NextStepSound: number, -- os.clock of the next footstep
	Gone: boolean,
}

const figures: { [number]: Figure } = {}

local function part(model: Model, name: string, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?): BasePart
	const piece = Instance.new("Part")
	piece.Name = name
	piece.Size = size
	piece.Shape = shape or Enum.PartType.Block
	piece.Color = color
	piece.Material = Enum.Material.SmoothPlastic
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CastShadow = false
	piece.CFrame = offset
	piece:SetAttribute("Offset", offset)
	piece.Parent = model
	return piece
end

-- Placeholder (feet at the origin, facing -Z): ~9 studs tall, thin, long arms, head with two white eyes
local function placeholder(): Model
	const model = Instance.new("Model")
	model.Name = "Stalker"
	part(model, "Body", Vector3.new(1.6, 5.6, 1), CFrame.new(0, 4.6, 0), INK)
	part(model, "LegL", Vector3.new(0.5, 2.2, 0.5), CFrame.new(-0.45, 1.1, 0), INK)
	part(model, "LegR", Vector3.new(0.5, 2.2, 0.5), CFrame.new(0.45, 1.1, 0), INK)
	part(model, "ArmL", Vector3.new(0.4, 4.8, 0.4), CFrame.new(-1.1, 4.4, 0) * CFrame.Angles(0, 0, math.rad(-6)), INK)
	part(model, "ArmR", Vector3.new(0.4, 4.8, 0.4), CFrame.new(1.1, 4.4, 0) * CFrame.Angles(0, 0, math.rad(6)), INK)
	const head = part(model, "Head", Vector3.new(2, 2, 2), CFrame.new(0, 8.4, 0), INK, Enum.PartType.Ball)
	for _, side in { -1, 1 } do
		const eye = part(
			model,
			if side < 0 then "EyeL" else "EyeR",
			Vector3.new(0.55, 0.7, 0.2),
			CFrame.new(0.42 * side, 8.55, -0.92),
			EYE,
			Enum.PartType.Ball
		)
		eye.Material = Enum.Material.Neon -- glowing eyes: seen at a glance, even in the dark (owner 2026-10-16)
		const glow = Instance.new("PointLight")
		glow.Color = EYE
		glow.Range = EYE_GLOW_RANGE
		glow.Brightness = EYE_GLOW_BRIGHTNESS
		glow.Shadows = false
		glow.Parent = eye
	end
	model.PrimaryPart = head
	return model
end

local function build(): Model
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const template = if assets ~= nil then assets:FindFirstChild(ASSET, true) else nil
	if template ~= nil and template:IsA("Model") then
		const copy = template:Clone()
		for _, piece in copy:GetDescendants() do
			if piece:IsA("BasePart") then
				piece.Anchored = true
				piece.CanCollide = false
				piece.CanQuery = false
				piece.CanTouch = false
			end
		end
		return copy
	end
	return placeholder()
end

-- Pose of the feet at a (fractional) step, facing the trailer
local function poseAt(figure: Figure, step: number): CFrame
	const feet = StalkerPath.At(figure.Front, figure.Base, figure.Ground, step, STEPS)
	return CFrame.lookAt(feet, feet - figure.Front.Out)
end

local function place(figure: Figure, pose: CFrame)
	const model = figure.Model
	if model.PrimaryPart ~= nil and model.PrimaryPart:GetAttribute("Offset") ~= nil then
		-- placeholder: every part keeps its authored offset from the feet; the head leans with the steps
		const tilt = CFrame.Angles(0, 0, math.rad(TILT_MAX * math.clamp(figure.Step / STEPS, 0, 1)))
		const swing = math.sin(figure.Phase) * math.rad(LEG_SWING)
		for _, piece in figure.Parts do
			const offset = piece:GetAttribute("Offset")
			if typeof(offset) == "CFrame" then
				const name = piece.Name
				local frame = offset
				if name == "Head" or string.sub(name, 1, 3) == "Eye" then
					frame = CFrame.new(0, 7.4, 0) * tilt * CFrame.new(0, -7.4, 0) * offset
				elseif name == "LegL" or name == "ArmR" or name == "LegR" or name == "ArmL" then
					-- legs and arms swing from the hip / shoulder, opposite pairs
					const sign = if name == "LegL" or name == "ArmR" then 1 else -1
					const pivotY = if string.sub(name, 1, 3) == "Leg" then 2.2 else 6.8
					frame = CFrame.new(0, pivotY, 0) * CFrame.Angles(swing * sign, 0, 0) * CFrame.new(0, -pivotY, 0) * offset
				end
				piece.CFrame = pose * frame
			end
		end
	else
		model:PivotTo(pose)
	end
end

local function setAlpha(figure: Figure, alpha: number, seconds: number)
	for _, piece in figure.Parts do
		TweenService:Create(piece, TweenInfo.new(seconds), { Transparency = alpha }):Play()
	end
	for _, light in figure.Model:GetDescendants() do
		if light:IsA("PointLight") then
			light.Enabled = alpha < 1
		end
	end
end

local function frameOf(ctx: Effect.Context): (TrailerFront.Front?, Vector3, number)
	const trailer = ctx.Point(TRAILER_POINT)
	if trailer == nil then
		return nil, Vector3.zero, 0
	end
	const lane = ctx.Point(LANE_POINT)
	const ground = if lane ~= nil then lane.Position.Y else trailer.Position.Y
	return TrailerFront.Of(trailer, ctx.Point(ACROSS_POINT), ground), trailer.Position, ground
end

-- One frame of the walk: on toward the record's Step at WALK_RATE, legs swinging, a footstep every STEP_SOUND_EVERY s;
-- still when it caught up (nobody watching); trembling against the glass at the window.
local function walk(ctx: Effect.Context, figure: Figure, dt: number)
	if figure.Gone then
		return
	end
	if figure.Step >= STEPS then
		const jitter = Vector3.new(
			(math.random() - 0.5) * TREMBLE,
			(math.random() - 0.5) * TREMBLE,
			(math.random() - 0.5) * TREMBLE
		)
		place(figure, poseAt(figure, STEPS) + jitter)
		return
	end
	if figure.Step >= figure.Target then
		return -- frozen mid-stride: it only moves while watched
	end
	figure.Step = math.min(figure.Step + WALK_RATE * dt, figure.Target)
	figure.Phase += dt * WALK_RATE * math.pi
	const now = os.clock()
	if now >= figure.NextStepSound then
		figure.NextStepSound = now + STEP_SOUND_EVERY
		ctx.Play(STEP_SOUND, poseAt(figure, figure.Step).Position)
	end
	place(figure, poseAt(figure, figure.Step))
end

local function vanish(figure: Figure, seconds: number)
	if figure.Gone then
		return
	end
	figure.Gone = true
	setAlpha(figure, 1, seconds)
	task.delay(seconds + 0.1, function()
		figure.Model:Destroy()
	end)
end

local function leapIn(ctx: Effect.Context, figure: Figure)
	if figure.Gone then
		return
	end
	ctx.Play(LEAP_SOUND, figure.Front.Window, true)
	const from = poseAt(figure, STEPS)
	const into = figure.Front.Window - figure.Front.Out * 4 + Vector3.new(0, 1, 0)
	const started = os.clock()
	figure.Gone = true
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		const t = math.clamp((os.clock() - started) / LEAP_TIME, 0, 1)
		const flat = from.Position:Lerp(into, t)
		const arc = math.sin(t * math.pi) * 3
		place(figure, CFrame.lookAt(flat + Vector3.new(0, arc, 0), flat + Vector3.new(0, arc, 0) - figure.Front.Out))
		if t >= 1 and connection ~= nil then
			connection:Disconnect()
			figure.Model:Destroy()
		end
	end)
end

local function bang(ctx: Effect.Context, figure: Figure)
	if figure.Gone then
		return
	end
	ctx.Play(BANG_SOUND, figure.Front.Window)
	task.delay(0.35, function()
		ctx.Play(BANG_SOUND, figure.Front.Window)
	end)
	task.delay(0.8, function()
		vanish(figure, FADE_OUT)
	end)
end

return {
	Ref = REF,

	Mount = function(ctx: Effect.Context, occ: Effect.Occurrence)
		const front, base, ground = frameOf(ctx)
		if front == nil then
			return
		end
		const model = build()
		const parts: { BasePart } = {}
		for _, piece in model:GetDescendants() do
			if piece:IsA("BasePart") then
				table.insert(parts, piece)
				piece.Transparency = 1
			end
		end
		const first = occ.Record()
		const figure: Figure = {
			Model = model,
			Head = model:FindFirstChild("Head") :: BasePart?,
			Parts = parts,
			Front = front,
			Base = base,
			Ground = ground,
			Step = first.Step,
			Target = first.Step,
			Phase = 0,
			NextStepSound = 0,
			Gone = false,
		}
		figures[occ.Id] = figure
		place(figure, poseAt(figure, figure.Step))
		model.Parent = ctx.Folder()
		setAlpha(figure, 0, if occ.Elapsed() > FADE_IN then 0 else FADE_IN)

		const shake = RunService.RenderStepped:Connect(function(dt: number)
			walk(ctx, figure, dt)
		end)

		Vide.effect(function()
			const record = occ.Record()
			if record.Phase == "Resolved" then
				-- a bang already plays its own exit; otherwise it simply fades where it stands
				task.delay(1.2, function()
					vanish(figure, FADE_OUT)
				end)
			elseif record.Step > figure.Target then
				figure.Target = record.Step
			end
		end)

		Vide.cleanup(function()
			shake:Disconnect()
			figures[occ.Id] = nil
			figure.Gone = true
			model:Destroy()
		end)
	end,

	Cue = function(ctx: Effect.Context, cue: Effect.Cue)
		const occ = cue.Occurrence
		const figure = if occ ~= nil then figures[occ.Id] else nil
		if cue.Cue == "stalker_leap" then
			if figure ~= nil then
				leapIn(ctx, figure)
			end
		elseif cue.Cue == "stalker_bang" then
			if figure ~= nil then
				bang(ctx, figure)
			end
		elseif cue.Cue == "jumpscare" then
			if cue.Entity == Players.LocalPlayer.UserId % ENTITY_MOD then
				Jumpscare.Show(ctx)
			end
		end
	end,
} :: Effect.Module
