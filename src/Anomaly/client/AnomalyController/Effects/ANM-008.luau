--!strict
--[[
	ANM-008 The long car: client effect (TASK-118; anomalies.md N8; architecture.md §19.13 "Long car"; MAP-01 §9.5
	ANM-008 route; AST-065, AST-083, AST-095 row 008; sound-list SFX-151..154).

	Presents only. AnomalyService (TASK-117) decides the window, who hid and who pays; this file never reads a hide.

	Mount (one occurrence of the `Anomalies` set):
	  * local car from the TASK-099 kit `ReplicatedStorage.Assets.Vehicles.LongCar` (placeholder black block if the
	    kit is missing). Anchored, no collision / query / touch: never hits anyone (T117-07).
	  * timeline from `StartedAt` (same pose on every client, a late joiner sees it parked): comes in from E-IN on
	    the Ninth WB lane, passes the parking mouth, stops, reverses into AN-12 facing MAP-01 south (MAP-01 §9.5).
	    Lanes = MapPoints E-IN / E-OUT (position + LookVector), never world constants (the place is turned 180).
	  * high beam when parked AND (Phase = Active OR cue `car_highbeam` arrived): kit SpotLights `HighBeam` (no
	    shadow, range 30, they light only the curb) + 2 cold `Beam`s from Light_HighL/R to the trailer (T118-01).
	  * Phase Resolved / Failed (or the record leaves the set): beam off, the car pulls out to the left onto the
	    Ninth EB lane and leaves by E-OUT, then is destroyed. Engine hum (`car_engine`) on the car while it exists.
	Cues: `car_highbeam` (beam on), `car_flash` (beam blinks twice), `car_honk` (low soft honk on the car),
	`trailer_blackout` (trailer lights off locally for the cue Duration, then LightController repaints; no rule).

	PROVISIONAL (frontend-coder, TASK-118) — numbers TASK-117 must match on the server:
	  ARRIVE_TIME = 9.5 s after StartedAt the car is parked on AN-12; `car_highbeam` + Phase Active should come
	  ~2 s later (StartedAt + 11.5). Keep the record LEAVE_TIME (~6 s) after Resolved/Failed so the car drives
	  away on every client; if the record goes earlier the car still leaves (it finishes on its own).
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Effect = require(script.Parent.Parent.Effect)

-- Route (MAP-01 §5.4): the Ninth WB lane comes in at E-IN, the EB lane leaves at E-OUT (behind the curve). The lanes
-- are read from the binding MapPoints (position + LookVector = travel direction), so the route follows the map
-- whatever its orientation in the place (2026-10-10: the place is turned 180 in Y, tools/assetplace/map_frame.luau).
const EDGE_RUN = 4 -- studs before E-IN where the car appears / past E-OUT where it vanishes
const REVERSE_LEAD = 14 -- studs past AN-12 along the WB lane (MAP-01 west) where the car stops before reversing
const LEAVE_TURN_RUN = 16 -- studs along the EB lane (MAP-01 east) where the left turn meets the EB lane
-- Fallbacks when the points are not streamed in: MAP-01 (x, z) through the map frame (x, z) -> (-x, K - z)
const MAP_K = 67.887287 -- tools/assetplace/map_frame.luau K
local function mapPoint(x: number, z: number): Vector3
	return Vector3.new(-x, 0, MAP_K - z)
end
const FALLBACK_SPOT = CFrame.lookAt(mapPoint(70, -22), mapPoint(70, 0)) -- AN-12, facing MAP-01 south
const FALLBACK_E_IN = CFrame.lookAt(mapPoint(136, -5), mapPoint(135, -5)) -- WB lane, travelling MAP-01 west
const FALLBACK_E_OUT = CFrame.lookAt(mapPoint(136, 5), mapPoint(137, 5)) -- EB lane, travelling MAP-01 east

-- Timeline (seconds; PROVISIONAL, see header)
const DRIVE_TIME = 6
const PAUSE_TIME = 0.5
const REVERSE_TIME = 3
const ARRIVE_TIME = DRIVE_TIME + PAUSE_TIME + REVERSE_TIME
const LEAVE_TURN_TIME = 3.5
const TURN_SAMPLES = 12

-- Look (AST-065: black #14162A, high beam cold white #F4F7FF)
const CAR_COLOR = Color3.fromHex("#14162A")
const BEAM_COLOR = Color3.fromHex("#F4F7FF")
const CREAM = Color3.fromHex("#FFF1D6")
const FALLBACK_SIZE = Vector3.new(7.1, 4, 19.5)
const BEAM_WIDTH_START = 1.4
const BEAM_WIDTH_END = 9
const BEAM_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.35),
	NumberSequenceKeypoint.new(0.6, 0.75),
	NumberSequenceKeypoint.new(1, 0.92),
})
const BEAM_SPREAD = 2 -- studs between the two beam ends on the trailer
const TRAILER_LIFT = 4 -- studs above the trailer centre the beams aim at (service window height)
const TRAILER_FALLBACK_RANGE = 63 -- MAP-01: ~63 studs from AN-12 to the trailer window
const VEHICLE_TAG = "Vehicle"

