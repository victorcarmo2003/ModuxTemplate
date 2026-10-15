--!strict
--[[
	V2 family A, odd customers (DEC-254; TASK-292; anomalies-v2-proposal.md §3 A). One deformation per actor, read
	in under a second, applied ONLY on this client to the server rig (Motor6D C0/C1, part sizes): presentation, never
	a verb (T10). Bound to the rig's `Variant` through CustomerActor.Follow, so it lasts while the actor walks off and
	is undone when the pool clears the attribute.

	Variants (rig attribute written by NpcService):
	  shake    ANM-011  the whole body shakes fast (RootJoint C0 jitter)
	  neck     ANM-012  the head is turned 180° around the neck and sways a little
	  eyes     ANM-013  all-white eyes: the face is RigController's (VARIANT_FACE); here only the idle is held still
	  bighead  ANM-014  head and everything welded to it at BIG_HEAD × size, growing up from the neck
	  float    ANM-015  the body hovers FLOAT studs above the ground with a slow bob
	  stare    ANM-016  the head always turns to the local camera (clamped to STARE_MAX)

	Rotations go around the torso's up axis expressed in the joint frame, so they hold whatever the R6 C0 layout is.
	The `jumpscare` cue of every family A anomaly is handled here too (Kit/Jumpscare).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Effect = require(script.Parent.Parent.Parent.Effect)
local Actor = require(script.Parent.CustomerActor)
local Jumpscare = require(script.Parent.Jumpscare)

const SHAKE_MOVE = 0.08 -- studs of jitter
const SHAKE_TURN = math.rad(4)
const NECK_SWAY = math.rad(8)
const NECK_SWAY_SPEED = 0.7 -- rad/s of the sway
const BIG_HEAD = 1.9
const FLOAT = 0.7 -- studs
const FLOAT_BOB = 0.12
const FLOAT_BOB_SPEED = 1.6
const STARE_MAX = math.rad(110)
const STARE_TURN = 10 -- 1/s, how fast the head catches the camera

export type Variant = "shake" | "neck" | "eyes" | "bighead" | "float" | "stare"

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
		const offset = Vector3.new(
			rng:NextNumber(-SHAKE_MOVE, SHAKE_MOVE),
			rng:NextNumber(-SHAKE_MOVE, SHAKE_MOVE),
			rng:NextNumber(-SHAKE_MOVE, SHAKE_MOVE)
		)
		root.C0 = base * CFrame.new(offset) * yaw(base, rng:NextNumber(-SHAKE_TURN, SHAKE_TURN))
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
	const connection = RunService.Heartbeat:Connect(function()
		const sway = math.sin((os.clock() - started) * NECK_SWAY_SPEED) * NECK_SWAY
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

-- Builds the effect module of one family A anomaly.
function OddCustomer.Effect(ref: string, variant: Variant): Effect.Module
	return {
		Ref = ref,
		Mount = function(ctx: Effect.Context, occ: Effect.Occurrence)
			Vide.cleanup(Actor.Follow(ctx, occ, variant, `odd_{variant}`, function(model: Model): Actor.Undo
				if variant == "shake" then
					return shake(model)
				elseif variant == "neck" then
					return neck(model)
				elseif variant == "bighead" then
					return bighead(model)
				elseif variant == "float" then
					return float(model)
				elseif variant == "stare" then
					return stare(model)
				end
				-- eyes: the face is the sign; the idle is held still like the blank folks
				return Actor.HoldStill(ctx, model)
			end))
		end,
		Cue = Jumpscare.Cue,
	}
end

return table.freeze(OddCustomer)
