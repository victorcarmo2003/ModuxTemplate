--!strict
--[[
	Shared helpers of the customer-anomaly effects ANM-001 (blank), ANM-004 (mirror) and ANM-005 (raincoat)
	(TASK-112; anomalies.md N1/N4/N5; style guide §4.4, §10; asset-list AST-059/060/062/082). Lives in a Folder
	(Effects/Kit/), so AnomalyController:LoadEffects never takes it for an effect module.

	The actor is a server rig (CustomerService:SpawnActor, TASK-108) with the attribute `Variant`; the record of the
	occurrence carries its NpcId in `Anchor` (TASK-111). What an effect puts on that rig must outlive the record: the
	server removes the record ~1 s after the verb, while the actor still walks away. So a look is bound to the rig's
	`Variant` (WhileVariant), not to the occurrence: it is undone when the attribute leaves (the pool clears it on
	release, TASK-108), when the rig leaves the Workspace (streaming out) or when it is destroyed.

	Presentation only (T10): nothing here decides, sends or reads a verb. Nothing points at the target (§4.4).
]]
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Effect = require(script.Parent.Parent.Parent.Effect)

const VARIANT_ATTRIBUTE = "Variant"
const POLL = 0.25 -- s between looks for the actor rig (it may stream in after the record)

export type Undo = () -> ()
export type Apply = (model: Model) -> Undo

const Kit = {}

-- model -> tag -> finish; weak keys: a forgotten rig never stays alive here
const active: { [Model]: { [string]: () -> () } } = setmetatable({}, { __mode = "k" }) :: any

function Kit.VariantOf(model: Model): string?
	const value = model:GetAttribute(VARIANT_ATTRIBUTE)
	return if typeof(value) == "string" and value ~= "" then value else nil
end

function Kit.Part(name: string, size: Vector3, color: Color3): Part
	const part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Anchored = true
	part.CastShadow = false
	return part
end

-- Welds a local part to a limb of the rig where `offset` puts it now (pose-independent: offset is limb space).
function Kit.Attach(part: BasePart, host: BasePart, offset: CFrame)
	part.Anchored = false
	part.Massless = true
	part.CFrame = host.CFrame * offset
	const weld = Instance.new("WeldConstraint")
	weld.Part0 = host
	weld.Part1 = part
	weld.Parent = part
	part.Parent = host.Parent
end

function Kit.Limb(model: Model, name: string): BasePart?
	const found = model:FindFirstChild(name)
	return if found ~= nil and found:IsA("BasePart") then found else nil
end

function Kit.Root(model: Model): BasePart?
	return Kit.Limb(model, "HumanoidRootPart") or model.PrimaryPart
end

-- Ground under a rig (excludes the rig and the local effects folder). nil = nothing within reach.
function Kit.Ground(ctx: Effect.Context, model: Model): Vector3?
	const root = Kit.Root(model)
	if root == nil then
		return nil
	end
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model, ctx.Folder() }
	const hit = Workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params)
	return if hit then hit.Position else nil
end

-- Runs `apply(model)` once per (rig, tag) while the rig keeps `variant`; its undo runs when the variant leaves, the
-- rig leaves the Workspace or is destroyed. false = not applied (other variant, already applied, apply errored).
function Kit.WhileVariant(model: Model, variant: string, tag: string, apply: Apply): boolean
	const tags = active[model]
	if tags ~= nil and tags[tag] ~= nil then
		return false
	end
	if Kit.VariantOf(model) ~= variant or not model:IsDescendantOf(Workspace) then
		return false
	end
	const ok, result = pcall(apply, model)
	if not ok then
		warn(`[AnomalyEffects] {tag} on {model:GetFullName()}: {result}`)
		return false
	end
	const undo: Undo = result
	const list = tags or {}
	active[model] = list

	const connections: { RBXScriptConnection } = {}
	local finished = false
	local function finish()
		if finished then
			return
		end
		finished = true
		for _, connection in connections do
			connection:Disconnect()
		end
		const current = active[model]
		if current ~= nil then
			current[tag] = nil
		end
		const fine, problem = pcall(undo)
		if not fine then
			warn(`[AnomalyEffects] {tag} undo: {problem}`)
		end
	end
	list[tag] = finish

	table.insert(
		connections,
		model:GetAttributeChangedSignal(VARIANT_ATTRIBUTE):Connect(function()
			if Kit.VariantOf(model) ~= variant then
				finish()
			end
		end)
	)
	table.insert(
		connections,
		model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(Workspace) then
				finish()
			end
		end)
	)
	table.insert(connections, model.Destroying:Connect(finish))
	return true
end

-- Inside Effect.Mount: looks for the actor rig of the occurrence (record Anchor = NpcId, TASK-111) until the root
-- dies, and binds `apply` to it with WhileVariant. A rig that streams out and back in is a new model: bound again.
function Kit.Follow(ctx: Effect.Context, occ: Effect.Occurrence, variant: string, tag: string, apply: Apply)
	local alive = true
	task.spawn(function()
		while alive do
			const id = occ.Record().Anchor
			const model = if id > 0 then ctx.Npc(id) else nil
			if model ~= nil then
				Kit.WhileVariant(model, variant, tag, apply)
			end
			task.wait(POLL)
		end
	end)
	-- Vide.cleanup of the occurrence root (required by the caller, see Effect.luau)
	return function()
		alive = false
	end
end

-- ANM-001 "no breathing" (style guide §4.4): while the rig stands (locomotion role idle), its idle track is held on
-- the first frame. Walking is untouched (the actor walks off slowly like anyone). Provisional (frontend-coder): reads
-- AnimController.Bindings; a public AnimController:Hold(model) would be cleaner (TASK-075 owner).
function Kit.HoldStill(ctx: Effect.Context, model: Model): Undo
	local frozen: AnimationTrack? = nil
	local speed = 1
	const connection = RunService.Heartbeat:Connect(function()
		const binding = ctx.Anim.Bindings[model]
		if binding == nil then
			return
		end
		const track = binding.Track
		if binding.Role == "idle" and track ~= nil and track.IsPlaying and track.Speed ~= 0 then
			track.TimePosition = 0
			track:AdjustSpeed(0)
			frozen = track
			speed = binding.ClipSpeed
		end
	end)
	return function()
		connection:Disconnect()
		const track = frozen
		if track ~= nil and track.Speed == 0 then
			pcall(function()
				track:AdjustSpeed(speed)
			end)
		end
	end
end

return table.freeze(Kit)
