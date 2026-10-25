--!strict
--[[
	RigController (TASK-016; architecture.md §18.9.2 / §18.9.4, network.md §5.1-5.3 T40)

	Dresses every `AnimalRig` model in the Workspace with CrewRig.Dress, when it appears (including models that
	stream in) and again whenever a look attribute (Species, Outfit, CustomerType, LookPack) or the local layer
	changes. Never talks to the network: the server writes attributes, this client decides textures and faces.

	Local layer (network.md §5.3):
	  - crew rig (Outfits.Use = "Crew"): its own LookPack, face = Content.Looks.PackFace (everyone sees the same);
	  - NPC: its LookPack, face = local override (SetExpression: mood from CustomerController, TASK-034) or the
	    neutral face (the mood holds in the low band too);
	  - low-sanity hallucination (TASK-644; DEC-168, DEC-169, DEC-373): while THIS player's own sanity is in one of the
	    LOW_TIERS deepest Content.Sanity.Tiers (SanityTier, DEC-352; Provisional: the two lowest, < 40), customers and
	    passers-by with no Variant (and the blank one, HALLUCINATION_VARIANTS: it arrives like any other customer) are
	    dressed Night on this client only; back to the server's pack when the tier rises. Nothing is written: the
	    LookPack attribute stays the server's, so NightWatch (which reads it) never fires on a hallucination. Crew rigs
	    never change with the local sanity (the body follows the night on the server, DEC-370 / DEC-373);
	  - Night on an NPC also comes from an anomaly variant with an animal rig (NIGHT_VARIANTS: raincoat),
	    always Night even with high sanity, except reserved outfits (none in use); mirror never goes Night.
	Local-only rigs (Opal, previews) are built with `Tag = false` and dressed by their owner with CrewRig.Dress.

	Wave 3 (TASK-110; architecture.md §19.3, §19.17; anomalies.md N1/N4/N5):
	  - Customer-anomaly `Variant` (rig attribute written by NpcService, TASK-108: blank / mirror / raincoat; nil =
	    ordinary). Re-dressed when it changes (a pooled rig loses it on release). Applied on this client only:
	      blank     face = CrewExpressions.Blank (AST-060 `T_Expr_Blank`, fully transparent): no eyes, mouth or cheeks
	                on the face shell; the head keeps the species' own skin, markings and nose in the worn pack (owner
	                2026-10-22: "o sem rosto dele tá com a pele branca... ele deveria manter a cor de pele dele"). Until
	                then Dress(..., blank = true) swapped the head for the flat AST-060 head (CrewLooks.Species[k].Blank:
	                one opaque Day-fur colour, no markings) and the atlas for repainted ears / tail / nose, in the Night
	                pack (NIGHT_VARIANTS): against the darkened body that flat head read as a white blob (all white on
	                the pale species: panda, rabbit, sheep). BLANK_HEAD = false keeps it off (rollback = true).
	                With a Content.Tics row of Body "Face" (ANM-001, owner 2026-10-22: it must arrive with a face) the
	                variant keeps the ordinary face until the local TicFace names one (Effects/Kit/Tic fades it in the
	                talk), so it never arrives faceless, not even before its effect mounts.
	      raincoat  face = CrewExpressions.EyesClosed (AST-059); while missing, the mood / neutral face.
	      mirror    pack = the server's (Day/Mid, like the original), never Night; face = CrewExpressions.EyesWhite
	                (all-white eyes; another agent creates it, until then the mood / neutral face); outfit sheet =
	                CrewLooks.Outfits["<outfit>_mirror"] for the worn pack when that row exists (AST-062, only Mid),
	                else the ordinary sheet.
	    raincoat is always Night (NIGHT_VARIANTS), whatever the sanity (Provisional, 2026-10-14; blank left it on
	    2026-10-22: it arrives in the pack of every other customer and keeps it). The
	    variant face beats the mood (the sign must stay readable: Provisional, frontend-coder). Mirrored accessories
	    are the ANM-004 effect's (TASK-112).
	  - Local rigs built on the client with `Tag = true` (passers-by, TASK-123) are tracked like any `AnimalRig` once
	    they enter the DataModel (CollectionService only signals tagged instances inside it), as any other rig. `Prepare(model)` dresses one synchronously before it is parented, so a pooled rig never
	    shows the Day pack for a frame.

	Warm-up (playtest fix, Day 1 morning): at start the whole character kit (ReplicatedStorage.Assets.Crew meshes,
	CrewExpressions, every CrewLooks texture) is preloaded once. Until that finishes (or WARMUP_TIMEOUT), NPC rigs
	(outfit Use ~= "Crew") are hidden locally with LocalTransparencyModifier, so nobody sees a half-downloaded NPC
	(dark body, no head/arms) during the intro. Only during the warm-up: no conflict with night anomaly effects.
	Texture ids go to PreloadAsync wrapped in a Decal (`preloadable`): a plain "rbxassetid://" string always reports
	Failure (checked in Studio 2026-10-17, as the audio ids of LoadQueue), so before that fix no look texture was really
	preloaded and every outfit / head / skin downloaded when the rig first showed (owner 2026-10-17: the looks rendered
	in front of the player at the start). Order: the crew (uniform, playable heads, class skins, atlas) first, then the
	NPC looks.
]]
local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Content = require(ReplicatedStorage.shared.Content)
local CrewLooks = require(ReplicatedStorage.shared.Crew.CrewLooks)
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)
local SkinLooks = require(ReplicatedStorage.shared.Crew.SkinLooks)
local SanityTier = require(ReplicatedStorage.shared.Anomaly.SanityTier)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

