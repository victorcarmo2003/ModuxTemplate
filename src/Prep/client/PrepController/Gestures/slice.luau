--!strict
-- slice: the knife along the dashed line of the bun (Content.Prep.Tolerances.bun_cut; Gestures row `slice`). Pure.
-- Raw error = mean lateral deviation of the samples from the guide, in % of the bun WIDTH (Unit PercentWidth), plus one point
-- per 1 % of the line the stroke did not span (under 90 % of From..To). Fewer samples than MinPoints is no cut: infinite
-- error (score 0). Points are in the bun space (0..1 on both axes; the bun is `Aspect` times wider than tall).
export type Params = {
	Aspect: number,
	-- y of the line and where it starts / ends (x), from Content.Prep.Build.Cut
	Y: number,
	From: number,
	To: number,
	MinPoints: number,
}

const SPAN = 0.9

const slice = {
	Key = "slice",
	-- Tolerance row this gesture is scored against.
	Target = "bun_cut",
}

function slice.Measure(points: { any }, params: Params): number
	const count = #points
	if count < params.MinPoints then
		return math.huge
	end
	local sum = 0
	local low, high = math.huge, -math.huge
	for _, point in points do
		const x, y = point.X :: number, point.Y :: number
		sum += math.abs(y - params.Y)
		low = math.min(low, x)
		high = math.max(high, x)
	end
	-- a deviation in bun heights, in % of the width
	const deviation = sum / count / params.Aspect * 100
	const missing = math.max(0, SPAN * (params.To - params.From) - (high - low)) * 100
	return deviation + missing
end

return slice
