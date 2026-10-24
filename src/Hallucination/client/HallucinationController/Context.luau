--!strict
-- Shared types and helpers of the hallucination effects (TASK-119; architecture.md §19.15; FEAT-019; DEC-038).
-- Plain module: no Modux, no Lync, no network. Every write an effect makes is local to this client and undone by the
-- run's cleanups (no prompt, no state the server or another client can see, never an anomaly).
--
--   Env    what the controller hands to an effect (audio, camera, vehicle, kitchen slots, subtitle, whisper line)
--   Run    one playing effect: Wait(seconds) -> false once cancelled, Cleanup(fn) runs on finish or cancel
--   Effect module contract: { CanRun: ((env) -> boolean)?, Play: (env, run) -> () }
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)

export type PlayOptions = { Volume: number?, Speed: number?, Vary: number?, Scare: boolean? }

export type Env = {
	Random: Random,
	-- One-shot / looped sound through AudioController. Keys missing from Content.Sounds are skipped silently
	-- (SFX-130/131/133/134 have no key yet: sound-list.md §5.12, Q-168).
	Sound: (key: string, at: (Vector3 | Instance)?, opts: PlayOptions?) -> Sound?,
	Loop: (key: string, at: (Vector3 | Instance)?, on: boolean) -> (),
	VehicleKey: () -> string,
	Vehicle: () -> Instance?,
	-- No real boss call is ringing or talking (BossController.State == "Idle").
	CallIdle: () -> boolean,
	-- TASK-601: the night of the run (RoundController.Night; 0 = not in a night yet)
	Night: () -> number,
	-- Kitchen slot state ("Empty" | "Working" | "Ready"), nil = no record.
	SlotState: (recordId: number) -> string?,
	-- Local subtitle strip (CallSubtitle) and whisper line; "" hides.
	Subtitle: (speaker: string, text: string) -> (),
	Whisper: (text: string) -> (),
	-- Camera shake of CameraController:HorrorShake (profile of HorrorScenes Rules.Shakes; owner 2026-10-20, Q-415).
	Shake: (profile: string, scale: number?) -> (),
}

export type Run = {
	Alive: (self: Run) -> boolean,
	Wait: (self: Run, seconds: number) -> boolean,
	Cleanup: (self: Run, fn: () -> ()) -> (),
	Finish: (self: Run) -> (),
	Done: boolean,
	Cleanups: { () -> () },
}

export type Effect = {
	CanRun: ((env: Env) -> boolean)?,
	Play: (env: Env, run: Run) -> (),
}

const Context = {}

-- Run -----------------------------------------------------------------------------------------------------------------

local RunMethods = {}
RunMethods.__index = RunMethods

function RunMethods.Alive(self: Run): boolean
	return not self.Done
end

function RunMethods.Wait(self: Run, seconds: number): boolean
	if self.Done then
		return false
	end
	task.wait(seconds)
	return not self.Done
end

function RunMethods.Cleanup(self: Run, fn: () -> ())
	if self.Done then
		fn()
		return
	end
	table.insert(self.Cleanups, fn)
end

function RunMethods.Finish(self: Run)
	if self.Done then
		return
	end
	self.Done = true
	-- last registered first (restore in reverse order of the writes)
	for index = #self.Cleanups, 1, -1 do
		const ok, err = pcall(self.Cleanups[index])
		if not ok then
			warn(`[HallucinationController] cleanup failed: {err}`)
		end
	end
	table.clear(self.Cleanups)
end

function Context.NewRun(): Run
	return (setmetatable({ Done = false, Cleanups = {} }, RunMethods) :: any) :: Run
end

-- Geometry --------------------------------------------------------------------------------------------------------

function Context.Camera(): Camera?
	return Workspace.CurrentCamera
end

function Context.Root(): BasePart?
	const character = Players.LocalPlayer.Character
	if character == nil then
		return nil
	end
	const root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

function Context.PositionOf(instance: Instance): Vector3?
	if instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Attachment") then
		return instance.WorldPosition
	elseif instance:IsA("PVInstance") then
		return instance:GetPivot().Position
	end
	return nil
end

-- Angle (degrees) between the camera look and the direction to `position`, and the distance; nil without a camera.
function Context.ViewAngle(position: Vector3): (number?, number)
	const camera = Context.Camera()
	if camera == nil then
		return nil, math.huge
	end
	const eye = camera.CFrame.Position
	const offset = position - eye
	const distance = offset.Magnitude
	if distance < 1e-3 then
		return 0, 0
	end
	const dot = math.clamp(camera.CFrame.LookVector:Dot(offset.Unit), -1, 1)
	return math.deg(math.acos(dot)), distance
end

