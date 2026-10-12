--!strict
-- Spec: the table test of the gestures (TASK-176 acceptance): for 10 synthetic inputs per gesture, the 0..100 the gesture
-- module gives is the one Prep/shared/Grade gives for the raw error the input was built to have; plus Assist (x1.3) and the
-- sampling rows. Pure: `cfg` is Content.Prep. The PrepController runs it once when the dev preview opens (`/dev prep ui`,
-- prints "gestures spec: N/N ok") and the same file runs in plain Luau (docs/AGENT-BRIEF.md §3b).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Grade = require(ReplicatedStorage.shared.Prep.Grade)
local hold = require(script.Parent.hold)
local place = require(script.Parent.place)
local slice = require(script.Parent.slice)
local slide = require(script.Parent.slide)
local Score = require(script.Parent.Score)
local taps = require(script.Parent.taps)
local trace = require(script.Parent.trace)

export type Result = { Total: number, Failed: { string } }

const Spec = {}

const ASPECT = 3.1

-- errors that sit clear of the band edges (no float fuzz on a limit)
const BAND_ERRORS = { 0, 3, 5.9, 6.1, 10, 14.9, 15.1, 25, 39, 60 }
const TAP_ERRORS = { 0, 100, 119, 130, 200, 249, 260, 400, 599, 700 }
const SAUCES = { 0, 0.5, 0.8, 0.85, 0.9, 1.0, 1.1, 1.2, 1.3, 1.6 }

