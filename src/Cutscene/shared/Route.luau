--!strict
--[[
	Route: the walk of one body through the MoveTo beats of a scene, as a pure function of the segment time. Shared:
	CutsceneController steers the own body along it (smooth start, cruise, stop, rounded corners, no dry stop at a
	waypoint) and CutsceneService checks bodies against it at each MoveTo (re-place one that is far, R23).

	Runs: consecutive MoveTo beats form one run (one continuous walk through every target); a beat with `Arrive`
	closes its run there (eased to a stop by Arrive, then the body waits for the next MoveTo); the last MoveTo closes
	the last run. A run starts at its first beat (or when the previous run ended, if later), accelerates at
	Rules.Walk.Accel to a cruise speed that makes it end on time (clamped to MinSpeed..MaxSpeed: a walk that cannot
	make it ends late), and brakes at the same rate. A run without Arrive walks at Rules.Walk.Cruise.

	Facing: along the walk; while braking it blends to the facing of the end spot (a MoveTo point's facing, or the
	phone for the stand spots), so the body ends turned the right way without a snap.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Motion = require(ReplicatedStorage.shared.Traffic.Motion)

type Scene = Content.Cutscene
type Beat = Content.CutsceneBeat

export type Run = {
	T0: number,
	T1: number,
	Path: Motion.Path,
	Length: number,
	Cruise: number,
	Accel: number,
	Face: Vector3, -- horizontal facing at the end
}

export type Plan = {
	Start: CFrame?, -- the mark of the slot
	Runs: { Run },
	Missing: boolean, -- a target was not found (not streamed in yet): build again later
}

export type Spot = (target: string, slot: number, count: number) -> CFrame?

const WALK = Content.Cutscenes.Rules.Walk
const CORNER_SAMPLES = 6
const MIN_RUN = 0.4 -- studs: a shorter run is a turn in place
const HEADING_HALF = 1 -- studs each side for the walking heading

const Route = {}

local function flat(v: Vector3): Vector3?
	const f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else nil
end

-- Polyline through `points` with each inner corner rounded by a quadratic curve of up to WALK.Corner studs
local function rounded(points: { Vector3 }): { Vector3 }
	if #points < 3 then
		return points
	end
	const out: { Vector3 } = { points[1] }
	for i = 2, #points - 1 do
		const before, here, after = points[i - 1], points[i], points[i + 1]
		const inbound = here - before
		const outbound = after - here
		const lengthIn, lengthOut = inbound.Magnitude, outbound.Magnitude
		if lengthIn < 1e-3 or lengthOut < 1e-3 then
			table.insert(out, here)
			continue
		end
		const radius = math.min(WALK.Corner, lengthIn * 0.45, lengthOut * 0.45)
		const a = here - inbound.Unit * radius
		const b = here + outbound.Unit * radius
		for k = 0, CORNER_SAMPLES do
			const u = k / CORNER_SAMPLES
			const v = 1 - u
			table.insert(out, a * (v * v) + here * (2 * v * u) + b * (u * u))
		end
	end
	table.insert(out, points[#points])
	-- drop zero-length steps
	const clean: { Vector3 } = { out[1] }
	for i = 2, #out do
		if (out[i] - clean[#clean]).Magnitude > 1e-3 then
			table.insert(clean, out[i])
		end
	end
	return clean
end

-- Cruise speed and duration of a trapezoid walk of `length` studs that should last `time` s (nil = free pace)
local function pace(length: number, time: number?): (number, number)
	const accel = WALK.Accel
	local speed: number
	if time == nil or time <= 0 then
		speed = WALK.Cruise
	else
		-- length = v (T - v / a)  ->  v = a (T - sqrt(T^2 - 4 L / a)) / 2
		const disc = time * time - 4 * length / accel
		speed = if disc < 0 then WALK.MaxSpeed else accel * (time - math.sqrt(disc)) / 2
	end
	speed = math.clamp(speed, WALK.MinSpeed, WALK.MaxSpeed)
	-- too short to reach that speed: triangle profile
	speed = math.min(speed, math.sqrt(length * accel))
	return speed, length / speed + speed / accel
end

-- Distance and speed after `tau` s of a run
local function along(run: Run, tau: number): (number, number)
	const a, v, length = run.Accel, run.Cruise, run.Length
	const total = run.T1 - run.T0
	const ramp = v / a
	if tau <= 0 then
		return 0, 0
	elseif tau >= total then
		return length, 0
	elseif tau < ramp then
		return 0.5 * a * tau * tau, a * tau
	elseif tau > total - ramp then
		const left = total - tau
		return length - 0.5 * a * left * left, a * left
	end
	return 0.5 * a * ramp * ramp + v * (tau - ramp), v
end

function Route.Build(scene: Scene, slot: number, count: number, spot: Spot): Plan
	const marks = scene.Marks
	const start = if #marks > 0 then spot(marks[math.min(slot, #marks)], slot, count) else nil
	const plan: Plan = { Start = start, Runs = {}, Missing = start == nil and #marks > 0 }

	const moves: { Beat } = {}
	for _, beat in scene.Beats do
		if beat.Kind == "MoveTo" then
			table.insert(moves, beat)
		end
	end
	table.sort(moves, function(a: Beat, b: Beat): boolean
		return a.At < b.At
	end)

	local cursor: Vector3? = if start ~= nil then start.Position else nil
	local free = -math.huge -- when the body is free to leave (end of the previous run)
	local points: { Vector3 }? = nil
	local t0 = 0
	local endFace: Vector3? = nil

	for index, beat in moves do
		const target = spot(beat.Target, slot, count)
		if target == nil then
			plan.Missing = true
			continue
		end
		if cursor == nil then
			-- no mark: the first target is where the body already is
			cursor = target.Position
			endFace = flat(target.LookVector)
			continue
		end
		if points == nil then
			points = { cursor :: Vector3 }
			t0 = math.max(beat.At, free)
		end
		table.insert(points :: { Vector3 }, target.Position)
		endFace = flat(target.LookVector)
		if beat.Arrive ~= nil or index == #moves then
			const line = Motion.Path(rounded(points :: { Vector3 }))
			if line ~= nil and line.Length >= MIN_RUN then
				const time = if beat.Arrive ~= nil then beat.Arrive - t0 else nil
				const speed, duration = pace(line.Length, time)
				const lastHeading = Motion.Heading(line, line.Length, HEADING_HALF)
				table.insert(plan.Runs, {
					T0 = t0,
					T1 = t0 + duration,
					Path = line,
					Length = line.Length,
					Cruise = speed,
					Accel = WALK.Accel,
					Face = endFace or lastHeading,
				})
				free = t0 + duration
			end
			cursor = target.Position
			points = nil
		end
	end
	return plan
end

-- Where the body should be at segment time `t`: position, velocity, facing (nil position = nothing known)
function Route.Sample(plan: Plan, t: number): (Vector3?, Vector3, Vector3?)
	const start = plan.Start
	local position: Vector3? = if start ~= nil then start.Position else nil
	local facing: Vector3? = if start ~= nil then flat(start.LookVector) else nil
	for _, run in plan.Runs do
		if t < run.T0 then
			return position, Vector3.zero, facing
		end
		if t <= run.T1 then
			const s, speed = along(run, t - run.T0)
			const heading = Motion.Heading(run.Path, s, HEADING_HALF)
			-- braking: blend to the end facing
			const brake = run.Cruise * run.Cruise / (2 * run.Accel)
			const w = if brake > 1e-3 then math.clamp((s - (run.Length - brake)) / brake, 0, 1) else 1
			local face = heading:Lerp(run.Face, w * w)
			face = if face.Magnitude > 1e-3 then face.Unit else run.Face
			return Motion.PointAt(run.Path, s), heading * speed, face
		end
		position = Motion.PointAt(run.Path, run.Length)
		facing = run.Face
	end
	return position, Vector3.zero, facing
end

-- Segment time when the last run ends (0 = no walk)
function Route.EndTime(plan: Plan): number
	const last = plan.Runs[#plan.Runs]
	return if last ~= nil then last.T1 else 0
end

return table.freeze(Route)
