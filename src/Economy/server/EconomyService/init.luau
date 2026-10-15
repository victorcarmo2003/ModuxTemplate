--!strict
-- Party money, tip jar, shift ledger, grade and summary (FEAT-012, FEAT-014; DEC-045, DEC-050, DEC-051, DEC-072,
-- DEC-083, DEC-238, DEC-239; architecture.md §2.3, §3.1, §4, §19.3, §19.26 A1, T48; network.md §3.3, §4.4; data.md §2.2;
-- TASK-021, TASK-050, TASK-242). Run place only.
-- Single writer of Cash and Drawer (Economy set, record 1). Since 2026-10-13 (DEC-238, DEC-239) SALES go straight to the
-- shared Cash and the cash drawer became a TIP JAR: the set field `Drawer` is kept for the wire and now means "tips in the
-- jar" (renaming it would break the client and Net; TipJarService and EconomyController read it as the jar). Others call:
--   Spend(amount, player?)        purchases (Mart, bench, trailer); atomic check-and-debit, never below 0
--   AddSale(amount, kind)         order price ("Sale") or thief caught ("Catch"): straight into Cash; while the shop takes entries
--   AddTip(amount)                customer tip or table tip: into the tip jar (AddToDrawer(amount, "Tip") is the same call)
--   Steal(amount)                 thief (FEAT-013): takes up to the jar, counted in the ledger's Stolen
--   CountArrival(), CountResult() ledger for the grade (CustomerService, TASK-032/033)
--   AddReportStep(name, fn)       fills ShiftReport fields of other features before it is sent (T48)
--   CollectTips()                 prompt on the jar (collect_tips): jar -> Cash now; the ledger remembers it for the report
--   TopUp(amount)                 first-run tutorial: Cash up to at least amount (TutorialService, Provisional)
--   PromptCashPack(player, missing) not enough Cash for a player's buy: prompts the Cash pack covering the difference
--                                 (Shop TopUp; owner request 2026-10-15). Spend calls it on failure with `player`
-- Cash changes by Spend, AddSale, CollectTips, the deposit, TopUp and DevAddCash.
-- Deposit on RoundService.ShiftEnded (start of Summary): grade A-D, bonus floor(day take x %) where the day take = Sales +
-- Tips + Catches - Stolen (DEC-051 parity), Cash += tips left in the jar + bonus, Drawer = 0, report steps, ShiftReport to
-- the group (Drawer = the day take), Reported(info, report).
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Charm = require(ReplicatedStorage.Packages.Charm)
local Content = require(ReplicatedStorage.shared.Content)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local TopUp = require(ReplicatedStorage.shared.Shop.TopUp)
local Ledger = require(script.Ledger)
local Modux = require(ServerScriptService.server.Modux)

export type Grade = Ledger.Grade
export type SaleResult = Ledger.SaleResult
export type DrawerKind = Ledger.DrawerKind
export type SaleKind = Ledger.SaleKind

-- ShiftReport packet (network.md §4.4), also handed to Reported listeners
export type Report = Ledger.Report

export type ShiftInfo = { Day: number, Night: number, IsNight: boolean, Attempt: number }

-- Report step (T48): fills Gems, AfkLocked, LastChanceUsed (reads the rest). No yield; an error becomes a warn.
export type ReportStep = (info: ShiftInfo, report: Report) -> ()
type Step = { Name: string, Run: ReportStep }

const RECORD = 1 -- Economy is a single record (network.md §3.3)
const CASH_MAX = 2147483647 -- Economy.Cash wire range
const DRAWER_MAX = 1000000 -- Economy.Drawer (the tip jar) / ShiftReport.Drawer (the day take) wire range
const COUNT_MAX = 999 -- ShiftReport.Arrived/Completed wire range
const TIPS_MAX = 100000 -- ShiftReport.Tips wire range
const GEMS_MAX = 1000 -- ShiftReport.Gems wire range
const BOSS_STAT = "BossBonusPP" -- Content.Stats (Shift Lead, Party scope, not stacking; DEC-069)
-- Closing: no new customer but the queue is still served (day: Last call, DEC-240), so sales, jar and ledger still take entries
const CLOSING = "Closing"
-- Seconds between two Cash pack prompts for the same player (a refused buy spammed on a prompt must not stack them)
const TOP_UP_COOLDOWN = 4
const SALE_KINDS: { [string]: boolean } = { Sale = true, Catch = true }
-- Sale.Result enum (network.md §4.3)
const RESULTS: { [string]: boolean } =
	{ Perfect = true, Complete = true, Incomplete = true, Wrong = true, Left = true, Refused = true, Slow = true }

