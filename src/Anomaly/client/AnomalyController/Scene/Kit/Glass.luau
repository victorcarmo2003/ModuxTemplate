--!strict
--[[
	Glass step (TASK-588; design/horror-cinematic.md §3.3, §3.4, §3.11, §11.3): the pane nearest the step's MapPoint
	(Point) does something only this client sees. The pane = the thin see-through part (Glass material, a part between
	clear and opaque, or one named glass / window) within GLASS_SEARCH studs of the point; none found = an invisible pane
	at the point, facing the point's look vector, so the marks and the sounds still land there. Local only, undone when
	the run ends (the moved parts go back home, the marks go away).
	  Target "Fog"     the glass mists over at the point's height (a breath from the other side): Value = how opaque
	                   (default FOG_OPACITY; 0 = clears), faded over Duration; it breathes slowly while it stays
	  Target "Knock"   a fingertip on the glass: Value = taps (default 1), the pane ticks on each; Sound = override
	  Target "Bang"    a blow: the pane flexes (decaying wobble along its normal) and dust falls from its top edge;
	                   Value = strength (default 1)
	  Target "Hand"    a palm mark pressed at the point slides down and fades over Duration (default HAND_TIME)
	  Target "Paw"     (TASK-593, ANM-021) a blow that leaves a BLACK ANIMAL PAW PRINT on the glass: the pane flexes and
	                   sways (shake + a slower rock), dust falls, the Bang sound, and a paw (pad, four toes, claws) is
	                   pressed at a seeded spot around the point; the prints pile up and stay until the run ends.
	                   Value = strength (default 1)
	  Target "Rattle"  the drive-thru shutter (the part / small model named shutter / blind nearest the point, else the
	                   pane) shakes for Duration (default RATTLE_TIME); Value = strength (default 1)
	To = "Misted" (any Target but Fog): only if that pane is misted now - the thing was really at the glass (ANM-006:
	the palm after the window shut, never when it faded away down the street).
	Every Target plays its default sound at the pane (Sound = another Content.Sounds key; "" = none). The palm squeak
	and the breath on the glass use placeholders until palm_squeak / glass_breath / glass_knock have an Id
	(sound-list.md §5.21).
	PROVISIONAL (TASK-588): every number until the owner's Play.
]]
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

-- AudioController PlayOptions (structural copy, as Scene/Steps)
type PlayOptions = { Volume: number?, Speed: number?, Vary: number?, Scare: boolean? }

const GLASS_SEARCH = 10 -- studs from the MapPoint to the pane
const SHUTTER_SEARCH = 8 -- studs from the MapPoint to the shutter
const MAX_THICK = 0.8 -- studs: thicker is a wall, not a pane
const MIN_FACE = 2 -- studs^2 of face at least
const SMALL_MODEL = 24 -- studs: a model bigger than this is the building, not the shutter
const GLASS_WORDS = { "glass", "window", "vidro", "pane" }
const SHUTTER_WORDS = { "shut", "blind", "persiana", "shutter" }
const FALLBACK_SIZE = Vector2.new(5, 4) -- studs of the invisible pane

const OVERLAY_NAME = "SceneGlass"
const PIXELS = 40 -- per stud on the overlay
const MARK_COLOR = Color3.fromHex("#DDE2EA") -- condensation, palm mark
const DUST_COLOR = Color3.fromHex("#B9AE98")

-- Fog
const FOG_OPACITY = 0.55
const FOG_SIZE = 2.6 -- studs across
const FOG_FADE = 1.5
const FOG_BREATH = 2.6 -- s per breath
const FOG_BREATH_DEPTH = 0.12 -- share of the opacity the breath takes
const MISTED = 0.05 -- FogLevel from which a pane counts as misted (To = "Misted")

