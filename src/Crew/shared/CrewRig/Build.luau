--!strict
-- CrewRig.Build: assembles an R6 animal rig from the kit (architecture.md §18.9.2, network.md §5.1 T40). TASK-016.
-- Production port of Crew.build (tools/assetplace/build_crew.luau). Runs on the server for crew and NPCs
-- (CharacterService, NpcService); may also run on a client for local-only rigs (Opal, "Crew" screen preview).
--
-- Geometry only, plus the data attributes (§5.2) and the AnimalRig tag. The assembled pieces carry the Day pack:
-- the outfit sheet is set to the outfit's Day sheet here, during assembly (the kit ships the crew / civil_a sheets),
-- and the head/atlas pieces keep the kit's Day textures. After Build the server only writes attributes; every pack
-- and face change is CrewRig.Dress on each client (T40). Pelt colour (MeshPart.Color under the texture alpha) comes
-- from CrewLooks and is written here (§18.9.2).
--
-- Rest pose: every kit piece keeps the imported pose (shared origin at the feet, front -Z), so each Motor6D C1 is
-- solved from it and the stock R6 animations work on the custom rig.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Content = require(ReplicatedStorage.shared.Content)
local CrewLooks = require(script.Parent.Parent.CrewLooks)
local Kit = require(script.Parent.Kit)

export type Pack = CrewLooks.Pack

export type Options = {
	-- Content.CustomerTypes key: written as attribute, adds the type's accessories (DEC-188).
	CustomerType: string?,
	-- Extra accessories by kit name (Assets.Crew.Accessories). Missing meshes are skipped with one warning.
	Accessories: { string }?,
	-- Crew cap. Default: on for the crew uniform (Outfits.Use = "Crew"), off for civil outfits. Ears-up species
	-- wear the cap with ear holes (Assets.Crew.CapEarsUp).
	Cap: boolean?,
	-- Hat that replaces the cap, by name in Assets.Crew.Hats ("ThiefHat" for Quick Quentin, DEC-159). Not raised.
	Hat: string?,
	-- Initial LookPack attribute (default "Day").
	LookPack: Pack?,
	-- Model name (default "Rig_<species>_<outfit>").
	Name: string?,
	-- Final CFrame of the HumanoidRootPart (ground point + 3 studs, architecture.md §18.5).
	CFrame: CFrame?,
	-- Anchor the HumanoidRootPart (static rigs: Opal, previews). Default false.
	Anchored: boolean?,
	-- Add the AnimalRig tag (default true). Local rigs dressed by their own owner pass false.
	Tag: boolean?,
}

const TAG = "AnimalRig"
const DEFAULT_PACK: Pack = "Day"

-- Standard R6 joint frames on the Part0 side; C1 is solved from the rest pose (as Crew.build).
type Joint = { Name: string, Part0: string, Part1: string, C0: CFrame }
const JOINTS: { Joint } = {
	{
		Name = "RootJoint",
		Part0 = "HumanoidRootPart",
		Part1 = "Torso",
		C0 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
	},
	{ Name = "Neck", Part0 = "Torso", Part1 = "Head", C0 = CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0) },
	{
		Name = "Right Shoulder",
		Part0 = "Torso",
		Part1 = "Right Arm",
		C0 = CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	},
	{
		Name = "Left Shoulder",
		Part0 = "Torso",
		Part1 = "Left Arm",
		C0 = CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	},
	{
		Name = "Right Hip",
		Part0 = "Torso",
		Part1 = "Right Leg",
		C0 = CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	},
	{
		Name = "Left Hip",
		Part0 = "Torso",
		Part1 = "Left Leg",
		C0 = CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	},
}

