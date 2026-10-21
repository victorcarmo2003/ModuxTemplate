--!strict
-- Shift ledger and settlement math (FEAT-012, FEAT-014; DEC-051, DEC-072). Pure: no Modux, no network, no atoms.
-- EconomyService keeps one Ledger per shift and calls Settle at the start of Summary. Numbers come from
-- Content.OrderRules (GradeThresholds, GradeBonusPct, NoCustomerGrade); nothing here is a design number.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

export type Grade = "A" | "B" | "C" | "D"
export type SaleResult = "Perfect" | "Complete" | "Incomplete" | "Wrong" | "Left" | "Refused" | "Slow"
-- Where shift money comes from: order price and tip. Sale goes straight to Cash (DEC-238, EconomyService:AddSale); Tip
-- goes to the tip jar (DEC-239, AddTip)
export type SaleKind = "Sale"
export type DrawerKind = "Sale" | "Tip"

-- Shift counters (architecture.md §2.3 "ledger do turno"; data.md §2.2: zeroed every shift, never in the snapshot)
export type Ledger = {
	Arrived: number, -- customers that reached the counter (FEAT-014 denominator)
	Served: number, -- hot dogs accepted: Perfect + Complete + Incomplete
	Completed: number, -- Perfect + Complete (= satisfied, DEC-051); anti-AFK base (DEC-083)
	Sales: number, -- $ from orders
	Tips: number, -- $ from tips (DEC-072)
	Collected: number, -- $ of tips moved from the jar to Cash during the shift ("Collect Tips", DEC-239); informative
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
	Take: number, -- the day take: Sales + Tips (the base of the bonus, DEC-051)
	Bonus: number,
	Deposited: number, -- Take + Bonus (the report line; Cash already holds the sales and the collected tips)
}

const Ledger = {}

function Ledger.new(): Ledger
	return { Arrived = 0, Served = 0, Completed = 0, Sales = 0, Tips = 0, Collected = 0 }
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
	else
		ledger.Tips += amount
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

-- Bonus = floor(day take x %) (FEAT-014); the day take = Sales + Tips, the same number the old drawer
-- gave (DEC-238, DEC-239: sales go to Cash and tips to the jar, but the grade bonus does not depend on where or when the
-- crew collected). bossPoints = party BossBonusPP (Shift Lead, +5, not stacking); FEAT-014 table: it adds to A/B/C and
-- never to D (D stays 0% and triggers the boss line). Pure: the caller adds the tips left in the jar to Cash.
function Ledger.settle(ledger: Ledger, bossPoints: number): Settlement
	const grade = Ledger.grade(ledger.Arrived, ledger.Completed)
	local pct = Content.OrderRules.GradeBonusPct[grade] or 0
	if grade ~= "D" then
		pct += math.max(bossPoints, 0)
	end
	const take = math.max(ledger.Sales + ledger.Tips, 0)
	const bonus = math.floor(take * pct / 100)
	return { Grade = grade, BonusPct = pct, Take = take, Bonus = bonus, Deposited = take + bonus }
end

return Ledger
