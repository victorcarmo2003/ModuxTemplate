--!strict
--[[
	OfferController (TASK-362; owner request 2026-10-17, Provisional; design/monetization-offers-proposal.md, Q-293..Q-299)

	Contextual shop offers: at the moment the game needs it, a short clickable note in the HUD nudge slot (top right,
	under the cart; ShopController:Offer) offers a utility of Content.Shop.Utilities. It NEVER opens the Roblox prompt by
	itself: only the player's click does (ShopController:PromptOffer), or, for the ShopShare half of the players
	(A/B of Q-293), the click opens the shop with that card flashing (ShopController:ShowCard).

	Triggers (Content.Shop.Offers, one row each; read here from what already replicates, nothing new on the server but
	the Cash ShopOffer):
	  Sanity       Night phase, sanity <= SanityShare of max, no coffee Tool in the hand or the backpack
	  OutOfStock   an open ingredient (not Blocked / Wrapped, it had stock before) is at 0 while selling; target = it
	  LowStock     OutCount+ open ingredients at 0, or LowStockCount+ under LowStockShare; replaces OutOfStock
	  Cash         ShopOffer from EconomyService (not enough Cash for a buy); shown within CASH_FRESH s or dropped
	  MateDown     a mate is Down while I am Active and have no Revive Kit (one offer per fall)
	  NightRetry   Attempt > 1 on a night (the night repeated after a NightLost), once the night is calm
	  AnomalyMiss  MissCount+ anomalies Failed in this night, once they are over
	  ScareBack    a mate scared me (ShopGrant util_scare Value 1), ScareBackDelay s later, that mate still here
	  NightStart   a night from OfferRules.KitNight on, once it is calm (Night Kit; DEC-267)
	Budget and fatigue (Content.Shop.OfferRules): one note at a time, Gap s between two offers (the scare nudge counts,
	through ShopController.NudgeGate / NudgeShown), PerShift per shift, per-offer PerShift and Cooldown, an offer ignored
	MuteAfter times in a row is muted for the run, PauseAfter ignored offers in a row pause them all for Pause s,
	AfterPrompt s quiet after any purchase prompt closed.
	Never: Settings "Shop tips" off (Prefs.ShopTips), the control group (ControlShare of the players by UserId, fixed;
	0 since DEC-268: everyone sees the offers; never in the Studio dev place), Day / Night under FirstDay (tutorial,
	free coffee lesson),
	a live anomaly (Signal / Active) or less than Calm s after one, the prep mode, cutscenes, cinematics, the shop or the
	settings open (ShopController:CanOffer), the local player not Active, a product not created yet (ProductId 0).
	Metrics (MetricUi): offer_shown / offer_click / offer_expired / offer_muted with Key = product and Offer = offer key;
	offers_off / offers_on when the setting changes.
	Dev (Studio dev place): `/dev offer <key | list | status | reset>` (DevClient "offer"): forces an offer (budget off),
	lists the keys, prints the state, clears every counter.
	Game servers only (the lobby has its own shop).
]]
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local ShopContent = require(ReplicatedStorage.shared.Content.Shop)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Prefs = require(StarterPlayer.StarterPlayerScripts.client.Settings.Prefs)

type Offer = ShopContent.Offer
type Utility = ShopContent.Utility

-- A due offer: the row, its target (ingredient index / mate UserId) and the words that fill its text
type Due = {
	Offer: Offer,
	Target: number?,
	Fill: { [string]: string },
	Memo: string?, -- per-target memory key ("restock:bun", "mate:123:45.2"): shown once
}

type PendingCash = { Product: string, Missing: number, At: number }
type PendingScare = { From: number, At: number }

const TICK = 0.5 -- s between two checks
const CASH_FRESH = 8 -- s a Cash ShopOffer stays valid (the player just tried to buy)
const SELLING: { [string]: boolean } = { Open = true, Closing = true, Night = true }
const MATE_PHASES: { [string]: boolean } = { Call = true, Prep = true, Night = true }
const LIVE: { [string]: boolean } = { Signal = true, Active = true }
const COFFEE_ITEM = "coffee"
const SCARE_KEY = "util_scare"
const DEV_COMMAND = "offer"