-- Knock / Bang / Rattle
const TAP_GAP = 0.17 -- s between two taps
const TAP_AMPLITUDE = 0.015 -- studs
const TAP_TIME = 0.08
const BANG_AMPLITUDE = 0.12 -- studs at strength 1
const BANG_TIME = 0.45
const BANG_FREQUENCY = 14 -- Hz
const DUST_COUNT = 14 -- particles at strength 1
const RATTLE_TIME = 0.5
const RATTLE_AMPLITUDE = 0.06
const RATTLE_FREQUENCY = 22

-- Paw (TASK-593)
const PAW_COLOR = Color3.fromHex("#060507")
const PAW_OPACITY = 0.9
const PAW_SIZE = 1.15 -- studs across at strength 1
const PAW_SPREAD = Vector2.new(0.36, 0.26) -- share of the pane's width / height around the point the prints land on
const PAW_TILT = 30 -- degrees each print may turn
const PAW_MAX = 12 -- prints per pane at most (the oldest go)
const PAW_SWAY_AMPLITUDE = 0.09 -- studs of the slow rock at strength 1
const PAW_SWAY_FREQUENCY = 5 -- Hz
const PAW_SWAY_TIME = 0.9 -- s

-- Hand
const HAND_TIME = 2.5
const HAND_SLIDE = 1.6 -- studs it slides down
const HAND_OPACITY = 0.55
const HAND_WIDTH = 0.95 -- studs
const HAND_HEIGHT = 1.35

const SOUNDS: { [string]: string } = {
	Knock = "door_knock", -- glass_knock when it has an Id
	Bang = "window_slam",
	Hand = "door_creak", -- palm_squeak when it has an Id
	Rattle = "handle_rattle",
	Paw = "window_slam",
}
const SOUND_VOLUME: { [string]: number } = { Knock = 0.45, Bang = 1, Hand = 0.5, Rattle = 0.9, Paw = 1 }

-- A pane: the glass part (nil = invisible fallback), a frame whose -Z is the pane normal, and its face size
type Pane = {
	Part: BasePart?,
	Frame: CFrame,
	Width: number,
	Height: number,
	Overlay: Part?,
	Guis: { SurfaceGui },
	Fog: { Frame },
	FogLevel: number,
	FogTween: NumberValue?,
	Dust: ParticleEmitter?,
	Paws: { GuiObject }, -- TASK-593: the paw prints on it, oldest first (both faces)
}

type Run = {
	Live: boolean,
	Panes: { [string]: Pane }, -- by MapPoint id
	-- what is shaking now and where it goes back (taken when a shake starts on a still thing: the shutter may have been
	-- closed / opened between two shakes)
	Homes: { [Instance]: CFrame },
	Jitters: { [Instance]: { Until: number, Started: number, Amplitude: number, Frequency: number, Axis: Vector3, Decay: boolean } },
	Pulse: RBXScriptConnection?,
}

const runs: { [State]: Run } = {}

local function hasWord(name: string, words: { string }): boolean
	const lower = string.lower(name)
	for _, word in words do
		if string.find(lower, word, 1, true) ~= nil then
			return true
		end
	end
	return false
end

local function isCharacter(part: BasePart): boolean
	const model = part:FindFirstAncestorWhichIsA("Model")
	return model ~= nil and model:FindFirstChildWhichIsA("Humanoid") ~= nil
end

local function overlap(ctx: Effect.Context, at: Vector3, radius: number): { BasePart }
	const params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	const ignore: { Instance } = { ctx.Folder() }
	for _, player in Players:GetPlayers() do
		if player.Character ~= nil then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	return Workspace:GetPartBoundsInRadius(at, radius, params)
end