local function fail(message: string)
	if RunService:IsStudio() then
		error(message, 0)
	end
	warn(message)
end

-- Non-negative integer amount, or nil
local function amountOf(value: any): number?
	if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge or value ~= math.floor(value) then
		return nil
	end
	return value
end

-- Whole number in [0, max]; anything else (a report step wrote garbage) becomes 0
local function wireInt(value: any, max: number): number
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.clamp(math.floor(value), 0, max)
end

const EconomyService = Modux.Service("EconomyService", {
	Require = { "PlaceService", "NetService", "RunStateService", "RoundService" },
	Priority = 740,
})

function EconomyService:Setup()
	-- Starts at RunParams.StartCash, $30 (DEC-045)
	self.Cash = self.Libs.Charm.atom(Content.RunParams.StartCash) :: Charm.Atom<number>
	self.Drawer = self.Libs.Charm.atom(0) :: Charm.Atom<number>
	-- Plain table: counters are server-only, nobody reacts to them (only the report goes out)
	self.Shift = Ledger.new() :: Ledger.Ledger
	self.Last = nil :: Report?
	-- Fired after the deposit: RewardService (wave 2) reads Completed for the anti-AFK rule (DEC-083)
	self.Reported = self.Libs.Signal.new() :: SignalLib.Signal<ShiftInfo, Report>
	-- Report steps in registration order (AddReportStep, T48)
	self.Steps = {} :: { Step }
	-- Last Cash pack prompt per player (os.clock), weak keys: a player who left is collected
	self.PromptedAt = setmetatable({}, { __mode = "k" }) :: { [Player]: number }
end

-- Reads -----------------------------------------------------------------------------------------------------------

function EconomyService:GetCash(): number
	return self.Cash()
end

-- Tips in the jar (the wire field is still called Drawer, DEC-239)
function EconomyService:GetDrawer(): number
	return self.Drawer()
end

function EconomyService:CanAfford(amount: number): boolean
	const value = amountOf(amount)
	return value ~= nil and self.Cash() >= value
end

-- Copy of the current shift ledger
function EconomyService:GetLedger(): Ledger.Ledger
	return table.clone(self.Shift)
end

-- Report of the last finished shift (nil before the first Summary)
function EconomyService:LastReport(): Report?
	return self.Last
end

-- Selling phase: customers come and orders are taken (FEAT-003). Content.Shift[phase].Selling (architecture.md §19.3)
function EconomyService:IsShopOpen(): boolean
	const round = self.Dependencies.RoundService
	if not round:IsStarted() then
		return false
	end
	const phase = Content.Shift.ByKey[round:GetPhase()]
	return phase ~= nil and phase.Selling
end

-- Sales, jar and ledger take entries: a selling phase or Closing (queue still served)
function EconomyService:IsDrawerOpen(): boolean
	const round = self.Dependencies.RoundService
	return self:IsShopOpen() or (round:IsStarted() and round:GetPhase() == CLOSING)
end

-- Writes ----------------------------------------------------------------------------------------------------------

-- Atomic check-and-debit: nothing yields between the read and the write, so two purchases handled in the same
-- frame run one after the other and the second sees the debited balance (T021-07). On failure with `player`,
-- that player gets "not_enough_cash" with the price.
function EconomyService:Spend(amount: number, player: Player?): boolean
	const value = amountOf(amount)
	if value == nil then
		fail(`[EconomyService] Spend: amount must be a non-negative integer, got {amount}`)
		return false
	end
	const cash = self.Cash()
	if cash < value then
		if player then
			self.Dependencies.RunStateService:Notify(player, "not_enough_cash", value)
			self:PromptCashPack(player, value - cash)
		end
		return false
	end
	self.Cash(cash - value)
	return true
end