-- `position` within `cone` degrees of the look and `range` studs, with a clear line from the camera (ignoring the
-- local character and `ignore`).
function Context.Sees(position: Vector3, cone: number, range: number, ignore: { Instance }?): boolean
	const angle, distance = Context.ViewAngle(position)
	if angle == nil or angle > cone or distance > range then
		return false
	end
	const camera = Context.Camera() :: Camera
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	const list: { Instance } = {}
	const character = Players.LocalPlayer.Character
	if character then
		table.insert(list, character)
	end
	if ignore then
		for _, item in ignore do
			table.insert(list, item)
		end
	end
	params.FilterDescendantsInstances = list
	params.IgnoreWater = true
	const eye = camera.CFrame.Position
	const hit = Workspace:Raycast(eye, position - eye, params)
	return hit == nil or (hit.Position - position).Magnitude < 1.5
end

-- Instances ---------------------------------------------------------------------------------------------------------

-- Tagged instances inside the Workspace.
function Context.Tagged(tag: string): { Instance }
	const out: { Instance } = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsDescendantOf(Workspace) then
			table.insert(out, instance)
		end
	end
	return out
end

-- Every BasePart of `root` (itself included) whose look counts as lit: Neon right now.
function Context.LitParts(root: Instance): { BasePart }
	const out: { BasePart } = {}
	if root:IsA("BasePart") and root.Material == Enum.Material.Neon then
		table.insert(out, root)
	end
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Material == Enum.Material.Neon then
			table.insert(out, descendant)
		end
	end
	return out
end

-- Every Light of `root`.
function Context.Lights(root: Instance): { Light }
	const out: { Light } = {}
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("Light") then
			table.insert(out, descendant)
		end
	end
	return out
end

-- Local "off" look that does not fight LightController (it owns Material, Color, Enabled and the decals; this only
-- touches LocalTransparencyModifier and Brightness). Returns the restore function.
function Context.Dim(parts: { BasePart }, lights: { Light }, amount: number): () -> ()
	const brightness: { [Light]: number } = {}
	for _, light in lights do
		brightness[light] = light.Brightness
		light.Brightness = light.Brightness * (1 - amount)
	end
	for _, part in parts do
		part.LocalTransparencyModifier = amount
	end
	return function()
		for light, value in brightness do
			if light.Parent ~= nil then
				light.Brightness = value
			end
		end
		for _, part in parts do
			if part.Parent ~= nil then
				part.LocalTransparencyModifier = 0
			end
		end
	end
end

-- Neon in sync with its sound (user request 2026-10-10): every frame the `sound`'s PlaybackLoudness (client only, on a
-- playing Sound) drives the neon: lit above NEON_ON, out below NEON_OFF (hysteresis, no chatter on the edge). Out =
-- Material SmoothPlastic on the parts and Enabled = false on the lights. Returns when the sound stops, the run is
-- cancelled or `limit` s passed; the original look is put back on exit (cleanup on the run too). A value that
-- LightController rewrote meanwhile (its own switch) is left alone: only what this still owns is restored.
-- PROVISIONAL thresholds (frontend-coder), calibrated against `neon_click` (NeonFlicking, 18 s).
const NEON_ON = 40
const NEON_OFF = 20

function Context.NeonSync(parts: { BasePart }, lights: { Light }, sound: Sound, run: Run, limit: number)
	const material: { [BasePart]: Enum.Material } = {}
	const enabled: { [Light]: boolean } = {}
	for _, part in parts do
		material[part] = part.Material
	end
	for _, light in lights do
		enabled[light] = light.Enabled
	end
	local lit = true
	local function apply(on: boolean)
		if on == lit then
			return
		end
		lit = on
		for part, original in material do
			if part.Parent ~= nil then
				part.Material = if on then original else Enum.Material.SmoothPlastic
			end
		end
		for light, original in enabled do
			if light.Parent ~= nil then
				light.Enabled = if on then original else false
			end
		end
	end
	local restored = false
	local function restore()
		if restored then
			return
		end
		restored = true
		if lit then
			return
		end
		-- only what still shows this effect's "out" look
		for part, original in material do
			if part.Parent ~= nil and part.Material == Enum.Material.SmoothPlastic then
				part.Material = original
			end
		end
		for light, original in enabled do
			if light.Parent ~= nil and light.Enabled == false then
				light.Enabled = original
			end
		end
		lit = true
	end
	run:Cleanup(restore)
	const started = os.clock()
	while run:Alive() and sound.IsPlaying and sound.Parent ~= nil and os.clock() - started < limit do
		const loudness = sound.PlaybackLoudness
		if lit and loudness < NEON_OFF then
			apply(false)
		elseif not lit and loudness > NEON_ON then
			apply(true)
		end
		RunService.RenderStepped:Wait()
	end
	restore()
end

-- Far spots (family D: street watcher, monster glimpse) -----------------------------------------------------------

