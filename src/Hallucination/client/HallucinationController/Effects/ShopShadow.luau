--!strict
-- shop_shadow (< 20, family D from Night 1; owner 2026-10-20, Provisional Q-415): while the player works inside the shop
-- (the vehicle: trailer or restaurant), a dark figure stands at the edge of the view, inside, a few steps away. The
-- moment the player turns to it, it is gone, with a short jolt of the camera (CameraController HorrorShake "Jolt") and
-- a low whoosh; sometimes a second one flicks at the other edge right after. Never looked at within WAIT s: it slips
-- out of view on its own. No verb, no sanity cost, no jumpscare (DEC-256), never in the middle of the screen at spawn.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local VehicleRoot = require(ReplicatedStorage.shared.Vehicle.VehicleRoot)
local Actors = require(script.Parent.Parent.Actors)
local Context = require(script.Parent.Parent.Context)

const WHOOSH = "shadow_whoosh" -- SFX-134
const HEIGHT = 5
const TRANSPARENCY = 0.1
const ANGLES = { 38, 50, 62, 74 } -- degrees off the look: the edge of the view, both sides
const DISTANCES = { 7, 9, 5.5, 11 } -- studs
const INSIDE_MARGIN = 1 -- studs kept from the box walls
const SEEN_CONE = 16 -- degrees: the player turned to it
const SEEN_TIME = 0.1 -- s: gone almost at once
const WAIT = 5 -- s it waits at the edge before slipping away unseen
const SLIP = 3 -- studs it slides out of view when unseen
const SLIP_TIME = 0.5
const JOLT = 0.8 -- scale of the "Jolt" shake (mild)
const SECOND_CHANCE = 0.4 -- a second one at the other edge after the first vanished
const SECOND_DELAY = 1.2
const SECOND_TIME = 0.35
const STEP = 1 / 30

type Spot = { Feet: Vector3, Side: number }

-- The vehicle box when the local character is inside it
local function insideBox(env: Context.Env): (CFrame?, Vector3?)
	const vehicle = env.Vehicle()
	const root = Context.Root()
	if vehicle == nil or root == nil or not (vehicle:IsA("Model") or vehicle:IsA("Folder")) then
		return nil, nil
	end
	const frame, size = VehicleRoot.Box(vehicle)
	const point = frame:PointToObjectSpace(root.Position)
	const half = size / 2
	if math.abs(point.X) > half.X or math.abs(point.Y) > half.Y or math.abs(point.Z) > half.Z then
		return nil, nil
	end
	return frame, size
end

local function inBox(frame: CFrame, size: Vector3, at: Vector3): boolean
	const point = frame:PointToObjectSpace(at)
	const half = size / 2 - Vector3.new(INSIDE_MARGIN, 0, INSIDE_MARGIN)
	return math.abs(point.X) <= half.X and math.abs(point.Z) <= half.Z and math.abs(point.Y) <= size.Y / 2
end

-- Spots at the edge of the view inside the shop with a clear line from the camera (`only` = that side, 0 = both)
local function spots(env: Context.Env, only: number): { Spot }
	const out: { Spot } = {}
	const frame, size = insideBox(env)
	const camera = Context.Camera()
	const root = Context.Root()
	if frame == nil or size == nil or camera == nil or root == nil then
		return out
	end
	const look = camera.CFrame.LookVector
	const flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		return out
	end
	for _, side in { -1, 1 } do
		if only ~= 0 and side ~= only then
			continue
		end
		for _, angle in ANGLES do
			const direction = CFrame.fromAxisAngle(Vector3.yAxis, math.rad(angle * side)):VectorToWorldSpace(flat.Unit)
			for _, distance in DISTANCES do
				const at = root.Position + direction * distance
				const feet = at - Actors.HIP
				if inBox(frame, size, at) and Context.Sees(feet + Vector3.new(0, HEIGHT * 0.8, 0), 180, 20) then
					table.insert(out, { Feet = feet, Side = side })
					break
				end
			end
		end
	end
	return out
end

local function place(feet: Vector3): Model
	const model = Actors.Silhouette(HEIGHT, TRANSPARENCY)
	model:PivotTo(Context.FacingCamera(feet))
	model.Parent = Workspace
	return model
end

const ShopShadow: Context.Effect = {
	CanRun = function(env: Context.Env): boolean
		return #spots(env, 0) > 0
	end,

	Play = function(env: Context.Env, run: Context.Run)
		const list = spots(env, 0)
		if #list == 0 then
			return
		end
		const spot = list[env.Random:NextInteger(1, #list)]
		local model: Model? = place(spot.Feet)
		run:Cleanup(function()
			if model then
				model:Destroy()
				model = nil
			end
		end)

		-- waits at the edge; the player turning to it makes it vanish with a jolt
		const head = spot.Feet + Vector3.new(0, HEIGHT * 0.8, 0)
		const started = os.clock()
		local seenFor = 0
		local last = started
		local seen = false
		while os.clock() - started < WAIT do
			if not run:Wait(STEP) then
				return
			end
			const now = os.clock()
			seenFor = if Context.Sees(head, SEEN_CONE, 30) then seenFor + (now - last) else 0
			last = now
			if seenFor >= SEEN_TIME then
				seen = true
				break
			end
		end

		if not seen then
			-- unseen: it slips away out of the view, quietly
			const current = model
			if current == nil then
				return
			end
			const camera = Context.Camera()
			if camera == nil then
				return
			end
			const away = camera.CFrame.RightVector * spot.Side * SLIP
			const from = spot.Feet
			const begin = os.clock()
			while true do
				const t = math.clamp((os.clock() - begin) / SLIP_TIME, 0, 1)
				current:PivotTo(Context.FacingCamera(from:Lerp(from + Vector3.new(away.X, 0, away.Z), t)))
				if t >= 1 or not run:Wait(STEP) then
					return
				end
			end
		end

		-- seen: gone at once, the camera jolts
		if model then
			model:Destroy()
			model = nil
		end
		env.Shake("Jolt", JOLT)
		env.Sound(WHOOSH, spot.Feet, { Volume = 0.45 })

		-- sometimes another one, at the other edge, only for a blink
		if env.Random:NextNumber() >= SECOND_CHANCE or not run:Wait(SECOND_DELAY) then
			return
		end
		const others = spots(env, -spot.Side)
		if #others == 0 then
			return
		end
		const other = others[env.Random:NextInteger(1, #others)]
		model = place(other.Feet)
		env.Sound(WHOOSH, other.Feet, { Volume = 0.3, Speed = 1.2 })
		if not run:Wait(SECOND_TIME) then
			return
		end
		if model then
			model:Destroy()
			model = nil
		end
	end,
}

return ShopShadow
