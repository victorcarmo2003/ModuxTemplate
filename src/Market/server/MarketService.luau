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
--   Gear Stand shutter (Mart v2, TASK-139; FEAT-015 v2): open / closed is GearStandService's (business hours, owner
--     request 2026-10-17, Content.Mart.Hours: opens at the end of each shift, closes StayOpenIntoShift s into the next
--     one; always closed in Content.Mart.KioskClosedPhases). Closed = bench prompts off and every bench purchase
--     refused in Validate AND Run (a hold that ends on the close buys nothing), with the toast gear_closed (throttled)
--     to the player who tried. Shelves (buy_package) never close (Q-177 A).
--   Cooldown (Q-203 Provisional): a line bought on the stand is "Sold out" for Content.Mart.Cooldown.Turns shifts
--     (UpgradeService owns the state); its prompt is off and the purchase refused in silence, the other lines stay free.
-- Refusal toasts (FEAT-005 D-04; TASK-080), only to the player who acted, the same key at most once every
-- NOTICE_GAP seconds: shelf Blocked -> shelf_locked {item}; bench "busy" (another buyer inside UpgradeService's guard)
-- -> bench_busy; bench "maxed" -> upgrade_maxed {upgrade}. Silent: run not started / member not Active (life state),
-- anchor without Package/BenchSlot, buy_package cadence, "locked" and "not_on_vehicle" (prompt never shown).
-- Blocked is KitchenService:IsBlocked (the Stock.Blocked of the set; ends the TASK-036 Provisional).
-- Provisional (TASK-036):
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
const NOTICE_GAP = 2 -- seconds (FEAT-005 anti-spam; Provisional constant, TASK-080: no Content field yet)

local function stringAttribute(anchor: Instance, name: string): string?
	const value = anchor:GetAttribute(name)
	return if type(value) == "string" and value ~= "" then value else nil
end

-- Upgrade on a bench slot (B1..B5), from Content.Upgrades.BenchSpot; a pedestal shared by a day-only and an anomaly-only
-- line (Content.Mode, TASK-324) sells the one that is on in this mode
local function upgradeAt(slot: string): Content.Upgrade?
	for _, upgrade in Content.Upgrades.List do
		if upgrade.BenchSpot == slot and not Content.Mode.IsOff(upgrade.Key) then
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
		"KitchenService",
		"GearStandService",
	},
	Priority = 615,
})

function MarketService:Setup()
	-- os.clock() of the last accepted buy_package per player (PACKAGE_GAP)
	self.LastBuy = {} :: { [Player]: number }
	-- os.clock() of the last refusal toast per player and Notices key (NOTICE_GAP)
	self.LastNotice = {} :: { [Player]: { [string]: number } }
	-- identity of the last shift that got the "Closing time" hint (once per shift)
	self.HintedShift = "" :: string
end

-- Reads -----------------------------------------------------------------------------------------------------------

-- Ingredient not on sale today (DEC-180): before its UnlockDay, or bound to another vehicle (Coffee before the trailer).
-- Same answer as Stock.Blocked: KitchenService owns the rule.
function MarketService:IsBlocked(ingredientKey: string): boolean
	return self.Dependencies.KitchenService:IsBlocked(ingredientKey)
end

function MarketService:PackageOf(anchor: Instance): Content.Package?
	const key = stringAttribute(anchor, "Package")
	return if key then Content.Packages.ByKey[key] else nil
end

function MarketService:UpgradeOf(anchor: Instance): Content.Upgrade?
	const slot = stringAttribute(anchor, "BenchSlot")
	return if slot then upgradeAt(slot) else nil
end

-- Gear Stand shutter up: GearStandService's business hours (reactive inside an effect). Also down on Day 1 in
-- Content.Mart.FirstShiftClosedPhases (owner request 2026-10-14; empty since the 2026-10-17 Day 1 cut).
function MarketService:IsKioskOpen(): boolean
	const round = self.Dependencies.RoundService
	return self.Dependencies.GearStandService:IsOpen()
		and not Content.Mart.FirstShiftClosed(round:Info(), round:GetPhase())
end

-- Bench slot sells now: upgrade exists on the current vehicle, not maxed, unlocked today, not resting after a
-- purchase (Gear Stand cooldown, Q-203: the line is "Sold out" for Content.Mart.Cooldown shifts). Money and the post-purchase
-- guard are checked by UpgradeService:Buy.
function MarketService:OnSale(upgrade: Content.Upgrade): boolean
	const upgrades = self.Dependencies.UpgradeService
	return upgrades:GetLevel(upgrade.Key) ~= nil
		and not Content.Mode.IsOff(upgrade.Key) -- anomaly mode: Wide Counter, Drawer Lock off the stand
		and upgrades:NextLevel(upgrade.Key) ~= nil
		and self.Dependencies.RoundService:GetDay() >= upgrade.UnlockDay
		and upgrades:GetWait(upgrade.Key) == 0
end

-- "Buy Grill 2 — $60" (Content.Actions.bench_buy_upgrade.Text with {upgrade} and {price})
function MarketService:UpgradeText(upgrade: Content.Upgrade, row: Content.UpgradeLevel): string
	const vehicle = self.Dependencies.UpgradeService:GetVehicle()
	const name = if buyableLevels(upgrade, vehicle) > 1 then `{upgrade.Name} {row.Level}` else upgrade.Name
	const text = Content.Actions.ByKey[UPGRADE_ACTION].Text
	return (string.gsub(string.gsub(text, "{upgrade}", name), "{price}", tostring(row.Price)))
end

