--!strict
--[[
	ANM-006 The stalker, client effect (DEC-260, replaces The wavers; TASK-351; server: AnomalyService/Anomalies/
	ANM-006.luau). Presents only: the stare clock, the steps, the leap and the faint are the server's (T10).

	  Signal    the figure fades in on the far sidewalk (shared/Anomaly/StalkerPath step 0, TrailerFront frame: the same
	            line the server measures the gaze on), facing the service window, perfectly still.
	  Step      record Step k: it LUNGES to step k in LUNGE s (a jerk, not a walk) and its head tilts a little more
	            each step. Cue stalker_step plays a step sound at its feet.
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
const STEPS = 6 -- Rules/ANM-006 Steps (the client never reads the rule: same number, Provisional)
const FADE_IN = 1.2
const FADE_OUT = 0.9
const LUNGE = 0.18 -- s of one lunge
const TILT_PER_STEP = 7 -- degrees the head leans per step
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
	Step: number, -- current shown step (fractional while lunging)
	Lunge: Tween?,
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
	part(model, "EyeL", Vector3.new(0.55, 0.7, 0.2), CFrame.new(-0.42, 8.55, -0.92), EYE, Enum.PartType.Ball)
	part(model, "EyeR", Vector3.new(0.55, 0.7, 0.2), CFrame.new(0.42, 8.55, -0.92), EYE, Enum.PartType.Ball)
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
		const tilt = CFrame.Angles(0, 0, math.rad(TILT_PER_STEP * figure.Step))
		for _, piece in figure.Parts do
			const offset = piece:GetAttribute("Offset")
			if typeof(offset) == "CFrame" then
				const isHead = piece.Name == "Head" or string.sub(piece.Name, 1, 3) == "Eye"
				piece.CFrame = pose * (if isHead then CFrame.new(0, 7.4, 0) * tilt * CFrame.new(0, -7.4, 0) * offset else offset)
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

-- Smooth lunge from the shown step to `step`
local function lungeTo(figure: Figure, step: number)
	if figure.Gone then
		return
	end
	const from = figure.Step
	const started = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		const t = math.clamp((os.clock() - started) / LUNGE, 0, 1)
		const eased = 1 - (1 - t) ^ 3
		figure.Step = from + (step - from) * eased
		if not figure.Gone then
			place(figure, poseAt(figure, figure.Step))
		end
		if t >= 1 and connection ~= nil then
			connection:Disconnect()
		end
	end)
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
		lungeTo(figure, STEPS - 2)
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
			Lunge = nil,
			Gone = false,
		}
		figures[occ.Id] = figure
		place(figure, poseAt(figure, figure.Step))
		model.Parent = ctx.Folder()
		setAlpha(figure, 0, if occ.Elapsed() > FADE_IN then 0 else FADE_IN)

		-- trembling against the glass while at the window
		const shake = RunService.RenderStepped:Connect(function()
			if figure.Gone or figure.Step < STEPS then
				return
			end
			const jitter = Vector3.new(
				(math.random() - 0.5) * TREMBLE,
				(math.random() - 0.5) * TREMBLE,
				(math.random() - 0.5) * TREMBLE
			)
			place(figure, poseAt(figure, STEPS) + jitter)
		end)

		Vide.effect(function()
			const record = occ.Record()
			if record.Phase == "Resolved" then
				-- a bang already plays its own exit; otherwise it simply fades where it stands
				task.delay(1.2, function()
					vanish(figure, FADE_OUT)
				end)
			elseif record.Step ~= math.round(figure.Step) and record.Step > figure.Step then
				lungeTo(figure, record.Step)
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
		if cue.Cue == "stalker_step" then
			if figure ~= nil then
				ctx.Play(STEP_SOUND, poseAt(figure, cue.Entity).Position)
			end
		elseif cue.Cue == "stalker_leap" then
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
