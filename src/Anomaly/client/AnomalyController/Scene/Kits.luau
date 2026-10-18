--!strict
--[[
	Scene/Kits (TASK-467; DEC-290, DEC-291; design/horror-cinematic.md §2, tech/horror-scene.md): the step handlers that
	need the sibling kits, plugged into the scene player through Scene.Handle once AnomalyController has its context.
	  Shake / Fov / Nudge  CameraController:HorrorShake / HorrorFov / HorrorNudge (TASK-463); HorrorClear at the end
	  Vignette             Effects/Kit/Screen.SetVignette, one channel per scene (TASK-464); cleared at the end
	  Whispers             Effects/Kit/Whispers.Ramp (the HIDE words, few then en masse; TASK-464). Value = To = 0 stops
	  Door                 the door leaf nearest the step's MapPoint shakes locally: Rattle (handle tried, fast jitter),
	                       Push (forced against the frame), Hold (one hard jolt, the latch holds). Back to its pose after.
	                       Lock: the AutoDoor of that leaf stays shut (attribute DoorHeld, DoorController) until the run ends
	  Shadow               a dark band on the light under that door (DOOR-GAP-B, TASK-465), dimming it: Pass crosses it,
	                       Arrive comes in from the side of the step's To MapPoint (the steps) and stays, Leave goes back out
	  Actor                no Target: two white eyes at the step's MapPoint for Duration s. Target = Model under
	                       ReplicatedStorage.Assets (TASK-472; dark placeholder while missing): walks on the floor from
	                       where it stands (or appears at Point) to To over Duration, then stands; Value = 1 removes it on
	                       arrival. Its Sound plays on a "Feet" part of the model at each step. Seen "Cameras": every part
	                       LocalTransparencyModifier 1, lights / particles / guis off and no shadow, unless Kit/Watch says
	                       this client looks through a security camera (switched live on Watch.Changed)
	Presentation only, client side, nothing replicated. Every handler registers its undo in state.Undo so the end of the
	run (record gone) leaves the world as it was.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)
local Effect = require(script.Parent.Parent.Effect)
local Screen = require(script.Parent.Parent.Effects.Kit.Screen)
local Watch = require(script.Parent.Parent.Effects.Kit.Watch)
local Whispers = require(script.Parent.Parent.Effects.Kit.Whispers)
local Steps = require(script.Parent.Steps)

type Step = Content.HorrorStep
type State = Steps.State
type Handler = Steps.Handler

-- The part of CameraController this module calls (TASK-463)
export type Camera = {
	HorrorShake: (self: any, profile: string, scale: number?) -> (),
	HorrorFov: (self: any, delta: number, back: number?, duration: number) -> (),
	HorrorNudge: (self: any, target: Vector3, degrees: number, duration: number) -> (),
	HorrorClear: (self: any) -> (),
}

const DOOR_SEARCH = 7 -- studs from the MapPoint to the door leaf (an open swing leaf sits ~5 away)
const GAP_SEARCH = 3 -- studs from the MapPoint to the light under the door
const GAP_MAP_ID = "DOOR-GAP-B"
const AUTO_DOOR_TAG = "AutoDoor"
const HELD_ATTRIBUTE = "DoorHeld" -- DoorController keeps a held door shut
const SHADOW_COLOR = Color3.fromRGB(8, 8, 14)
const EYE_SIZE = 0.55
const EYE_GAP = 0.45 -- studs from the centre to each eye
const WALKER_COLOR = Color3.fromHex("#14162A") -- AST-064 fur (placeholder only)
const FLOOR_PROBE = 14 -- studs down from a MapPoint to find the floor
const STEP_GAP = 0.6 -- s between two footsteps when the sound length is unknown (as Scene/Steps)
const MIN_STEP_GAP = 0.3
const WALK_BOB = 0.15 -- studs
const WALK_BOB_RATE = 6 -- rad/s
-- what could glow on a model seen only on the cameras: switched off with it
const GLOW_CLASSES = { "Light", "ParticleEmitter", "Beam", "Trail", "Fire", "Smoke", "Sparkles", "Highlight", "LayerCollector" }
const warnedModel: { [string]: boolean } = {}

local function pointOf(ctx: Effect.Context, id: string?): CFrame?
	if id == nil then
		return nil
	end
	return ctx.Point(id)
end

local function nearest(root: Instance?, at: Vector3, radius: number, keep: (BasePart) -> boolean): BasePart?
	if root == nil then
		return nil
	end
	local best: BasePart? = nil
	local bestDistance = radius
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and keep(d) then
			const distance = (d.Position - at).Magnitude
			if distance < bestDistance then
				best, bestDistance = d, distance
			end
		end
	end
	return best
end

local function restaurant(): Instance?
	return Workspace:FindFirstChild("MAP01_Restaurant")
end

-- Camera ----------------------------------------------------------------------------------------------------------------

local function cameraHandlers(camera: Camera): { [string]: Handler }
	local function undo(state: State)
		state.Undo.camera = function()
			camera:HorrorClear()
		end
	end
	return {
		Shake = function(_ctx, state, step, _late)
			camera:HorrorShake(step.Target or "Jolt", step.Value)
			undo(state)
		end,
		Fov = function(_ctx, state, step, _late)
			const back = if type(step.To) == "number" then step.To else nil
			camera:HorrorFov(step.Value or 0, back, step.Duration or 0.5)
			undo(state)
		end,
		Nudge = function(ctx, state, step, _late)
			const target = pointOf(ctx, step.Point)
			if target == nil then
				return
			end
			camera:HorrorNudge(target.Position, step.Value or 2, step.Duration or 1)
			undo(state)
		end,
	}
end

-- Screen ----------------------------------------------------------------------------------------------------------------

const vignette: Handler = function(_ctx, state, step, late)
	const to = if type(step.To) == "number" then step.To else step.Value or 0
	const duration = math.max((step.Duration or 0) - late, 0)
	Screen.SetVignette(step.Value or 0, to, duration, state.Key)
	state.Undo.vignette = function()
		Screen.ClearVignette(state.Key)
	end
end

const whispers: Handler = function(_ctx, state, step, late)
	const running = state.Undo.whispers
	if running ~= nil then
		state.Undo.whispers = nil
		running()
	end
	const from = step.Value or 0
	const to = if type(step.To) == "number" then step.To else from
	const seconds = (step.Duration or 0) - late
	if (from <= 0 and to <= 0) or seconds <= 0.2 then
		return -- a stop step (or nothing left of the ramp)
	end
	-- DEC-293: Target = a list of Content.HorrorScenes.Words (real hints); nil = the Kit's HIDE list
	const list = if step.Target ~= nil then Content.HorrorScenes.Words[step.Target] else nil
	state.Undo.whispers = Whispers.Ramp(seconds, math.max(from, 0.05), math.max(to, 0.05), list)
end

-- Door ------------------------------------------------------------------------------------------------------------------

-- Offsets in the leaf's own space for each move, as a function of k = 0..1 over the step
local function doorOffset(kind: string, k: number): CFrame
	const fade = 1 - k
	if kind == "Rattle" then
		-- the handle tried: small fast jitter with a slight twist
		const wave = math.sin(k * 60)
		return CFrame.new(wave * 0.02 * fade, 0, 0) * CFrame.Angles(0, math.rad(wave * 0.8 * fade), 0)
	elseif kind == "Push" then
		-- forced against the frame: two pushes inwards
		const push = math.max(0, math.sin(k * math.pi * 2)) * 0.09
		return CFrame.new(0, 0, push)
	end
	-- Hold: one hard jolt, the latch holds
	return CFrame.new(0, 0, math.exp(-k * 8) * 0.06 * math.sin(k * 40))
end

const door: Handler = function(ctx, state, step, _late)
	const at = pointOf(ctx, step.Point)
	if at == nil then
		return
	end
	const leaf = nearest(restaurant(), at.Position, DOOR_SEARCH, function(part)
		return part.Name == "Leaf"
	end)
	if leaf == nil then
		return
	end
	const kind = step.Target or "Rattle"
	if kind == "Lock" then
		local holder: Instance? = leaf
		while holder ~= nil and not CollectionService:HasTag(holder, AUTO_DOOR_TAG) do
			holder = holder.Parent
		end
		if holder ~= nil then
			const door = holder
			door:SetAttribute(HELD_ATTRIBUTE, true)
			state.Undo[`lock:{door:GetFullName()}`] = function()
				door:SetAttribute(HELD_ATTRIBUTE, nil)
			end
		end
		return
	end
	const tag = `door:{leaf:GetFullName()}`
	const previous = state.Undo[tag]
	if previous ~= nil then
		previous()
	end
	const rest = leaf.CFrame
	const duration = math.max(step.Duration or 0.6, 0.1)
	const started = os.clock()
	local connection: RBXScriptConnection? = nil
	local function stop()
		if connection ~= nil then
			connection:Disconnect()
			connection = nil
		end
		if leaf.Parent ~= nil then
			leaf.CFrame = rest
		end
		state.Undo[tag] = nil
	end
	connection = RunService.RenderStepped:Connect(function()
		const k = (os.clock() - started) / duration
		if k >= 1 or leaf.Parent == nil then
			stop()
			return
		end
		leaf.CFrame = rest * doorOffset(kind, k)
	end)
	state.Undo[tag] = stop
end

-- Shadow under the door -------------------------------------------------------------------------------------------------

-- One band per run and gap: Arrive leaves it standing in the middle, a later Leave takes it out (owner 2026-10-18: the
-- shadow and the steps came from different sides; now both come from / go to the step's `To` MapPoint side)
type Band = { Part: BasePart, Light: Light?, Brightness: number }
const bands: { [string]: Band } = {}

const shadow: Handler = function(ctx, state, step, _late)
	const at = pointOf(ctx, step.Point)
	if at == nil then
		return
	end
	const gap = nearest(restaurant(), at.Position, GAP_SEARCH, function(part)
		return part:GetAttribute("MapId") == GAP_MAP_ID
	end)
	if gap == nil then
		return
	end
	const mode = step.Target or "Pass"
	const duration = math.max(step.Duration or 1.2, 0.2)
	const wide = gap.Size.X >= gap.Size.Z
	local long = if wide then gap.CFrame.RightVector else gap.CFrame.LookVector
	const length = math.max(gap.Size.X, gap.Size.Z)
	const width = math.min(gap.Size.X, gap.Size.Z)
	-- the side the creature is on: towards the `To` point along the gap
	const side = if type(step.To) == "string" then pointOf(ctx, step.To) else nil
	if side ~= nil and (side.Position - gap.Position):Dot(long) < 0 then
		long = -long
	end
	const centre = gap.CFrame * CFrame.new(0, 0.012, 0)
	const outside = centre + long * length * 0.75 -- just off the gap, on the creature's side
	const key = `{state.Id}:{gap:GetFullName()}`
	local band = bands[key]

	local function clear()
		const current = bands[key]
		if current == nil then
			return
		end
		bands[key] = nil
		current.Part:Destroy()
		if current.Light ~= nil and current.Light.Parent ~= nil then
			current.Light.Brightness = current.Brightness
		end
	end

	if mode == "Leave" then
		if band == nil then
			return
		end
		TweenService:Create(band.Part, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { CFrame = outside }):Play()
		if band.Light ~= nil then
			TweenService:Create(band.Light, TweenInfo.new(duration), { Brightness = band.Brightness }):Play()
		end
		task.delay(duration + 0.05, clear)
		return
	end

	if band == nil then
		const part = Instance.new("Part")
		part.Name = "HorrorScene_Shadow"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		part.Color = SHADOW_COLOR
		part.Transparency = 0.12
		part.Size = if wide then Vector3.new(length * 0.32, 0.03, width + 0.04) else Vector3.new(width + 0.04, 0.03, length * 0.32)
		part.CFrame = outside
		part.Parent = ctx.Folder()
		const light = gap:FindFirstChildWhichIsA("Light")
		const created: Band = { Part = part, Light = light, Brightness = if light ~= nil then light.Brightness else 0 }
		band = created
		bands[key] = created
		state.Undo[`shadow:{key}`] = clear
	end
	const current = band :: Band
	if current.Light ~= nil then
		TweenService:Create(current.Light, TweenInfo.new(duration), { Brightness = current.Brightness * 0.35 }):Play()
	end
	if mode == "Arrive" then
		TweenService:Create(current.Part, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { CFrame = centre }):Play()
		return
	end
	-- Pass: across to the other side and gone
	TweenService:Create(current.Part, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = centre - long * length * 0.75 }):Play()
	task.delay(duration + 0.05, clear)
end

-- Eyes at a MapPoint ----------------------------------------------------------------------------------------------------

local function eyes(ctx: Effect.Context, state: State, step: Step, late: number)
	const at = pointOf(ctx, step.Point)
	const hold = (step.Duration or 1) - late
	if at == nil or hold <= 0 then
		return
	end
	const model = Instance.new("Model")
	model.Name = "HorrorScene_Eyes"
	for _, side in { -1, 1 } do
		const eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.one * EYE_SIZE
		eye.Material = Enum.Material.Neon
		eye.Color = Color3.new(1, 1, 1)
		eye.Anchored = true
		eye.CanCollide = false
		eye.CanQuery = false
		eye.CanTouch = false
		eye.CastShadow = false
		eye.CFrame = at * CFrame.new(side * EYE_GAP, 0, 0)
		eye.Parent = model
	end
	model.Parent = ctx.Folder()
	const tag = `actor:{step.Point}`
	local function stop()
		model:Destroy()
		state.Undo[tag] = nil
	end
	task.delay(math.max(hold, 0.1), stop)
	state.Undo[tag] = stop
end

-- A model walking a MapPoint path (TASK-472) ----------------------------------------------------------------------------

-- One per run and Target: a later Actor step of the same Target walks it on from where it stands
type Walker = {
	Tag: string,
	Model: Model,
	Feet: BasePart, -- carrier of its steps, moves with the model
	Pivot: CFrame, -- feet on the floor, facing the way it walks
	Token: number, -- bumped by each walk (a newer walk ends the older one)
	Parts: { BasePart },
	Decals: { Decal },
	Glows: { [Instance]: boolean }, -- lights / particles / guis and their own Enabled
	Watch: RBXScriptConnection?,
}
const walkers: { [string]: Walker } = {}

local function walkerModel(name: string): Model
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const found = if assets ~= nil then assets:FindFirstChild(name, true) else nil
	if found ~= nil and found:IsA("Model") then
		return found:Clone()
	end
	if not warnedModel[name] then
		warnedModel[name] = true
		warn(`[Scene] Model {name} not found under ReplicatedStorage.Assets: dark placeholder`)
	end
	-- tall dark figure, pivot at the feet facing -Z (the Walker's silhouette, no eyes: seen only on the cameras)
	const model = Instance.new("Model")
	model.Name = name
	const bodyPart = Instance.new("Part")
	bodyPart.Name = "Body"
	bodyPart.Size = Vector3.new(2.2, 6.2, 1.4)
	bodyPart.CFrame = CFrame.new(0, 3.1, 0)
	bodyPart.Color = WALKER_COLOR
	bodyPart.Material = Enum.Material.SmoothPlastic
	bodyPart.Parent = model
	const head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.one * 1.7
	head.CFrame = CFrame.new(0, 7, 0)
	head.Color = WALKER_COLOR
	head.Material = Enum.Material.SmoothPlastic
	head.Parent = model
	model.WorldPivot = CFrame.identity
	return model
end

local function showWalker(walker: Walker, visible: boolean)
	const modifier = if visible then 0 else 1
	for _, part in walker.Parts do
		part.LocalTransparencyModifier = modifier
	end
	for _, decal in walker.Decals do
		decal.LocalTransparencyModifier = modifier
	end
	for glow, enabled in walker.Glows do
		(glow :: any).Enabled = visible and enabled
	end
end

local function removeWalker(tag: string)
	const walker = walkers[tag]
	if walker == nil then
		return
	end
	walkers[tag] = nil
	walker.Token += 1
	if walker.Watch ~= nil then
		walker.Watch:Disconnect()
		walker.Watch = nil
	end
	walker.Model:Destroy()
end

-- Floor under a MapPoint (the points sit at about head / sound height)
local function floorUnder(ctx: Effect.Context, at: Vector3): Vector3
	const ignore: { Instance } = { ctx.Folder() }
	for _, player in Players:GetPlayers() do
		if player.Character ~= nil then
			table.insert(ignore, player.Character)
		end
	end
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	const hit = Workspace:Raycast(at + Vector3.new(0, 2, 0), Vector3.new(0, -FLOOR_PROBE, 0), params)
	return if hit ~= nil then hit.Position else at
end

local function spawnWalker(ctx: Effect.Context, tag: string, name: string, seen: string, at: Vector3, towards: Vector3): Walker
	const model = walkerModel(name)
	const parts: { BasePart } = {}
	const decals: { Decal } = {}
	const glows: { [Instance]: boolean } = {}
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.Anchored = true
			piece.CanCollide = false
			piece.CanQuery = false
			piece.CanTouch = false
			piece.CastShadow = false -- no shadow on the floor gives it away
			table.insert(parts, piece)
		elseif piece:IsA("Decal") then
			table.insert(decals, piece)
		elseif piece:IsA("Humanoid") then
			piece.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		else
			for _, class in GLOW_CLASSES do
				if piece:IsA(class) then
					glows[piece] = (piece :: any).Enabled == true
					break
				end
			end
		end
	end
	const feet = Instance.new("Part")
	feet.Name = "Feet"
	feet.Size = Vector3.one * 0.2
	feet.Transparency = 1
	feet.Anchored = true
	feet.CanCollide = false
	feet.CanQuery = false
	feet.CanTouch = false
	feet.CastShadow = false
	feet.CFrame = model:GetPivot() + Vector3.new(0, 0.3, 0)
	feet.Parent = model
	const flat = Vector3.new(towards.X - at.X, 0, towards.Z - at.Z)
	const pivot = if flat.Magnitude > 1e-3 then CFrame.lookAt(at, at + flat) else CFrame.new(at)
	const walker: Walker = {
		Tag = tag,
		Model = model,
		Feet = feet,
		Pivot = pivot,
		Token = 0,
		Parts = parts,
		Decals = decals,
		Glows = glows,
		Watch = nil,
	}
	-- hidden before it enters the world, so it never flashes in first person
	if seen == "Cameras" then
		showWalker(walker, Watch.Watching())
		walker.Watch = Watch.Changed(function(watching)
			showWalker(walker, watching)
		end)
	else
		showWalker(walker, true)
	end
	model:PivotTo(pivot)
	model.Parent = ctx.Folder()
	walkers[tag] = walker
	return walker
end

local function walk(ctx: Effect.Context, walker: Walker, step: Step, to: Vector3, late: number)
	walker.Token += 1
	const token = walker.Token
	const from = walker.Pivot.Position
	const flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	const facing = if flat.Magnitude > 1e-3 then flat.Unit else walker.Pivot.LookVector
	const duration = math.max(step.Duration or 1, 0.1)
	const key = step.Sound
	const gone = step.Value == 1
	const started = os.clock() - late
	local nextStep = late -- s into the walk of the next footstep
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function()
		if walker.Token ~= token or walker.Model.Parent == nil then
			if connection ~= nil then
				connection:Disconnect()
			end
			return
		end
		const t = os.clock() - started
		const k = math.clamp(t / duration, 0, 1)
		-- steady pace (same travel as the old moving footstep sound); a small bob while it walks
		const position = from:Lerp(to, k)
		walker.Pivot = CFrame.lookAt(position, position + facing)
		const bob = if k < 1 then math.abs(math.sin(t * WALK_BOB_RATE)) * WALK_BOB else 0
		walker.Model:PivotTo(walker.Pivot + Vector3.new(0, bob, 0))
		if key ~= nil and k < 1 and t >= nextStep then
			const played = ctx.Play(key, walker.Feet)
			const length = if played ~= nil and played.TimeLength > 0 then played.TimeLength else STEP_GAP
			nextStep = t + math.max(length, MIN_STEP_GAP)
		end
		if k >= 1 then
			if connection ~= nil then
				connection:Disconnect()
			end
			if gone then
				removeWalker(walker.Tag)
			end
		end
	end)
end

const actor: Handler = function(ctx, state, step, late)
	const target = step.Target
	if target == nil or target == "" then
		eyes(ctx, state, step, late)
		return
	end
	const to = if type(step.To) == "string" then pointOf(ctx, step.To) else nil
	if to == nil then
		return
	end
	const goal = floorUnder(ctx, to.Position)
	const tag = `walker:{state.Id}:{target}`
	local walker = walkers[tag]
	if walker == nil then
		-- no Point = only walks one already standing (e.g. Resolved before it came)
		const from = pointOf(ctx, step.Point)
		if from == nil then
			return
		end
		walker = spawnWalker(ctx, tag, target, step.Seen or "All", floorUnder(ctx, from.Position), goal)
		state.Undo[tag] = function()
			removeWalker(tag)
		end
	end
	walk(ctx, walker :: Walker, step, goal, late)
end

const Kits = {}

-- Called once by AnomalyController after Scene.Start (needs CameraController).
function Kits.Register(handle: (kind: Content.HorrorStepKind, handler: Handler) -> (), camera: Camera?)
	if camera ~= nil then
		for kind, handler in cameraHandlers(camera) do
			handle(kind :: Content.HorrorStepKind, handler)
		end
	end
	handle("Vignette", vignette)
	handle("Whispers", whispers)
	handle("Door", door)
	handle("Shadow", shadow)
	handle("Actor", actor)
end

return table.freeze(Kits)