function Spec.Run(cfg: Score.Config & { Build: any, Gestures: any }): Result
	const failed: { string } = {}
	local total = 0
	const build = cfg.Build
	local function check(name: string, got: any, want: any)
		total += 1
		if got ~= want then
			table.insert(failed, `{name}: got {tostring(got)}, want {tostring(want)}`)
		end
	end
	local function row(key: string): Grade.Tolerance
		return cfg.Tolerances.ByKey[key]
	end
	local function minPoints(key: string): number
		return cfg.Gestures.ByKey[key].MinPoints
	end

	-- slice: 12 samples across the line, every one `percent` of the width off it
	const sliceParams: slice.Params = { Aspect = ASPECT, Y = build.Cut.Y, From = build.Cut.From, To = build.Cut.To, MinPoints = minPoints("slice") }
	local function cutStroke(percent: number): { any }
		const points: { any } = {}
		for index = 1, 12 do
			table.insert(points, { X = build.Cut.From + (build.Cut.To - build.Cut.From) * (index - 1) / 11, Y = build.Cut.Y + percent / 100 * ASPECT })
		end
		return points
	end
	for _, error in BAND_ERRORS do
		check(`slice {error}`, Score.Value(cfg, "bun_cut", slice.Measure(cutStroke(error), sliceParams), nil, false), Grade.Score(cfg, row("bun_cut"), error, false))
	end
	check("slice too few samples", Score.Value(cfg, "bun_cut", slice.Measure({ { X = 0.1, Y = 0.5 } }, sliceParams), nil, false), 0)
	check("slice a half line costs", slice.Measure({ { X = 0.04, Y = 0.5 }, { X = 0.1, Y = 0.5 }, { X = 0.2, Y = 0.5 }, { X = 0.3, Y = 0.5 }, { X = 0.4, Y = 0.5 }, { X = 0.5, Y = 0.5 }, { X = 0.5, Y = 0.5 }, { X = 0.5, Y = 0.5 } }, sliceParams) > 30, true)
	check("slice assist 7.5 is Perfect", Score.Band(cfg, Score.Value(cfg, "bun_cut", slice.Measure(cutStroke(7.5), sliceParams), nil, true)), "Perfect")
	check("slice no assist 7.5 is Good", Score.Band(cfg, Score.Value(cfg, "bun_cut", slice.Measure(cutStroke(7.5), sliceParams), nil, false)), "Good")

	-- place: dropped `percent` of the bun length from the groove (sideways, then up and down)
	const placeParams: place.Params = { Aspect = ASPECT, X = build.Groove.X, Y = build.Groove.Y, MinPoints = minPoints("place") }
	for index, error in BAND_ERRORS do
		const points = if index % 2 == 0
			then { { X = 0.1, Y = 0.9 }, { X = 0.3, Y = 0.6 }, { X = build.Groove.X + error / 100, Y = build.Groove.Y } }
			else { { X = 0.1, Y = 0.9 }, { X = 0.3, Y = 0.6 }, { X = build.Groove.X, Y = build.Groove.Y - error / 100 * ASPECT } }
		check(`place {error}`, Score.Value(cfg, "sausage_place", place.Measure(points, placeParams), nil, false), Grade.Score(cfg, row("sausage_place"), error, false))
	end
	check("place a tap is no drag", Score.Value(cfg, "sausage_place", place.Measure({ { X = 0.5, Y = 0.5 } }, placeParams), nil, false), 0)
	check("place assist 11 is Perfect", Score.Band(cfg, Score.Value(cfg, "sausage_place", place.Measure({ { X = 0, Y = 0 }, { X = 0, Y = 0 }, { X = 0.61, Y = 0.5 } }, placeParams), nil, true)), "Perfect")

	-- slide: settles at the mean of the last 3 samples (a jittery start does not count)
	const slideParams: slide.Params = { Aspect = ASPECT, X = build.Groove.X, Y = build.Groove.Y, MinPoints = minPoints("slide"), Settle = 3 }
	for _, error in BAND_ERRORS do
		const x = build.Groove.X - error / 100
		const points = { { X = 0.9, Y = 0.1 }, { X = 0.7, Y = 0.9 }, { X = x, Y = build.Groove.Y }, { X = x, Y = build.Groove.Y }, { X = x, Y = build.Groove.Y } }
		check(`slide {error}`, Score.Value(cfg, "cheese", slide.Measure(points, slideParams), nil, false), Grade.Score(cfg, row("cheese"), error, false))
	end
	check("slide too few samples", Score.Value(cfg, "cheese", slide.Measure({ { X = 0.5, Y = 0.5 } }, slideParams), nil, false), 0)

	-- hold: released `percent` of the bar from the target (before and after it)
	const holdParams: hold.Params = { Target = build.Potato.Target }
	for index, error in BAND_ERRORS do
		const progress = build.Potato.Target + (if index % 2 == 0 then -1 else 1) * error / 100
		check(`hold {error}`, Score.Value(cfg, "potato_sticks", hold.Measure(math.clamp(progress, 0, 1), holdParams), nil, false), Grade.Score(cfg, row("potato_sticks"), math.abs(math.clamp(progress, 0, 1) - build.Potato.Target) * 100, false))
	end
	check("hold exact", Score.Value(cfg, "potato_sticks", hold.Measure(build.Potato.Target, holdParams), nil, false), 100)

	-- taps: three rings, every tap `ms` early or late; a ring not tapped is a miss
	const tapsParams: taps.Params = { Count = build.Bacon.Count, Miss = build.Bacon.Miss }
	const ideal = { 10, 10.55, 11.1 }
	for _, ms in TAP_ERRORS do
		const tapped: { number? } = { ideal[1] + ms / 1000, ideal[2] - ms / 1000, ideal[3] + ms / 1000 }
		check(`taps {ms}`, Score.Value(cfg, "bacon", taps.Measure(ideal, tapped, tapsParams), nil, false), Grade.Score(cfg, row("bacon"), math.min(ms, build.Bacon.Miss), false))
	end
	check("taps a missing ring", Score.Value(cfg, "bacon", taps.Measure(ideal, { ideal[1], ideal[2] } :: { number? }, tapsParams), nil, false), Grade.Score(cfg, row("bacon"), build.Bacon.Miss / 3, false))
	check("taps none", Score.Value(cfg, "bacon", taps.Measure(ideal, {} :: { number? }, tapsParams), nil, false), 0)
	check("taps need the 3 of the row", minPoints("taps"), build.Bacon.Count)

	-- trace: the pour (coverage / excess from an amount) and the geometry of a drawn stroke
	for _, amount in SAUCES do
		const coverage, excess = trace.Poured(amount)
		check(`pour {amount}`, Score.Value(cfg, "ketchup", coverage, excess, false), Grade.Score(cfg, row("ketchup"), Grade.CoverageError(row("ketchup"), math.min(100, amount * 100), math.max(0, amount - 1) * 100), false))
	end
	const traceParams: trace.Params = { Aspect = ASPECT, Path = build.Sauce.Path, Reach = build.Sauce.Reach, Spill = build.Sauce.Spill }
	local function along(count: number, last: number): { any }
		-- `count` samples over the first `last` (0..1) of the path
		const points: { any } = {}
		const path = build.Sauce.Path
		const legs = #path - 1
		for index = 0, count - 1 do
			const position = index / (count - 1) * last * legs
			const leg = math.min(math.floor(position), legs - 1)
			const alpha = position - leg
			table.insert(points, { X = path[leg + 1].X + (path[leg + 2].X - path[leg + 1].X) * alpha, Y = path[leg + 1].Y + (path[leg + 2].Y - path[leg + 1].Y) * alpha })
		end
		return points
	end
	const fullCoverage, fullExcess = trace.Measure(along(40, 1), traceParams)
	check("trace the whole path: coverage", fullCoverage >= 99, true)
	check("trace the whole path: no excess", fullExcess <= 1, true)
	check("trace the whole path is near 100", Score.Value(cfg, "mustard", fullCoverage, fullExcess, false) >= 95, true)
	const halfCoverage = trace.Measure(along(40, 0.5), traceParams)
	check("trace half the path covers about half", halfCoverage > 40 and halfCoverage < 65, true)
	const lineCoverage = trace.Measure({ { X = 0.1, Y = 0.5 }, { X = 0.3, Y = 0.5 }, { X = 0.5, Y = 0.5 }, { X = 0.7, Y = 0.5 }, { X = 0.9, Y = 0.5 } }, traceParams)
	check("trace a straight line is not Perfect", lineCoverage < 70, true)
	const offCoverage, offExcess = trace.Measure({ { X = 0.1, Y = 1.5 }, { X = 0.5, Y = 1.5 }, { X = 0.9, Y = 1.5 } }, traceParams)
	check("trace off the bun covers nothing", offCoverage, 0)
	check("trace off the bun is all excess", offExcess, 100)
	check("trace a dot paints nothing", trace.Measure({ { X = 0.5, Y = 0.5 } }, traceParams), 0)
	check("trace amount of the whole path", math.abs(trace.Amount(along(40, 1), traceParams) - 1) < 0.02, true)
	check("trace Perfect coverage 90 excess 5", Score.Band(cfg, Score.Value(cfg, "ketchup", 90, 5, false)), "Perfect")
	check("trace assist widens the limits", Score.Value(cfg, "ketchup", 80, 0, true) > Score.Value(cfg, "ketchup", 80, 0, false), true)

	-- the sampling rows the recogniser reads: 30 Hz, the minimum of points, the cap of the stroke reuse
	for _, key in { "slice", "place", "trace", "slide", "hold" } do
		check(`row {key} samples at 30 Hz`, cfg.Gestures.ByKey[key].Hz, 30)
	end
	check("row trace keeps at most 64 points", cfg.Gestures.ByKey.trace.MaxPoints, 64)
	check("row taps is discrete", cfg.Gestures.ByKey.taps.Hz, 0)

	return { Total = total, Failed = failed }
end

return Spec
