--!strict
-- Class skins, client side (owner request 2026-10-17, Provisional; design/skins-proposal.md). Lobby and Run.
--   Owned / Equipped   SkinState from SkinService (Ready after the first one)
--   Prices             live Creator Hub price per skin (GetProductInfo), Content.Skins Robux until it answers
--   Buy(key)           PromptProductPurchase of the skin's Developer Product; only when on sale and not owned. The grant is
--                      the server's (receipt); the new SkinState arrives and `Granted` fires for the feedback
--   Equip(class, key)  SkinEquip ("none" = the crew uniform)
--   Shown(class)       skins of a class the circles show: owned ones, and the ones on sale now (a limited skin past its
--                      EndsAt disappears for a player who does not own it)
local ContentProvider = game:GetService("ContentProvider")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local SkinIcons = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.ClassSelect.SkinIcons)

const NONE = Content.Skins.Rules.None
const CLOCK_TICK = 30 -- s: the limited countdown and the end of sale refresh at this pace

const SkinController = Modux.Controller("SkinController", { Priority = 790 })

function SkinController:Setup()
	self.Owned = Vide.source({}) :: Vide.Source<{ [string]: boolean }>
	self.Equipped = Vide.source({}) :: Vide.Source<{ [string]: string }>
	self.Ready = Vide.source(false) :: Vide.Source<boolean>
	self.Prices = Vide.source({}) :: Vide.Source<{ [string]: number }>
	-- server time, ticked every CLOCK_TICK s (limited countdowns)
	self.Now = Vide.source(workspace:GetServerTimeNow()) :: Vide.Source<number>
	-- skin key of an open purchase prompt ("" = none)
	self.Prompting = Vide.source("") :: Vide.Source<string>
	-- fires with the skin key when a skin arrives in Owned after the first SkinState (purchase feedback)
	self.Granted = self.Libs.Signal.new() :: SignalLib.Signal<string>
end

function SkinController:OnSale(key: string): boolean
	const skin = Content.Skins.ByKey[key]
	if skin == nil or skin.ProductId <= 0 then
		return false
	end
	return not skin.Limited or self.Now() < skin.EndsAt
end

-- Still listed (sale window), whether or not the product is created: a skin with ProductId 0 shows "Soon".
function SkinController:Listed(key: string): boolean
	const skin = Content.Skins.ByKey[key]
	return skin ~= nil and (not skin.Limited or self.Now() < skin.EndsAt)
end

function SkinController:Owns(key: string): boolean
	return self.Owned()[key] == true
end

-- Skin worn with `class` ("" = the crew uniform).
function SkinController:EquippedOf(class: string): string
	return self.Equipped()[class] or ""
end

function SkinController:Shown(class: string): { string }
	const out: { string } = {}
	for _, key in Content.Skins.ByClass[class] or {} do
		if self:Owns(key) or self:Listed(key) then
			table.insert(out, key)
		end
		if #out >= Content.Skins.Rules.PerClass then
			break
		end
	end
	return out
end

-- Robux price to show; nil = the product is not created yet.
function SkinController:RobuxOf(key: string): number?
	const skin = Content.Skins.ByKey[key]
	if skin == nil or skin.ProductId <= 0 then
		return nil
	end
	return self.Prices()[key] or skin.Robux
end

-- Seconds left of the limited sale of any listed skin (the banner); nil = no limited skin on sale.
function SkinController:LimitedLeft(): number?
	local best: number? = nil
	const now = self.Now()
	for _, skin in Content.Skins.List do
		if skin.Limited and skin.ProductId > 0 and now < skin.EndsAt then
			const left = skin.EndsAt - now
			if best == nil or left > best then
				best = left
			end
		end
	end
	return best
end

function SkinController:Buy(key: string): boolean
	const skin = Content.Skins.ByKey[key]
	if skin == nil or not Vide.untrack(function()
		return self:OnSale(key) and not self:Owns(key)
	end) or Vide.untrack(self.Prompting) ~= "" then
		return false
	end
	self.Prompting(key)
	const ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(Players.LocalPlayer, skin.ProductId)
	end)
	if not ok then
		warn(`[SkinController] PromptProductPurchase({key}) failed: {err}`)
		self.Prompting("")
		return false
	end
	return true
end

function SkinController:Equip(class: string, key: string)
	self.Libs.Net.SkinEquip:fireServer({ Class = class, Skin = if key == "" then NONE else key })
end

function SkinController:LoadPrices()
	for _, skin in Content.Skins.List do
		if skin.ProductId <= 0 then
			continue
		end
		task.spawn(function()
			const ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(skin.ProductId, Enum.InfoType.Product)
			end)
			const price = if ok and type(info) == "table" then (info :: any).PriceInRobux else nil
			if type(price) == "number" then
				const copy = table.clone(Vide.untrack(self.Prices))
				copy[skin.Key] = price
				self.Prices(copy)
			end
		end)
	end
end

SkinController:OnInit(function(self)
	self:Setup()

	self.Libs.Net.SkinState:onClient(function(data)
		const before = Vide.untrack(self.Owned)
		const wasReady = Vide.untrack(self.Ready)
		const equipped: { [string]: string } = {}
		for _, row in data.Equipped do
			equipped[row.Class] = row.Skin
		end
		self.Owned(table.freeze(table.clone(data.Owned)))
		self.Equipped(table.freeze(equipped))
		self.Ready(true)
		if wasReady then
			for key in data.Owned do
				if not before[key] then
					self.Granted:Fire(key)
				end
			end
		end
	end)

	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number)
		if userId == Players.LocalPlayer.UserId then
			self.Prompting("")
		end
	end)
end)

SkinController:OnStart(function(self)
	self:LoadPrices()
	-- the circle art of the class screen, in the background (the look textures are RigController's warm-up); a Decal per
	-- id: PreloadAsync reports a plain id string as Failure
	task.spawn(function()
		const holders: { Instance } = {}
		for _, id in SkinIcons do
			const holder = Instance.new("Decal")
			holder.Texture = id
			table.insert(holders, holder)
		end
		pcall(function()
			ContentProvider:PreloadAsync(holders)
		end)
	end)
	task.spawn(function()
		while true do
			task.wait(CLOCK_TICK)
			self.Now(workspace:GetServerTimeNow())
		end
	end)
end)

return SkinController
