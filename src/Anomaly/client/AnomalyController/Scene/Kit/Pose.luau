--!strict
--[[
	Pose step (TASK-587; design/horror-cinematic.md §3.13, §11.3): moves the anomaly's customer actor (record Anchor =
	NpcId, Effects/Kit/CustomerActor) or, with Value = 1 where it says so, every customer under Workspace.Npcs. Local
	only, nothing replicated, undone when the run ends.
	  Target "Lift"   the head pitches up Value degrees (default LIFT): the blank face raised, the hood lifted
	  Target "Tilt"   the head rolls sideways Value degrees (default TILT; negative = the other side)
	  Target "Turn"   the head turns to this client's camera (Duration = s for a half turn: small = a snap). Value = 1:
	                  every customer under Workspace.Npcs turns together, the actor too. Through a security camera the
	                  camera IS the security camera: it stares into the feed
	  Target "Scale"  the head (and what is welded to it) grows to Value x the size it had at the run's first Scale step,
	                  over Duration. With Seen nil it waits until the head is OUT of this client's view (it only grows
	                  while nobody looks); a Seen "Cameras" / "Eyes" layer grows at once, on its own eyes
	  Target "Float"  the body rises Value studs (default FLOAT) over Duration, on top of the family A float
	  Target "Blink"  the face shell goes for Duration s (default BLINK): a blink. Value = 1: every customer BUT the actor
	                  blinks together; To = s between two blinks (repeats until the run ends)
	  Target "Mimic"  the head copies this client's camera turn Value s late (default MIMIC_DELAY): the copy (TASK-590)
	  To      (Lift / Tilt / Turn / Scale / Float / Mimic) s the pose holds once reached, then it eases back over Duration;
	          0 = ease back now; nil = held until the run ends
	  Sound   Content.Sounds key played on the head when the pose lands (Scale: when it really grows)
	  Seen    which eyes see it (Scene/Seen): "Cameras" = only through a security camera, "Eyes" = only with the bare eye
	The neck and the root are moved through Motor6D.Transform after the animation (PreSimulation), composed on what the
	animation wrote: the family A modifiers (C0), the stare pressure and the Night watchers (C1) keep theirs. The head
	size is written like OddCustomer's big head and given back only if nobody changed it since.
	PROVISIONAL (TASK-587, frontend-coder): every number until the owner's Play.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)
local Effect = require(script.Parent.Parent.Parent.Effect)
local Steps = require(script.Parent.Parent.Steps)
local Seen = require(script.Parent.Parent.Seen)

type Step = Content.HorrorStep
type State = Steps.State
type Handler = Steps.Handler

const NPC_FOLDER = "Npcs"
const LIFT = 22 -- degrees
const TILT = 24 -- degrees
const FLOAT = 0.6 -- studs
const BLINK = 0.14 -- s the face is gone
const MIMIC_DELAY = 0.6 -- s
const MIMIC_YAW = math.rad(70) -- the copy never turns past this
const MIMIC_PITCH = math.rad(35)
const TURN_MAX = math.rad(150) -- past the rig's own pose
const TURN_HALF = 0.35 -- s for a half turn when the step has no Duration
const TURN_SETTLE = 3 -- 1/s back to the pose when released
const DEFAULT_EASE = 0.6 -- s
const ACTOR_WAIT = 3 -- s a step waits for the actor rig to stream in
const ACTOR_POLL = 0.25
const HISTORY = 3 -- s of camera look kept for Mimic
const EPSILON = 1e-4

-- One eased value of one rig: Target + Seen layer
type Channel = {
	Target: string,
	From: number,
	Goal: number,
	Rest: number, -- the value it eases back to (0, Scale 1)
	T0: number,
	Duration: number,
	Hold: number?, -- s held once reached, then back to Rest
	Visible: boolean,
	Pending: boolean, -- Scale: waits until the head is out of view
	Sound: string?,
	Delay: number, -- Mimic
	Origin: Vector2?, -- Mimic: the camera (yaw, pitch) when it started
}

-- What a Transform layer last wrote over which animation value
type Layer = { Base: CFrame, Written: CFrame? }

type Welded = { Part: BasePart, Size: Vector3, Offset: CFrame, Weld: WeldConstraint }

