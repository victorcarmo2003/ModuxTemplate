--!strict
-- Black cloak dash (owner 2026-10-21, Provisional): a tall black cloak runs along the avenue in front of the shop, very
-- fast, with the shadow_whoosh riding on it. Used by Effects/CaveSound (its whoosh) and Effects/ShadowDash (dev trigger).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Context = require(script.Parent.Context)

const WHOOSH = "shadow_whoosh"
const TIME = 6 -- s the effect holds its slot after the dash (the whoosh tails off)

-- owner 2026-10-21: the cloak runs along the avenue seen through the front window (Ninth Avenue, MAP-01), in TRL space
-- (TRL faces away from the street: -Z of TRL is the front). From / To = the two ends, picked in a random order.
const AVENUE = {
	Point = "TRL",
	-- owner 2026-10-21: the near sidewalk just past the patio rail (world z ~43), not the avenue lanes (z ~67, lost in fog)
	From = Vector3.new(32, 0, -38),
	To = Vector3.new(-32, 0, -38),
}
-- fallback with no TRL: a street MapPoint in front of the camera, crossed sideways in DASH_TIME
const STREET: Context.SpotQuery = {
	MinDistance = 25,
	MaxDistance = 70,
	MinAngle = 0,
	MaxAngle = 30, -- in view: the dash must be seen
	Height = 5,
}
const DASH_SPAN = 34 -- studs crossed (fallback)
const DASH_TIME = 0.6 -- s: very fast (the street run is 64 studs)
const CLOAK_HEIGHT = 6.5
const CLOAK_COLOR = Color3.fromRGB(8, 8, 10)
const STEP = 1 / 60

local function part(name: string, size: Vector3, shape: Enum.PartType?): Part
	const made = Instance.new("Part")
	made.Name = name
	made.Shape = shape or Enum.PartType.Block
	made.Size = size
	made.Color = CLOAK_COLOR
	made.Material = Enum.Material.SmoothPlastic
	made.Anchored = true
	made.CanCollide = false
	made.CanQuery = false
	made.CanTouch = false
	made.CastShadow = false
	return made
end

-- Tall black cloak with a hood and a dark smear behind it (Trail)
local function cloak(): (Model, Part)
	const model = Instance.new("Model")
	model.Name = "Hallucination_Cloak"
	const body = part("Body", Vector3.new(2.2, CLOAK_HEIGHT - 1.6, 1.4))
	body.CFrame = CFrame.new(0, (CLOAK_HEIGHT - 1.6) / 2, 0)
	body.Parent = model
	const hood = part("Hood", Vector3.new(1.9, 1.9, 1.9), Enum.PartType.Ball)
	hood.CFrame = CFrame.new(0, CLOAK_HEIGHT - 0.9, 0)
	hood.Parent = model
	const top = Instance.new("Attachment")
	top.Position = Vector3.new(0, body.Size.Y / 2, 0)
	top.Parent = body
	const bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -body.Size.Y / 2, 0)
	bottom.Parent = body
	const trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(CLOAK_COLOR)
	trail.Transparency = NumberSequence.new(0.3, 1)
	trail.Lifetime = 0.25
	trail.Parent = body
	model.PrimaryPart = body
	model.WorldPivot = CFrame.new() -- pivot at the feet
	return model, body
end

const Cloak = {}

-- (from, direction, span) of the dash: the avenue in front of the shop when the map has it, else a street MapPoint in
-- view crossed sideways; nil = neither
local function path(env: Context.Env): (Vector3?, Vector3, number)
	const flip = env.Random:NextNumber() < 0.5
	const ok, anchor = pcall(MapIndex.FindPoint, AVENUE.Point)
	if ok and anchor ~= nil then
		const a = anchor:PointToWorldSpace(AVENUE.From)
		const b = anchor:PointToWorldSpace(AVENUE.To)
		const from, to = if flip then b else a, if flip then a else b
		const flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
		return from, flat.Unit, flat.Magnitude
	end
	const camera = Context.Camera()
	const spots = Context.FarSpots(STREET)
	if camera == nil or #spots == 0 then
		return nil, Vector3.xAxis, 0
	end
	const spot = spots[env.Random:NextInteger(1, #spots)].Position
	const right = camera.CFrame.RightVector
	const side = Vector3.new(right.X, 0, right.Z).Unit * (if flip then 1 else -1)
	return spot - side * (DASH_SPAN / 2), side, DASH_SPAN
end

-- The dash; false = nowhere to run (the caller plays the plain sound)
function Cloak.Dash(env: Context.Env, run: Context.Run): boolean
	const from, side, span = path(env)
	if from == nil then
		return false
	end
	const model, body = cloak()
	run:Cleanup(function()
		model:Destroy()
	end)
	model:PivotTo(CFrame.lookAt(from, from + side))
	model.Parent = Workspace
	-- on a point, not on the cloak: the cloak is gone after DASH_TIME and would cut the whoosh short
	env.Sound(WHOOSH, from + side * (span / 2) + Vector3.new(0, CLOAK_HEIGHT / 2, 0), { Vary = 0.08, Scare = true })
	const started = os.clock()
	while true do
		const t = math.min((os.clock() - started) / DASH_TIME, 1)
		const at = from + side * (span * t)
		model:PivotTo(CFrame.lookAt(at, at + side))
		if t >= 1 or not run:Wait(STEP) then
			break
		end
	end
	model:Destroy()
	run:Wait(TIME)
	return true
end

return Cloak
