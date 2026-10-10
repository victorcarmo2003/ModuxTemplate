--!strict
-- Mart: shelves and bench of basic upgrades (FEAT-008, FEAT-015; DEC-049, DEC-101, DEC-106, DEC-109, DEC-180,
-- DEC-184; architecture.md §9, §18.4; content-data.md §3.18; TASK-036). Run place only.
-- Owner of the actions buy_package and bench_buy_upgrade and of the PromptEnabled/PromptText of their anchors.
-- No network of its own: the client reads Economy, Stock and Upgrades (MarketController, TASK-037).
--   Shelves (Interactable + PromptAction buy_package + Package): price from Content.Packages, EconomyService:Spend,
--     Tool in hand by ItemService:Give. Ingredient not unlocked = no prompt and every buy refused ("Out of stock",
--     DEC-180); Coffee stays blocked until the trailer (Ingredients.Vehicle). Fruit/vegetables have no anchor (DEC-109).
--   Bench B1..B5 (PromptAction bench_buy_upgrade + BenchSlot): which upgrade sits on a slot is data
--     (Content.Upgrades.BenchSpot). Always on sale (DEC-106); no prompt when Maxed, "Trailer only" (not on the current
--     vehicle) or before UnlockDay. The purchase is UpgradeService:Buy (atomic, its own guards).
--   S1 (bench_buy_item, wave 4): prompt always off, "Nothing special today" (Q-120). The action is not registered.
-- Provisional (TASK-036):
--   * Blocked is derived here with the Stock.Blocked formula (content-data.md §3.3: Day < UnlockDay, or Vehicle not the
--     current one) until KitchenService (TASK-025) exposes it; both read the same Day and vehicle, so they agree;
--   * bench prompt text "Buy Grill 2 — $60" (upgrade Name + level number; the number is left out when the upgrade has
--     a single level to buy); the world card keeps the ui-text.md level names;
--   * a player's buy_package packets closer than PACKAGE_GAP are refused (cadence; the hold is 0.5 s on the client).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(ServerScriptService.server.Modux)

const TAG = "Interactable"
const PACKAGE_ACTION = "buy_package"
const UPGRADE_ACTION = "bench_buy_upgrade"
const ITEM_ACTION = "bench_buy_item"
const PACKAGE_GAP = Content.Actions.ByKey[PACKAGE_ACTION].Hold * 0.8

local function stringAttribute(anchor: Instance, name: string): string?
	const value = anchor:GetAttribute(name)
	return if type(value) == "string" and value ~= "" then value else nil
end

-- Upgrade on a bench slot (B1..B5), from Content.Upgrades.BenchSpot
local function upgradeAt(slot: string): Content.Upgrade?
	for _, upgrade in Content.Upgrades.List do
		if upgrade.BenchSpot == slot then
			return upgrade
		end
	end
	return nil
end

-- Levels above the start level on a vehicle (how many purchases the upgrade has there)
local function buyableLevels(upgrade: Content.Upgrade, vehicle: string): number
	local count = 0
	for _, row in upgrade.Levels[vehicle] or {} do
		if row.Level > upgrade.StartLevel then
			count += 1
		end
	end
	return count
end

const MarketService = Modux.Service("MarketService", {
	Require = {
		"PlaceService",
		"PlayerService",
		"InteractionService",
		"ItemService",
		"EconomyService",
		"UpgradeService",
		"RoundService",
		"RunStateService",
	},
	Priority = 615,
})

function MarketService:Setup()
	-- os.clock() of the last accepted buy_package per player (PACKAGE_GAP)
	self.LastBuy = {} :: { [Player]: number }
end

-- Reads -----------------------------------------------------------------------------------------------------------

-- Ingredient not on sale today (DEC-180): before its UnlockDay, or bound to another vehicle (Coffee before the trailer).
function MarketService:IsBlocked(ingredientKey: string): boolean
	const ingredient = Content.Ingredients.ByKey[ingredientKey]
	if ingredient == nil then
		return true
	end
	if ingredient.Vehicle ~= nil and ingredient.Vehicle ~= self.Dependencies.UpgradeService:GetVehicle() then
		return true
	end
	return self.Dependencies.RoundService:GetDay() < ingredient.UnlockDay
end

function MarketService:PackageOf(anchor: Instance): Content.Package?
	const key = stringAttribute(anchor, "Package")
	return if key then Content.Packages.ByKey[key] else nil
end

function MarketService:UpgradeOf(anchor: Instance): Content.Upgrade?
	const slot = stringAttribute(anchor, "BenchSlot")
	return if slot then upgradeAt(slot) else nil
end

-- Bench slot sells now: upgrade exists on the current vehicle, not maxed, unlocked today. Money and the post-purchase
-- guard are checked by UpgradeService:Buy.
function MarketService:OnSale(upgrade: Content.Upgrade): boolean
	const upgrades = self.Dependencies.UpgradeService
	return upgrades:GetLevel(upgrade.Key) ~= nil
		and upgrades:NextLevel(upgrade.Key) ~= nil
		and self.Dependencies.RoundService:GetDay() >= upgrade.UnlockDay
end

