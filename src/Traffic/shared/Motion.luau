--!strict
--[[
	Motion (TASK-104; architecture.md §8.1, §19.17, T21; network.md §6.2, §13.7). Shared, pure: no services, no
	Instances, no state of its own. Same inputs -> same outputs on the server and on every client, so a car (or a
	passer-by) drawn from a record sits at the same place everywhere.

	1D record (Traffic and Pedestrians sets): { AnchorAt, AnchorDist, StopDist, HeldUntil }.
	  * The anchor is a STANDSTILL: at AnchorAt the body is at rest at AnchorDist and pulls away with Profile.Accel up
	    to the profile speed. Before AnchorAt it waits at AnchorDist. (PROVISIONAL, backend-coder: the record has no
	    speed field, so every record starts from rest. A car is only re-anchored while stopped; changes on a moving
	    car keep the anchor and only touch StopDist / HeldUntil, see TrafficService.)
	  * Profile speed: Profile.Fast, or Profile.SlowSpeed inside a Slow stretch (cars: the X-T box footprint). The body
	    slows with Profile.Brake so that it enters a Slow stretch already at SlowSpeed.
	  * StopDist > 0: while it binds (HeldUntil = 0, or t < HeldUntil) the body brakes to stop EXACTLY on StopDist
	    and waits there. HeldUntil > 0 = pulls away by itself at HeldUntil (no second record). A stop behind the body
	    (s > StopDist) is ignored.
	Integration on a fixed grid of DT from AnchorAt (deterministic), linear in between. A Cursor caches the grid state
	so a caller that samples forward in time pays one step per DT.

	Path helpers (polyline in studs): distance along the nodes from the first one; PointAt extrapolates past the ends
	along the end segments; Stretches = parts of the polyline whose XZ falls inside a box footprint (Slow profile of the
	X-T box, crosswalk ranges). Node order and node position are the binding's (TrafficService/Paths reads them).
]]

export type Record = {
	AnchorAt: number,
	AnchorDist: number,
	StopDist: number,
	HeldUntil: number,
}

export type Profile = {
	Length: number,
	-- [from, to] stretches (studs along the path) at SlowSpeed, sorted by `from`
	Slow: { { number } },
	Fast: number,
	SlowSpeed: number,
	Accel: number,
	Brake: number,
}

-- Grid state: (S0, U0) at step K, (S1, U1) at step K + 1
export type Cursor = {
	K: number,
	S0: number,
	U0: number,
	S1: number,
	U1: number,
}

export type Path = {
	Points: { Vector3 },
	Cum: { number },
	Length: number,
}

const DT = 1 / 30
const EPSILON = 0.05 -- studs: on the stop line
const MAX_STEPS = 20 * 60 * 30 -- grid steps a single call may integrate (20 min of motion)
const SAMPLE = 0.5 -- studs between footprint samples (Stretches)

const Motion = {}

Motion.DT = DT
Motion.Epsilon = EPSILON

-- Profile ---------------------------------------------------------------------------------------------------------

function Motion.Profile(
	length: number,
	slow: { { number } },
	fast: number,
	slowSpeed: number,
	accel: number,
	brake: number
): Profile
	return {
		Length = length,
		Slow = slow,
		Fast = fast,
		SlowSpeed = slowSpeed,
		Accel = accel,
		Brake = brake,
	}
end

-- Profile speed at distance `s`
function Motion.SpeedAt(profile: Profile, s: number): number
	for _, stretch in profile.Slow do
		if s >= stretch[1] and s <= stretch[2] then
			return profile.SlowSpeed
		end
	end
	return profile.Fast
end

-- Start of the next Slow stretch ahead of `s` (math.huge if none)
local function nextSlow(profile: Profile, s: number): number
	for _, stretch in profile.Slow do
		if stretch[1] > s then
			return stretch[1]
		end
	end
	return math.huge
end

-- The stop of `record` still binds at distance `s` and time `t`
function Motion.Holding(record: Record, s: number, t: number): boolean
	if record.StopDist <= 0 or s > record.StopDist + EPSILON then
		return false
	end
	return record.HeldUntil <= 0 or t < record.HeldUntil
end