type Grown = {
	Head: BasePart,
	Motor: Motor6D,
	Size: Vector3,
	C1: CFrame,
	Welded: { Welded },
	Shown: number, -- factor applied now
	Written: Vector3, -- head size this piece wrote last
}

type Rig = {
	Model: Model,
	Head: BasePart?,
	Neck: Motor6D?,
	Root: Motor6D?,
	NeckLayer: Layer,
	RootLayer: Layer,
	Channels: { [string]: Channel },
	Turn: number, -- rad shown now
	Grown: Grown?,
}

type Run = {
	Rigs: { [Model]: Rig },
	Faces: { [BasePart]: boolean }, -- face shells hidden by a blink now
	Stops: { () -> () }, -- Seen bindings
	History: { { At: number, Look: Vector2 } }, -- Mimic
	Driver: RBXScriptConnection?,
	Alive: boolean,
}

-- The camera look now and some time ago (Mimic)
type Look = { Now: Vector2, At: (t: number) -> Vector2 }

const runs: { [State]: Run } = {}

-- Helpers ---------------------------------------------------------------------------------------------------------------

local function smooth(k: number): number
	return k * k * (3 - 2 * k)
end

local function motor(model: Model, part: string, name: string): Motor6D?
	const host = model:FindFirstChild(part)
	const found = if host ~= nil then host:FindFirstChild(name) else nil
	return if found ~= nil and found:IsA("Motor6D") then found else nil
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

local function customers(): { Model }
	const out: { Model } = {}
	const folder = Workspace:FindFirstChild(NPC_FOLDER)
	for _, child in if folder ~= nil then folder:GetChildren() else {} do
		if child:IsA("Model") and child:FindFirstChild("Head") ~= nil then
			table.insert(out, child)
		end
	end
	return out
end

-- The camera look as (yaw, pitch), radians
local function look(): Vector2
	const camera = Workspace.CurrentCamera
	if camera == nil then
		return Vector2.zero
	end
	const v = camera.CFrame.LookVector
	return Vector2.new(math.atan2(-v.X, -v.Z), math.asin(math.clamp(v.Y, -1, 1)))
end

local function wrap(angle: number): number
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

local function signedAngle(from: Vector3, to: Vector3, up: Vector3): number
	const a = from - up * from:Dot(up)
	const b = to - up * to:Dot(up)
	if a.Magnitude < EPSILON or b.Magnitude < EPSILON then
		return 0
	end
	return math.atan2(a.Unit:Cross(b.Unit):Dot(up), a.Unit:Dot(b.Unit))
end

-- true when this client's camera does not show the head (behind it or off the screen)
local function unseen(head: BasePart): boolean
	const camera = Workspace.CurrentCamera
	if camera == nil then
		return true
	end
	const _, onScreen = camera:WorldToViewportPoint(head.Position)
	return not onScreen
end

-- Writes `offset` over what the animation left in motor.Transform this frame (or over the last base when nothing
-- animates the joint: no build-up)
local function layer(joint: Motor6D, saved: Layer, offset: CFrame)
	const current = joint.Transform
	if saved.Written == nil or current ~= saved.Written then
		saved.Base = current
	end
	const out = saved.Base * offset
	joint.Transform = out
	saved.Written = out
end

local function unlayer(joint: Motor6D?, saved: Layer)
	if joint ~= nil and saved.Written ~= nil and joint.Parent ~= nil and joint.Transform == saved.Written then
		joint.Transform = saved.Base
	end
	saved.Written = nil
end

local function play(ctx: Effect.Context, key: string?, rig: Rig)
	if key == nil then
		return
	end
	const head = rig.Head
	ctx.Audio:Play(key, if head ~= nil then head else rig.Model:GetPivot().Position)
end

-- Head size -------------------------------------------------------------------------------------------------------------

local function grown(rig: Rig): Grown?
	if rig.Grown ~= nil then
		return rig.Grown
	end
	const head = rig.Head
	const neck = rig.Neck
	if head == nil or neck == nil then
		return nil
	end
	const welded: { Welded } = {}
	for _, d in rig.Model:GetDescendants() do
		if d:IsA("WeldConstraint") and d.Part0 == head and d.Part1 ~= nil then
			const part = d.Part1 :: BasePart
			table.insert(welded, { Part = part, Size = part.Size, Offset = head.CFrame:ToObjectSpace(part.CFrame), Weld = d })
		end
	end
	const created: Grown = {
		Head = head,
		Motor = neck,
		Size = head.Size,
		C1 = neck.C1,
		Welded = welded,
		Shown = 1,
		Written = head.Size,
	}
	rig.Grown = created
	return created
