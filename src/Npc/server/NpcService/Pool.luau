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
	Customer: Attachment, -- Prompt_Customer: take_order -> serve (CustomerService). No Prompt_Refuse since TASK-354:
	-- refusing is closing the service window
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
	CustomerType: string?, -- nil = no customer accessories (plain passer-by)
	Hat: string?, -- kit hat replacing the cap (Assets.Crew.Hats); none in use
	Group: string, -- collision group of every part (architecture.md §12.3)
	Parking: Instance,
}

const ANCHOR_TAG = "Interactable"
-- Seated pose (SeatingService/Diner.luau, TASK-145): a posed Motor6D keeps its rest C0 in this attribute; release
-- puts it back, so a pooled rig never comes out sitting or anchored.
const REST_ATTRIBUTE = "RestC0"
const SEATED_ATTRIBUTE = "Seated"
const CUSTOMER_ACTION = "take_order"
-- Anchor offset from the HumanoidRootPart (torso centre, -Z = the rig's front). TASK-474 (owner, Play 2026-10-18): the
-- pill sat on the neck and hid the face, and anomalies are told by the face (white eyes, wrong smile). Now on the upper
-- chest, in front of the torso: +0.5 keeps the pill (centred on the anchor, no StudsOffset) under the neck joint (+1.0)
-- on every species (all share the R6 body kit; only the head changes), and 0.6 forward stays short of the restaurant
-- counter (PU-n stands 1.2 from it) and above its top, so the camera sight check still clears it. Same anchor for the
-- server range check (Registry.position), so client and server keep measuring the same point.
const CUSTOMER_OFFSET = Vector3.new(0, 0.5, -0.6)
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
		Hat = spec.Hat,
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
	rig.Root.Anchored = false
	for _, motor in rig.Model:GetDescendants() do
		if motor:IsA("Motor6D") then
			const rest = motor:GetAttribute(REST_ATTRIBUTE)
			if typeof(rest) == "CFrame" then
				motor.C0 = rest
			end
		end
	end
	rig.Model:SetAttribute(SEATED_ATTRIBUTE, nil)
	rig.Model:SetAttribute("Eating", nil) -- SeatingService/Diner.Eat (Q-209)
	rig.Model:SetAttribute("NpcId", nil)
	rig.Model:SetAttribute("Variant", nil) -- actor variant (TASK-108): a reused rig is a plain customer again
	-- anomaly tic of the order talk (TabletService, Content.Tics): a reused rig never carries the last actor's residue
	-- + the delivery queue of a customer anomaly (Anomaly Kit/CustomerActor, owner 2026-10-22): its deformed body and Hurry step,
	-- and the Plain tantrum (his rage and the plate he threw)
	for _, name in {
		"TicAt",
		"TicUser",
		"Tic",
		"TicFollow",
		"TicEnd",
		"TicEcho",
		"AnomalyQueue",
		"AnomalyStep",
		"AnomalyRage",
		"AnomalyThrow",
	} do
		rig.Model:SetAttribute(name, nil)
	end
	rig.Model:SetAttribute("FromWalker", nil) -- adopted passer-by (TASK-163)
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