const OfferController = Modux.Controller("OfferController", {
	Require = {
		"PlaceController",
		"ShopController",
		"RoundController",
		"VitalController",
		"KitchenController",
		"ReviveKitController",
	},
	Priority = 530,
})

function OfferController:Setup()
	self.Enabled = false :: boolean
	const rules = Content.Shop.OfferRules
	const userId = math.abs(Players.LocalPlayer.UserId)
	-- fixed buckets by UserId (two different spreads so the groups do not overlap by construction)
	self.Control = (((userId * 7919) % 1000) / 1000 < rules.ControlShare) :: boolean
	self.ShopClick = (((userId * 104729 + 17) % 1000) / 1000 < rules.ShopShare) :: boolean
	-- os.clock() of the last offer / scare nudge on the note; of the last purchase prompt closed; pause end
	self.LastAt = (-math.huge) :: number
	self.PromptAt = (-math.huge) :: number
	self.PausedUntil = 0 :: number
	-- os.clock() of the last live anomaly seen
	self.LiveAt = (-math.huge) :: number
	-- shift key -> offers shown in it (all / per offer)
	self.Shift = "" :: string
	self.ShiftCount = 0 :: number
	self.OfferCount = {} :: { [string]: number }
	self.OfferAt = {} :: { [string]: number }
	-- fatigue: ignored in a row per offer and overall; muted offers (rest of the run)
	self.Ignored = {} :: { [string]: number }
	self.IgnoredRow = 0 :: number
	self.Muted = {} :: { [string]: boolean }
	-- per-target memory (shown once): ingredient this shift, a mate's fall, a night retry
	self.Memo = {} :: { [string]: boolean }
	-- ingredients that had stock at some point (an empty bowl that never had any is not "ran out")
	self.HadStock = {} :: { [string]: boolean }
	-- anomaly records failed in this shift
	self.Failed = {} :: { [number]: boolean }
	self.Pending = nil :: PendingCash?
	self.Scare = nil :: PendingScare?
	-- the offer on the note now (to tell click from expiry)
	self.Showing = nil :: { Key: string, Token: number, Clicked: boolean }?
	self.Tips = true :: boolean
end

-- Helpers --------------------------------------------------------------------------------------------------------------

function OfferController:Metric(event: string, offer: Offer?)
	const product = if offer ~= nil and offer.Product ~= "" then offer.Product else nil
	self.Libs.Net.MetricUi:fireServer({
		Event = event :: any,
		Key = product :: any,
		Offer = if offer ~= nil then offer.Key :: any else nil,
	})
end

function OfferController:ShiftKey(): string
	const round = self.Dependencies.RoundController
	return `{Vide.untrack(round.Day)}:{Vide.untrack(round.Night)}:{Vide.untrack(round.IsNight)}:{Vide.untrack(
		round.Attempt
	)}`
end

-- New shift (day or night, or a night attempt): per-shift counters and memories start over.
function OfferController:StepShift()
	const key = self:ShiftKey()
	if key == self.Shift then
		return
	end
	self.Shift = key
	self.ShiftCount = 0
	self.OfferCount = {}
	self.Failed = {}
	for memo in self.Memo do
		if string.sub(memo, 1, 8) == "restock:" then
			self.Memo[memo] = nil
		end
	end
end

-- Day 1 and Night 1 are the tutorial and the free coffee lesson.
function OfferController:PastTutorial(): boolean
	const round = self.Dependencies.RoundController
	const first = Content.Shop.OfferRules.FirstDay
	if Vide.untrack(round.IsNight) then
		return Vide.untrack(round.Night) >= first
	end
	return Vide.untrack(round.Day) >= first
end

-- No live anomaly now and none for Calm s (anomaly records of ShopController, the same Anomalies set).
function OfferController:Calm(now: number): boolean
	const records = self.Dependencies.ShopController.Records :: { [number]: { Phase: string } }
	for id, record in records do
		if LIVE[record.Phase] then
			self.LiveAt = now
		elseif record.Phase == "Failed" then
			self.Failed[id] = true
		end
	end
	return now - self.LiveAt >= Content.Shop.OfferRules.Calm
end

