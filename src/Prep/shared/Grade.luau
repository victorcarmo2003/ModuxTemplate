--!strict
-- Hot dog grade of the world kitchen (docs/tech/kitchen-world.md §4; DEC-306, DEC-308; TASK-569). ReplicatedStorage.shared.Prep.Grade.
-- Pure: no Modux, Lync, Vide nor self.Libs; every function takes the numbers (Content.Prep, or a table of the same shape) so a
-- test can feed its own. The gesture grading of the focused prep mode (Score, CoverageError, Plausible, FlipScore) left with it
-- (TASK-581).
--   Band(score)          0..100 points -> band (Grades.Points thresholds)
--   Points(band)         band -> points
--   PerfectTime(players) seconds a plate may take from the ticket and still be Perfect
--   Assembly(...)        served plate -> band (server, at the hand-over)
--   SaleEffect(band)     band -> tip effect of the sale (CustomerService, Orders.TipFor)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PrepContent = require(ReplicatedStorage.shared.Content.Prep)

export type Band = PrepContent.Band

-- Only what the math reads; Content.Prep satisfies it
export type Config = {
	Grades: PrepContent.Grades,
	Assembly: PrepContent.Assembly,
}

-- What Assembly reads of a plate: the toppings on it (any order) and whether its sausage was flipped in the window
export type Plate = { Toppings: { string }, Flipped: boolean }

-- What a served plate does to the tip of a Complete sale (Orders.TipFor reads it):
--   Tip       nil = the taker's base tip, 0 = no base tip
--   Extra     $ added on top of that, inside the same window
--   TipWindow seconds added to the tip window; Mood = mood bands (Messy -1)
export type SaleEffect = { Tip: number?, Extra: number, TipWindow: number, Mood: number }

const Grade = {}

-- Points -> band: the band whose points the score reaches (Perfect >= Points.Perfect, Good >= Points.Good).
function Grade.Band(cfg: Config, score: number): Band
	const points = cfg.Grades.Points
	if score >= points.Perfect then
		return "Perfect"
	elseif score >= points.Good then
		return "Good"
	end
	return "Messy"
end

function Grade.Points(cfg: Config, band: Band): number
	const points = cfg.Grades.Points
	if band == "Perfect" then
		return points.Perfect
	elseif band == "Good" then
		return points.Good
	end
	return points.Messy
end

-- Seconds from the ticket to the hand-over that still allow a Perfect: PerfectTime solo, PerPlayer less per player over the
-- first, never under PerfectMin.
function Grade.PerfectTime(cfg: Config, players: number?): number
	const rules = cfg.Assembly
	const extra = math.max(math.floor(players or 1) - 1, 0)
	return math.max(rules.PerfectTime - rules.PerPlayer * extra, rules.PerfectMin)
end

-- True when `toppings` holds exactly the keys of `order` (no repeat, nothing missing, nothing extra; order of addition free).
function Grade.Exact(order: { string }, toppings: { string }): boolean
	if #order ~= #toppings then
		return false
	end
	const wanted: { [string]: boolean } = {}
	for _, key in order do
		wanted[key] = true
	end
	const seen: { [string]: boolean } = {}
	for _, key in toppings do
		if not wanted[key] or seen[key] then
			return false
		end
		seen[key] = true
	end
	return true
end

-- Band of a served plate (kitchen-world.md §4). `order` = the toppings of the ticket line, `seconds` = from the ticket to the
-- hand-over (server clock; NaN or negative = not timed: never Perfect by time), `players` = active players of the run.
--   exact and in time = Perfect; exact = Good, lifted to Perfect by the flip bonus (DEC-298); anything else = Messy.
function Grade.Assembly(cfg: Config, order: { string }, plate: Plate, seconds: number, players: number?): Band
	if not Grade.Exact(order, plate.Toppings) then
		return "Messy"
	end
	const timed = seconds == seconds and seconds >= 0
	if (timed and seconds <= Grade.PerfectTime(cfg, players)) or plate.Flipped then
		return "Perfect"
	end
	return "Good"
end

-- Sale effect of a band (Q-219 B, DEC-305): Messy = no tip and one mood band worse; Perfect = base tip + TipExtra; band nil
-- (a hot dog with no grade) = nil, the base tip as before.
function Grade.SaleEffect(cfg: Config, band: Band?): SaleEffect?
	if band == nil then
		return nil
	end
	const effect = cfg.Grades.Effects[band]
	const fixed = effect.Tip
	return {
		Tip = if fixed ~= nil and fixed <= 0 then 0 else nil,
		Extra = math.max(effect.TipExtra or 0, 0),
		TipWindow = effect.TipWindow,
		Mood = effect.Mood,
	}
end

return table.freeze(Grade)