-- Closing-time hint (user feedback 2026-10-11; Q-203 Provisional) -----------------------------------------------------

-- Cheapest next level among the stand's lines that sell now, nil when nothing sells
function MarketService:CheapestOnSale(): number?
	const upgrades = self.Dependencies.UpgradeService
	local cheapest: number? = nil
	for _, upgrade in Content.Upgrades.List do
		if upgrade.SoldAt ~= "Bench" or not self:OnSale(upgrade) then
			continue
		end
		const row = upgrades:NextLevel(upgrade.Key)
		if row ~= nil and (cheapest == nil or row.Price < cheapest) then
			cheapest = row.Price
		end
	end
	return cheapest
end

-- Nothing bought yet on the current vehicle (any Bench line still at its start level)
function MarketService:NeverBought(): boolean
	const upgrades = self.Dependencies.UpgradeService
	for _, upgrade in Content.Upgrades.List do
		const level = if upgrade.SoldAt == "Bench" then upgrades:GetLevel(upgrade.Key) else nil
		if level ~= nil and level > upgrade.StartLevel then
			return false
		end
	end
	return true
end

-- The party can afford a line (cash + the drawer about to be collected) or never bought one. Same rule on the client
-- for the arrow (MarketController/Hint.luau).
function MarketService:HintDue(): boolean
	const cheapest = self:CheapestOnSale()
	if cheapest == nil then
		return false
	end
	const economy = self.Dependencies.EconomyService
	return economy:GetCash() + economy:GetDrawer() >= cheapest or self:NeverBought()
end

-- Closing starts: one toast per shift to the party (only with the business hours off, Content.Mart.Hours). The day Closing
-- is the Last call (DEC-240, the crew is still serving and has its own toast), so the hint waits for the Summary.
function MarketService:OnPhase(phase: string, info: { Day: number, Night: number, IsNight: boolean })
	if phase ~= "Closing" and phase ~= "Summary" then
		return
	end
	-- business hours on: the stand's own "Gear Stand is OPEN" toast at the shift end replaces this hint
	if Content.Mart.Hours.OpenAtShiftEnd then
		return
	end
	if phase == "Closing" and self.Dependencies.RoundService:IsLastCall() then
		return
	end
	const key = `{info.Day}/{info.Night}/{if info.IsNight then 1 else 0}`
	if key == self.HintedShift or not self:HintDue() then
		return
	end
	self.HintedShift = key
	self.Dependencies.RunStateService:Notify("all", "mart_hint", 0)
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
		if upgrade == nil or not self:IsKioskOpen() or not self:OnSale(upgrade) then
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

-- Refusal toast to the player who acted, throttled per key (FEAT-005 anti-spam).
function MarketService:Refuse(player: Player, key: string, value: number) -- value 0 = none
	const now = os.clock()
	local keys = self.LastNotice[player]
	if keys == nil then
		keys = {}
		self.LastNotice[player] = keys
	end
	const last = keys[key]
	if last ~= nil and now - last < NOTICE_GAP then
		return
	end
	keys[key] = now
	self.Dependencies.RunStateService:Notify(player, key, value)
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
	if package == nil then
		return false
	end
	if self:IsBlocked(package.Ingredient) then
		self:Refuse(player, "shelf_locked", Content.Ingredients.IndexOf[package.Ingredient] or 0)
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
	if not self.Dependencies.EconomyService:Spend(package.Price, player, package.Key) then
		return -- "not_enough_cash" already sent by Spend
	end
	self.LastBuy[player] = os.clock()
	items:Give(player, package.Item, { Count = package.Amount })
end

function MarketService:ValidateUpgrade(player: Player, anchor: Instance): boolean
	if not self:CanAct(player) then
		return false
	end
	if not self:IsKioskOpen() then
		self:Refuse(player, "gear_closed", 0) -- a hold that ended on the close, or a stale prompt
		return false
	end
	const upgrade = self:UpgradeOf(anchor)
	if upgrade == nil then
		return false
	end
	const ok, reason = self.Dependencies.UpgradeService:CanBuy(upgrade.Key)
	if reason == "busy" then
		self:Refuse(player, "bench_busy", 0)
	elseif reason == "maxed" then
		self:Refuse(player, "upgrade_maxed", Content.Upgrades.IndexOf[upgrade.Key] or 0)
	end
	-- "cooldown": silent, the prompt is already off and the plate says "Sold out"
	return ok
end

function MarketService:BuyUpgrade(player: Player, anchor: Instance)
	const upgrade = self:UpgradeOf(anchor)
	if upgrade == nil or not self:IsKioskOpen() then
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

	self.Dependencies.RoundService.PhaseChanged:Connect(function(phase, _day, _night)
		self:OnPhase(phase, self.Dependencies.RoundService:Info())
	end)

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self.LastBuy[player] = nil
		self.LastNotice[player] = nil
	end)
end)

MarketService:OnStart(function(self)
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end

	-- Day, vehicle, levels and phase (Gear Stand shutter) drive every Mart prompt: one effect re-reads them
	-- (purchase, restore, unlock day, swap, turn change).
	const round = self.Dependencies.RoundService
	const upgrades = self.Dependencies.UpgradeService
	self.Libs.Charm.effect(function()
		round:GetDay()
		round:GetPhase()
		round:IsNight()
		upgrades:GetVehicle()
		upgrades:Capture()
		upgrades.Cooldown()
		upgrades.Turn()
		self.Dependencies.GearStandService:IsOpen()
		self:RefreshAll()
	end)

	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(anchor)
		if anchor:IsDescendantOf(workspace) then
			self:Refresh(anchor)
		end
	end)
end)

return MarketService
