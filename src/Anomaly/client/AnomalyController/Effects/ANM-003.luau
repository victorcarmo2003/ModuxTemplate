--!strict
--[[
	ANM-003 "The stopped clock", client effect (TASK-114; docs/story/anomalies.md N3; asset-list AST-044, AST-095 "003:
	nenhum VFX"; MAP-01 C-01 / AN-11; DEC-048, DEC-195). API: ../Effect.luau. Server: Anomalies/ANM-003.luau (TASK-113).

	The bank clock C-01 runs all the time on every client and stops while an ANM-003 occurrence is live:

	  - Running: `Hand_Hour` / `Hand_Minute` (AST-044; blockout `C-01_HourHand` / `C-01_MinuteHand`) show the game
	    clock (same hour as the HUD, DEC-048), one jump per game minute, turning around `Clock_Center` (empty of the
	    .fbx, see Assets/models/building/AST-044_BellmoorSavings_atts.json; fallback MapPoint AN-11, which sits on the
	    same axis). Ticking `amb_clock_tick` loops at `Audio_Tick` (fallback: the centre).
	  - Stopped (sign): from the record (Phase Signal/Active) or the cue `clock_stop`, hands freeze at the game time of
	    the record's StartedAt (same frozen time on every client, late joiners included) and the ticking stops. The HUD
	    clock keeps going (DEC-195: no frozen HUD).
	  - Resumed: cue `clock_resume` (success or failure) or the record leaving the set; the hands jump to the current
	    time and the ticking comes back.

	  - TASK-340 (owner 2026-10-15): cue `bell` (Entity = stroke 1..3) tolls the church bell (Kit/Bell: SFX, a small
	    "BELL n / 3" pill, a camera shudder); cue `swarm` (the trailer light was still on at the 3rd stroke): cartoon
	    moths and bats swarm the light and the players before everyone faints (server).

	Only local visual CFrames of the hand parts are written (purely visual; nobody else animates them). No VFX.

	PROVISIONAL (frontend-coder, TASK-114): (a) the Effect API has no boot hook and no task owns the running bank
	clock, so this module starts the clock driver when it is loaded, taking the Context from its AnomalyController
	(require of script.Parent.Parent at runtime); the architect may move the running clock to a Place/World
	controller and keep only the stop here. (b) The rotation axis is AN-11's LookVector, flipped toward the side the
	hands are on (face part `Clock_Face` / `C-01`); the hands' angle at build time is read from their geometry, so the
	AST-044 hands (built at 12:00) and the blockout ones (hour at 3:00) both work. (c) On resume the hands jump to
	the current time (the clock does not "lose" the stopped minutes: same hour as the HUD).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Effect = require(script.Parent.Parent.Effect)
local Bell = require(script.Parent.Kit.Bell)

const REF = "ANM-003"
const STOP_CUE = "clock_stop"
const RESUME_CUE = "clock_resume"
const TICK_SOUND = "amb_clock_tick"
const CLOCK_POINT = "AN-11" -- MapPoint on the C-01 axis (MAP-01 §10.3)
const CENTER_NAME = "Clock_Center"
const TICK_NAME = "Audio_Tick"
const FACE_NAMES = { "Clock_Face", "C-01" }

type HandKind = "Hour" | "Minute"

-- AST-044 names first (preferred when both exist), then the MAP-01 blockout
const HAND_NAMES: { [string]: HandKind } = {
	Hand_Hour = "Hour",
	Hand_Minute = "Minute",
	["C-01_HourHand"] = "Hour",
	["C-01_MinuteHand"] = "Minute",
}
const PREFERRED: { [string]: boolean } = { Hand_Hour = true, Hand_Minute = true }

const STEP_EVERY = 0.1 -- s between two driver steps
const RESCAN_EVERY = 3 -- s between two Workspace scans while the clock is missing (streaming, map loading)
const STOP_GRACE = 3 -- s a clock_stop cue is held while its record has not arrived yet
const MINUTES_HOUR = 60
const MINUTES_DIAL = 720
const TAU = 2 * math.pi
const EPSILON = 1e-3

type Hand = {
	Instance: PVInstance,
	Kind: HandKind,
	Base: CFrame, -- pivot as built (server pose)
	Angle0: number, -- clockwise angle from 12 as built (radians)
}

type Clock = {
	Center: Vector3,
	Axis: Vector3, -- toward the viewer (clockwise = negative turn around it)
	Hands: { Hand },
	SoundAt: Instance | Vector3,
}

type Stop = { At: number } -- server time the clock stopped

-- Driver state (module-level: one bank clock per place) ----------------------------------------------------------

local context: Effect.Context? = nil
local clock: Clock? = nil
local started = false
local failed = false
local lastStep = 0
local lastScan = -math.huge
local shownMinute: number? = nil
local soundAt: (Instance | Vector3)? = nil
local soundOn = false

-- Live stops: occurrence -> its stop; `pending` = a clock_stop cue whose record is not here yet.
const stops: { [Effect.Occurrence]: Stop } = {}
local pending: Stop? = nil
-- Occurrences that already got clock_resume (the record may outlive the cue for a moment)
const resumed: { [Effect.Occurrence]: boolean } = setmetatable({}, { __mode = "k" }) :: any
-- Frozen game minute while stopped (nil = running)
local frozen: number? = nil

-- Geometry --------------------------------------------------------------------------------------------------------

local function positionOf(instance: Instance): Vector3?
	if instance:IsA("Attachment") then
		return instance.WorldPosition
	elseif instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Model") then
		return instance:GetPivot().Position
	end
	return nil
end

-- Clockwise angle from 12 (as seen from the front) of the hand's centre around the axis.
local function angleOf(position: Vector3, center: Vector3, axis: Vector3): number
	const offset = position - center
	local up = Vector3.yAxis - axis * Vector3.yAxis:Dot(axis)
	if up.Magnitude < EPSILON then
		return 0
	end
	up = up.Unit
	const right = up:Cross(axis)
	const x, y = offset:Dot(right), offset:Dot(up)
	if math.abs(x) < EPSILON and math.abs(y) < EPSILON then
		return 0 -- pivot on the axis: assume built at 12
	end
	return math.atan2(x, y)
end

local function handCentre(instance: PVInstance): Vector3
	if instance:IsA("BasePart") then
		return instance.Position -- box centre: off the axis, toward the tip
	end
	const model = instance :: Model
	const cf, _ = model:GetBoundingBox()
	return cf.Position
end

local function findIn(root: Instance, name: string): Instance?
	return root:FindFirstChild(name, true)
end

-- Scans the Workspace for the clock C-01 (nil if the hands or the axis are not there).
local function discover(ctx: Effect.Context): Clock?
	const found: { [HandKind]: PVInstance } = {}
	for _, descendant in Workspace:GetDescendants() do
		const kind = HAND_NAMES[descendant.Name]
		if kind == nil or not descendant:IsA("PVInstance") then
			continue
		end
		const current = found[kind]
		if current == nil or (PREFERRED[descendant.Name] and not PREFERRED[current.Name]) then
			found[kind] = descendant
		end
	end
	const anyHand = found.Minute or found.Hour
	if anyHand == nil then
		return nil
	end
	const root: Instance = anyHand:FindFirstAncestorWhichIsA("Model") or anyHand.Parent or Workspace

	const point = ctx.Point(CLOCK_POINT)
	local center: Vector3? = nil
	const centerMark = findIn(root, CENTER_NAME)
	if centerMark ~= nil then
		center = positionOf(centerMark)
	end
	if center == nil and point ~= nil then
		center = point.Position
	end
	if center == nil then
		const face = findIn(root, FACE_NAMES[2])
		center = if face ~= nil then positionOf(face) else nil
	end
	if center == nil then
		return nil
	end
	const centerAt: Vector3 = center

	-- axis: AN-11 faces out of the facade; flip it toward the hands' side of the face
	local axis = if point ~= nil then point.LookVector else Vector3.zAxis
	axis = Vector3.new(axis.X, 0, axis.Z)
	axis = if axis.Magnitude > EPSILON then axis.Unit else Vector3.zAxis
	for _, name in FACE_NAMES do
		const face = findIn(root, name)
		const facePosition = if face ~= nil then positionOf(face) else nil
		if facePosition ~= nil then
			if (handCentre(anyHand) - facePosition):Dot(axis) < 0 then
				axis = -axis
			end
			break
		end
	end

	const hands: { Hand } = {}
	for kind, instance in found do
		const base = instance:GetPivot()
		table.insert(hands, {
			Instance = instance,
			Kind = kind,
			Base = base,
			Angle0 = angleOf(handCentre(instance), centerAt, axis),
		})
	end

	const tick = findIn(root, TICK_NAME)
	return {
		Center = centerAt,
		Axis = axis,
		Hands = hands,
		SoundAt = if tick ~= nil then tick else centerAt,
	}
end

local function valid(current: Clock): boolean
	for _, hand in current.Hands do
		if not hand.Instance:IsDescendantOf(Workspace) then
			return false
		end
	end
	return true
end

-- Game time -------------------------------------------------------------------------------------------------------

-- Continuous game minute at server time `t` (RoundController.Clock, network.md §3.1); nil before the first record.
local function minutesAt(ctx: Effect.Context, t: number): number?
	const round = ctx.Round.Clock
	if round == nil then
		return nil
	end
	local minutes = round.ClockFrom
	if round.PhaseDuration > 0 then
		const alpha = math.clamp((t - round.PhaseStartedAt) / round.PhaseDuration, 0, 1)
		minutes = round.ClockFrom + (round.ClockTo - round.ClockFrom) * alpha
	end
	return minutes
end

-- Hands -----------------------------------------------------------------------------------------------------------

local function pose(current: Clock, minute: number)
	const center = current.Center
	for _, hand in current.Hands do
		const target = if hand.Kind == "Minute"
			then (minute % MINUTES_HOUR) / MINUTES_HOUR * TAU
			else (minute % MINUTES_DIAL) / MINUTES_DIAL * TAU
		const turn = CFrame.fromAxisAngle(current.Axis, -(target - hand.Angle0))
		hand.Instance:PivotTo(CFrame.new(center) * turn * CFrame.new(-center) * hand.Base)
	end
end

local function setTicking(ctx: Effect.Context, at: (Instance | Vector3)?, on: boolean)
	if soundAt ~= nil and (soundAt ~= at or not on) and soundOn then
		ctx.Audio:Loop(TICK_SOUND, soundAt, false)
		soundOn = false
	end
	soundAt = at
	if on and at ~= nil and not soundOn then
		ctx.Audio:Loop(TICK_SOUND, at, true)
		soundOn = true
	end
end

-- Stops -----------------------------------------------------------------------------------------------------------

-- Earliest live stop (nil = running).
local function stoppedAt(): number?
	local at: number? = nil
	for _, stop in stops do
		if at == nil or stop.At < at then
			at = stop.At
		end
	end
	const held = pending
	if held ~= nil and (at == nil or held.At < at) then
		at = held.At
	end
	return at
end

local function refreshFrozen(ctx: Effect.Context)
	const at = stoppedAt()
	if at == nil then
		frozen = nil
	elseif frozen == nil then
		frozen = minutesAt(ctx, at)
	end
	shownMinute = nil -- repose on the next step
end

local function setStop(ctx: Effect.Context, occ: Effect.Occurrence, at: number?)
	if at ~= nil and not resumed[occ] then
		stops[occ] = { At = at }
	else
		stops[occ] = nil
	end
	pending = nil
	refreshFrozen(ctx)
end

-- Driver ----------------------------------------------------------------------------------------------------------

local function step(ctx: Effect.Context)
	const now = ctx.Now()
	const held = pending
	if held ~= nil and now - held.At > STOP_GRACE then
		pending = nil -- the record never came: run again
		refreshFrozen(ctx)
	end

	local current = clock
	if current ~= nil and not valid(current) then
		clock = nil
		current = nil
		shownMinute = nil
	end
	if current == nil then
		const t = os.clock()
		if t - lastScan < RESCAN_EVERY then
			setTicking(ctx, nil, false)
			return
		end
		lastScan = t
		current = discover(ctx)
		clock = current
		if current == nil then
			setTicking(ctx, nil, false)
			return
		end
	end
	const found = current :: Clock -- non-nil here (both branches above return or assign)

	const running = frozen == nil
	setTicking(ctx, found.SoundAt, running)

	const minutes = if running then minutesAt(ctx, now) else frozen
	if minutes == nil then
		return
	end
	const minute = math.floor(minutes)
	if minute == shownMinute then
		return
	end
	shownMinute = minute
	pose(found, minute)
end

local function start(ctx: Effect.Context)
	context = context or ctx
	if started then
		return
	end
	started = true
	RunService.Heartbeat:Connect(function()
		const active = context
		if failed or active == nil then
			return
		end
		const t = os.clock()
		if t - lastStep < STEP_EVERY then
			return
		end
		lastStep = t
		const ok, problem = pcall(step, active)
		if not ok then
			failed = true
			warn(`[AnomalyController] Effects/{REF} clock driver stopped: {problem}`)
		end
	end)
end

-- Boot: the clock runs from the start, not only after the first N3 (PROVISIONAL (a), see header).
task.defer(function()
	const ok, ctx = pcall(function(): Effect.Context
		const controller = (require :: any)(script.Parent.Parent)
		return controller:Context()
	end)
	if ok then
		start(ctx)
	else
		warn(`[AnomalyController] Effects/{REF}: no context at boot, the clock starts with the first N3 ({ctx})`)
	end
end)

-- Module ----------------------------------------------------------------------------------------------------------

const StoppedClock: Effect.Module = {
	Ref = REF,

	Mount = function(ctx: Effect.Context, occ: Effect.Occurrence)
		start(ctx)
		Vide.effect(function()
			const record = occ.Record()
			const live = record.Phase == "Signal" or record.Phase == "Active"
			setStop(ctx, occ, if live then record.StartedAt else nil)
		end)
		Vide.cleanup(function()
			stops[occ] = nil
			refreshFrozen(ctx)
		end)
	end,

	Cue = function(ctx: Effect.Context, cue: Effect.Cue)
		start(ctx)
		const occ = cue.Occurrence
		if cue.Cue == STOP_CUE then
			if occ ~= nil then
				setStop(ctx, occ, Vide.untrack(occ.Record).StartedAt)
			else
				pending = { At = cue.At }
				refreshFrozen(ctx)
			end
		elseif cue.Cue == "bell" then
			Bell.Stroke(ctx, cue.Entity)
		elseif cue.Cue == "swarm" then
			Bell.Swarm(ctx, cue.Rng)
		elseif cue.Cue == RESUME_CUE then
			if occ ~= nil then
				resumed[occ] = true
				stops[occ] = nil
			end
			pending = nil
			refreshFrozen(ctx)
		end
	end,
}

return StoppedClock