-- Flash (cue car_flash, Duration 1): off/on twice
const FLASH = { { false, 0.15 }, { true, 0.2 }, { false, 0.15 }, { true, 0 } }
const HONK_SPEED = 0.75 -- lower pitch: "buzina grave, curta, baixa" (SFX-154 has no key yet)
const HONK_VOLUME = 0.8
-- Comic scare (user request 2026-10-10): `car_honk_goofy` at full row volume (not opts.Scare: outside the DEC-173 cap)
-- the first time the beam turns on with the car parked. A car already parked with the beam on when this client
-- mounts it (late joiner) does not honk.
const GOOFY_HONK = "car_honk_goofy"

-- Trailer blackout (cue trailer_blackout): groups of the trailer, lamp look when off (LightController's)
const BLACKOUT_GROUPS = { "trailer_interior", "trailer_lights" }
const LAMP_OFF_COLOR = Color3.fromHex("#EAD6B0")

-- A lane = point on it + travel direction (horizontal unit)
type Lane = { Origin: Vector3, Dir: Vector3 }
type Route = { Wb: Lane, Eb: Lane, EdgeIn: Vector3, EdgeOut: Vector3 }

type CarState = {
	Ctx: Effect.Context,
	Model: Model,
	Body: BasePart,
	Parts: { BasePart },
	Offsets: { CFrame },
	Lamps: { BasePart },
	Spots: { SpotLight },
	Beams: { Beam },
	Target: BasePart, -- beam ends on the trailer
	Spot: CFrame, -- AN-12 pose
	Route: Route, -- lanes from E-IN / E-OUT
	StartedAt: number,
	Phase: Effect.Phase,
	Cued: boolean, -- car_highbeam arrived
	Flashing: boolean, -- beam forced by the flash sequence
	FlashOn: boolean,
	Parked: boolean, -- already placed on the spot
	Honked: boolean, -- goofy honk already played (or skipped for a late joiner)
	LeaveAt: number?, -- server time the car starts to pull out
	TurnLength: number,
	Orphan: boolean, -- the record left the set
	Done: boolean,
	Connection: RBXScriptConnection?,
}

-- occurrence id -> live car (Cue reaches the car of its occurrence)
const cars: { [number]: CarState } = {}

-- Geometry ---------------------------------------------------------------------------------------------------------

local function bezier(a: Vector3, b: Vector3, c: Vector3, t: number): Vector3
	const u = 1 - t
	return a * (u * u) + b * (2 * u * t) + c * (t * t)
end

local function bezierTangent(a: Vector3, b: Vector3, c: Vector3, t: number): Vector3
	return (b - a) * (2 * (1 - t)) + (c - b) * (2 * t)
end

local function facing(position: Vector3, direction: Vector3): CFrame
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, 1)
	end
	return CFrame.lookAt(position, position + flat.Unit)
end

