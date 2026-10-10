--!strict
-- roof_steps (< 40; script.md §8, sound-list.md SFX-130): light, slow steps crossing the trailer roof. Audio only.
-- Only on the trailer with the player inside or right next to it. The key `roof_step` is not in Content.Sounds yet
-- (Q-168): until then the effect plays silently (Provisional).
local Context = require(script.Parent.Parent.Context)

const VEHICLE = "trailer"
const KEY = "roof_step"
const STEPS = 5
const STEP_TIME = 0.75 -- s: 3-4 s in total (sound-list)
const NEAR = 6 -- studs of margin around the trailer box
const ROOF_LIFT = 0.5

local function box(env: Context.Env): (CFrame?, Vector3?)
	if env.VehicleKey() ~= VEHICLE then
		return nil, nil
	end
	const vehicle = env.Vehicle()
	if vehicle == nil or not vehicle:IsA("Model") then
		return nil, nil
	end
	const frame, size = vehicle:GetBoundingBox()
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

const RoofSteps: Context.Effect = {
	CanRun = function(env: Context.Env): boolean
		const frame, size = box(env)
		return frame ~= nil and size ~= nil and near(frame, size)
	end,

	Play = function(env: Context.Env, run: Context.Run)
		const frame, size = box(env)
		if frame == nil or size == nil then
			return
		end
		-- along the long side of the roof, from a random end
		const long = if size.X >= size.Z then Vector3.xAxis * (size.X / 2) else Vector3.zAxis * (size.Z / 2)
		const sign = if env.Random:NextNumber() < 0.5 then -1 else 1
		const top = Vector3.yAxis * (size.Y / 2 + ROOF_LIFT)
		for step = 1, STEPS do
			const t = (step - 1) / (STEPS - 1) -- 0..1
			const offset = long * sign * (0.7 - 1.4 * t) + top
			env.Sound(KEY, frame:PointToWorldSpace(offset), { Volume = 0.8 })
			if not run:Wait(STEP_TIME * env.Random:NextNumber(0.85, 1.15)) then
				return
			end
		end
	end,
}

return RoofSteps