function OfferController:HasCoffee(): boolean
	const player = Players.LocalPlayer
	for _, holder in { player.Character, player:FindFirstChildOfClass("Backpack") } do
		if holder == nil then
			continue
		end
		for _, child in (holder :: Instance):GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("Item") == COFFEE_ITEM then
				return true
			end
		end
	end
	return false
end

-- Price text of a product ("R$ 25"): the real Creator Hub price when ShopController loaded it.
function OfferController:Price(utility: Utility): string
	return self.Dependencies.ShopController:PriceOf(utility)
end

local function fill(text: string, words: { [string]: string }): string
	return (string.gsub(text, "{(%a+)}", function(name: string): string
		return words[name] or `\{{name}\}`
	end))
end

-- Budget ---------------------------------------------------------------------------------------------------------------

-- Global budget only (gap, per shift, pause, after a prompt). The scare nudge goes through it too.
function OfferController:Budget(now: number): boolean
	const rules = Content.Shop.OfferRules
	return now - self.LastAt >= rules.Gap
		and self.ShiftCount < rules.PerShift
		and now >= self.PausedUntil
		and now - self.PromptAt >= rules.AfterPrompt
end

-- May this offer show now (its own limits; not the global budget)
function OfferController:Allowed(offer: Offer, now: number): boolean
	if not offer.Enabled or self.Muted[offer.Key] then
		return false
	end
	if (self.OfferCount[offer.Key] or 0) >= offer.PerShift then
		return false
	end
	if now - (self.OfferAt[offer.Key] or -math.huge) < offer.Cooldown then
		return false
	end
	if offer.Product ~= "" then
		const utility = Content.Shop.Utilities.ByKey[offer.Product]
		if utility == nil or utility.ProductId <= 0 then
			return false
		end
	end
	return true
end

-- Triggers -------------------------------------------------------------------------------------------------------------

function OfferController:StockDue(due: { Due })
	const round = self.Dependencies.RoundController
	if not SELLING[Vide.untrack(round.Phase)] then
		return
	end
	const rules = Content.Shop.OfferRules
	const kitchen = self.Dependencies.KitchenController
	local empty: { number } = {}
	local low = 0
	for index, ingredient in Content.Ingredients.List do
		const record = kitchen:StockOf(ingredient.Key)
		if record == nil or record.Blocked or record.Wrapped == true or record.Capacity <= 0 then
			continue
		end
		if record.Amount > 0 then
			self.HadStock[ingredient.Key] = true
		end
		if record.Amount <= 0 and self.HadStock[ingredient.Key] then
			table.insert(empty, index)
		end
		if record.Amount < record.Capacity * rules.LowStockShare then
			low += 1
		end
	end
	if #empty >= rules.OutCount or low >= rules.LowStockCount then
		for _, offer in Content.Shop.Offers.List do
			if offer.Trigger == "LowStock" then
				table.insert(due, { Offer = offer, Fill = {} })
			end
		end
		return
	end
	for _, index in empty do
		const ingredient = Content.Ingredients.List[index]
		const memo = `restock:{ingredient.Key}`
		if self.Memo[memo] then
			continue
		end
		for _, offer in Content.Shop.Offers.List do
			if offer.Trigger == "OutOfStock" then
				table.insert(due, {
					Offer = offer,
					Target = index,
					Fill = { ingredient = ingredient.Name },
					Memo = memo,
				})
			end
		end
		return
	end
end

function OfferController:SanityDue(due: { Due })
	const round = self.Dependencies.RoundController
	const vital = self.Dependencies.VitalController
	const max = Vide.untrack(vital.Max)
	const value = Vide.untrack(vital.Sanity)
	if Vide.untrack(round.Phase) ~= "Night" or max <= 0 or value <= 0 then
		return
	end
	if value > max * Content.Shop.OfferRules.SanityShare or self:HasCoffee() then
		return
	end
	for _, offer in Content.Shop.Offers.List do
		if offer.Trigger == "Sanity" then
			table.insert(due, { Offer = offer, Fill = {} })
		end
	end
end

