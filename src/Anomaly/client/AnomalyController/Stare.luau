--!strict
--[[
	Stare pressure, client look (TASK-482; DEC-294, DEC-295 Q-368 A; design/horror-cinematic.md §8;
	tech/stare-pressure.md). Presentation only (T10): the sanity drain is AnomalyService:StareTick, from the Gaze the
	camera already sends; nothing here sends or decides anything.

	Target: the head of the actor (record Anchor = NpcId) of an Active occurrence whose Content row has `Stare`. The own
	camera in first person (CameraController:IsFirstPerson), own character alive, the head within the row's ViewRange,
	inside the cone Content.Sanity.Stare.Angle around the camera look and in line of sight (TICK s between two reads).
	  Stare     s of continuous stare; looking away Sanity.Stare.Release s restarts it (same rule as the server)
	  Pressure  0..1: past Sanity.Stare.Delay it climbs to 1 over HorrorScenes.Stare.Build; looking away it falls to 0
	            over Release ("solta tudo em ~1 s")
	What the pressure drives (all off at 0):
	  heart     single heartbeats (Content.Sounds heartbeat, like the scene step) HeartFrom -> HeartTo BPM
	  edges     Kit/Screen vignette channel "stare" up to Vignette, with a slow flicker of +-Flicker ("glaucoma";
	            no flicker with Motion.Reduced)
	  whispers  Kit/Whispers.Stream of Words[key] (default "stare": STOP STARING, DON'T LOOK), WhisperFrom -> WhisperTo
	  head      the actor's head turns towards the camera at HeadSpeed * pressure deg/s, at most HeadMax past its own pose,
	            and tilts sideways up to HeadTilt * pressure (a customer at the window already faces the camera: with the
	            turn alone nothing moved, owner 2026-10-18) (Neck Motor6D C1, so the family A modifiers that write C0 every
	            frame, ANM-012's neck, still hold)
	  face      the face shell (CrewRig "Face", welded to the Head) taller and narrower by FaceStretch and swaying by
	            FaceRoll degrees (Q-368 A: scale/rotation of the face parts, no EditableMesh)
	The head and the face are local only and come back to the server's pose as the pressure falls; a rig that streamed
	out or was pooled is restored on the next look.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)
local Sight = require(ReplicatedStorage.shared.Anomaly.Sight)
local Motion = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Motion)
local Effect = require(script.Parent.Effect)
local Screen = require(script.Parent.Effects.Kit.Screen)
local Whispers = require(script.Parent.Effects.Kit.Whispers)

export type Camera = { IsFirstPerson: (self: any) -> boolean }

-- Local pose of one actor rig while the stare touches it
type Pose = {
	Model: Model,
	Head: BasePart,
	Motor: Motor6D?,
	BaseC1: CFrame,
	Turn: number, -- rad past the rig's own pose
	Tilt: number, -- rad of sideways head tilt shown now
	Face: BasePart?,
	FaceWeld: WeldConstraint?,
	FaceSize: Vector3,
	FaceOffset: CFrame, -- face shell in head space
	Distort: number, -- 0..1 shown now
}

const RULES = Content.Sanity.Stare
const LOOK = Content.HorrorScenes.Stare
const WORDS = Content.HorrorScenes.Words
const CHANNEL = "stare" -- Kit/Screen vignette channel
const TICK = 0.1 -- s between two target / line-of-sight reads
const HALF_COS = math.cos(math.rad(RULES.Angle / 2))
const HEAD_MAX = math.rad(LOOK.HeadMax)
const HEAD_SPEED = math.rad(LOOK.HeadSpeed)
const HEAD_TILT = math.rad(LOOK.HeadTilt)
const FACE_ROLL = math.rad(LOOK.FaceRoll)
const CATCH_UP = 2 -- 1/s: how fast the pressure catches up when the stare resumes before the release
const SETTLE = 3 -- 1/s: how fast the head and face go back when the pressure is gone
const EPSILON = 1e-3
const FLICKER_SPEED = 5 -- noise frequency of the edge flicker
const SWAY_SPEED = 2.3 -- rad/s of the face sway

const Stare = {}

local ctx: Effect.Context? = nil
local camera: Camera? = nil
local started = false
local nextRead = 0
local target: { Key: string, Head: BasePart, Model: Model }? = nil
local looking = false
local stareTime = 0
local awayTime = 0
local pressure = 0
local wordsKey: string? = nil
local stopWords: (() -> ())? = nil
local heartOn = false
const poses: { [Model]: Pose } = setmetatable({}, { __mode = "k" }) :: any

local function headOf(model: Model): BasePart?
	const head = model:FindFirstChild("Head")
	return if head ~= nil and head:IsA("BasePart") then head else nil
end

-- Closest head (by angle) of an Active Stare occurrence; nil = none.
local function findTarget(context: Effect.Context): ({ Key: string, Head: BasePart, Model: Model }?, number)
	local best: { Key: string, Head: BasePart, Model: Model }? = nil
	local bestRange = 0
	local bestCos = -2
	const view = Workspace.CurrentCamera
	if view == nil then
		return nil, 0
	end
	const eye = view.CFrame.Position
	const look = view.CFrame.LookVector
	for _, occ in context.Occurrences(nil) do
		if not occ.Row.Stare then
			continue
		end
		const record = occ.Record()
		if record.Phase ~= "Active" or record.Anchor == 0 then
			continue
		end
		const model = context.Npc(record.Anchor)
		const head = if model ~= nil then headOf(model) else nil
		if model == nil or head == nil or not model:IsDescendantOf(Workspace) then
			continue
		end
		const offset = head.Position - eye
		if offset.Magnitude < EPSILON then
			continue
		end
		const cos = offset.Unit:Dot(look)
		if cos > bestCos then
			best, bestCos, bestRange = { Key = occ.Key, Head = head, Model = model }, cos, occ.Row.ViewRange
		end
	end
	return best, bestRange
end

local function inSight(context: Effect.Context, head: BasePart, model: Model, range: number): boolean
	const view = Workspace.CurrentCamera
	const owner = camera
	const character = Players.LocalPlayer.Character
	const humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if view == nil or owner == nil or humanoid == nil or humanoid.Health <= 0 or not owner:IsFirstPerson() then
		return false
	end
	const eye = view.CFrame.Position
	const offset = head.Position - eye
	const distance = offset.Magnitude
	if distance > range or distance < EPSILON or offset.Unit:Dot(view.CFrame.LookVector) < HALF_COS then
		return false
	end
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	const ignore: { Instance } = { model, context.Folder() }
	if character ~= nil then
		table.insert(ignore, character)
	end
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	return Sight.Clear(eye, offset, params) -- TASK-493: glass / invisible barriers do not hide it
end

-- Heart ----------------------------------------------------------------------------------------------------------------

-- Beat loop while the pressure is up (the scene's Heartbeat sound, Content.Sounds heartbeat)
local function startHeart()
	if heartOn then
		return
	end
	const row = Content.Sounds.ByKey.heartbeat
	if row == nil or row.Id == "" then
		return
	end
	heartOn = true
	const found = SoundService:FindFirstChild("Sfx", true)
	const group: SoundGroup? = if found ~= nil and found:IsA("SoundGroup") then found else nil
	task.spawn(function()
		while heartOn and pressure > 0 do
			const p = pressure
			const beat = Instance.new("Sound")
			beat.Name = "Stare_Heartbeat"
			beat.SoundId = row.Id
			beat.Volume = row.Volume * (0.45 + 0.65 * p)
			beat.PlaybackSpeed = 0.95 + 0.2 * p
			beat.SoundGroup = group
			beat.Parent = SoundService
			beat:Play()
			task.delay(2, function()
				beat:Destroy()
			end)
			task.wait(60 / (LOOK.HeartFrom + (LOOK.HeartTo - LOOK.HeartFrom) * p))
		end
		heartOn = false
	end)
end

-- Whispers ---------------------------------------------------------------------------------------------------------------

local function whisperRate(): number
	if pressure <= 0 then
		return 0
	end
	return LOOK.WhisperFrom + (LOOK.WhisperTo - LOOK.WhisperFrom) * pressure
end

local function setWords(key: string?)
	const list = if key ~= nil then (LOOK.Words[key] or "stare") else nil
	if list == wordsKey then
		return
	end
	const stop = stopWords
	stopWords = nil
	if stop ~= nil then
		stop()
	end
	wordsKey = list
	const words = if list ~= nil then WORDS[list] else nil
	if words ~= nil then
		stopWords = Whispers.Stream(words, whisperRate)
	end
end

-- Head and face ----------------------------------------------------------------------------------------------------------

local function poseOf(model: Model, head: BasePart): Pose
	const existing = poses[model]
	if existing ~= nil then
		return existing
	end
	const torso = model:FindFirstChild("Torso")
	const neck = if torso ~= nil then torso:FindFirstChild("Neck") else nil
	const motor: Motor6D? = if neck ~= nil and neck:IsA("Motor6D") then neck else nil
	const shell = model:FindFirstChild("Face")
	const face: BasePart? = if shell ~= nil and shell:IsA("BasePart") then shell else nil
	local weld: WeldConstraint? = nil
	if face ~= nil then
		for _, descendant in model:GetDescendants() do
			if
				descendant:IsA("WeldConstraint")
				and ((descendant.Part0 == head and descendant.Part1 == face) or (descendant.Part0 == face and descendant.Part1 == head))
			then
				weld = descendant
				break
			end
		end
	end
	const pose: Pose = {
		Model = model,
		Head = head,
		Motor = motor,
		BaseC1 = if motor ~= nil then motor.C1 else CFrame.identity,
		Turn = 0,
		Tilt = 0,
		Face = if weld ~= nil then face else nil,
		FaceWeld = weld,
		FaceSize = if face ~= nil then face.Size else Vector3.one,
		FaceOffset = if face ~= nil then head.CFrame:ToObjectSpace(face.CFrame) else CFrame.identity,
		Distort = 0,
	}
	poses[model] = pose
	return pose
end

-- Signed angle (rad) around `up` that takes `from` to `to` (both projected on the plane of `up`).
local function signedAngle(from: Vector3, to: Vector3, up: Vector3): number
	const a = from - up * from:Dot(up)
	const b = to - up * to:Dot(up)
	if a.Magnitude < EPSILON or b.Magnitude < EPSILON then
		return 0
	end
	return math.atan2(a.Unit:Cross(b.Unit):Dot(up), a.Unit:Dot(b.Unit))
end

local function applyHead(pose: Pose, dt: number, driven: boolean)
	const motor = pose.Motor
	const torso = if motor ~= nil then motor.Part0 else nil
	if motor == nil or torso == nil then
		return
	end
	const view = Workspace.CurrentCamera
	if driven and view ~= nil then
		const up = torso.CFrame.UpVector
		const miss = signedAngle(pose.Head.CFrame.LookVector, view.CFrame.Position - pose.Head.Position, up)
		const step = HEAD_SPEED * pressure * dt
		pose.Turn = math.clamp(pose.Turn + math.clamp(miss, -step, step), -HEAD_MAX, HEAD_MAX)
	else
		pose.Turn -= pose.Turn * math.min(1, dt * SETTLE)
	end
	const tilt = if driven then HEAD_TILT * pressure else 0
	pose.Tilt += (tilt - pose.Tilt) * math.min(1, dt * SETTLE)
	-- the physical turn around the torso's up, then the tilt around the head's own front, in the joint frame, after the
	-- animation (C1 side)
	const axis = motor.C0:VectorToObjectSpace(Vector3.yAxis)
	const front = motor.C0:VectorToObjectSpace(-Vector3.zAxis)
	const turn = CFrame.fromAxisAngle(axis, pose.Turn) * CFrame.fromAxisAngle(front, pose.Tilt)
	motor.C1 = pose.BaseC1 * turn:Inverse()
end

local function applyFace(pose: Pose, dt: number, driven: boolean, now: number)
	const face = pose.Face
	const weld = pose.FaceWeld
	if face == nil or weld == nil or face.Parent == nil then
		return
	end
	const goal = if driven then pressure else 0
	pose.Distort += (goal - pose.Distort) * math.min(1, dt * SETTLE)
	const amount = pose.Distort
	const stretch = LOOK.FaceStretch * amount * (0.75 + 0.25 * math.sin(now * SWAY_SPEED * 1.3))
	const roll = FACE_ROLL * amount * math.sin(now * SWAY_SPEED)
	weld.Enabled = false
	face.Size = pose.FaceSize * Vector3.new(1 - stretch * 0.5, 1 + stretch, 1)
	face.CFrame = pose.Head.CFrame * pose.FaceOffset * CFrame.Angles(0, 0, roll)
	weld.Enabled = true
end

local function restore(pose: Pose)
	const motor = pose.Motor
	if motor ~= nil and motor.Parent ~= nil then
		motor.C1 = pose.BaseC1
	end
	const face = pose.Face
	const weld = pose.FaceWeld
	if face ~= nil and weld ~= nil and face.Parent ~= nil and pose.Head.Parent ~= nil then
		weld.Enabled = false
		face.Size = pose.FaceSize
		face.CFrame = pose.Head.CFrame * pose.FaceOffset
		weld.Enabled = true
	end
	poses[pose.Model] = nil
end

local function stepPoses(dt: number, now: number)
	const current = target
	if current ~= nil and pressure > 0 then
		poseOf(current.Model, current.Head)
	end
	for model, pose in poses do
		if model.Parent == nil or pose.Head.Parent == nil then
			poses[model] = nil
			continue
		end
		const driven = current ~= nil and current.Model == model and pressure > 0
		applyHead(pose, dt, driven and looking)
		applyFace(pose, dt, driven, now)
		if not driven and math.abs(pose.Turn) < EPSILON and math.abs(pose.Tilt) < EPSILON and pose.Distort < EPSILON then
			restore(pose)
		end
	end
end

-- Loop -------------------------------------------------------------------------------------------------------------------

local function stepScreen(now: number)
	if pressure <= 0 then
		Screen.ClearVignette(CHANNEL)
		return
	end
	local value = LOOK.Vignette * pressure
	if not Motion.Reduced() then
		value += LOOK.Flicker * pressure * math.noise(now * FLICKER_SPEED, 0.5)
	end
	Screen.SetVignette(value, value, 0, CHANNEL)
end

local function step(dt: number)
	const context = ctx
	if context == nil then
		return
	end
	const now = os.clock()
	if now >= nextRead then
		nextRead = now + TICK
		const found, range = findTarget(context)
		const previous = target
		if found == nil or previous == nil or found.Model ~= previous.Model then
			stareTime = 0
		end
		target = found
		looking = found ~= nil and inSight(context, found.Head, found.Model, range)
	end
	const current = target
	if looking then
		awayTime = 0
		stareTime += dt
	else
		awayTime += dt
		if awayTime >= RULES.Release then
			stareTime = 0
		end
	end
	const was = pressure
	if looking and stareTime >= RULES.Delay then
		const goal = math.clamp((stareTime - RULES.Delay) / LOOK.Build, 0, 1)
		pressure = math.min(goal, pressure + math.max(dt / LOOK.Build, dt * CATCH_UP))
	else
		pressure = math.max(0, pressure - dt / RULES.Release)
	end
	if pressure > 0 and was <= 0 then
		startHeart()
	end
	setWords(if pressure > 0 and current ~= nil then current.Key else nil)
	if pressure > 0 or was > 0 then
		stepScreen(now)
	end
	stepPoses(dt, now)
end

-- Starts the loop (AnomalyController:OnStart). Idempotent.
function Stare.Start(context: Effect.Context, cameraController: Camera)
	if started then
		return
	end
	started = true
	ctx = context
	camera = cameraController
	RunService.RenderStepped:Connect(step)
end

-- Current pressure 0..1 (debugging, other effects).
function Stare.Pressure(): number
	return pressure
end

return table.freeze(Stare)