-- The pane's frame: -Z along the thinnest axis (the normal), Y along the most vertical of the other two
local function frameOf(part: BasePart): (CFrame, number, number, number)
	const size = part.Size
	const cf = part.CFrame
	type Axis = { Vector: Vector3, Length: number }
	const axes: { Axis } = {
		{ Vector = cf.RightVector, Length = size.X },
		{ Vector = cf.UpVector, Length = size.Y },
		{ Vector = cf.LookVector, Length = size.Z },
	}
	table.sort(axes, function(a: Axis, b: Axis): boolean
		return a.Length < b.Length
	end)
	const normal = axes[1]
	local up, side = axes[2], axes[3]
	if math.abs(side.Vector.Y) > math.abs(up.Vector.Y) then
		up, side = side, up
	end
	const upVector: Vector3 = if up.Vector.Y < 0 then -up.Vector else up.Vector
	return CFrame.lookAt(cf.Position, cf.Position + normal.Vector, upVector), side.Length, up.Length, normal.Length
end

local function isGlass(part: BasePart): boolean
	if part.Material == Enum.Material.Glass then
		return true
	end
	if part.Transparency >= 0.3 and part.Transparency < 0.98 then
		return true
	end
	return hasWord(part.Name, GLASS_WORDS)
end

local function findGlass(ctx: Effect.Context, at: Vector3): BasePart?
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, part in overlap(ctx, at, GLASS_SEARCH) do
		if isCharacter(part) or not isGlass(part) then
			continue
		end
		const _, width, height, thick = frameOf(part)
		if thick > MAX_THICK or width * height < MIN_FACE then
			continue
		end
		-- distance to the pane's face, not its centre (a long shop window)
		const flat = part.CFrame:PointToObjectSpace(at)
		const half = part.Size / 2
		const nearest = Vector3.new(
			math.clamp(flat.X, -half.X, half.X),
			math.clamp(flat.Y, -half.Y, half.Y),
			math.clamp(flat.Z, -half.Z, half.Z)
		)
		const distance = (flat - nearest).Magnitude
		if distance < bestDistance then
			best, bestDistance = part, distance
		end
	end
	return best
end

-- The shutter: a part / small model named like one; else nil (the pane rattles)
local function findShutter(ctx: Effect.Context, at: Vector3): Instance?
	local best: Instance? = nil
	local bestDistance = math.huge
	for _, part in overlap(ctx, at, SHUTTER_SEARCH) do
		if isCharacter(part) then
			continue
		end
		local named: Instance? = nil
		if hasWord(part.Name, SHUTTER_WORDS) then
			named = part
		end
		const model = part:FindFirstAncestorWhichIsA("Model")
		if model ~= nil and hasWord(model.Name, SHUTTER_WORDS) and model:GetExtentsSize().Magnitude < SMALL_MODEL then
			named = model
		end
		if named == nil then
			continue
		end
		const distance = (part.Position - at).Magnitude
		if distance < bestDistance then
			best, bestDistance = named, distance
		end
	end
	return best
end

-- Run / pane -----------------------------------------------------------------------------------------------------------

local function pivotOf(thing: Instance): CFrame?
	if thing:IsA("BasePart") then
		return thing.CFrame
	elseif thing:IsA("Model") then
		return thing:GetPivot()
	end
	return nil
end

local function place(thing: Instance, at: CFrame)
	if thing:IsA("BasePart") then
		thing.CFrame = at
	elseif thing:IsA("Model") then
		thing:PivotTo(at)
	end
end

local function dropRun(state: State)
	const run = runs[state]
	if run == nil then
		return
	end
	runs[state] = nil
	run.Live = false
	if run.Pulse ~= nil then
		run.Pulse:Disconnect()
	end
	for thing, home in run.Homes do
		if thing.Parent ~= nil then
			place(thing, home)
		end
	end
	for _, pane in run.Panes do
		if pane.FogTween ~= nil then
			pane.FogTween:Destroy()
		end
		if pane.Overlay ~= nil then
			pane.Overlay:Destroy()
		end
	end
end

