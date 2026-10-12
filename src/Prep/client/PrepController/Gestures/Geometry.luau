--!strict
-- Geometry: the small pure maths under the gesture measures (docs/tech/prep-mode.md §6 Gestures; TASK-176). Points are
-- anything with X and Y (a Vector2 of an Event, or a plain table of the tests); the helpers work on parallel arrays so no
-- Roblox type is built here. The "space" is the bun space (0..1 on both axes, x to the right) with x multiplied by the bun
-- aspect (width / height), so a distance is in bun heights and a circle is a circle.
-- A point is anything with X and Y (a Vector2, or a plain table in the tests); typed `any` on purpose: a union of the two
-- is invariant under the new solver and a list of Vector2 would not pass for it.
export type Point = any

export type Path = { xs: { number }, ys: { number } }

const Geometry = {}

-- Distance of (px, py) to the segment a-b.
function Geometry.SegmentDistance(px: number, py: number, ax: number, ay: number, bx: number, by: number): number
	const dx, dy = bx - ax, by - ay
	const lengthSq = dx * dx + dy * dy
	local t = 0
	if lengthSq > 0 then
		t = math.clamp(((px - ax) * dx + (py - ay) * dy) / lengthSq, 0, 1)
	end
	const cx, cy = ax + dx * t, ay + dy * t
	return math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy))
end

-- The points in the space of the bun (x scaled by the aspect).
function Geometry.Space(points: { any }, aspect: number): Path
	const xs: { number } = {}
	const ys: { number } = {}
	for index, point in points do
		xs[index] = point.X * aspect
		ys[index] = point.Y
	end
	return { xs = xs, ys = ys }
end

-- Distance of a point to a polyline (a single point is a point).
function Geometry.Distance(px: number, py: number, path: Path): number
	const count = #path.xs
	if count == 0 then
		return math.huge
	end
	if count == 1 then
		const dx, dy = px - path.xs[1], py - path.ys[1]
		return math.sqrt(dx * dx + dy * dy)
	end
	local best = math.huge
	for index = 1, count - 1 do
		const d = Geometry.SegmentDistance(px, py, path.xs[index], path.ys[index], path.xs[index + 1], path.ys[index + 1])
		if d < best then
			best = d
		end
	end
	return best
end

function Geometry.Length(path: Path): number
	local total = 0
	for index = 1, #path.xs - 1 do
		const dx, dy = path.xs[index + 1] - path.xs[index], path.ys[index + 1] - path.ys[index]
		total += math.sqrt(dx * dx + dy * dy)
	end
	return total
end

-- Evenly spaced samples along a polyline (both ends included), one every `step` or closer.
function Geometry.Samples(path: Path, step: number): Path
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

return table.freeze(Geometry)
