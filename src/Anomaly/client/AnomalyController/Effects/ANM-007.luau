--!strict
--[[
	ANM-007 The Walker, client effect (TASK-116; anomalies.md N7, DEC-123; npcs.md NPC-015; asset-list AST-036,
	AST-064; MAP-01 §5.6; server contract: AnomalyService/Anomalies/ANM-007.luau, TASK-115).

	The Walker is a client-only actor in ctx.Folder() (no Humanoid, never replicated). The server keeps `Step` in the
	record and tests the gaze against the same spot; nothing here feeds a rule (X3-15/X3-16: moving or deleting the
	local Walker changes nothing on the server).

	Positions (same as the server):
	  step 0..3  StreetLight post with Group "juniper_posts" and Order = step + 1 (NL-01 = 1 ... NL-04 = 4). The
	             Walker stands on the `Walker_Spot` fitting of the AST-036 when present, else on the ground under the
	             lamp (the server aims its cone at the box centre of the post, < 2 studs away: same view at 130+ studs).
	  step 4     MapPoint WALKER-10 (across the Ninth from the window, outside the trailer light), facing as the point.
	Record:
	  Signal     hidden: only the buzz (cue `post_buzz`, DEC-123) — the figure is there when the buzz stops dry.
	  Active     standing under the post of `Step`, facing down the street (towards the next step); every change of
	             Step is a cut, no walk cycle (AST-064 "aparece no próximo"). A late joiner sees the current step.
	  Failed     stays at the light (critical: the night is being lost).
	  Resolved   backs into the dark (away from the trailer) and fades out; removal destroys it.
	Cues:
	  post_buzz     entity = post Order (1): `post_buzz` from that lamp (exclusive to the real N7, DEC-123).
	  post_flicker  entity = post Order of the new step (0 = WALKER-10: the last post he left flickers). Local dim of
	                the lamp (LocalTransparencyModifier + Light.Brightness): LightController keeps Material/Enabled.
	  walker_step   entity = step: one muffled heavy step from his spot (the last step, WALKER-10, marked opts.Scare, DEC-173 cap).
	                The last step also plays `jumpscare` on screen (Scare cap).

	PROVISIONAL (frontend-coder, TASK-116): Part placeholder until AST-064 ships (TASK-124): tall dark "high
	trapezoid" (#14162A, ~7 studs, wide-brim hat, coat opening like a skirt, no arms, no ears, no face, resembles no
	species: T116-04). A Model named `AST-064_Walker` under ReplicatedStorage.Assets replaces it automatically (feet on
	the spot). Visible only from Active; retreat 1 s / 6 studs; flicker pattern ~0.45 s.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Effect = require(script.Parent.Parent.Effect)

const REF = "ANM-007"
const POST_TAG = "StreetLight"
const POST_GROUP = "juniper_posts"
const LAST_POINT = "WALKER-10"
const STEPS = 4 -- Rules/ANM-007 Steps (server); step STEPS = WALKER-10 (4 posts NL-01..04, MAP-01 §5.6)
const ASSET_NAME = "AST-064_Walker"
const SPOT_NAME = "Walker_Spot" -- AST-036 fitting
const RETRY = 1 -- s between two lookups of a position not streamed in yet

const INK = Color3.fromHex("#14162A") -- AST-064 (matte, no reflection)
const GROUND_PROBE = 4 -- studs above the post base where the ground raycast starts
const GROUND_DEPTH = 12

const RETREAT_TIME = 1 -- s (the server keeps a Resolved record ~1 s, LINGER)
const RETREAT_DISTANCE = 6 -- studs into the dark
const FADE_OUT = 0.5 -- s on removal while still visible
const FRAME = 1 / 30

-- off / on seconds of the post flicker (cue Duration 0.5; style guide AST-036 `Flicker`)
const FLICKER = { 0.07, 0.06, 0.1, 0.08, 0.12 }
const DIM = 0.92

type Body = { Model: Model, Foot: number } -- Foot = pivot height above the soles

type State = {
	Occurrence: Effect.Occurrence,
	Body: Body?,
	Shown: boolean,
	Step: number?, -- step currently drawn
	Retreating: boolean,
	Alive: boolean,
	Retrying: boolean,
}

const states: { [number]: State } = {}
-- Flicker: lamps already dimmed (no stacking) and their real brightness
const flickering: { [Instance]: boolean } = {}
const baseBrightness: { [Light]: number } = {}

-- Posts and spots -------------------------------------------------------------------------------------------------

local function postByOrder(order: number): Instance?
	for _, post in CollectionService:GetTagged(POST_TAG) do
		if post:GetAttribute("Group") == POST_GROUP and post:GetAttribute("Order") == order and post:IsDescendantOf(Workspace) then
			return post
		end
	end
	return nil
end

local function boxOf(instance: Instance): (CFrame?, Vector3?)
	if instance:IsA("Model") then
		const cf, size = instance:GetBoundingBox()
		return cf, size
	elseif instance:IsA("BasePart") then
		return instance.CFrame, instance.Size
	end
	return nil, nil
end

local function worldOf(instance: Instance): Vector3?
	if instance:IsA("Attachment") then
		return instance.WorldPosition
	elseif instance:IsA("BasePart") then
		return instance.Position
	end
	return nil
end

-- Lamp of a post: the parent of its first Light, else its first Neon part.
local function lampOf(post: Instance): Vector3?
	for _, descendant in post:GetDescendants() do
		if descendant:IsA("Light") and descendant.Parent then
			const at = worldOf(descendant.Parent)
			if at then
				return at
			end
		end
	end
	for _, descendant in post:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Material == Enum.Material.Neon then
			return descendant.Position
		end
	end
	return nil
end

local function groundUnder(x: number, base: number, z: number, ignore: { Instance }): number
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	const hit = Workspace:Raycast(Vector3.new(x, base + GROUND_PROBE, z), Vector3.new(0, -GROUND_DEPTH, 0), params)
	return if hit then hit.Position.Y else base
end

-- Feet position of a step (nil = not bound / not streamed in).
local function spotOf(ctx: Effect.Context, step: number): Vector3?
	if step >= STEPS then
		const point = ctx.Point(LAST_POINT)
		return if point then point.Position else nil
	end
	const post = postByOrder(step + 1)
	if post == nil then
		return nil
	end
	const fitting = post:FindFirstChild(SPOT_NAME, true)
	if fitting then
		if fitting:IsA("Attachment") then
			return fitting.WorldPosition
		elseif fitting:IsA("BasePart") then
			return fitting.Position - Vector3.new(0, fitting.Size.Y / 2, 0)
		end
	end
	const cf, size = boxOf(post)
	if cf == nil or size == nil then
		return nil
	end
	const base = cf.Position.Y - size.Y / 2
	const lamp = lampOf(post) or cf.Position
	const ignore: { Instance } = { post, ctx.Folder() }
	for _, player in Players:GetPlayers() do
		const character = player.Character
		if character then
			table.insert(ignore, character)
		end
	end
	return Vector3.new(lamp.X, groundUnder(lamp.X, base, lamp.Z, ignore), lamp.Z)
end

-- Facing at a step: down the street towards the next step; at WALKER-10 the point's own facing.
local function poseOf(ctx: Effect.Context, step: number): CFrame?
	const at = spotOf(ctx, step)
	if at == nil then
		return nil
	end
	local look: Vector3? = nil
	if step >= STEPS then
		const point = ctx.Point(LAST_POINT)
		look = if point then point.LookVector else nil
	else
		const nextAt = spotOf(ctx, step + 1)
		if nextAt then
			look = nextAt - at
		end
	end
	const flat = if look then Vector3.new(look.X, 0, look.Z) else Vector3.zero
	if flat.Magnitude < 1e-3 then
		return CFrame.new(at)
	end
	return CFrame.lookAt(at, at + flat.Unit)
end

-- Body ------------------------------------------------------------------------------------------------------------

local function localPart(name: string, size: Vector3, offset: CFrame, parent: Instance, shape: Enum.PartType?): Part
	const part = Instance.new("Part")
	part.Name = name
	if shape then
		part.Shape = shape
	end
	part.Size = size
	part.CFrame = offset
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Reflectance = 0
	part.Color = INK
	part.Parent = parent
	return part
end

-- Placeholder AST-064, pivot at the soles, facing -Z: ~7 tall, base 2.6 wide, hat brim 2.2.
local function placeholder(): Body
	const model = Instance.new("Model")
	model.Name = "AST-064_Walker_Placeholder"
	localPart("Coat_Hem", Vector3.new(2.6, 1.5, 1.5), CFrame.new(0, 0.75, 0), model)
	localPart("Coat_Mid", Vector3.new(2.2, 1.7, 1.3), CFrame.new(0, 2.35, 0), model)
	const chest = localPart("Coat_Chest", Vector3.new(1.9, 1.5, 1.15), CFrame.new(0, 3.95, 0), model)
	const head = localPart("Head", Vector3.new(1.2, 1.5, 1.2), CFrame.new(0, 5.4, 0), model)
	const oval = Instance.new("SpecialMesh")
	oval.MeshType = Enum.MeshType.Sphere
	oval.Parent = head
	localPart("Hat_Brim", Vector3.new(0.15, 2.2, 2.2), CFrame.new(0, 6.0, 0) * CFrame.Angles(0, 0, math.rad(90)), model, Enum.PartType.Cylinder)
	localPart("Hat_Crown", Vector3.new(0.9, 1.35, 1.35), CFrame.new(0, 6.5, 0) * CFrame.Angles(0, 0, math.rad(90)), model, Enum.PartType.Cylinder)
	model.PrimaryPart = chest
	model.WorldPivot = CFrame.new()
	return { Model = model, Foot = 0 }
end

local function fromAsset(): Body?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const found = if assets then assets:FindFirstChild(ASSET_NAME, true) else nil
	if found == nil or not found:IsA("Model") then
		return nil
	end
	const model = found:Clone()
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end
	const pivot = model:GetPivot()
	const box, size = model:GetBoundingBox()
	return { Model = model, Foot = pivot.Position.Y - (box.Position.Y - size.Y / 2) }
end

local function setFade(body: Body, amount: number)
	for _, descendant in body.Model:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			descendant.LocalTransparencyModifier = amount
		end
	end
end

local function place(body: Body, pose: CFrame)
	body.Model:PivotTo(pose + Vector3.new(0, body.Foot, 0))
end

-- State -----------------------------------------------------------------------------------------------------------

local function hide(state: State)
	const body = state.Body
	if body then
		body.Model.Parent = nil
	end
	state.Shown = false
	state.Step = nil
end

local function retreat(ctx: Effect.Context, state: State)
	const body = state.Body
	if body == nil or not state.Shown or state.Retreating then
		return
	end
	state.Retreating = true
	const step = state.Step or 0
	const from = body.Model:GetPivot()
	-- away from the trailer: from the next step back to this one (step 0: same line, past the last post)
	const here = spotOf(ctx, step)
	const toward = spotOf(ctx, if step >= STEPS then STEPS - 1 else step + 1)
	local away = if here and toward then here - toward else -from.LookVector
	away = Vector3.new(away.X, 0, away.Z)
	away = if away.Magnitude > 1e-3 then away.Unit else -from.LookVector
	task.spawn(function()
		const started = os.clock()
		while state.Alive and state.Retreating do
			const t = math.clamp((os.clock() - started) / RETREAT_TIME, 0, 1)
			body.Model:PivotTo(from + away * RETREAT_DISTANCE * t)
			setFade(body, t)
			if t >= 1 then
				break
			end
			task.wait(FRAME)
		end
		if state.Alive and state.Retreating then
			hide(state)
		end
	end)
end

local apply: (ctx: Effect.Context, state: State) -> ()

local function retryLater(ctx: Effect.Context, state: State)
	if state.Retrying then
		return
	end
	state.Retrying = true
	task.spawn(function()
		while state.Alive and not state.Shown do
			task.wait(RETRY)
			if not state.Alive then
				break
			end
			const phase = state.Occurrence.Record().Phase
			if phase ~= "Active" and phase ~= "Failed" then
				break
			end
			apply(ctx, state)
		end
		state.Retrying = false
	end)
end

apply = function(ctx: Effect.Context, state: State)
	if not state.Alive then
		return
	end
	const record = state.Occurrence.Record()
	const phase = record.Phase
	if phase == "Resolved" then
		retreat(ctx, state)
		return
	end
	if phase ~= "Active" and phase ~= "Failed" then
		hide(state)
		return
	end
	const step = math.clamp(math.floor(record.Step), 0, STEPS)
	if state.Shown and state.Step == step then
		return
	end
	const pose = poseOf(ctx, step)
	if pose == nil then
		retryLater(ctx, state)
		return
	end
	local body = state.Body
	if body == nil then
		body = fromAsset() or placeholder()
		state.Body = body
	end
	const current = body :: Body
	state.Retreating = false
	setFade(current, 0)
	place(current, pose) -- a cut: no walk cycle (AST-064)
	current.Model.Parent = ctx.Folder()
	state.Shown = true
	state.Step = step
end

-- Flicker ---------------------------------------------------------------------------------------------------------

local function flicker(post: Instance)
	if flickering[post] then
		return
	end
	flickering[post] = true
	const lights: { Light } = {}
	const lamps: { BasePart } = {}
	for _, descendant in post:GetDescendants() do
		if descendant:IsA("Light") then
			if baseBrightness[descendant] == nil then
				baseBrightness[descendant] = descendant.Brightness
			end
			table.insert(lights, descendant)
		elseif descendant:IsA("BasePart") and descendant.Material == Enum.Material.Neon then
			table.insert(lamps, descendant)
		end
	end
	for index, seconds in FLICKER do
		const off = index % 2 == 1
		for _, light in lights do
			if light.Parent then
				const base = baseBrightness[light] or light.Brightness
				light.Brightness = if off then base * (1 - DIM) else base
			end
		end
		for _, lamp in lamps do
			if lamp.Parent then
				lamp.LocalTransparencyModifier = if off then DIM else 0
			end
		end
		task.wait(seconds)
	end
	for _, light in lights do
		if light.Parent then
			light.Brightness = baseBrightness[light] or light.Brightness
		end
	end
	for _, lamp in lamps do
		if lamp.Parent then
			lamp.LocalTransparencyModifier = 0
		end
	end
	flickering[post] = nil
end

-- Module ----------------------------------------------------------------------------------------------------------

const Walker: Effect.Module = {
	Ref = REF,

	Mount = function(ctx: Effect.Context, occ: Effect.Occurrence)
		const state: State = {
			Occurrence = occ,
			Body = nil,
			Shown = false,
			Step = nil,
			Retreating = false,
			Alive = true,
			Retrying = false,
		}
		states[occ.Id] = state

		Vide.effect(function()
			occ.Record() -- track: Phase and Step
			Vide.untrack(function()
				apply(ctx, state)
			end)
		end)

		Vide.cleanup(function()
			state.Alive = false
			if states[occ.Id] == state then
				states[occ.Id] = nil
			end
			const body = state.Body
			state.Body = nil
			if body == nil then
				return
			end
			if not state.Shown or body.Model.Parent == nil then
				body.Model:Destroy()
				return
			end
			-- removed while visible (night over, restore): fade out where he stands, then gone
			task.spawn(function()
				const started = os.clock()
				const from = math.clamp(
					if body.Model.PrimaryPart then body.Model.PrimaryPart.LocalTransparencyModifier else 0,
					0,
					1
				)
				while body.Model.Parent ~= nil do
					const t = math.clamp((os.clock() - started) / FADE_OUT, 0, 1)
					setFade(body, from + (1 - from) * t)
					if t >= 1 then
						break
					end
					task.wait(FRAME)
				end
				body.Model:Destroy()
			end)
		end)
	end,

	Cue = function(ctx: Effect.Context, cue: Effect.Cue)
		if cue.Cue == "post_buzz" then
			-- DEC-123: rises ~2 s and stops dry; heard by the whole party (the sound row carries the shape)
			const post = postByOrder(if cue.Entity > 0 then cue.Entity else 1)
			ctx.Play("post_buzz", if post then lampOf(post) else nil)
		elseif cue.Cue == "post_flicker" then
			const post = postByOrder(if cue.Entity > 0 then cue.Entity else STEPS)
			if post then
				flicker(post)
			end
		elseif cue.Cue == "walker_step" then
			const step = math.clamp(math.floor(cue.Entity), 0, STEPS)
			ctx.Play("walker_step", spotOf(ctx, step), step >= STEPS)
			if step >= STEPS then
				-- last step (WALKER-10, N7 failing): jumpscare on screen, DEC-173 cap (user request 2026-10-10)
				ctx.Play("jumpscare", nil, true)
			end
		end
	end,
}

return Walker
