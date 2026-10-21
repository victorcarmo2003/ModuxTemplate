--!strict
-- Hot dog grade and the gestures of the cooking focus (docs/tech/kitchen-focus.md §3; docs/tech/kitchen-world.md §4; DEC-306,
-- DEC-308; owner 2026-10-19: "precisão conta"). Exported by Content as Prep. Pure data, Provisional numbers.
--   gesture score: raw error of a gesture (Tolerances row, lower is better) -> 0..100, piecewise line through
--     (0 -> 100), (Perfect -> Grades.Bands.Perfect), (Good -> Grades.Bands.Good), (Worst -> 0)   (Grade.Score)
--   band of a served plate (Grade.Assembly):
--     Messy    a topping missing or extra (the customer takes it, no tip)
--     else     the mean of the plate's gesture scores (Scores attribute: cut, dog, flip, one per topping) -> Perfect >=
--              Bands.Perfect, Good >= Bands.Good, else Messy; a Perfect slower than Assembly.PerfectTime is lowered to Good
--   tip: Grades.Effects[band] (Grade.SaleEffect; DEC-305: Perfect = base tip + TipExtra)
-- The bun space of the gestures: x 0..1 along the bun (left to right on screen), y 0..1 across it, Build.Aspect = length / width.
local Table = require(script.Parent.Table)

export type Band = "Perfect" | "Good" | "Messy"

export type Grades = {
	Points: { Perfect: number, Good: number, Messy: number },
	Bands: { Perfect: number, Good: number }, -- minimum 0..100 score of each band
	Unflipped: number, -- flip score of a sausage never flipped
	-- Tip nil = the taker's base tip (OrderRules.TipAmount), 0 = no tip; TipExtra = $ added to the base tip (DEC-305)
	Effects: { [Band]: { Tip: number?, TipExtra: number?, TipWindow: number, Mood: number } },
	Labels: { [Band]: string },
}

export type Assembly = {
	PerfectTime: number, -- s from the ticket to the hand-over for a Perfect, solo
	PerPlayer: number, -- s taken off PerfectTime per player over the first
	PerfectMin: number, -- s: PerfectTime never drops under this
}

-- One gesture tolerance (key = bun_cut, sausage_place, grill_flip or an Ingredients topping)
export type Tolerance = {
	Key: string,
	Gesture: string, -- slice | place | trace | flip
	Perfect: number, -- largest raw error that still scores Perfect
	Good: number, -- largest raw error that still scores Good
	Worst: number, -- raw error where the score reaches 0
	ExcessWeight: number, -- sauces only: error = max(100 - coverage, excess x this); 0 elsewhere
}

-- Geometry of the gestures in the bun space (the old prep's Build, kept)
export type Build = {
	Aspect: number,
	Cut: { Y: number, From: number, To: number, MinPoints: number },
	Groove: { X: number, Y: number },
	Sauce: { Path: { { X: number, Y: number } }, Reach: number, Spill: number, MinPoints: number, MaxPoints: number },
	DropSlack: number, -- bun-space share outside the bun a drop still lands
}

const grades: Grades = {
	Points = { Perfect = 100, Good = 70, Messy = 30 }, -- FEAT-039
	Bands = { Perfect = 85, Good = 55 },
	Unflipped = 0,
	Effects = {
		-- Q-219 B: only tip and mood, never the price. DEC-305: Perfect = base + $1
		Perfect = { TipExtra = 1, TipWindow = 4, Mood = 0 },
		Good = { TipWindow = 0, Mood = 0 },
		Messy = { Tip = 0, TipWindow = 0, Mood = -1 },
	},
	Labels = { Perfect = "Perfect!", Good = "Good", Messy = "Messy" },
}

const assembly: Assembly = { PerfectTime = 60, PerPlayer = 5, PerfectMin = 35 } -- longer than the world kitchen's 45: gestures take time

-- FEAT-039 tables (Provisional, Q-219), the old prep's numbers:
--   bun_cut        mean lateral deviation from the guide, % of the bun width, + the % of the line not crossed
--   sausage_place  distance of the drop to the groove, % of the bun length
--   sauces         max(100 - coverage %, excess % x ExcessWeight)
--   solids         distance of the drop to the middle of the bun, % of the bun length (cheese, bacon, potato sticks)
--   grill_flip     % of the cook time away from the middle of the flip window (Restaurant.Grill.FlipFrom..FlipTo)
const tolerances = Table.new({
	{ Key = "bun_cut", Gesture = "slice", Perfect = 6, Good = 15, Worst = 40, ExcessWeight = 0 },
	{ Key = "sausage_place", Gesture = "place", Perfect = 10, Good = 22, Worst = 60, ExcessWeight = 0 },
	{ Key = "grill_flip", Gesture = "flip", Perfect = 10, Good = 25, Worst = 60, ExcessWeight = 0 },
	{ Key = "ketchup", Gesture = "trace", Perfect = 15, Good = 40, Worst = 80, ExcessWeight = 1.5 },
	{ Key = "mustard", Gesture = "trace", Perfect = 15, Good = 40, Worst = 80, ExcessWeight = 1.5 },
	{ Key = "cream_cheese", Gesture = "trace", Perfect = 15, Good = 40, Worst = 80, ExcessWeight = 1.5 },
	{ Key = "cheese", Gesture = "place", Perfect = 12, Good = 25, Worst = 60, ExcessWeight = 0 },
	{ Key = "bacon", Gesture = "place", Perfect = 12, Good = 25, Worst = 60, ExcessWeight = 0 },
	{ Key = "potato_sticks", Gesture = "place", Perfect = 12, Good = 25, Worst = 60, ExcessWeight = 0 },
} :: { Tolerance })

const build: Build = {
	Aspect = 2.5,
	Cut = { Y = 0.5, From = 0.04, To = 0.96, MinPoints = 6 },
	Groove = { X = 0.5, Y = 0.5 },
	-- DEC-311: an S wave (one and a half periods) along the hot dog, drawn as white arrows that curve over the sausage
	Sauce = {
		Path = {
			{ X = 0.08, Y = 0.50 },
			{ X = 0.16, Y = 0.74 },
			{ X = 0.24, Y = 0.79 },
			{ X = 0.32, Y = 0.62 },
			{ X = 0.40, Y = 0.38 },
			{ X = 0.48, Y = 0.21 },
			{ X = 0.56, Y = 0.26 },
			{ X = 0.64, Y = 0.50 },
			{ X = 0.72, Y = 0.74 },
			{ X = 0.80, Y = 0.79 },
			{ X = 0.88, Y = 0.62 },
			{ X = 0.94, Y = 0.44 },
		},
		Reach = 0.15,
		Spill = 0.4,
		MinPoints = 6,
		MaxPoints = 64,
	},
	DropSlack = 0.15,
}

return Table.record({
	Grades = grades,
	Assembly = assembly,
	Tolerances = tolerances,
	Build = build,
	Bands = { "Perfect", "Good", "Messy" } :: { Band },
})
