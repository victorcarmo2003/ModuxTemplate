--!strict
-- Robux shop: the single MarketplaceService.ProcessReceipt of the place, Lobby and Run (TASK-160; user request
-- 2026-10-11, Provisional; architecture.md §10.1, data.md §1.4 and §1.7, network.md §15). It plays the
-- MonetizationService role of architecture.md §10.1 (same priority, 790) under the feature name Shop.
-- Products: gem packs from Content.Shop (ProductId 0 = not created yet: never registered); other services add theirs
-- with RegisterProduct in their OnInit (ShopUtilityService, TASK-290).
-- Game Passes (TASK-291; owner request 2026-10-14, Provisional): one per class (Content.Shop.GamePasses, PassId 0 = not
-- created). The class is written to profile.Classes when the pass is bought here (PromptGamePassPurchaseFinished) and on
-- each join for a pass owner (UserOwnsGamePassAsync in pcall, cached per player; a failed check retries on the next
-- join). A class already in the profile is never written again. Once written it stays (profile.Classes is the one
-- ownership list, data.md §1.7).
-- One-time bundles (DEC-267; Content.Shop.Bundles, e.g. the Starter Crate): Gems + ReviveCredits and a stamp in
-- profile.OneTimeBought (the lobby hides the offer once stamped; a second receipt still grants, Robux were paid).
-- Other Game Passes (Content.Shop.Passes, e.g. the Thermos): owned through OwnsPass; a purchase in this server marks
-- the cache (OnPassFinished) so its owner service (ShopUtilityService) sees it at once.
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
local MetricsLog = require(ServerScriptService.server.Metrics.MetricsService.Log)

-- Same type as ProfileService.Profile (one atom per Template field)
type Profile = Atomic.Table<Template.Data>

export type Patch = Struct.Partial<Template.Data>

