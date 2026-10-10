--!strict
-- NpcService/Pool: fixed pool of server NPC rigs (architecture.md §12.3, T11; DEC-045, DEC-191). TASK-031.
-- At most `Capacity` rigs ever exist (Content.Flow.MaxNpc = 12; Opal is a client rig, outside, DEC-191). A spawn
-- reuses an idle rig with the same geometry key (species + customer type, Look.Key); without one it builds a new
-- rig while there is room, else it rebuilds the idle rig that waited longest. All rigs busy = no spawn.
-- Rigs are built once by CrewRig.Build (server: geometry + attributes only, T40), get the customer prompt anchors
-- (architecture.md §18.4) and wait in a parking folder outside the Workspace (InteractionService frees their
-- EntityIds; the client never sees them). No network, no Modux.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)

export type Rig = {
	Model: Model,
	Root: BasePart,
	Humanoid: Humanoid,
	Key: string,
	Customer: Attachment, -- Prompt_Customer: take_order -> serve (CustomerService)
	Refuse: Attachment, -- Prompt_Refuse: refuse
	Active: boolean,
	ReleasedAt: number,
}

export type Pool = {
	Capacity: number,
	Rigs: { Rig },
	Builds: number, -- rigs built since boot (soak: stops growing once the pool is warm)
}

export type BuildSpec = {
	Species: string,
	Outfit: string,
	CustomerType: string,
	Group: string, -- collision group of every part (architecture.md §12.3)
	Parking: Instance,
}

const ANCHOR_TAG = "Interactable"
const CUSTOMER_ACTION = "take_order"
const REFUSE_ACTION = "refuse"
-- Anchor offsets from the HumanoidRootPart (torso centre). PROVISIONAL: Prompt_Customer at the neck, Prompt_Refuse
-- 1.5 below it (architecture.md §18.4).
const CUSTOMER_OFFSET = Vector3.new(0, 1.5, 0)
const REFUSE_OFFSET = Vector3.new(0, 0, 0)
-- Server rig: only walking. Everything else off (architecture.md §12.3).
const DISABLED_STATES = {
	Enum.HumanoidStateType.Climbing,
	Enum.HumanoidStateType.Swimming,
	Enum.HumanoidStateType.FallingDown,
	Enum.HumanoidStateType.Ragdoll,
	Enum.HumanoidStateType.Seated,
	Enum.HumanoidStateType.Flying,
	Enum.HumanoidStateType.StrafingNoPhysics,
	Enum.HumanoidStateType.PlatformStanding,
	Enum.HumanoidStateType.Physics,
	Enum.HumanoidStateType.Jumping,
	Enum.HumanoidStateType.Dead,
}

const PoolModule = {}

function PoolModule.new(capacity: number): Pool
	return { Capacity = capacity, Rigs = {}, Builds = 0 }
end

-- (active, total)
function PoolModule.counts(pool: Pool): (number, number)
	local active = 0
	for _, rig in pool.Rigs do
		if rig.Active then
			active += 1
		end
	end
	return active, #pool.Rigs
end

local function anchor(root: BasePart, name: string, action: string, offset: Vector3): Attachment
	const attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = offset
	-- Attributes before the tag: InteractionService reads them when the anchor enters the Workspace.
	attachment:SetAttribute("PromptAction", action)
	attachment:SetAttribute("PromptEnabled", false)
	CollectionService:AddTag(attachment, ANCHOR_TAG)
	attachment.Parent = root
	return attachment
end

local function resetAnchor(attachment: Attachment, action: string)
	attachment:SetAttribute("PromptAction", action)
	attachment:SetAttribute("PromptEnabled", false)
	attachment:SetAttribute("PromptText", nil)
	attachment:SetAttribute("PromptHold", nil)
end

-- Builds a parked rig. Errors propagate (kit missing, unknown key): the caller pcalls.
function PoolModule.build(spec: BuildSpec): Rig
	const model = CrewRig.Build(spec.Species, spec.Outfit, {
		CustomerType = spec.CustomerType,
		LookPack = "Day",
		Name = "Npc",
	})
	const root = model.PrimaryPart
	const humanoid = model:FindFirstChildOfClass("Humanoid")
	if root == nil or humanoid == nil then
		model:Destroy()
		error(`[NpcService] CrewRig.Build gave a rig without HumanoidRootPart/Humanoid ({spec.Species})`)
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = spec.Group
		end
	end
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	for _, state in DISABLED_STATES do
		humanoid:SetStateEnabled(state, false)
	end

	const rig: Rig = {
		Model = model,
		Root = root,
		Humanoid = humanoid,
		Key = "",
		Customer = anchor(root, "Prompt_Customer", CUSTOMER_ACTION, CUSTOMER_OFFSET),
		Refuse = anchor(root, "Prompt_Refuse", REFUSE_ACTION, REFUSE_OFFSET),
		Active = false,
		ReleasedAt = 0,
	}
	model.Parent = spec.Parking
	return rig
end

-- Idle rig with `key`, else a new one from `build` (room left, or the longest-idle rig destroyed to make room).
-- nil = every rig is busy, or the build failed.
function PoolModule.acquire(pool: Pool, key: string, build: () -> Rig?): Rig?
	local oldest: Rig? = nil
	for _, rig in pool.Rigs do
		if rig.Active then
			continue
		end
		if rig.Key == key then
			rig.Active = true
			return rig
		end
		if oldest == nil or rig.ReleasedAt < oldest.ReleasedAt then
			oldest = rig
		end
	end

	if #pool.Rigs >= pool.Capacity then
		if oldest == nil then
			return nil
		end
		const index = table.find(pool.Rigs, oldest)
		if index ~= nil then
			table.remove(pool.Rigs, index)
		end
		oldest.Model:Destroy()
	end

	const rig = build()
	if rig == nil then
		return nil
	end
	rig.Key = key
	rig.Active = true
	table.insert(pool.Rigs, rig)
	pool.Builds += 1
	return rig
end

-- Back to the parking folder: stops walking, resets the prompt anchors to their idle state, drops NpcId.
function PoolModule.release(pool: Pool, rig: Rig, now: number, parking: Instance)
	if table.find(pool.Rigs, rig) == nil then
		rig.Model:Destroy()
		return
	end
	rig.Active = false
	rig.ReleasedAt = now
	if rig.Model.Parent ~= nil and rig.Root:IsDescendantOf(workspace) then
		rig.Humanoid:MoveTo(rig.Root.Position)
	end
	resetAnchor(rig.Customer, CUSTOMER_ACTION)
	resetAnchor(rig.Refuse, REFUSE_ACTION)
	rig.Model:SetAttribute("NpcId", nil)
	rig.Model.Name = "Npc"
	rig.Model.Parent = parking
end

-- Destroys every rig (place shutdown or tests).
function PoolModule.clear(pool: Pool)
	for _, rig in pool.Rigs do
		rig.Model:Destroy()
	end
	table.clear(pool.Rigs)
end

return table.freeze(PoolModule)
