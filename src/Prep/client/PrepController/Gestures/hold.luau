--!strict
-- hold: press and release on the green band of a filling bar (Content.Prep.Tolerances.potato_sticks; Gestures row `hold`).
-- Pure. Raw error = distance of the release to the target, in % of the bar (Unit PercentBar). `progress` is 0..1 of the fill.
const hold = {
	Key = "hold",
	Target = "potato_sticks",
}

export type Params = {
	Target: number,
}

function hold.Measure(progress: number, params: Params): number
	return math.abs(math.clamp(progress, 0, 1) - params.Target) * 100
end

return hold