-- What a product gives. Patch is applied with the PurchaseId in one batch (it must not touch Receipts); After runs
-- once, right after the grant (feedback, or the run-state effect of a utility, TASK-290). No yield inside a Handler.
-- Wait = true: the product cannot be granted in this server now (a run utility bought in the lobby): nothing is written
-- and the receipt stays NotProcessedYet, so Roblox delivers it again in a later server.
-- Send (TASK-352, gifts): a yielding step that must succeed BEFORE the grant is written (the ProfileStore message of a
-- gift). false or an error = NotProcessedYet, nothing written; Roblox retries and Send runs again, so what it sends must
-- be idempotent on the other side (gift messages carry the PurchaseId, GiftService grants each id once).
export type Grant = {
	Patch: Patch,
	After: (() -> ())?,
	Wait: boolean?,
	Send: ((purchaseId: string) -> boolean)?,
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
const PASS_RETRY = 2 -- UserOwnsGamePassAsync attempts per pass on join
const REVIVE_MAX = 99 -- same cap as ShopUtilityService

const ShopService = Modux.Service(
	"ShopService",
	{ Require = { "ProfileService", "NetService", "PlaceService" }, Priority = 790 }
)

function ShopService:Setup()
	self.Handlers = {} :: { [number]: Handler }
	-- ProductId -> key, for logs
	self.Names = {} :: { [number]: string }
	-- key -> handler of every registered product, ProductId 0 included (DevReceipt)
	self.ByKey = {} :: { [string]: Handler }
	-- player -> PassId -> owns (only answers that came back; a failed call is not cached)
	self.Passes = {} :: { [Player]: { [number]: boolean } }
	-- PurchaseIds whose Grant.Send is running (a concurrent ProcessReceipt of the same id waits for Roblox's retry)
	self.Sending = {} :: { [string]: boolean }
end

-- Registers a Developer Product. Call in OnInit (receipts start in OnStart). A ProductId of 0 or less is a product not
-- created on the Creator Hub yet: skipped with no error (Content.Shop placeholders).
function ShopService:RegisterProduct(productId: number, name: string, handler: Handler)
	self.ByKey[name] = handler
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

function ShopService:ReplyClass(player: Player, key: string, reason: "Granted")
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
				MetricsLog.gems(player, "Source", pack.Gems, profile.Gems(), "GemPack", pack.Key)
				MetricsLog.panel(player, "shop", 3, "bought", { pack = pack.Key })
			end,
		}
	end
end

-- One-time bundle (DEC-267): Gems += Gems, ReviveCredits += Revives, OneTimeBought[Key] = now.
function ShopService:BundleHandler(bundle: Content.ShopBundle): Handler
	return function(player: Player, profile: Profile): Grant
		const bought = table.clone(profile.OneTimeBought())
		bought[bundle.Key] = os.time()
		return {
			Patch = {
				Gems = math.clamp(profile.Gems() + bundle.Gems, 0, GEMS_MAX),
				ReviveCredits = math.clamp(profile.ReviveCredits() + bundle.Revives, 0, REVIVE_MAX),
				OneTimeBought = bought,
			},
			After = function()
				if bundle.Gems > 0 then
					self:Notify(player, "gems_gained", bundle.Gems)
					MetricsLog.gems(player, "Source", bundle.Gems, profile.Gems(), "Bundle", bundle.Key)
				end
			end,
		}
	end
end

-- Game Passes -----------------------------------------------------------------------------------------------------

-- Owns the pass? Cached per player; nil = Roblox did not answer (try again later).
function ShopService:OwnsPass(player: Player, passId: number): boolean?
	if passId <= 0 then
		return false
	end
	const cache = self.Passes[player] or {}
	self.Passes[player] = cache
	if cache[passId] ~= nil then
		return cache[passId]
	end
	for _ = 1, PASS_RETRY do
		const ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		if ok then
			cache[passId] = owns == true
			return cache[passId]
		end
		task.wait(1)
	end
	return nil
end

-- The player owns the Game Pass of this class (cached answer only: never yields). ClassService pre-check.
function ShopService:OwnsClassPass(player: Player, key: string): boolean
	const pass = Content.Shop.GamePasses.ByKey[key]
	const cache = self.Passes[player]
	return pass ~= nil and cache ~= nil and cache[pass.PassId] == true
end

-- Writes the class of a pass to the profile once. notify = the purchase just happened (ClassBuyResult + Notice).
function ShopService:GrantPass(player: Player, key: string, notify: boolean): boolean
	const profiles = self.Dependencies.ProfileService
	const profile = profiles:Get(player)
	const class = Content.Classes.ByKey[key]
	if not profile or not class or not class.InMvp then
		return false
	end
	if not profiles:OwnedClasses(profile)[key] then
		profiles:Update(player, { Classes = profiles:WithClass(profile, key) })
		profiles:RequestSave(player)
	end
	if notify then
		MetricsLog.panel(player, "classes", 3, "buy", { class = key, currency = "robux" })
		self:ReplyClass(player, key, "Granted")
		self:Notify(player, "class_bought", Content.Classes.IndexOf[key])
	end
	return true
end

-- On join: every created pass this player owns unlocks its class (yields; runs in its own thread).
function ShopService:CheckPasses(player: Player)
	for _, pass in Content.Shop.GamePasses.List do
		if pass.PassId <= 0 or player.Parent ~= Players then
			continue
		end
		if self:OwnsPass(player, pass.PassId) then
			self:GrantPass(player, pass.Key, false)
		end
	end
end

function ShopService:OnPassFinished(player: Player, passId: number, purchased: boolean)
	if not purchased or passId <= 0 then
		return
	end
	for _, pass in Content.Shop.Passes.List do
		if pass.PassId == passId then
			const cache = self.Passes[player] or {}
			cache[passId] = true
			self.Passes[player] = cache
			return
		end
	end
	for _, pass in Content.Shop.GamePasses.List do
		if pass.PassId == passId then
			const cache = self.Passes[player] or {}
			cache[passId] = true
			self.Passes[player] = cache
			self:GrantPass(player, pass.Key, true)
			return
		end
	end
end

function ShopService:RegisterContent()
	for _, pack in Content.Shop.GemPacks.List do
		self:RegisterProduct(pack.ProductId, pack.Key, self:GemPackHandler(pack))
	end
	for _, bundle in Content.Shop.Bundles.List do
		self:RegisterProduct(bundle.ProductId, bundle.Key, self:BundleHandler(bundle))
	end
	for _, pass in Content.Shop.GamePasses.List do
		const class = Content.Classes.ByKey[pass.Key]
		if not class or not class.InMvp then
			warn(`[ShopService] Content.Shop.GamePasses.{pass.Key} is not an MVP class: not sold`)
		end
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
	-- (Grant.Send is the one exception: it yields, then the id and the profile are checked again before the write)
	if table.find(profile.Receipts(), purchaseId) == nil then
		const ok, grant = pcall(handler, player, profile)
		if not ok then
			warn(`[ShopService] handler {name} failed for {purchaseId}: {grant}`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if grant.Wait then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if grant.Send then
			if self.Sending[purchaseId] then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			self.Sending[purchaseId] = true
			const sentOk, sent = pcall(grant.Send, purchaseId)
			self.Sending[purchaseId] = nil
			if not sentOk or sent ~= true then
				if not sentOk then
					warn(`[ShopService] send of {name} failed for {purchaseId}: {sent}`)
				end
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			-- Send yielded: the profile may be gone (left; Roblox retries, Send is idempotent) or the id written meanwhile.
			-- The Patch was computed before the yield, so a Grant with Send keeps it to fields nobody else writes.
			if profiles:Get(player) ~= profile then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
		end
		if table.find(profile.Receipts(), purchaseId) == nil then
			const patch = table.clone(grant.Patch) :: { [string]: any }
			patch.Receipts = withReceipt(profile.Receipts(), purchaseId)
			profiles:Update(player, patch :: any)
			after = grant.After
		end
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
-- A class key runs the Game Pass grant instead (no receipt). Server only, never reachable from the network; dev mode.
function ShopService:DevReceipt(player: Player, key: string, purchaseId: string): string
	if not self.Dependencies.PlaceService:IsDev() then
		error("[ShopService] DevReceipt needs dev mode")
	end
	if Content.Shop.GamePasses.ByKey[key] then
		return if self:GrantPass(player, key, true) then "PassGranted" else "PassRefused"
	end
	local handler: Handler? = nil
	const pack = Content.Shop.GemPacks.ByKey[key]
	if pack then
		handler = self:GemPackHandler(pack)
	else
		handler = self.ByKey[key] -- products other services registered (Content.Shop.Utilities, TASK-290)
	end
	if handler == nil then
		error(`unknown shop key {key} (Content.Shop.GemPacks, GamePasses or Utilities)`, 0)
	end
	return tostring(self:Fulfil(player, handler, purchaseId, key))
end

ShopService:OnInit(function(self)
	self:Setup()
	self:RegisterContent()

	self.Dependencies.ProfileService.Loaded:Connect(function(player)
		task.spawn(function()
			self:CheckPasses(player)
		end)
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		self:OnPassFinished(player, passId, purchased)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self.Passes[player] = nil
	end)
end)

-- OnStart: every OnInit (other services' RegisterProduct) has run before the first receipt is accepted.
ShopService:OnStart(function(self)
	MarketplaceService.ProcessReceipt = function(receipt: Receipt): Enum.ProductPurchaseDecision
		const ok, decision = pcall(self.ProcessReceipt, self, receipt)
		if not ok then
			warn(`[ShopService] ProcessReceipt error: {decision}`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if decision == Enum.ProductPurchaseDecision.PurchaseGranted then
			MetricsLog.receipt(receipt :: any) -- RoMetrics sale (once per PurchaseId, price = CurrencySpent)
		end
		return decision
	end
end)

return ShopService
