--!strict
--[[
	V2 family A, odd customers (DEC-254; TASK-292; anomalies-v2-proposal.md §3 A). One deformation per actor, read
	in under a second, applied ONLY on this client to the server rig (Motor6D C0/C1, part sizes): presentation, never
	a verb (T10). Bound to the rig's `Variant` through CustomerActor.Follow, so it lasts while the actor walks off and
	is undone when the pool clears the attribute.

	Variants (rig attribute written by NpcService):
	  shake    ANM-011  the whole body shakes fast (RootJoint C0 jitter); owner 2026-10-22: only a restless fidget
	                    (SHAKE_FIDGET) until his order is taken (rig AnomalyQueue), then the full tremor. A topping on
	                    his plain order (condition Plain, §9.9): cue plate_throw = Kit/Tantrum throws the plate at the
	                    wall, the TUM and his line; while the rig carries AnomalyRage, Kit/Tantrum's rage (monster face,
	                    bugged ticks) owns the RootJoint and this tremor steps aside
	  neck     ANM-012  the head is turned 180° around the neck and sways a little
	  eyes     ANM-013  all-white eyes: the face is RigController's (VARIANT_FACE); here only the idle is held still
	  bighead  ANM-014  head and everything welded to it at BIG_HEAD × size, growing up from the neck
	  float    ANM-015  the body hovers FLOAT studs above the ground with a slow bob
	  stare    ANM-016  the head always turns to the local camera (clamped to STARE_MAX)
	  oncam    ANM-023  normal in person; while this client watches the security cameras (SecurityView set) the body is
	                    broken (arms and legs bent the wrong way, the torso twisted and twitching) and the head turns to
	                    the lens (Q-437, Provisional)

	Rotations go around the torso's up axis expressed in the joint frame, so they hold whatever the R6 C0 layout is.
	The `jumpscare` cue of every family A anomaly is handled here too (Kit/Jumpscare).
	ANM-012 cues (TASK-336, owner 2026-10-15): `neck_snap` (Entity = actor) marks the rig `NeckSnap` locally: the head
	snaps round the rest of the way (SNAP_TIME, a roll) with the `neck_crack` SFX and stays there, no more sway;
	`window_slam` (Entity = actor): the bang of the service window thrown open (`window_slam`, `door_close` when the
	first has no Id yet) and a short camera kick for who stands near the window.
	Owner 2026-10-22 (Provisional): the same for "eyes" (ANM-013: normal eyes with a glint until the talk; the cameras see
	them white) and "bighead" (ANM-014: the head arrives normal, Q-461, and grows in the talk; the cameras see it huge).
	Anomaly tics (design/anomaly-tics-proposal.md, pilot ANM-012, Provisional Q-459 a): a variant with a Content.Tics row
	(by Variant) gets its body from Kit/Tic instead (she arrives with the head forward, twitches, the cameras show it
	turned, the talk turns it); without the row the old modifier above is used (rollback = remove the row). Once the tic
	left its residue (rig Tic = "Done") the neck_snap cue does nothing: the head is already round.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local TrailerFront = require(ReplicatedStorage.shared.Anomaly.TrailerFront)
local Effect = require(script.Parent.Parent.Parent.Effect)
local Actor = require(script.Parent.CustomerActor)
local Jumpscare = require(script.Parent.Jumpscare)
local Tic = require(script.Parent.Tic)
local Tantrum = require(script.Parent.Tantrum)

const SHAKE_MOVE = 0.08 -- studs of jitter
const SHAKE_TURN = math.rad(4)
const SHAKE_FIDGET = 0.25 -- share of the tremor before his order is taken (owner 2026-10-22, Provisional)
const QUEUE_ATTRIBUTE = "AnomalyQueue" -- Anomaly Kit/CustomerActor: the actor waits in the delivery queue
const NECK_SWAY = math.rad(8)
const NECK_SWAY_SPEED = 0.7 -- rad/s of the sway
const BIG_HEAD = 1.9
const FLOAT = 0.7 -- studs
const FLOAT_BOB = 0.12
const FLOAT_BOB_SPEED = 1.6
const SNAP_ATTRIBUTE = "NeckSnap" -- local only: os.clock() of the snap
const SNAP_TIME = 0.12 -- s of the snap
const SNAP_EXTRA = math.pi * 0.85 -- rad turned on top of the 180 (almost a full turn)
const SNAP_ROLL = math.rad(28) -- head tilt after the snap
const CRACK_KEY = "neck_crack"
const SLAM_KEYS = { "window_slam", "door_close" } -- first key with an Id
const SLAM_KICK = 20 -- studs from the window where the camera kicks
const SLAM_KICK_ANGLE = math.rad(2.2)
const SLAM_KICK_TIME = 0.25
const STARE_MAX = math.rad(110)
const STARE_TURN = 10 -- 1/s, how fast the head catches the camera
const BANGER_PITCH = 28 -- degrees the head hangs forward (TASK-591, Provisional)
const BANGER_SWAY = 4 -- degrees of slow side sway

const VIEW_ATTRIBUTE = Content.Security.Rules.ViewAttribute -- "" outside the cameras
const ONCAM_HEAD_ROLL = math.rad(72) -- the head lies on its shoulder
const ONCAM_TWITCH = 0.06 -- studs of the torso twitch
const ONCAM_TWITCH_TURN = math.rad(6)

export type Variant = "shake" | "neck" | "eyes" | "bighead" | "float" | "stare" | "banger" | "oncam"

const OddCustomer = {}

local function joint(model: Model, part: string, name: string): Motor6D?
	const host = model:FindFirstChild(part)
	const found = if host then host:FindFirstChild(name) else nil
	return if found ~= nil and found:IsA("Motor6D") then found else nil
end

-- Rotation of `angle` around the torso's up axis, in the frame of a joint whose Part0 is the torso/root.
local function yaw(c0: CFrame, angle: number): CFrame
	const axis = c0:VectorToObjectSpace(Vector3.yAxis)
	return CFrame.fromAxisAngle(axis, angle)
end

local function shake(model: Model): Actor.Undo
	const root = joint(model, "HumanoidRootPart", "RootJoint")
	if root == nil then
		return function() end
	end
	const base = root.C0
	const rng = Random.new()
	const connection = RunService.RenderStepped:Connect(function()
		if Tantrum.Raging(model) then
			return -- enraged (Kit/Tantrum): its own tremor and ticks on the RootJoint
		end
		-- owner 2026-10-22 (proposal §2.5): restless on arrival, the full tremor only once he waits for his order
		const amount = if model:GetAttribute(QUEUE_ATTRIBUTE) ~= nil then 1 else SHAKE_FIDGET
		const move = SHAKE_MOVE * amount
		const turn = SHAKE_TURN * amount
		const offset = Vector3.new(rng:NextNumber(-move, move), rng:NextNumber(-move, move), rng:NextNumber(-move, move))
		root.C0 = base * CFrame.new(offset) * yaw(base, rng:NextNumber(-turn, turn))
	end)
	return function()
		connection:Disconnect()
		root.C0 = base
	end
end

local function neck(model: Model): Actor.Undo
	const motor = joint(model, "Torso", "Neck")
	if motor == nil then
		return function() end
	end
	const base = motor.C0
	const started = os.clock()
	local swayAtSnap: number? = nil
	const connection = RunService.Heartbeat:Connect(function()
		const now = os.clock()
		const snappedAt = model:GetAttribute(SNAP_ATTRIBUTE)
		if type(snappedAt) == "number" then
			-- TASK-336: the snap, then held there (no sway)
			const from = swayAtSnap or (math.sin((snappedAt - started) * NECK_SWAY_SPEED) * NECK_SWAY)
			swayAtSnap = from
			const t = math.clamp((now - snappedAt) / SNAP_TIME, 0, 1)
			const e = 1 - (1 - t) * (1 - t)
			motor.C0 = base * yaw(base, math.pi + from + SNAP_EXTRA * e) * CFrame.Angles(0, 0, SNAP_ROLL * e)
			return
		end
		const sway = math.sin((now - started) * NECK_SWAY_SPEED) * NECK_SWAY
		motor.C0 = base * yaw(base, math.pi + sway)
	end)
	return function()
		connection:Disconnect()
		motor.C0 = base
	end
end

-- Head + every part welded to it (WeldConstraint with Part0 = Head, CrewRig.Build), scaled around the neck.
local function bighead(model: Model): Actor.Undo
	const head = model:FindFirstChild("Head")
	const motor = joint(model, "Torso", "Neck")
	if head == nil or not head:IsA("BasePart") or motor == nil then
		return function() end
	end
	type Saved = { Part: BasePart, Size: Vector3, Offset: CFrame, Weld: WeldConstraint }
	const saved: { Saved } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("WeldConstraint") and descendant.Part0 == head and descendant.Part1 ~= nil then
			const part = descendant.Part1 :: BasePart
			table.insert(saved, {
				Part = part,
				Size = part.Size,
				Offset = head.CFrame:ToObjectSpace(part.CFrame),
				Weld = descendant,
			})
		end
	end
	const headSize = head.Size
	const c1 = motor.C1

	local function apply(scale: number)
		for _, entry in saved do
			entry.Weld.Enabled = false
		end
		head.Size = headSize * scale
		motor.C1 = c1 - c1.Position + c1.Position * scale
		for _, entry in saved do
			const offset = entry.Offset
			entry.Part.Size = entry.Size * scale
			entry.Part.CFrame = head.CFrame * (offset - offset.Position + offset.Position * scale)
			entry.Weld.Enabled = true
		end
	end
	apply(BIG_HEAD)
	return function()
		if head.Parent ~= nil then
			apply(1)
		end
	end
end

local function float(model: Model): Actor.Undo
	const root = joint(model, "HumanoidRootPart", "RootJoint")
	if root == nil then
		return function() end
	end
	const base = root.C0
	const up = base:VectorToObjectSpace(Vector3.yAxis)
	const started = os.clock()
	const connection = RunService.Heartbeat:Connect(function()
		const height = FLOAT + math.sin((os.clock() - started) * FLOAT_BOB_SPEED) * FLOAT_BOB
		root.C0 = base * CFrame.new(up * height)
	end)
	return function()
		connection:Disconnect()
		root.C0 = base
	end
end

local function stare(model: Model): Actor.Undo
	const motor = joint(model, "Torso", "Neck")
	const torso = model:FindFirstChild("Torso")
	if motor == nil or torso == nil or not torso:IsA("BasePart") then
		return function() end
	end
	const base = motor.C0
	local current = 0
	const connection = RunService.RenderStepped:Connect(function(dt: number)
		const camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end
		-- torso space: front is -Z; the angle around +Y that takes -Z to the camera
		const dir = torso.CFrame:PointToObjectSpace(camera.CFrame.Position)
		const target = math.clamp(math.atan2(-dir.X, -dir.Z), -STARE_MAX, STARE_MAX)
		current += (target - current) * math.min(1, dt * STARE_TURN)
		motor.C0 = base * yaw(base, current)
	end)
	return function()
		connection:Disconnect()
		motor.C0 = base
	end
end

-- Q-437 (ANM-023 the one on camera): only the security cameras see it. Each joint's pose is relative to its own C0, so
-- it holds whatever the R6 layout is; outside the cameras every joint is back at its base.
const ONCAM_POSE: { [string]: CFrame } = {
	-- one arm wrenched up behind the back, the other hanging twisted backwards; the legs splayed the wrong way
	["Left Shoulder"] = CFrame.Angles(math.rad(-160), math.rad(40), math.rad(-60)),
	["Right Shoulder"] = CFrame.Angles(math.rad(70), math.rad(150), math.rad(20)),
	["Left Hip"] = CFrame.Angles(math.rad(45), math.rad(-30), math.rad(55)),
	["Right Hip"] = CFrame.Angles(math.rad(-50), math.rad(35), math.rad(-40)),
}

local function oncam(model: Model): Actor.Undo
	const torso = model:FindFirstChild("Torso")
	const neck = joint(model, "Torso", "Neck")
	const root = joint(model, "HumanoidRootPart", "RootJoint")
	if torso == nil or not torso:IsA("BasePart") then
		return function() end
	end
	const limbs: { [Motor6D]: CFrame } = {}
	for name in ONCAM_POSE do
		const motor = joint(model, "Torso", name)
		if motor ~= nil then
			limbs[motor] = motor.C0
		end
	end
	const neckBase = if neck ~= nil then neck.C0 else nil
	const rootBase = if root ~= nil then root.C0 else nil
	const rng = Random.new()
	local broken = false
	local function restore()
		for motor, base in limbs do
			motor.C0 = base
		end
		if neck ~= nil and neckBase ~= nil then
			neck.C0 = neckBase
		end
		if root ~= nil and rootBase ~= nil then
			root.C0 = rootBase
		end
	end
	const connection = RunService.RenderStepped:Connect(function()
		const view = Players.LocalPlayer:GetAttribute(VIEW_ATTRIBUTE)
		const watching = type(view) == "string" and view ~= ""
		if not watching then
			if broken then
				broken = false
				restore()
			end
			return
		end
		broken = true
		for motor, base in limbs do
			motor.C0 = base * ONCAM_POSE[motor.Name]
		end
		const camera = Workspace.CurrentCamera
		if neck ~= nil and neckBase ~= nil and camera ~= nil then
			-- the head to the lens (the security camera is the current camera while watching), no clamp, tilted over
			const dir = torso.CFrame:PointToObjectSpace(camera.CFrame.Position)
			const angle = math.atan2(-dir.X, -dir.Z)
			neck.C0 = neckBase * yaw(neckBase, angle) * CFrame.Angles(0, 0, ONCAM_HEAD_ROLL)
		end
		if root ~= nil and rootBase ~= nil then
			const twitch = if rng:NextNumber() < 0.08 then 1 else 0
			root.C0 = rootBase
				* CFrame.new(0, 0, twitch * ONCAM_TWITCH)
				* CFrame.Angles(math.rad(22), math.rad(35) + twitch * ONCAM_TWITCH_TURN, math.rad(24))
		end
	end)
	return function()
		connection:Disconnect()
		restore()
	end
end

-- TASK-591 (ANM-022 the head banger): the head hangs forward, low, as if leaning on the glass, swaying a little
local function banger(model: Model): Actor.Undo
	const motor = joint(model, "Torso", "Neck")
	if motor == nil then
		return function() end
	end
	const base = motor.C0
	const started = os.clock()
	const connection = RunService.RenderStepped:Connect(function()
		const sway = math.sin((os.clock() - started) * 1.3) * math.rad(BANGER_SWAY)
		motor.C0 = base * CFrame.Angles(math.rad(BANGER_PITCH), 0, sway)
	end)
	return function()
		connection:Disconnect()
		motor.C0 = base
	end
end

local function firstSound(keys: { string }): string?
	for _, key in keys do
		const row = Content.Sounds.ByKey[key]
		if row ~= nil and row.Id ~= "" then
			return key
		end
	end
	return nil
end

-- neck_snap: mark the rig (the neck modifier reads it) and crack at the head
local function snapNeck(ctx: Effect.Context, npcId: number)
	const model = ctx.Npc(npcId)
	if model == nil or model:GetAttribute("Tic") == "Done" then
		return
	end
	model:SetAttribute(SNAP_ATTRIBUTE, os.clock())
	const head = model:FindFirstChild("Head")
	ctx.Audio:Play(CRACK_KEY, if head ~= nil and head:IsA("BasePart") then head else model:GetPivot().Position)
end

-- A short camera kick for this client when it stands within `radius` studs of `at`
local function kick(at: Vector3?, radius: number)
	const character = Players.LocalPlayer.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	const camera = Workspace.CurrentCamera
	if at == nil or camera == nil or root == nil or not root:IsA("BasePart") then
		return
	end
	if (root.Position - at).Magnitude > radius then
		return
	end
	const started = os.clock()
	local last = 0
	const connection = RunService.RenderStepped:Connect(function()
		const t = (os.clock() - started) / SLAM_KICK_TIME
		const angle = if t < 1 then SLAM_KICK_ANGLE * math.sin(t * math.pi) else 0
		camera.CFrame = camera.CFrame * CFrame.Angles(angle - last, 0, 0)
		last = angle
	end)
	task.delay(SLAM_KICK_TIME + 0.05, function()
		connection:Disconnect()
	end)
end

-- window_slam: the bang at the service window and a short camera kick nearby
local function slamWindow(ctx: Effect.Context)
	const trailer = ctx.Point("TRL")
	const at = if trailer ~= nil then TrailerFront.Of(trailer, ctx.Point("WALKER-10")).Window else nil
	const key = firstSound(SLAM_KEYS)
	if key ~= nil then
		ctx.Audio:Play(key, at, { Volume = 1 })
	end
	kick(at, SLAM_KICK)
end

-- Builds the effect module of one family A anomaly.
function OddCustomer.Effect(ref: string, variant: Variant): Effect.Module
	return {
		Ref = ref,
		Mount = function(ctx: Effect.Context, occ: Effect.Occurrence)
			Vide.cleanup(Actor.Follow(ctx, occ, variant, `odd_{variant}`, function(model: Model): Actor.Undo
				-- anomaly tics (Content.Tics): a variant with a row gets its body from Kit/Tic (owner 2026-10-22: the white
				-- eyes and the big head join the turned neck); without the row the old modifier below (rollback)
				const tic = Content.Tics.ByVariant[variant]
				if variant == "shake" then
					-- the tremor + the tantrum of condition Plain (Kit/Tantrum: the throw pose, the rage)
					const undoShake = shake(model)
					const undoTantrum = Tantrum.Mount(ctx, model)
					return function()
						undoTantrum()
						undoShake()
					end
				elseif variant == "neck" then
					return if tic ~= nil then Tic.Mount(ctx, model, tic) else neck(model)
				elseif variant == "bighead" then
					return if tic ~= nil then Tic.Mount(ctx, model, tic) else bighead(model)
				elseif variant == "float" then
					return float(model)
				elseif variant == "stare" then
					return stare(model)
				elseif variant == "banger" then
					return banger(model)
				elseif variant == "oncam" then
					return oncam(model)
				end
				-- eyes: the face is the sign; the idle is held still like the blank folks (with a tic row the white eyes
				-- wait for the talk, Kit/Tic)
				const still = Actor.HoldStill(ctx, model)
				if variant == "eyes" and tic ~= nil then
					const undoTic = Tic.Mount(ctx, model, tic)
					return function()
						undoTic()
						still()
					end
				end
				return still
			end))
		end,
		Cue = function(ctx: Effect.Context, cue: Effect.Cue)
			if cue.Cue == "neck_snap" then
				snapNeck(ctx, cue.Entity)
			elseif cue.Cue == "window_slam" then
				slamWindow(ctx)
			elseif cue.Cue == "plate_throw" then
				Tantrum.Throw(ctx, cue.Entity)
			else
				Jumpscare.Cue(ctx, cue)
			end
		end,
	}
end

return table.freeze(OddCustomer)