-- One grid step from (s, u), the state at grid time t, to the next grid point
local function step(profile: Profile, record: Record, s: number, u: number, t: number): (number, number)
	local target = Motion.SpeedAt(profile, s)
	const slowSpeed = profile.SlowSpeed
	const brake = profile.Brake
	-- slow down ahead of a Slow stretch
	const slowAt = nextSlow(profile, s)
	if slowAt < math.huge and u > slowSpeed then
		const room = slowAt - s
		if u * u - slowSpeed * slowSpeed >= 2 * brake * math.max(room - u * DT, 0) then
			target = slowSpeed
		end
	end
	const held = Motion.Holding(record, s, t)
	if held then
		const room = record.StopDist - s
		if room <= EPSILON then
			return record.StopDist, 0
		end
		-- brake to stop exactly on StopDist (v^2 = 2 a d)
		if u * u >= 2 * brake * math.max(room - u * DT, 0) then
			const decel = u * u / (2 * room)
			local nu = math.max(u - decel * DT, 0)
			local ns = s + (u + nu) * 0.5 * DT
			if ns >= record.StopDist - EPSILON or nu <= 0 then
				ns = record.StopDist
				nu = 0
			end
			return ns, nu
		end
	end
	local nu: number
	if u < target then
		nu = math.min(u + profile.Accel * DT, target)
	else
		nu = math.max(u - brake * DT, target)
	end
	local ns = s + (u + nu) * 0.5 * DT
	if held and ns > record.StopDist then
		ns = record.StopDist
		nu = 0
	end
	return ns, nu
end

-- Cursor ----------------------------------------------------------------------------------------------------------

-- Fresh grid state at the anchor (rest)
function Motion.Cursor(profile: Profile, record: Record): Cursor
	const s1, u1 = step(profile, record, record.AnchorDist, 0, record.AnchorAt)
	return { K = 0, S0 = record.AnchorDist, U0 = 0, S1 = s1, U1 = u1 }
end

function Motion.Clone(cursor: Cursor): Cursor
	return { K = cursor.K, S0 = cursor.S0, U0 = cursor.U0, S1 = cursor.S1, U1 = cursor.U1 }
end

-- Moves `cursor` forward to grid step `target` (never backwards). A body parked on a binding stop jumps the grid.
local function advance(profile: Profile, record: Record, cursor: Cursor, target: number)
	local steps = 0
	while cursor.K < target and steps < MAX_STEPS do
		if cursor.U1 == 0 and Motion.Holding(record, cursor.S1, record.AnchorAt + (cursor.K + 1) * DT) then
			local last = target
			if record.HeldUntil > 0 then
				-- last grid index whose step still sees the hold (t_last < HeldUntil)
				last = math.min(target, math.ceil((record.HeldUntil - record.AnchorAt) / DT) - 1)
			end
			if last > cursor.K then
				cursor.K = last
				cursor.S0, cursor.U0 = cursor.S1, cursor.U1
				continue
			end
		end
		cursor.K += 1
		cursor.S0, cursor.U0 = cursor.S1, cursor.U1
		cursor.S1, cursor.U1 = step(profile, record, cursor.S0, cursor.U0, record.AnchorAt + cursor.K * DT)
		steps += 1
	end
end

-- Distance and speed at time `t`, moving `cursor` forward. A `t` before the cursor's step reads the cursor's step.
function Motion.Sample(profile: Profile, record: Record, cursor: Cursor, t: number): (number, number)
	if t <= record.AnchorAt then
		return record.AnchorDist, 0
	end
	advance(profile, record, cursor, math.floor((t - record.AnchorAt) / DT))
	const t0 = record.AnchorAt + cursor.K * DT
	const alpha = math.clamp((t - t0) / DT, 0, 1)
	return cursor.S0 + (cursor.S1 - cursor.S0) * alpha, cursor.U0 + (cursor.U1 - cursor.U0) * alpha
end

-- Distance and speed at time `t` from the anchor (no cursor kept)
function Motion.At(profile: Profile, record: Record, t: number): (number, number)
	return Motion.Sample(profile, record, Motion.Cursor(profile, record), t)
end

-- First time the body reaches distance `dist` (>= dist - Epsilon), or nil when it never does before `limit` (server
-- time) or is held for good before it (HeldUntil = 0). `from` (optional) is a cursor to start from; it is not moved.
function Motion.TimeAt(profile: Profile, record: Record, dist: number, limit: number, from: Cursor?): number?
	if record.AnchorDist >= dist - EPSILON then
		return record.AnchorAt
	end
	const cursor = if from then Motion.Clone(from) else Motion.Cursor(profile, record)
	local steps = 0
	while steps < MAX_STEPS do
		const t0 = record.AnchorAt + cursor.K * DT
		if cursor.S1 >= dist - EPSILON then
			if cursor.S0 >= dist - EPSILON then
				return t0
			end
			const span = cursor.S1 - cursor.S0
			const alpha = if span > 0 then math.clamp((dist - cursor.S0) / span, 0, 1) else 1
			return t0 + alpha * DT
		end
		if t0 > limit then
			return nil
		end
		-- parked for good on a stop before `dist`
		if
			cursor.U1 == 0
			and record.HeldUntil <= 0
			and Motion.Holding(record, cursor.S1, record.AnchorAt + (cursor.K + 1) * DT)
		then
			return nil
		end
		advance(profile, record, cursor, cursor.K + 1)
		steps += 1
	end
	return nil
