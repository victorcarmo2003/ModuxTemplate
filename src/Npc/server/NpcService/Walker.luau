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
-- Natural gait (playtest 2026-10-12, PROVISIONAL, numbers in Content.Movement): the graph corners are rounded (entry /
-- middle / exit points of a quadratic curve, only when a raycast says the chords are clear and never at crosswalk
-- points); points that are only passed through count as reached inside a small radius, so the rig keeps walking (no
-- stop per waypoint); WalkSpeed eases at the start and the end of a walk; the body turns with an AlignOrientation
-- (capped angular speed) towards the point and a little ahead to the next one, never on the spot. No network.
-- Detour (restaurant patio, 2026-10-18, PROVISIONAL): an off-graph walk (Direct: seat approach points; the first leg of
-- a graph walk that starts away from its node) whose straight line is blocked walks around the blocking props instead
-- (corners of their boxes, shortest clear way, Walker.Detour). The swept box uses the rig's collision group, so other
-- rigs and NpcPass props never count. A Direct walk that stalls within DIRECT_NEAR of its goal counts as arrived (an
-- approach point beside a fence or a lamp pole: the seat snap does the rest).

export type Mover = { Model: Model, Root: BasePart, Humanoid: Humanoid }

-- true = another rig is right ahead along `direction` (flat unit vector): wait
-- `remaining`: studs to the waypoint; a rig past it is not in the way
export type Gate = (direction: Vector3, remaining: number) -> boolean

export type Crossing = {
	At: { [number]: string }, -- index in `points` of the far curb of a crosswalk edge -> crosswalk key
	Reserve: (cw: string) -> boolean,
	Release: (cw: string) -> (),
	MaxWait: number, -- seconds from the grant to the far curb (Content.Traffic.Crossing.MaxWait)
}

const POLL = 0.05 -- seconds between checks of arrival / cancellation
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
-- Detour, PROVISIONAL (restaurant patio, 2026-10-18)
const DETOUR_WIDTH = 1.8 -- studs: width of the swept box (rig torso 2; a brush along a pole still counts as clear)
const DETOUR_BOTTOM = 0.7 -- studs above the floor where the swept box starts (floor trims and rails below)
const DETOUR_TOP = 4.6 -- studs above the floor where it ends
const DETOUR_MARGIN = 1.5 -- studs around an obstacle's box for the corner points (half the rig + clearance)
const DETOUR_END = 1.2 -- studs: a hit this close to the end of a leg is the goal's own neighbour (fence, pole)
const DETOUR_SPAN = 16 -- studs: wider obstacles (walls, buildings) are never walked around
const DETOUR_OBSTACLES = 3 -- obstacles one detour may go around
const DIRECT_NEAR = 1.5 -- studs: a Direct walk stalled this close to its goal has arrived

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

const MOVE = Content.Movement
const CORNER = MOVE.Corner
const ACCEPT = MOVE.Accept
const EASE = MOVE.Speed
const TURN = MOVE.Turn
const SIDE_RAY = 0.9 -- studs: the safety raycast of a curve runs on the line and on both sides of it
const MAX_RAY_RETRIES = 3 -- rigs hit by a ray are skipped this many times

