--!strict
-- Robux shop: the single MarketplaceService.ProcessReceipt of the place, Lobby and Run (TASK-160; user request
-- 2026-10-11, Provisional; architecture.md §10.1, data.md §1.4 and §1.7, network.md §15). It plays the
-- MonetizationService role of architecture.md §10.1 (same priority, 790) under the feature name Shop.
-- Products: gem packs and class products from Content.Shop (ProductId 0 = not created yet: never registered); other
-- services add theirs with RegisterProduct in their OnInit (wave 4 revive).
-- Idempotent per PurchaseId: the grant patch and the PurchaseId (profile.Receipts, last RECEIPTS_KEPT) are written in
-- one Update (one Charm batch, no yield between the "already granted?" check and the write), and PurchaseGranted is
-- returned only after ProfileService:SaveConfirmed sees the PurchaseId in LastSavedData. Anything else returns
-- NotProcessedYet and Roblox delivers the receipt again (here or on the next server the player joins).
-- The client prompts (PromptProductPurchase with the id from Content.Shop); this service never prompts and trusts
-- nothing from the client: only Roblox receipts grant.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Atomic = require(ReplicatedStorage.shared.Types.Atomic)
local Struct = require(ReplicatedStorage.shared.Types.Struct)
local Template = require(ServerScriptService.server.Profile.ProfileService.Template)
local Modux = require(ServerScriptService.server.Modux)

-- Same type as ProfileService.Profile (one atom per Template field)
type Profile = Atomic.Table<Template.Data>

export type Patch = Struct.Partial<Template.Data>

-- What a product gives. Patch is applied with the PurchaseId in one batch (it must not touch Receipts); After runs
-- once, right after the grant (feedback only: Notice, ClassBuyResult). No yield inside a Handler.
export type Grant = {
	Patch: Patch,
	After: (() -> ())?,
}
export type Handler = (player: Player, profile: Profile) -> Grant

-- MarketplaceService.ProcessReceipt argument (fields this service reads)
export type Receipt = {
	PlayerId: number,
	PurchaseId: string,
	ProductId: number,
}

const RECEIPTS_KEPT = 50 -- circular list in the profile (data.md §1.1)
const PROFILE_WAIT = 10 -- s a receipt waits for a profile that is still loading
const GEMS_MAX = 2147483647 -- Profile.Gems wire range (network.md §4.5)

const ShopService = Modux.Service(
	"ShopService",
	{ Require = { "ProfileService", "NetService", "PlaceService" }, Priority = 790 }
)

function ShopService:Setup()
	self.Handlers = {} :: { [number]: Handler }
	-- ProductId -> key, for logs
	self.Names = {} :: { [number]: string }
end

-- Registers a Developer Product. Call in OnInit (receipts start in OnStart). A ProductId of 0 or less is a product not
-- created on the Creator Hub yet: skipped with no error (Content.Shop placeholders).
function ShopService:RegisterProduct(productId: number, name: string, handler: Handler)
	if productId <= 0 then
		return
	end
	if self.Handlers[productId] then
		error(`[ShopService] ProductId {productId} registered twice ({self.Names[productId]}, {name})`)
	end
	self.Handlers[productId] = handler
	self.Names[productId] = name
end

function ShopService:Notify(player: Player, kind: string, value: number)
	const net = self.Dependencies.NetService
	if not net:IsRunning() or not net:IsReady(player) then
		return
	end
	self.Libs.Net.Notice:fireClient(player, {
		Kind = kind,
		Value = value,
	})
end

function ShopService:ReplyClass(player: Player, key: string, reason: "Granted" | "Converted")
	const net = self.Dependencies.NetService
	if not net:IsRunning() or not net:IsReady(player) then
		return
	end
	self.Libs.Net.ClassBuyResult:fireClient(player, {
		Class = key,
		Ok = true,
		Reason = reason,
	})
end

-- Gem pack: Gems += pack.Gems (GemsEarned stays: earned, not bought).
function ShopService:GemPackHandler(pack: Content.ShopGemPack): Handler
	return function(player: Player, profile: Profile): Grant
		return {
			Patch = { Gems = math.clamp(profile.Gems() + pack.Gems, 0, GEMS_MAX) },
			After = function()
				self:Notify(player, "gems_gained", pack.Gems)
			end,
		}
	end
end

-- Class product: unlocks the class. Already owned (bought with gems or a code between the prompt and the receipt):
-- the purchase turns into the class gem price, so nothing paid is lost (data.md §1.7, Provisional).
function ShopService:ClassHandler(key: string): Handler
	const class = Content.Classes.ByKey[key]
	return function(player: Player, profile: Profile): Grant
		const profiles = self.Dependencies.ProfileService
		if profiles:OwnedClasses(profile)[key] then
			return {
				Patch = { Gems = math.clamp(profile.Gems() + class.Price, 0, GEMS_MAX) },
				After = function()
					self:ReplyClass(player, key, "Converted")
					self:Notify(player, "gems_gained", class.Price)
				end,
			}
		end
		return {
			Patch = { Classes = profiles:WithClass(profile, key) },
			After = function()
				self:ReplyClass(player, key, "Granted")
				self:Notify(player, "class_bought", Content.Classes.IndexOf[key])
			end,
		}
	end