-- One Heartbeat per run: the jitters (around each thing's home) and the fog breathing
local function pulse(run: Run)
	const now = os.clock()
	for thing, jitter in run.Jitters do
		const home = run.Homes[thing]
		if home == nil or thing.Parent == nil then
			run.Jitters[thing] = nil
			continue
		end
		if now >= jitter.Until then
			run.Jitters[thing] = nil
			run.Homes[thing] = nil
			place(thing, home)
			continue
		end
		const t = now - jitter.Started
		const life = jitter.Until - jitter.Started
		const fade = if jitter.Decay then 1 - t / life else 1
		const offset = math.sin(t * jitter.Frequency * math.pi * 2) * jitter.Amplitude * fade
		place(thing, home + jitter.Axis * offset)
	end
	const breath = 1 - FOG_BREATH_DEPTH * (0.5 + 0.5 * math.sin(now * math.pi * 2 / FOG_BREATH))
	for _, pane in run.Panes do
		if pane.FogLevel <= 0 then
			continue
		end
		for _, patch in pane.Fog do
			patch.BackgroundTransparency = 1 - pane.FogLevel * breath
		end
	end
end

local function runOf(state: State): Run
	const existing = runs[state]
	if existing ~= nil then
		return existing
	end
	const run: Run = { Live = true, Panes = {}, Homes = {}, Jitters = {}, Pulse = nil }
	run.Pulse = RunService.Heartbeat:Connect(function()
		pulse(run)
	end)
	runs[state] = run
	state.Undo["glass"] = function()
		dropRun(state)
	end
	return run
end

local function paneOf(ctx: Effect.Context, state: State, id: string): (Pane?, Vector3)
	const point = ctx.Point(id)
	if point == nil then
		return nil, Vector3.zero
	end
	const run = runOf(state)
	local pane = run.Panes[id]
	if pane == nil then
		const glass = findGlass(ctx, point.Position)
		local frame: CFrame
		local width: number, height: number
		if glass ~= nil then
			const found, w, h = frameOf(glass)
			frame, width, height = found, w, h
		else
			frame, width, height = point, FALLBACK_SIZE.X, FALLBACK_SIZE.Y
		end
		const created: Pane = {
			Part = glass,
			Frame = frame,
			Width = width,
			Height = height,
			Overlay = nil,
			Guis = {},
			Fog = {},
			FogLevel = 0,
			FogTween = nil,
			Dust = nil,
			Paws = {},
		}
		run.Panes[id] = created
		pane = created
	end
	return pane, point.Position
end

-- The local overlay that carries the marks, on both faces of the pane
local function overlayOf(ctx: Effect.Context, pane: Pane): Part
	const existing = pane.Overlay
	if existing ~= nil then
		return existing
	end
	const part = Instance.new("Part")
	part.Name = OVERLAY_NAME
	part.Size = Vector3.new(pane.Width, pane.Height, 0.05)
	part.CFrame = pane.Frame
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = ctx.Folder()
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		const gui = Instance.new("SurfaceGui")
		gui.Name = OVERLAY_NAME
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = PIXELS
		gui.LightInfluence = 0.6 -- dim in the dark, never glowing
		gui.ClipsDescendants = true
		gui.Adornee = part
		gui.Parent = part
		table.insert(pane.Guis, gui)
	end
	pane.Overlay = part
	return part
end

-- Where a world point lands on a face of the pane (scale coordinates of that face's gui)
local function onFace(pane: Pane, gui: SurfaceGui, at: Vector3): Vector2
	const flat = pane.Frame:PointToObjectSpace(at)
	const x = math.clamp(flat.X / pane.Width, -0.5, 0.5)
	const y = math.clamp(flat.Y / pane.Height, -0.5, 0.5)
	-- seen from the front (-Z) the gui runs towards -X; from the back towards +X
	const u = if gui.Face == Enum.NormalId.Front then 0.5 - x else 0.5 + x
	return Vector2.new(u, 0.5 - y)
end

local function surfacePoint(pane: Pane, at: Vector3): Vector3
	const flat = pane.Frame:PointToObjectSpace(at)
	return pane.Frame * Vector3.new(
		math.clamp(flat.X, -pane.Width / 2, pane.Width / 2),
		math.clamp(flat.Y, -pane.Height / 2, pane.Height / 2),
		0
	)
end

local function play(ctx: Effect.Context, target: string, step: Step, at: Vector3, volume: number?)
	const key = if step.Sound ~= nil then step.Sound else SOUNDS[target]
	if key == nil or key == "" then
		return
	end
	const opts: PlayOptions = { Volume = (volume or 1) * (SOUND_VOLUME[target] or 1) }
	ctx.Audio:Play(key, at, opts)
end

-- What moves for a shake: the glass part, or nothing (an invisible pane has nothing to move)
local function jitter(run: Run, thing: Instance?, axis: Vector3, amplitude: number, frequency: number, duration: number, decay: boolean)
	if thing == nil then
		return
	end
	if run.Jitters[thing] == nil or run.Homes[thing] == nil then
		const home = pivotOf(thing)
		if home == nil then
			return
		end
		run.Homes[thing] = home
	end
	const now = os.clock()
	run.Jitters[thing] = {
		Until = now + duration,
		Started = now,
		Amplitude = amplitude,
		Frequency = frequency,
		Axis = axis,
		Decay = decay,
	}
end

-- Targets --------------------------------------------------------------------------------------------------------------

local function fog(ctx: Effect.Context, pane: Pane, step: Step, at: Vector3, late: number)
	const level = math.clamp(step.Value or FOG_OPACITY, 0, 1)
	const fade = math.max((step.Duration or FOG_FADE) - late, 0)
	if #pane.Fog == 0 then
		if level <= 0 then
			return
		end
		overlayOf(ctx, pane)
		for _, gui in pane.Guis do
			const spot = onFace(pane, gui, at)
			const patch = Instance.new("Frame")
			patch.Name = "Fog"
			patch.AnchorPoint = Vector2.new(0.5, 0.5)
			patch.Position = UDim2.fromScale(spot.X, spot.Y)
			patch.Size = UDim2.fromOffset(FOG_SIZE * PIXELS, FOG_SIZE * 0.8 * PIXELS)
			patch.BackgroundColor3 = MARK_COLOR
			patch.BackgroundTransparency = 1
			patch.BorderSizePixel = 0
			const corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = patch
			-- soft edge: clear at the rim, misted in the middle
			const gradient = Instance.new("UIGradient")
			gradient.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.3, 0.35),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(0.7, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			})
			gradient.Parent = patch
			patch.Parent = gui
			table.insert(pane.Fog, patch)
		end
	end
	-- FogLevel eased through a NumberValue (the breathing reads it every frame)
	if pane.FogTween ~= nil then
		pane.FogTween:Destroy()
	end
	const value = Instance.new("NumberValue")
	value.Value = pane.FogLevel
	value.Changed:Connect(function(v: number)
		pane.FogLevel = v
		if v <= 0 then
			for _, patch in pane.Fog do
				patch.BackgroundTransparency = 1
			end
		end
	end)
	pane.FogTween = value
	if fade <= 0 then
		value.Value = level
	else
		TweenService:Create(value, TweenInfo.new(fade, Enum.EasingStyle.Sine), { Value = level }):Play()
	end
	if step.Sound ~= nil and step.Sound ~= "" then
		ctx.Audio:Play(step.Sound, surfacePoint(pane, at))
	end
