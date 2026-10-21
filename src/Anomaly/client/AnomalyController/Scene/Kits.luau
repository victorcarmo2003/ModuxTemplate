--!strict
--[[
	Scene/Kits (TASK-467; DEC-290, DEC-291; design/horror-cinematic.md §2, tech/horror-scene.md): the step handlers that
	need the sibling kits, plugged into the scene player through Scene.Handle once AnomalyController has its context.
	  Shake / Fov / Nudge  CameraController:HorrorShake / HorrorFov / HorrorNudge (TASK-463); HorrorClear at the end
	  Vignette             Effects/Kit/Screen.SetVignette, one channel per scene (TASK-464); cleared at the end
	  Whispers             Effects/Kit/Whispers.Ramp (the HIDE words, few then en masse; TASK-464). Value = To = 0 stops
	  Door                 the door leaf nearest the step's MapPoint shakes locally: Rattle (handle tried, fast jitter),
	                       Push (forced against the frame), Hold (one hard jolt, the latch holds), Bulge (TASK-592: one
	                       heavy blow, the leaf swells a little and is shoved in, then settles). Back to its pose after.
	                       Lock: the AutoDoor of that leaf stays shut (attribute DoorHeld, DoorController) until the run ends
	  Shadow               a dark band on the light under that door (DOOR-GAP-B, TASK-465), dimming it: Pass crosses it,
	                       Arrive comes in from the side of the step's To MapPoint (the steps) and stays, Leave goes back out
	  Actor                no Target: two white eyes at the step's MapPoint for Duration s. Target = Model under
	                       ReplicatedStorage.Assets (TASK-472; dark placeholder while missing): walks on the floor from
	                       where it stands (or appears at Point) to To over Duration, then stands; Value = 1 removes it on
	                       arrival. Its Sound plays on a "Feet" part of the model at each step. Seen "Cameras": every part
	                       LocalTransparencyModifier 1, lights / particles / guis off and no shadow, unless Kit/Watch says
	                       this client looks through a security camera (switched live on Watch.Changed)
	Roof (TASK-484)      heavy steps on the roof along a line through this client's position (seeded heading): Walk
	                       from Value to To (fractions of the line) over Duration, Leave (from where it is, fading), Thud
	                       (one landing). Each step: Sound (roof_step) just above the ceiling, dust falling under it, the
	                       lamps near it swaying (local CFrame, put back at the end), a small camera thump when close
	HeadDown (TASK-484)  while held, a look pitched up past Value degrees gets a soft nudge back below the horizon (To
	                       degrees <= Rules.MaxNudge, 0.45 s each, every 0.5 s at most): it helps, it never locks
	Grade / Blur (TASK-493)  a ColorCorrectionEffect / BlurEffect of our own in Lighting (HorrorGrade, HorrorBlur),
                       eased with a heartbeat-sized tremble; Silence (TASK-493) eases SoundService Master > Music,
                       Ambient and Sfx > Kitchen down (the dramatic pause) and back
Presentation only, client side, nothing replicated. Every handler registers its undo in state.Undo so the end of the
	run (record gone) leaves the world as it was.
]]
local CollectionService = game:GetService("CollectionService")
local TextChatService = game:GetService("TextChatService")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)
local Effect = require(script.Parent.Parent.Effect)
local Screen = require(script.Parent.Parent.Effects.Kit.Screen)
local Watch = require(script.Parent.Parent.Effects.Kit.Watch)
local Seen = require(script.Parent.Seen)
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
	-- TASK-591: the suspense hijack, up to Rules.MaxPull degrees (Effects/ANM-016 drags every view to the starer)
	HorrorPull: (self: any, target: Vector3, degrees: number, duration: number) -> (),
	HorrorClear: (self: any) -> (),
}

const DOOR_SEARCH = 7 -- studs from the MapPoint to the door leaf (an open swing leaf sits ~5 away)
const GAP_SEARCH = 3 -- studs from the MapPoint to the light under the door
const GAP_MAP_ID = "DOOR-GAP-B"
-- Door Bulge (TASK-592; PROVISIONAL): share of the step spent on the hit, studs shoved in, swell of thickness / face
const BULGE_HIT = 0.12
const BULGE_PUSH = 0.22
const BULGE_THICK = 0.9
const BULGE_FACE = 0.035
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
	-- Text "Red" (owner 2026-10-18, the chase): the words in red, without the whispering bed
	const options: Whispers.RampOptions? = if step.Text == "Red" then { Color = Color3.fromRGB(214, 28, 34), Bed = false } else nil
	state.Undo.whispers = Whispers.Ramp(seconds, math.max(from, 0.05), math.max(to, 0.05), list, options)
end

-- Door ------------------------------------------------------------------------------------------------------------------

-- TASK-592 Bulge: how swollen the leaf is over the step (fast hit, slow settle)
local function bulgeAmount(k: number): number
	if k < BULGE_HIT then
		return k / BULGE_HIT
	end
	return math.exp(-(k - BULGE_HIT) * 5)
