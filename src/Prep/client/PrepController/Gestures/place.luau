--!strict
-- place: the sausage dragged into the groove of the bun (Content.Prep.Tolerances.sausage_place; Gestures row `place`). Pure.
-- Raw error = distance of the point where the sausage was dropped to the groove, in % of the bun LENGTH (Unit PercentLength).
-- The drop point is the last sample; a drag with fewer samples than MinPoints is a tap, not a gesture (infinite error).
const place = {
	Key = "place",
	Target = "sausage_place",
}

export type Params = {
	Aspect: number,
	-- the groove (Content.Prep.Build.Groove), bun space
	X: number,
	Y: number,
	MinPoints: number,
}

-- Distance in % of the bun length between two points of the bun space.
function place.Distance(x: number, y: number, params: Params): number
	const dx = x - params.X
	-- a vertical distance is in bun heights: / Aspect makes it bun lengths
	const dy = (y - params.Y) / params.Aspect
	return math.sqrt(dx * dx + dy * dy) * 100
end

function place.Measure(points: { any }, params: Params): number
	const count = #points
	if count < params.MinPoints then
		return math.huge
	end
	const last = points[count]
	return place.Distance(last.X, last.Y, params)
end

return place