-- Not enough Cash for a buy of `player` (owner request 2026-10-15): prompt the created Cash pack that covers the missing
-- amount (TopUp.Cash: the smallest that covers it, else the biggest). The receipt goes through ShopUtilityService like a
-- buy from the HUD cart (Cash += Amount for the whole party); the player still has to press the buy again. At most one
-- prompt per TOP_UP_COOLDOWN s per player.
function EconomyService:PromptCashPack(player: Player, missing: number)
	const now = os.clock()
	const last = self.PromptedAt[player]
	if last and now - last < TOP_UP_COOLDOWN then
		return
	end
	const pack = TopUp.Cash(missing)
	if pack == nil then
		return
	end
	self.PromptedAt[player] = now
	const ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(player, pack.ProductId)
	end)
	if not ok then
		warn(`[EconomyService] PromptProductPurchase({pack.Key}) failed: {err}`)
	end
end

-- Order price or thief reward straight into the shared Cash (DEC-238; it used to fall in the drawer, DEC-050). Only while
-- the shop takes entries; returns what actually went in (0 when refused or Cash is at its cap).
function EconomyService:AddSale(amount: number, kind: SaleKind): number
	const value = amountOf(amount)
	if value == nil then
		fail(`[EconomyService] AddSale: amount must be a non-negative integer, got {amount}`)
		return 0
	end
	if not SALE_KINDS[kind] then
		fail(`[EconomyService] AddSale: unknown kind {kind} (Sale or Catch; tips go through AddTip)`)
		return 0
	end
	if not self:IsDrawerOpen() then
		warn(`[EconomyService] AddSale({value}, {kind}) outside a selling phase or Closing ignored`)
		return 0
	end
	const cash = self.Cash()
	const added = math.min(value, CASH_MAX - cash)
	if added <= 0 then
		return 0
	end
	self.Cash(cash + added)
	Ledger.credit(self.Shift, kind, added)
	return added
end

-- A tip into the tip jar (DEC-239): customer tip (DEC-072) or the tip left on a table (SeatingService). The crew moves it
-- to Cash with CollectTips; what stays in the jar is deposited at the Summary. Returns what went in.
function EconomyService:AddTip(amount: number): number
	const value = amountOf(amount)
	if value == nil then
		fail(`[EconomyService] AddTip: amount must be a non-negative integer, got {amount}`)
		return 0
	end
	if not self:IsDrawerOpen() then
		warn(`[EconomyService] AddTip({value}) outside a selling phase or Closing ignored`)
		return 0
	end
	const jar = self.Drawer()
	const added = math.min(value, DRAWER_MAX - jar)
	if added <= 0 then
		return 0
	end
	self.Drawer(jar + added)
	Ledger.credit(self.Shift, "Tip", added)
	return added
end

-- For callers written against the drawer: only "Tip" goes to the jar (DEC-239); prices and rewards use AddSale.
function EconomyService:AddToDrawer(amount: number, kind: DrawerKind): number
	if kind ~= "Tip" then
		fail(`[EconomyService] AddToDrawer only takes "Tip" now (DEC-238); use AddSale for {kind}`)
		return 0
	end
	return self:AddTip(amount)
end

-- Thief (FEAT-013): takes up to the tip jar, adds it to the ledger's Stolen, returns what was taken. The amount
-- (floor(Drawer x StealPct / 100) when Drawer >= MinDrawer) is ThiefService's call, from Content. Dormant while the jar
-- stays small (DEC-239).
function EconomyService:Steal(amount: number): number
	const value = amountOf(amount)
	if value == nil then
		fail(`[EconomyService] Steal: amount must be a non-negative integer, got {amount}`)
		return 0
	end
	const drawer = self.Drawer()
	const taken = math.min(value, drawer)
	if taken <= 0 then
		return 0
	end
	self.Drawer(drawer - taken)
	self.Shift.Stolen += taken
	return taken
end