end

-- The leaf's size swollen by `amount`: the thinnest axis (the thickness) grows the most, the face a little
local function bulgeSize(size: Vector3, amount: number): Vector3
	const thin = math.min(size.X, size.Y, size.Z)
	local function grow(axis: number): number
		return axis * (1 + amount * (if axis == thin then BULGE_THICK else BULGE_FACE))
	end
	return Vector3.new(grow(size.X), grow(size.Y), grow(size.Z))
end

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
	elseif kind == "Bulge" then
		-- TASK-592: a heavy blow from outside, shoved in hard, then a slow settle with a small tremble
		return CFrame.new(0, 0, bulgeAmount(k) * BULGE_PUSH) * CFrame.Angles(math.rad(math.sin(k * 50) * 0.4 * fade), 0, 0)
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
	const size = leaf.Size
	const bulge = kind == "Bulge"
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
			leaf.Size = size
		end
		state.Undo[tag] = nil
	end
	connection = RunService.RenderStepped:Connect(function()
		const k = (os.clock() - started) / duration
		if k >= 1 or leaf.Parent == nil then
			stop()
			return
		end
		if bulge then
			leaf.Size = bulgeSize(size, bulgeAmount(k))
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
		-- well past the gap and fading out on the way, so nothing of it is left in view when it ends (owner 2026-10-19)
		const gone = centre + long * length * 1.4
		TweenService:Create(band.Part, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { CFrame = gone }):Play()
		TweenService:Create(band.Part, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
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
	-- TASK-589: "Cameras" = only on the feed, "Eyes" = only in first person (Scene/Seen)
	if Seen.Layered(seen) then
		showWalker(walker, Seen.Visible(seen))
		walker.Watch = Watch.Changed(function()
			showWalker(walker, Seen.Visible(seen))
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

-- Heartbeat -------------------------------------------------------------------------------------------------------------

-- One run's heartbeat loop: a beat every 60/BPM s, BPM from Value to To over Duration (owner 2026-10-18).
-- Owner 2026-10-19 ("toca excessivamente ... continua tocando por um tempo ... um fadeout ... cortar uns 80%"):
--   * a calming ramp (To < Value: the escape, the crawler gone, the safe ones after a catch) plays only CALM_SHARE of its
--     Duration and fades out over it, quieter beat after beat, then stops by itself;
--   * a stop step (Value 0) with a Duration fades the running heart out over it instead of cutting it;
--   * a held rate (past Duration, waiting for a stop step) gives up after HOLD_MAX s with a short fade, so a stop step that
--     never runs (a Where filter, a phase skipped) cannot leave the heart beating.
const CALM_SHARE = 0.2
const HOLD_MAX = 10
const HOLD_FADE = 1

const heartbeat: Handler = function(_ctx, state, step, late)
	const from = step.Value or 0
	const to = if type(step.To) == "number" then step.To else from
	const running = (state.Undo :: any).heartbeat :: ((fade: number?) -> ())?
	if running ~= nil then
		state.Undo.heartbeat = nil
		-- a stop step with a Duration fades the heart that runs
		running(if from <= 0 and to <= 0 then step.Duration else nil)
	end
	if from <= 0 and to <= 0 then
		return -- stop step: a sudden silence (or the fade above)
	end
	const row = Content.Sounds.ByKey.heartbeat
	if row == nil or row.Id == "" then
		return
	end
	const found = SoundService:FindFirstChild("Sfx", true)
	const group: SoundGroup? = if found ~= nil and found:IsA("SoundGroup") then found else nil
	const calming = to < from
	const fullDuration = math.max((step.Duration or 0) - late, 0.1)
	const duration = if calming then math.max(fullDuration * CALM_SHARE, 0.1) else fullDuration
	const startedAt = os.clock()
	local alive = true
	local fadeFrom: number? = if calming then startedAt else nil
	local fadeFor = duration
	state.Undo.heartbeat = function(fade: number?)
		if fade ~= nil and fade > 0 and alive then
			fadeFrom = os.clock()
			fadeFor = fade
		else
			alive = false
		end
	end :: any
	task.spawn(function()
		while alive do
			const now = os.clock()
			const t = math.clamp((now - startedAt) / duration, 0, 1)
			-- past Duration it holds the last rate until a stop step, the end of the run or HOLD_MAX
			if fadeFrom == nil and now - startedAt > duration + HOLD_MAX then
				fadeFrom = now
				fadeFor = HOLD_FADE
			end
			local gain = 1
			const fading = fadeFrom
			if fading ~= nil then
				gain = 1 - (now - fading) / fadeFor
				if gain <= 0 then
					alive = false
					break
				end
			end
			const bpm = math.max(from + (to - from) * t, 20)
			const beat = Instance.new("Sound")
			beat.Name = "HorrorScene_Heartbeat"
			beat.SoundId = row.Id
			-- a rising heart gets louder; a calming one never does
			beat.Volume = row.Volume * (if calming then 1 else 0.55 + 0.65 * t) * gain
			beat.PlaybackSpeed = 0.95 + 0.2 * (if calming then 1 - t else t)
			beat.SoundGroup = group
			beat.Parent = SoundService
			beat:Play()
			task.delay(2, function()
				beat:Destroy()
			end)
			task.wait(60 / bpm)
		end
	end)
end

-- Cinema: black bars + HUD hidden -----------------------------------------------------------------------------------------

const CINEMA_NAME = "HorrorCinema"
const HUD_GUIS = { "Hud" } -- the game HUD (coins, shop, sanity...); TouchGui stays (mobile must still move)
-- World: the station outlines (Highlight) and the floating pills (BillboardGui: tips "$0", stock "9/20", "Ready!") turned
-- off while the bars are up (owner 2026-10-18: the money still showed and the outlines flickered under the shakes).
-- Only the workspace ones: the prompts (PromptController) and the breaker note live in PlayerGui and stay.
type Cinema = {
	Gui: ScreenGui,
	Top: Frame,
	Bottom: Frame,
	Saved: { [string]: boolean },
	Backpack: boolean?,
	Chat: boolean?,
	World: { Instance }?,
}
local cinema: Cinema? = nil

local function hideHud(on: boolean, saved: { [string]: boolean }, current: Cinema)
	const playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return
	end
	for _, name in HUD_GUIS do
		const gui = playerGui:FindFirstChild(name)
		if gui ~= nil and gui:IsA("ScreenGui") then
			if on then
				if saved[name] == nil then
					saved[name] = gui.Enabled
				end
				gui.Enabled = false
			elseif saved[name] ~= nil then
				gui.Enabled = saved[name]
			end
		end
	end
	if on then
		const ok, enabled = pcall(function(): boolean
			return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)
		end)
		if ok and current.Backpack == nil then
			current.Backpack = enabled
		end
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false)
		if current.World == nil then
			const off: { Instance } = {}
			for _, instance in workspace:GetDescendants() do
				if instance:IsA("Highlight") or instance:IsA("BillboardGui") then
					const thing = instance :: any
					if thing.Enabled then
						thing.Enabled = false
						table.insert(off, instance)
					end
				end
			end
			current.World = off
		end
		const chat = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
		if chat ~= nil then
			if current.Chat == nil then
				current.Chat = chat.Enabled
			end
			chat.Enabled = false
		end
	else
		if current.Backpack ~= nil then
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, current.Backpack)
		end
		const world = current.World
		if world ~= nil then
			current.World = nil
			for _, instance in world do
				if instance.Parent ~= nil then
					(instance :: any).Enabled = true
				end
			end
		end
		const chat = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
		if chat ~= nil and current.Chat ~= nil then
			chat.Enabled = current.Chat
		end
	end
