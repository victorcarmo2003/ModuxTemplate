--!strict
-- Gifts (TASK-352; owner request 2026-10-16, Provisional): a player buys a gem pack or a class for another player, and
-- admins gift them for free (AdminService giftclass / giftgems). Delivery is a ProfileStore message to the recipient's
-- profile (ProfileService:MessageAsync), so it reaches a player who is online here, in another server or offline.
--
-- Paid gift (Content.Shop.Gifts, one Developer Product per item; ProductId 0 = not created: refused, never prompted):
--   1. GiftPrompt { Key, Recipient } (c -> s, own rate limit): the recipient must not be the buyer and must have a
--      profile (played at least once). Saved as profile.GiftPending[Key] of the buyer (a receipt retried in another
--      server still knows the recipient). Answer GiftResult Ok, then the client prompts the product.
--   2. ShopService.ProcessReceipt (the single one) runs this product's handler: Grant.Send sends the message with
--      Id = PurchaseId; only when MessageAsync returned true is the receipt written and PurchaseGranted returned.
-- Delivery (ProfileService.Message, any server where the recipient's profile is loaded): each message Id is granted once
-- (profile.GiftsReceived, last GIFTS_KEPT), then processed() drops it from the profile on the same save.
--   Class   unlocked in profile.Classes (same path as ClassService / ShopService:GrantPass); already owned (or no longer
--           sold) = its gem Price instead, like CodesService
--   Gems    profile.Gems += Amount (GemsEarned is not touched: not earned)
-- The recipient gets GiftReceived (queued until the client is ready). Analytics: gift_sent / gift_received, gems as an
-- economy Source "Gift".
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Atomic = require(ReplicatedStorage.shared.Types.Atomic)
local Template = require(ServerScriptService.server.Profile.ProfileService.Template)
local Modux = require(ServerScriptService.server.Modux)
local MetricsLog = require(ServerScriptService.server.Metrics.MetricsService.Log)
local ShopTypes = require(ServerScriptService.server.ModuxTypes.ShopService)

type Profile = Atomic.Table<Template.Data>
type Grant = ShopTypes.Grant
type Handler = ShopTypes.Handler

export type Kind = Content.ShopGiftKind

-- What travels in the ProfileStore message (JSON: plain fields only)
export type Message = {
	Gift: true, -- marks a gift message (other message kinds may share the profile queue later)
	Id: string, -- PurchaseId of the receipt, or "admin:<guid>"
	Kind: Kind,
	Key: string, -- Class: class key. Gems: gem pack key, "" for an admin gift
	Amount: number, -- Gems: gems to credit. Class: 0
	From: number, -- UserId of the giver (0 = admin console without a player)
	FromName: string,
	At: number, -- os.time() when sent
}

export type Reason = "Ok" | "Sent" | "Self" | "NotFound" | "Unavailable" | "Rate" | "Busy" | "Failed"

const PROMPT_GAP = 1 -- s between two GiftPrompt of the same player (each one may cost a DataStore read)
const PENDING_TTL = 24 * 3600 -- s a GiftPending stays valid (a receipt older than that still goes to it: never dropped)
const GIFTS_KEPT = 50 -- circular list of delivered message ids (profile.GiftsReceived)
const GEMS_MAX = 2147483647 -- Profile.Gems wire range (network.md §4.5)
const NAME_MAX = 40 -- GiftReceived.FromName wire length

const GiftService = Modux.Service("GiftService", {
	Require = { "ShopService", "ProfileService", "NetService" },
	Priority = 450, -- below ShopService (790): RegisterProduct needs its Setup; above AdminService (50)
})

function GiftService:Setup()
	self.PromptAt = {} :: { [Player]: number }
	self.Busy = {} :: { [Player]: boolean }
	-- UserIds known to have a profile (only positive answers are cached)
	self.Known = {} :: { [number]: boolean }
	-- GiftReceived waiting for the client to be ready (delivered on join before the Ready handshake)
	self.Outbox = {} :: { [Player]: { any } }
end

function GiftService:Reply(player: Player, key: string, reason: Reason)
	const net = self.Dependencies.NetService
	if not net:IsRunning() or not net:IsReady(player) then
		return
	end
	self.Libs.Net.GiftResult:fireClient(player, {
		Ok = reason == "Ok" or reason == "Sent",
		Reason = reason,
		Key = key,
	})
end

function GiftService:Tell(player: Player, payload: any)
	const net = self.Dependencies.NetService
	if net:IsRunning() and net:IsReady(player) then
		self.Libs.Net.GiftReceived:fireClient(player, payload)
		return
	end
	const box = self.Outbox[player] or {}
	table.insert(box, payload)
	self.Outbox[player] = box
end

function GiftService:Flush(player: Player)
	const box = self.Outbox[player]
	if box == nil then
		return
	end
	self.Outbox[player] = nil
	for _, payload in box do
		self.Libs.Net.GiftReceived:fireClient(player, payload)
	end
end

-- Sending --------------------------------------------------------------------------------------------------------

-- Has this UserId played (a profile exists)? Yields on a cache miss; nil = the DataStore did not answer.
function GiftService:Exists(userId: number): boolean?
	if self.Known[userId] or Players:GetPlayerByUserId(userId) ~= nil then
		return true
	end
	const exists = self.Dependencies.ProfileService:ExistsAsync(userId)
	if exists then
		self.Known[userId] = true
	end
	return exists
end

-- Sends a gift message to a UserId (any server or offline). Yields. Every gift goes through here (paid and admin).
function GiftService:Send(recipient: number, message: Message): boolean
	const ok, sent = pcall(function()
		return self.Dependencies.ProfileService:MessageAsync(recipient, message :: any)
	end)
	if not ok then
		warn(`[GiftService] MessageAsync to {recipient} failed ({message.Id}): {sent}`)
		return false
	end
	if sent then
		const props = { kind = message.Kind, key = message.Key, to = recipient, id = message.Id }
		const giver = Players:GetPlayerByUserId(message.From)
		if giver then
			MetricsLog.player(giver, "gift_sent", message.Amount, props)
		else
			MetricsLog.server("gift_sent", message.Amount, props)
		end
	end
	return sent
end

-- Admin gift (AdminService): no receipt, a fresh id. Amount: gems (Kind Gems), ignored for a class. Yields.
function GiftService:SendFree(recipient: number, kind: Kind, key: string, amount: number, from: Player?): boolean
	return self:Send(recipient, {
		Gift = true,
		Id = `admin:{HttpService:GenerateGUID(false)}`,
		Kind = kind,
		Key = key,
		Amount = if kind == "Gems" then math.max(0, math.floor(amount)) else 0,
		From = if from then from.UserId else 0,
		FromName = if from then from.DisplayName else "Sell Hotdogs",
		At = os.time(),
	})
end

-- GiftPrompt: validates and stores the recipient of this buyer's next receipt of `key`. Yields (DataStore read).
function GiftService:Prompt(player: Player, key: string, recipient: number): Reason
	const gift = Content.Shop.Gifts.ByKey[key]
	if gift == nil or gift.ProductId <= 0 then
		return "Unavailable"
	end
	if recipient ~= recipient or recipient <= 0 or recipient % 1 ~= 0 then
		return "NotFound"
	end
	if recipient == player.UserId then
		return "Self"
	end
	const exists = self:Exists(recipient)
	if exists == nil then
		return "Busy"
	elseif not exists then
		return "NotFound"
	end
	const profiles = self.Dependencies.ProfileService
	const profile = profiles:Get(player)
	if profile == nil then
		return "Busy"
	end
	const pending = table.clone(profile.GiftPending())
	pending[key] = { Recipient = recipient, At = os.time() }
	profiles:Update(player, { GiftPending = pending })
	profiles:RequestSave(player)
	return "Ok"
end

-- Drops the pending recipient of `key` once its gift went out (a newer GiftPrompt to someone else is kept).
function GiftService:ClearPending(player: Player, key: string, recipient: number)
	const profiles = self.Dependencies.ProfileService
	const profile = profiles:Get(player)
	if profile == nil then
		return
	end
	const current = profile.GiftPending()[key]
	if current == nil or current.Recipient ~= recipient then
		return
	end
	const pending = table.clone(profile.GiftPending())
	pending[key] = nil
	profiles:Update(player, { GiftPending = pending })
end

-- Receipt handler of one gift product (ShopService.Fulfil): Send runs the message, Patch stays empty (only the receipt
-- id is written; the pending recipient is cleared by Send itself, after the yield).
function GiftService:Handler(gift: Content.ShopGift): Handler
	return function(player: Player, profile: Profile): Grant
		const pending = profile.GiftPending()[gift.Key]
		if pending == nil then
			warn(`[GiftService] receipt of {gift.Key} by {player.UserId} with no recipient: retried later`)
			return { Patch = {}, Wait = true }
		end
		if os.time() - pending.At > PENDING_TTL then
			warn(`[GiftService] {gift.Key} by {player.UserId}: recipient picked {os.time() - pending.At} s ago, sent anyway`)
		end
		const recipient = pending.Recipient
		local amount = 0
		if gift.Kind == "Gems" then
			const pack = Content.Shop.GemPacks.ByKey[gift.Target]
			amount = if pack then pack.Gems else 0
		end
		return {
			Patch = {},
			Send = function(purchaseId: string): boolean
				const sent = self:Send(recipient, {
					Gift = true,
					Id = purchaseId,
					Kind = gift.Kind,
					Key = gift.Target,
					Amount = amount,
					From = player.UserId,
					FromName = player.DisplayName,
					At = os.time(),
				})
				if player.Parent == Players then
					self:Reply(player, gift.Key, if sent then "Sent" else "Failed")
				end
				if sent then
					self:ClearPending(player, gift.Key, recipient)
				end
				return sent
			end,
		}
	end
end

-- Delivery -------------------------------------------------------------------------------------------------------

local function withId(list: { string }, id: string): { string }
	const out = table.clone(list)
	table.insert(out, id)
	while #out > GIFTS_KEPT do
		table.remove(out, 1)
	end
	return out
end

local function clean(message: { [string]: any }): Message?
	if message.Gift ~= true or type(message.Id) ~= "string" or message.Id == "" then
		return nil
	end
	if message.Kind ~= "Class" and message.Kind ~= "Gems" then
		return nil
	end
	const amount = tonumber(message.Amount) or 0
	return {
		Gift = true,
		Id = message.Id,
		Kind = message.Kind,
		Key = if type(message.Key) == "string" then message.Key else "",
		Amount = if amount == amount then math.clamp(math.floor(amount), 0, GEMS_MAX) else 0,
		From = tonumber(message.From) or 0,
		FromName = string.sub(if type(message.FromName) == "string" then message.FromName else "", 1, NAME_MAX),
		At = tonumber(message.At) or 0,
	}
end

-- ProfileService.Message: applies a gift once and marks it processed (dropped on the same save as the grant).
function GiftService:Receive(player: Player, raw: { [string]: any }, processed: () -> ())
	const message = clean(raw)
	if message == nil then
		if raw.Gift == true then
			warn(`[GiftService] malformed gift message for {player.UserId}: dropped`)
			processed()
		end
		return -- not a gift: another listener's message
	end
	const profiles = self.Dependencies.ProfileService
	const profile = profiles:Get(player)
	if profile == nil then
		return -- stays queued: next session
	end
	if table.find(profile.GiftsReceived(), message.Id) ~= nil then
		processed() -- already granted (a receipt retried after its message went out)
		return
	end

	local kind: Kind = message.Kind
	local key = message.Key
	local gems = 0
	local classes: { [string]: boolean }? = nil
	if message.Kind == "Class" then
		const class = Content.Classes.ByKey[key]
		if class == nil then
			warn(`[GiftService] gift {message.Id}: unknown class {key}: dropped`)
			processed()
			return
		end
		if profiles:OwnedClasses(profile)[key] or not class.InMvp then
			kind = "Gems"
			gems = class.Price -- already owned: its gem price instead (CodesService rule, data.md §1.7)
		else
			classes = profiles:WithClass(profile, key)
		end
	else
		gems = message.Amount
	end

	const balance = math.clamp(profile.Gems() + gems, 0, GEMS_MAX)
	const patch: { [string]: any } = { GiftsReceived = withId(profile.GiftsReceived(), message.Id) }
	if gems > 0 then
		patch.Gems = balance
	end
	if classes then
		patch.Classes = classes
	end
	profiles:Update(player, patch :: any)
	processed()
	profiles:RequestSave(player)

	MetricsLog.gems(player, "Source", gems, balance, "Gift", key)
	MetricsLog.player(player, "gift_received", if kind == "Gems" then gems else 0, {
		kind = message.Kind,
		key = key,
		from = message.From,
		converted = kind ~= message.Kind,
	})
	self:Tell(player, {
		Kind = kind,
		Key = string.sub(key, 1, 32),
		Amount = if kind == "Gems" then gems else 0,
		FromName = message.FromName,
	})
end

GiftService:OnInit(function(self)
	self:Setup()

	const shop = self.Dependencies.ShopService
	for _, gift in Content.Shop.Gifts.List do
		shop:RegisterProduct(gift.ProductId, gift.Key, self:Handler(gift))
	end

	self.Dependencies.ProfileService.Message:Connect(function(player, message, processed)
		self:Receive(player, message, processed)
	end)
	self.Dependencies.NetService.ClientReady:Connect(function(player)
		self:Flush(player)
	end)

	self.Libs.Net.GiftPrompt:onServer(function(data, player: Player)
		const key = data.Key
		const now = os.clock()
		if self.Busy[player] then
			return self:Reply(player, key, "Busy")
		end
		if now - (self.PromptAt[player] or -math.huge) < PROMPT_GAP then
			return self:Reply(player, key, "Rate")
		end
		self.PromptAt[player] = now
		self.Busy[player] = true
		task.spawn(function()
			const ok, reason = pcall(self.Prompt, self, player, key, data.Recipient)
			self.Busy[player] = nil
			if not ok then
				warn(`[GiftService] GiftPrompt failed for {player.UserId}: {reason}`)
			end
			if player.Parent == Players then
				self:Reply(player, key, if ok then reason else "Busy")
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.PromptAt[player] = nil
		self.Busy[player] = nil
		self.Outbox[player] = nil
	end)
end)

return GiftService