end

function ShopService:RegisterContent()
	for _, pack in Content.Shop.GemPacks.List do
		self:RegisterProduct(pack.ProductId, pack.Key, self:GemPackHandler(pack))
	end
	for _, product in Content.Shop.ClassProducts.List do
		const class = Content.Classes.ByKey[product.Key]
		if not class or not class.InMvp then
			warn(`[ShopService] Content.Shop.ClassProducts.{product.Key} is not an MVP class: not sold`)
			continue
		end
		self:RegisterProduct(product.ProductId, product.Key, self:ClassHandler(product.Key))
	end
	if next(self.Handlers) == nil then
		warn("[ShopService] no Developer Product ids in Content.Shop yet (all 0): Robux purchases are off")
	end
end

-- Profile of a player still in the server, waiting up to PROFILE_WAIT s while it loads.
function ShopService:WaitProfile(player: Player): Profile?
	const profiles = self.Dependencies.ProfileService
	const deadline = os.clock() + PROFILE_WAIT
	local profile = profiles:Get(player)
	while profile == nil and player.Parent == Players and os.clock() < deadline do
		task.wait(0.25)
		profile = profiles:Get(player)
	end
	return profile
end

local function withReceipt(receipts: { string }, purchaseId: string): { string }
	const out = table.clone(receipts)
	table.insert(out, purchaseId)
	while #out > RECEIPTS_KEPT do
		table.remove(out, 1)
	end
	return out
end

function ShopService:ProcessReceipt(receipt: Receipt): Enum.ProductPurchaseDecision
	const player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- delivered again when the player joins a server
	end
	const handler = self.Handlers[receipt.ProductId]
	if not handler then
		warn(`[ShopService] receipt {receipt.PurchaseId} for unknown ProductId {receipt.ProductId} (Content.Shop?)`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return self:Fulfil(player, handler, receipt.PurchaseId, self.Names[receipt.ProductId])
end

-- Grants once per PurchaseId and confirms the save (data.md §1.4). Yields.
function ShopService:Fulfil(
	player: Player,
	handler: Handler,
	purchaseId: string,
	name: string
): Enum.ProductPurchaseDecision
	const profile = self:WaitProfile(player)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	const profiles = self.Dependencies.ProfileService
	local after: (() -> ())? = nil
	-- from the check to the Update: no yield, so a concurrent ProcessReceipt for the same id sees it already granted
	if table.find(profile.Receipts(), purchaseId) == nil then
		const ok, grant = pcall(handler, player, profile)
		if not ok then
			warn(`[ShopService] handler {name} failed for {purchaseId}: {grant}`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		const patch = table.clone(grant.Patch) :: { [string]: any }
		patch.Receipts = withReceipt(profile.Receipts(), purchaseId)
		profiles:Update(player, patch :: any)
		after = grant.After
	end
	if after then
		task.spawn(after) -- the balance is already in the Profile packet; the toast does not wait for the DataStore
	end

	const saved = profiles:SaveConfirmed(player, function(data): boolean
		const list = data.Receipts
		return type(list) == "table" and table.find(list, purchaseId) ~= nil
	end)
	if saved then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	warn(`[ShopService] receipt {purchaseId} granted in memory but not confirmed saved: NotProcessedYet (retried)`)
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Dev hook (DevService "receipt" command): runs the receipt path for a Content.Shop key without a Creator Hub product.
-- Server only, never reachable from the network; needs dev mode.
function ShopService:DevReceipt(player: Player, key: string, purchaseId: string): string
	if not self.Dependencies.PlaceService:IsDev() then
		error("[ShopService] DevReceipt needs dev mode")
	end
	local handler: Handler? = nil
	const pack = Content.Shop.GemPacks.ByKey[key]
	if pack then
		handler = self:GemPackHandler(pack)
	elseif Content.Shop.ClassProducts.ByKey[key] then
		handler = self:ClassHandler(key)
	end
	if handler == nil then
		error(`unknown shop key {key} (Content.Shop.GemPacks or ClassProducts)`, 0)
	end
	return tostring(self:Fulfil(player, handler, purchaseId, key))
end

ShopService:OnInit(function(self)
	self:Setup()
	self:RegisterContent()
end)

-- OnStart: every OnInit (other services' RegisterProduct) has run before the first receipt is accepted.
ShopService:OnStart(function(self)
	MarketplaceService.ProcessReceipt = function(receipt: Receipt): Enum.ProductPurchaseDecision
		const ok, decision = pcall(self.ProcessReceipt, self, receipt)
		if not ok then
			warn(`[ShopService] ProcessReceipt error: {decision}`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		return decision
	end
end)

return ShopService