end

local function bar(name: string, gui: ScreenGui, anchorY: number): Frame
	const frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BorderSizePixel = 0
	frame.AnchorPoint = Vector2.new(0, anchorY)
	frame.Position = UDim2.fromScale(0, anchorY)
	frame.Size = UDim2.fromScale(1, 0)
	frame.Parent = gui
	return frame
end

local function closeCinema(duration: number)
	const current = cinema
	if current == nil then
		return
	end
	cinema = nil
	hideHud(false, current.Saved, current)
	const info = TweenInfo.new(math.max(duration, 0.05), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	TweenService:Create(current.Top, info, { Size = UDim2.fromScale(1, 0) }):Play()
	const tween = TweenService:Create(current.Bottom, info, { Size = UDim2.fromScale(1, 0) })
	tween.Completed:Once(function()
		current.Gui:Destroy()
	end)
	tween:Play()
end

const cinemaStep: Handler = function(_ctx, state, step, late)
	const amount = step.Value or 0
	const duration = math.max((step.Duration or 0.8) - late, 0.05)
	if amount <= 0 then
		closeCinema(duration)
		return
	end
	local current = cinema
	if current == nil then
		const playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if playerGui == nil then
			return
		end
		const gui = Instance.new("ScreenGui")
		gui.Name = CINEMA_NAME
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.ScreenInsets = Enum.ScreenInsets.None
		gui.ClipToDeviceSafeArea = false
		gui.DisplayOrder = 40 -- under the whispers (45) and the jumpscare
		gui.Parent = playerGui
		const created: Cinema = { Gui = gui, Top = bar("Top", gui, 0), Bottom = bar("Bottom", gui, 1), Saved = {} }
		cinema = created
		current = created
	end
	const live = current :: Cinema
	hideHud(true, live.Saved, live)
	const info = TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	TweenService:Create(live.Top, info, { Size = UDim2.fromScale(1, amount) }):Play()
	TweenService:Create(live.Bottom, info, { Size = UDim2.fromScale(1, amount) }):Play()
	state.Undo.cinema = function()
		closeCinema(0.6)
	end
end

-- Roof: something heavy on the roof, overhead (TASK-484, ANM-019) -------------------------------------------------------

-- The walk is a line across the roof through this client's own position (seeded heading: the same on every client),
-- so it always passes right over the player's head. Each step: the step sound just above the ceiling, a puff of dust
-- under it, the lamps near it swaying, a faint camera thump when it is close.
const ROOF_HALF = 30 -- studs from the middle of the walk to each end
const ROOF_STRIDE = 4.5 -- studs between two steps
const ROOF_SIDE = 0.8 -- studs left / right of the line (left foot, right foot)
const ROOF_PROBE = 40 -- studs up from the eye to find the ceiling
const ROOF_OPEN = 10 -- studs above the eye when there is no ceiling (outside)
const ROOF_ABOVE = 1.5 -- studs above the ceiling the steps sound
const ROOF_STEP_KEY = "roof_step"
const ROOF_LAND_KEY = "steps_stop"
const ROOF_THUMP_RANGE = 14 -- studs (flat): closer steps shake the camera a little
const ROOF_SWAY_RANGE = 20 -- studs (flat) from a step to the lamps it sways
const ROOF_LAMP_PARTS = 8 -- a lamp Model with more parts than this is a building: only the part itself sways
const SWAY_MAX = math.rad(9)
const SWAY_STEP = math.rad(3.5)
const SWAY_THUD = math.rad(8)
const SWAY_REST = math.rad(0.15)
const SWAY_RATE = 4.2 -- rad/s of the swing
const SWAY_DAMP = 1.1 -- 1/s
const DUST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
const DUST_COLOR = Color3.fromRGB(140, 123, 102)
const GRIT_COLOR = Color3.fromRGB(84, 72, 60)
const DUST_LIFE = 3 -- s a dust / step carrier part lives
-- TASK-593 (owner Play 2026-10-19: the steps went on long after it left): the roof_step clip is longer than one step,
-- so each step's sound is cut after ROOF_STEP_RING s (a short fade) and the live ones are cut at once when the walk
-- stops (a Thud, Kits.RoofStop, the end of the run). Provisional.
const ROOF_STEP_RING = 0.9 -- s one step sounds
const ROOF_STEP_FADE = 0.25 -- s of its fade out

type Lamp = {
	Parts: { BasePart },
	Origins: { CFrame },
	Pivot: Vector3, -- top of the lamp: it swings from there
	Energy: number, -- swing amplitude (rad)
	Clock: number,
}

type RoofRun = {
	From: Vector3,
	To: Vector3,
	At: number, -- fraction 0..1 of the line where the last step fell
	Lamps: { Lamp }?,
	Sway: RBXScriptConnection?,
	Walk: number, -- token of the walk playing (a new one stops the old)
	Voices: { Sound }, -- TASK-593: the step sounds still ringing (cut when the walk stops)
}

local cameraRef: Camera? = nil
const roofRuns: { [State]: RoofRun } = setmetatable({}, { __mode = "k" }) :: any

-- Every anchored part holding a Light under root, with the small Model around it (the lamp shade, the cord)
local function lampsOf(root: Instance): { Lamp }
	const out: { Lamp } = {}
	const taken: { [BasePart]: boolean } = {}
	for _, light in root:GetDescendants() do
		if not light:IsA("Light") then
			continue
		end
		const part = light.Parent
		if part == nil or not part:IsA("BasePart") or not part.Anchored or taken[part] then
			continue
		end
		local parts: { BasePart } = { part }
		const model = part.Parent
		if model ~= nil and model ~= root and model:IsA("Model") then
			const pieces: { BasePart } = {}
			for _, piece in model:GetDescendants() do
				if piece:IsA("BasePart") and piece.Anchored and not taken[piece] then
					table.insert(pieces, piece)
				end
			end
			if #pieces <= ROOF_LAMP_PARTS then
				parts = pieces
			end
		end
		local top = -math.huge
		local center = Vector3.zero
		const origins: { CFrame } = {}
		for _, piece in parts do
			taken[piece] = true
			table.insert(origins, piece.CFrame)
			top = math.max(top, piece.Position.Y + piece.Size.Y / 2)
			center += piece.Position
		end
		center /= #parts
		table.insert(out, {
			Parts = parts,
			Origins = origins,
			Pivot = Vector3.new(center.X, top, center.Z),
			Energy = 0,
			Clock = 0,
		})
	end
	return out
end

local function restoreLamps(run: RoofRun)
	const sway = run.Sway
	if sway ~= nil then
		sway:Disconnect()
		run.Sway = nil
	end
	for _, lamp in run.Lamps or {} do
		for index, piece in lamp.Parts do
			if piece.Parent ~= nil then
				piece.CFrame = lamp.Origins[index]
			end
		end
		lamp.Energy = 0
	end
end

-- TASK-593: stops the walk playing and cuts every step still ringing (the lamps keep swinging down on their own)
local function roofHush(run: RoofRun)
	run.Walk += 1
	for _, voice in run.Voices do
		if voice.Parent ~= nil then
			voice:Stop()
		end
	end
	table.clear(run.Voices)
end

-- The run's walk line (built on its first Roof step; undone with the run)
local function roofRun(state: State): RoofRun
	const existing = roofRuns[state]
	if existing ~= nil then
		return existing
	end
	const character = Players.LocalPlayer.Character
	const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	const view = Workspace.CurrentCamera
	const center = if root ~= nil and root:IsA("BasePart")
		then root.Position
		elseif view ~= nil then view.CFrame.Position
		else Vector3.zero
	const heading = state.Rng:NextNumber(0, math.pi * 2)
	const direction = Vector3.new(math.cos(heading), 0, math.sin(heading))
	const run: RoofRun = {
		From = center - direction * ROOF_HALF,
		To = center + direction * ROOF_HALF,
		At = 0,
		Lamps = nil,
		Sway = nil,
		Walk = 0,
		Voices = {},
	}
	roofRuns[state] = run
	state.Undo.roof = function()
		roofHush(run)
		restoreLamps(run)
		roofRuns[state] = nil
	end
	return run
end

local function swing(run: RoofRun)
	if run.Sway ~= nil then
		return
	end
	run.Sway = RunService.Heartbeat:Connect(function(dt: number)
		local moving = false
		for _, lamp in run.Lamps or {} do
			if lamp.Energy <= 0 then
				continue
			end
			lamp.Clock += dt
			lamp.Energy *= math.exp(-SWAY_DAMP * dt)
			if lamp.Energy < SWAY_REST then
				lamp.Energy = 0
			else
				moving = true
			end
			const angle = lamp.Energy * math.sin(lamp.Clock * SWAY_RATE)
			const pivot = CFrame.new(lamp.Pivot)
			const turn = pivot * CFrame.Angles(angle, 0, angle * 0.6) * pivot:Inverse()
			for index, piece in lamp.Parts do
				if piece.Parent ~= nil then
					piece.CFrame = if lamp.Energy > 0 then turn * lamp.Origins[index] else lamp.Origins[index]
				end
			end
		end
		const sway = run.Sway
		if not moving and sway ~= nil then
			sway:Disconnect()
			run.Sway = nil
		end
	end)
end

local function kickLamps(run: RoofRun, at: Vector3, range: number, amount: number)
	if run.Lamps == nil then
		run.Lamps = lampsOf(restaurant() or Workspace)
	end
	local any = false
	for _, lamp in run.Lamps :: { Lamp } do
		const offset = lamp.Pivot - at
		const distance = Vector2.new(offset.X, offset.Z).Magnitude
		if distance <= range then
			lamp.Energy = math.min(SWAY_MAX, lamp.Energy + amount * (1 - distance / range))
			any = true
		end
	end
	if any then
		swing(run)
	end
end

-- Y of the ceiling underside above `at` (eye height), or open sky above it
local function ceilingAt(ctx: Effect.Context, at: Vector3): number
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	const ignore: { Instance } = { ctx.Folder() }
	const character = Players.LocalPlayer.Character
	if character ~= nil then
		table.insert(ignore, character)
	end
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	const hit = Workspace:Raycast(at, Vector3.new(0, ROOF_PROBE, 0), params)
	return if hit ~= nil then hit.Position.Y else at.Y + ROOF_OPEN
end

local function carrierAt(ctx: Effect.Context, name: string, at: Vector3, size: Vector3): Part
	const part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Position = at
	part.Parent = ctx.Folder()
	task.delay(DUST_LIFE, part.Destroy, part)
	return part
end

-- A puff of dust and a few grains falling from the ceiling at `at`
local function dust(ctx: Effect.Context, at: Vector3, amount: number)
	const part = carrierAt(ctx, "HorrorScene_Dust", at, Vector3.new(2, 0.2, 2))
	const puff = Instance.new("ParticleEmitter")
	puff.Texture = DUST_TEXTURE
	puff.Color = ColorSequence.new(DUST_COLOR)
	puff.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1.1) })
	puff.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	puff.Lifetime = NumberRange.new(1.2, 2.2)
	puff.Speed = NumberRange.new(0.4, 1.4)
	puff.SpreadAngle = Vector2.new(30, 30)
	puff.EmissionDirection = Enum.NormalId.Bottom
	puff.Acceleration = Vector3.new(0, -2.5, 0)
	puff.Drag = 1.5
	puff.RotSpeed = NumberRange.new(-40, 40)
	puff.Rate = 0
	puff.Parent = part
	const grit = Instance.new("ParticleEmitter")
	grit.Texture = DUST_TEXTURE
	grit.Color = ColorSequence.new(GRIT_COLOR)
	grit.Size = NumberSequence.new(0.07)
	grit.Transparency = NumberSequence.new(0.1)
	grit.Lifetime = NumberRange.new(0.7, 1.1)
	grit.Speed = NumberRange.new(0.5, 1.5)
	grit.SpreadAngle = Vector2.new(20, 20)
	grit.EmissionDirection = Enum.NormalId.Bottom
	grit.Acceleration = Vector3.new(0, -26, 0)
	grit.Rate = 0
	grit.Parent = part
	puff:Emit(math.max(1, math.round(6 * amount)))
	grit:Emit(math.max(1, math.round(10 * amount)))
