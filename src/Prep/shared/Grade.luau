--!strict
-- Hot dog grade of the world kitchen and of the cooking focus (docs/tech/kitchen-world.md §4, kitchen-focus.md §3; DEC-306, DEC-308;
-- TASK-569). ReplicatedStorage.shared.Prep.Grade. Pure: no Modux, Lync, Vide nor self.Libs; every function takes the numbers
-- (Content.Prep, or a table of the same shape) so a test can feed its own. The client scores a gesture with Score (the pip it
-- shows) and the server bands the plate with Assembly.
--   Score(cfg, key, a, b?) raw measure of a gesture -> 0..100 (Tolerances row `key`; sauces: coverage a, excess b)
--   Band(score)            0..100 score -> band (Grades.Bands thresholds)
--   Points(band)           band -> points
--   PerfectTime(players)   seconds a plate may take from the ticket and still be Perfect
--   Assembly(...)          served plate -> band (server, at the hand-over)
--   SaleEffect(band)       band -> tip effect of the sale (CustomerService, Orders.TipFor)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PrepContent = require(ReplicatedStorage.shared.Content.Prep)

export type Band = PrepContent.Band
export type Tolerance = PrepContent.Tolerance

-- Only what the math reads; Content.Prep satisfies it
export type Config = {
	Grades: PrepContent.Grades,
	Assembly: PrepContent.Assembly,
	read Tolerances: { read ByKey: { [string]: Tolerance } },
}

-- What Assembly reads of a plate: the toppings on it (any order), whether its sausage was flipped in the window, and the
-- gesture scores of the cooking focus (cut, dog, flip, one per topping; nil or empty = a plate made without the focus)
export type Plate = { Toppings: { string }, Flipped: boolean, Scores: { [string]: number }? }

-- What a served plate does to the tip of a Complete sale (Orders.TipFor reads it):
--   Tip       nil = the taker's base tip, 0 = no base tip
--   Extra     $ added on top of that, inside the same window
--   TipWindow seconds added to the tip window; Mood = mood bands (Messy -1)
export type SaleEffect = { Tip: number?, Extra: number, TipWindow: number, Mood: number }

const Grade = {}

local function clamp(value: number, low: number, high: number): number
	return math.max(low, math.min(high, value))
end

local function lerp(from: number, to: number, alpha: number): number
	return from + (to - from) * alpha
end

-- Raw error of a sauce stroke: the worse of the missing coverage and the weighted excess (both in %).
function Grade.CoverageError(tolerance: Tolerance, coverage: number, excess: number): number
	return math.max(100 - clamp(coverage, 0, 100), math.max(0, excess) * tolerance.ExcessWeight)
end

-- Raw error -> integer score 0..100 through (0, 100), (Perfect, Bands.Perfect), (Good, Bands.Good), (Worst, 0). Floor, so an
-- error just over a limit never rounds back up into the better band.
function Grade.Raw(cfg: Config, tolerance: Tolerance, rawError: number): number
	const bands = cfg.Grades.Bands
	const miss = if rawError ~= rawError then math.huge else math.max(0, rawError)
	local score: number
	if miss <= tolerance.Perfect then
		score = lerp(100, bands.Perfect, miss / tolerance.Perfect)
	elseif miss <= tolerance.Good then
		score = lerp(bands.Perfect, bands.Good, (miss - tolerance.Perfect) / (tolerance.Good - tolerance.Perfect))
	elseif miss <= tolerance.Worst then
		score = lerp(bands.Good, 0, (miss - tolerance.Good) / (tolerance.Worst - tolerance.Good))
	else
		score = 0
	end
	return clamp(math.floor(score), 0, 100)
end

-- Score of a gesture against the Tolerances row `key`: sauces (gesture trace) give coverage `a` and excess `b`, every other
-- gesture one raw error `a`. Unknown key = 0.
function Grade.Score(cfg: Config, key: string, a: number, b: number?): number
	const tolerance = cfg.Tolerances.ByKey[key]
	if tolerance == nil then
		return 0
	end
	const raw = if tolerance.Gesture == "trace" then Grade.CoverageError(tolerance, a, b or 0) else a
	return Grade.Raw(cfg, tolerance, raw)
end

-- Score -> band (Perfect >= Bands.Perfect, Good >= Bands.Good).
function Grade.Band(cfg: Config, score: number): Band
	const bands = cfg.Grades.Bands
	if score >= bands.Perfect then
		return "Perfect"
	elseif score >= bands.Good then
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

-- Mean of the gesture scores a plate needs: the cut, the sausage in the bun, the flip (Unflipped when never flipped) and one per
-- topping of the order (0 when missing).
function Grade.Mean(cfg: Config, order: { string }, scores: { [string]: number }): number
	local total, count = 0, 0
	local function add(value: number?, fallback: number)
		total += clamp(if value ~= nil and value == value then value else fallback, 0, 100)
		count += 1
	end
	add(scores.cut, 0)
	add(scores.dog, 0)
	add(scores.flip, cfg.Grades.Unflipped)
	for _, key in order do
		add(scores[key], 0)
	end
	return total / count
end

-- Band of a served plate (kitchen-world.md §4, kitchen-focus.md §3). `order` = the toppings of the ticket line, `seconds` = from
-- the ticket to the hand-over (server clock; NaN or negative = not timed: never Perfect), `players` = active players of the run.
--   toppings not exactly the order's = Messy.
--   with gesture scores (the cooking focus): the band of their mean (Grade.Mean); a Perfect slower than PerfectTime = Good.
--   without (a plate made without the focus): in time = Perfect, else Good, lifted to Perfect by the flip bonus (DEC-298).
function Grade.Assembly(cfg: Config, order: { string }, plate: Plate, seconds: number, players: number?): Band
	if not Grade.Exact(order, plate.Toppings) then
		return "Messy"
	end
	const timed = seconds == seconds and seconds >= 0
	const inTime = timed and seconds <= Grade.PerfectTime(cfg, players)
	const scores = plate.Scores
	if scores ~= nil and next(scores) ~= nil then
		const band = Grade.Band(cfg, Grade.Mean(cfg, order, scores))
		return if band == "Perfect" and not inTime then "Good" else band
	end
	if inTime or plate.Flipped then
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