end

local function applyScale(g: Grown, scale: number)
	for _, entry in g.Welded do
		entry.Weld.Enabled = false
	end
	g.Head.Size = g.Size * scale
	const c1 = g.C1
	g.Motor.C1 = c1 - c1.Position + c1.Position * scale
	for _, entry in g.Welded do
		const offset = entry.Offset
		entry.Part.Size = entry.Size * scale
		entry.Part.CFrame = g.Head.CFrame * (offset - offset.Position + offset.Position * scale)
		entry.Weld.Enabled = true
	end
	g.Shown = scale
	g.Written = g.Head.Size
end

local function shrink(g: Grown)
	-- given back only when the head still has the size written here (OddCustomer's big head may have undone it first)
	if g.Head.Parent ~= nil and g.Head.Size == g.Written and g.Shown ~= 1 then
		applyScale(g, 1)
	end
end

-- Channels --------------------------------------------------------------------------------------------------------------

local function valueOf(channel: Channel, now: number): number
	if channel.Pending then
		return channel.From
	end
	const k = if channel.Duration > 0 then math.clamp((now - channel.T0) / channel.Duration, 0, 1) else 1
	const v = channel.From + (channel.Goal - channel.From) * smooth(k)
	const hold = channel.Hold
	if hold ~= nil and k >= 1 and now >= channel.T0 + channel.Duration + hold then
		-- held long enough: ease back
		channel.From = v
		channel.Goal = channel.Rest
		channel.T0 = now
		channel.Hold = nil
	end
	return v
end

local function settled(channel: Channel, now: number): boolean
	return channel.Hold == nil
		and channel.Goal == channel.Rest
		and not channel.Pending
		and now >= channel.T0 + channel.Duration
end

-- Driver ----------------------------------------------------------------------------------------------------------------

local function release(rig: Rig)
	unlayer(rig.Neck, rig.NeckLayer)
	unlayer(rig.Root, rig.RootLayer)
	const g = rig.Grown
	if g ~= nil then
		shrink(g)
	end
end

local function drive(ctx: Effect.Context, rig: Rig, now: number, dt: number, view: Look)
	local pitch, roll, yaw, rise, scale = 0, 0, 0, 0, 1
	local turning = false
	local turnSpeed = math.pi / TURN_HALF
	for key, channel in rig.Channels do
		const v = valueOf(channel, now)
		const target = channel.Target
		if target == "Scale" and channel.Pending and channel.Visible then
			const head = rig.Head
			if head == nil or unseen(head) then
				-- nobody looks: it grows now
				channel.Pending = false
				channel.T0 = now
				play(ctx, channel.Sound, rig)
			end
		end
		if channel.Visible then
			if target == "Lift" then
				pitch += math.rad(v)
			elseif target == "Tilt" then
				roll += math.rad(v)
			elseif target == "Float" then
				rise += v
			elseif target == "Scale" then
				scale *= v
			elseif target == "Turn" and v > 0.5 then
				turning = true
				turnSpeed = math.max(turnSpeed, math.pi / math.max(channel.Duration, 0.05))
			elseif target == "Mimic" and v > 0 then
				const origin = channel.Origin or view.Now
				const late = view.At(now - channel.Delay)
				yaw += math.clamp(wrap(late.X - origin.X), -MIMIC_YAW, MIMIC_YAW) * v
				pitch += math.clamp(late.Y - origin.Y, -MIMIC_PITCH, MIMIC_PITCH) * v
			end
		end
		if target ~= "Scale" and settled(channel, now) then
			rig.Channels[key] = nil
		end
	end

	-- Turn: steered by what the head really shows (the other writers included), never past TURN_MAX
	const head = rig.Head
	const neck = rig.Neck
	const camera = Workspace.CurrentCamera
	if turning and head ~= nil and neck ~= nil and neck.Part0 ~= nil and camera ~= nil then
		const miss = signedAngle(head.CFrame.LookVector, camera.CFrame.Position - head.Position, neck.Part0.CFrame.UpVector)
		const limit = turnSpeed * dt
		rig.Turn = math.clamp(rig.Turn + math.clamp(miss, -limit, limit), -TURN_MAX, TURN_MAX)
	else
		rig.Turn -= rig.Turn * math.min(1, dt * TURN_SETTLE)
	end
	yaw += rig.Turn

	if neck ~= nil and neck.Parent ~= nil then
		if math.abs(pitch) + math.abs(roll) + math.abs(yaw) > EPSILON then
			-- a turn of the head around the neck, in the head's own axes, carried into the joint's frame
			const r = neck.C1.Rotation
			layer(neck, rig.NeckLayer, r:Inverse() * CFrame.fromEulerAnglesYXZ(pitch, yaw, roll) * r)
		else
			unlayer(neck, rig.NeckLayer)
		end
	end
	const root = rig.Root
	if root ~= nil and root.Parent ~= nil then
		if math.abs(rise) > EPSILON then
			layer(root, rig.RootLayer, CFrame.new(root.C0:VectorToObjectSpace(Vector3.yAxis) * rise))
		else
			unlayer(root, rig.RootLayer)
		end
	end
	if math.abs(scale - 1) > EPSILON or rig.Grown ~= nil then
		const g = grown(rig)
		if g ~= nil and math.abs(g.Shown - scale) > 1e-3 and g.Head.Parent ~= nil then
			if g.Shown == 1 or g.Head.Size == g.Written then
				applyScale(g, scale)
			end
		end
	end
end

local function sample(run: Run, now: number): Look
	const current = look()
	const history = run.History
	table.insert(history, { At = now, Look = current })
	while #history > 2 and history[1].At < now - HISTORY do
		table.remove(history, 1)
	end
	return {
		Now = current,
		At = function(t: number): Vector2
			local best = current
			for index = #history, 1, -1 do
				best = history[index].Look
				if history[index].At <= t then
					break
				end
			end
			return best
		end,
	}
end

local function stopRun(state: State)
	const run = runs[state]
	if run == nil then
		return
	end
	runs[state] = nil
	run.Alive = false
	if run.Driver ~= nil then
		run.Driver:Disconnect()
	end
	for _, stop in run.Stops do
		stop()
	end
	for _, rig in run.Rigs do
		release(rig)
	end
	for face in run.Faces do
		if face.Parent ~= nil then
			face.LocalTransparencyModifier = 0
		end
	end
end

local function runOf(ctx: Effect.Context, state: State): Run
	const existing = runs[state]
	if existing ~= nil then
		return existing
	end
	const run: Run = { Rigs = {}, Faces = {}, Stops = {}, History = {}, Driver = nil, Alive = true }
	runs[state] = run
	state.Undo.pose = function()
		stopRun(state)
	end
	run.Driver = RunService.PreSimulation:Connect(function(dt: number)
		const now = os.clock()
		const view = sample(run, now)
		for model, rig in run.Rigs do
			if model.Parent == nil then
				run.Rigs[model] = nil
				continue
			end
			drive(ctx, rig, now, dt, view)
		end
	end)
	return run
end

local function rigOf(run: Run, model: Model): Rig
	const existing = run.Rigs[model]
	if existing ~= nil then
		return existing
	end
	const head = model:FindFirstChild("Head")
	const rig: Rig = {
		Model = model,
		Head = if head ~= nil and head:IsA("BasePart") then head else nil,
		Neck = motor(model, "Torso", "Neck"),
		Root = motor(model, "HumanoidRootPart", "RootJoint"),
		NeckLayer = { Base = CFrame.identity, Written = nil },
		RootLayer = { Base = CFrame.identity, Written = nil },
		Channels = {},
		Turn = 0,
		Grown = nil,
	}
	run.Rigs[model] = rig
	return rig
end

-- Steps -----------------------------------------------------------------------------------------------------------------

const DEFAULTS: { [string]: number } = { Lift = LIFT, Tilt = TILT, Float = FLOAT, Scale = 1, Turn = 1, Mimic = 1 }
const RESTS: { [string]: number } = { Scale = 1 }

local function setChannel(ctx: Effect.Context, run: Run, rig: Rig, step: Step, late: number, quiet: boolean?)
	const target = step.Target or "Lift"
	const key = `{target}:{step.Seen or "All"}`
	const now = os.clock()
	const rest = RESTS[target] or 0
	const goal = if target == "Turn" or target == "Mimic" then 1 else (step.Value or DEFAULTS[target] or 0)
	const hold = if type(step.To) == "number" then step.To else nil
	local channel = rig.Channels[key]
	const from = if channel ~= nil then valueOf(channel, now) else rest
	const pending = target == "Scale" and not Seen.Layered(step.Seen) and goal ~= from
	const duration = if target == "Turn" then (step.Duration or TURN_HALF) else (step.Duration or DEFAULT_EASE)
	if channel == nil then
		const created: Channel = {
			Target = target,
			From = from,
			Goal = goal,
			Rest = rest,
			T0 = now - late,
			Duration = duration,
			Hold = hold,
			Visible = true,
			Pending = pending,
			Sound = step.Sound,
			Delay = if target == "Mimic" then (step.Value or MIMIC_DELAY) else 0,
			Origin = if target == "Mimic" then look() else nil,
		}
		rig.Channels[key] = created
		channel = created
		-- the eyes that see this layer (bound once per channel)
		table.insert(
			run.Stops,
			Seen.Bind(step.Seen, function(visible)
				created.Visible = visible
			end)
		)
	else
		channel.From = from
		channel.Goal = goal
		channel.T0 = now - late
		channel.Duration = duration
		channel.Hold = hold
		channel.Pending = pending
		channel.Sound = step.Sound
	end
	const live = channel :: Channel
	if hold == 0 then
		-- 0 = back now
		live.Goal = rest
		live.Hold = nil
	end
	if not live.Pending and not quiet then
		play(ctx, step.Sound, rig)
	end
end

local function blink(run: Run, models: { Model }, seconds: number, seen: string?)
	if not Seen.Visible(seen) then
		return
	end
	for _, model in models do
		const face = model:FindFirstChild("Face")
		if face ~= nil and face:IsA("BasePart") and not run.Faces[face] then
			run.Faces[face] = true
			face.LocalTransparencyModifier = 1
			task.delay(seconds, function()
				run.Faces[face] = nil
				if face.Parent ~= nil then
					face.LocalTransparencyModifier = 0
				end
			end)
		end
	end
end

local function blinkStep(ctx: Effect.Context, state: State, run: Run, step: Step)
	const seconds = step.Duration or BLINK
	local function who(): { Model }
		const actor = actorOf(ctx, state)
		if step.Value ~= 1 then
			return if actor ~= nil then { actor } else {}
		end
		const out: { Model } = {}
		for _, model in customers() do
			if model ~= actor then
				table.insert(out, model)
			end
		end
		return out
	end
	blink(run, who(), seconds, step.Seen)
	const every = if type(step.To) == "number" and step.To > seconds then step.To else nil
	if every ~= nil then
		task.spawn(function()
			while run.Alive do
				task.wait(every)
				if not run.Alive then
					break
				end
				blink(run, who(), seconds, step.Seen)
			end
		end)
	end
	if step.Sound ~= nil then
		ctx.Audio:Play(step.Sound)
	end
end

const pose: Handler = function(ctx, state, step, late)
	const run = runOf(ctx, state)
	if step.Target == "Blink" then
		blinkStep(ctx, state, run, step)
		return
	end
	if step.Target == "Turn" and step.Value == 1 then
		const actor = actorOf(ctx, state)
		const list = customers()
		if actor ~= nil and table.find(list, actor) == nil then
			table.insert(list, actor)
		end
		-- one Sound for the whole room, on the first head
		for index, model in list do
			setChannel(ctx, run, rigOf(run, model), step, late, index > 1)
		end
		return
	end
	const actor = actorOf(ctx, state)
	if actor ~= nil then
		setChannel(ctx, run, rigOf(run, actor), step, late)
		return
	end
	-- the rig may still be streaming in: wait a little for it
	task.spawn(function()
		const started = os.clock()
		while run.Alive and os.clock() - started < ACTOR_WAIT do
			task.wait(ACTOR_POLL)
			const found = actorOf(ctx, state)
			if found ~= nil and run.Alive then
				setChannel(ctx, run, rigOf(run, found), step, late + os.clock() - started)
				return
			end
		end
	end)
end

return table.freeze({
	Register = function(handle: (kind: Content.HorrorStepKind, handler: Handler) -> (), _camera: any)
		handle("Pose", pose)
	end,
})