end

-- One step (or the landing, `heavy`) at the flat point `at`: the sound above the ceiling, dust, lamps, a thump
local function roofStep(
	ctx: Effect.Context,
	state: State,
	run: RoofRun,
	at: Vector3,
	sound: string,
	volume: number,
	heavy: boolean
)
	const view = Workspace.CurrentCamera
	const eye = if view ~= nil then view.CFrame.Position else at
	const ceiling = ceilingAt(ctx, Vector3.new(at.X, eye.Y, at.Z))
	const part = carrierAt(ctx, "HorrorScene_RoofStep", Vector3.new(at.X, ceiling + ROOF_ABOVE, at.Z), Vector3.one * 0.2)
	const voice = ctx.Audio:Play(sound, part, { Volume = volume, Speed = if heavy then 0.6 else 0.72 + state.Rng:NextNumber(0, 0.1) })
	if voice ~= nil then
		-- TASK-593: one step is one step, never the whole clip (the landing rings twice as long)
		table.insert(run.Voices, voice)
		const ring = if heavy then ROOF_STEP_RING * 2 else ROOF_STEP_RING
		task.delay(ring, function()
			const index = table.find(run.Voices, voice)
			if index == nil then
				return -- already cut by roofHush
			end
			table.remove(run.Voices, index)
			if voice.Parent ~= nil and voice.IsPlaying then
				TweenService:Create(voice, TweenInfo.new(ROOF_STEP_FADE), { Volume = 0 }):Play()
				task.delay(ROOF_STEP_FADE, function()
					if voice.Parent ~= nil then
						voice:Stop()
					end
				end)
			end
		end)
	end
	if heavy then
		ctx.Audio:Play(ROOF_LAND_KEY, part, { Volume = volume })
	end
	const strength = math.min(volume, 1)
	dust(ctx, Vector3.new(at.X, ceiling - 0.15, at.Z), (if heavy then 4 else 1) * strength)
	kickLamps(
		run,
		Vector3.new(at.X, ceiling, at.Z),
		if heavy then ROOF_SWAY_RANGE * 2 else ROOF_SWAY_RANGE,
		(if heavy then SWAY_THUD else SWAY_STEP) * strength
	)
	const camera = cameraRef
	if camera == nil then
		return
	end
	const flat = Vector2.new(at.X - eye.X, at.Z - eye.Z).Magnitude
	if heavy then
		camera:HorrorShake("Jolt", math.clamp(1 - flat / (ROOF_THUMP_RANGE * 3), 0.3, 1))
	elseif flat < ROOF_THUMP_RANGE then
		camera:HorrorShake("Step", strength * (1 - flat / ROOF_THUMP_RANGE))
	else
		return
	end
	state.Undo.camera = function()
		camera:HorrorClear()
	end
