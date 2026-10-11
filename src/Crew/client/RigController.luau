--!strict
--[[
	RigController (TASK-016; architecture.md §18.9.2 / §18.9.4, network.md §5.1-5.3 T40)

	Dresses every `AnimalRig` model in the Workspace with CrewRig.Dress, when it appears (including models that
	stream in) and again whenever a look attribute (Species, Outfit, CustomerType, LookPack) or the local layer
	changes. Never talks to the network: the server writes attributes, this client decides textures and faces.

	Local layer (network.md §5.3):
	  - crew rig (Outfits.Use = "Crew"): its own LookPack, face = Content.Looks.PackFace (everyone sees the same);
	  - NPC: its LookPack, face = local override (SetExpression: mood from CustomerController, TASK-034) or the
	    neutral face;
	  - when the local character has LookPack = "Night" (low band, DEC-168/169), every NPC except reserved outfits
	    (Quick Quentin, DEC-159) is dressed Night + Normal_Night on this client only; Normal_Night beats the mood
	    (Provisional, proposals-round-3.md §2). Since the crew is never Night by day (DEC-167), this only happens
	    at night. A server write of LookPack re-dresses through the same rule, so the local Night is never undone.
	Local-only rigs (Opal, previews) are built with `Tag = false` and dressed by their owner with CrewRig.Dress.

	Wave 3 (TASK-110; architecture.md §19.3, §19.17; anomalies.md N1/N4/N5):
	  - Customer-anomaly `Variant` (rig attribute written by NpcService, TASK-108: blank / mirror / raincoat; nil =
	    ordinary). Re-dressed when it changes (a pooled rig loses it on release). Applied on this client only:
	      blank     face = CrewExpressions.Blank (AST-060 `T_Expr_Blank`, empty shell); while the kit lacks it the face
	                shell is hidden locally (LocalTransparencyModifier 1), same reading: no eyes, mouth or brows.
	      raincoat  face = CrewExpressions.EyesClosed (AST-059); while missing, the ordinary resolution.
	      mirror    ordinary face (the copy reacts like a customer); outfit sheet = CrewLooks.Outfits["<outfit>_mirror"]
	                for the worn pack when that row exists (AST-062, only Mid), else the ordinary sheet.
	    The variant face beats the mood and the low-band Normal_Night (the sign must stay readable: Provisional,
	    frontend-coder); the pack still follows the low band. Mirrored accessories are the ANM-004 effect's (TASK-112).
	  - Local rigs built on the client with `Tag = true` (passers-by, TASK-123) are tracked like any `AnimalRig` once
	    they enter the DataModel (CollectionService only signals tagged instances inside it), including the local
	    Night of the low band. `Prepare(model)` dresses one synchronously before it is parented, so a pooled rig never
	    shows the Day pack for a frame.

	Warm-up (playtest fix, Day 1 morning): at start the whole character kit (ReplicatedStorage.Assets.Crew meshes,
	CrewExpressions, every CrewLooks texture) is preloaded once. Until that finishes (or WARMUP_TIMEOUT), NPC rigs
	(outfit Use ~= "Crew") are hidden locally with LocalTransparencyModifier, so nobody sees a half-downloaded NPC
	(dark body, no head/arms) during the intro. Only during the warm-up: no conflict with night anomaly effects.
]]
local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Content = require(ReplicatedStorage.shared.Content)
local CrewLooks = require(ReplicatedStorage.shared.Crew.CrewLooks)
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

type Pack = CrewRig.Pack
type Rig = { Connections: { RBXScriptConnection }, Pending: boolean }

const NIGHT: Pack = "Night"
const NIGHT_FACE = Content.Looks.PackFace.Night -- Normal_Night (DEC-168, DEC-207)
const NEUTRAL_FACE = Content.Looks.PackFace.Day -- Normal: NPC face without a mood

-- Wave 3 (TASK-110): customer-anomaly look (rig attribute, NpcService TASK-108).
const VARIANT_ATTRIBUTE = "Variant"
const BLANK = "blank"
const MIRROR = "mirror"
-- Fixed face by variant (name in ReplicatedStorage.CrewExpressions; outside Content.Looks.Expressions until the
-- AST-059/060 textures land, so they are looked up here and never handed to Dress while missing).
const VARIANT_FACE = table.freeze({
	blank = "Blank", -- AST-060 T_Expr_Blank
	raincoat = "EyesClosed", -- AST-059 T_Expr_EyesClosed
}) :: { [string]: string }
const MIRROR_SUFFIX = "_mirror" -- CrewLooks.Outfits key of the mirrored sheet (AST-062), Provisional
-- s: NPC rigs are revealed after this even if the kit preload has not finished (Provisional).
const WARMUP_TIMEOUT = 20

const RigController = Modux.Controller("RigController", { Priority = 680 })

