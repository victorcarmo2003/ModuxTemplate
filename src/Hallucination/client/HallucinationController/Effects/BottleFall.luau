--!strict
-- bottle_fall (< 60, family D; anomalies-v2-proposal.md §3 D; DEC-254): a squeeze bottle of ketchup on the counter
-- tips over by itself while the player looks at it, lands with a soft thud and rolls a little. Local prop only (the
-- trailer has no loose bottle: the counter keeps its bins), never a prep item, never an input, no damage.
--   1. the bottle appears next to the ketchup bin (Bin_Ketchup) OUT of view, standing on the counter (raycast);
--   2. when the player has looked at it for SEEN_TIME, it falls (TIP_TIME, eased) and rolls ROLL studs;
--   3. it is gone once out of view for AWAY_TIME after the fall, or after STAY; never seen within LIFETIME: removed.
-- Asset: ReplicatedStorage.Assets...Ketchup_Bottle when it exists (pivot at the base centre, upright); until then a
-- placeholder (red body, cream cap, nozzle). Thud = `grill_drop` (Provisional until a bottle key exists).
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Context = require(script.Parent.Parent.Context)

const ASSET_NAME = "Ketchup_Bottle"
const BIN_NAME = "Bin_Ketchup"
const KEY = "grill_drop"
const RED = Color3.fromHex("#E2402E")
const CAP = Color3.fromHex("#F4EBDD")
const BOTTLE_HEIGHT = 1.1
const OFFSETS = { 1.4, -1.4, 2.2, -2.2 } -- studs from the bin, along its sides
const NEAR = 28 -- studs: the player is in or next to the trailer
const HIDDEN_CONE = 50 -- degrees: appear only outside this cone
const SEEN_CONE = 30
const SEEN_TIME = 0.5
const TIP_TIME = 0.35
const ROLL = 0.35
const AWAY_TIME = 1
const STAY = 12
const LIFETIME = 25
const STEP = 1 / 30

local function bin(env: Context.Env): BasePart?
	const vehicle = env.Vehicle()
	if vehicle == nil then
		return nil
	end
	const found = vehicle:FindFirstChild(BIN_NAME, true)
	return if found and found:IsA("BasePart") then found else nil
end

-- A free spot on the counter next to the bin, out of view; nil when none.
local function spot(env: Context.Env): Vector3?
	const target = bin(env)
	const root = Context.Root()
	if target == nil or root == nil or (target.Position - root.Position).Magnitude > NEAR then
		return nil
	end
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	const ignore: { Instance } = {}
	const character = Players.LocalPlayer.Character
	if character then
		table.insert(ignore, character)
	end
	params.FilterDescendantsInstances = ignore
	const out: { Vector3 } = {}
	for _, offset in OFFSETS do
		for _, axis in { target.CFrame.RightVector, target.CFrame.LookVector } do
			const flat = Vector3.new(axis.X, 0, axis.Z)
			if flat.Magnitude > 0.1 then
				const above = target.Position + flat.Unit * offset + Vector3.new(0, 3, 0)
				const hit = Workspace:Raycast(above, Vector3.new(0, -6, 0), params)
				if
					hit
					and hit.Normal.Y > 0.9
					and hit.Position.Y > target.Position.Y - 1.5
					and hit.Position.Y < target.Position.Y + 0.6
				then
					const angle = Context.ViewAngle(hit.Position)
					if angle ~= nil and angle > HIDDEN_CONE then
						table.insert(out, hit.Position)
					end
				end
			end
		end
	end
	if #out == 0 then
		return nil
	end
	return out[env.Random:NextInteger(1, #out)]
end

local function placeholder(): Model
	const model = Instance.new("Model")
	model.Name = ASSET_NAME
	-- cylinders lie along X: Angles(0, 0, 90deg) stands them up
	const body = Context.Prop("Body", Vector3.new(0.8, 0.42, 0.42), RED, Enum.PartType.Cylinder)
	body.CFrame = CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, math.rad(90))
	body.Parent = model
	const cap = Context.Prop("Cap", Vector3.new(0.16, 0.36, 0.36), CAP, Enum.PartType.Cylinder)
	cap.CFrame = CFrame.new(0, 0.88, 0) * CFrame.Angles(0, 0, math.rad(90))
	cap.Parent = model
	const nozzle = Context.Prop("Nozzle", Vector3.new(0.1, 0.18, 0.1), CAP)
	nozzle.CFrame = CFrame.new(0, 1.04, 0)
	nozzle.Parent = model
	model.PrimaryPart = body
	model.WorldPivot = CFrame.new()
	return model
end

local function eased(t: number): number
	return t * t -- falls faster as it goes
end

const BottleFall: Context.Effect = {
	CanRun = function(env: Context.Env): boolean
		return spot(env) ~= nil
	end,

	Play = function(env: Context.Env, run: Context.Run)
		const base = spot(env)
		if base == nil then
			return
		end
		const yaw = env.Random:NextNumber(0, math.pi * 2)
		const standing = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
		const model = Context.Asset(ASSET_NAME, placeholder)
		run:Cleanup(function()
			model:Destroy()
		end)
		model:PivotTo(standing)
		model.Parent = Workspace
		const middle = base + Vector3.new(0, BOTTLE_HEIGHT / 2, 0)

		-- 1. wait to be looked at
		const started = os.clock()
		local seenFor = 0
		local last = os.clock()
		while seenFor < SEEN_TIME do
			if os.clock() - started > LIFETIME or not run:Wait(STEP) then
				return
			end
			const now = os.clock()
			seenFor = if Context.Sees(middle, SEEN_CONE, NEAR + 10, { model }) then seenFor + now - last else 0
			last = now
		end

		-- 2. tip over the base edge on the bottle's local +X side, then roll a little
		const radius = 0.21
		const hinge = standing * CFrame.new(radius, 0, 0)
		const fromHinge = hinge:Inverse() * standing
		const tipStart = os.clock()
		while true do
			const t = math.clamp((os.clock() - tipStart) / TIP_TIME, 0, 1)
			model:PivotTo(hinge * CFrame.Angles(0, 0, -math.rad(90) * eased(t)) * fromHinge)
			if t >= 1 then
				break
			end
			if not run:Wait(STEP) then
				return
			end
		end
		env.Sound(KEY, base, { Volume = 0.5, Speed = 1.2 })
		const lying = model:GetPivot()
		const rollStart = os.clock()
		while true do
			const t = math.clamp((os.clock() - rollStart) / 0.4, 0, 1)
			const along = standing.LookVector * ROLL * (1 - (1 - t) * (1 - t))
			model:PivotTo(lying + along)
			if t >= 1 or not run:Wait(STEP) then
				break
			end
		end

		-- 3. stays until the player looks away
		const fallen = os.clock()
		local awayFor = 0
		last = os.clock()
		while os.clock() - fallen < STAY do
			if not run:Wait(0.1) then
				return
			end
			const now = os.clock()
			awayFor = if Context.Sees(model:GetPivot().Position, SEEN_CONE + 15, NEAR + 10, { model })
				then 0
				else awayFor + now - last
			last = now
			if awayFor >= AWAY_TIME then
				return
			end
		end
	end,
}

return BottleFall