end

local function roofPoint(run: RoofRun, fraction: number): Vector3
	return run.From:Lerp(run.To, math.clamp(fraction, 0, 1))
end

-- Target "Walk" (steady heavy steps from Value to To, fractions of the line, over Duration), "Leave" (from where it is
-- to To, fading out) or "Thud" (one landing at Value; nil = where it is). Sound = step key (roof_step). TASK-593: a
-- Thud ends the walk playing (it jumped) and cuts its ringing steps; a new Walk / Leave stops the one before.
const roofStepHandler: Handler = function(ctx, state, step, late)
	const run = roofRun(state)
	const target = step.Target or "Walk"
	const sound = step.Sound or ROOF_STEP_KEY
	if target == "Thud" then
		roofHush(run)
		const at = step.Value or run.At
		run.At = at
		roofStep(ctx, state, run, roofPoint(run, at), sound, 1.3, true)
		return
	end
	const leaving = target == "Leave"
	const from = if leaving or step.Value == nil then run.At else step.Value
	const to = if type(step.To) == "number" then step.To else 1
	const duration = math.max((step.Duration or 4) - late, 0.2)
	const count = math.max(2, math.round(math.abs(to - from) * ROOF_HALF * 2 / ROOF_STRIDE))
	const side = (run.To - run.From).Unit:Cross(Vector3.yAxis)
	run.Walk += 1 -- the walk before stops; its last steps ring out (ROOF_STEP_RING)
	const token = run.Walk
	task.spawn(function()
		for index = 1, count do
			task.wait(duration / count)
			if run.Walk ~= token or roofRuns[state] ~= run then
				return
			end
			const fraction = from + (to - from) * (index / count)
			run.At = fraction
			const volume = if leaving then 1 - 0.8 * (index / count) else 1
			const foot = if index % 2 == 0 then ROOF_SIDE else -ROOF_SIDE
			roofStep(ctx, state, run, roofPoint(run, fraction) + side * foot, sound, volume, false)
		end
	end)
