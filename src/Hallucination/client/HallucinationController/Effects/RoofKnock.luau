--!strict
-- roof_knock (< 40, family D; anomalies-v2-proposal.md §3 D; DEC-254): three slow knocks on the trailer roof, a
-- pause, one more. Audio only (`door_knock` played from the roof, a bit lower). Only with the player inside or right
-- next to the trailer. Sibling of roof_steps (steps walk across, knocks stay on one spot).
local Context = require(script.Parent.Parent.Context)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VehicleRoot = require(ReplicatedStorage.shared.Vehicle.VehicleRoot)

const VEHICLE = "trailer"
const KEY = "door_knock" -- Provisional: a dedicated roof knock has no key yet
const NEAR = 6 -- studs of margin around the trailer box
const ROOF_LIFT = 0.5
const KNOCKS = { 0, 0.45, 0.9, 2.4 } -- s from the start: three, a pause, one more
const SPEED = 0.8 -- lower pitch: heavier, from above
const VOLUME = 0.7

local function box(env: Context.Env): (CFrame?, Vector3?)
	if env.VehicleKey() ~= VEHICLE then
		return nil, nil
	end
	const vehicle = env.Vehicle()
	if vehicle == nil or not (vehicle:IsA("Model") or vehicle:IsA("Folder")) then
		return nil, nil
	end
	const frame, size = VehicleRoot.Box(vehicle)
	return frame, size
end

local function near(frame: CFrame, size: Vector3): boolean
	const root = Context.Root()
	if root == nil then
		return false
	end
	const point = frame:PointToObjectSpace(root.Position)
	const half = size / 2 + Vector3.new(NEAR, NEAR, NEAR)
	return math.abs(point.X) <= half.X and math.abs(point.Y) <= half.Y and math.abs(point.Z) <= half.Z
end

const RoofKnock: Context.Effect = {
	CanRun = function(env: Context.Env): boolean
		const frame, size = box(env)
		return frame ~= nil and size ~= nil and near(frame, size)
	end,

	Play = function(env: Context.Env, run: Context.Run)
		const frame, size = box(env)
		if frame == nil or size == nil then
			return
		end
		-- one spot on the roof, somewhere along the long side
		const long = if size.X >= size.Z then Vector3.xAxis * (size.X / 2) else Vector3.zAxis * (size.Z / 2)
		const offset = long * env.Random:NextNumber(-0.6, 0.6) + Vector3.yAxis * (size.Y / 2 + ROOF_LIFT)
		const at = frame:PointToWorldSpace(offset)
		local elapsed = 0
		for _, time in KNOCKS do
			if time > elapsed and not run:Wait(time - elapsed) then
				return
			end
			elapsed = time
			env.Sound(KEY, at, { Volume = VOLUME, Speed = SPEED, Vary = 0.05 })
		end
		run:Wait(0.6)
	end,
}

return RoofKnock
