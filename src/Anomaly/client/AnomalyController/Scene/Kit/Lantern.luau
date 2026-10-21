--!strict
--[[
	Lantern step (TASK-589; design/horror-cinematic.md §11.3): the blackout's small lights made a piece every scene can
	use. Local only, undone when the run ends.
	  Target "Glow"    the soft white light around the local player (R11, the blackout's GLOW): Value = range in studs
	                   (0 = goes out), To = brightness (default GLOW_BRIGHTNESS), faded over Duration. Follows a respawn.
	  Target "Beacon"  the way out shown in the dark (R5, the breaker's beacon): a Mustard light pulsing at Point and a
	                   Highlight over the model nearest to it, seen through walls. Value = 0 takes it away; Duration = s
	                   it stays (nil = until the run ends).
	  Target "Eyes"    two white eyes that light what is in front of them (ANM-013, the inverse of the glow): at Point,
	                   facing the local player; Value = light range (default EYES_RANGE); Duration = s (nil = run end).
	                   Honours Step.Seen (Scene/Seen).
	PROVISIONAL (TASK-589): every number until the owner's Play.
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

-- Glow (the blackout's numbers, Effects/ANM-020)
const GLOW_NAME = "SceneLantern_Glow"
const GLOW_RANGE = 5.6
const GLOW_BRIGHTNESS = 0.9
const GLOW_COLOR = Color3.fromHex("#EEF2FF")

-- Beacon (house Mustard, never alert red)
const BEACON_NAME = "SceneLantern_Beacon"
const BEACON_RANGE = 5
const BEACON_BRIGHTNESS = 0.9
const BEACON_PULSE = 1.6 -- s per pulse
const BEACON_COLOR = Color3.fromHex("#E8B23A")
const BEACON_SEARCH = 6 -- studs around Point for the model the Highlight wraps
const HIGHLIGHT_FILL = 0.75

-- Eyes
const EYES_NAME = "SceneLantern_Eyes"
const EYES_RANGE = 10
const EYES_BRIGHTNESS = 1.6
const EYES_COLOR = Color3.fromHex("#F4F1E8")
const EYES_GAP = 0.32 -- studs between the two eyes
const EYES_SIZE = 0.16
const EYES_HEIGHT = 5 -- studs over Point when the point is on the floor

const DEFAULT_FADE = 0.4

local function rootOf(): BasePart?
	const character = Players.LocalPlayer.Character
	const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local function carrier(ctx: Effect.Context, name: string, at: CFrame, size: Vector3): Part
	const part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = at
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = ctx.Folder()
	return part
end

-- Glow ------------------------------------------------------------------------------------------------------------------

type Glow = { Light: PointLight, Follow: RBXScriptConnection }

const glows: { [State]: Glow } = {}

local function dropGlow(state: State)
	const glow = glows[state]
	if glow == nil then
		return
	end
	glows[state] = nil
	glow.Follow:Disconnect()
	glow.Light:Destroy()
end

local function glowStep(state: State, step: Step, late: number)
	const range = step.Value or GLOW_RANGE
	const brightness = if type(step.To) == "number" then step.To else GLOW_BRIGHTNESS
	const fade = math.max((step.Duration or DEFAULT_FADE) - late, 0)
	local glow = glows[state]
	if range <= 0 then
		if glow == nil then
			return
		end
		const light = glow.Light
		const tween = TweenService:Create(light, TweenInfo.new(fade), { Brightness = 0 })
		tween.Completed:Once(function()
			if glows[state] == glow then
				dropGlow(state)
			end
		end)
		tween:Play()
		return
	end
	if glow == nil then
		const light = Instance.new("PointLight")
		light.Name = GLOW_NAME
		light.Color = GLOW_COLOR
		light.Shadows = false
		light.Brightness = 0
		light.Range = range
		const created: Glow = {
			Light = light,
			-- follows the local character (a respawn too)
			Follow = RunService.Heartbeat:Connect(function()
				const root = rootOf()
				if root ~= nil and light.Parent ~= root then
					light.Parent = root
				end
			end),
		}
		glows[state] = created
		glow = created
		state.Undo["lantern:glow"] = function()
			dropGlow(state)
		end
	end
	const live = glow :: Glow
	live.Light.Parent = rootOf()
	TweenService:Create(live.Light, TweenInfo.new(fade), { Range = range, Brightness = brightness }):Play()
end

-- Beacon ----------------------------------------------------------------------------------------------------------------

type Beacon = { Part: Part, Light: PointLight, Highlight: Highlight?, Pulse: RBXScriptConnection }

const beacons: { [State]: { [string]: Beacon } } = {}

local function dropBeacon(state: State, point: string)
	const list = beacons[state]
	const beacon = if list ~= nil then list[point] else nil
	if list == nil or beacon == nil then
		return
	end
	list[point] = nil
	beacon.Pulse:Disconnect()
	if beacon.Highlight ~= nil then
		beacon.Highlight:Destroy()
	end
	beacon.Part:Destroy()
end

-- The model the Highlight wraps: the nearest anchored part around the point that is not a character, and its model
local function adorneeNear(ctx: Effect.Context, at: Vector3): Instance?
	local best: BasePart? = nil
	local bestDistance = BEACON_SEARCH
	const params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ctx.Folder() }
	for _, part in Workspace:GetPartBoundsInRadius(at, BEACON_SEARCH, params) do
		const owner = part:FindFirstAncestorWhichIsA("Model")
		if owner ~= nil and owner:FindFirstChildWhichIsA("Humanoid") ~= nil then
			continue -- never a character
		end
		const distance = (part.Position - at).Magnitude
		if distance < bestDistance then
			best, bestDistance = part, distance
		end
	end
	if best == nil then
		return nil
	end
	const model = best:FindFirstAncestorWhichIsA("Model")
	-- a whole map is not a prop: wrap only a small model
	if model ~= nil and model:GetExtentsSize().Magnitude < BEACON_SEARCH * 3 then
		return model
	end
	return best
end

local function beaconStep(ctx: Effect.Context, state: State, step: Step, late: number)
	const id = step.Point
	if id == nil then
		return
	end
	if (step.Value or 1) <= 0 then
		dropBeacon(state, id)
		return
	end
	const at = ctx.Point(id)
	if at == nil then
		return
	end
	dropBeacon(state, id)
	const part = carrier(ctx, BEACON_NAME, at, Vector3.one * 0.2)
	const light = Instance.new("PointLight")
	light.Name = BEACON_NAME
	light.Range = BEACON_RANGE
	light.Color = BEACON_COLOR
	light.Shadows = false
	light.Parent = part
	local highlight: Highlight? = nil
	const adornee = adorneeNear(ctx, at.Position)
	if adornee ~= nil then
		const created = Instance.new("Highlight")
		created.Name = BEACON_NAME
		created.FillColor = BEACON_COLOR
		created.OutlineColor = BEACON_COLOR
		created.FillTransparency = HIGHLIGHT_FILL
		created.OutlineTransparency = 0
		created.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		created.Adornee = adornee
		created.Parent = part
		highlight = created
	end
	const beacon: Beacon = {
		Part = part,
		Light = light,
		Highlight = highlight,
		Pulse = RunService.RenderStepped:Connect(function()
			const wave = 0.5 + 0.5 * math.sin(os.clock() * math.pi * 2 / BEACON_PULSE)
			light.Brightness = BEACON_BRIGHTNESS * (0.35 + 0.65 * wave)
			if highlight ~= nil then
				highlight.FillTransparency = HIGHLIGHT_FILL + (1 - HIGHLIGHT_FILL) * 0.6 * (1 - wave)
			end
		end),
	}
	local list = beacons[state]
	if list == nil then
		const created: { [string]: Beacon } = {}
		beacons[state] = created
		list = created
		state.Undo["lantern:beacon"] = function()
			const all = beacons[state]
			if all == nil then
				return
			end
			for point in all do
				dropBeacon(state, point)
			end
			beacons[state] = nil
		end
	end
	(list :: { [string]: Beacon })[id] = beacon
	const duration = step.Duration
	if duration ~= nil then
		task.delay(math.max(duration - late, 0), function()
			const current = beacons[state]
			if current ~= nil and current[id] == beacon then
				dropBeacon(state, id)
			end
		end)
	end
end

-- Eyes ------------------------------------------------------------------------------------------------------------------

local function eyesStep(ctx: Effect.Context, state: State, step: Step, late: number)
	const id = step.Point
	const at = if id ~= nil then ctx.Point(id) else nil
	if at == nil then
		return
	end
	const root = rootOf()
	const from = at.Position + Vector3.new(0, EYES_HEIGHT, 0)
	const towards = if root ~= nil then Vector3.new(root.Position.X, from.Y, root.Position.Z) else from + at.LookVector
	const face = if (towards - from).Magnitude > 0.01 then CFrame.lookAt(from, towards) else CFrame.new(from)
	const holder = carrier(ctx, EYES_NAME, face, Vector3.new(EYES_GAP * 2, EYES_SIZE, EYES_SIZE))
	const balls: { Part } = {}
	for side = -1, 1, 2 do
		const ball = Instance.new("Part")
		ball.Name = EYES_NAME
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.one * EYES_SIZE
		ball.Material = Enum.Material.Neon
		ball.Color = EYES_COLOR
		ball.Anchored = true
		ball.CanCollide = false
		ball.CanQuery = false
		ball.CanTouch = false
		ball.CastShadow = false
		ball.CFrame = face * CFrame.new(side * EYES_GAP / 2, 0, 0)
		ball.Parent = holder
		table.insert(balls, ball)
	end
	const light = Instance.new("SpotLight")
	light.Name = EYES_NAME
	light.Face = Enum.NormalId.Front
	light.Angle = 70
	light.Range = step.Value or EYES_RANGE
	light.Brightness = EYES_BRIGHTNESS
	light.Color = EYES_COLOR
	light.Shadows = true
	light.Parent = holder
	const stop = Seen.Bind(step.Seen, function(visible)
		for _, ball in balls do
			ball.Transparency = if visible then 0 else 1
		end
		light.Enabled = visible
	end)
	const tag = `lantern:eyes:{id}:{step.At}`
	local function drop()
		if state.Undo[tag] == nil then
			return
		end
		state.Undo[tag] = nil
		stop()
		holder:Destroy()
	end
	state.Undo[tag] = drop
	const duration = step.Duration
	if duration ~= nil then
		task.delay(math.max(duration - late, 0), drop)
	end
end

const lantern: Handler = function(ctx, state, step, late)
	const target = step.Target or "Glow"
	if target == "Glow" then
		glowStep(state, step, late)
	elseif target == "Beacon" then
		beaconStep(ctx, state, step, late)
	elseif target == "Eyes" then
		eyesStep(ctx, state, step, late)
	end
end

return table.freeze({
	Register = function(handle: (kind: Content.HorrorStepKind, handler: Handler) -> (), _camera: any)
		handle("Lantern", lantern)
	end,
})
