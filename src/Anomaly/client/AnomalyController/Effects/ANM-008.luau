--!strict
--[[
	ANM-008 The long car: client effect (TASK-118, TASK-331; anomalies.md N8; architecture.md §19.13 "Long car"; AST-065,
	AST-083, AST-095 row 008; sound-list SFX-151..154).

	Presents only. AnomalyService decides who closed the window and who is scared; this file never reads a hide.

	Mount (one occurrence of the `Anomalies` set):
	  * local car from the TASK-099 kit `ReplicatedStorage.Assets.Vehicles.LongCar` (placeholder black block if the
	    kit is missing). Anchored, no collision / query / touch: never hits anyone (T117-07).
	  * timeline from `StartedAt` (same pose on every client, a late joiner sees it parked), owner request 2026-10-15
	    (TASK-331): it comes in from E-IN and ROLLS SLOWLY down the Ninth WB lane, then suddenly SPEEDS UP onto the
	    front of the trailer (shared/Anomaly/TrailerFront: the same pose the server tests) and BRAKES with a skid, nose
	    on the service window. Lane = MapPoint E-IN (position + LookVector), never world constants.
	  * high beam when parked AND (Phase = Active OR cue `car_highbeam` arrived): kit SpotLights `HighBeam` + 2 cold
	    `Beam`s from Light_HighL/R to the service window; the goofy horn the first time it turns on.
	  * Phase Resolved / Failed (or the record leaves the set): beam off, the car backs out onto the lane and drives on,
	    then is destroyed. Engine hum (`car_engine`) on the car, pitched up while it rushes.
	Cues: `car_highbeam` (beam on), `car_flash` (beam blinks twice), `car_honk` (low soft honk on the car),
	`trailer_blackout` (trailer lights off locally for the cue Duration), `jumpscare` (Entity = UserId % 65536: only that
	client is BLINDED by the beam - white-out, bloom, washed grade - and then shows the face; the sanity loss is the
	server's, no faint: owner 2026-10-19).
	Parked, the two kit SpotLights (`HighBeam` in Light_HighL/R) are re-aimed at the service window (TrailerFront.Window),
	not left along the body (owner 2026-10-19: they lit the diagonal).

	PROVISIONAL (TASK-331) - numbers Rules/ANM-008 must match on the server: ARRIVE_TIME = SLOW + RUSH + BRAKE = 8.2 s
	after StartedAt the car is braked; the beam comes BeamDelay (5 s) later (server cue/phase). Brake screech `car_screech` (Id "" until
	the owner sends it: silence).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local TrailerFront = require(ReplicatedStorage.shared.Anomaly.TrailerFront)
local Effect = require(script.Parent.Parent.Effect)
local Jumpscare = require(script.Parent.Kit.Jumpscare)
local Watch = require(script.Parent.Kit.Watch)

-- Route: the Ninth WB lane comes in at E-IN (position + LookVector = travel direction), so the route follows the map
-- whatever its orientation in the place (2026-10-10: the place is turned 180 in Y).
const EDGE_RUN = 4 -- studs before E-IN where the car appears
const RUSH_RUN = 34 -- studs before the trailer front (along the lane) where the car floors it
const BACK_TIME = 1.6 -- s backing out onto the lane when it leaves
const LEAVE_SPEED = 26 -- studs/s at the end of the leave ease-in
const LEAVE_RUN = 170 -- studs driven along the lane before it vanishes
const ENTITY_MOD = 65536
-- Fallbacks when the points are not streamed in: MAP-01 (x, z) through the map frame (x, z) -> (-x, K - z)
const MAP_K = 67.887287 -- tools/assetplace/map_frame.luau K
local function mapPoint(x: number, z: number): Vector3
	return Vector3.new(-x, 0, MAP_K - z)
end
const FALLBACK_E_IN = CFrame.lookAt(mapPoint(136, -5), mapPoint(135, -5)) -- WB lane, travelling MAP-01 west
const FALLBACK_TRL = CFrame.lookAt(mapPoint(70, 20), mapPoint(70, 0))

-- Timeline (seconds; PROVISIONAL, see header)
const SLOW_TIME = 5.6 -- rolling slowly: the warning
const RUSH_TIME = 1.8 -- floors it
const BRAKE_TIME = 0.8 -- skids round to face the window
const ARRIVE_TIME = SLOW_TIME + RUSH_TIME + BRAKE_TIME
const SLOW_SHARE = 0.35 -- share of the lane run covered while rolling, at least (the rest is the rush)
const ENGINE_RUSH = 1.8 -- engine PlaybackSpeed while rushing
const SCREECH = "car_screech"

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

-- Flash (cue car_flash, Duration 1): off/on twice
const FLASH = { { false, 0.15 }, { true, 0.2 }, { false, 0.15 }, { true, 0 } }
const HONK_SPEED = 0.75 -- lower pitch: "buzina grave, curta, baixa" (SFX-154 has no key yet)
const HONK_VOLUME = 0.8
-- Comic scare (user request 2026-10-10): `car_honk_goofy` at full row volume (not opts.Scare: outside the DEC-173 cap)
-- the first time the beam turns on with the car parked. A car already parked with the beam on when this client
-- mounts it (late joiner) does not honk.
const GOOFY_HONK = "car_honk_goofy"

-- Blinding (owner 2026-10-19: "estourar a visão"): the caught player is blown out by the high beam, then the face.
const BLIND_NAME = "ANM008_Blind"
const BLIND_ORDER = 49 -- under the jumpscare face (Kit/Jumpscare DisplayOrder 50)
const BLIND_HOLD = 0.35 -- s of pure white before the fade
const BLIND_FADE = 2.6 -- s back to normal
const BLIND_BRIGHTNESS = 1.2 -- ColorCorrection at the peak: blown out, cold, no colour
const BLIND_CONTRAST = -0.4
const BLIND_SATURATION = -1
const BLIND_BLOOM_INTENSITY = 4
const BLIND_BLOOM_SIZE = 56
const BLIND_BLOOM_THRESHOLD = 0.3
const BLIND_SPOT_BRIGHTNESS = 14 -- the high beam flares for this client while it blinds
const BLIND_SPOT_RANGE = 60
const FACE_DELAY = 0.45 -- s into the white-out the face pops

-- Driver (TASK-588; design/horror-cinematic.md §11.2 "nas câmeras o carro não tem motorista"): a dark head and shoulders
-- behind the wheel, seen with the bare eye only; on a security camera (Kit/Watch) the seat is empty. Placeholder Parts
-- (PROVISIONAL), on the window side of the car, a third of the way back from the nose.
const DRIVER_COLOR = Color3.fromHex("#07060B")
const DRIVER_SIDE = -0.22 -- share of the car width from the centre (the driver's side; -X = left)
const DRIVER_BACK = 0.3 -- share of the car length from the nose
const DRIVER_HEAD = 1.1 -- studs
const DRIVER_SHOULDERS = Vector3.new(1.7, 1.1, 0.9)

-- Trailer blackout (cue trailer_blackout): groups of the trailer, lamp look when off (LightController's)
const BLACKOUT_GROUPS = { "trailer_interior", "trailer_lights" }
const LAMP_OFF_COLOR = Color3.fromHex("#EAD6B0")

-- A lane = point on it + travel direction (horizontal unit)
type Lane = { Origin: Vector3, Dir: Vector3 }
type Route = { Wb: Lane, EdgeIn: Vector3, Front: TrailerFront.Front }

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
	Spot: CFrame, -- braked pose in front of the trailer
	Route: Route,
	StartedAt: number,
	Phase: Effect.Phase,
	Cued: boolean, -- car_highbeam arrived
	Flashing: boolean, -- beam forced by the flash sequence
	FlashOn: boolean,
	Parked: boolean, -- already placed on the spot
	Honked: boolean, -- goofy honk already played (or skipped for a late joiner)
	Rushing: boolean, -- engine pitched up
	Screeched: boolean, -- brake screech played (or skipped for a late joiner)
	Engine: Sound?,
	LeaveAt: number?, -- server time the car starts to pull out
	Orphan: boolean, -- the record left the set
	Done: boolean,
	Connection: RBXScriptConnection?,
	Driver: { BasePart }, -- TASK-588: hidden on the cameras
	DriverWatch: RBXScriptConnection?,
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

-- `p` projected on the lane line, at height y
local function onLane(l: Lane, p: Vector3, y: number): Vector3
	const q = l.Origin + l.Dir * (p - l.Origin):Dot(l.Dir)
	return Vector3.new(q.X, y, q.Z)
end

-- Lane from E-IN and the trailer front (TRL + WALKER-10), fallbacks when not streamed in
local function route(ctx: Effect.Context): Route
	const eIn = ctx.Point("E-IN") or FALLBACK_E_IN
	const wb: Lane = { Origin = eIn.Position, Dir = flatUnit(eIn.LookVector, Vector3.xAxis) }
	-- the car drives at the lane's height (E-IN sits on the road), never at the TRL pivot (below the street, TASK-348)
	-- TASK-490: in the restaurant it brakes at the drive-thru window (DT-STOP), the same pose as the server
	const front = TrailerFront.Pick(
		ctx.Point("TRL") or FALLBACK_TRL,
		ctx.Point("WALKER-10"),
		eIn,
		ctx.Point("DT-STOP")
	)
	return { Wb = wb, EdgeIn = wb.Origin - wb.Dir * EDGE_RUN, Front = front }
end

-- Key points of the run: lane start, where it floors it, the lane point abeam the trailer, the braked spot
local function keyPoints(r: Route): (Vector3, Vector3, Vector3, Vector3)
	const spot = r.Front.Stop.Position
	const y = spot.Y
	const abeam = onLane(r.Wb, spot, y)
	const start = onLane(r.Wb, r.EdgeIn, y)
	-- the rush starts RUSH_RUN studs before the trailer, never behind the lane start
	const run = math.max(0, (abeam - start):Dot(r.Wb.Dir))
	const rush = start + r.Wb.Dir * math.max(run * SLOW_SHARE, run - RUSH_RUN)
	return start, rush, abeam, spot
end

-- Pose while arriving / parked, `t` seconds after StartedAt
local function arrivePose(spot: CFrame, r: Route, t: number): CFrame
	const start, rush, abeam, stop = keyPoints(r)
	if t < SLOW_TIME then
		-- rolling slowly, a constant crawl down the lane
		return facing(start:Lerp(rush, math.max(t, 0) / SLOW_TIME), r.Wb.Dir)
	elseif t < SLOW_TIME + RUSH_TIME then
		-- floors it: ease-in along a curve that swings off the lane onto the trailer front
		const a = (t - SLOW_TIME) / RUSH_TIME
		const e = a * a
		return facing(bezier(rush, abeam, stop, e), bezierTangent(rush, abeam, stop, math.max(e, 0.05)))
	elseif t < ARRIVE_TIME then
		-- brakes: skids round until the nose points at the window
		const e = smooth((t - SLOW_TIME - RUSH_TIME) / BRAKE_TIME)
		const from = facing(stop, bezierTangent(rush, abeam, stop, 1))
		return from:Lerp(spot, e)
	end
	return spot
end

-- Pose while leaving, `u` seconds after LeaveAt; nil = gone
local function leavePose(state: CarState, u: number): CFrame?
	const r = state.Route
	const stop = state.Spot.Position
	const abeam = onLane(r.Wb, stop, stop.Y)
	if u < BACK_TIME then
		-- backs out onto the lane, still facing the trailer, turning to the lane at the end
		const e = smooth(u / BACK_TIME)
		const pose = facing(stop:Lerp(abeam, e), state.Spot.LookVector)
		return pose:Lerp(facing(abeam, r.Wb.Dir), e * e)
	end
	const v = u - BACK_TIME
	const accel = LEAVE_SPEED / 2 -- reaches LEAVE_SPEED after 2 s
	const run = if v < 2 then 0.5 * accel * v * v else accel * 2 + LEAVE_SPEED * (v - 2)
	if run > LEAVE_RUN then
		return nil
	end
	return facing(abeam + r.Wb.Dir * run, r.Wb.Dir)
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

-- Where the beams land: the service window of the trailer (TrailerFront), a bit up
local function beamTarget(lanes: Route): Vector3
	return lanes.Front.Window + Vector3.new(0, TRAILER_LIFT, 0)
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

-- TASK-588: the driver nobody sees on the cameras, added to the car model (it moves with it)
local function addDriver(model: Model): { BasePart }
	const pivot = model:GetPivot()
	const _, size = model:GetBoundingBox()
	const length = math.max(size.Z, size.X)
	const width = math.min(size.Z, size.X)
	const seat = pivot * CFrame.new(width * DRIVER_SIDE, size.Y * 0.62, -length / 2 + length * DRIVER_BACK)
	const parts: { BasePart } = {}
	for _, piece in {
		{ "DriverShoulders", Enum.PartType.Block, DRIVER_SHOULDERS, CFrame.new() },
		{ "DriverHead", Enum.PartType.Ball, Vector3.one * DRIVER_HEAD, CFrame.new(0, DRIVER_SHOULDERS.Y / 2 + DRIVER_HEAD * 0.45, 0) },
	} do
		const part = Instance.new("Part")
		part.Name = piece[1] :: string
		part.Shape = piece[2] :: Enum.PartType
		part.Size = piece[3] :: Vector3
		part.CFrame = seat * (piece[4] :: CFrame)
		part.Color = DRIVER_COLOR
		part.Material = Enum.Material.SmoothPlastic
		part.CastShadow = false
		part.Parent = model
		table.insert(parts, part)
	end
	return parts
end

local function showDriver(parts: { BasePart })
	const modifier = if Watch.Watching() then 1 else 0
	for _, part in parts do
		part.LocalTransparencyModifier = modifier
	end
end

local function buildCar(ctx: Effect.Context, occ: Effect.Occurrence): CarState
	const lanes = route(ctx)
	const spot = lanes.Front.Stop
	const model = cloneCar()
	model.Name = `LongCar_{occ.Id}`
	const body = model.PrimaryPart :: BasePart
	const pivot = model:GetPivot()
	const driver = addDriver(model)
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
	const target = beamTarget(lanes)
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
	const late = ctx.Now() - startedAt > ARRIVE_TIME
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
		Honked = late and Vide.untrack(occ.Record).Phase == "Active",
		Rushing = false,
		Screeched = late,
		Engine = nil,
		LeaveAt = nil,
		Orphan = false,
		Done = false,
		Connection = nil,
		Driver = driver,
		DriverWatch = Watch.Changed(function()
			showDriver(driver)
		end),
	}
	showDriver(driver)
	model:PivotTo(arrivePose(spot, lanes, ctx.Now() - startedAt))
	model.Parent = ctx.Folder()
	state.Engine = ctx.Audio:Loop("car_engine", body, true)
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
	if state.DriverWatch ~= nil then
		state.DriverWatch:Disconnect()
		state.DriverWatch = nil
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

-- The high beam straight at the service window: each kit SpotLight's attachment turned to the beam target
local function aimLights(state: CarState)
	const target = beamTarget(state.Route)
	for _, spot in state.Spots do
		const holder = spot.Parent
		if holder ~= nil and holder:IsA("Attachment") then
			holder.WorldCFrame = CFrame.lookAt(holder.WorldPosition, target)
		end
	end
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
	-- the rush: engine roars; the brake: one screech
	const t = now - state.StartedAt
	const rushing = t >= SLOW_TIME and t < SLOW_TIME + RUSH_TIME
	if rushing ~= state.Rushing then
		state.Rushing = rushing
		const engine = state.Engine
		if engine ~= nil and engine.Parent ~= nil then
			engine.PlaybackSpeed = if rushing then ENGINE_RUSH else 1
		end
	end
	if not state.Screeched and t >= SLOW_TIME + RUSH_TIME then
		state.Screeched = true
		state.Ctx.Audio:Play(SCREECH, state.Body)
	end
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
			aimLights(state)
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

-- White-out for this client only (cue jumpscare for us): own effects in Lighting, a white sheet under the face, the
-- beam flaring; everything eases back over BLIND_FADE and is destroyed.
local function blind(state: CarState?)
	const tint = Instance.new("ColorCorrectionEffect")
	tint.Name = BLIND_NAME
	tint.TintColor = BEAM_COLOR
	tint.Brightness = BLIND_BRIGHTNESS
	tint.Contrast = BLIND_CONTRAST
	tint.Saturation = BLIND_SATURATION
	tint.Parent = Lighting
	const bloom = Instance.new("BloomEffect")
	bloom.Name = BLIND_NAME
	bloom.Intensity = BLIND_BLOOM_INTENSITY
	bloom.Size = BLIND_BLOOM_SIZE
	bloom.Threshold = BLIND_BLOOM_THRESHOLD
	bloom.Parent = Lighting
	const gui = Instance.new("ScreenGui")
	gui.Name = BLIND_NAME
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.ClipToDeviceSafeArea = false
	gui.ResetOnSpawn = false
	gui.DisplayOrder = BLIND_ORDER
	const sheet = Instance.new("Frame")
	sheet.Size = UDim2.fromScale(1, 1)
	sheet.BackgroundColor3 = BEAM_COLOR
	sheet.BorderSizePixel = 0
	sheet.Parent = gui
	gui.Parent = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	const spots: { [SpotLight]: { number } } = {}
	if state ~= nil and not state.Done then
		for _, spot in state.Spots do
			spots[spot] = { spot.Brightness, spot.Range }
			spot.Brightness = BLIND_SPOT_BRIGHTNESS
			spot.Range = BLIND_SPOT_RANGE
		end
	end
	task.delay(BLIND_HOLD, function()
		const info = TweenInfo.new(BLIND_FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(tint, info, { TintColor = Color3.new(1, 1, 1), Brightness = 0, Contrast = 0, Saturation = 0 })
			:Play()
		TweenService:Create(bloom, info, { Intensity = 0 }):Play()
		TweenService:Create(sheet, info, { BackgroundTransparency = 1 }):Play()
		for spot, was in spots do
			if spot.Parent ~= nil then
				TweenService:Create(spot, info, { Brightness = was[1], Range = was[2] }):Play()
			end
		end
		task.wait(BLIND_FADE)
		tint:Destroy()
		bloom:Destroy()
		gui:Destroy()
	end)
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
				else route(ctx).Front.Stop.Position
			ctx.Audio:Play("car_honk_soft", at, { Speed = HONK_SPEED, Volume = HONK_VOLUME })
		elseif cue.Cue == "trailer_blackout" then
			blackout(ctx, cue.Row.Duration)
		elseif cue.Cue == "jumpscare" then
			if cue.Entity == Players.LocalPlayer.UserId % ENTITY_MOD then
				blind(state)
				task.delay(FACE_DELAY, Jumpscare.Show, ctx)
			end
		end
	end,
} :: Effect.Module
