--!strict
-- slide: the cheese slice slid onto the bun (Content.Prep.Tolerances.cheese; Gestures row `slide`). Pure.
-- Raw error = distance of where the slice settled to the target, in % of the bun length (Unit PercentTarget). It settles at the
-- mean of the last `Settle` samples, so one jittery last frame does not decide the grade (a slice is slid, not dropped).
-- Fewer samples than MinPoints is no slide (infinite error).
const slide = {
	Key = "slide",
	Target = "cheese",
}

export type Params = {
	Aspect: number,
	X: number,
	Y: number,
	MinPoints: number,
	Settle: number,
}

function slide.Measure(points: { any }, params: Params): number
	const count = #points
	if count < params.MinPoints then
		return math.huge
	end
	const take = math.min(math.max(params.Settle, 1), count)
	local sx, sy = 0, 0
	for index = count - take + 1, count do
		sx += points[index].X
		sy += points[index].Y
	end
	const dx = sx / take - params.X
	const dy = (sy / take - params.Y) / params.Aspect
	return math.sqrt(dx * dx + dy * dy) * 100
end

return slide
