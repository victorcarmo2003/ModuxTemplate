--!strict
-- window_face (< 20, family D; anomalies-v2-proposal.md §3 D; DEC-254, DEC-256): a round cartoon face peeks through
-- one of the current vehicle's windows for 0.3 s and is gone. Silent, small, in the window frame: a "did I see
-- that?", never a jumpscare (no sound sting, never fills the screen, never closer than MIN_RANGE).
-- Asset: ReplicatedStorage.Assets...Window_Face when it exists (pivot at the face centre, facing -Z); until then a
-- placeholder head (#2B2233, round ears, big white eyes with dark pupils) that must not recall the Walker.
-- Window: a Glass / "window" part of the vehicle in view (cone, range), not the tip jar; the face sits BEHIND the
-- glass, away from the camera.
local Workspace = game:GetService("Workspace")
local Context = require(script.Parent.Parent.Context)

const ASSET_NAME = "Window_Face"
const COLOR = Color3.fromHex("#2B2233")
const EYE = Color3.fromHex("#F4EBDD")
const PUPIL = Color3.fromHex("#14121A")
const CONE = 55 -- degrees: the window must be in view
const MIN_RANGE = 6 -- studs: never right in the player's face
const MAX_RANGE = 32
const BEHIND = 1.6 -- studs past the glass
const SHOW = 0.3 -- s (§3 D)
const SKIP = { "tip", "jar", "cup", "bin" } -- glass that is not a window

type Spot = { At: Vector3, Distance: number }

local function isWindow(part: BasePart): boolean
	const lower = string.lower(part.Name)
	for _, word in SKIP do
		if string.find(lower, word, 1, true) then
			return false
		end
	end
	return part.Material == Enum.Material.Glass
		or string.find(lower, "window", 1, true) ~= nil
		or string.find(lower, "glass", 1, true) ~= nil
end

local function spots(env: Context.Env): { Spot }
	const out: { Spot } = {}
	const vehicle = env.Vehicle()
	const camera = Context.Camera()
	if vehicle == nil or camera == nil then
		return out
	end
	for _, descendant in vehicle:GetDescendants() do
		if descendant:IsA("BasePart") and isWindow(descendant) and descendant.Size.Magnitude > 1.5 then
			const angle, distance = Context.ViewAngle(descendant.Position)
			if angle ~= nil and angle <= CONE and distance >= MIN_RANGE and distance <= MAX_RANGE then
				const away = (descendant.Position - camera.CFrame.Position).Unit
				table.insert(out, { At = descendant.Position + away * BEHIND, Distance = distance })
			end
		end
	end
	return out
end

local function placeholder(): Model
	const model = Instance.new("Model")
	model.Name = ASSET_NAME
	const head = Context.Prop("Head", Vector3.new(2.2, 2.2, 2.2), COLOR, Enum.PartType.Ball)
	head.CFrame = CFrame.new()
	head.Parent = model
	for _, x in { -0.85, 0.85 } do
		const ear = Context.Prop("Ear", Vector3.new(0.8, 0.8, 0.8), COLOR, Enum.PartType.Ball)
		ear.CFrame = CFrame.new(x, 1, 0)
		ear.Parent = model
	end
	for _, x in { -0.42, 0.42 } do
		-- cylinders lie along X: turn them to face -Z
		const eye = Context.Prop("Eye", Vector3.new(0.3, 0.62, 0.62), EYE, Enum.PartType.Cylinder)
		eye.CFrame = CFrame.new(x, 0.18, -1.0) * CFrame.Angles(0, math.rad(90), 0)
		eye.Parent = model
		const pupil = Context.Prop("Pupil", Vector3.new(0.32, 0.3, 0.3), PUPIL, Enum.PartType.Cylinder)
		pupil.CFrame = CFrame.new(x, 0.16, -1.06) * CFrame.Angles(0, math.rad(90), 0)
		pupil.Parent = model
	end
	model.PrimaryPart = head
	model.WorldPivot = CFrame.new()
	return model
end

const WindowFace: Context.Effect = {
	CanRun = function(env: Context.Env): boolean
		return #spots(env) > 0
	end,

	Play = function(env: Context.Env, run: Context.Run)
		const list = spots(env)
		const camera = Context.Camera()
		if #list == 0 or camera == nil then
			return
		end
		const spot = list[env.Random:NextInteger(1, #list)]
		const model = Context.Asset(ASSET_NAME, placeholder)
		run:Cleanup(function()
			model:Destroy()
		end)
		-- the pivot looks along -Z: lookAt the eye turns the face to the player
		model:PivotTo(CFrame.lookAt(spot.At, camera.CFrame.Position))
		model.Parent = Workspace
		run:Wait(SHOW)
	end,
}

return WindowFace