-- R6 core parts: jointed, collide like the stock R6 (Torso and Head), queryable/touchable.
const CORE: { [string]: boolean } = {
	HumanoidRootPart = true,
	Torso = true,
	Head = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
}
const COLLIDES: { [string]: boolean } = { Torso = true, Head = true }
const LIMBS = { "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "Head" }

local function setPart(parts: { [string]: BasePart }, key: string, part: BasePart?)
	const old = parts[key]
	if old ~= nil and old ~= part then
		old:Destroy()
	end
	parts[key] = part :: any
end

local function takeAll(parts: { [string]: BasePart }, list: { BasePart })
	for _, part in list do
		setPart(parts, part.Name, part)
	end
end

local function drop(parts: { [string]: BasePart }, key: string)
	setPart(parts, key, nil)
end

-- Body piece that rides with the Torso (tail, shell, apron); everything else on the animal rides with the Head.
local function bodyPiece(name: string): boolean
	return name == "Apron" or string.find(name, "Tail", 1, true) ~= nil or string.find(name, "Shell", 1, true) ~= nil
end

-- Accessory anchor: attribute Anchor (R6 part name) on the piece or its kit root; else the R6 part whose rest-pose
-- centre is nearest (pieces are modelled in place, §18.9.2). PROVISIONAL until the AST-054 sheet fixes a rule.
local function accessoryAnchor(piece: BasePart, root: Instance, parts: { [string]: BasePart }): BasePart
	const named = piece:GetAttribute("Anchor") or root:GetAttribute("Anchor")
	if typeof(named) == "string" and CORE[named] and parts[named] then
		return parts[named]
	end
	local best: BasePart = parts.Head
	local bestDistance = math.huge
	for _, name in LIMBS do
		const limb = parts[name]
		if limb ~= nil then
			const distance = (limb.Position - piece.Position).Magnitude
			if distance < bestDistance then
				best = limb
				bestDistance = distance
			end
		end
	end
	return best
end

local function accessoryList(customerType: string?, extra: { string }?): { string }
	const out: { string } = {}
	if customerType ~= nil then
		const row = Content.CustomerTypes.ByKey[customerType]
		if row == nil then
			error(`[CrewRig] unknown CustomerType '{customerType}'`, 3)
		end
		for _, name in row.Accessories do
			table.insert(out, name)
		end
	end
	if extra ~= nil then
		for _, name in extra do
			if not table.find(out, name) then
				table.insert(out, name)
			end
		end
	end
	return out
end

local function build(species: string, outfit: string, opts: Options?): Model
	const o: Options = opts or {}
	const speciesRow = Content.Species.ByKey[species]
	const look = CrewLooks.Species[species]
	if speciesRow == nil or look == nil then
		error(`[CrewRig] unknown species '{species}' (Content.Species / CrewLooks.Species)`, 2)
	end
	const outfitRow = Content.Outfits.ByKey[outfit]
	const sheets = CrewLooks.Outfits[outfit]
	if outfitRow == nil or sheets == nil then
		error(`[CrewRig] unknown outfit '{outfit}' (Content.Outfits / CrewLooks.Outfits)`, 2)
	end
	const pack = o.LookPack or DEFAULT_PACK
	if not table.find(Content.Looks.Packs, pack) then
		error(`[CrewRig] unknown LookPack '{tostring(pack)}'`, 2)
	end
	const accessories = accessoryList(o.CustomerType, o.Accessories)
	const asset = speciesRow.Asset

	const parts: { [string]: BasePart } = {}
	-- Accessory pieces: kept apart so their names never collide with body pieces.
	const extras: { { Part: BasePart, Root: Instance } } = {}

	takeAll(parts, Kit.CloneParts(Kit.Body())) -- Torso, arms, legs, Apron, Cap
	takeAll(parts, Kit.CloneParts(Kit.Animal(asset))) -- Head_<A>, Face_<A>, Ears/Tail/extras

	-- Civil outfits: straight arms (DEC-161), no apron (§18.9.2).
	if outfitRow.Arms == "Civil" then
		takeAll(parts, Kit.CloneParts(Kit.CivilArms()))
		drop(parts, "Apron")
	end

	-- Headwear: a hat replaces the cap; ears-up species wear the cap with ear holes.
	const wantCap = if o.Cap ~= nil then o.Cap else outfitRow.Use == "Crew"
	if o.Hat ~= nil or not wantCap or look.EarsUp then
		drop(parts, "Cap")
	end
	if o.Hat ~= nil then
		takeAll(parts, Kit.CloneParts(Kit.Hat(o.Hat))) -- one MeshPart named "Hat"
	elseif wantCap and look.EarsUp then
		takeAll(parts, Kit.CloneParts(Kit.CapEarsUp())) -- one MeshPart named "Cap"
	end
	-- Round heads (DEC-152) are taller than the base head: the cap rides up (hats are modelled in place).
	if parts.Cap ~= nil then
		parts.Cap.CFrame += Vector3.new(0, look.CapRaise, 0)
	end

	-- Head and face shell of the species.
	const head = parts["Head_" .. asset]
	if head == nil then
		error(`[CrewRig] kit animal '{asset}' has no Head_{asset}`, 2)
	end
	parts["Head_" .. asset] = nil
	head.Name = "Head"
	setPart(parts, "Head", head)
	const face = parts["Face_" .. asset]
	if face ~= nil then
		parts["Face_" .. asset] = nil
		face.Name = "Face"
		setPart(parts, "Face", face)
	else
		Kit.WarnOnce("Face_" .. asset, `kit animal '{asset}' has no Face_{asset}: rig without expressions`)
	end
	for _, name in LIMBS do
		if parts[name] == nil then
			error(`[CrewRig] kit piece '{name}' missing for {species}/{outfit}`, 2)
		end
	end

	for _, name in accessories do
		const root = Kit.Accessory(name)
		if root == nil then
			Kit.WarnOnce("Accessory:" .. name, `Assets.Crew.Accessories.{name} missing: built without it`)
			continue
		end
		for _, piece in Kit.CloneParts(root, true) do
			piece:SetAttribute("Accessory", name)
			table.insert(extras, { Part = piece, Root = root })
		end
	end

	-- Textures and pelt: outfit parts get the outfit's Day sheet and the fur colour; atlas pieces remember their Day
	-- texture so Dress can swap to the Mid/Night atlas and back.
	const daySheet = sheets.Day
	head.Color = look.Fur
	for _, part in parts do
		if not part:IsA("MeshPart") then
			continue
		end
		if part:GetAttribute("OutfitPart") then
			part.TextureID = daySheet
			part.Color = look.Fur
		elseif part ~= head and part ~= face and part.TextureID ~= "" and part:GetAttribute("DayTextureID") == nil then
			part:SetAttribute("DayTextureID", part.TextureID)
		end
	end
	for _, extra in extras do
		const part = extra.Part
		if part:IsA("MeshPart") and part.TextureID ~= "" and part:GetAttribute("DayTextureID") == nil then
			part:SetAttribute("DayTextureID", part.TextureID)
		end
	end

	-- HumanoidRootPart at the Torso rest frame (as the stock R6).
	const root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CFrame = parts.Torso.CFrame
	setPart(parts, "HumanoidRootPart", root)

	const model = Instance.new("Model")
	model.Name = o.Name or `Rig_{species}_{outfit}`

	local function place(part: BasePart, core: boolean)
		part.Anchored = false
		part.CanCollide = core and COLLIDES[part.Name] == true
		part.CanQuery = core
		part.CanTouch = core
		part.Massless = not core
		part.Parent = model
	end
	for name, part in parts do
		place(part, CORE[name] == true)
	end
	for _, extra in extras do
		place(extra.Part, false)
	end
	root.Anchored = o.Anchored == true

	for _, joint in JOINTS do
		const part0 = parts[joint.Part0]
		const part1 = parts[joint.Part1]
		const motor = Instance.new("Motor6D")
		motor.Name = joint.Name
		motor.Part0 = part0
		motor.Part1 = part1
		motor.C0 = joint.C0
		motor.C1 = part1.CFrame:ToObjectSpace(part0.CFrame * joint.C0)
		motor.Parent = part0
	end

	-- Cosmetic pieces welded where they were modelled.
	local function weld(anchor: BasePart, part: BasePart)
		const constraint = Instance.new("WeldConstraint")
		constraint.Part0 = anchor
		constraint.Part1 = part
		constraint.Parent = part
	end
	for name, part in parts do
		if not CORE[name] then
			weld(if bodyPiece(name) then parts.Torso else head, part)
		end
	end
	for _, extra in extras do
		weld(accessoryAnchor(extra.Part, extra.Root, parts), extra.Part)
	end

	const humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	model.PrimaryPart = root
	-- the whole rig streams in at once, so the client dresses a complete model (T26, network.md §5.1)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	if o.CFrame ~= nil then
		model:PivotTo(o.CFrame)
	end

	model:SetAttribute("Species", species)
	model:SetAttribute("Outfit", outfit)
	if o.CustomerType ~= nil then
		model:SetAttribute("CustomerType", o.CustomerType)
	end
	model:SetAttribute("LookPack", pack)
	if o.Tag ~= false then
		CollectionService:AddTag(model, TAG)
	end
	return model
end

return {
	Build = build,
	Tag = TAG,
}
