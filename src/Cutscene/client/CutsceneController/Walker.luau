--!strict
--[[
	Walker: steers the OWN body along the shared Route while the server keeps it frozen for the cutscene
	(attribute `Frozen`). Presentation only: the server placed the body, decides the targets (same Route, same map
	Anchors) and re-places a body that is far at each MoveTo. The client owns its character's physics, so a smooth
	walk here replicates to every mate.

	  * Position: Humanoid:Move toward the Route point of this instant (planned velocity + a pull on the error), with
	    WalkSpeed = that speed: the Route's acceleration and braking are what the body does (no dry stop).
	  * Facing: AutoRotate off during the scene; the root yaw eases to the Route facing (walk heading, then the end
	    spot's facing while braking). AutoRotate comes back when the scene ends.
	  * Slot: not on the wire; the one whose planned spot is nearest to the body (the server placed it there).
	  * WalkSpeed is only written while `Frozen` is set: when the server unfreezes, its WalkSpeed wins.
	PROVISIONAL (frontend-coder, 2026-10-11): PULL, TURN_RATE, SNAP, LOCK_DISTANCE.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Anchors = require(ReplicatedStorage.shared.Cutscene.Anchors)
local Route = require(ReplicatedStorage.shared.Cutscene.Route)

type Scene = Content.Cutscene

export type Walker = {
	Step: (elapsed: number, dt: number) -> (),
	Stop: () -> (),
	-- the own walk plan (nil = slot not found yet)
	Plan: () -> Route.Plan?,
}

const FROZEN_ATTRIBUTE = "Frozen"
const PULL = 2.5 -- 1/s: velocity added per stud of error
const MAX_EXTRA = 5 -- studs/s above the plan to catch up
const ARRIVED = 0.35 -- studs: close enough while the plan stands still
const TURN_RATE = 7 -- 1/s ease of the root yaw
const SNAP = 18 -- studs off the plan: put the body back on it
const LOCK_DISTANCE = 6 -- studs: the body stands on this slot's planned spot
const REBUILD = 1 -- s between two builds of a plan with a missing target
const MAX_SLOTS = 4
const SEARCH_EVERY = 0.25 -- s between two slot searches

const Walker = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function yawOf(look: Vector3): number
	return math.atan2(-look.X, -look.Z)
end

local function angleDelta(from: number, to: number): number
	return (to - from + math.pi) % (2 * math.pi) - math.pi
end

local function isFrozen(character: Model): boolean
	const value = character:GetAttribute(FROZEN_ATTRIBUTE)
	return value == true or (type(value) == "string" and value ~= "")
end

function Walker.new(scene: Scene, count: number): Walker
	local slot: number? = nil
	local plan: Route.Plan? = nil
	local builtAt = 0
	local humanoid: Humanoid? = nil
	local autoRotate: boolean? = nil
	local yaw: number? = nil
	local moving = false
	local searchedAt = -math.huge

	local function release()
		const h = humanoid
		if h ~= nil and h.Parent ~= nil then
			h:Move(Vector3.zero, false)
			if autoRotate ~= nil then
				h.AutoRotate = autoRotate
			end
		end
		humanoid = nil
		autoRotate = nil
		yaw = nil
		moving = false
	end

	local function planOf(s: number): Route.Plan
		return Route.Build(scene, s, count, Anchors.Spot)
	end

	-- Slot whose planned spot (now) is nearest to the body
	local function findSlot(root: BasePart, elapsed: number): number?
		local best: number? = nil
		local bestDistance = LOCK_DISTANCE
		for s = 1, math.clamp(count, 1, MAX_SLOTS) do
			const position = Route.Sample(planOf(s), elapsed)
			if position ~= nil then
				const distance = flat(position - root.Position).Magnitude
				if distance < bestDistance then
					best = s
					bestDistance = distance
				end
			end
		end
		return best
	end

	return {
		Step = function(elapsed: number, dt: number)
			const character = Players.LocalPlayer.Character
			const h = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
			const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
			if character == nil or h == nil or root == nil or not root:IsA("BasePart") or not isFrozen(character) then
				release()
				return
			end
			if h ~= humanoid then
				release()
				humanoid = h
			end
			const now = os.clock()
			if slot == nil then
				if now - searchedAt < SEARCH_EVERY then
					return
				end
				searchedAt = now
				slot = findSlot(root, elapsed)
				if slot == nil then
					return
				end
			end
			local current = plan
			if current == nil or (current.Missing and now - builtAt >= REBUILD) then
				current = planOf(slot :: number)
				plan = current
				builtAt = now
			end
			const p = current :: Route.Plan
			if #p.Runs == 0 then
				return -- nothing to walk in this scene: the server's placement stands
			end
			if autoRotate == nil then
				autoRotate = h.AutoRotate
				h.AutoRotate = false
			end

			const target, velocity, facing = Route.Sample(p, elapsed)
			if target == nil then
				return
			end
			const offset = flat(target - root.Position)
			if offset.Magnitude > SNAP then
				root.CFrame = CFrame.new(Vector3.new(target.X, root.Position.Y, target.Z)) * root.CFrame.Rotation
				return
			end
			const planned = flat(velocity)
			local desired = planned + offset * PULL
			const cap = planned.Magnitude + MAX_EXTRA
			if desired.Magnitude > cap then
				desired = desired.Unit * cap
			end
			if planned.Magnitude < 1e-3 and offset.Magnitude < ARRIVED then
				desired = Vector3.zero
			end
			if desired.Magnitude > 0.05 then
				h.WalkSpeed = desired.Magnitude
				h:Move(desired.Unit, false)
				moving = true
			elseif moving then
				h:Move(Vector3.zero, false)
				moving = false
			end

			-- smooth turn to the planned facing (walk heading, then the end spot)
			const look = if facing ~= nil then facing else (if planned.Magnitude > 0.1 then planned.Unit else nil)
			if look ~= nil then
				const goal = yawOf(look)
				local turned = yaw or yawOf(root.CFrame.LookVector)
				turned += angleDelta(turned, goal) * (1 - math.exp(-TURN_RATE * dt))
				yaw = turned
				root.CFrame = CFrame.new(root.Position) * CFrame.fromOrientation(0, turned, 0)
			end
		end,
		Stop = release,
		Plan = function(): Route.Plan?
			if plan == nil and slot ~= nil then
				plan = planOf(slot :: number)
				builtAt = os.clock()
			end
			return plan
		end,
	}
end

return table.freeze(Walker)