local function smooth(t: number): number
	const x = math.clamp(t, 0, 1)
	return x * x * (3 - 2 * x)
end

local function flatUnit(v: Vector3, default: Vector3): Vector3
	const flat = Vector3.new(v.X, 0, v.Z)
	return if flat.Magnitude > 1e-3 then flat.Unit else default
end

local function lane(point: CFrame): Lane
	return { Origin = point.Position, Dir = flatUnit(point.LookVector, Vector3.xAxis) }
end

-- Lanes of the route from the binding (E-IN = WB lane, E-OUT = EB lane), fallbacks when not streamed in
local function route(ctx: Effect.Context): Route
	const eIn = ctx.Point("E-IN") or FALLBACK_E_IN
	const eOut = ctx.Point("E-OUT") or FALLBACK_E_OUT
	const wb, eb = lane(eIn), lane(eOut)
	return { Wb = wb, Eb = eb, EdgeIn = wb.Origin - wb.Dir * EDGE_RUN, EdgeOut = eb.Origin + eb.Dir * EDGE_RUN }
end

-- `p` projected on the lane line, at height y
local function onLane(l: Lane, p: Vector3, y: number): Vector3
	const q = l.Origin + l.Dir * (p - l.Origin):Dot(l.Dir)
	return Vector3.new(q.X, y, q.Z)
end

-- Reverse curve: from the WB lane past the spot, back into the spot (faces along the WB lane, then the spot)
local function reverseCurve(spot: CFrame, r: Route): (Vector3, Vector3, Vector3)
	const p = spot.Position
	const r1 = onLane(r.Wb, p, p.Y)
	return r1 + r.Wb.Dir * REVERSE_LEAD, r1, p
end

-- Leave curve: out of the spot forward, turning left onto the EB lane
local function leaveCurve(spot: CFrame, r: Route): (Vector3, Vector3, Vector3)
	const p = spot.Position
	const l1 = onLane(r.Eb, p, p.Y)
	return p, l1, l1 + r.Eb.Dir * LEAVE_TURN_RUN
end

local function curveLength(a: Vector3, b: Vector3, c: Vector3): number
	local length = 0
	local last = a
	for i = 1, TURN_SAMPLES do
		const point = bezier(a, b, c, i / TURN_SAMPLES)
		length += (point - last).Magnitude
		last = point
	end
	return length
end

-- Pose while arriving / parked, `t` seconds after StartedAt
local function arrivePose(spot: CFrame, r: Route, t: number): CFrame
	const r0, r1, r2 = reverseCurve(spot, r)
	if t < DRIVE_TIME then
		-- ease-out along the WB lane: comes in fast, stops past the parking mouth
		const a = math.max(t, 0) / DRIVE_TIME
		const e = 1 - (1 - a) * (1 - a)
		const start = onLane(r.Wb, r.EdgeIn, spot.Position.Y)
		return facing(start:Lerp(r0, e), r.Wb.Dir)
	elseif t < DRIVE_TIME + PAUSE_TIME then
		return facing(r0, r.Wb.Dir)
	elseif t < ARRIVE_TIME then
		const e = smooth((t - DRIVE_TIME - PAUSE_TIME) / REVERSE_TIME)
		-- reversing: the car faces against its motion
		return facing(bezier(r0, r1, r2, e), -bezierTangent(r0, r1, r2, e))
	end
	return spot
end

-- Pose while leaving, `u` seconds after LeaveAt; nil = past E-OUT
local function leavePose(state: CarState, u: number): CFrame?
	const spot = state.Spot
	const l0, l1, l2 = leaveCurve(spot, state.Route)
	if u < LEAVE_TURN_TIME then
		-- ease-in out of the spot ("vai embora devagar")
		const a = math.max(u, 0) / LEAVE_TURN_TIME
		const e = a * a
		return facing(bezier(l0, l1, l2, e), bezierTangent(l0, l1, l2, e))
	end
	const speed = 2 * state.TurnLength / LEAVE_TURN_TIME -- end speed of the ease-in
	const eb = state.Route.Eb
	const run = speed * (u - LEAVE_TURN_TIME)
	if run > (state.Route.EdgeOut - l2):Dot(eb.Dir) then
		return nil
	end
	return facing(l2 + eb.Dir * run, eb.Dir)