end

-- HeadDown (TASK-484): while it walks, a look going up past Value degrees gets a soft nudge back down (To degrees, at
-- most Rules.MaxNudge, each nudge HEAD_DOWN_NUDGE s, far under Rules.MaxControlLock): it helps, the player can always
-- look up anyway. Value = 0 stops it.
const HEAD_DOWN_EVERY = 0.15 -- s between two checks
const HEAD_DOWN_GAP = 0.5 -- s between two nudges
const HEAD_DOWN_NUDGE = 0.45 -- s of each nudge
const HEAD_DOWN_AIM = math.rad(-12) -- the nudge aims a little below the horizon, straight ahead
const headDown: Handler = function(_ctx, state, step, late)
	const running = state.Undo.headdown
	if running ~= nil then
		state.Undo.headdown = nil
		running()
	end
	const threshold = step.Value or 0
	const seconds = (step.Duration or 0) - late
	const camera = cameraRef
	if threshold <= 0 or seconds <= 0 or camera == nil then
		return
	end
	const degrees = if type(step.To) == "number" then step.To else Content.HorrorScenes.Rules.MaxNudge
	local alive = true
	state.Undo.headdown = function()
		alive = false
	end
	task.spawn(function()
		const ends = os.clock() + seconds
		local nextNudge = 0
		while alive and os.clock() < ends do
			const view = Workspace.CurrentCamera
			if view ~= nil and os.clock() >= nextNudge then
				const look = view.CFrame.LookVector
				if math.deg(math.asin(math.clamp(look.Y, -1, 1))) > threshold then
					const _, yaw = view.CFrame:ToOrientation()
					const aim = CFrame.fromOrientation(HEAD_DOWN_AIM, yaw, 0).LookVector
					camera:HorrorNudge(view.CFrame.Position + aim * 20, degrees, HEAD_DOWN_NUDGE)
					nextNudge = os.clock() + HEAD_DOWN_GAP
				end
			end
			task.wait(HEAD_DOWN_EVERY)
		end
	end)