-- "Collect Tips" (DEC-239; it was "Collect Cash", Q-201): everything in the tip jar goes to Cash right now. Same rules
-- as AddTip (selling phase or Closing). The ledger keeps the amount (Collected). Returns what moved (0 = nothing: empty
-- jar, shop closed, Cash at its cap).
function EconomyService:CollectTips(): number
	if not self:IsDrawerOpen() then
		return 0
	end
	const jar = self.Drawer()
	const cash = self.Cash()
	const moved = math.min(jar, CASH_MAX - cash)
	if moved <= 0 then
		return 0
	end
	self.Libs.Charm.batch(function()
		self.Cash(cash + moved)
		self.Drawer(jar - moved)
	end)
	self.Shift.Collected += moved
	return moved
end

-- A customer reached the counter (FEAT-014 denominator). Called once per customer by CustomerService.
function EconomyService:CountArrival()
	if not self:IsDrawerOpen() then
		return
	end
	self.Shift.Arrived += 1
end

-- Outcome of a customer that arrived (Perfect/Complete = satisfied, DEC-051). Money goes through AddSale / AddTip.
function EconomyService:CountResult(result: SaleResult)
	if not RESULTS[result] then
		fail(`[EconomyService] CountResult: unknown result {result}`)
		return
	end
	if not self:IsDrawerOpen() then
		return
	end
	Ledger.count(self.Shift, result)
end

-- Report steps (T48: no Require cycle; RewardService and RoundService register here) -----------------------------

-- Call from the peripheral's OnInit (lower priority, so Setup already ran). Runs at every deposit, in registration
-- order, before the ShiftReport goes out. A repeated name is refused.
function EconomyService:AddReportStep(name: string, fn: ReportStep)
	if type(name) ~= "string" or name == "" or type(fn) ~= "function" then
		fail("[EconomyService] AddReportStep: needs a name and a function")
		return
	end
	for _, step in self.Steps do
		if step.Name == name then
			fail(`[EconomyService] AddReportStep: duplicate step {name}`)
			return
		end
	end
	table.insert(self.Steps, { Name = name, Run = fn })
end

-- Every step on the report; an error in one is a warn, the next ones still run and the report goes out anyway
function EconomyService:RunReportSteps(info: ShiftInfo, report: Report)
	for _, step in self.Steps do
		const ok, err = pcall(step.Run, info, report)
		if not ok then
			warn(`[EconomyService] report step {step.Name} failed: {err}`)
		end
	end
	-- Fields a step may write, back into wire shape (an out-of-range int would break the packet)
	report.Gems = wireInt(report.Gems, GEMS_MAX)
	report.AfkLocked = report.AfkLocked == true
	report.LastChanceUsed = report.LastChanceUsed == true
end

-- Settlement ------------------------------------------------------------------------------------------------------

-- Party BossBonusPP: highest Party-scoped Add among members in the server (does not stack, DEC-069).
-- Shift Lead is out of the MVP (DEC-186), so wave 1 always gets 0.
function EconomyService:BossPoints(): number
	local best = 0
	for _, member in self.Dependencies.RunStateService.Members() do
		if member.State == "Away" then
			continue
		end
		const class = Content.Classes.ByKey[member.Class]
		if class == nil then
			continue
		end
		for _, effect in class.Effects do
			if effect.Stat == BOSS_STAT and effect.Scope == "Party" and effect.Op == "Add" then
				best = math.max(best, effect.Value)
			end
		end
	end
	return best
end

-- Start of Summary (RoundService.ShiftEnded): grade, bonus, deposit, report. Jar and ledger end at zero. Sales are in
-- Cash already (DEC-238) and so are the tips collected during the shift: the deposit adds the grade bonus and the tips
-- nobody collected (DEC-239, auto-deposit).
function EconomyService:Deposit(info: ShiftInfo): Report
	const ledger = self.Shift
	const jar = self.Drawer()
	const settlement = Ledger.settle(ledger, self:BossPoints())

	self.Libs.Charm.batch(function()
		self.Cash(math.min(self.Cash() + jar + settlement.Bonus, CASH_MAX))
		self.Drawer(0)
	end)

	const report: Report = {
		Day = info.Day,
		Night = info.Night,
		IsNight = info.IsNight,
		Arrived = math.min(ledger.Arrived, COUNT_MAX),
		Completed = math.min(ledger.Completed, COUNT_MAX),
		Drawer = math.min(settlement.Take, DRAWER_MAX), -- the day take: Sales + Tips + Catches - Stolen (field name kept)
		Tips = math.min(ledger.Tips, TIPS_MAX),
		Stolen = math.min(ledger.Stolen, DRAWER_MAX),
		Grade = settlement.Grade,
		Bonus = math.min(settlement.Bonus, DRAWER_MAX),
		Deposited = math.min(settlement.Deposited, DRAWER_MAX),
		Gems = 0, -- RewardService step (DEC-104)
		AfkLocked = false, -- RewardService step (DEC-083)
		LastChanceUsed = false, -- RoundService step, night summary (DEC-053, DEC-110)
	}
	self:RunReportSteps(info, report)
	self.Last = table.clone(report)
	self.Shift = Ledger.new()

	const net = self.Dependencies.NetService
	if net:IsRunning() then
		self.Libs.Net.ShiftReport:fireClient(net.Audience, report)
	end
	self.Reported:Fire(info, report)
	return report
