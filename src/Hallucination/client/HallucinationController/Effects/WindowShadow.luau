--!strict
-- window_shadow (< 20; script.md §8, AST-085 `Shadow_Card`, sound-list.md SFX-134): a shadow passes behind a trailer
-- window, at the edge of the view ("vulto na periferia"); never in the middle of the screen, never a face, no chase.
-- Asset: ReplicatedStorage.Assets...Shadow_Card when it exists; until then a placeholder silhouette of a generic crew
-- member (round head, small round ears, #2B2233, height 5) that must not recall the Walker (#14162A, tall, hat).
-- Placement: a window/glass part of the current vehicle seen between PERIPHERY_MIN..MAX degrees; without one, a
-- point at the side of the view (Provisional until the trailer's back window gets a name in AST-027).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Context = require(script.Parent.Parent.Context)

const ASSET_NAME = "Shadow_Card"
const KEY = "shadow_whoosh" -- SFX-134, no key yet (Q-168)
const COLOR = Color3.fromHex("#2B2233")
const TRANSPARENCY = 0.15
const PERIPHERY_MIN = 30 -- degrees
const PERIPHERY_MAX = 75
const WINDOW_RANGE = 45 -- studs
const BEHIND = 2.5 -- studs past the glass, away from the camera
const FALLBACK_DISTANCE = 16
const FALLBACK_ANGLE = 55
const CROSS = 5 -- studs walked across
const TIME = 0.6 -- s (sound-list: 0.6 s)
const STEP = 1 / 30

local function isWindow(part: BasePart): boolean
	const lower = string.lower(part.Name)
	if string.find(lower, "service", 1, true) then
		return false -- the service window faces the customers: not "the back"
	end
	return part.Material == Enum.Material.Glass or string.find(lower, "window", 1, true) ~= nil
end

local function windowSpot(env: Context.Env): Vector3?
	const vehicle = env.Vehicle()
	const camera = Context.Camera()
	if vehicle == nil or camera == nil then
		return nil
	end
	const spots: { Vector3 } = {}
	for _, descendant in vehicle:GetDescendants() do
		if descendant:IsA("BasePart") and isWindow(descendant) then
			const angle, distance = Context.ViewAngle(descendant.Position)
			if angle ~= nil and angle >= PERIPHERY_MIN and angle <= PERIPHERY_MAX and distance <= WINDOW_RANGE then
				const away = (descendant.Position - camera.CFrame.Position).Unit
				table.insert(spots, descendant.Position + away * BEHIND)
			end
		end
	end
	if #spots == 0 then
		return nil
	end
	return spots[env.Random:NextInteger(1, #spots)]
end

local function fallbackSpot(env: Context.Env): Vector3?
	const camera = Context.Camera()
	if camera == nil then
		return nil
	end
	const side = if env.Random:NextNumber() < 0.5 then -1 else 1
	const look = camera.CFrame.LookVector
	const flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		return nil
	end
	const direction = CFrame.fromAxisAngle(Vector3.yAxis, math.rad(FALLBACK_ANGLE * side)):VectorToWorldSpace(flat.Unit)
	const root = Context.Root()
	const base = if root then root.Position else camera.CFrame.Position
	return base + direction * FALLBACK_DISTANCE
end

local function part(name: string, size: Vector3, shape: Enum.PartType?): Part
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
	made.Color = COLOR
	made.Transparency = TRANSPARENCY
	return made
end

-- Placeholder Shadow_Card: pivot at the feet, height 5.
local function placeholder(): Model
	const model = Instance.new("Model")
	model.Name = ASSET_NAME
	const body = part("Body", Vector3.new(1.8, 2.6, 0.9))
	body.CFrame = CFrame.new(0, 1.3, 0)
	body.Parent = model
	const head = part("Head", Vector3.new(2.2, 2.2, 2.2), Enum.PartType.Ball)
	head.CFrame = CFrame.new(0, 3.7, 0)
	head.Parent = model
	for _, x in { -0.8, 0.8 } do
		const ear = part("Ear", Vector3.new(0.7, 0.7, 0.7), Enum.PartType.Ball)
		ear.CFrame = CFrame.new(x, 4.75, 0)
		ear.Parent = model
	end
	model.PrimaryPart = body
	model.WorldPivot = CFrame.new()
	return model
end

local function card(): Model
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const found = if assets then assets:FindFirstChild(ASSET_NAME, true) else nil
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

const WindowShadow: Context.Effect = {
	CanRun = function(env: Context.Env): boolean
		return Context.Camera() ~= nil and (windowSpot(env) ~= nil or fallbackSpot(env) ~= nil)
	end,

	Play = function(env: Context.Env, run: Context.Run)
		const spot = windowSpot(env) or fallbackSpot(env)
		const camera = Context.Camera()
		if spot == nil or camera == nil then
			return
		end
		-- feet on the spot's floor: windows are ~3 studs above the trailer floor
		const feet = spot - Vector3.new(0, 3, 0)
		const toCamera = camera.CFrame.Position - feet
		const flat = Vector3.new(toCamera.X, 0, toCamera.Z)
		const facing = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
		const across = facing:Cross(Vector3.yAxis).Unit
		const sign = if env.Random:NextNumber() < 0.5 then -1 else 1
		const from = feet - across * sign * CROSS / 2
		const to = feet + across * sign * CROSS / 2

		const model = card()
		run:Cleanup(function()
			model:Destroy()
		end)
		model:PivotTo(CFrame.lookAt(from, from + facing))
		model.Parent = Workspace
		env.Sound(KEY, feet, { Volume = 0.5 })

		const started = os.clock()
		while true do
			const t = math.clamp((os.clock() - started) / TIME, 0, 1)
			const at = from:Lerp(to, t)
			model:PivotTo(CFrame.lookAt(at, at + facing))
			if t >= 1 or not run:Wait(STEP) then
				return
			end
		end
	end,
}

return WindowShadow
