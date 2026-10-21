--!strict
--[[
	Prop step (TASK-587; design/horror-cinematic.md §3.13, §11.3): the world near Point moves, locally. Point = a
	MapPoint, or "Actor" (the feet of the anomaly's customer, record Anchor) or "Player" (this client's feet). The props
	are the small anchored parts / small models of the map around it (cups, bottles, napkins, sauce): never a character,
	never an interactable (a ProximityPrompt inside), never anything big. Nothing replicated; every prop goes back to
	where it was and every part made here is gone when the run ends.
	  Target "Shake"   the props within To studs (default SHAKE_RADIUS) rattle for Duration s; Value = studs of jitter
	  Target "Float"   the props within To studs (default FLOAT_RADIUS) rise Value studs (default FLOAT_HEIGHT) over
	                   Duration, turning slowly, then hover until a Drop or the run's end
	  Target "Drop"    what this run floated falls back at once (Duration = s of the fall, default DROP_TIME)
	  Target "Sway"    the lamps (anchored parts holding a Light) within To studs (default SWAY_RADIUS) swing, pushed
	                   again and again for Duration s; Value = degrees of each push
	  Target "Puddle"  dark water on the floor under Point. To a number: the puddle grows from Value to To studs of
	                   radius over Duration (0 = it dries away). To a string ("Player", "Actor" or a MapPoint): the water
	                   runs from the puddle to there over Duration (Flood), Value = width of the stream
	  Target "Lift"    floor boards rise at Point on one end and slam back down (dust), over Duration; Value = degrees,
	                   Burst = how many boards (default 1), in a line to To (a MapPoint) when given
	  Sound   Content.Sounds key played at Point when the step starts
	  Seen    which eyes see it (Scene/Seen): "Cameras" = only through a security camera, "Eyes" = only with the bare eye
	PROVISIONAL (TASK-587, frontend-coder): every number until the owner's Play.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)
local Effect = require(script.Parent.Parent.Parent.Effect)
local Steps = require(script.Parent.Parent.Steps)
local Seen = require(script.Parent.Parent.Seen)

type Step = Content.HorrorStep
type State = Steps.State
type Handler = Steps.Handler

const NPC_FOLDER = "Npcs"
const PROP_MAX = 3.2 -- studs: bigger parts / models are furniture, not props
const PROP_MODEL_PARTS = 8 -- a small model with more parts than this moves part by part
const MAX_PROPS = 16 -- per step, nearest first
const SHAKE_RADIUS = 7
const SHAKE_AMOUNT = 0.035 -- studs
const SHAKE_TURN = math.rad(2.5)
const FLOAT_RADIUS = 6
const FLOAT_HEIGHT = 1.2
const FLOAT_TIME = 4
const FLOAT_BOB = 0.08
const FLOAT_SPIN = 0.35 -- rad/s at full height
const DROP_TIME = 0.3
const SWAY_RADIUS = 14
const SWAY_PUSH = 6 -- degrees
const SWAY_EVERY = 0.8 -- s between two pushes
const SWAY_MAX = math.rad(12)
const SWAY_RATE = 4 -- rad/s of the swing
const SWAY_DAMP = 0.9 -- 1/s
const SWAY_REST = math.rad(0.15)
const PUDDLE_NAME = "ScenePuddle"
const PUDDLE_COLOR = Color3.fromHex("#1C2430")
const PUDDLE_TRANSPARENCY = 0.3
const PUDDLE_THICK = 0.04
const PUDDLE_LIFT = 0.03 -- studs over the floor (no z-fight)
const STREAM_WIDTH = 1.2
const BOARD_NAME = "SceneBoard"
const BOARD_SIZE = Vector3.new(0.9, 0.14, 4)
const BOARD_ANGLE = 16 -- degrees
const BOARD_TIME = 1.2
const BOARD_GAP = 1 -- studs between two boards
const BOARD_COLOR = Color3.fromHex("#6B4A2F")
const BOARD_FADE = 1.5 -- s the board takes to sink back into the floor after the slam
const FLOOR_PROBE = 14
const DUST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
const DUST_COLOR = Color3.fromRGB(140, 123, 102)
const DEFAULT_EASE = 0.6

-- One prop: its parts move together around Pivot
type Prop = {
	Parts: { BasePart },
	Origins: { CFrame },
	Pivot: Vector3,
	Seed: number,
	Float: Float?,
	Shake: Jitter?,
}
type Float = { From: number, Goal: number, T0: number, Duration: number, Drop: boolean, Visible: boolean }
type Jitter = { Amount: number, Until: number, Visible: boolean }

type Lamp = {
	Parts: { BasePart },
	Origins: { CFrame },
	Pivot: Vector3,
	Energy: number,
	Clock: number,
	Push: number, -- rad per push
	Until: number, -- pushed until
	Next: number,
	Visible: boolean,
}

type Puddle = { Part: Part, Radius: number, Visible: boolean }

type Run = {
	Props: { [BasePart]: Prop }, -- by first part
	Taken: { [BasePart]: Prop },
	Lamps: { [BasePart]: Lamp },
	Puddles: { [string]: Puddle },
	Made: { Instance }, -- parts made here (streams, boards, dust)
	Stops: { () -> () },
	Rng: Random,
	Driver: RBXScriptConnection?,
}

const runs: { [State]: Run } = {}

-- Where ---------------------------------------------------------------------------------------------------------------

local function rootOf(model: Model?): BasePart?
	if model == nil then
		return nil
	end
	const root = model:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local function actorOf(ctx: Effect.Context, state: State): Model?
	for _, occ in ctx.Occurrences(state.Key) do
		if occ.Id == state.Id then
			const anchor = occ.Record().Anchor
			return if anchor > 0 then ctx.Npc(anchor) else nil
		end
	end
	return nil
end

local function exclusions(ctx: Effect.Context): { Instance }
	const out: { Instance } = { ctx.Folder() }
	const npcs = Workspace:FindFirstChild(NPC_FOLDER)
	if npcs ~= nil then
		table.insert(out, npcs)
	end
	for _, player in Players:GetPlayers() do
		if player.Character ~= nil then
			table.insert(out, player.Character)
		end
	end
	return out
end

-- "Actor" / "Player" / a MapPoint id -> a position
local function where(ctx: Effect.Context, state: State, id: string?): Vector3?
	if id == nil then
		return nil
	elseif id == "Player" then
		const root = rootOf(Players.LocalPlayer.Character)
		return if root ~= nil then root.Position else nil
	elseif id == "Actor" then
		const root = rootOf(actorOf(ctx, state))
		return if root ~= nil then root.Position else nil
	end
	const point = ctx.Point(id)
	return if point ~= nil then point.Position else nil
end

-- The floor under `at` (the hit), or nil
local function floorAt(ctx: Effect.Context, at: Vector3): RaycastResult?
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclusions(ctx)
	params.IgnoreWater = true
	return Workspace:Raycast(at + Vector3.new(0, 2, 0), Vector3.new(0, -FLOOR_PROBE, 0), params)
end

-- Props ---------------------------------------------------------------------------------------------------------------

local function interactable(instance: Instance): boolean
	return instance:FindFirstChildWhichIsA("ProximityPrompt", true) ~= nil
end

local function small(size: Vector3): boolean
	return size.Magnitude <= PROP_MAX
end

-- The props near `at`: each small anchored visible part, or the small model it belongs to, nearest first
local function propsNear(ctx: Effect.Context, run: Run, at: Vector3, radius: number): { Prop }
	const params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclusions(ctx)
	const found: { Prop } = {}
	const seen: { [Prop]: boolean } = {}
	const parts = Workspace:GetPartBoundsInRadius(at, radius, params)
	table.sort(parts, function(a: BasePart, b: BasePart): boolean
		return (a.Position - at).Magnitude < (b.Position - at).Magnitude
	end)
	for _, part in parts do
		if #found >= MAX_PROPS then
			break
		end
		const known = run.Taken[part]
		if known ~= nil then
			if not seen[known] then
				seen[known] = true
				table.insert(found, known)
			end
			continue
		end
		if not part.Anchored or part.Transparency >= 0.95 or not small(part.Size) or interactable(part) then
			continue
		end
		local group: { BasePart } = { part }
		const model = part:FindFirstAncestorWhichIsA("Model")
		if model ~= nil and model ~= Workspace and small(model:GetExtentsSize()) and not interactable(model) then
			const pieces: { BasePart } = {}
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and d.Anchored and run.Taken[d] == nil then
					table.insert(pieces, d)
				end
			end
			if #pieces > 0 and #pieces <= PROP_MODEL_PARTS then
				group = pieces
			end
		end
		const origins: { CFrame } = {}
		local center = Vector3.zero
		for _, piece in group do
			table.insert(origins, piece.CFrame)
			center += piece.Position
		end
		const prop: Prop = {
			Parts = group,
			Origins = origins,
			Pivot = center / #group,
			Seed = run.Rng:NextNumber(0, math.pi * 2),
			Float = nil,
			Shake = nil,
		}
		for _, piece in group do
			run.Taken[piece] = prop
		end
		run.Props[group[1]] = prop
		seen[prop] = true
		table.insert(found, prop)
	end
	return found
end

local function place(prop: Prop, offset: CFrame?)
	for index, piece in prop.Parts do
		if piece.Parent ~= nil then
			piece.CFrame = if offset ~= nil then offset * prop.Origins[index] else prop.Origins[index]
		end
	end
end

local function forget(run: Run, key: BasePart, prop: Prop)
	place(prop, nil)
	run.Props[key] = nil
	for _, piece in prop.Parts do
		run.Taken[piece] = nil
	end
end

-- Lamps ---------------------------------------------------------------------------------------------------------------

local function lampsNear(ctx: Effect.Context, run: Run, at: Vector3, radius: number): { Lamp }
	const params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclusions(ctx)
	const out: { Lamp } = {}
	for _, part in Workspace:GetPartBoundsInRadius(at, radius, params) do
		if not part.Anchored or part:FindFirstChildWhichIsA("Light", true) == nil then
			continue
		end
		const known = run.Lamps[part]
		if known ~= nil then
			table.insert(out, known)
			continue
		end
		local parts: { BasePart } = { part }
		const model = part.Parent
		if model ~= nil and model:IsA("Model") then
			const pieces: { BasePart } = {}
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and d.Anchored then
					table.insert(pieces, d)
				end
			end
			if #pieces <= PROP_MODEL_PARTS then
				parts = pieces
			end
		end
		local top = -math.huge
		local center = Vector3.zero
		const origins: { CFrame } = {}
		for _, piece in parts do
			table.insert(origins, piece.CFrame)
			top = math.max(top, piece.Position.Y + piece.Size.Y / 2)
			center += piece.Position
		end
		center /= #parts
		const lamp: Lamp = {
			Parts = parts,
			Origins = origins,
			Pivot = Vector3.new(center.X, top, center.Z),
			Energy = 0,
			Clock = run.Rng:NextNumber(0, 2),
			Push = 0,
			Until = 0,
			Next = 0,
			Visible = true,
		}
		for _, piece in parts do
			run.Lamps[piece] = lamp
		end
		table.insert(out, lamp)
	end
	return out
end

-- Driver --------------------------------------------------------------------------------------------------------------

local function smooth(k: number): number
	return k * k * (3 - 2 * k)
end

local function heightOf(float: Float, now: number): (number, boolean)
	const k = if float.Duration > 0 then math.clamp((now - float.T0) / float.Duration, 0, 1) else 1
	const e = if float.Drop then k * k else smooth(k)
	return float.From + (float.Goal - float.From) * e, k >= 1
end

local function drive(run: Run, now: number, dt: number)
	for key, prop in run.Props do
		local offset: CFrame? = nil
		const float = prop.Float
		if float ~= nil then
			const height, done = heightOf(float, now)
			if done and float.Drop then
				prop.Float = nil
			elseif float.Visible then
				const share = math.clamp(height / FLOAT_HEIGHT, 0, 1)
				const bob = if done then math.sin(now * 1.4 + prop.Seed) * FLOAT_BOB else 0
				const pivot = CFrame.new(prop.Pivot)
				const turn = CFrame.Angles(
					math.sin(now * 0.8 + prop.Seed) * 0.12 * share,
					(now + prop.Seed) * FLOAT_SPIN * share,
					math.cos(now * 0.6 + prop.Seed) * 0.1 * share
				)
				offset = CFrame.new(0, height + bob, 0) * pivot * turn * pivot:Inverse()
			end
		end
		const shake = prop.Shake
		if shake ~= nil then
			if now >= shake.Until then
				prop.Shake = nil
			elseif shake.Visible then
				const a = shake.Amount
				const jitter = CFrame.new(run.Rng:NextNumber(-a, a), run.Rng:NextNumber(0, a), run.Rng:NextNumber(-a, a))
					* CFrame.Angles(0, run.Rng:NextNumber(-SHAKE_TURN, SHAKE_TURN), run.Rng:NextNumber(-SHAKE_TURN, SHAKE_TURN))
				const pivot = CFrame.new(prop.Pivot)
				offset = (offset or CFrame.identity) * pivot * jitter * pivot:Inverse()
			end
		end
		if prop.Float == nil and prop.Shake == nil then
			forget(run, key, prop)
		else
			place(prop, offset)
		end
	end
	const done: { [Lamp]: boolean } = {}
	for _, lamp in run.Lamps do
		if done[lamp] then
			continue
		end
		done[lamp] = true
		if now < lamp.Until and now >= lamp.Next then
			lamp.Next = now + SWAY_EVERY
			lamp.Energy = math.min(SWAY_MAX, lamp.Energy + lamp.Push)
		end
		if lamp.Energy <= 0 then
			continue
		end
		lamp.Clock += dt
		lamp.Energy *= math.exp(-SWAY_DAMP * dt)
		if lamp.Energy < SWAY_REST and now >= lamp.Until then
			lamp.Energy = 0
		end
		const angle = if lamp.Visible then lamp.Energy * math.sin(lamp.Clock * SWAY_RATE) else 0
		const pivot = CFrame.new(lamp.Pivot)
		const turn = pivot * CFrame.Angles(angle, 0, angle * 0.6) * pivot:Inverse()
		for index, piece in lamp.Parts do
			if piece.Parent ~= nil then
				piece.CFrame = if lamp.Energy > 0 then turn * lamp.Origins[index] else lamp.Origins[index]
			end
		end
	end
end

local function stopRun(state: State)
	const run = runs[state]
	if run == nil then
		return
	end
	runs[state] = nil
	if run.Driver ~= nil then
		run.Driver:Disconnect()
	end
	for _, stop in run.Stops do
		stop()
	end
	for key, prop in run.Props do
		forget(run, key, prop)
	end
	const given: { [Lamp]: boolean } = {}
	for _, lamp in run.Lamps do
		if not given[lamp] then
			given[lamp] = true
			for index, piece in lamp.Parts do
				if piece.Parent ~= nil then
					piece.CFrame = lamp.Origins[index]
				end
			end
		end
	end
	for _, puddle in run.Puddles do
		puddle.Part:Destroy()
	end
	for _, made in run.Made do
		made:Destroy()
	end
end

local function runOf(state: State): Run
	const existing = runs[state]
	if existing ~= nil then
		return existing
	end
	const run: Run = {
		Props = {},
		Taken = {},
		Lamps = {},
		Puddles = {},
		Made = {},
		Stops = {},
		Rng = Random.new(state.Id * 7919 + 13),
		Driver = nil,
	}
	runs[state] = run
	state.Undo.prop = function()
		stopRun(state)
	end
	run.Driver = RunService.Heartbeat:Connect(function(dt: number)
		drive(run, os.clock(), dt)
	end)
	return run
end

local function bind(run: Run, seen: string?, apply: (visible: boolean) -> ())
	table.insert(run.Stops, Seen.Bind(seen, apply))
end

-- Steps ---------------------------------------------------------------------------------------------------------------

local function radiusOf(step: Step, default: number): number
	return if type(step.To) == "number" and step.To > 0 then step.To else default
end

local function shakeStep(ctx: Effect.Context, run: Run, step: Step, at: Vector3, late: number)
	const now = os.clock()
	const jitters: { Jitter } = {}
	for _, prop in propsNear(ctx, run, at, radiusOf(step, SHAKE_RADIUS)) do
		const jitter: Jitter = { Amount = step.Value or SHAKE_AMOUNT, Until = now - late + (step.Duration or 2), Visible = true }
		prop.Shake = jitter
		table.insert(jitters, jitter)
	end
	bind(run, step.Seen, function(visible)
		for _, jitter in jitters do
			jitter.Visible = visible
		end
	end)
end

local function floatStep(ctx: Effect.Context, run: Run, step: Step, at: Vector3, late: number)
	const now = os.clock()
	const floats: { Float } = {}
	for _, prop in propsNear(ctx, run, at, radiusOf(step, FLOAT_RADIUS)) do
		const current = prop.Float
		const from = if current ~= nil then (heightOf(current, now)) else 0
		const float: Float = {
			From = from,
			Goal = step.Value or FLOAT_HEIGHT,
			T0 = now - late,
			-- each prop leaves the table a little after the last (seeded)
			Duration = (step.Duration or FLOAT_TIME) * (0.75 + 0.5 * ((prop.Seed / (math.pi * 2)) % 1)),
			Drop = false,
			Visible = true,
		}
		prop.Float = float
		table.insert(floats, float)
	end
	bind(run, step.Seen, function(visible)
		for _, float in floats do
			float.Visible = visible
		end
	end)
end

local function dropStep(run: Run, step: Step)
	const now = os.clock()
	for _, prop in run.Props do
		const float = prop.Float
		if float ~= nil and not float.Drop then
			float.From = (heightOf(float, now))
			float.Goal = 0
			float.T0 = now
			float.Duration = step.Duration or DROP_TIME
			float.Drop = true
		end
	end
end

local function swayStep(ctx: Effect.Context, run: Run, step: Step, at: Vector3, late: number)
	const now = os.clock()
	const lamps = lampsNear(ctx, run, at, radiusOf(step, SWAY_RADIUS))
	for _, lamp in lamps do
		lamp.Push = math.rad(step.Value or SWAY_PUSH)
		lamp.Until = now - late + (step.Duration or 0.1)
		lamp.Next = now
	end
	bind(run, step.Seen, function(visible)
		for _, lamp in lamps do
			lamp.Visible = visible
		end
	end)
end

local function puddlePart(ctx: Effect.Context, name: string): Part
	const part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Glass
	part.Color = PUDDLE_COLOR
	part.Reflectance = 0.2
	part.Transparency = PUDDLE_TRANSPARENCY
	part.Parent = ctx.Folder()
	return part
end

local function puddleStep(ctx: Effect.Context, state: State, run: Run, step: Step, at: Vector3, late: number)
	const id = step.Point or "?"
	const hit = floorAt(ctx, at)
	if hit == nil then
		return
	end
	const floor = hit.Position + Vector3.new(0, PUDDLE_LIFT, 0)
	const duration = math.max((step.Duration or DEFAULT_EASE) - late, 0.05)
	local puddle = run.Puddles[id]
	if type(step.To) == "string" then
		-- Flood: the water runs from the puddle to there
		const goal = where(ctx, state, step.To)
		if goal == nil then
			return
		end
		const flat = Vector3.new(goal.X, floor.Y, goal.Z)
		const length = (flat - floor).Magnitude
		if length < 0.5 then
			return
		end
		const stream = puddlePart(ctx, PUDDLE_NAME)
		const width = step.Value or STREAM_WIDTH
		const facing = CFrame.lookAt(floor, flat)
		stream.Size = Vector3.new(width, PUDDLE_THICK, 0.1)
		stream.CFrame = facing * CFrame.new(0, 0, -0.05)
		table.insert(run.Made, stream)
		TweenService:Create(stream, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(width, PUDDLE_THICK, length),
			CFrame = facing * CFrame.new(0, 0, -length / 2),
		}):Play()
		bind(run, step.Seen, function(visible)
			stream.LocalTransparencyModifier = if visible then 0 else 1
		end)
		return
	end
	-- Grow (or dry away at 0)
	const goal = math.max(if type(step.To) == "number" then step.To else (step.Value or 1), 0)
	if puddle == nil then
		const part = puddlePart(ctx, PUDDLE_NAME)
		part.Shape = Enum.PartType.Cylinder
		const radius = math.max(step.Value or 0.2, 0.05)
		part.Size = Vector3.new(PUDDLE_THICK, radius * 2, radius * 2)
		part.CFrame = CFrame.new(floor) * CFrame.Angles(0, 0, math.rad(90))
		const created: Puddle = { Part = part, Radius = radius, Visible = true }
		run.Puddles[id] = created
		puddle = created
		bind(run, step.Seen, function(visible)
			created.Visible = visible
			part.LocalTransparencyModifier = if visible then 0 else 1
		end)
	end
	const live = puddle :: Puddle
	live.Radius = goal
	const size = math.max(goal, 0.01) * 2
	const tween = TweenService:Create(live.Part, TweenInfo.new(duration, Enum.EasingStyle.Sine), {
		Size = Vector3.new(PUDDLE_THICK, size, size),
		Transparency = if goal <= 0 then 1 else PUDDLE_TRANSPARENCY,
	})
	tween:Play()
	if goal <= 0 then
		tween.Completed:Once(function()
			if run.Puddles[id] == live then
				run.Puddles[id] = nil
				live.Part:Destroy()
			end
		end)
	end
end

local function dust(ctx: Effect.Context, run: Run, at: Vector3)
	const part = Instance.new("Part")
	part.Name = BOARD_NAME
	part.Size = Vector3.new(2, 0.2, 2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Position = at
	part.Parent = ctx.Folder()
	const emitter = Instance.new("ParticleEmitter")
	emitter.Texture = DUST_TEXTURE
	emitter.Color = ColorSequence.new(DUST_COLOR)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1.6) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(1, 2.5)
	emitter.SpreadAngle = Vector2.new(70, 70)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Rate = 0
	emitter.Parent = part
	emitter:Emit(18)
	table.insert(run.Made, part)
	task.delay(2, function()
		part:Destroy()
	end)
end

local function liftStep(ctx: Effect.Context, state: State, run: Run, step: Step, at: Vector3, late: number)
	const duration = math.max((step.Duration or BOARD_TIME) - late, 0.2)
	const count = math.max(step.Burst or 1, 1)
	const toward = where(ctx, state, if type(step.To) == "string" then step.To else nil)
	const heading = run.Rng:NextNumber(0, math.pi * 2)
	local direction = Vector3.new(math.cos(heading), 0, math.sin(heading))
	if toward ~= nil and Vector3.new(toward.X - at.X, 0, toward.Z - at.Z).Magnitude > 0.1 then
		direction = Vector3.new(toward.X - at.X, 0, toward.Z - at.Z).Unit
	end
	const angle = math.rad(step.Value or BOARD_ANGLE)
	const boards: { Part } = {}
	for index = 1, count do
		const spot = at + direction * BOARD_GAP * (index - 1)
		const hit = floorAt(ctx, spot)
		if hit == nil then
			continue
		end
		-- the board lies along the line, its hinge at the far end
		const floor = hit.Position + Vector3.new(0, BOARD_SIZE.Y / 2, 0)
		const along = CFrame.lookAt(floor, floor + Vector3.new(-direction.Z, 0, direction.X))
		const board = Instance.new("Part")
		board.Name = BOARD_NAME
		board.Size = BOARD_SIZE
		board.Anchored = true
		board.CanCollide = false
		board.CanQuery = false
		board.CanTouch = false
		-- dressed like the floor it comes out of
		const under = hit.Instance
		board.Material = if under:IsA("BasePart") then hit.Material else Enum.Material.WoodPlanks
		board.Color = if under:IsA("BasePart") then under.Color else BOARD_COLOR
		board.CFrame = along
		board.Parent = ctx.Folder()
		table.insert(run.Made, board)
		table.insert(boards, board)
		const hinge = along * CFrame.new(0, -BOARD_SIZE.Y / 2, BOARD_SIZE.Z / 2)
		const rest = hinge:ToObjectSpace(along)
		const delay = (index - 1) * 0.12
		const started = os.clock() + delay
		local connection: RBXScriptConnection? = nil
		connection = RunService.Heartbeat:Connect(function()
			const k = math.clamp((os.clock() - started) / duration, 0, 1)
			-- up fast, a shiver at the top, slammed down
			const lift = if k < 0.35 then smooth(k / 0.35) elseif k < 0.7 then 1 + math.sin(k * 60) * 0.06 else 1 - ((k - 0.7) / 0.3) ^ 2
			if board.Parent ~= nil then
				board.CFrame = hinge * CFrame.Angles(angle * math.max(lift, 0), 0, 0) * rest
			end
			if k >= 1 and connection ~= nil then
				connection:Disconnect()
				connection = nil
				board.CFrame = along
				dust(ctx, run, floor)
				-- back into the floor
				TweenService:Create(board, TweenInfo.new(BOARD_FADE), { Transparency = 1 }):Play()
			end
		end)
		task.delay(delay + duration * 0.1, dust, ctx, run, floor)
	end
	bind(run, step.Seen, function(visible)
		for _, board in boards do
			board.LocalTransparencyModifier = if visible then 0 else 1
		end
	end)
end

const prop: Handler = function(ctx, state, step, late)
	const target = step.Target or "Shake"
	const run = runOf(state)
	if target == "Drop" then
		dropStep(run, step)
		if step.Sound ~= nil then
			ctx.Audio:Play(step.Sound, where(ctx, state, step.Point))
		end
		return
	end
	const at = where(ctx, state, step.Point)
	if at == nil then
		return
	end
	if step.Sound ~= nil then
		ctx.Audio:Play(step.Sound, at)
	end
	if target == "Shake" then
		shakeStep(ctx, run, step, at, late)
	elseif target == "Float" then
		floatStep(ctx, run, step, at, late)
	elseif target == "Sway" then
		swayStep(ctx, run, step, at, late)
	elseif target == "Puddle" then
		puddleStep(ctx, state, run, step, at, late)
	elseif target == "Lift" then
		liftStep(ctx, state, run, step, at, late)
	end
end

return table.freeze({
	Register = function(handle: (kind: Content.HorrorStepKind, handler: Handler) -> (), _camera: any)
		handle("Prop", prop)
	end,
})