-- "Buy Grill 2 — $60" (Content.Actions.bench_buy_upgrade.Text with {upgrade} and {price})
function MarketService:UpgradeText(upgrade: Content.Upgrade, row: Content.UpgradeLevel): string
	const vehicle = self.Dependencies.UpgradeService:GetVehicle()
	const name = if buyableLevels(upgrade, vehicle) > 1 then `{upgrade.Name} {row.Level}` else upgrade.Name
	const text = Content.Actions.ByKey[UPGRADE_ACTION].Text
	return (string.gsub(string.gsub(text, "{upgrade}", name), "{price}", tostring(row.Price)))
end

-- Prompts ---------------------------------------------------------------------------------------------------------

function MarketService:Refresh(anchor: Instance)
	const action = anchor:GetAttribute("PromptAction")
	const interaction = self.Dependencies.InteractionService
	if action == PACKAGE_ACTION then
		const package = self:PackageOf(anchor)
		-- Text left to the client (Prompt.luau fills {item}/{price} from Package): same table, no duplicate string.
		interaction:SetPrompt(anchor, package ~= nil and not self:IsBlocked(package.Ingredient))
	elseif action == UPGRADE_ACTION then
		const upgrade = self:UpgradeOf(anchor)
		if upgrade == nil or not self:OnSale(upgrade) then
			interaction:SetPrompt(anchor, false)
			return
		end
		const row = self.Dependencies.UpgradeService:NextLevel(upgrade.Key) :: Content.UpgradeLevel
		interaction:SetPrompt(anchor, true, self:UpgradeText(upgrade, row))
	elseif action == ITEM_ACTION then
		interaction:SetPrompt(anchor, false) -- S1 "Nothing special today" (wave 1, Q-120)
	end
end

function MarketService:RefreshAll()
	for _, anchor in CollectionService:GetTagged(TAG) do
		if anchor:IsDescendantOf(workspace) then
			self:Refresh(anchor)
		end
	end
end

-- Actions ---------------------------------------------------------------------------------------------------------

function MarketService:CanAct(player: Player): boolean
	return self.Dependencies.RoundService:IsStarted() and self.Dependencies.RunStateService:IsActive(player)
end

function MarketService:ValidatePackage(player: Player, anchor: Instance): boolean
	if not self:CanAct(player) then
		return false
	end
	const package = self:PackageOf(anchor)
	if package == nil or self:IsBlocked(package.Ingredient) then
		return false
	end
	const last = self.LastBuy[player]
	return last == nil or os.clock() - last >= PACKAGE_GAP
end

-- Hotbar and package limit before the money (T036-07: refused without charging), then Spend and Give with no yield
-- in between, so the Tool always lands once the cash is gone.
function MarketService:BuyPackage(player: Player, anchor: Instance)
	const package = self:PackageOf(anchor)
	if package == nil then
		return
	end
	const items = self.Dependencies.ItemService
	const ok, notice, value = items:CanGive(player, package.Item)
	if not ok then
		if notice then
			self.Dependencies.RunStateService:Notify(player, notice, value)
		end
		return
	end
	if items:Template(package.Item) == nil then
		warn(`[MarketService] no kit Tool for "{package.Item}" (Assets.Items.Tools): purchase refused`)
		return
	end
	if player:FindFirstChildOfClass("Backpack") == nil then
		return
	end
	if not self.Dependencies.EconomyService:Spend(package.Price, player) then
		return -- "not_enough_cash" already sent by Spend
	end
	self.LastBuy[player] = os.clock()
	items:Give(player, package.Item, { Count = package.Amount })
end

function MarketService:ValidateUpgrade(player: Player, anchor: Instance): boolean
	if not self:CanAct(player) then
		return false
	end
	const upgrade = self:UpgradeOf(anchor)
	return upgrade ~= nil and (self.Dependencies.UpgradeService:CanBuy(upgrade.Key))
end

function MarketService:BuyUpgrade(player: Player, anchor: Instance)
	const upgrade = self:UpgradeOf(anchor)
	if upgrade == nil then
		return
	end
	self.Dependencies.UpgradeService:Buy(upgrade.Key, player)
end

MarketService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end

	-- InteractionService (730) built its handler table in its own OnInit, before this one (615).
	const interaction = self.Dependencies.InteractionService
	interaction:RegisterAction(PACKAGE_ACTION, {
		Validate = function(player: Player, anchor: Instance, _id: number): boolean
			return self:ValidatePackage(player, anchor)
		end,
		Run = function(player: Player, anchor: Instance, _id: number)
			self:BuyPackage(player, anchor)
		end,
	})
	interaction:RegisterAction(UPGRADE_ACTION, {
		Validate = function(player: Player, anchor: Instance, _id: number): boolean
			return self:ValidateUpgrade(player, anchor)
		end,
		Run = function(player: Player, anchor: Instance, _id: number)
			self:BuyUpgrade(player, anchor)
		end,
	})

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self.LastBuy[player] = nil
	end)
end)

MarketService:OnStart(function(self)
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end

	-- Day, vehicle and levels drive every Mart prompt: one effect re-reads them (purchase, restore, unlock day, swap).
	const round = self.Dependencies.RoundService
	const upgrades = self.Dependencies.UpgradeService
	self.Libs.Charm.effect(function()
		round:GetDay()
		upgrades:GetVehicle()
		upgrades:Capture()
		self:RefreshAll()
	end)

	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(anchor)
		if anchor:IsDescendantOf(workspace) then
			self:Refresh(anchor)
		end
	end)
end)

return MarketService