end

-- Model --------------------------------------------------------------------------------------------------------------

local function fallbackModel(): Model
	const model = Instance.new("Model")
	model.Name = "LongCar"
	const body = Instance.new("Part")
	body.Name = "Body"
	body.Size = FALLBACK_SIZE
	body.Color = CAR_COLOR
	body.Material = Enum.Material.SmoothPlastic
	body.CFrame = CFrame.new(0, FALLBACK_SIZE.Y / 2, 0)
	body.Parent = model
	model.PrimaryPart = body
	body.PivotOffset = body.CFrame:Inverse() -- pivot = base centre, like the kit
	const front = -FALLBACK_SIZE.Z / 2
	const lamps = Instance.new("Part")
	lamps.Name = "Headlights"
	lamps.Size = Vector3.new(5.2, 0.4, 0.2)
	lamps.Color = CREAM
	lamps.Material = Enum.Material.Neon
	lamps.CFrame = CFrame.new(0, 2.4, front - 0.1)
	lamps.Parent = model
	for _, side in { { "Light_HighL", -2.08 }, { "Light_HighR", 2.08 } } do
		const attachment = Instance.new("Attachment")
		attachment.Name = side[1] :: string
		attachment.CFrame = CFrame.new(side[2] :: number, 0.4, front)
		attachment.Parent = body
	end
	return model
end

local function cloneCar(): Model
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const vehicles = if assets then assets:FindFirstChild("Vehicles") else nil
	const template = if vehicles then vehicles:FindFirstChild("LongCar") else nil
	if template and template:IsA("Model") and template.PrimaryPart then
		return template:Clone()
	end
	return fallbackModel()
end

-- Current vehicle (trailer or cart) of the party: Vehicle tag with the Vehicle attribute of RoundController
local function vehicleModel(ctx: Effect.Context): Instance?
	const key = Vide.untrack(ctx.Round.Vehicle)
	for _, instance in CollectionService:GetTagged(VEHICLE_TAG) do
		if instance:GetAttribute("Vehicle") == key and instance:IsA("PVInstance") then
			return instance
		end
	end
	return nil
end

-- Where the beams land: centre of the current vehicle, a bit up (the service window)
local function beamTarget(ctx: Effect.Context, spot: CFrame): Vector3
	const vehicle = vehicleModel(ctx)
	if vehicle and vehicle:IsA("Model") then
		const box = vehicle:GetBoundingBox()
		return box.Position + Vector3.new(0, TRAILER_LIFT, 0)
	elseif vehicle and vehicle:IsA("BasePart") then
		return vehicle.Position + Vector3.new(0, TRAILER_LIFT, 0)
	end
	return spot.Position + spot.LookVector * TRAILER_FALLBACK_RANGE + Vector3.new(0, TRAILER_LIFT, 0)
end

local function makeBeam(from: Attachment, to: Attachment): Beam
	const beam = Instance.new("Beam")
	beam.Name = "HighBeam"
	beam.Attachment0 = from
	beam.Attachment1 = to
	beam.Color = ColorSequence.new(BEAM_COLOR)
	beam.Transparency = BEAM_TRANSPARENCY
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Width0 = BEAM_WIDTH_START
	beam.Width1 = BEAM_WIDTH_END
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Enabled = false
	beam.Parent = from
	return beam
end