function OfferController:MateDue(due: { Due })
	const round = self.Dependencies.RoundController
	if not MATE_PHASES[Vide.untrack(round.Phase)] or not Vide.untrack(round.IsNight) then
		return
	end
	if Vide.untrack(self.Dependencies.ReviveKitController.Count) > 0 then
		return
	end
	const me = Players.LocalPlayer.UserId
	for userId, member in Vide.untrack(self.Dependencies.VitalController.Members) do
		if userId == me or member.State ~= "Down" then
			continue
		end
		const player = Players:GetPlayerByUserId(userId)
		if player == nil then
			continue
		end
		const memo = `mate:{userId}:{member.StateEndsAt}`
		if self.Memo[memo] then
			continue
		end
		for _, offer in Content.Shop.Offers.List do
			if offer.Trigger == "MateDown" then
				table.insert(due, { Offer = offer, Fill = { name = player.DisplayName }, Memo = memo })
			end
		end
		return
	end
end

function OfferController:NightDue(due: { Due })
	const round = self.Dependencies.RoundController
	if Vide.untrack(round.Phase) ~= "Night" then
		return
	end
	const night = Vide.untrack(round.Night)
	const attempt = Vide.untrack(round.Attempt)
	if night >= Content.Shop.OfferRules.KitNight then
		const kitMemo = `kit:{night}:{attempt}`
		if not self.Memo[kitMemo] then
			for _, offer in Content.Shop.Offers.List do
				if offer.Trigger == "NightStart" then
					table.insert(due, { Offer = offer, Fill = {}, Memo = kitMemo })
				end
			end
		end
	end
	if attempt > 1 then
		const memo = `retry:{night}:{attempt}`
		if not self.Memo[memo] then
			for _, offer in Content.Shop.Offers.List do
				if offer.Trigger == "NightRetry" then
					table.insert(due, { Offer = offer, Fill = {}, Memo = memo })
				end
			end
		end
	end
	local failed = 0
	for _ in self.Failed do
		failed += 1
	end
	if failed >= Content.Shop.OfferRules.MissCount then
		for _, offer in Content.Shop.Offers.List do
			if offer.Trigger == "AnomalyMiss" then
				table.insert(due, { Offer = offer, Fill = {} })
			end
		end
	end
end

function OfferController:CashDue(due: { Due }, now: number)
	const pending = self.Pending
	if pending == nil then
		return
	end
	if now - pending.At > CASH_FRESH then
		self.Pending = nil
		return
	end
	const utility = Content.Shop.Utilities.ByKey[pending.Product]
	if utility == nil then
		self.Pending = nil
		return
	end
	for _, offer in Content.Shop.Offers.List do
		if offer.Trigger == "Cash" then
			table.insert(due, {
				Offer = offer,
				Fill = { missing = tostring(pending.Missing), amount = tostring(utility.Amount), product = utility.Name },
			})
		end
	end
end

function OfferController:ScareDue(due: { Due }, now: number)
	const pending = self.Scare
	if pending == nil or now < pending.At then
		return
	end
	const player = Players:GetPlayerByUserId(pending.From)
	if player == nil then
		self.Scare = nil
		return
	end
	for _, offer in Content.Shop.Offers.List do
		if offer.Trigger == "ScareBack" then
			table.insert(due, { Offer = offer, Target = pending.From, Fill = { name = player.DisplayName } })
		end
	end
end

-- Show -----------------------------------------------------------------------------------------------------------------

-- Product an offer buys: its own, or the Cash pack the server picked.
function OfferController:ProductOf(entry: Due): string
	if entry.Offer.Product ~= "" then
		return entry.Offer.Product
	end
	const pending = self.Pending
	return if pending ~= nil then pending.Product else ""
end

