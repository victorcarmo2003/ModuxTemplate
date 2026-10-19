--!strict
-- Hot dog grade of the world kitchen (docs/tech/kitchen-world.md §4; DEC-306, DEC-308; TASK-569). Exported by Content as Prep.
-- The focused prep mode and the conveyor are gone (TASK-581): only what src/Prep/shared/Grade.luau reads is left here.
-- Pure data, Provisional numbers until the owner's Play (kitchen-world.md header).
--   band of a served plate (Grade.Assembly):
--     Perfect  the toppings are exactly the order's AND the plate was ready within Assembly.PerfectTime s of the ticket
--              (minus Assembly.PerPlayer s per player over the first, never under Assembly.PerfectMin)
--     Good     the toppings are exactly the order's
--     Messy    a topping missing or extra (the customer takes it, no tip)
--   flip bonus (DEC-298): a sausage flipped inside Restaurant.Grill.FlipFrom..FlipTo lifts Good to Perfect
--   tip: Grades.Effects[band] (Grade.SaleEffect; DEC-305: Perfect = base tip + TipExtra)
local Table = require(script.Parent.Table)

export type Band = "Perfect" | "Good" | "Messy"

export type Grades = {
	Points: { Perfect: number, Good: number, Messy: number },
	-- Tip nil = the taker's base tip (OrderRules.TipAmount), 0 = no tip; TipExtra = $ added to the base tip (DEC-305)
	Effects: { [Band]: { Tip: number?, TipExtra: number?, TipWindow: number, Mood: number } },
	Labels: { [Band]: string },
}

export type Assembly = {
	PerfectTime: number, -- s from the ticket to the hand-over for a Perfect, solo
	PerPlayer: number, -- s taken off PerfectTime per player over the first
	PerfectMin: number, -- s: PerfectTime never drops under this
}

const grades: Grades = {
	Points = { Perfect = 100, Good = 70, Messy = 30 }, -- FEAT-039
	Effects = {
		-- Q-219 B: only tip and mood, never the price. DEC-305: Perfect = base + $1
		Perfect = { TipExtra = 1, TipWindow = 4, Mood = 0 },
		Good = { TipWindow = 0, Mood = 0 },
		Messy = { Tip = 0, TipWindow = 0, Mood = -1 },
	},
	Labels = { Perfect = "Perfect!", Good = "Good", Messy = "Messy" },
}

const assembly: Assembly = { PerfectTime = 45, PerPlayer = 5, PerfectMin = 25 } -- kitchen-world.md §4 (Provisional)

return Table.record({
	Grades = grades,
	Assembly = assembly,
	Bands = { "Perfect", "Good", "Messy" } :: { Band },
})