local function buildCar(ctx: Effect.Context, occ: Effect.Occurrence): CarState
	const spot = ctx.Point("AN-12") or FALLBACK_SPOT
	const model = cloneCar()
	model.Name = `LongCar_{occ.Id}`
	const body = model.PrimaryPart :: BasePart
	const pivot = model:GetPivot()
	const parts: { BasePart } = {}
	const offsets: { CFrame } = {}
	const lamps: { BasePart } = {}
	const spots: { SpotLight } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			table.insert(parts, descendant)
			table.insert(offsets, pivot:Inverse() * descendant.CFrame)
			if descendant.Name == "Headlights" then
				descendant.Material = Enum.Material.Neon
				descendant.Color = CREAM
				table.insert(lamps, descendant)
			end
		elseif descendant:IsA("SpotLight") then
			descendant.Enabled = false
			descendant.Shadows = false
			table.insert(spots, descendant)
		end
	end

	-- beam ends on the trailer (one invisible anchor part, two attachments side by side)
	const target = beamTarget(ctx, spot)
	const holder = Instance.new("Part")
	holder.Name = "HighBeamTarget"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.CFrame = facing(target, target - spot.Position)
	holder.Parent = ctx.Folder() -- outside the car model: PivotTo must not carry it
	const beams: { Beam } = {}
	for i, name in { "Light_HighL", "Light_HighR" } do
		const from = body:FindFirstChild(name)
		if from and from:IsA("Attachment") then
			const to = Instance.new("Attachment")
			to.Name = `{name}_Target`
			to.Position = Vector3.new(if i == 1 then -BEAM_SPREAD / 2 else BEAM_SPREAD / 2, 0, 0)
			to.Parent = holder
			table.insert(beams, makeBeam(from, to))
		end
	end

	const startedAt = Vide.untrack(occ.Record).StartedAt
	const lanes = route(ctx)
	const l0, l1, l2 = leaveCurve(spot, lanes)
	const state: CarState = {
		Ctx = ctx,
		Model = model,
		Body = body,
		Parts = parts,
		Offsets = offsets,
		Lamps = lamps,
		Spots = spots,
		Beams = beams,
		Target = holder,
		Spot = spot,
		Route = lanes,
		StartedAt = startedAt,
		Phase = Vide.untrack(occ.Record).Phase,
		Cued = false,
		Flashing = false,
		FlashOn = false,
		Parked = false,
		Honked = ctx.Now() - startedAt > ARRIVE_TIME and Vide.untrack(occ.Record).Phase == "Active",
		LeaveAt = nil,
		TurnLength = curveLength(l0, l1, l2),
		Orphan = false,
		Done = false,
		Connection = nil,
	}
	model:PivotTo(arrivePose(spot, lanes, ctx.Now() - startedAt))
	model.Parent = ctx.Folder()
	ctx.Audio:Loop("car_engine", body, true)
	return state
end

-- State --------------------------------------------------------------------------------------------------------------

local function setBeam(state: CarState, on: boolean)
	for _, spot in state.Spots do
		if spot.Enabled ~= on then
			spot.Enabled = on
		end
	end
	for _, beam in state.Beams do
		if beam.Enabled ~= on then
			beam.Enabled = on
		end
	end
	const color = if on then BEAM_COLOR else CREAM
	for _, lamp in state.Lamps do
		if lamp.Color ~= color then
			lamp.Color = color
		end
	end
end

local function finish(state: CarState, occId: number)
	if state.Done then
		return
	end
	state.Done = true
	const connection = state.Connection
	if connection then
		connection:Disconnect()
		state.Connection = nil
	end
	state.Ctx.Audio:Loop("car_engine", state.Body, false)
	state.Model:Destroy()
	state.Target:Destroy()
	if cars[occId] == state then
		cars[occId] = nil
	end
end