end

-- At rest on its binding stop at time `t` (parked; not merely starting from the anchor)
function Motion.Parked(profile: Profile, record: Record, cursor: Cursor, t: number): boolean
	const s, u = Motion.Sample(profile, record, cursor, t)
	return u == 0 and record.StopDist > 0 and math.abs(s - record.StopDist) <= EPSILON and Motion.Holding(record, s, t)
end

-- Path geometry ---------------------------------------------------------------------------------------------------

-- Polyline from ordered points (nil with fewer than 2)
function Motion.Path(points: { Vector3 }): Path?
	if #points < 2 then
		return nil
	end
	const cum: { number } = { 0 }
	for i = 2, #points do
		cum[i] = cum[i - 1] + (points[i] - points[i - 1]).Magnitude
	end
	return { Points = points, Cum = cum, Length = cum[#cum] }
end

-- Point at distance `s` (extrapolated past the ends along the end segments)
function Motion.PointAt(path: Path, s: number): Vector3
	const points, cum = path.Points, path.Cum
	local lo, hi = 1, #points
	if s <= 0 then
		hi = 2
	elseif s >= path.Length then
		lo = #points - 1
	else
		while hi - lo > 1 do
			const mid = (lo + hi) // 2
			if cum[mid] <= s then
				lo = mid
			else
				hi = mid
			end
		end
	end
	hi = lo + 1
	const span = cum[hi] - cum[lo]
	const alpha = if span > 0 then (s - cum[lo]) / span else 0
	return points[lo] + (points[hi] - points[lo]) * alpha
end

-- Horizontal unit heading at `s`, from the chord over `half` studs each side
function Motion.Heading(path: Path, s: number, half: number): Vector3
	const ahead = Motion.PointAt(path, s + half)
	const behind = Motion.PointAt(path, s - half)
	const direction = Vector3.new(ahead.X - behind.X, 0, ahead.Z - behind.Z)
	if direction.Magnitude < 1e-3 then
		return Vector3.new(0, 0, -1)
	end
	return direction.Unit
end

-- Distance along the path of the point nearest to `position` (XZ), and the horizontal offset to it
function Motion.Project(path: Path, position: Vector3): (number, number)
	const points, cum = path.Points, path.Cum
	local best, bestOffset = 0, math.huge
	for i = 1, #points - 1 do
		const a, b = points[i], points[i + 1]
		const ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		const ap = Vector3.new(position.X - a.X, 0, position.Z - a.Z)
		const length2 = ab:Dot(ab)
		const alpha = if length2 > 0 then math.clamp(ap:Dot(ab) / length2, 0, 1) else 0
		const offset = (ap - ab * alpha).Magnitude
		if offset < bestOffset then
			bestOffset = offset
			best = cum[i] + (cum[i + 1] - cum[i]) * alpha
		end
	end
	return best, bestOffset
end

-- [from, to] stretches of the path whose XZ falls inside the footprint of a box (`cframe`, `size`), sampled every
-- `sample` studs (default 0.5). Sorted by `from`.
function Motion.Stretches(path: Path, cframe: CFrame, size: Vector3, sample: number?): { { number } }
	const out: { { number } } = {}
	const every = sample or SAMPLE
	const half = size / 2
	const points, cum = path.Points, path.Cum
	const length = path.Length
	local from: number? = nil
	local s = 0
	local segment = 1
	while s <= length do
		while segment < #points - 1 and cum[segment + 1] < s do
			segment += 1
		end
		const a, b = points[segment], points[segment + 1]
		const span = cum[segment + 1] - cum[segment]
		const alpha = if span > 0 then (s - cum[segment]) / span else 0
		const pos = cframe:PointToObjectSpace(a:Lerp(b, alpha))
		const inside = math.abs(pos.X) <= half.X and math.abs(pos.Z) <= half.Z
		if inside and from == nil then
			from = s
		elseif not inside and from ~= nil then
			table.insert(out, { from, s })
			from = nil
		end
		s += every
	end
	if from ~= nil then
		table.insert(out, { from, length })
	end
	return out
end

return table.freeze(Motion)
