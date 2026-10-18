--!strict
-- Night watchers (owner 2026-10-18, art direction; DEC-296 Provisional). While an anomaly with Tension runs, the server
-- dresses the street customers in the Night pack (NpcService:SetTension: dark skin, green eyes). Here, on each client,
-- those customers turn their heads slowly to follow THIS player's camera, as if they were all staring; when the pack
-- goes back (the anomaly ended) the heads settle back to the animation. Presentation only (T10).
-- Only rigs under Workspace.Npcs with LookPack "Night" and no Variant (a customer-anomaly actor keeps its own head:
-- the family A modifiers and the stare pressure drive it). The turn is written on the Neck Motor6D C1 (after the
-- animation), the same way as AnomalyController/Stare, so both never fight over C0.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

export type NightWatch = { Destroy: () -> () }

type Pose = {
	Model: Model,
	Head: BasePart,
	Motor: Motor6D,
	BaseC1: CFrame,
	Turn: number, -- rad around the torso's up
	Seed: number,
}

const FOLDER_NAME = "Npcs"
const NIGHT_PACK = "Night"
const VARIANT_ATTRIBUTE = "Variant"
const RANGE = 70 -- studs from the camera; farther heads settle back
const SPEED = math.rad(55) -- rad/s at most (slow, creepy)
const MAX_TURN = math.rad(110) -- past the animation's own pose
const SETTLE = 3 -- 1/s back to the pose when released
const DELAY_SPREAD = 1.6 -- s: each head starts turning a little later than the last (seeded)
const SCAN_EVERY = 0.5 -- s between rescans of the folder
const EPSILON = 1e-4

local function signedAngle(from: Vector3, to: Vector3, up: Vector3): number
	const a = from - up * from:Dot(up)
	const b = to - up * to:Dot(up)
	if a.Magnitude < EPSILON or b.Magnitude < EPSILON then
		return 0
	end
	return math.atan2(a.Unit:Cross(b.Unit):Dot(up), a.Unit:Dot(b.Unit))
end

local function watching(model: Model): boolean
	return model:GetAttribute("LookPack") == NIGHT_PACK and model:GetAttribute(VARIANT_ATTRIBUTE) == nil
end

local function poseOf(model: Model, seed: number): Pose?
	const torso = model:FindFirstChild("Torso")
	const neck = if torso ~= nil then torso:FindFirstChild("Neck") else nil
	const head = model:FindFirstChild("Head")
	if neck == nil or not neck:IsA("Motor6D") or head == nil or not head:IsA("BasePart") then
		return nil
	end
	return { Model = model, Head = head, Motor = neck, BaseC1 = neck.C1, Turn = 0, Seed = seed }
end

return function(): NightWatch
	const poses: { [Model]: Pose } = {}
	const since: { [Model]: number } = {} -- os.clock when the rig went Night
	local seed = 0
	local scanned = 0

	local function release(pose: Pose)
		if pose.Motor.Parent ~= nil then
			pose.Motor.C1 = pose.BaseC1
		end
	end

	local function scan(now: number)
		const folder = Workspace:FindFirstChild(FOLDER_NAME)
		if folder == nil then
			return
		end
		for _, child in folder:GetChildren() do
			if child:IsA("Model") and poses[child] == nil and watching(child) then
				seed += 1
				const pose = poseOf(child, seed)
				if pose ~= nil then
					poses[child] = pose
					since[child] = now + ((seed * 0.618) % 1) * DELAY_SPREAD
				end
			end
		end
	end

	const connection = RunService.RenderStepped:Connect(function(dt: number)
		const now = os.clock()
		if now - scanned >= SCAN_EVERY then
			scanned = now
			scan(now)
		end
		const camera = Workspace.CurrentCamera
		const character = Players.LocalPlayer.Character
		for model, pose in poses do
			const motor = pose.Motor
			const torso = motor.Part0
			if model.Parent == nil or motor.Parent == nil or torso == nil then
				poses[model] = nil
				since[model] = nil
				continue
			end
			const view = if camera ~= nil then camera.CFrame.Position else nil
			const driven = watching(model)
				and view ~= nil
				and character ~= nil
				and now >= (since[model] or now)
				and (view - pose.Head.Position).Magnitude <= RANGE
			if driven and view ~= nil then
				const up = torso.CFrame.UpVector
				const miss = signedAngle(pose.Head.CFrame.LookVector, view - pose.Head.Position, up)
				const step = SPEED * dt
				pose.Turn = math.clamp(pose.Turn + math.clamp(miss, -step, step), -MAX_TURN, MAX_TURN)
			else
				pose.Turn -= pose.Turn * math.min(1, dt * SETTLE)
				if not watching(model) and math.abs(pose.Turn) < math.rad(0.5) then
					release(pose)
					poses[model] = nil
					since[model] = nil
					continue
				end
			end
			const axis = motor.C0:VectorToObjectSpace(Vector3.yAxis)
			motor.C1 = pose.BaseC1 * CFrame.fromAxisAngle(axis, pose.Turn):Inverse()
		end
	end)

	return {
		Destroy = function()
			connection:Disconnect()
			for _, pose in poses do
				release(pose)
			end
			table.clear(poses)
			table.clear(since)
		end,
	}
end
