--!strict
-- Order phases and rules (content-data.md §3.16; FEAT-010, FEAT-011, FEAT-014; DEC-051, DEC-071, DEC-072).
-- Exported by Content as OrderPhases (this table) and OrderRules (.Rules).
-- Formulas live in the services; this table only holds their parameters (rule §1.3.3):
--   price    = BasePrice + sum(Ingredients[k].OrderPrice)                      (DEC-071)
--   tip      = TipAmount if Complete within TipWindowBase + TipWindowPerK x K s (DEC-072)
--   patience = PatienceBase + PatiencePerK x K + Counter PatienceBonus s        (DEC-072, DEC-046)
--   incomplete pays floor(price x IncompletePct / 100), no tip                  (DEC-072)
-- Ingredient weights are Ingredients[k].Weight (DEC-071); x NewIngredientBoost if unlocked today (FEAT-010).
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

-- K distribution per phase (FEAT-010 table; DEC-071, proposals-round-2 §3.4). Endless days use day_6_plus.
const base = Table.new({
	{ Key = "day_1", FromDay = 1, ToDay = 1, IsNight = false, KWeights = { 0.10, 0.60, 0.30, 0.00 } }, -- mean K 1.2
	{ Key = "day_2_3", FromDay = 2, ToDay = 3, IsNight = false, KWeights = { 0.05, 0.45, 0.40, 0.10 } }, -- 1.55
	{ Key = "day_4_5", FromDay = 4, ToDay = 5, IsNight = false, KWeights = { 0.05, 0.35, 0.40, 0.20 } }, -- 1.75
	{ Key = "day_6_plus", FromDay = 6, ToDay = 0, IsNight = false, KWeights = { 0.00, 0.30, 0.40, 0.30 } }, -- 2.0
	{ Key = "night", FromDay = 1, ToDay = 0, IsNight = true, KWeights = { 0.00, 0.30, 0.40, 0.30 } }, -- 2.0, wave 2
} :: { OrderPhase })

const rules: OrderRules = {
	BasePrice = 4, -- bun + sausage (DEC-071)
	MaxToppings = 3, -- DEC-071
	NewIngredientBoost = 1.5, -- weight x1.5 on the unlock day (FEAT-010)
	TipAmount = 1, -- fixed $1 (DEC-072); class modifiers via Stat TipAmount (DEC-069)
	TipWindowBase = 16, -- 16 + 4K s (DEC-072)
	TipWindowPerK = 4,
	PatienceBase = 40, -- 40 + 5K s (DEC-072)
	PatiencePerK = 5,
	IncompletePct = 50, -- floor(50%) (DEC-072)
	GradeThresholds = { A = 0.90, B = 0.75, C = 0.50 }, -- satisfied share (DEC-051, FEAT-014)
	GradeBonusPct = { A = 20, B = 10, C = 0, D = 0 }, -- boss bonus, % of the drawer, floored (DEC-051, FEAT-014)
	NoCustomerGrade = "C", -- no customer at the counter = C (FEAT-014, DEC-051)
}

return Table.with(base, {
	Rules = Table.record(rules),
})
