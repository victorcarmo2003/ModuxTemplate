--!strict
-- Shift ledger and settlement math (FEAT-012, FEAT-014; DEC-051, DEC-072). Pure: no Modux, no network, no atoms.
-- EconomyService keeps one Ledger per shift and calls Settle at the start of Summary. Numbers come from
-- Content.OrderRules (GradeThresholds, GradeBonusPct, NoCustomerGrade); nothing here is a design number.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

export type Grade = "A" | "B" | "C" | "D"
export type SaleResult = "Perfect" | "Complete" | "Incomplete" | "Wrong" | "Left" | "Refused"
-- Where drawer money comes from: order price, tip, thief caught (+$5 "Nice catch!", FEAT-013: money, not a customer)
export type DrawerKind = "Sale" | "Tip" | "Catch"

-- Shift counters (architecture.md §2.3 "ledger do turno"; data.md §2.2: zeroed every shift, never in the snapshot)
export type Ledger = {
	Arrived: number, -- customers that reached the counter (FEAT-014 denominator)
	Served: number, -- hot dogs accepted: Perfect + Complete + Incomplete
	Completed: number, -- Perfect + Complete (= satisfied, DEC-051); anti-AFK base (DEC-083)
	Sales: number, -- $ from orders
	Tips: number, -- $ from tips (DEC-072)
	Catches: number, -- $ from caught thieves (wave 2)
	Stolen: number, -- $ taken by the thief (wave 1: always 0)
}

-- ShiftReport packet (network.md §4.4)
export type Report = {
	Day: number,
	Night: number,
	IsNight: boolean,
	Arrived: number,
	Completed: number,
	Drawer: number,
	Tips: number,
	Stolen: number,
	Grade: Grade,
	Bonus: number,
	Deposited: number,
	Gems: number,
	AfkLocked: boolean,
	LastChanceUsed: boolean,
}

export type Settlement = {
	Grade: Grade,
	BonusPct: number,
	Bonus: number,
	Deposited: number,
}

const Ledger = {}

function Ledger.new(): Ledger
	return { Arrived = 0, Served = 0, Completed = 0, Sales = 0, Tips = 0, Catches = 0, Stolen = 0 }
end

-- Counts one customer outcome. Left/Refused/Wrong only matter through Arrived (they are not satisfied).
function Ledger.count(ledger: Ledger, result: SaleResult)
	if result == "Perfect" or result == "Complete" then
		ledger.Completed += 1
		ledger.Served += 1
	elseif result == "Incomplete" then
		ledger.Served += 1
	end
end

function Ledger.credit(ledger: Ledger, kind: DrawerKind, amount: number)
	if kind == "Sale" then
		ledger.Sales += amount
	elseif kind == "Tip" then
		ledger.Tips += amount
	else
		ledger.Catches += amount
	end
end

-- Grade by satisfied share = completed / arrived (DEC-051). No customer at the counter = NoCustomerGrade (C).
function Ledger.grade(arrived: number, completed: number): Grade
	const rules = Content.OrderRules
	if arrived <= 0 then
		return rules.NoCustomerGrade
	end
	const share = math.min(completed, arrived) / arrived
	const thresholds = rules.GradeThresholds
	if share >= thresholds.A then
		return "A"
	elseif share >= thresholds.B then
		return "B"
	elseif share >= thresholds.C then
		return "C"
	end
	return "D"
end

-- Bonus = floor(drawer x %) (FEAT-014). bossPoints = party BossBonusPP (Shift Lead, +5, not stacking); FEAT-014
-- table: it adds to A/B/C and never to D (D stays 0% and triggers the boss line).
function Ledger.settle(ledger: Ledger, drawer: number, bossPoints: number): Settlement
	const grade = Ledger.grade(ledger.Arrived, ledger.Completed)
	local pct = Content.OrderRules.GradeBonusPct[grade] or 0
	if grade ~= "D" then
		pct += math.max(bossPoints, 0)
	end
	const bonus = math.floor(drawer * pct / 100)
	return { Grade = grade, BonusPct = pct, Bonus = bonus, Deposited = drawer + bonus }
end

return Ledger
