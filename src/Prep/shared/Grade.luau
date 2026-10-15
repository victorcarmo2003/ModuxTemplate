--!strict
-- Prep grading (docs/tech/prep-mode.md §2, §3; FEAT-039). ReplicatedStorage.shared.Prep.Grade. Pure: no Modux, Lync, Vide nor
-- self.Libs; every function takes the numbers (Content.Prep, or a table of the same shape) so the client score preview
-- and the server verdict use the same math and the table tests can feed their own tolerances.
--   Score(tolerance, error)   raw error of a gesture -> 0..100 score (client, after the gesture)
--   Band(score)               score -> Perfect / Good / Messy (server, from the wire score)
--   Plate(stages, ...)        stage scores + plate time -> plate band (server, at PrepFinish)
--   Plausible(...)            floors on the server clock and on the client Ms (server)
--   FlipScore(...)            sausage flip score from the server timestamps (server)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PrepContent = require(ReplicatedStorage.shared.Content.Prep)

export type Band = PrepContent.Band
export type Tolerance = PrepContent.Tolerance

-- Only what the math reads; Content.Prep satisfies it
export type Config = {
	Rules: PrepContent.Rules,
	Grades: PrepContent.Grades,
}

export type Stages = {
	Cut: number,
	Place: number,
	Toppings: { number }, -- one score per topping
	Sausage: number?, -- grill flip score stamped by the server (nil = not graded, e.g. a parked plate)
}

export type PlateResult = {
	Band: Band,
	Average: number, -- mean of the stage points
	Capped: boolean, -- true when a Perfect was lowered to Good by the time floor
	Stages: number, -- how many stages counted
}

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

-- Raw error -> integer score 0..100, piecewise linear through (0, 100), (Perfect, Bands.Perfect), (Good, Bands.Good),
-- (Worst, 0). The limits are scaled by Rules.Assist when assist is on. Floor, so an error just over a limit never rounds
-- back up into the better band.
function Grade.Score(cfg: Config, tolerance: Tolerance, rawError: number, assist: boolean?): number
	const scale = if assist then cfg.Rules.Assist else 1
	const perfect = tolerance.Perfect * scale
	const good = tolerance.Good * scale
	const worst = tolerance.Worst * scale
	const bands = cfg.Grades.Bands
	const miss = if rawError ~= rawError then math.huge else math.max(0, rawError)
	local score: number
	if miss <= perfect then
		score = lerp(100, bands.Perfect, miss / perfect)
	elseif miss <= good then
		score = lerp(bands.Perfect, bands.Good, (miss - perfect) / (good - perfect))
	elseif miss <= worst then
		score = lerp(bands.Good, 0, (miss - good) / (worst - good))
	else
		score = 0
	end
	return clamp(math.floor(score), 0, 100)
end

-- Wire score -> band. Scores outside 0..100 or not finite are the caller's to refuse (Plausible / the schema); here they
-- clamp to Messy / Perfect.
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

-- Seconds under which a plate with `toppings` toppings is refused / cannot be Perfect (server clock).
function Grade.MinTime(cfg: Config, toppings: number): number
	return cfg.Rules.MinPlate + cfg.Rules.PerTopping * toppings
end

function Grade.PerfectTime(cfg: Config, toppings: number): number
	return cfg.Rules.PerfectMin + cfg.Rules.PerTopping * toppings
end

