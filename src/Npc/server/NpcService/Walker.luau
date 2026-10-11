--!strict
-- NpcService/Walker: follows a list of graph waypoints with Humanoid:MoveTo (architecture.md §12.3, T11). TASK-031.
-- One waypoint at a time (graph edges are <= 40 studs, §18.6, so a single MoveTo never hits its 8 s give-up at
-- customer speeds). A waypoint missed twice is snapped to (PROVISIONAL anti-stuck: the NPC never blocks the queue).
-- `alive` is polled so a despawn or a newer walk order stops this one within POLL seconds; nothing here outlives it.
-- Walk animation is not here: Motor6D.Transform does not replicate, so the limbs are animated by the client
-- (DEC-183 note, Provisional; NpcController/RigController). No network, no Modux.
-- Crosswalks (TASK-122; architecture.md §8.1, §19.17; DEC-133): a waypoint reached through a crosswalk edge (the far
-- curb) is only walked to once `crossing.Reserve(cw)` grants it (TrafficService:ReserveCrossing, through NpcService);
-- the NPC waits on the near curb meanwhile. Not on the far curb `crossing.MaxWait` s after the grant -> snapped there
-- (failsafe, logged). The reservation is released on arrival, on the snap and on cancel.
-- Anti-stuck (playtest 2026-10-11: rigs caught on street-light poles, PROVISIONAL): a MoveTo that makes less than
-- PROGRESS studs of progress for STUCK_TIME s backs off and side-steps (alternating sides), then walks on. After
-- SIDESTEPS tries the rig is snapped to the waypoint if no player is within HIDDEN_RADIUS, and always after HARD_CAP
-- tries (crosswalk and Direct walks never snap here: their callers decide). A wait at the spacing gate is not "stuck".
-- Spacing (same playtest: rigs walking inside each other): `Gate(direction)` (NpcService:Blocked) says another rig
-- stands or walks the same way right ahead; the rig stops and waits (at most GATE_MAX s per waypoint, so two gates
-- can never lock each other), then walks on.

export type Mover = { Model: Model, Root: BasePart, Humanoid: Humanoid }

-- true = another rig is right ahead along `direction` (flat unit vector): wait
export type Gate = (direction: Vector3) -> boolean

export type Crossing = {
	At: { [number]: string }, -- index in `points` of the far curb of a crosswalk edge -> crosswalk key
	Reserve: (cw: string) -> boolean,
	Release: (cw: string) -> (),
	MaxWait: number, -- seconds from the grant to the far curb (Content.Traffic.Crossing.MaxWait)
}

const POLL = 0.1 -- seconds between checks of arrival / cancellation
const STEP_TIMEOUT = 9 -- seconds; Humanoid:MoveTo gives up at 8 s and fires MoveToFinished(false)
const RETRIES = 1 -- extra MoveTo per waypoint before snapping
const LIFT = 3 -- HumanoidRootPart above the floor point (architecture.md §18.5)
const RESERVE_POLL = 0.25 -- seconds between reservation requests on the near curb
-- Anti-stuck, PROVISIONAL (debugger, playtest 2026-10-11)
const STUCK_TIME = 1 -- seconds without progress = stuck
const PROGRESS = 0.4 -- studs closer to the waypoint that count as progress
const ARRIVE = 2.5 -- studs: a MoveToFinished(true) farther than this is stale (a superseded side-step) and ignored
const BACK_OFF = 1 -- studs back from the obstacle before the side-step
const SIDE_STEP = 3 -- studs sideways (NPC radius 1 + pole + 1 of clearance)
const SIDE_TIME = 0.8 -- seconds at most on a side-step
const SIDESTEPS = 2 -- side-steps before a snap when no player is near
const HARD_CAP = 5 -- side-steps before a snap even in view (never stays stuck)
const HIDDEN_RADIUS = 40 -- studs: no player character this close = nobody sees the snap
-- Spacing gate, PROVISIONAL
const GATE_MAX = 3 -- seconds a rig waits behind another per waypoint before it walks on anyway

local Players = game:GetService("Players")

const Walker = {}

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

-- Puts the rig on `target` (floor point), keeping its heading.
function Walker.Snap(mover: Mover, target: Vector3)
	const rotation = mover.Root.CFrame.Rotation
	mover.Model:PivotTo(CFrame.new(target + Vector3.new(0, LIFT, 0)) * rotation)
end

-- No player character within HIDDEN_RADIUS of the rig.
local function hidden(mover: Mover): boolean
	const position = mover.Root.Position
	for _, player in Players:GetPlayers() do
		const character = player.Character
		const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root ~= nil and root:IsA("BasePart") and (root.Position - position).Magnitude < HIDDEN_RADIUS then
			return false
		end
	end
	return true
end

-- Backs off and steps to one side of the line to `target` (side = 1 / -1). YIELDS up to SIDE_TIME.
local function sideStep(mover: Mover, target: Vector3, side: number, alive: () -> boolean)
	const position = mover.Root.Position
	local direction = flat(target - position)
	if direction.Magnitude < 1e-3 then
		direction = flat(mover.Root.CFrame.LookVector)
	end
	if direction.Magnitude < 1e-3 then
		return
	end
	direction = direction.Unit
	const lateral = Vector3.new(-direction.Z, 0, direction.X) * side
	const goal = position - direction * BACK_OFF + lateral * SIDE_STEP
	mover.Humanoid:MoveTo(goal)
	const deadline = os.clock() + SIDE_TIME
	while alive() and os.clock() < deadline and flat(goal - mover.Root.Position).Magnitude > 0.75 do
		task.wait(POLL)
	end
