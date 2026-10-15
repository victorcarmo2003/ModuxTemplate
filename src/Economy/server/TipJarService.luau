--!strict
-- Tip jar prompt (DEC-239, user decision 2026-10-13; PROVISIONAL). Replaces CashDeskService (the register / drawer, Q-201).
-- Run place only. Sales go straight to the party Cash (DEC-238); only TIPS fall in the jar (customer tips, table tips).
-- The crew collects them on a prompt (Content.Actions.collect_tips, hold 0.4 s) and EconomyService:CollectTips() moves the
-- jar to Cash; the tips nobody collected are deposited at the Summary (EconomyService:Deposit).
-- Jar model: a Model with attribute MapId = Content.TipJar.MapId ("TRL-TIPJAR") inside the Vehicle. While the map has not
-- migrated, the old drawer ids (Content.TipJar.LegacyMapIds: DRAWER, TRL-DRAWER) are accepted as the jar, with a warning.
-- Anchor: Attachment `Prompt_Collect` on the top part of the jar model, created at runtime (no place edit needed). If the map
-- already has an Attachment named Prompt_Collect inside that model, it is tagged and used as is (the level designer
-- fine-tunes the spot that way). PromptEnabled = the shop takes entries, the jar holds money and the vehicle is the one in
-- use. The client only presents (EconomyController fills the jar from the Economy set field Drawer and plays the coins on
-- the CashCollected packet, which keeps its shape: Amount).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(ServerScriptService.server.Modux)

const ACTION = "collect_tips"
const ANCHOR_NAME = "Prompt_Collect"
const ANCHOR_TAG = "Interactable"
const VEHICLE_TAG = "Vehicle"
const VEHICLE_ATTRIBUTE = "Vehicle"
-- Studs above the highest part of the jar model. PROVISIONAL: clears the jar number (Value_Anchor + 0.6) and sits apart
-- from the topping pills of the cart.
const LIFT = 1.6

const TipJarService = Modux.Service("TipJarService", {
	Require = { "PlaceService", "NetService", "RoundService", "EconomyService", "InteractionService" },
	Priority = 585,
})

function TipJarService:Setup()
	self.Enabled = false :: boolean
	-- anchor -> Vehicle model that owns it
	self.Jars = {} :: { [Attachment]: Instance }
	self.WarnedLegacy = false :: boolean
end

-- Highest BasePart of a model (the top of the jar)
local function topPart(model: Instance): BasePart?
	local best: BasePart? = nil
	local bestTop = -math.huge
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			const top = descendant.Position.Y + descendant.Size.Y / 2
			if top > bestTop then
				bestTop = top
				best = descendant
			end
		end
	end
	return best
end

-- The jar Model of a vehicle: the new MapId first, the legacy drawer ids as a fallback
function TipJarService:FindJar(vehicle: Instance): Model?
	const config = Content.TipJar
	local legacy: Model? = nil
	for _, descendant in vehicle:GetDescendants() do
		const id = descendant:GetAttribute("MapId")
		if not descendant:IsA("Model") or type(id) ~= "string" then
			continue
		end
		if id == config.MapId then
			return descendant
		elseif legacy == nil and table.find(config.LegacyMapIds, id) ~= nil then
			legacy = descendant
		end
	end
	if legacy ~= nil and not self.WarnedLegacy then
		self.WarnedLegacy = true
		warn(`[TipJarService] using the old drawer model {legacy:GetFullName()} as the tip jar: give it MapId {config.MapId}`)
	end
	return legacy
end

function TipJarService:Build(vehicle: Instance)
	const jar = self:FindJar(vehicle)
	if jar == nil then
		return
	end
	local anchor = jar:FindFirstChild(ANCHOR_NAME, true)
	if anchor == nil or not anchor:IsA("Attachment") then
		const part = topPart(jar)
		if part == nil then
			return
		end
		const created = Instance.new("Attachment")
		created.Name = ANCHOR_NAME
		created.Parent = part
		created.WorldPosition = part.Position + Vector3.new(0, part.Size.Y / 2 + LIFT, 0)
		anchor = created
	end
	const attachment = anchor :: Attachment
	-- Attributes before the tag: InteractionService reads them when the anchor is tagged
	attachment:SetAttribute("PromptAction", ACTION)
	attachment:SetAttribute("PromptEnabled", false)
	self.Jars[attachment] = vehicle
	CollectionService:AddTag(attachment, ANCHOR_TAG)
end

-- Jar -> Cash now and the coins on every client. Shared by the prompt and the dev command. Returns what moved.
function TipJarService:CollectNow(): number
	const amount = self.Dependencies.EconomyService:CollectTips()
	if amount > 0 and self.Dependencies.NetService:IsRunning() then
		self.Libs.Net.CashCollected:fireClient(self.Dependencies.NetService.Audience, { Amount = amount })
	end
	return amount
end

-- Anchor of the vehicle in use, shop taking entries, tips inside
function TipJarService:IsLive(anchor: Instance): boolean
	const vehicle = self.Jars[anchor :: Attachment]
	if vehicle == nil then
		return false
	end
	const round = self.Dependencies.RoundService
	const economy = self.Dependencies.EconomyService
	return round:IsStarted()
		and vehicle:GetAttribute(VEHICLE_ATTRIBUTE) == round:CurrentVehicle()
		and economy:IsDrawerOpen()
		and economy:GetDrawer() > 0
end

function TipJarService:Refresh()
	const interaction = self.Dependencies.InteractionService
	for anchor in self.Jars do
		interaction:SetPrompt(anchor, self:IsLive(anchor))
	end
end

TipJarService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self.Enabled = true

	-- Priority 585 < 730: InteractionService already built its handler table
	self.Dependencies.InteractionService:RegisterAction(ACTION, {
		Validate = function(_player: Player, anchor: Instance): boolean
			return self:IsLive(anchor)
		end,
		Run = function(_player: Player, anchor: Instance)
			if not self:IsLive(anchor) then
				return
			end
			self:CollectNow()
		end,
	})
end)

TipJarService:OnStart(function(self)
	if not self.Enabled then
		return
	end
	-- The map is loaded (StreamingEnabled off, T57)
	for _, vehicle in CollectionService:GetTagged(VEHICLE_TAG) do
		if vehicle:IsDescendantOf(workspace) then
			self:Build(vehicle)
		end
	end
	if next(self.Jars) == nil then
		warn(`[TipJarService] no {Content.TipJar.MapId} model inside a Vehicle: 'Collect Tips' has no prompt`)
	end

	-- Jar money and phase are atoms; the vehicle in use changes at ShiftStarted
	self.Libs.Charm.effect(function()
		self.Dependencies.EconomyService.Drawer()
		self.Dependencies.RoundService.Phase()
		self:Refresh()
	end)
	self.Dependencies.RoundService.ShiftStarted:Connect(function()
		self:Refresh()
	end)
end)

return TipJarService