end

-- Grade / Blur / Silence (TASK-493) ---------------------------------------------------------------------------------

const Lighting = game:GetService("Lighting")
const GRADE_NAME = "HorrorGrade"
const BLUR_NAME = "HorrorBlur"
const GRADE_TINTS: { [string]: Color3 } = {
	Cold = Color3.fromRGB(196, 212, 255),
	Red = Color3.fromRGB(255, 128, 118),
	Sick = Color3.fromRGB(208, 255, 196),
	Lift = Color3.fromRGB(255, 255, 255), -- owner 2026-10-18 (the chase): a touch brighter, the night's blue kept
}
const SILENCE_GROUPS = { { "Master", "Music" }, { "Master", "Ambient" }, { "Master", "Sfx", "Kitchen" } }

-- Eases `from` -> `to` over `seconds`, calling `apply(value)` every frame; returns the stop function.
local function ease(from: number, to: number, seconds: number, apply: (number) -> ()): () -> ()
	if seconds <= 0 then
		apply(to)
		return function() end
	end
	const started = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		const t = math.clamp((os.clock() - started) / seconds, 0, 1)
		const e = t * t * (3 - 2 * t)
		apply(from + (to - from) * e)
		if t >= 1 and connection ~= nil then
			connection:Disconnect()
			connection = nil
		end
	end)
	return function()
		if connection ~= nil then
			connection:Disconnect()
			connection = nil
		end
	end
end

local function effectOf(className: string, name: string): Instance
	const existing = Lighting:FindFirstChild(name)
	if existing ~= nil and existing.ClassName == className then
		return existing
	end
	const created = Instance.new(className)
	created.Name = name
	created.Parent = Lighting
	return created
end

const gradeLevel: { [string]: number } = {} -- scene key -> current strength (the strongest one shows)
local gradeTint = "Cold"
local gradeStop: (() -> ())? = nil

const grade: Handler = function(_ctx, state, step, late)
	const effect = effectOf("ColorCorrectionEffect", GRADE_NAME) :: ColorCorrectionEffect
	const from = step.Value or 0
	const to = if type(step.To) == "number" then step.To else from
	gradeTint = step.Target or gradeTint
	const tint = GRADE_TINTS[gradeTint] or GRADE_TINTS.Cold
	if gradeStop ~= nil then
		gradeStop()
	end
	gradeStop = ease(from, to, math.max((step.Duration or 0) - late, 0), function(v: number)
		gradeLevel[state.Key] = v
		local strongest = 0
		for _, level in gradeLevel do
			strongest = math.max(strongest, level)
		end
		-- Red keeps its colour (owner 2026-10-18: "tudo vai ficando vermelho"); Cold / Sick drain it
		const red = gradeTint == "Red"
		const lift = gradeTint == "Lift"
		effect.Saturation = (if red then 0.15 elseif lift then 0 else -0.75) * strongest
		effect.Contrast = (if lift then 0.06 else 0.32) * strongest
		effect.Brightness = (if red then -0.02 elseif lift then 0.12 else -0.06) * strongest
		effect.TintColor = Color3.new(1, 1, 1):Lerp(tint, strongest)
		effect.Enabled = strongest > 0.001
	end)
	state.Undo.grade = function()
		if gradeStop ~= nil then
			gradeStop()
			gradeStop = nil
		end
		gradeLevel[state.Key] = nil
		if next(gradeLevel) == nil then
			effect:Destroy()
		end
	end