end

-- One MoveTo with anti-stuck and the spacing gate. true = reached (or snapped), false = gave up or cancelled.
-- `snap`: may snap to `target` when stuck (graph sidewalk edges only).
local function step(
	mover: Mover,
	target: Vector3,
	alive: () -> boolean,
	timeout: number?,
	snap: boolean,
	gate: Gate?
): boolean
	local finished: boolean? = nil
	const connection = mover.Humanoid.MoveToFinished:Connect(function(reached: boolean)
		finished = reached
	end)
	mover.Humanoid:MoveTo(target)
	local deadline = os.clock() + (timeout or STEP_TIMEOUT)
	local best = flat(target - mover.Root.Position).Magnitude
	local progressAt = os.clock()
	local tries = 0
	local gated = 0
	local waiting = false
	while alive() and os.clock() < deadline do
		task.wait(POLL)
		if not alive() then
			break
		end
		const now = os.clock()
		const offset = flat(target - mover.Root.Position)
		const distance = offset.Magnitude
		if finished == true and distance > ARRIVE then
			finished = nil -- stale event of a superseded MoveTo (side-step or gate stop)
		end
		if finished ~= nil then
			break
		end
		-- spacing gate: stop behind a rig right ahead (at most GATE_MAX s per waypoint)
		if gate ~= nil and distance > ARRIVE and gated < GATE_MAX and gate(offset.Unit) then
			if not waiting then
				waiting = true
				mover.Humanoid:MoveTo(mover.Root.Position)
			end
			gated += POLL
			deadline += POLL
			progressAt = now
			continue
		end
		if waiting then
			waiting = false
			mover.Humanoid:MoveTo(target)
			progressAt = now
		end
		if distance < best - PROGRESS then
			best = distance
			progressAt = now
		elseif now - progressAt > STUCK_TIME then
			tries += 1
			if snap and (tries > HARD_CAP or (tries > SIDESTEPS and hidden(mover))) then
				warn(`[NpcService] {mover.Model.Name} stuck {tries}x on the way to {target}: snapped to the waypoint`)
				Walker.Snap(mover, target)
				finished = true
				break
			end
			sideStep(mover, target, if tries % 2 == 1 then 1 else -1, alive)
			finished = nil
			mover.Humanoid:MoveTo(target)
			best = flat(target - mover.Root.Position).Magnitude
			progressAt = os.clock()
		end
	end
	connection:Disconnect()
	return finished == true
end

-- Turns the rig to face `look` (horizontal part only).
function Walker.Face(mover: Mover, look: Vector3)
	const horizontal = flat(look)
	if horizontal.Magnitude < 1e-3 then
		return
	end
	const position = mover.Root.Position
	mover.Root.CFrame = CFrame.lookAt(position, position + horizontal.Unit)
end

-- Crosses to the far curb `point` under a reservation of `cw`. true = arrived (or snapped), false = cancelled.
local function cross(mover: Mover, point: Vector3, cw: string, crossing: Crossing, alive: () -> boolean): boolean
	while not crossing.Reserve(cw) do
		if not alive() then
			return false
		end
		task.wait(RESERVE_POLL)
	end
	if not alive() then
		crossing.Release(cw)
		return false
	end
	const arrived = step(mover, point, alive, crossing.MaxWait, false, nil)
	if not alive() then
		crossing.Release(cw)
		return false
	end
	if not arrived then
		warn(`[NpcService] {mover.Model.Name} still on {cw} when its reservation ended: snapped to the curb`)
		Walker.Snap(mover, point)
	end
	crossing.Release(cw)
	return true
end

-- Walks through `points` in order. `reached(index)` runs after each waypoint. true = all reached (or snapped),
-- false = cancelled (`alive` turned false). `crossing` (optional): crosswalk edges wait for a reservation.
-- `gate` (optional): spacing behind other rigs (never on a crosswalk edge: the road is no place to wait).
function Walker.Follow(
	mover: Mover,
	points: { Vector3 },
	alive: () -> boolean,
	reached: (index: number) -> (),
	crossing: Crossing?,
	gate: Gate?
): boolean
	for index, point in points do
		const cw = if crossing then crossing.At[index] else nil
		if crossing ~= nil and cw ~= nil then
			if not cross(mover, point, cw, crossing, alive) then
				return false
			end
			reached(index)
			continue
		end
		local arrived = false
		for _ = 0, RETRIES do
			if not alive() then
				return false
			end
			arrived = step(mover, point, alive, nil, true, gate)
			if arrived then
				break
			end
		end
		if not alive() then
			return false
		end
		if not arrived then
			Walker.Snap(mover, point)
		end
		reached(index)
	end
	return true
end

-- One straight MoveTo to `target` (no graph: Pad tables, pair partners; TASK-145/146). YIELDS. true = reached, false =
-- gave up after `timeout` s (default STEP_TIMEOUT) or cancelled. Never snaps: the caller decides.
function Walker.Direct(mover: Mover, target: Vector3, alive: () -> boolean, timeout: number?): boolean
	if not alive() then
		return false
	end
	return step(mover, target, alive, timeout, false, nil)
end

-- Stops any MoveTo in progress.
function Walker.Stop(mover: Mover)
	if mover.Root:IsDescendantOf(workspace) then
		mover.Humanoid:MoveTo(mover.Root.Position)
	end
end

return table.freeze(Walker)