type Pack = CrewRig.Pack
type Rig = { Connections: { RBXScriptConnection }, Pending: boolean }

const NIGHT: Pack = "Night"
const NEUTRAL_FACE = Content.Looks.PackFace.Day -- Normal: NPC face without a mood
const NIGHT_FACE = Content.Looks.PackFace.Night -- Normal_Night: hallucinated NPC without a mood (DEC-169)

-- Wave 3 (TASK-110): customer-anomaly look (rig attribute, NpcService TASK-108).
const VARIANT_ATTRIBUTE = "Variant"
const BLANK = "blank"
const MIRROR = "mirror"
-- Fixed face by variant (name in ReplicatedStorage.CrewExpressions; kept outside the closed
-- Content.Looks.Expressions, so they are looked up here and never handed to Dress while missing).
const VARIANT_FACE = table.freeze({
	blank = "Blank", -- AST-060 T_Expr_Blank
	raincoat = "EyesClosed", -- AST-059 T_Expr_EyesClosed
	mirror = "EyesWhite", -- AST-062 `T_Expr_EyesWhite`, all-white eyes (Provisional 2026-10-14)
	eyes = "EyesWhite", -- V2 family A ANM-013 (DEC-254, TASK-292): same all-white eyes as the copy
	shake = "Angry", -- V2 family A ANM-011 (TASK-276, owner 2026-10-14): angry face while it shakes (T_Expr_Angry)
}) :: { [string]: string }
-- Face used while a variant's own expression is not in CrewExpressions yet (TASK-276: Angry not uploaded yet)
const VARIANT_FALLBACK = table.freeze({
	shake = "Stressed",
}) :: { [string]: string }
-- Variants always dressed Night on a rig, whatever the local sanity (Provisional 2026-10-14). Add future ones here.
-- Owner 2026-10-22: blank left (the ANM-001 customer arrives like any other one and keeps its skin when its face goes).
const NIGHT_VARIANTS = table.freeze({ raincoat = true }) :: { [string]: boolean }
-- AST-060 flat Blank head / atlas (CrewLooks.Species[k].Blank) on the blank variant. Off since 2026-10-22 (owner: keep
-- the species' skin): only the face shell goes blank. true = the old look (rollback).
const BLANK_HEAD = false
-- Variants whose fixed face waits for their tic (Content.Tics Body "Face"; owner 2026-10-22, ANM-001 arrives with a
-- face): without a local TicFace they show the ordinary face; Effects/Kit/Tic writes the blank one when it is due.
const FACE_WAITS: { [string]: boolean } = {}
for _, row in Content.Tics.List do
	if row.Body == "Face" then
		FACE_WAITS[row.Variant] = true
	end
end
-- Anomaly tics (Effects/Kit/Tic, owner 2026-10-22, Provisional): a LOCAL attribute on the rig that holds back or picks a
-- variant's fixed face: "" = the ordinary face for now (ANM-013 arrives with normal eyes), a name = that face (the white
-- eyes once they opened, or through a security camera). Never replicated; nil = the variant's face as always.
const TIC_FACE = "TicFace"
const MIRROR_SUFFIX = "_mirror" -- CrewLooks.Outfits key of the mirrored sheet (AST-062), Provisional
-- TASK-644 (Provisional, DEC-168/169/373): how many of the deepest Content.Sanity.Tiers make customers and passers-by look
-- Night on this client (2 = Shaken + Breaking, own sanity < 40).
const LOW_TIERS = 2
-- Variants that follow the hallucination like an ordinary customer (blank arrives in everyone's pack, owner 2026-10-22).
-- Not here: raincoat (always Night anyway), mirror (never Night), the family A faces (their own look).
const HALLUCINATION_VARIANTS = table.freeze({ blank = true }) :: { [string]: boolean }
-- s: NPC rigs are revealed after this even if the kit preload has not finished (Provisional).
const WARMUP_TIMEOUT = 12

const RigController = Modux.Controller("RigController", { Require = { "VitalController" }, Priority = 680 })

-- PreloadAsync list item for a texture id: a Decal holding it (a plain id string is reported Failure and not
-- downloaded). Instances pass through.
local function preloadable(items: { any }): { any }
	const out: { any } = {}
	for _, item in items do
		if typeof(item) == "string" then
			if item ~= "" then
				const holder = Instance.new("Decal")
				holder.Texture = item
				table.insert(out, holder)
			end
		else
			table.insert(out, item)
		end
	end
	return out
end

-- Every texture of a class skin (outfit sheets, atlas, head) by pack.
local function skinTextures(look: SkinLooks.SkinLook): { string }
	const out: { string } = { look.Day, look.Mid, look.Night, look.Atlas.Day, look.Atlas.Mid, look.Atlas.Night }
	const head = look.Head
	if head ~= nil then
		table.insert(out, head.Day)
		table.insert(out, head.Mid)
		table.insert(out, head.Night)
	end
	return out
end

function RigController:Setup()
	self.Rigs = {} :: { [Model]: Rig }
	-- Local face overrides by rig (weak keys: a forgotten override never keeps a rig alive).
	self.Expressions = setmetatable({}, { __mode = "k" }) :: { [Model]: string }
	self.Preloaded = {} :: { [string]: boolean }
	-- Kit warm-up done (or timed out): NPC rigs are shown as they arrive.
	self.Warm = false :: boolean
	-- NPC rigs hidden while the kit warms up -> their DescendantAdded connection.
	self.Concealed = {} :: { [Model]: RBXScriptConnection }
	-- TASK-644: own sanity in the low tiers right now (local hallucination on NPCs)
	self.Hallucinating = false :: boolean
end

local function isNpcRig(model: Model): boolean
	if model == Players.LocalPlayer.Character then
		return false
	end
	const outfit = model:GetAttribute("Outfit")
	const row = if typeof(outfit) == "string" then Content.Outfits.ByKey[outfit] else nil
	return row == nil or row.Use ~= "Crew"
end

local function setHidden(instance: Instance, hidden: boolean)
	const modifier = if hidden then 1 else 0
	if instance:IsA("BasePart") then
		instance.LocalTransparencyModifier = modifier
	end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = modifier
		end
	end
end

-- Hides an NPC rig locally until the warm-up ends (parts that stream in later are hidden too).
function RigController:Conceal(model: Model)
	if self.Warm or self.Concealed[model] ~= nil or not isNpcRig(model) then
		return
	end
	setHidden(model, true)
	self.Concealed[model] = model.DescendantAdded:Connect(function(descendant: Instance)
		setHidden(descendant, true)
	end)
end

function RigController:Reveal(model: Model)
	const connection = self.Concealed[model]
	if connection == nil then
		return
	end
	connection:Disconnect()
	self.Concealed[model] = nil
	setHidden(model, false)
	self:Schedule(model)
end

function RigController:EndWarmup()
	if self.Warm then
		return
	end
	self.Warm = true
	for model in self.Concealed do
		self:Reveal(model)
	end
end

-- Preloads every mesh and texture a rig can use, then reveals the concealed NPC rigs. Best effort, async.
function RigController:Warmup()
	task.delay(WARMUP_TIMEOUT, function()
		self:EndWarmup()
	end)
	task.spawn(function()
		const list: { any } = {}
		const assets = ReplicatedStorage:WaitForChild("Assets", 10)
		const crew = if assets then assets:WaitForChild("Crew", 10) else nil
		if crew ~= nil then
			table.insert(list, crew)
		end
		const expressions = ReplicatedStorage:FindFirstChild("CrewExpressions")
		if expressions ~= nil then
			table.insert(list, expressions)
		end
		-- the crew first: uniform, atlas, the playable species' heads and the class skins
		for _, id in CrewLooks.Outfits.crew or {} do
			table.insert(list, id)
		end
		for _, id in CrewLooks.Atlas do
			table.insert(list, id)
		end
		const crewSpecies: { [string]: boolean } = {}
		for _, class in Content.Classes.List do
			crewSpecies[class.Species] = true
			const look = CrewLooks.Species[class.Species]
			if look ~= nil then
				for _, id in look.Head do
					table.insert(list, id)
				end
			end
		end
		for _, look in SkinLooks.BySkin do
			for _, id in skinTextures(look) do
				table.insert(list, id)
			end
		end
		-- then the NPC looks
		for key, look in CrewLooks.Species do
			if not crewSpecies[key] then
				for _, id in look.Head do
					table.insert(list, id)
				end
			end
			if BLANK_HEAD and look.Blank ~= nil then
				table.insert(list, look.Blank.Head)
			end
		end
		for key, sheets in CrewLooks.Outfits do
			if key ~= "crew" then
				for _, id in sheets do
					table.insert(list, id)
				end
			end
		end
		pcall(function()
			ContentProvider:PreloadAsync(preloadable(list))
		end)
		self:EndWarmup()
	end)
end

-- Own sanity in the LOW_TIERS deepest tiers (reactive: reads VitalController's sources). Max 0 (no sanity: lobby,
-- out of the run) is never low.
function RigController:LowSanity(): boolean
	const vital = self.Dependencies.VitalController
	const max = vital.Max()
	if max <= 0 then
		return false
	end
	return SanityTier.index(vital.Sanity(), max) > #Content.Sanity.Tiers - LOW_TIERS
end

-- Re-dresses the NPC rigs whenever the local hallucination turns on or off (crew rigs are not touched).
function RigController:WatchSanity()
	Vide.root(function()
		Vide.effect(function()
			const low = self:LowSanity()
			if low == self.Hallucinating then
				return
			end
			self.Hallucinating = low
			for model in self.Rigs do
				if isNpcRig(model) then
					self:Schedule(model)
				end
			end
		end)
		return nil
	end)
end

-- Customer-anomaly variant of a rig (nil = ordinary). Not reactive.
function RigController:VariantOf(model: Model): string?
	const value = model:GetAttribute(VARIANT_ATTRIBUTE)
	return if typeof(value) == "string" and value ~= "" then value else nil
end

local function hasExpression(name: string): boolean
	const folder = ReplicatedStorage:FindFirstChild("CrewExpressions")
	const found = if folder then folder:FindFirstChild(name) else nil
	return found ~= nil and found:IsA("SurfaceAppearance")
end

-- Pack, face and blank flag this client shows for `model` (nil face = PackFace of the worn pack, inside Dress;
-- blank = dress the species' Blank head / atlas, AST-060: only with BLANK_HEAD, off since 2026-10-22).
function RigController:Resolve(model: Model): (Pack, string?, boolean)
	const outfit = model:GetAttribute("Outfit")
	const row = if typeof(outfit) == "string" then Content.Outfits.ByKey[outfit] else nil
	const pack = CrewRig.AsPack(model:GetAttribute("LookPack")) or "Day"
	const override = self.Expressions[model]
	if row ~= nil and row.Use == "Crew" then
		return pack, override, false
	end
	const variant = self:VariantOf(model)
	const reserved = row ~= nil and row.Use == "Reserved"
	-- TASK-644: own low sanity -> this client sees the ordinary customer / passer-by in the Night pack
	const hallucinated = self.Hallucinating
		and not reserved
		and (variant == nil or HALLUCINATION_VARIANTS[variant] == true)
	const nightVariant = variant ~= nil and NIGHT_VARIANTS[variant] == true and not reserved
	const shown: Pack = if nightVariant or hallucinated then NIGHT else pack
	local fixed = if variant then VARIANT_FACE[variant] else nil
	const ticFace = model:GetAttribute(TIC_FACE)
	if fixed ~= nil and type(ticFace) == "string" then
		fixed = if ticFace == "" then nil else ticFace
	elseif fixed ~= nil and variant ~= nil and FACE_WAITS[variant] then
		fixed = nil -- its face waits for the tic (ANM-001 arrives with its own face)
	end
	if fixed ~= nil and not hasExpression(fixed) and variant ~= nil then
		fixed = VARIANT_FALLBACK[variant]
	end
	if fixed ~= nil and hasExpression(fixed) then
		-- Blank head / atlas only together with the empty face, and only with BLANK_HEAD (off: the species' own head)
		return shown, fixed, BLANK_HEAD and variant == BLANK and fixed == VARIANT_FACE[BLANK] and not reserved
	end
	-- DEC-169: the hallucinated NPC wears Normal_Night unless a mood is showing (Provisional: the mood still wins)
	return shown, override or (if hallucinated then NIGHT_FACE else NEUTRAL_FACE), false
end

-- Local face for one rig (e.g. the customer's mood); nil clears it. Purely local, never replicated.
function RigController:SetExpression(model: Model, expression: string?)
	self.Expressions[model] = expression
	self:Schedule(model)
end

-- Re-dress one rig, or every tracked rig.
function RigController:Refresh(model: Model?)
	if model ~= nil then
		self:Schedule(model)
		return
	end
	for rig in self.Rigs do
		self:Schedule(rig)
	end
end

function RigController:Schedule(model: Model)
	const rig = self.Rigs[model]
	if rig == nil or rig.Pending then
		return
	end
	rig.Pending = true
	task.defer(function()
		rig.Pending = false
		if self.Rigs[model] == rig then
			self:Apply(model)
		end
	end)
end

function RigController:Apply(model: Model)
	if not model:IsDescendantOf(workspace) then
		return
	end
	self:Dress(model)
end

-- Local rig (TASK-123): dress now, before it is parented (no Day frame). Tracking starts when it enters the
-- DataModel with its AnimalRig tag. Safe to call on any rig built by CrewRig.Build.
function RigController:Prepare(model: Model)
	self:Dress(model)
end

function RigController:Dress(model: Model)
	const pack, face, blank = self:Resolve(model)
	if not CrewRig.Dress(model, pack, face, blank) then
		return
	end
	self:ApplyVariant(model, pack)
	self:Preload(model)
end

-- What Dress cannot do for a variant (TASK-110): the mirrored outfit sheet.
function RigController:ApplyVariant(model: Model, pack: Pack)
	const variant = self:VariantOf(model)

	if variant == MIRROR then
		const outfit = model:GetAttribute("Outfit")
		const sheets = if typeof(outfit) == "string" then CrewLooks.Outfits[outfit .. MIRROR_SUFFIX] else nil
		const sheet = if sheets and typeof(outfit) == "string" then sheets[CrewRig.EffectivePack(outfit, pack)] else nil
		if sheet ~= nil then
			for _, child in model:GetChildren() do
				if child:IsA("MeshPart") and child:GetAttribute("OutfitPart") then
					CrewRig.ApplySheet(child, sheet)
				end
			end
		end
	end
end

-- First time a species / outfit shows up, preload its three packs so a later band change does not blink
-- (network.md §5.1; DEC-167 Provisional "3 packs preloaded"). Async, best effort.
function RigController:Preload(model: Model)
	const ids: { any } = {}
	local function add(key: string, textures: { [Pack]: string })
		if self.Preloaded[key] then
			return
		end
		self.Preloaded[key] = true
		for _, id in textures do
			table.insert(ids, id)
		end
	end
	const species = model:GetAttribute("Species")
	const outfit = model:GetAttribute("Outfit")
	const look = if typeof(species) == "string" then CrewLooks.Species[species] else nil
	const sheets = if typeof(outfit) == "string" then CrewLooks.Outfits[outfit] else nil
	if look ~= nil then
		add("Species:" .. (species :: string), look.Head)
		if BLANK_HEAD and look.Blank ~= nil and self:VariantOf(model) == BLANK then
			add("Blank:" .. (species :: string), { Day = look.Blank.Head, Mid = look.Blank.Atlas.Mid, Night = look.Blank.Atlas.Night })
		end
	end
	if sheets ~= nil then
		add("Outfit:" .. (outfit :: string), sheets)
	end
	add("Atlas", CrewLooks.Atlas)
	const skin = model:GetAttribute("Skin")
	const skinLook = if typeof(skin) == "string" then SkinLooks.BySkin[skin] else nil
	if skinLook ~= nil and not self.Preloaded["Skin:" .. (skin :: string)] then
		self.Preloaded["Skin:" .. (skin :: string)] = true
		for _, id in skinTextures(skinLook) do
			table.insert(ids, id)
		end
	end
	if not self.Preloaded.Expressions then
		self.Preloaded.Expressions = true
		const folder = ReplicatedStorage:FindFirstChild("CrewExpressions")
		if folder ~= nil then
			for _, expression in folder:GetChildren() do
				table.insert(ids, expression)
			end
		end
	end
	if #ids > 0 then
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync(preloadable(ids))
			end)
		end)
	end
end

function RigController:Add(instance: Instance)
	if not instance:IsA("Model") or self.Rigs[instance] ~= nil then
		return
	end
	const model = instance
	const rig: Rig = { Connections = {}, Pending = false }
	self.Rigs[model] = rig
	self:Conceal(model)
	local function schedule()
		self:Schedule(model)
	end
	table.insert(
		rig.Connections,
		model.AttributeChanged:Connect(function(name: string)
			if name == VARIANT_ATTRIBUTE or name == TIC_FACE or table.find(CrewRig.LookAttributes, name) then
				schedule()
			end
		end)
	)
	-- parts that arrive late (streaming) or are rebuilt get dressed too
	table.insert(
		rig.Connections,
		model.ChildAdded:Connect(function(child: Instance)
			if child:IsA("BasePart") then
				schedule()
			end
		end)
	)
	table.insert(rig.Connections, model.AncestryChanged:Connect(schedule))
	table.insert(
		rig.Connections,
		model.Destroying:Connect(function()
			self.Expressions[model] = nil
			const concealed = self.Concealed[model]
			if concealed ~= nil then
				concealed:Disconnect()
				self.Concealed[model] = nil
			end
			self:Remove(model)
		end)
	)
	schedule()
end

function RigController:Remove(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	const rig = self.Rigs[instance]
	if rig == nil then
		return
	end
	for _, connection in rig.Connections do
		connection:Disconnect()
	end
	self.Rigs[instance] = nil
end

RigController:OnInit(function(self)
	self:Setup()
end)

RigController:OnStart(function(self)
	self:Warmup()
	self:WatchSanity()
	CollectionService:GetInstanceAddedSignal(CrewRig.Tag):Connect(function(instance: Instance)
		self:Add(instance)
	end)
	CollectionService:GetInstanceRemovedSignal(CrewRig.Tag):Connect(function(instance: Instance)
		self:Remove(instance)
	end)
	for _, instance in CollectionService:GetTagged(CrewRig.Tag) do
		self:Add(instance)
	end
end)

return RigController
