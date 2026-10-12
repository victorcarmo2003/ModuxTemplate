--!strict
-- "Collect Cash" at the register (user playtest 2026-10-11; PROVISIONAL, Q-201). Run place only.
-- Sales still fall into the drawer (DEC-050) and the end-of-shift report still shows the whole day take, but the crew
-- can now move the drawer to the party Cash at any time (Content.Actions.collect_cash, hold 0.4 s) to buy ingredients.
-- Server-authoritative: EconomyService:Collect() does the move; the thief and Cash Drawer Lock keep working on what is
-- left in the drawer (a collected drawer is below Thief.MinDrawer: nothing to steal).
-- Anchor: Attachment `Prompt_Collect` on the top part of the DRAWER (cart) / TRL-DRAWER (trailer) model, created at
-- runtime (no place edit needed). If the map already has an Attachment named Prompt_Collect inside that model, it is
-- tagged and used as is (that is how the level designer fine-tunes the spot). PromptEnabled = the drawer is open, holds
-- money and the vehicle is the one in use; the client only presents (EconomyController plays the coins on CashCollected).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(ServerScriptService.server.Modux)

const ACTION = "collect_cash"
const ANCHOR_NAME = "Prompt_Collect"
const ANCHOR_TAG = "Interactable"
const VEHICLE_TAG = "Vehicle"
const VEHICLE_ATTRIBUTE = "Vehicle"
const DRAWER_IDS: { [string]: boolean } = { DRAWER = true, ["TRL-DRAWER"] = true }
-- Studs above the highest part of the drawer model. PROVISIONAL: clears the DrawerValue number (Value_Anchor + 0.6)
-- and sits apart from the topping pills of the cart.
const LIFT = 1.6

const CashDeskService = Modux.Service("CashDeskService", {
	Require = { "PlaceService", "NetService", "RoundService", "EconomyService", "InteractionService" },
	Priority = 585,
})

function CashDeskService:Setup()
	self.Enabled = false :: boolean
	-- anchor -> Vehicle model that owns it
	self.Desks = {} :: { [Attachment]: Instance }
end

-- Highest BasePart of a model (the top of the register / POS)
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

function CashDeskService:Build(vehicle: Instance)
	local drawer: Instance? = nil
	for _, descendant in vehicle:GetDescendants() do
		const id = descendant:GetAttribute("MapId")
		if descendant:IsA("Model") and type(id) == "string" and DRAWER_IDS[id] then
			drawer = descendant
			break
		end
	end
	if drawer == nil then
		return
	end
	local anchor = drawer:FindFirstChild(ANCHOR_NAME, true)
	if anchor == nil or not anchor:IsA("Attachment") then
		const part = topPart(drawer)
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
	self.Desks[attachment] = vehicle
	CollectionService:AddTag(attachment, ANCHOR_TAG)
end

-- Anchor of the vehicle in use, drawer open, money inside
function CashDeskService:IsLive(anchor: Instance): boolean
	const vehicle = self.Desks[anchor :: Attachment]
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

function CashDeskService:Refresh()
	const interaction = self.Dependencies.InteractionService
	for anchor in self.Desks do
		interaction:SetPrompt(anchor, self:IsLive(anchor))
	end
end

CashDeskService:OnInit(function(self)
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
			const amount = self.Dependencies.EconomyService:Collect()
			if amount > 0 and self.Dependencies.NetService:IsRunning() then
				self.Libs.Net.CashCollected:fireClient(self.Dependencies.NetService.Audience, { Amount = amount })
			end
		end,
	})
end)

CashDeskService:OnStart(function(self)
	if not self.Enabled then
		return
	end
	-- The map is loaded (StreamingEnabled off, T57)
	for _, vehicle in CollectionService:GetTagged(VEHICLE_TAG) do
		if vehicle:IsDescendantOf(workspace) then
			self:Build(vehicle)
		end
	end
	if next(self.Desks) == nil then
		warn("[CashDeskService] no DRAWER / TRL-DRAWER model inside a Vehicle: 'Collect Cash' has no prompt")
	end

	-- Drawer money and phase are atoms; the vehicle in use changes at ShiftStarted
	self.Libs.Charm.effect(function()
		self.Dependencies.EconomyService.Drawer()
		self.Dependencies.RoundService.Phase()
		self:Refresh()
	end)
	self.Dependencies.RoundService.ShiftStarted:Connect(function()
		self:Refresh()
	end)
end)

return CashDeskService