local function place(state: CarState, pivot: CFrame)
	const cframes: { CFrame } = table.create(#state.Parts, CFrame.identity)
	for i, offset in state.Offsets do
		cframes[i] = pivot * offset
	end
	workspace:BulkMoveTo(state.Parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

local function step(state: CarState, occId: number)
	if state.Model.Parent == nil then
		finish(state, occId) -- night-end safety net emptied the folder
		return
	end
	const now = state.Ctx.Now()
	const parkedAt = state.StartedAt + ARRIVE_TIME
	if state.LeaveAt == nil and (state.Orphan or state.Phase == "Resolved" or state.Phase == "Failed") then
		state.LeaveAt = math.max(now, parkedAt)
	end
	const leaveAt = state.LeaveAt
	if leaveAt and now >= leaveAt then
		setBeam(state, false)
		const pose = leavePose(state, now - leaveAt)
		if pose == nil then
			finish(state, occId)
			return
		end
		place(state, pose)
		return
	end
	const parked = now >= parkedAt
	local beam = parked and (state.Phase == "Active" or state.Cued)
	if state.Flashing then
		beam = parked and state.FlashOn
	end
	setBeam(state, beam)
	if beam and not state.Honked then
		state.Honked = true
		state.Ctx.Audio:Play(GOOFY_HONK, state.Body)
	end
	if parked then
		-- parked pose is fixed: move only once after arriving
		if not state.Parked then
			state.Parked = true
			place(state, state.Spot)
		end
	else
		state.Parked = false
		place(state, arrivePose(state.Spot, state.Route, now - state.StartedAt))
	end
end

-- Trailer lights off locally for `duration` (flavor only: the server never drains for it, T117-06). While dark the
-- fixtures are marked "lit" so LightController (paints only on change) leaves them alone; afterwards they are marked
-- unknown so it repaints them on its next tick.
local function blackout(ctx: Effect.Context, duration: number)
	const light = ctx.Light
	const untilAt = os.clock() + duration
	while os.clock() < untilAt do
		for _, key in BLACKOUT_GROUPS do
			const fixtures = light.Fixtures[key]
			if fixtures == nil then
				continue
			end
			for _, fixture in fixtures do
				for _, lamp in fixture.Lamps do
					lamp.Part.Material = Enum.Material.SmoothPlastic
					lamp.Part.Color = LAMP_OFF_COLOR
				end
				for _, item in fixture.Lights do
					item.Enabled = false
				end
				fixture.Lit = true
				fixture.Live = true
			end
		end
		RunService.Heartbeat:Wait()
	end
	for _, key in BLACKOUT_GROUPS do
		const fixtures = light.Fixtures[key]
		if fixtures == nil then
			continue
		end
		for _, fixture in fixtures do
			fixture.Lit = nil
			fixture.Live = nil
		end
	end
end

local function flash(state: CarState)
	state.Flashing = true
	for _, frame in FLASH do
		if state.Done then
			return
		end
		state.FlashOn = frame[1] :: boolean
		const wait = frame[2] :: number
		if wait > 0 then
			task.wait(wait)
		end
	end
	state.Flashing = false
	state.Cued = true -- after the blink the beam stays on until the car leaves
end

return {
	Ref = "ANM-008",
	Mount = function(ctx: Effect.Context, occ: Effect.Occurrence)
		const previous = cars[occ.Id]
		if previous then
			finish(previous, occ.Id)
		end
		const state = buildCar(ctx, occ)
		cars[occ.Id] = state
		const occId = occ.Id
		state.Connection = RunService.RenderStepped:Connect(function()
			step(state, occId)
		end)
		Vide.effect(function()
			const record = occ.Record()
			state.Phase = record.Phase
			state.StartedAt = record.StartedAt
		end)
		Vide.cleanup(function()
			-- the record left the set: the car still drives away on its own, then destroys itself
			state.Orphan = true
		end)
	end,
	Cue = function(ctx: Effect.Context, cue: Effect.Cue)
		const occ = cue.Occurrence
		const state = if occ then cars[occ.Id] else nil
		if cue.Cue == "car_highbeam" then
			if state then
				state.Cued = true
			end
		elseif cue.Cue == "car_flash" then
			if state then
				flash(state)
			end
		elseif cue.Cue == "car_honk" then
			const at: Vector3 | Instance = if state and not state.Done
				then state.Body
				else (ctx.Point("AN-12") or FALLBACK_SPOT).Position
			ctx.Audio:Play("car_honk_soft", at, { Speed = HONK_SPEED, Volume = HONK_VOLUME })
		elseif cue.Cue == "trailer_blackout" then
			blackout(ctx, cue.Row.Duration)
		end
	end,
} :: Effect.Module
