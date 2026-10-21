--!strict
-- CrewRig.Dress: textures and face of a rig built by CrewRig.Build (architecture.md §18.9.2, network.md §5.1 T40).
-- TASK-016. Production port of Crew.applyTime + Crew.setExpression (tools/assetplace/build_crew.luau).
-- CLIENT ONLY in a running game: the server never writes TextureID nor SurfaceAppearance after assembly, so a local
-- swap (DEC-168 Night for the observer in the low band) is never undone by replication.
--
-- Pack: outfit sheet (CrewLooks.Outfits[outfit][pack]), head (CrewLooks.Species[species].Head[pack]) and the atlas
-- pieces (CrewLooks.Atlas[pack]; Day = the piece's own DayTextureID). An outfit without that pack (Day only)
-- dresses the whole rig in Day, so head and coat never disagree.
-- Blank (ANM-001 / ANM-004, AST-060): `blank = true` swaps the head and the atlas pieces for the species' Blank
-- textures (CrewLooks.Species[k].Blank: smooth skin-colour head, ears / tail / nose repainted in that colour) of the
-- worn pack. Silent fallback to the ordinary textures when the species has no Blank row. The face is the caller's
-- (CrewExpressions.Blank): Dress does not pick it.
-- Face: clone of ReplicatedStorage.CrewExpressions.<expression> on the face shell, shell TextureID = "" (the shell needs
-- real transparency, SurfaceAppearance AlphaMode Transparency). Only Normal_Night has a night version (DEC-207): the
-- caller passes the final name (Content.Looks.PackFace gives Normal_Night for the crew in Night).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Content = require(ReplicatedStorage.shared.Content)
local CrewLooks = require(script.Parent.Parent.CrewLooks)
local SkinLooks = require(script.Parent.Parent.SkinLooks)
local Kit = require(script.Parent.Kit)

export type Pack = CrewLooks.Pack

const FALLBACK_FACE = "Normal"
-- Local debug attribute (network.md §5.2: the face is never a server attribute).
const EXPRESSION_ATTRIBUTE = "Expression"

local function asPack(value: unknown): Pack?
	if value == "Day" or value == "Mid" or value == "Night" then
		return value
	end
	return nil
end

-- Pack actually worn: the requested one if the outfit has it, else Day.
local function effectivePack(outfit: string, pack: Pack): Pack
	const row = Content.Outfits.ByKey[outfit]
	if row ~= nil and table.find(row.Packs, pack) then
		return pack
	end
	return "Day"
end

local function setFace(model: Model, expression: string): boolean
	const face = model:FindFirstChild("Face")
	if face == nil or not face:IsA("MeshPart") then
		return false
	end
	local name = expression
	local template = Kit.Expression(name)
	if template == nil then
		Kit.WarnOnce("Expression:" .. name, `CrewExpressions.{name} missing: using {FALLBACK_FACE}`)
		name = FALLBACK_FACE
		template = Kit.Expression(name)
	end
	if template == nil then
		return false
	end
	if face.TextureID ~= "" then
		face.TextureID = ""
	end
	-- Keep the current shell when it already shows this expression (no flicker, no churn).
	local current: SurfaceAppearance? = nil
	for _, child in face:GetChildren() do
		if child:IsA("SurfaceAppearance") then
			if current == nil and child.Name == name then
				current = child
			else
				child:Destroy()
			end
		end
	end
	if current == nil then
		template:Clone().Parent = face
	end
	model:SetAttribute(EXPRESSION_ATTRIBUTE, name)
	return true
end

-- Dress `model` in `pack` (default: its LookPack attribute) with `expression` (default: Content.Looks.PackFace of
-- the worn pack). `blank` dresses the species' Blank head / atlas (see top). Returns false when the model is not a
-- dressable rig (missing attributes or unknown keys).
local function dress(model: Model, pack: Pack?, expression: string?, blank: boolean?): boolean
	if RunService:IsRunning() and RunService:IsServer() and not RunService:IsClient() then
		error("[CrewRig] Dress is client-only (T40, network.md §5.1): the server only writes attributes", 2)
	end
	const species = model:GetAttribute("Species")
	const outfit = model:GetAttribute("Outfit")
	if typeof(species) ~= "string" or typeof(outfit) ~= "string" then
		return false
	end
	const look = CrewLooks.Species[species]
	const sheets = CrewLooks.Outfits[outfit]
	if look == nil or sheets == nil then
		Kit.WarnOnce(`Dress:{species}/{outfit}`, `cannot dress {model:GetFullName()}: unknown {species}/{outfit}`)
		return false
	end
	const wanted = pack or asPack(model:GetAttribute("LookPack")) or "Day"
	const worn = effectivePack(outfit, wanted)

	-- class skin (attribute Skin, CrewRig.Build): its own sheet per pack; no row = the outfit's sheet
	const skin = model:GetAttribute("Skin")
	local skinSheets: SkinLooks.SkinLook? = nil
	if typeof(skin) == "string" and skin ~= "" then
		skinSheets = SkinLooks.BySkin[skin]
		if skinSheets == nil then
			Kit.WarnOnce(`DressSkin:{skin}`, `skin '{skin}' has no SkinLooks row: dressed in the outfit sheet`)
		end
	end
	const sheet = if skinSheets ~= nil then SkinLooks.Sheet(skinSheets, worn) else sheets[worn] or sheets.Day
	const blankLook = if blank == true then look.Blank else nil
	const skinHead = if skinSheets ~= nil then skinSheets.Head else nil
	const headTexture = if blankLook
		then blankLook.Head
		elseif skinHead ~= nil then SkinLooks.Sheet(skinHead, worn)
		else look.Head[worn] or look.Head.Day
	const atlas = if blankLook
		then blankLook.Atlas[worn] or blankLook.Atlas.Day
		elseif worn == "Day" then nil
		else CrewLooks.Atlas[worn]

	for _, child in model:GetChildren() do
		if not child:IsA("MeshPart") then
			continue
		end
		local texture: string? = nil
		if child:GetAttribute("OutfitPart") then
			texture = sheet
		elseif skinSheets ~= nil and child:GetAttribute("DayTextureID") == SkinLooks.BaseAtlas then
			texture = SkinLooks.Sheet(skinSheets.Atlas, worn) -- atlas piece (cap, ears, tail): the skin's atlas copy
		elseif child.Name == "Head" then
			texture = headTexture
		else
			const day = child:GetAttribute("DayTextureID")
			if typeof(day) == "string" then
				texture = atlas or day
			end
		end
		if texture ~= nil and child.TextureID ~= texture then
			child.TextureID = texture
		end
	end

	setFace(model, expression or Content.Looks.PackFace[worn] or FALLBACK_FACE)
	return true
end

return {
	Dress = dress,
	EffectivePack = effectivePack,
	AsPack = asPack,
}
