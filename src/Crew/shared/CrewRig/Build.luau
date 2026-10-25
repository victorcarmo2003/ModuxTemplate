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
local AccessoryFit = require(script.Parent.Parent.AccessoryFit)
local CrewLooks = require(script.Parent.Parent.CrewLooks)
local SkinLooks = require(script.Parent.Parent.SkinLooks)
local Kit = require(script.Parent.Kit)

export type Pack = CrewLooks.Pack

export type Options = {
	-- Content.CustomerTypes key: written as attribute, adds the type's accessories (DEC-188).
	CustomerType: string?,
	-- Extra accessories by kit name (Assets.Crew.Accessories). Missing meshes, and pieces that do not fit the species
	-- (AccessoryFit: lion hard hat, mask of another species...), are skipped with one warning.
	Accessories: { string }?,
	-- Crew cap. Default: on for the crew uniform (Outfits.Use = "Crew"), off for civil outfits. Ears-up species
	-- wear the cap with ear holes (Assets.Crew.CapEarsUp).
	Cap: boolean?,
	-- Hat that replaces the cap, by name in Assets.Crew.Hats (none in use since DEC-313). Not raised.
	Hat: string?,
	-- Class skin (Content.Skins key; owner request 2026-10-17): written as attribute Skin (Dress swaps the outfit sheet),
	-- its Fur replaces the species fur, its Accessories / Hat are added. Only on a crew outfit (Outfits.Use = "Crew");
	-- an unknown key is ignored with one warning.
	Skin: string?,
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

-- Accessory anchor: attribute Anchor (R6 part name) on the piece or its kit root (build_kits writes it), else the
-- AccessoryFit row (an older place without the attribute); else the R6 part whose rest-pose centre is nearest (pieces
-- are modelled in place, §18.9.2). Hand-held pieces need the explicit anchor: their centre is nearer the leg.
local function accessoryAnchor(
	piece: BasePart,
	root: Instance,
	fallback: string?,
	parts: { [string]: BasePart }
): BasePart
	local function named(value: unknown): BasePart?
		return if typeof(value) == "string" and CORE[value] then parts[value] else nil
	end
	const explicit = named(piece:GetAttribute("Anchor")) or named(root:GetAttribute("Anchor")) or named(fallback)
	if explicit ~= nil then
		return explicit
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

-- Kit piece actually worn for a requested accessory on this species, and its fit (AccessoryFit, generated from
-- AST-081_offsets.json). nil when the piece does not fit the species (warned once per species and piece).
local function fitFor(species: string, name: string): (string?, AccessoryFit.Fit?)
	const piece = AccessoryFit.Pieces[name]
	if piece ~= nil and piece.Only ~= nil and piece.Only ~= species then
		Kit.WarnOnce(`Fit:{name}:{species}`, `{name} is shaped for '{piece.Only}', not '{species}': built without it`)
		return nil, nil
	end
	const bySpecies = AccessoryFit.Species[species]
	const fit = if bySpecies ~= nil then bySpecies[name] else nil
	if fit == nil then
		return name, nil
	end
	if fit.Forbidden ~= nil then
		Kit.WarnOnce(`Fit:{name}:{species}`, `{name} does not fit '{species}' ({fit.Forbidden}): built without it`)
		return nil, nil
	end
	return fit.Use or name, fit
end

-- Size scale about a point, factors along the world (rest pose) axes; kit pieces are axis-aligned, so each local axis
-- takes the factor of the world axis it lies along.
local function scaleAbout(part: BasePart, scale: Vector3, pivot: Vector3)
	const frame = part.CFrame
	local function along(axis: Vector3): number
		const x, y, z = math.abs(axis.X), math.abs(axis.Y), math.abs(axis.Z)
		if x >= y and x >= z then
			return scale.X
		elseif y >= z then
			return scale.Y
		end
		return scale.Z
	end
	part.Size *= Vector3.new(along(frame.RightVector), along(frame.UpVector), along(frame.LookVector))
	part.CFrame = frame.Rotation + (pivot + (frame.Position - pivot) * scale)
end

local function applyFit(part: BasePart, fit: AccessoryFit.Fit)
	if fit.Scale ~= nil then
		scaleAbout(part, fit.Scale, AccessoryFit.Pivot)
	end
	if fit.Offset ~= nil then
		part.CFrame += fit.Offset
	end
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
	local skin: Content.Skin? = nil
	if o.Skin ~= nil and outfitRow.Use == "Crew" then
		skin = Content.Skins.ByKey[o.Skin]
		if skin == nil then
			Kit.WarnOnce("Skin:" .. o.Skin, `unknown skin '{o.Skin}' (Content.Skins): built in the crew uniform`)
		end
	end
	local extraAccessories = o.Accessories
	if skin ~= nil and skin.Accessories ~= nil then
		const merged: { string } = table.clone(extraAccessories or {})
		for _, name in skin.Accessories do
			table.insert(merged, name)
		end
		extraAccessories = merged
	end
	const hat: string? = o.Hat or if skin ~= nil then skin.Hat else nil
	const fur = if skin ~= nil and skin.Fur ~= nil then skin.Fur else look.Fur
	const accessories = accessoryList(o.CustomerType, extraAccessories)
	const asset = speciesRow.Asset

	const parts: { [string]: BasePart } = {}
	-- Accessory pieces: kept apart so their names never collide with body pieces.
	const extras: { { Part: BasePart, Root: Instance, Anchor: string? } } = {}

	takeAll(parts, Kit.CloneParts(Kit.Body())) -- Torso, arms, legs, Apron, Cap
	takeAll(parts, Kit.CloneParts(Kit.Animal(asset))) -- Head_<A>, Face_<A>, Ears/Tail/extras

	-- Civil outfits: straight arms (DEC-161), no apron (§18.9.2).
	if outfitRow.Arms == "Civil" then
		takeAll(parts, Kit.CloneParts(Kit.CivilArms()))
		drop(parts, "Apron")
	end

	-- Headwear: a hat replaces the cap; ears-up species wear the cap with ear holes.
	const wantCap = if o.Cap ~= nil then o.Cap else outfitRow.Use == "Crew"
	if hat ~= nil or not wantCap or look.EarsUp then
		drop(parts, "Cap")
	end
	if hat ~= nil then
		takeAll(parts, Kit.CloneParts(Kit.Hat(hat))) -- one MeshPart named "Hat"
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

	for _, requested in accessories do
		-- species fit first (variant, offset/scale, forbidden), then the kit piece
		const name, fit = fitFor(species, requested)
		if name == nil then
			continue
		end
		const root = Kit.Accessory(name)
		if root == nil then
			Kit.WarnOnce("Accessory:" .. name, `Assets.Crew.Accessories.{name} missing: built without it`)
			continue
		end
		const row = AccessoryFit.Pieces[name]
		for _, piece in Kit.CloneParts(root, true) do
			if fit ~= nil then
				applyFit(piece, fit) -- rest pose, before the weld
			end
			piece:SetAttribute("Accessory", requested)
			table.insert(extras, { Part = piece, Root = root, Anchor = if row ~= nil then row.Anchor else nil })
		end
	end

	-- Textures and pelt: outfit parts get the outfit's Day sheet and the fur colour; atlas pieces remember their Day
	-- texture so Dress can swap to the Mid/Night atlas and back.
	const skinSheets = if skin ~= nil then SkinLooks.BySkin[skin.Key] else nil
	const daySheet = if skinSheets ~= nil then SkinLooks.Sheet(skinSheets, "Day") else sheets.Day
	head.Color = fur
	if skinSheets ~= nil and skinSheets.Head ~= nil and head:IsA("MeshPart") then
		head.TextureID = SkinLooks.Sheet(skinSheets.Head, "Day") -- the skin fur is baked in its own head
	end
	for _, part in parts do
		if not part:IsA("MeshPart") then
			continue
		end
		if part:GetAttribute("OutfitPart") then
			Kit.ApplySheet(part, daySheet) -- SurfaceAppearance Overlay: the fur colour shows on hands / forearms
			part.Color = fur
		elseif part ~= head and part ~= face and part.TextureID ~= "" and part:GetAttribute("DayTextureID") == nil then
			part:SetAttribute("DayTextureID", part.TextureID)
			if skinSheets ~= nil and part.TextureID == SkinLooks.BaseAtlas then
				part.TextureID = SkinLooks.Sheet(skinSheets.Atlas, "Day") -- atlas piece: the skin's atlas copy
			end
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
		weld(accessoryAnchor(extra.Part, extra.Root, extra.Anchor, parts), extra.Part)
	end

	const humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	-- first-person eye at the height of the rig's round head (user request 2026-10-12: camera a bit higher)
	humanoid.CameraOffset = Vector3.new(0, 0.6, 0)
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
	if skin ~= nil then
		model:SetAttribute("Skin", skin.Key)
	end
	if o.Tag ~= false then
		CollectionService:AddTag(model, TAG)
	end
	return model
end

return {
	Build = build,
	Tag = TAG,
}