export type SpotQuery = {
	MinDistance: number, -- studs from the camera
	MaxDistance: number,
	MinAngle: number, -- degrees from the look
	MaxAngle: number,
	Height: number, -- studs above the point that must be in clear line (the figure's head)
	MaxRise: number?, -- studs the point may sit above / below the local character's feet (default 12)
}

-- Every MapPoint (any id) on the ground around the player that fits the query, with a clear line from the camera to
-- `Height` above it. The map's own points keep the figures on sidewalks, curbs and lots, never inside a building.
function Context.FarSpots(query: SpotQuery): { CFrame }
	const out: { CFrame } = {}
	const root = Context.Root()
	if root == nil or not MapIndex.HasBinding() then
		return out
	end
	const feet = root.Position.Y - 3
	const rise = query.MaxRise or 12
	const ok, points = pcall(MapIndex.Points, "")
	if not ok then
		return out
	end
	for _, point in points do
		const at = point.Position
		if math.abs(at.Y - feet) <= rise then
			const head = at + Vector3.new(0, query.Height, 0)
			const angle, distance = Context.ViewAngle(head)
			if
				angle ~= nil
				and angle >= query.MinAngle
				and angle <= query.MaxAngle
				and distance >= query.MinDistance
				and distance <= query.MaxDistance
				and Context.Sees(head, 180, query.MaxDistance)
			then
				table.insert(out, point)
			end
		end
	end
	return out
end

-- Flat CFrame at `at` facing the camera (yaw only).
function Context.FacingCamera(at: Vector3): CFrame
	const camera = Context.Camera()
	if camera then
		const eye = camera.CFrame.Position
		const flat = Vector3.new(eye.X, at.Y, eye.Z)
		if (flat - at).Magnitude > 0.5 then
			return CFrame.lookAt(at, flat)
		end
	end
	return CFrame.new(at)
end

-- Local props ------------------------------------------------------------------------------------------------------

-- Anchored, ghost-like part (no collision, no query, no touch, no shadow).
function Context.Prop(name: string, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	const made = Instance.new("Part")
	made.Name = name
	made.Size = size
	if shape then
		made.Shape = shape
	end
	made.Anchored = true
	made.CanCollide = false
	made.CanQuery = false
	made.CanTouch = false
	made.CastShadow = false
	made.Material = Enum.Material.SmoothPlastic
	made.TopSurface = Enum.SurfaceType.Smooth
	made.BottomSurface = Enum.SurfaceType.Smooth
	made.Color = color
	return made
end

-- A clone of ReplicatedStorage.Assets...<name> (art replaces the placeholder by dropping a Model with that name, pivot
-- at the feet facing -Z) made ghost-like, or `placeholder()` while it does not exist.
function Context.Asset(name: string, placeholder: () -> Model): Model
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const found = if assets then assets:FindFirstChild(name, true) else nil
	if found and found:IsA("Model") then
		const model = found:Clone()
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
				descendant.CastShadow = false
			end
		end
		return model
	end
	return placeholder()
end

-- Weighted pick ---------------------------------------------------------------------------------------------------

function Context.Pick<T>(random: Random, rows: { T }, weight: (T) -> number): T?
	local total = 0
	for _, row in rows do
		total += math.max(weight(row), 0)
	end
	if total <= 0 then
		return nil
	end
	local roll = random:NextNumber(0, total)
	for _, row in rows do
		const share = math.max(weight(row), 0)
		roll -= share
		if share > 0 and roll <= 0 then -- a 0-weight row is never picked, even on a roll of exactly 0
			return row
		end
	end
	return rows[#rows]
end

-- Phone glitch (owner 2026-10-21) -------------------------------------------------------------------------------------

-- `phone_glitch` is a 6.5 s file: played whole twice in a row it doubled. Outside the blackout's omen (HorrorScenes plays
-- that one whole) it plays ONCE at a time and is cut in the middle: a new glitch stops the previous one, and each one
-- fades out at GLITCH_CUT s.
const GLITCH_KEY = "phone_glitch"
const GLITCH_CUT = 3.25 -- s: half of the file
const GLITCH_FADE = 0.25
local lastGlitch: Sound? = nil

local function fadeOut(sound: Sound)
	if sound.Parent == nil or not sound.IsPlaying then
		return
	end
	const from = sound.Volume
	const started = os.clock()
	while sound.Parent ~= nil and sound.IsPlaying and os.clock() - started < GLITCH_FADE do
		sound.Volume = from * (1 - (os.clock() - started) / GLITCH_FADE)
		RunService.Heartbeat:Wait()
	end
	sound:Stop()
end

function Context.Glitch(env: Env, at: (Vector3 | Instance)?, opts: PlayOptions?): Sound?
	const previous = lastGlitch
	if previous ~= nil then
		lastGlitch = nil
		task.spawn(fadeOut, previous)
	end
	const sound = env.Sound(GLITCH_KEY, at, opts)
	if sound == nil then
		return nil
	end
	lastGlitch = sound
	task.delay(GLITCH_CUT, function()
		if lastGlitch == sound then
			lastGlitch = nil
		end
		fadeOut(sound)
	end)
	return sound
end

return Context
