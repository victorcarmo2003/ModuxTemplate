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

const RigController = Modux.Controller("RigController", { Priority = 680 })

function RigController:Setup()
	self.Rigs = {} :: { [Model]: Rig }
	-- Local face overrides by rig (weak keys: a forgotten override never keeps a rig alive).
	self.Expressions = setmetatable({}, { __mode = "k" }) :: { [Model]: string }
	-- The local character is in the low sanity band (LookPack = "Night").
	self.LowBand = false :: boolean
	self.CharacterConnection = nil :: RBXScriptConnection?
	self.Preloaded = {} :: { [string]: boolean }
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
	const pack, face = self:Resolve(model)
	if CrewRig.Dress(model, pack, face) then
		self:Preload(model)
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
	local function schedule()
		self:Schedule(model)
	end
	table.insert(
		rig.Connections,
		model.AttributeChanged:Connect(function(name: string)
			if table.find(CrewRig.LookAttributes, name) then
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
