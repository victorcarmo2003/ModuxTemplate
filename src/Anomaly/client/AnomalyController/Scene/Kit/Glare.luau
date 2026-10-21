--!strict
--[[
	Glare step (TASK-588; design/horror-cinematic.md §3.4, §11.3): headlights through the glass. Local only, undone when
	the run ends.
	  Target "Flash"  the high beam at the MapPoint Point: a hard white light there that dies over Duration (default
	                  FLASH_TIME); if the point is in this client's view (on screen, nothing opaque between), the screen
	                  is blinded too: bloom, a washed grade and a blur of Value (default FLASH_BLUR, <= Rules.MaxBlur)
	                  easing back to nothing over Duration. Who is looking pays, who is not only sees the room light up
	  Target "Sweep"  a car's lights crossing the room: a SpotLight at Point (outside the window) aimed at the MapPoint To
	                  (default the point's look vector), tilted up to the ceiling, sweeping from -Value to +Value degrees
	                  (default SWEEP_ANGLE) over Duration (default SWEEP_TIME), fading in and out. The window frames throw
	                  their shadows across the ceiling as it goes
	PROVISIONAL (TASK-588): every number until the owner's Play.
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)
local Effect = require(script.Parent.Parent.Parent.Effect)
local Steps = require(script.Parent.Parent.Steps)

type Step = Content.HorrorStep
type State = Steps.State
type Handler = Steps.Handler

const NAME = "SceneGlare"
const BEAM_COLOR = Color3.fromHex("#F4F6FF") -- cold white, as the kit's high beam

-- Flash
const FLASH_TIME = 0.6
const FLASH_BLUR = 6
const FLASH_RANGE = 30
const FLASH_BRIGHTNESS = 6
const FLASH_LIGHT_HOLD = 1.5 -- the world light lasts this many times the screen blind
const BLOOM_INTENSITY = 2.4
const BLOOM_SIZE = 56
const BLOOM_THRESHOLD = 0.6
const WASH_BRIGHTNESS = 0.35
const WASH_CONTRAST = -0.25
const WASH_SATURATION = -0.6
const VIEW_RANGE = 160 -- studs: farther is a light in the distance, no blind
const OPAQUE = 0.3 -- a part more see-through than this does not hide the beam (glass)

-- Sweep
const SWEEP_ANGLE = 45 -- degrees each side
const SWEEP_TIME = 3
const SWEEP_PITCH = 14 -- degrees up: it lands on the ceiling
const SWEEP_RANGE = 45
const SWEEP_BRIGHTNESS = 4
const SWEEP_CONE = 38 -- SpotLight Angle
const SWEEP_FADE = 0.35

type Flash = { Carrier: Part, Screen: { Instance } }
type Run = { Flashes: { Flash }, Sweeps: { Part } }

const runs: { [State]: Run } = {}

local function dropRun(state: State)
	const run = runs[state]
	if run == nil then
		return
	end
	runs[state] = nil
	for _, flash in run.Flashes do
		flash.Carrier:Destroy()
		for _, effect in flash.Screen do
			effect:Destroy()
		end
	end
	for _, carrier in run.Sweeps do
		carrier:Destroy()
	end
end

local function runOf(state: State): Run
	const existing = runs[state]
	if existing ~= nil then
		return existing
	end
	const run: Run = { Flashes = {}, Sweeps = {} }
	runs[state] = run
	state.Undo["glare"] = function()
		dropRun(state)
	end
	return run
end

local function carrier(ctx: Effect.Context, at: CFrame): Part
	const part = Instance.new("Part")
	part.Name = NAME
	part.Size = Vector3.one * 0.2
	part.CFrame = at
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = ctx.Folder()
	return part
end

-- Is the point in this client's view: on screen, near enough, nothing opaque in between (glass lets it through)
local function inView(ctx: Effect.Context, at: Vector3): boolean
	const camera = Workspace.CurrentCamera
	if camera == nil then
		return false
	end
	const from = camera.CFrame.Position
	const towards = at - from
	if towards.Magnitude > VIEW_RANGE then
		return false
	end
	const _, onScreen = camera:WorldToViewportPoint(at)
	if not onScreen then
		return false
	end
	const ignore: { Instance } = { ctx.Folder() }
	for _, player in Players:GetPlayers() do
		if player.Character ~= nil then
			table.insert(ignore, player.Character)
		end
	end
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	-- walk through the see-through parts on the way (at most a few panes)
	local origin = from
	for _ = 1, 4 do
		const left = at - origin
		if left.Magnitude < 0.5 then
			return true
		end
		const hit = Workspace:Raycast(origin, left, params)
		if hit == nil then
			return true
		end
		const part = hit.Instance
		if part.Transparency < OPAQUE and part.Material ~= Enum.Material.Glass then
			return false
		end
		table.insert(ignore, part)
		params.FilterDescendantsInstances = ignore
		origin = hit.Position
	end
	return true
end

local function fadeOut(instance: Instance, time: number, goal: { [string]: any })
	const tween = TweenService:Create(instance, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	tween:Play()
end

local function flash(ctx: Effect.Context, state: State, step: Step, late: number)
	const id = step.Point
	const at = if id ~= nil then ctx.Point(id) else nil
	if at == nil then
		return
	end
	const duration = math.max((step.Duration or FLASH_TIME) - late, 0.1)
	const run = runOf(state)
	-- the room lights up white, whoever looks or not
	const part = carrier(ctx, at)
	const light = Instance.new("PointLight")
	light.Name = NAME
	light.Color = BEAM_COLOR
	light.Range = FLASH_RANGE
	light.Brightness = FLASH_BRIGHTNESS
	light.Shadows = true
	light.Parent = part
	fadeOut(light, duration * FLASH_LIGHT_HOLD, { Brightness = 0 })
	const entry: Flash = { Carrier = part, Screen = {} }
	table.insert(run.Flashes, entry)
	-- who looks at it is blinded
	if inView(ctx, at.Position) then
		const bloom = Instance.new("BloomEffect")
		bloom.Name = NAME
		bloom.Intensity = BLOOM_INTENSITY
		bloom.Size = BLOOM_SIZE
		bloom.Threshold = BLOOM_THRESHOLD
		bloom.Parent = Lighting
		fadeOut(bloom, duration, { Intensity = 0 })
		const wash = Instance.new("ColorCorrectionEffect")
		wash.Name = NAME
		wash.Brightness = WASH_BRIGHTNESS
		wash.Contrast = WASH_CONTRAST
		wash.Saturation = WASH_SATURATION
		wash.Parent = Lighting
		fadeOut(wash, duration, { Brightness = 0, Contrast = 0, Saturation = 0 })
		const blur = Instance.new("BlurEffect")
		blur.Name = NAME
		blur.Size = math.clamp(step.Value or FLASH_BLUR, 0, Content.HorrorScenes.Rules.MaxBlur)
		blur.Parent = Lighting
		fadeOut(blur, duration, { Size = 0 })
		entry.Screen = { bloom, wash, blur }
	end
	task.delay(duration * FLASH_LIGHT_HOLD + 0.1, function()
		if runs[state] ~= run then
			return
		end
		const index = table.find(run.Flashes, entry)
		if index ~= nil then
			table.remove(run.Flashes, index)
		end
		part:Destroy()
		for _, effect in entry.Screen do
			effect:Destroy()
		end
	end)
end

local function sweep(ctx: Effect.Context, state: State, step: Step, late: number)
	const id = step.Point
	const at = if id ~= nil then ctx.Point(id) else nil
	if at == nil then
		return
	end
	const duration = math.max(step.Duration or SWEEP_TIME, 0.2)
	if late >= duration then
		return
	end
	const aimId = if type(step.To) == "string" then step.To else nil
	const aim = if aimId ~= nil then ctx.Point(aimId) else nil
	const from = at.Position
	const towards = if aim ~= nil then aim.Position - from else at.LookVector
	const flat = Vector3.new(towards.X, 0, towards.Z)
	const base = if flat.Magnitude > 1e-3 then CFrame.lookAt(from, from + flat) else CFrame.new(from)
	const half = math.rad(step.Value or SWEEP_ANGLE)
	const pitch = math.rad(SWEEP_PITCH)
	const run = runOf(state)
	const part = carrier(ctx, base)
	const light = Instance.new("SpotLight")
	light.Name = NAME
	light.Face = Enum.NormalId.Front
	light.Color = BEAM_COLOR
	light.Range = SWEEP_RANGE
	light.Angle = SWEEP_CONE
	light.Shadows = true
	light.Brightness = 0
	light.Parent = part
	table.insert(run.Sweeps, part)
	const started = os.clock() - late
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function()
		const t = os.clock() - started
		if part.Parent == nil or t >= duration then
			if connection ~= nil then
				connection:Disconnect()
			end
			const index = table.find(run.Sweeps, part)
			if index ~= nil then
				table.remove(run.Sweeps, index)
			end
			part:Destroy()
			return
		end
		const k = t / duration
		-- eased across, quick in the middle like a car turning past
		const eased = (1 - math.cos(k * math.pi)) / 2
		part.CFrame = base * CFrame.Angles(0, half - 2 * half * eased, 0) * CFrame.Angles(pitch, 0, 0)
		const fade = math.min(t / SWEEP_FADE, (duration - t) / SWEEP_FADE, 1)
		light.Brightness = SWEEP_BRIGHTNESS * math.max(fade, 0)
	end)
end

const glare: Handler = function(ctx, state, step, late)
	const target = step.Target or "Flash"
	if target == "Flash" then
		flash(ctx, state, step, late)
	elseif target == "Sweep" then
		sweep(ctx, state, step, late)
	end
end

return table.freeze({
	Register = function(handle: (kind: Content.HorrorStepKind, handler: Handler) -> (), _camera: any)
		handle("Glare", glare)
	end,
})