-- Plate band from the stage scores. elapsed = seconds on the server clock between PrepBegin and PrepFinish.
-- Perfect needs a mean >= Plate.PerfectAvg with no Messy stage, Good a mean >= Plate.GoodAvg; a Perfect under the time floor
-- is lowered to Good.
function Grade.Plate(cfg: Config, stages: Stages, elapsed: number): PlateResult
	const scores: { number } = { stages.Cut, stages.Place }
	for _, score in stages.Toppings do
		table.insert(scores, score)
	end
	if stages.Sausage ~= nil then
		table.insert(scores, stages.Sausage)
	end
	local total = 0
	local anyMessy = false
	for _, score in scores do
		const band = Grade.Band(cfg, score)
		total += Grade.Points(cfg, band)
		if band == "Messy" then
			anyMessy = true
		end
	end
	const average = total / #scores
	local band: Band
	if average >= cfg.Grades.Plate.PerfectAvg and not anyMessy then
		band = "Perfect"
	elseif average >= cfg.Grades.Plate.GoodAvg then
		band = "Good"
	else
		band = "Messy"
	end
	local capped = false
	if band == "Perfect" and elapsed < Grade.PerfectTime(cfg, #stages.Toppings) then
		band = "Good"
		capped = true
	end
	return { Band = band, Average = average, Capped = capped, Stages = #scores }
end

-- Plausibility of a summary (server): the plate took at least MinTime on the server clock, and the client Ms (milliseconds)
-- does not claim more than the server saw plus MsSlack. Returns ok, reason (a Content.Prep.Reasons key).
function Grade.Plausible(cfg: Config, toppings: number, elapsed: number, clientMs: number): (boolean, string?)
	if elapsed < Grade.MinTime(cfg, toppings) then
		return false, "TooFast"
	end
	if elapsed > cfg.Rules.PlateMax then
		return false, "NoSession"
	end
	if clientMs / 1000 > elapsed + cfg.Rules.MsSlack then
		return false, "Invalid"
	end
	return true, nil
end

-- Seconds of the first side of a sausage of this Duration (the whole cook minus the second side after the flip).
function Grade.FirstSide(cfg: Config, duration: number): number
	return math.max(duration - cfg.Rules.Grill.PostFlip, 0.05)
end

-- Progress 0..1 the world draws for a sausage on the grill, from the record (server clock `now`, StartedAt, Duration, flipped).
-- The first side runs 0 -> Target; the sausage then WAITS there (the flip window is open) until the flip; the second side runs
-- Target -> 1 over PostFlip s. Flipping re-bases StartedAt (the server writes now - FirstSide), so this one formula serves both.
function Grade.CookProgress(cfg: Config, startedAt: number, duration: number, now: number, flipped: boolean): number
	if duration <= 0 then
		return 0
	end
	const first = Grade.FirstSide(cfg, duration)
	const elapsed = math.max(now - startedAt, 0)
	const target = cfg.Rules.Grill.Target
	if elapsed < first then
		return target * elapsed / first
	elseif not flipped then
		return target
	end
	return clamp(target + (1 - target) * (elapsed - first) / cfg.Rules.Grill.PostFlip, target, 1)
end

-- Where the flip cursor is, 0..1 of the bar, at server time `now` (TASK-257): in the pause it goes from the LEFT end to the right
-- end in Rules.Grill.Swing s and back, forever (a triangle wave that starts at 0 the moment the first side is done). Before the
-- pause: 0. The client draws it with this and the server grades with it: one source.
function Grade.SwingAt(cfg: Config, startedAt: number, duration: number, now: number): number
	const reachedAt = startedAt + Grade.FirstSide(cfg, duration)
	const swing = math.max(cfg.Rules.Grill.Swing, 0.05)
	const t = now - reachedAt
	if t <= 0 then
		return 0
	end
	const phase = (t / swing) % 2
	return if phase <= 1 then phase else 2 - phase
end

-- Sausage flip score from the server clock: flippedAt nil = never flipped (Q-222: Messy). In the pause the error is how far the
-- swinging cursor is from the middle when the flip lands, in % of the bar (0 = dead centre, 50 = an end). A flip BEFORE the pause
-- is accepted (TASK-257) with the worst error of the tolerance.
function Grade.FlipScore(cfg: Config, tolerance: Tolerance, startedAt: number, flippedAt: number?, duration: number): number
	if flippedAt == nil or duration <= 0 then
		return cfg.Grades.Unflipped
	end
	const reachedAt = startedAt + Grade.FirstSide(cfg, duration)
	if flippedAt < reachedAt then
		return Grade.Score(cfg, tolerance, tolerance.Worst, false)
	end
	const position = Grade.SwingAt(cfg, startedAt, duration, flippedAt)
	return Grade.Score(cfg, tolerance, math.abs(position - 0.5) * 100, false)
end

-- Effect of a plate band on the sale (Q-219 B): tip in $ (nil = base tip), extra tip window seconds, mood bands.
function Grade.Effect(cfg: Config, band: Band): { Tip: number?, TipWindow: number, Mood: number }
	return cfg.Grades.Effects[band]
end

return table.freeze(Grade)
