--!strict
-- The measures of the cooking focus gestures (kitchen-focus.md §3), brought back from the old prep (Gestures/Geometry, slice,
-- place, trace). Pure: points are { X, Y } in the bun space (x 0..1 along the bun, y 0..1 across it; Content.Prep.Build.Aspect =
-- length / width). Each returns the raw error Grade.Score wants (sauces: coverage and excess, both %).
export type Point = { X: number, Y: number }
type Path = { xs: { number }, ys: { number } }

const STEP = 0.1 -- sampling step of the sauce paths, bun heights
const SPAN = 0.9 -- a cut must cross this share of the line From..To

const Gestures = {}

local function segmentDistance(px: number, py: number, ax: number, ay: number, bx: number, by: number): number
	const dx, dy = bx - ax, by - ay
	const lengthSq = dx * dx + dy * dy
	local t = 0
	if lengthSq > 0 then
		t = math.clamp(((px - ax) * dx + (py - ay) * dy) / lengthSq, 0, 1)
	end
	const cx, cy = ax + dx * t, ay + dy * t
	return math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy))
end

-- The points in the bun space with x scaled by the aspect (a distance is in bun widths, a circle is a circle)
local function space(points: { Point }, aspect: number): Path
	const xs: { number } = {}
	const ys: { number } = {}
	for index, point in points do
		xs[index] = point.X * aspect
		ys[index] = point.Y
	end
	return { xs = xs, ys = ys }
end

local function distance(px: number, py: number, path: Path): number
	const count = #path.xs
	if count == 0 then
		return math.huge
	elseif count == 1 then
		const dx, dy = px - path.xs[1], py - path.ys[1]
		return math.sqrt(dx * dx + dy * dy)
	end
	local best = math.huge
	for index = 1, count - 1 do
		best = math.min(best, segmentDistance(px, py, path.xs[index], path.ys[index], path.xs[index + 1], path.ys[index + 1]))
	end
	return best
end

local function samples(path: Path, step: number): Path
	const xs: { number } = {}
	const ys: { number } = {}
	const count = #path.xs
	if count == 0 then
		return { xs = xs, ys = ys }
	end
	table.insert(xs, path.xs[1])
	table.insert(ys, path.ys[1])
	for index = 1, count - 1 do
		const ax, ay, bx, by = path.xs[index], path.ys[index], path.xs[index + 1], path.ys[index + 1]
		const length = math.sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay))
		const pieces = math.max(1, math.ceil(length / step))
		for piece = 1, pieces do
			const alpha = piece / pieces
			table.insert(xs, ax + (bx - ax) * alpha)
			table.insert(ys, ay + (by - ay) * alpha)
		end
	end
	return { xs = xs, ys = ys }
end

-- The knife along the cut line (bun_cut): mean lateral deviation from the line, % of the bun width, plus one point per 1 % of
-- the line not crossed. A cut going right to left counts too. Fewer than `minPoints` samples = no cut (infinite).
function Gestures.Slice(points: { Point }, aspect: number, y: number, from: number, to: number, minPoints: number): number
	const count = #points
	if count < minPoints then
		return math.huge
	end
	local sum = 0
	local low, high = math.huge, -math.huge
	for _, point in points do
		sum += math.abs(point.Y - y)
		low = math.min(low, point.X)
		high = math.max(high, point.X)
	end
	const deviation = sum / count / aspect * 100
	const missing = math.max(0, SPAN * (to - from) - (high - low)) * 100
	return deviation + missing
end

-- A drop (sausage_place, cheese, bacon, potato sticks): distance of the drop point to the target, % of the bun length.
function Gestures.Place(x: number, y: number, aspect: number, targetX: number, targetY: number): number
	const dx = x - targetX
	const dy = (y - targetY) / aspect
	return math.sqrt(dx * dx + dy * dy) * 100
end

-- Sauce strokes against the target path: (coverage %, excess %). Coverage = share of the path that any stroke reaches within
-- `reach`; excess = share of the laid samples farther than `spill` from the path or off the bun.
function Gestures.Trace(strokes: { { Point } }, path: { Point }, aspect: number, reach: number, spill: number): (number, number)
	const guide = space(path, aspect)
	const spaced: { Path } = {}
	for _, points in strokes do
		if #points >= 2 then
			table.insert(spaced, space(points, aspect))
		end
	end
	if #spaced == 0 then
		return 0, 0
	end
	const wanted = samples(guide, STEP)
	local covered = 0
	for index = 1, #wanted.xs do
		for _, stroke in spaced do
			if distance(wanted.xs[index], wanted.ys[index], stroke) <= reach then
				covered += 1
				break
			end
		end
	end
	local laidCount, off = 0, 0
	for _, stroke in spaced do
		const laid = samples(stroke, STEP)
		for index = 1, #laid.xs do
			const x, y = laid.xs[index], laid.ys[index]
			const rawX = x / aspect
			laidCount += 1
			if rawX < 0 or rawX > 1 or y < 0 or y > 1 or distance(x, y, guide) > spill then
				off += 1
			end
		end
	end
	return covered / #wanted.xs * 100, off / math.max(laidCount, 1) * 100
end

return table.freeze(Gestures)