-- One point of a planned walk. Loose = only passed through (reached inside the accept radius, no stop).
-- Index = waypoint of the caller it belongs to; Last = the last point of that waypoint (the caller's reached()).
type Item = { Position: Vector3, Index: number, Loose: boolean, Last: boolean }

-- Per-step motion: the point after this one (look-ahead), loose, WalkSpeed easing at the start / the end of a walk
-- Base = the WalkSpeed the owner set (the walk writes it back at its end; nil = the step does)
-- Near = a stall this close to the target counts as reached (Direct only)
type Motion = { Loose: boolean, After: Vector3?, EaseIn: boolean, EaseOut: boolean, Base: number?, Near: number? }

export type Options = { Ease: boolean } -- Ease false = the owner drives WalkSpeed

type Turner = { Align: AlignOrientation, AutoRotate: boolean, Token: number }

local turners: { [BasePart]: Turner } = setmetatable({}, { __mode = "k" }) :: any
local debugDraw = false

const Walker = {}

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

-- Turning ---------------------------------------------------------------------------------------------------------

-- Turner of the rig (AlignOrientation on the root: physics turns the body at a capped angular speed, so the heading
-- never snaps). Disabled while idle; AutoRotate is off only while it is enabled.
local function turnerOf(mover: Mover): Turner
	const existing = turners[mover.Root]
	if existing ~= nil and existing.Align.Parent ~= nil then
		return existing
	end
	const attachment = Instance.new("Attachment")
	attachment.Name = "WalkTurnAttachment"
	attachment.Parent = mover.Root
	const align = Instance.new("AlignOrientation")
	align.Name = "WalkTurn"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.RigidityEnabled = false
	align.PrimaryAxisOnly = false
	align.ReactionTorqueEnabled = false
	align.MaxTorque = math.huge
	align.MaxAngularVelocity = math.rad(TURN.Rate)
	align.Responsiveness = TURN.Responsiveness
	align.CFrame = mover.Root.CFrame.Rotation
	align.Enabled = false
	align.Parent = mover.Root
	const created: Turner = { Align = align, AutoRotate = true, Token = 0 }
	turners[mover.Root] = created
	return created
end

-- Starts steering the body (the Humanoid stops turning it by itself meanwhile)
local function beginTurn(mover: Mover, facing: Vector3?): Turner
	const turner = turnerOf(mover)
	turner.Token += 1
	if not turner.Align.Enabled then
		turner.AutoRotate = mover.Humanoid.AutoRotate
		const position = mover.Root.Position
		const look = if facing ~= nil then facing else mover.Root.CFrame.LookVector
		turner.Align.CFrame = CFrame.lookAt(position, position + Vector3.new(look.X, 0, look.Z))
		turner.Align.Enabled = true
	end
	mover.Humanoid.AutoRotate = false
	return turner
end

-- Gives the body back to the Humanoid
local function endTurn(mover: Mover)
	const turner = turners[mover.Root]
	if turner == nil or not turner.Align.Enabled then
		return
	end
	turner.Token += 1
	turner.Align.Enabled = false
	if mover.Humanoid.Parent ~= nil then
		mover.Humanoid.AutoRotate = turner.AutoRotate
	end
end

-- Goal heading (flat direction), only while steering
local function aim(mover: Mover, direction: Vector3)
	const turner = turners[mover.Root]
	if turner == nil or not turner.Align.Enabled or direction.Magnitude < 1e-3 then
		return
	end
	const position = mover.Root.Position
	turner.Align.CFrame = CFrame.lookAt(position, position + Vector3.new(direction.X, 0, direction.Z))
end

-- Heading towards `target`, leaning to `after` as the point comes close (look-ahead, no turn on the spot)
local function headingTo(position: Vector3, target: Vector3, after: Vector3?): Vector3
	const offset = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
	const distance = offset.Magnitude
	if distance < 1e-3 then
		return offset
	end
	local direction = offset / distance
	if after ~= nil and distance < TURN.LookAhead then
		const next = Vector3.new(after.X - target.X, 0, after.Z - target.Z)
		if next.Magnitude > 1e-3 then
			const weight = (1 - distance / TURN.LookAhead) * TURN.LookBlend
			const mixed = direction * (1 - weight) + next.Unit * weight
			if mixed.Magnitude > 1e-3 then
				direction = mixed.Unit
			end
		end
	end
	return direction
end

-- Planning --------------------------------------------------------------------------------------------------------

-- A thin ray (and two on its sides) from `a` to `b` hits nothing solid. Rigs with a Humanoid do not count.
local function clear(a: Vector3, b: Vector3, params: RaycastParams, exclude: { Instance }): boolean
	const delta = b - a
	const side = Vector3.new(-delta.Z, 0, delta.X)
	if side.Magnitude < 1e-3 then
		return true
	end
	const offset = side.Unit * SIDE_RAY
	const up = Vector3.new(0, CORNER.RayHeight, 0)
	for _, shift in { Vector3.zero, offset, -offset } do
		for _ = 1, MAX_RAY_RETRIES do
			const hit = workspace:Raycast(a + up + shift, delta, params)
			if hit == nil then
				break
			end
			const model = hit.Instance:FindFirstAncestorOfClass("Model")
			if model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil then
				table.insert(exclude, model)
				params.FilterDescendantsInstances = exclude
				continue
			end
			return false
		end
	end
	return true
end

-- Walk of `points` with the corners rounded. Crosswalk points (the far curb and the near curb in front of it) and the
-- last point stay as they are; a corner whose curve would touch something stays sharp.
local function plan(mover: Mover, points: { Vector3 }, crossing: Crossing?): { Item }
	const items: { Item } = {}
	const count = #points
	const exclude: { Instance } = { mover.Model }
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	params.FilterDescendantsInstances = exclude
	local previous = mover.Root.Position
	for index, point in points do
		local fixed = index == count
		if crossing ~= nil and (crossing.At[index] ~= nil or crossing.At[index + 1] ~= nil) then
			fixed = true
		end
		if fixed then
			table.insert(items, { Position = point, Index = index, Loose = false, Last = true })
			previous = point
			continue
		end
		const incoming = flat(point - previous)
		const outgoing = flat(points[index + 1] - point)
		const lengthIn, lengthOut = incoming.Magnitude, outgoing.Magnitude
		if lengthIn < 1e-3 or lengthOut < 1e-3 then
			table.insert(items, { Position = point, Index = index, Loose = true, Last = true })
			previous = point
			continue
		end
		const din, dout = incoming / lengthIn, outgoing / lengthOut
		const angle = math.deg(math.acos(math.clamp(din:Dot(dout), -1, 1)))
		if angle < CORNER.MinAngle then
			-- almost straight: pass through without a stop
			table.insert(items, { Position = point, Index = index, Loose = true, Last = true })
			previous = point
			continue
		end
		const radius = math.min(CORNER.Radius, lengthIn * CORNER.EdgeShare, lengthOut * CORNER.EdgeShare)
		local rounded = false
		if radius >= CORNER.MinRadius then
			const entry = Vector3.new(point.X - din.X * radius, point.Y, point.Z - din.Z * radius)
			const exit = Vector3.new(point.X + dout.X * radius, point.Y, point.Z + dout.Z * radius)
			const middle = entry * 0.25 + point * 0.5 + exit * 0.25
			if clear(entry, middle, params, exclude) and clear(middle, exit, params, exclude) then
				table.insert(items, { Position = entry, Index = index, Loose = true, Last = false })
				table.insert(items, { Position = middle, Index = index, Loose = true, Last = false })
				table.insert(items, { Position = exit, Index = index, Loose = true, Last = true })
				rounded = true
			end
		end
		if not rounded then
			table.insert(items, { Position = point, Index = index, Loose = false, Last = true })
		end
		previous = point
	end
	return items
end

-- Detour -----------------------------------------------------------------------------------------------------------

-- Cast settings of a rig: its own collision group (other rigs, players and NpcPass props are not in the way)
local function sweepParams(mover: Mover): RaycastParams
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { mover.Model }
	params.RespectCanCollide = true
	params.CollisionGroup = mover.Root.CollisionGroup
	return params
end

-- First solid thing a rig-wide box meets walking flat from `a` to `b` on the floor `floorY`; nil = clear. A hit within
-- DETOUR_END of `b` does not count (the goal's own neighbour).
local function sweep(a: Vector3, b: Vector3, floorY: number, params: RaycastParams): RaycastResult?
	const height = DETOUR_TOP - DETOUR_BOTTOM
	const y = floorY + DETOUR_BOTTOM + height / 2
	const from = Vector3.new(a.X, y, a.Z)
	const delta = Vector3.new(b.X, y, b.Z) - from
	const length = delta.Magnitude
	if length < 0.05 then
		return nil
	end
	const hit = workspace:Blockcast(CFrame.lookAt(from, from + delta), Vector3.new(DETOUR_WIDTH, height, 0.2), delta, params)
	if hit ~= nil and hit.Distance >= length - DETOUR_END then
		return nil
	end
	return hit
end

-- Flat corners of `part`'s world box grown by DETOUR_MARGIN, at height `y`; nil when it is too big to walk around.
local function corners(part: BasePart, y: number): { Vector3 }?
	const frame, size = part.CFrame, part.Size
	local low = Vector3.new(math.huge, 0, math.huge)
	local high = -low
	for _, x in { -0.5, 0.5 } do
		for _, z in { -0.5, 0.5 } do
			for _, h in { -0.5, 0.5 } do
				const corner = frame * Vector3.new(size.X * x, size.Y * h, size.Z * z)
				low = Vector3.new(math.min(low.X, corner.X), 0, math.min(low.Z, corner.Z))
				high = Vector3.new(math.max(high.X, corner.X), 0, math.max(high.Z, corner.Z))
			end
		end
	end
	if high.X - low.X > DETOUR_SPAN or high.Z - low.Z > DETOUR_SPAN then
		return nil
	end
	const m = DETOUR_MARGIN
	return {
		Vector3.new(low.X - m, y, low.Z - m),
		Vector3.new(high.X + m, y, low.Z - m),
		Vector3.new(high.X + m, y, high.Z + m),
		Vector3.new(low.X - m, y, high.Z + m),
	}
end

-- The straight way from the rig to `target` is clear of props (Detour casts).
function Walker.Clear(mover: Mover, target: Vector3): boolean
	const start = mover.Root.Position
	return sweep(start, target, start.Y - LIFT, sweepParams(mover)) == nil
end

-- Points to walk through (in order, `target` excluded) to get around the props between the rig and `target`: the
-- shortest clear way over the corners of the blocking boxes. Empty = the straight way is clear, or no way around was
-- found (the caller walks straight, as before).
function Walker.Detour(mover: Mover, target: Vector3): { Vector3 }
	const start = mover.Root.Position
	const floorY = start.Y - LIFT
	const params = sweepParams(mover)
	const first = sweep(start, target, floorY, params)
	if first == nil then
		return {}
	end
	const points: { Vector3 } = { start, target } -- 1 = the rig, 2 = the goal, then the corners
	const known: { [Instance]: true } = {}
	const cache: { [number]: RaycastResult | false } = {}
	local count = 0
	local function add(part: Instance): boolean
		if known[part] ~= nil or count >= DETOUR_OBSTACLES or not part:IsA("BasePart") then
			return false
		end
		known[part] = true
		const list = corners(part, target.Y)
		if list == nil then
			return false
		end
		count += 1
		for _, corner in list do
			table.insert(points, corner)
		end
		return true
	end
	local function edge(i: number, j: number): RaycastResult?
		const key = math.min(i, j) * 64 + math.max(i, j)
		local hit: (RaycastResult | false)? = cache[key]
		if hit == nil then
			const swept: RaycastResult | false = sweep(points[i], points[j], floorY, params) or false
			cache[key] = swept
			hit = swept
		end
		return if hit == false or hit == nil then nil else hit
	end
	add(first.Instance)
	for _ = 1, DETOUR_OBSTACLES do
		-- Dijkstra over the few points (at most 2 + 4 * DETOUR_OBSTACLES)
		const n = #points
		const cost: { number } = table.create(n, math.huge)
		const from: { number } = table.create(n, 0)
		const done: { boolean } = table.create(n, false)
		const blockers: { Instance } = {}
		cost[1] = 0
		while true do
			local best, at = math.huge, 0
			for i = 1, n do
				if not done[i] and cost[i] < best then
					best, at = cost[i], i
				end
			end
			if at == 0 or at == 2 then
				break
			end
			done[at] = true
			for j = 1, n do
				if done[j] or j == at then
					continue
				end
				const length = flat(points[j] - points[at]).Magnitude
				if cost[at] + length >= cost[j] then
					continue
				end
				const hit = edge(at, j)
				if hit ~= nil then
					table.insert(blockers, hit.Instance)
					continue
				end
				cost[j] = cost[at] + length
				from[j] = at
			end
		end
		if cost[2] < math.huge then
			const way: { Vector3 } = {}
			local at = from[2]
			while at > 1 do
				table.insert(way, 1, points[at])
				at = from[at]
			end
			return way
		end
		local grew = false
		for _, part in blockers do
			if add(part) then
				grew = true
			end
		end
		if not grew then
			break
		end
	end
	return {}
end

-- Dev: little balls on the planned curve (Walker.SetDebug)
local function draw(items: { Item })
	const folder = Instance.new("Folder")
	folder.Name = "WalkDebug"
	for _, item in items do
		const ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.one * (if item.Loose then 0.6 else 1.2)
		ball.Anchored = true
		ball.CanCollide = false
		ball.CanQuery = false
		ball.CanTouch = false
		ball.Material = Enum.Material.Neon
		ball.Color = if item.Loose then Color3.fromRGB(255, 200, 60) else Color3.fromRGB(80, 160, 255)
		ball.Position = item.Position + Vector3.new(0, 0.5, 0)
		ball.Parent = folder
	end
	folder.Parent = workspace
	task.delay(12, function()
		folder:Destroy()
	end)
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
	aim(mover, flat(goal - position))
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
	gate: Gate?,
	motion: Motion?
): boolean
	const humanoid = mover.Humanoid
	local finished: boolean? = nil
	const connection = humanoid.MoveToFinished:Connect(function(reached: boolean)
		finished = reached
	end)
	const loose = motion ~= nil and motion.Loose
	const after = if motion ~= nil then motion.After else nil
	const easeOut = motion ~= nil and motion.EaseOut
	-- WalkSpeed easing: `base` is what the owner set; it is written back when the step ends
	const applied0 = humanoid.WalkSpeed
	const base = if motion ~= nil and motion.Base ~= nil then motion.Base else applied0
	local ramp = motion ~= nil and motion.EaseIn
	local rampAt = os.clock()
	local applied = applied0
	local function ease(distance: number, now: number)
		local factor = 1
		if ramp then
			const t = math.clamp((now - rampAt) / EASE.StartTime, 0, 1)
			factor = EASE.StartFactor + (1 - EASE.StartFactor) * t
		end
		if easeOut then
			const t = math.clamp(distance / EASE.BrakeDistance, 0, 1)
			factor = math.min(factor, EASE.EndFactor + (1 - EASE.EndFactor) * t)
		end
		const speed = base * factor
		if math.abs(speed - applied) > 0.05 then
			applied = speed
			humanoid.WalkSpeed = speed
		end
	end
	const accept = math.clamp(ACCEPT.PerSpeed * base, ACCEPT.Min, ACCEPT.Max)
	beginTurn(mover)
	aim(mover, headingTo(mover.Root.Position, target, after))
	if ramp or easeOut then
		ease(flat(target - mover.Root.Position).Magnitude, os.clock())
	end
	humanoid:MoveTo(target)
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
		-- a point that is only passed through: on to the next one without a stop
		if loose and distance < accept then
			finished = true
			break
		end
		-- spacing gate: stop behind a rig right ahead (at most GATE_MAX s per waypoint)
		if gate ~= nil and distance > ARRIVE and gated < GATE_MAX and gate(offset.Unit, distance) then
			if not waiting then
				waiting = true
				mover.Humanoid:MoveTo(mover.Root.Position)
				ramp = motion ~= nil -- walks on from rest: ease in again
			end
			gated += POLL
			deadline += POLL
			progressAt = now
			continue
		end
		if waiting then
			waiting = false
			rampAt = now
			aim(mover, headingTo(mover.Root.Position, target, after))
			mover.Humanoid:MoveTo(target)
			progressAt = now
		end
		if motion ~= nil then
			aim(mover, headingTo(mover.Root.Position, target, after))
			if ramp or easeOut then
				ease(distance, now)
			end
		end
		if distance < best - PROGRESS then
			best = distance
			progressAt = now
		elseif now - progressAt > STUCK_TIME then
			if motion ~= nil and motion.Near ~= nil and distance < motion.Near then
				finished = true -- stalled right beside the goal: close enough
				break
			end
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
	if (motion == nil or motion.Base == nil) and applied ~= base and humanoid.Parent ~= nil then
		humanoid.WalkSpeed = base
	end
	endTurn(mover)
	return finished == true
end

-- Turns the rig to face `look` (horizontal part only). A big turn is steered (capped angular speed, FaceTime s at
-- most); a small one, an anchored or a hidden rig is set at once.
function Walker.Face(mover: Mover, look: Vector3)
	const horizontal = flat(look)
	if horizontal.Magnitude < 1e-3 then
		return
	end
	const root = mover.Root
	const position = root.Position
	const goal = CFrame.lookAt(position, position + horizontal.Unit)
	const current = flat(root.CFrame.LookVector)
	const angle = if current.Magnitude < 1e-3 then 180 else math.deg(math.acos(math.clamp(current.Unit:Dot(horizontal.Unit), -1, 1)))
	if root.Anchored or not root:IsDescendantOf(workspace) or angle < TURN.FaceMin then
		endTurn(mover)
		root.CFrame = goal
		return
	end
	const turner = beginTurn(mover, current)
	turner.Align.CFrame = goal
	const token = turner.Token
	task.delay(TURN.FaceTime, function()
		if turner.Token == token and root.Parent ~= nil then
			endTurn(mover)
		end
	end)
end

-- Crosses to the far curb `point` under a reservation of `cw`. true = arrived (or snapped), false = cancelled.
local function cross(
	mover: Mover,
	point: Vector3,
	cw: string,
	crossing: Crossing,
	alive: () -> boolean,
	motion: Motion?
): boolean
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
	const arrived = step(mover, point, alive, crossing.MaxWait, false, nil, motion)
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
-- Corners are rounded and passed through without a stop (see the header); `options.Ease` (default true) eases WalkSpeed
-- at the start of the walk, after every stop and before the points it stops at.
function Walker.Follow(
	mover: Mover,
	points: { Vector3 },
	alive: () -> boolean,
	reached: (index: number) -> (),
	crossing: Crossing?,
	gate: Gate?,
	options: Options?
): boolean
	const items = plan(mover, points, crossing)
	if debugDraw then
		draw(items)
	end
	const easing = options == nil or options.Ease
	const base = mover.Humanoid.WalkSpeed
	local done = true
	for position, item in items do
		const motion: Motion = {
			Loose = item.Loose,
			After = if items[position + 1] then items[position + 1].Position else nil,
			EaseIn = easing and (position == 1 or not items[position - 1].Loose),
			EaseOut = easing and not item.Loose,
			Base = base,
		}
		const cw = if crossing and not item.Loose then crossing.At[item.Index] else nil
		if crossing ~= nil and cw ~= nil then
			if not cross(mover, item.Position, cw, crossing, alive, motion) then
				done = false
				break
			end
			reached(item.Index)
			continue
		end
		local arrived = false
		for _ = 0, RETRIES do
			if not alive() then
				break
			end
			arrived = step(mover, item.Position, alive, nil, true, gate, motion)
			if arrived then
				break
			end
		end
		if not alive() then
			done = false
			break
		end
		if not arrived then
			Walker.Snap(mover, item.Position)
		end
		if item.Last then
			reached(item.Index)
		end
	end
	if mover.Humanoid.Parent ~= nil and mover.Humanoid.WalkSpeed ~= base then
		mover.Humanoid.WalkSpeed = base
	end
	return done
end

-- Walk to `target` off the graph (seat approach points, pair partners; TASK-145/146): straight, or around the props in
-- the way (Walker.Detour). YIELDS. true = reached (or stalled within DIRECT_NEAR of it), false = gave up after
-- `timeout` s (default STEP_TIMEOUT, the whole walk) or cancelled. Never snaps: the caller decides.
function Walker.Direct(mover: Mover, target: Vector3, alive: () -> boolean, timeout: number?): boolean
	if not alive() then
		return false
	end
	const deadline = os.clock() + (timeout or STEP_TIMEOUT)
	const way = Walker.Detour(mover, target)
	if debugDraw and #way > 0 then
		const items: { Item } = {}
		for index, point in way do
			table.insert(items, { Position = point, Index = index, Loose = true, Last = true })
		end
		draw(items)
	end
	for index, point in way do
		const motion: Motion = { Loose = true, After = way[index + 1] or target, EaseIn = index == 1, EaseOut = false }
		step(mover, point, alive, math.max(deadline - os.clock(), POLL), false, nil, motion)
		if not alive() then
			return false
		end
	end
	return step(mover, target, alive, math.max(deadline - os.clock(), POLL), false, nil, {
		Loose = false,
		EaseIn = #way == 0,
		EaseOut = true,
		Near = DIRECT_NEAR,
	})
end

-- Stops any MoveTo in progress.
function Walker.Stop(mover: Mover)
	endTurn(mover)
	if mover.Root:IsDescendantOf(workspace) then
		mover.Humanoid:MoveTo(mover.Root.Position)
	end
end

-- Dev: draws the planned curve of every following walk for 12 s (yellow = passed through, blue = a stop)
function Walker.SetDebug(on: boolean)
	debugDraw = on
end

return table.freeze(Walker)
