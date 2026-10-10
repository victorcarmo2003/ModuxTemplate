--!strict
-- Order phases and rules (content-data.md §3.16; FEAT-010, FEAT-011; DEC-051, DEC-071, DEC-072).
-- Exported by Content as OrderPhases (this table) and OrderRules (.Rules).
-- STUB (TASK-003): values from FEAT-010 and content-data.md v4; reviewed in TASK-008.
local Table = require(script.Parent.Table)

export type OrderPhase = {
	Key: string,
	FromDay: number,
	ToDay: number, -- 0 = no upper bound
	IsNight: boolean,
	KWeights: { number }, -- chance of K = 0, 1, 2, 3 toppings (sums to 1)
}

export type Grade = "A" | "B" | "C" | "D"

export type OrderRules = {
	BasePrice: number,
	MaxToppings: number,
	NewIngredientBoost: number,
	TipAmount: number,
	TipWindowBase: number,
	TipWindowPerK: number,
	PatienceBase: number,
	PatiencePerK: number,
	IncompletePct: number, -- floor
	GradeThresholds: { A: number, B: number, C: number },
	GradeBonusPct: { [Grade]: number },
	NoCustomerGrade: Grade, -- DEC-051
}

const base = Table.new({
	{ Key = "day_1", FromDay = 1, ToDay = 1, IsNight = false, KWeights = { 0.10, 0.60, 0.30, 0.00 } },
	{ Key = "day_2_3", FromDay = 2, ToDay = 3, IsNight = false, KWeights = { 0.05, 0.45, 0.40, 0.10 } },
	{ Key = "day_4_5", FromDay = 4, ToDay = 5, IsNight = false, KWeights = { 0.05, 0.35, 0.40, 0.20 } },
	{ Key = "day_6_plus", FromDay = 6, ToDay = 0, IsNight = false, KWeights = { 0.00, 0.30, 0.40, 0.30 } },
	{ Key = "night", FromDay = 1, ToDay = 0, IsNight = true, KWeights = { 0.00, 0.30, 0.40, 0.30 } },
} :: { OrderPhase })

const rules: OrderRules = {
	BasePrice = 4,
	MaxToppings = 3,
	NewIngredientBoost = 1.5,
	TipAmount = 1,
	TipWindowBase = 16,
	TipWindowPerK = 4,
	PatienceBase = 40,
	PatiencePerK = 5,
	IncompletePct = 50,
	GradeThresholds = { A = 0.90, B = 0.75, C = 0.50 },
	GradeBonusPct = { A = 20, B = 10, C = 0, D = 0 },
	NoCustomerGrade = "C",
}

return Table.with(base, {
	Rules = Table.record(rules),
})