end

local blurStop: (() -> ())? = nil

const blur: Handler = function(_ctx, state, step, late)
	const effect = effectOf("BlurEffect", BLUR_NAME) :: BlurEffect
	const max = Content.HorrorScenes.Rules.MaxBlur
	const from = math.clamp(step.Value or 0, 0, max)
	const to = math.clamp(if type(step.To) == "number" then step.To else from, 0, max)
	if blurStop ~= nil then
		blurStop()
	end
	blurStop = ease(from, to, math.max((step.Duration or 0) - late, 0), function(v: number)
		effect.Size = v
		effect.Enabled = v > 0.05
	end)
	state.Undo.blur = function()
		if blurStop ~= nil then
			blurStop()
			blurStop = nil
		end
		effect:Destroy()
	end
end

type Ducked = { Group: SoundGroup, Base: number }
local ducked: { Ducked }? = nil
local silenceStop: (() -> ())? = nil
local silenceLevel = 1

local function silenceGroups(): { Ducked }
	if ducked ~= nil then
		return ducked
	end
	const out: { Ducked } = {}
	for _, path in SILENCE_GROUPS do
		local node: Instance? = SoundService
		for _, name in path do
			node = if node ~= nil then node:FindFirstChild(name) else nil
		end
		if node ~= nil and node:IsA("SoundGroup") then
			table.insert(out, { Group = node, Base = node.Volume })
		end
	end
	ducked = out
	return out
end

local function restoreSilence()
	if silenceStop ~= nil then
		silenceStop()
		silenceStop = nil
	end
	const list = ducked
	if list ~= nil then
		for _, item in list do
			item.Group.Volume = item.Base
		end
	end
	ducked = nil
	silenceLevel = 1
end

const silence: Handler = function(_ctx, state, step, late)
	const list = silenceGroups()
	const from = math.clamp(step.Value or silenceLevel, 0, 1)
	const to = math.clamp(if type(step.To) == "number" then step.To else from, 0, 1)
	if silenceStop ~= nil then
		silenceStop()
	end
	silenceStop = ease(from, to, math.max((step.Duration or 0) - late, 0), function(v: number)
		silenceLevel = v
		for _, item in list do
			item.Group.Volume = item.Base * v
		end
		if v >= 0.999 and to >= 0.999 then
			restoreSilence()
		end
	end)
	state.Undo.silence = restoreSilence
end

-- A piece of Scene/Kit (TASK-586)
export type KitPiece = {
	Register: (handle: (kind: Content.HorrorStepKind, handler: Handler) -> (), camera: Camera?) -> (),
}

const Kits = {}

-- Called once by AnomalyController after Scene.Start (needs CameraController).
function Kits.Register(handle: (kind: Content.HorrorStepKind, handler: Handler) -> (), camera: Camera?)
	cameraRef = camera
	if camera ~= nil then
		for kind, handler in cameraHandlers(camera) do
			handle(kind :: Content.HorrorStepKind, handler)
		end
	end
	handle("Vignette", vignette)
	handle("Heartbeat", heartbeat)
	handle("Cinema", cinemaStep)
	handle("Whispers", whispers)
	handle("Door", door)
	handle("Shadow", shadow)
	handle("Actor", actor)
	handle("Roof", roofStepHandler)
	handle("HeadDown", headDown)
	handle("Grade", grade)
	handle("Blur", blur)
	handle("Silence", silence)
	-- TASK-586: one module per new piece in Scene/Kit (Pose, Prop, Glass, Glare, Silhouette, Lantern...), each returning
	-- { Register = function(handle, camera) }, so the pieces are written in parallel without sharing this file
	const folder = script.Parent:FindFirstChild("Kit")
	for _, child in if folder ~= nil then folder:GetChildren() else {} do
		if child:IsA("ModuleScript") then
			const piece = (require :: any)(child) :: KitPiece
			piece.Register(handle, camera)
		end
	end
end

-- The camera kit given to Register (Effects/ANM-019 punches the view of the caught player with it); nil before
function Kits.Camera(): Camera?
	return cameraRef
end

-- Where the roof walk is now (the flat point of its last step, at the walk's height), or nil when no Roof run is live.
-- Effects/ANM-019 hangs the stain, the prints and the drips under it.
function Kits.RoofAt(): Vector3?
	for _, run in roofRuns do
		return roofPoint(run, run.At)
	end
	return nil
end

-- TASK-593: the walk is over (Effects/ANM-019 when the record leaves Signal / Active): every Roof run stops stepping
-- and its ringing steps are cut. A later Thud / Leave step of the scene still plays (the jump off, the run away).
function Kits.RoofStop()
	for _, run in roofRuns do
		roofHush(run)
	end
end

return table.freeze(Kits)