end

local function knock(ctx: Effect.Context, run: Run, pane: Pane, step: Step, at: Vector3)
	const taps = math.max(math.floor(step.Value or 1), 1)
	const where = surfacePoint(pane, at)
	for index = 1, taps do
		task.delay((index - 1) * TAP_GAP, function()
			if not run.Live then
				return
			end
			play(ctx, "Knock", step, where)
			jitter(run, pane.Part, pane.Frame.LookVector, TAP_AMPLITUDE, 1 / (TAP_TIME * 2), TAP_TIME, true)
		end)
	end
end

local function dustOf(ctx: Effect.Context, pane: Pane): ParticleEmitter
	const existing = pane.Dust
	if existing ~= nil then
		return existing
	end
	const overlay = overlayOf(ctx, pane)
	const dust = Instance.new("ParticleEmitter")
	dust.Name = OVERLAY_NAME
	dust.Rate = 0
	dust.Color = ColorSequence.new(DUST_COLOR)
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0.04) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(0.8, 1.4)
	dust.Speed = NumberRange.new(0.2, 0.8)
	dust.SpreadAngle = Vector2.new(70, 20)
	dust.Acceleration = Vector3.new(0, -6, 0)
	dust.Drag = 1.5
	dust.LightInfluence = 1
	-- a line along the top edge, not a point: the box shape takes the size of its own thin part there
	dust.Shape = Enum.ParticleEmitterShape.Box
	dust.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	const strip = Instance.new("Part")
	strip.Name = OVERLAY_NAME
	strip.Size = Vector3.new(pane.Width * 0.9, 0.05, 0.05)
	strip.CFrame = pane.Frame * CFrame.new(0, pane.Height / 2, 0)
	strip.Transparency = 1
	strip.Anchored = true
	strip.CanCollide = false
	strip.CanQuery = false
	strip.CanTouch = false
	strip.CastShadow = false
	strip.Parent = overlay
	dust.Parent = strip
	pane.Dust = dust
	return dust
