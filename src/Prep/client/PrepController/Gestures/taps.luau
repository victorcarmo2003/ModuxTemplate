--!strict
-- taps: the rings that close, one tap each (Content.Prep.Tolerances.bacon; Gestures row `taps`, MinPoints 3 = the taps).
-- Pure. Raw error = mean timing error of the taps, in ms (Unit Milliseconds). `ideal` and `taps` are clock seconds, one entry
-- per ring (a ring nobody tapped is nil and counts `Miss` ms), so a missing tap is the Worst and never a free pass.
const taps = {
	Key = "taps",
	Target = "bacon",
}

export type Params = {
	Count: number,
	Miss: number,
}

function taps.Measure(ideal: { number }, tapped: { number? }, params: Params): number
	if params.Count <= 0 then
		return math.huge
	end
	local sum = 0
	for index = 1, params.Count do
		const wanted, got = ideal[index], tapped[index]
		if wanted == nil or got == nil then
			sum += params.Miss
		else
			sum += math.min(math.abs(got - wanted) * 1000, params.Miss)
		end
	end
	return sum / params.Count
end

return taps