function RigController:Setup()
	self.Rigs = {} :: { [Model]: Rig }
	-- Local face overrides by rig (weak keys: a forgotten override never keeps a rig alive).
	self.Expressions = setmetatable({}, { __mode = "k" }) :: { [Model]: string }
	-- The local character is in the low sanity band (LookPack = "Night").
	self.LowBand = false :: boolean
	self.CharacterConnection = nil :: RBXScriptConnection?
	self.Preloaded = {} :: { [string]: boolean }
	-- Rigs whose face shell this controller hid (blank without its expression); weak keys.
	self.HiddenFaces = setmetatable({}, { __mode = "k" }) :: { [Model]: boolean }
	-- Kit warm-up done (or timed out): NPC rigs are shown as they arrive.
	self.Warm = false :: boolean
	-- NPC rigs hidden while the kit warms up -> their DescendantAdded connection.
	self.Concealed = {} :: { [Model]: RBXScriptConnection }
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
	self.HiddenFaces[model] = nil
	self:Schedule(model) -- re-applies a variant's hidden face (ApplyVariant)
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
		for _, look in CrewLooks.Species do
			for _, id in look.Head do
				table.insert(list, id)
			end
		end
		for _, sheets in CrewLooks.Outfits do
			for _, id in sheets do
				table.insert(list, id)
			end
		end
		for _, id in CrewLooks.Atlas do
			table.insert(list, id)
		end
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
		self:EndWarmup()
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

-- Pack and face this client shows for `model` (nil face = PackFace of the worn pack, inside Dress).
function RigController:Resolve(model: Model): (Pack, string?)
	const outfit = model:GetAttribute("Outfit")
	const row = if typeof(outfit) == "string" then Content.Outfits.ByKey[outfit] else nil
	const pack = CrewRig.AsPack(model:GetAttribute("LookPack")) or "Day"
	const override = self.Expressions[model]
	if row ~= nil and row.Use == "Crew" then
		return pack, override
	end
	const variant = self:VariantOf(model)
	const fixed = if variant then VARIANT_FACE[variant] else nil
	if fixed ~= nil and hasExpression(fixed) then
		return if self.LowBand and (row == nil or row.Use ~= "Reserved") then NIGHT else pack, fixed
	end
	if self.LowBand and (row == nil or row.Use ~= "Reserved") then
		return NIGHT, NIGHT_FACE
	end
	if override == nil and outfit == "thief" then
		return pack, "Thief" -- Quick Quentin's own face (T_Expr_Thief, NPC-007)
	end
	return pack, override or NEUTRAL_FACE
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
	const pack, face = self:Resolve(model)
	if not CrewRig.Dress(model, pack, face) then
		return
	end
	self:ApplyVariant(model, pack)
	self:Preload(model)
end

-- What Dress cannot do for a variant (TASK-110): the mirrored sheet and the blank face without its texture.
function RigController:ApplyVariant(model: Model, pack: Pack)
	const variant = self:VariantOf(model)

	const hide = variant == BLANK and not hasExpression(VARIANT_FACE[BLANK])
	if hide or self.HiddenFaces[model] then
		const face = model:FindFirstChild("Face")
		if face ~= nil and face:IsA("BasePart") then
			face.LocalTransparencyModifier = if hide then 1 else 0
		end
		self.HiddenFaces[model] = if hide then true else nil
	end

	if variant == MIRROR then
		const outfit = model:GetAttribute("Outfit")
		const sheets = if typeof(outfit) == "string" then CrewLooks.Outfits[outfit .. MIRROR_SUFFIX] else nil
		const sheet = if sheets and typeof(outfit) == "string" then sheets[CrewRig.EffectivePack(outfit, pack)] else nil
		if sheet ~= nil then
			for _, child in model:GetChildren() do
				if child:IsA("MeshPart") and child:GetAttribute("OutfitPart") and child.TextureID ~= sheet then
					child.TextureID = sheet
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
	end
	if sheets ~= nil then
		add("Outfit:" .. (outfit :: string), sheets)
	end
	add("Atlas", CrewLooks.Atlas)
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
				ContentProvider:PreloadAsync(ids)
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
			if name == VARIANT_ATTRIBUTE or table.find(CrewRig.LookAttributes, name) then
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
			self.HiddenFaces[model] = nil
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

-- Low band of the local character (its LookPack attribute, written by the server).
function RigController:WatchCharacter(character: Model?)
	const previous = self.CharacterConnection
	if previous ~= nil then
		previous:Disconnect()
		self.CharacterConnection = nil
	end
	local function update()
		const low = character ~= nil and character:GetAttribute("LookPack") == NIGHT
		if low ~= self.LowBand then
			self.LowBand = low
			self:Refresh()
		end
	end
	if character ~= nil then
		self.CharacterConnection = character:GetAttributeChangedSignal("LookPack"):Connect(update)
	end
	update()
end

RigController:OnInit(function(self)
	self:Setup()
end)

RigController:OnStart(function(self)
	self:Warmup()
	const player = Players.LocalPlayer
	player.CharacterAdded:Connect(function(character: Model)
		self:WatchCharacter(character)
	end)
	player.CharacterRemoving:Connect(function()
		self:WatchCharacter(nil)
	end)
	self:WatchCharacter(player.Character)

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