end

-- New shift: ledger and jar start empty (data.md §2.2). A jar that is not empty here skipped its Summary
-- (DevSetDay mid-shift): discarded like a lost night's jar (FEAT-012), with a warning.
function EconomyService:BeginShift()
	if self.Drawer() > 0 then
		warn(`[EconomyService] shift started with ${self.Drawer()} in the tip jar (no Summary): discarded`)
		self.Drawer(0)
	end
	self.Shift = Ledger.new()
end

-- Snapshot "Cash" (data.md §3.3): Cash only; Drawer and ledger are zero at every capture.
function EconomyService:RestoreCash(data: any)
	self.Libs.Charm.batch(function()
		if type(data) == "number" and data == data then
			self.Cash(math.clamp(math.floor(data), 0, CASH_MAX))
		end
		self.Drawer(0)
	end)
	self.Shift = Ledger.new()
end

-- First-run tutorial (user request 2026-10-11, Provisional; TutorialService): Cash goes up to at least `amount` (the
-- price of the package Walt sends the rookie to buy), so the shopping lesson never stalls on money. Never lowers Cash.
-- Returns what was added.
function EconomyService:TopUp(amount: number): number
	const value = amountOf(amount)
	if value == nil then
		fail(`[EconomyService] TopUp: amount must be a non-negative integer, got {amount}`)
		return 0
	end
	const cash = self.Cash()
	if cash >= value then
		return 0
	end
	self.Cash(math.min(value, CASH_MAX))
	return value - cash
end

-- Dev hook (board TASK-021 v1.1, R2; command in TASK-043). `amount` may be negative; Cash never goes below 0.
function EconomyService:DevAddCash(amount: number): number
	if not self.Dependencies.PlaceService:IsDev() then
		error("[EconomyService] DevAddCash is dev mode only", 2)
	end
	if type(amount) ~= "number" or amount ~= amount or math.abs(amount) == math.huge then
		error("[EconomyService] DevAddCash: amount must be a finite number", 2)
	end
	const cash = math.clamp(self.Cash() + math.floor(amount), 0, CASH_MAX)
	self.Cash(cash)
	return cash
end

-- Network ---------------------------------------------------------------------------------------------------------

function EconomyService:Record(): { Cash: number, Drawer: number }
	return {
		Cash = math.clamp(self.Cash(), 0, CASH_MAX),
		Drawer = math.clamp(self.Drawer(), 0, DRAWER_MAX),
	}
end

EconomyService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end

	self.Dependencies.RunStateService:RegisterSnapshot("Cash", function()
		return self.Cash()
	end, function(data, _mode)
		self:RestoreCash(data)
	end)

	-- Signals exist since RoundService's OnInit (priority 750 > 740)
	const round = self.Dependencies.RoundService
	round.ShiftEnded:Connect(function(info)
		self:Deposit(info)
	end)
	round.ShiftStarted:Connect(function()
		self:BeginShift()
	end)
end)

EconomyService:OnStart(function(self)
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end

	-- Lync.start already ran (NetService OnStart, priority 1000). Late joiners get the record from the set.
	self.Libs.Net.Economy:add(RECORD, self:Record())
	self.Libs.Charm.effect(function()
		const record = self:Record()
		if self.Dependencies.NetService:IsRunning() then
			self.Libs.Net.Economy:update(RECORD, record)
		end
	end)
end)

return EconomyService
