--!strict
-- ghost_customer (< 40; script.md §8, AST-085): a customer waits in the queue and is gone when the player looks again.
-- Local rig (CrewRig.Build with Tag = false: RigController and the server never see it), Night pack + Normal_Night
-- (kept on purpose, Provisional 2026-10-14: it highlights the hallucination; the low band no longer dresses
-- real NPCs Night), anchored, no collision, no prompt, never in the Customers set. No sound.
--   1. spawns on a free queue slot Q1..Q5 the player is NOT looking at;
--   2. once seen (in the view cone, clear line) and then out of view, it is removed -> "gone on the 2nd look";
--   3. never seen within LIFETIME: removed quietly.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Context = require(script.Parent.Parent.Context)

const QUEUE = { "Q1", "Q2", "Q3", "Q4", "Q5" }
const RIG_TAG = "AnimalRig"
const PACK: CrewRig.Pack = "Night"
const FACE = Content.Looks.PackFace.Night
const FREE_RADIUS = 2.5 -- studs: a real customer (or anyone) closer than this takes the slot
const RANGE = 70 -- studs from the camera
const HIDDEN_CONE = 50 -- degrees: spawn only outside this cone
const SEEN_CONE = 30 -- degrees: "looking at it"
const SEEN_TIME = 0.4 -- s in view to count as seen
const AWAY_TIME = 0.5 -- s out of view after being seen
const LIFETIME = 25 -- s
const STEP = 0.1
const HIP = Vector3.new(0, 3, 0) -- HRP = ground point + 3 studs (architecture.md §18.5)

local function point(id: string): CFrame?
	const ok, result = pcall(MapIndex.FindPoint, id)
	return if ok then result else nil
end

local function occupied(position: Vector3): boolean
	for _, rig in Context.Tagged(RIG_TAG) do
		const at = Context.PositionOf(rig)
		if at and (at - position).Magnitude <= FREE_RADIUS + 3 then
			return true
		end
	end
	return false
end

local function freeSlots(): { CFrame }
	const out: { CFrame } = {}
	for _, id in QUEUE do
		const frame = point(id)
		if frame then
			const position = frame.Position
			const angle, distance = Context.ViewAngle(position)
			if angle ~= nil and angle > HIDDEN_CONE and distance <= RANGE and not occupied(position) then
				table.insert(out, frame)
			end
		end
	end
	return out
end

local function pickLook(random: Random): (string?, string?)
	const species: { string } = {}
	for _, row in Content.Species.List do
		if row.Customer and row.ReservedFor == nil then
			table.insert(species, row.Key)
		end
	end
	const outfits: { string } = {}
	for _, row in Content.Outfits.List do
		if row.Use == "Civil" then
			table.insert(outfits, row.Key)
		end
	end
	if #species == 0 or #outfits == 0 then
		return nil, nil
	end
	return species[random:NextInteger(1, #species)], outfits[random:NextInteger(1, #outfits)]
end

local function facing(env: Context.Env, at: Vector3): CFrame
	-- toward the counter: the current vehicle; flat
	const vehicle = env.Vehicle()
	const target = if vehicle then Context.PositionOf(vehicle) else nil
	if target then
		const flat = Vector3.new(target.X, at.Y, target.Z)
		if (flat - at).Magnitude > 0.5 then
			return CFrame.lookAt(at, flat)
		end
	end
	return CFrame.new(at)
end

local function build(env: Context.Env, frame: CFrame): Model?
	const species, outfit = pickLook(env.Random)
	if species == nil or outfit == nil then
		return nil
	end
	const ok, result = pcall(function(): Model
		const model = CrewRig.Build(species, outfit, {
			Tag = false,
			Anchored = true,
			LookPack = PACK,
			Name = "Hallucination_Customer",
			CFrame = facing(env, frame.Position + HIP),
		})
		CrewRig.Dress(model, PACK, FACE)
		return model
	end)
	if not ok then
		return nil
	end
	const model = result
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
		end
	end
	return model
end

const GhostCustomer: Context.Effect = {
	CanRun = function(_env: Context.Env): boolean
		return #freeSlots() > 0
	end,

	Play = function(env: Context.Env, run: Context.Run)
		const slots = freeSlots()
		if #slots == 0 then
			return
		end
		const model = build(env, slots[env.Random:NextInteger(1, #slots)])
		if model == nil then
			return
		end
		run:Cleanup(function()
			model:Destroy()
		end)
		model.Parent = Workspace

		const started = os.clock()
		local seenFor = 0
		local seen = false
		local awayFor = 0
		local last = os.clock()
		while os.clock() - started < LIFETIME do
			if not run:Wait(STEP) or model.Parent == nil then
				return
			end
			const now = os.clock()
			const dt = now - last
			last = now
			const head = model:FindFirstChild("Head")
			const at = if head and head:IsA("BasePart") then head.Position else model:GetPivot().Position
			const inView = Context.Sees(at, SEEN_CONE, RANGE, { model })
			if not seen then
				seenFor = if inView then seenFor + dt else 0
				seen = seenFor >= SEEN_TIME
			else
				awayFor = if inView then 0 else awayFor + dt
				if awayFor >= AWAY_TIME then
					return -- gone before the second look
				end
			end
		end
	end,
}

return GhostCustomer