end

local function bang(ctx: Effect.Context, run: Run, pane: Pane, step: Step, at: Vector3)
	const strength = math.max(step.Value or 1, 0.1)
	play(ctx, "Bang", step, surfacePoint(pane, at), strength)
	jitter(run, pane.Part, pane.Frame.LookVector, BANG_AMPLITUDE * strength, BANG_FREQUENCY, BANG_TIME, true)
	dustOf(ctx, pane):Emit(math.floor(DUST_COUNT * strength + 0.5))
end

local function hand(ctx: Effect.Context, pane: Pane, step: Step, at: Vector3, late: number)
	const duration = math.max((step.Duration or HAND_TIME) - late, 0.2)
	overlayOf(ctx, pane)
	play(ctx, "Hand", step, surfacePoint(pane, at))
	for _, gui in pane.Guis do
		const spot = onFace(pane, gui, at)
		const mark = Instance.new("CanvasGroup")
		mark.Name = "Hand"
		mark.AnchorPoint = Vector2.new(0.5, 0.5)
		mark.Position = UDim2.fromScale(spot.X, spot.Y)
		mark.Size = UDim2.fromOffset(HAND_WIDTH * PIXELS, HAND_HEIGHT * PIXELS)
		mark.BackgroundTransparency = 1
		mark.GroupTransparency = 1 - HAND_OPACITY
		-- palm + four fingers (+ thumb), rounded: a mark, nothing more (Mild)
		const palm = Instance.new("Frame")
		palm.AnchorPoint = Vector2.new(0.5, 1)
		palm.Position = UDim2.fromScale(0.5, 1)
		palm.Size = UDim2.fromScale(0.8, 0.5)
		palm.BackgroundColor3 = MARK_COLOR
		palm.BorderSizePixel = 0
		const palmCorner = Instance.new("UICorner")
		palmCorner.CornerRadius = UDim.new(0.35, 0)
		palmCorner.Parent = palm
		palm.Parent = mark
		for index, finger in { { 0.2, 0.42 }, { 0.4, 0.5 }, { 0.6, 0.48 }, { 0.8, 0.4 } } do
			const piece = Instance.new("Frame")
			piece.Name = `Finger{index}`
			piece.AnchorPoint = Vector2.new(0.5, 1)
			piece.Position = UDim2.fromScale(finger[1], 0.55)
			piece.Size = UDim2.fromScale(0.15, finger[2])
			piece.BackgroundColor3 = MARK_COLOR
			piece.BorderSizePixel = 0
			const corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = piece
			piece.Parent = mark
		end
		const thumb = Instance.new("Frame")
		thumb.AnchorPoint = Vector2.new(0.5, 0.5)
		thumb.Position = UDim2.fromScale(if gui.Face == Enum.NormalId.Front then 0.05 else 0.95, 0.68)
		thumb.Size = UDim2.fromScale(0.15, 0.32)
		thumb.Rotation = if gui.Face == Enum.NormalId.Front then -35 else 35
		thumb.BackgroundColor3 = MARK_COLOR
		thumb.BorderSizePixel = 0
		const thumbCorner = Instance.new("UICorner")
		thumbCorner.CornerRadius = UDim.new(0.5, 0)
		thumbCorner.Parent = thumb
		thumb.Parent = mark
		mark.Parent = gui
		-- it slides down the glass, smearing, and fades
		const slide = HAND_SLIDE / pane.Height
		TweenService:Create(mark, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromScale(spot.X, spot.Y + slide),
			Size = UDim2.fromOffset(HAND_WIDTH * PIXELS, (HAND_HEIGHT + HAND_SLIDE * 0.5) * PIXELS),
			GroupTransparency = 1,
		}):Play()
		task.delay(duration + 0.1, mark.Destroy, mark)
	end
