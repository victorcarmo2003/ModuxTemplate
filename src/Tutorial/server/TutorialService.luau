--!strict
-- TutorialService (user request 2026-10-11, Provisional): single responder of `TutorialComplete` (network.md, Profile
-- packet field TutorialDone; data.md §1.1). Sets the profile flag TutorialDone = true when the client says the
-- first-hot-dog tutorial ended (finished or skipped) and asks a save. Idempotent: a second packet changes nothing.
-- Cosmetic flag (nothing else reads it on the server): the client is trusted to say it. Run place only.
-- AnyPending (Provisional, user request 2026-10-11): BossService rings and holds the tutorial call (BossCalls Trigger
-- Tutorial) while a player in the server still has the tutorial ahead.
-- Tutorial customer (Provisional, user request 2026-10-11): `TutorialBegin` from a rookie (TutorialDone = false) asks
-- CustomerService for the tutorial customer (one at a time, shared.Tutorial.Rules). Once nobody has the tutorial
-- pending any more (finished, skipped, left), an unserved tutorial customer is sent away (CustomerService:EndTutorial).
-- Shopping lesson (Provisional, user request 2026-10-11; shared.Tutorial.Rules Buns / Package): on the first
-- TutorialBegin while EVERY player in the server is a rookie (a veteran's run is never touched) the bun stock is capped
-- at Rules.Buns (one), so the first sale empties the crate and Walt sends the rookie to the Mart. While the tutorial
-- customer still waits, a hot dog thrown away gives the bun back (never stuck without a bun for the first sale). When
-- the buns run out with a rookie pending, Cash is topped up to the package price (EconomyService:TopUp) so the
-- purchase never stalls on money. Server decides: the client only reads the Stock set.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local TutorialRules = require(ReplicatedStorage.shared.Tutorial.Rules)
local Modux = require(ServerScriptService.server.Modux)

const TICK_RATE = 2 -- Hz: the pending check of the tutorial customer
const HOT_DOG = "hot_dog"
const PACKAGE = Content.Packages.ByKey[TutorialRules.Package]
const BUN = if PACKAGE then PACKAGE.Ingredient else "bun"

const TutorialService = Modux.Service(
	"TutorialService",
	{
		Require = { "ProfileService", "PlaceService", "CustomerService", "KitchenService", "EconomyService" },
		Priority = 500,
	}
)

function TutorialService:Setup()
	self.Enabled = false :: boolean
	-- a tutorial customer was asked and the tutorial may still be running for someone
	self.Asked = false :: boolean
	-- the tutorial stock (Rules.Buns) was applied in this server
	self.Seeded = false :: boolean
end

function TutorialService:Complete(player: Player)
	const profiles = self.Dependencies.ProfileService
	const profile = profiles:Get(player)
	if profile == nil or profile.TutorialDone() == true then
		return
	end
	profiles:Update(player, { TutorialDone = true })
	profiles:RequestSave(player)
end

-- A player in the server with a loaded profile still has the tutorial ahead (TutorialDone = false)
function TutorialService:IsPending(player: Player): boolean
	const profile = self.Dependencies.ProfileService:Get(player)
	return profile ~= nil and profile.TutorialDone() == false
end

function TutorialService:AnyPending(): boolean
	for _, player in Players:GetPlayers() do
		if self:IsPending(player) then
			return true
		end
	end
	return false
end

-- Every player in the server has a loaded profile with the tutorial ahead (a tutorial run)
function TutorialService:AllPending(): boolean
	const players = Players:GetPlayers()
	if #players == 0 then
		return false
	end
	for _, player in players do
		if not self:IsPending(player) then
			return false
		end
	end
	return true
end

-- Cash up to the package price while a rookie has the shopping lesson ahead
function TutorialService:EnsureCash()
	if PACKAGE ~= nil and self.Seeded and self:AnyPending() then
		self.Dependencies.EconomyService:TopUp(PACKAGE.Price)
	end
end

-- Tutorial stock: the bun stock capped at Rules.Buns, once per server, only in a run of rookies
function TutorialService:Seed()
	if self.Seeded or not self:AllPending() then
		return
	end
	self.Seeded = true
	const kitchen = self.Dependencies.KitchenService
	const amount = kitchen:GetStock(BUN)
	if amount > TutorialRules.Buns then
		kitchen:SetAmount(BUN, TutorialRules.Buns)
	end
	self:EnsureCash()
end

-- A hot dog thrown away while the tutorial customer still waits: the bun comes back (the first sale never stalls)
function TutorialService:OnDiscarded(item: string)
	if not self.Seeded or item ~= HOT_DOG or not self:AnyPending() then
		return
	end
	if not self.Dependencies.CustomerService:HasTutorial() then
		return
	end
	const kitchen = self.Dependencies.KitchenService
	if kitchen:GetStock(BUN) < TutorialRules.Buns then
		kitchen:SetAmount(BUN, TutorialRules.Buns)
	end
end

-- A rookie started the tutorial (answered the call): the tutorial customer comes
function TutorialService:Begin(player: Player)
	if not self:IsPending(player) then
		return
	end
	self:Seed()
	if self.Dependencies.CustomerService:RequestTutorial() then
		self.Asked = true
	end
end

function TutorialService:Step()
	if self.Asked and not self:AnyPending() then
		self.Asked = false
		self.Dependencies.CustomerService:EndTutorial()
	end
end

TutorialService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self.Enabled = true
	self.Libs.Net.TutorialComplete:onServer(function(_, player: Player)
		self:Complete(player)
	end)
	self.Libs.Net.TutorialBegin:onServer(function(_, player: Player)
		self:Begin(player)
	end)
	-- KitchenService (650) created its signals in its own OnInit, before this one (500)
	const kitchen = self.Dependencies.KitchenService
	kitchen.Discarded:Connect(function(_player: Player, item: string, _altered: boolean, _where: string)
		self:OnDiscarded(item)
	end)
	kitchen.StockChanged:Connect(function(ingredient: string, amount: number)
		if ingredient == BUN and amount <= 0 then
			self:EnsureCash()
		end
	end)
end)

TutorialService:OnTick(function(self)
	if self.Enabled then
		self:Step()
	end
end, TICK_RATE)

return TutorialService
