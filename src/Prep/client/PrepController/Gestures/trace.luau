--!strict
-- trace: the zig-zag of a sauce over the bun (Content.Prep.Tolerances ketchup / mustard / cream_cheese; Gestures row `trace`,
-- 30 Hz, MinPoints 12, MaxPoints 64). Pure.
-- Measure answers the two numbers Grade.CoverageError wants, in % (the score is `Score.Value`):
--   coverage  share of the target Path that has the stroke within `Reach` (sampled every STEP bun heights along the path)
--   excess    share of the stroke (sampled the same way) that lies farther than `Spill` from the Path or off the bun
-- A stroke with fewer than 2 points paints nothing: (0, 0). Measure is the pour of the hold-instead-of-trace mode too:
-- `Amount` turns "how much sauce" (1 = one path length) into the same two numbers.
local Geometry = require(script.Parent.Geometry)

export type Params = {
	Aspect: number,
	-- the target path, bun space (Content.Prep.Build.Sauce.Path)
	Path: { { X: number, Y: number } },
	Reach: number,
	Spill: number,
}

const STEP = 0.1

const trace = {
	Key = "trace",
}

function trace.Measure(points: { any }, params: Params): (number, number)
	if #points < 2 then
		return 0, 0
	end
	const guide = Geometry.Space(params.Path, params.Aspect)
	const stroke = Geometry.Space(points, params.Aspect)

	const wanted = Geometry.Samples(guide, STEP)
	local covered = 0
	for index = 1, #wanted.xs do
		if Geometry.Distance(wanted.xs[index], wanted.ys[index], stroke) <= params.Reach then
			covered += 1
		end
	end

	const laid = Geometry.Samples(stroke, STEP)
	local off = 0
	for index = 1, #laid.xs do
		const x, y = laid.xs[index], laid.ys[index]
		const rawX = x / params.Aspect
		if rawX < 0 or rawX > 1 or y < 0 or y > 1 or Geometry.Distance(x, y, guide) > params.Spill then
			off += 1
		end
	end
	return covered / #wanted.xs * 100, off / #laid.xs * 100
end

-- Length of the stroke in path lengths (1 = as much sauce as the whole path): the meter of the gesture.
function trace.Amount(points: { any }, params: Params): number
	const guide = Geometry.Length(Geometry.Space(params.Path, params.Aspect))
	if guide <= 0 or #points < 2 then
		return 0
	end
	return Geometry.Length(Geometry.Space(points, params.Aspect)) / guide
end

-- The hold-instead-of-trace pour: `amount` of sauce (1 = the path) is all on the bun; over 1 spills.
function trace.Poured(amount: number): (number, number)
	return math.min(100, math.max(0, amount) * 100), math.max(0, amount - 1) * 100
end

return trace