end

-- TASK-593: one black paw print (pad, four toes, a claw on each) built at scale on a gui of the pane
local function pawMark(pixels: number, mirrored: boolean): CanvasGroup
	const mark = Instance.new("CanvasGroup")
	mark.Name = "Paw"
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Size = UDim2.fromOffset(pixels, pixels * 1.1)
	mark.BackgroundTransparency = 1
	mark.GroupTransparency = 1 - PAW_OPACITY
	local function blob(name: string, x: number, y: number, w: number, h: number, rotation: number, round: number)
		const piece = Instance.new("Frame")
		piece.Name = name
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Position = UDim2.fromScale(if mirrored then 1 - x else x, y)
		piece.Size = UDim2.fromScale(w, h)
		piece.Rotation = if mirrored then -rotation else rotation
		piece.BackgroundColor3 = PAW_COLOR
		piece.BorderSizePixel = 0
		const corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(round, 0)
		corner.Parent = piece
		piece.Parent = mark
	end
	-- the pad: wide, lower lobes
	blob("Pad", 0.5, 0.72, 0.56, 0.4, 0, 0.45)
	blob("PadL", 0.34, 0.8, 0.26, 0.24, -20, 0.5)
	blob("PadR", 0.66, 0.8, 0.26, 0.24, 20, 0.5)
	-- four toes in an arc, each with a claw scratch beyond it (a long thin smear: it scraped the glass)
	for index, toe in { { 0.16, 0.42, -28 }, { 0.37, 0.27, -9 }, { 0.63, 0.27, 9 }, { 0.84, 0.42, 28 } } do
		const x, y, tilt = toe[1], toe[2], toe[3]
		blob(`Toe{index}`, x, y, 0.19, 0.24, tilt, 0.5)
		const dx = math.sin(math.rad(tilt)) * 0.15
		blob(`Claw{index}`, x + dx, y - 0.19, 0.045, 0.16, tilt, 0.5)
	end
	return mark
end