function OfferController:Show(entry: Due, forced: boolean?)
	const offer = entry.Offer
	const productKey = self:ProductOf(entry)
	const utility = Content.Shop.Utilities.ByKey[productKey]
	if utility == nil then
		return
	end
	const shop = self.Dependencies.ShopController
	const words = table.clone(entry.Fill)
	words.price = self:Price(utility)
	const text = fill(offer.Text, words)
	const now = os.clock()
	if not forced then
		self.LastAt = now
		self.ShiftCount += 1
		self.OfferCount[offer.Key] = (self.OfferCount[offer.Key] or 0) + 1
		self.OfferAt[offer.Key] = now
	end
	if entry.Memo ~= nil then
		self.Memo[entry.Memo] = true
	end
	if offer.Trigger == "Cash" then
		self.Pending = nil
	elseif offer.Trigger == "ScareBack" then
		self.Scare = nil
	end
	const metricOffer: Offer = if offer.Product == "" then table.clone(offer) else offer
	if offer.Product == "" then
		metricOffer.Product = productKey
	end
	const target = entry.Target
	local showing: { Key: string, Token: number, Clicked: boolean }? = nil
	const token = shop:Offer(text, utility.Icon, Content.Shop.OfferRules.Show, function()
		if showing ~= nil then
			showing.Clicked = true
		end
		self.Ignored[offer.Key] = 0
		self.IgnoredRow = 0
		self:Metric("offer_click", metricOffer)
		if self.ShopClick then
			shop:ShowCard(productKey)
		else
			shop:PromptOffer(productKey, target)
		end
	end)
	showing = { Key = offer.Key, Token = token, Clicked = false }
	self.Showing = showing
	self:Metric("offer_shown", metricOffer)
	task.delay(Content.Shop.OfferRules.Show + 0.2, function()
		if showing == nil or showing.Clicked or self.Showing ~= showing then
			return
		end
		self.Showing = nil
		-- replaced by another note before its time is not an expiry the player chose
		if shop:NoteToken() ~= showing.Token then
			return
		end
		self:Ignore(offer, metricOffer)
	end)
end

-- The offer expired without a click.
function OfferController:Ignore(offer: Offer, metricOffer: Offer)
	const rules = Content.Shop.OfferRules
	self:Metric("offer_expired", metricOffer)
	self.Ignored[offer.Key] = (self.Ignored[offer.Key] or 0) + 1
	self.IgnoredRow += 1
	if self.Ignored[offer.Key] >= rules.MuteAfter and not self.Muted[offer.Key] then
		self.Muted[offer.Key] = true
		self:Metric("offer_muted", metricOffer)
	end
	if self.IgnoredRow >= rules.PauseAfter then
		self.IgnoredRow = 0
		self.PausedUntil = os.clock() + rules.Pause
	end
end

-- Tick -----------------------------------------------------------------------------------------------------------------

-- Everything that blocks every offer.
function OfferController:Blocked(): boolean
	if not self.Tips or self.Control then
		return true
	end
	if Vide.untrack(self.Dependencies.VitalController.LocalState) ~= "Active" then
		return true
	end
	if Vide.untrack(self.Dependencies.RoundController.Paused) then
		return true
	end
	return not self:PastTutorial() or not self.Dependencies.ShopController:CanOffer()
end

function OfferController:Step()
	const now = os.clock()
	self:StepShift()
	const calm = self:Calm(now)
	if self:Blocked() or not calm or not self:Budget(now) then
		return
	end
	const due: { Due } = {}
	self:MateDue(due)
	self:SanityDue(due)
	self:StockDue(due)
	self:CashDue(due, now)
	self:NightDue(due)
	self:ScareDue(due, now)
	local best: Due? = nil
	for _, entry in due do
		if not self:Allowed(entry.Offer, now) then
			continue
		end
		if best == nil or entry.Offer.Priority > best.Offer.Priority then
			best = entry
		end
	end
	if best ~= nil then
		self:Show(best)
	end
end

-- Dev ------------------------------------------------------------------------------------------------------------------

function OfferController:Reset()
	self.LastAt = -math.huge
	self.PromptAt = -math.huge
	self.PausedUntil = 0
	self.ShiftCount = 0
	self.OfferCount = {}
	self.OfferAt = {}
	self.Ignored = {}
	self.IgnoredRow = 0
	self.Muted = {}
	self.Memo = {}
	self.Failed = {}
end

