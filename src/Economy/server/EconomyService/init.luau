--!strict
-- Party money, cash drawer, shift ledger, grade and summary (FEAT-012, FEAT-014; DEC-045, DEC-050, DEC-051, DEC-072,
-- DEC-083; architecture.md §2.3, §3.1, §4, §19.3, §19.26 A1, T48; network.md §3.3, §4.4; data.md §2.2;
-- TASK-021, TASK-050). Run place only.
-- Single writer of Cash and Drawer (Economy set, record 1). Others call:
--   Spend(amount, player?)        purchases (Mart, bench, trailer); atomic check-and-debit, never below 0
--   AddToDrawer(amount, kind)     order price / tip / thief caught ("Catch"); while the drawer is open
--   Steal(amount)                 thief (FEAT-013): takes up to the drawer, counted in the ledger's Stolen
--   CountArrival(), CountResult() ledger for the grade (CustomerService, TASK-032/033)
--   AddReportStep(name, fn)       fills ShiftReport fields of other features before it is sent (T48)
--   Collect()                     "Collect Cash" (Q-201): drawer -> Cash now; the ledger remembers it for the report
--   TopUp(amount)                 first-run tutorial: Cash up to at least amount (TutorialService, Provisional)
-- Payments go to the drawer, never to Cash (DEC-050): Cash only changes by Spend, Collect, the deposit, TopUp and DevAddCash.
-- Deposit on RoundService.ShiftEnded (start of Summary): grade A-D, bonus floor(day take x %), Cash += drawer left + bonus,
-- Drawer = 0, report steps, ShiftReport to the group, Reported(info, report).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Charm = require(ReplicatedStorage.Packages.Charm)
local Content = require(ReplicatedStorage.shared.Content)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Ledger = require(script.Ledger)
local Modux = require(ServerScriptService.server.Modux)

export type Grade = Ledger.Grade
export type SaleResult = Ledger.SaleResult
export type DrawerKind = Ledger.DrawerKind

-- ShiftReport packet (network.md §4.4), also handed to Reported listeners
export type Report = Ledger.Report

export type ShiftInfo = { Day: number, Night: number, IsNight: boolean, Attempt: number }

-- Report step (T48): fills Gems, AfkLocked, LastChanceUsed (reads the rest). No yield; an error becomes a warn.
export type ReportStep = (info: ShiftInfo, report: Report) -> ()
type Step = { Name: string, Run: ReportStep }

const RECORD = 1 -- Economy is a single record (network.md §3.3)
const CASH_MAX = 2147483647 -- Economy.Cash wire range
const DRAWER_MAX = 1000000 -- Economy.Drawer / ShiftReport.Drawer wire range
const COUNT_MAX = 999 -- ShiftReport.Arrived/Completed wire range
const TIPS_MAX = 100000 -- ShiftReport.Tips wire range
const GEMS_MAX = 1000 -- ShiftReport.Gems wire range
const BOSS_STAT = "BossBonusPP" -- Content.Stats (Shift Lead, Party scope, not stacking; DEC-069)
-- Closing: sign CLOSED but the queue is still served, so the drawer and the ledger still take entries (DEC-048)
const CLOSING = "Closing"
const KINDS: { [string]: boolean } = { Sale = true, Tip = true, Catch = true }
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
end

-- Reads -----------------------------------------------------------------------------------------------------------

function EconomyService:GetCash(): number
	return self.Cash()
end

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

-- Drawer and ledger take entries: a selling phase or Closing (queue still served)
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
		end
		return false
	end
	self.Cash(cash - value)
	return true
end

-- Money into the drawer (DEC-050). Only while the shop runs; returns what actually went in (0 when refused).
function EconomyService:AddToDrawer(amount: number, kind: DrawerKind): number
	const value = amountOf(amount)
	if value == nil then
		fail(`[EconomyService] AddToDrawer: amount must be a non-negative integer, got {amount}`)
		return 0
	end
	if not KINDS[kind] then
		fail(`[EconomyService] AddToDrawer: unknown kind {kind}`)
		return 0
	end
	if not self:IsDrawerOpen() then
		warn(`[EconomyService] AddToDrawer({value}, {kind}) outside a selling phase or Closing ignored`)
		return 0
	end
	const drawer = self.Drawer()
	const added = math.min(value, DRAWER_MAX - drawer)
	if added <= 0 then
		return 0
	end
	self.Drawer(drawer + added)
	Ledger.credit(self.Shift, kind, added)
	return added
end

-- Thief (FEAT-013): takes up to the drawer, adds it to the ledger's Stolen, returns what was taken. The amount
-- (floor(Drawer x StealPct / 100) when Drawer >= MinDrawer) is ThiefService's call, from Content.
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

-- "Collect Cash" (user playtest 2026-10-11, Provisional Q-201): everything in the drawer goes to Cash right now, so the
-- crew can buy ingredients mid-shift. Same drawer rules as AddToDrawer (selling phase or Closing). The ledger keeps
-- the amount (Collected), so the report and the grade bonus still count the whole day take. Returns what moved (0 =
-- nothing: empty drawer, drawer closed, Cash at its cap).
function EconomyService:Collect(): number
	if not self:IsDrawerOpen() then
		return 0
	end
	const drawer = self.Drawer()
	const cash = self.Cash()
	const moved = math.min(drawer, CASH_MAX - cash)
	if moved <= 0 then
		return 0
	end
	self.Libs.Charm.batch(function()
		self.Cash(cash + moved)
		self.Drawer(drawer - moved)
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

-- Outcome of a customer that arrived (Perfect/Complete = satisfied, DEC-051). Money goes through AddToDrawer.
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

-- Start of Summary (RoundService.ShiftEnded): grade, bonus, deposit, report. Drawer and ledger end at zero.
function EconomyService:Deposit(info: ShiftInfo): Report
	const ledger = self.Shift
	const drawer = self.Drawer()
	const settlement = Ledger.settle(ledger, drawer, self:BossPoints())

	self.Libs.Charm.batch(function()
		-- what was collected during the shift is already in Cash (Collect)
		self.Cash(math.min(self.Cash() + settlement.Deposited - ledger.Collected, CASH_MAX))
		self.Drawer(0)
	end)

	const report: Report = {
		Day = info.Day,
		Night = info.Night,
		IsNight = info.IsNight,
		Arrived = math.min(ledger.Arrived, COUNT_MAX),
		Completed = math.min(ledger.Completed, COUNT_MAX),
		Drawer = math.min(drawer + ledger.Collected, DRAWER_MAX), -- day take: collected + still in the drawer
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

-- New shift: ledger and drawer start empty (data.md §2.2). A drawer that is not empty here skipped its Summary
-- (DevSetDay mid-shift): discarded like a lost night's drawer (FEAT-012), with a warning.
function EconomyService:BeginShift()
	if self.Drawer() > 0 then
		warn(`[EconomyService] shift started with ${self.Drawer()} in the drawer (no Summary): discarded`)
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