local function paw(ctx: Effect.Context, state: State, run: Run, pane: Pane, step: Step, at: Vector3)
	const strength = math.max(step.Value or 1, 0.1)
	-- the window may have slid shut since the pane was found: follow the glass part while it is still
	const glassPart = pane.Part
	if glassPart ~= nil and run.Jitters[glassPart] == nil and glassPart.Parent ~= nil then
		const frame = frameOf(glassPart)
		pane.Frame = frame
		const overlay = pane.Overlay
		if overlay ~= nil then
			overlay.CFrame = frame
		end
	end
	const where = surfacePoint(pane, at)
	play(ctx, "Paw", step, where, strength)
	-- it shakes (the hit) and rocks (the frame giving), then dust from the top edge
	jitter(run, pane.Part, pane.Frame.LookVector, BANG_AMPLITUDE * strength, BANG_FREQUENCY, BANG_TIME, true)
	task.delay(BANG_TIME * 0.6, function()
		if run.Live then
			jitter(run, pane.Part, pane.Frame.LookVector, PAW_SWAY_AMPLITUDE * strength, PAW_SWAY_FREQUENCY, PAW_SWAY_TIME, true)
		end
	end)
	dustOf(ctx, pane):Emit(math.floor(DUST_COUNT * strength + 0.5))
	-- the print: same spot and turn on every client (the run's seeded Rng)
	const flat = pane.Frame:PointToObjectSpace(where)
	const spotWorld = pane.Frame * Vector3.new(
		flat.X + state.Rng:NextNumber(-1, 1) * PAW_SPREAD.X * pane.Width,
		flat.Y + state.Rng:NextNumber(-1, 1) * PAW_SPREAD.Y * pane.Height,
		0
	)
	const turn = state.Rng:NextNumber(-PAW_TILT, PAW_TILT)
	const pixels = PAW_SIZE * math.clamp(0.8 + 0.25 * strength, 0.8, 1.3) * PIXELS
	overlayOf(ctx, pane)
	for _, gui in pane.Guis do
		const spot = onFace(pane, gui, spotWorld)
		const mark = pawMark(pixels, gui.Face ~= Enum.NormalId.Front)
		mark.Position = UDim2.fromScale(spot.X, spot.Y)
		mark.Rotation = if gui.Face == Enum.NormalId.Front then turn else -turn
		-- slammed on: a touch bigger and fainter, then it settles
		mark.Size = UDim2.fromOffset(pixels * 1.25, pixels * 1.1 * 1.25)
		mark.GroupTransparency = 1
		mark.Parent = gui
		TweenService:Create(mark, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(pixels, pixels * 1.1),
			GroupTransparency = 1 - PAW_OPACITY,
		}):Play()
		table.insert(pane.Paws, mark)
	end
	while #pane.Paws > PAW_MAX * #pane.Guis do
		const oldest = table.remove(pane.Paws, 1)
		if oldest ~= nil then
			oldest:Destroy()
		end
	end
end

local function rattle(ctx: Effect.Context, run: Run, pane: Pane, step: Step, at: Vector3, late: number)
	const strength = math.max(step.Value or 1, 0.1)
	const duration = math.max((step.Duration or RATTLE_TIME) - late, 0.1)
	const shutter = findShutter(ctx, at)
	const thing: Instance? = if shutter ~= nil then shutter else pane.Part
	play(ctx, "Rattle", step, surfacePoint(pane, at), strength)
	jitter(run, thing, pane.Frame.LookVector, RATTLE_AMPLITUDE * strength, RATTLE_FREQUENCY, duration, false)
end

const glass: Handler = function(ctx, state, step, late)
	const id = step.Point
	if id == nil then
		return
	end
	const pane, at = paneOf(ctx, state, id)
	if pane == nil then
		return
	end
	const run = runOf(state)
	const target = step.Target or "Knock"
	if step.To == "Misted" and target ~= "Fog" and pane.FogLevel < MISTED then
		return
	end
	if target == "Fog" then
		fog(ctx, pane, step, at, late)
	elseif target == "Knock" then
		knock(ctx, run, pane, step, at)
	elseif target == "Bang" then
		bang(ctx, run, pane, step, at)
	elseif target == "Hand" then
		hand(ctx, pane, step, at, late)
	elseif target == "Rattle" then
		rattle(ctx, run, pane, step, at, late)
	elseif target == "Paw" then
		paw(ctx, state, run, pane, step, at)
	end
end

return table.freeze({
	Register = function(handle: (kind: Content.HorrorStepKind, handler: Handler) -> (), _camera: any)
		handle("Glass", glass)
	end,
})