function OfferController:Status(): string
	const now = os.clock()
	const muted: { string } = {}
	for key in self.Muted do
		table.insert(muted, key)
	end
	return table.concat({
		`control={self.Control} shopClick={self.ShopClick} tips={self.Tips} blocked={self:Blocked()}`,
		`tutorialPast={self:PastTutorial()} calm={self:Calm(now)} budget={self:Budget(now)} canOffer={self.Dependencies.ShopController:CanOffer()}`,
		`shift={self.Shift} shown={self.ShiftCount}/{Content.Shop.OfferRules.PerShift} gap={math.floor(now - self.LastAt)}s`,
		`ignoredRow={self.IgnoredRow} paused={math.max(0, math.floor(self.PausedUntil - now))}s muted={table.concat(muted, ",")}`,
	}, "\n")
end

-- `/dev offer <key | list | status | reset>`: a key forces that offer now (budget off; a sample target / words).
function OfferController:Dev(text: string)
	const word = string.lower(string.match(text, "%S+") or "status")
	if word == "list" then
		print(`[OfferController] offers: {table.concat(Content.Shop.Offers.Keys, ", ")}`)
		return
	elseif word == "reset" then
		self:Reset()
		print("[OfferController] counters cleared")
		return
	elseif word == "status" then
		print(`[OfferController]\n{self:Status()}`)
		return
	end
	const offer = Content.Shop.Offers.ByKey[word]
	if offer == nil then
		warn(`[OfferController] /dev offer: unknown '{word}' (try 'list')`)
		return
	end
	const entry: Due = { Offer = offer, Fill = { name = Players.LocalPlayer.DisplayName } }
	if offer.Trigger == "OutOfStock" then
		entry.Target = 1
		entry.Fill.ingredient = Content.Ingredients.List[1].Name
	elseif offer.Trigger == "Cash" then
		self.Pending = { Product = "cash_100", Missing = 40, At = os.clock() }
		entry.Fill.missing = "40"
		entry.Fill.amount = tostring(Content.Shop.Utilities.ByKey.cash_100.Amount)
		entry.Fill.product = Content.Shop.Utilities.ByKey.cash_100.Name
	elseif offer.Trigger == "ScareBack" then
		entry.Target = Players.LocalPlayer.UserId
	end
	self:Show(entry, true)
	print(`[OfferController] forced {offer.Key}`)
end

-- Lifecycle ------------------------------------------------------------------------------------------------------------

OfferController:OnInit(function(self)
	self:Setup()
	const net = self.Libs.Net

	net.ShopOffer:onClient(function(data)
		self.Pending = { Product = data.Product, Missing = data.Value, At = os.clock() }
	end)
	-- a mate scared me: offer the scare back a moment later
	net.ShopGrant:onClient(function(data)
		if data.Product == SCARE_KEY and data.Value == 1 and data.From ~= 0 then
			self.Scare = { From = data.From, At = os.clock() + Content.Shop.OfferRules.ScareBackDelay }
		end
	end)
	net.DevClient:onClient(function(data)
		if data.Command == DEV_COMMAND and self.Dependencies.PlaceController:IsDev() then
			self:Dev(data.Text)
		end
	end)
end)

OfferController:OnStart(function(self)
	if self.Dependencies.PlaceController:Is("Lobby") then
		return
	end
	self.Enabled = true
	-- the Studio dev place is never the control group (testers must see the offers; `/dev offer status` shows it)
	if self.Dependencies.PlaceController:IsDev() then
		self.Control = false
	end
	const shop = self.Dependencies.ShopController
	-- the scare nudge joins the budget (the control group keeps it as it was)
	if not self.Control then
		shop.NudgeGate = function(): boolean
			return self.Tips and self:Budget(os.clock())
		end
		shop.NudgeShown = function()
			self.LastAt = os.clock()
			self.ShiftCount += 1
		end
	end
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number)
		if userId == Players.LocalPlayer.UserId then
			self.PromptAt = os.clock()
		end
	end)
	-- the Shop tips setting: on / off live, reported once per change
	Vide.root(function()
		Vide.effect(function()
			const on = Prefs.ShopTips()
			Vide.untrack(function()
				if on ~= self.Tips then
					self.Tips = on
					self:Metric(if on then "offers_on" else "offers_off")
				end
				return nil
			end)
		end)
		return nil
	end)
end)

OfferController:OnTick(function(self)
	if not self.Enabled then
		return
	end
	self:Step()
end, TICK)

return OfferController
