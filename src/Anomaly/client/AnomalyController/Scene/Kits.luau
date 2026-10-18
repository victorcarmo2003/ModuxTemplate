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
	  Shadow               a dark band slides along the light under that door (DOOR-GAP-B, TASK-465) and dims it
	  Actor                two white eyes at the step's MapPoint for Duration s (the window, for whoever did not hide)
	Presentation only, client side, nothing replicated. Every handler registers its undo in state.Undo so the end of the
	run (record gone) leaves the world as it was.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)
local Effect = require(script.Parent.Parent.Effect)
local Screen = require(script.Parent.Parent.Effects.Kit.Screen)
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
	state.Undo.whispers = Whispers.Ramp(seconds, math.max(from, 0.05), math.max(to, 0.05))
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
	const duration = math.max(step.Duration or 1.2, 0.2)
	-- the band crosses the long side of the gap
	const long = if gap.Size.X >= gap.Size.Z then gap.CFrame.RightVector else gap.CFrame.LookVector
	const length = math.max(gap.Size.X, gap.Size.Z)
	const width = math.min(gap.Size.X, gap.Size.Z)
	const band = Instance.new("Part")
	band.Name = "HorrorScene_Shadow"
	band.Anchored = true
	band.CanCollide = false
	band.CanQuery = false
	band.CanTouch = false
	band.CastShadow = false
	band.Material = Enum.Material.SmoothPlastic
	band.Color = SHADOW_COLOR
	band.Transparency = 0.12
	band.Size = if gap.Size.X >= gap.Size.Z then Vector3.new(length * 0.3, 0.03, width + 0.04) else Vector3.new(width + 0.04, 0.03, length * 0.3)
	const from = gap.CFrame * CFrame.new(0, 0.012, 0) + (-long * length * 0.65)
	band.CFrame = from
	band.Parent = ctx.Folder()
	const light = gap:FindFirstChildWhichIsA("Light")
	const brightness = if light ~= nil then light.Brightness else 0
	if light ~= nil then
		TweenService:Create(light, TweenInfo.new(duration * 0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, true), { Brightness = brightness * 0.25 }):Play()
	end
	TweenService:Create(band, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = from + long * length * 1.3 }):Play()
	local done = false
	local function stop()
		if done then
			return
		end
		done = true
		band:Destroy()
		if light ~= nil and light.Parent ~= nil then
			light.Brightness = brightness
		end
	end
	task.delay(duration + 0.05, stop)
	state.Undo[`shadow:{gap:GetFullName()}`] = stop
end

-- Eyes at a MapPoint ----------------------------------------------------------------------------------------------------

const actor: Handler = function(ctx, state, step, _late)
	const at = pointOf(ctx, step.Point)
	if at == nil then
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
	task.delay(math.max(step.Duration or 1, 0.1), stop)
	state.Undo[tag] = stop
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
