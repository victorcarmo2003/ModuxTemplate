--!strict
-- ANM-006 The stalker (DEC-260, replaces The wavers; TASK-351; owner request 2026-10-16). Rule in Rules/ANM-006.luau.
-- Verb dont_look. A tall figure stands on the far sidewalk in full view of the service window (shared/Anomaly/
-- StalkerPath on the TrailerFront frame, the same line on both sides). It only moves while somebody stares at it:
--   Start   MapPoint TRL bound (else Start false, retried, one warning) -> Phase Signal, Step 0.
--   Stare   every tick, if ANY Active player is Looking at it (gaze cone, ViewRange, line of sight; a player inside
--           the trailer with the window closed cannot see out), the stare clock runs; each StepEvery s of stare =
--           one step closer (record Step, the client lunges it forward). Nobody looking = it stands still.
--   Window  Step = Steps: Phase Active, LeapDelay s later it leaps in through the service window and attacks the
--           NEAREST Active player to the window, wherever he is (cue jumpscare Entity = UserId % 65536, ScareFaint s
--           later VitalService:Fall; DEC-255), Phase Failed. Window closed at that moment: it bangs on it (cue
--           stalker_bang) and leaves, Phase Resolved.
--   AutoOff nobody brought it to the window in AutoOff s: it fades away, Phase Resolved.
--   Seen    1 s in the gaze cone (ctx.SeenTick), like any Cone anomaly.
-- Not -RuleBroken and not a lost night by itself (DEC-255).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local TrailerFront = require(ReplicatedStorage.shared.Anomaly.TrailerFront)
local StalkerPath = require(ReplicatedStorage.shared.Anomaly.StalkerPath)
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Kit.CustomerActor)

const REF = "ANM-006"
const TRAILER_POINT = "TRL"
const ACROSS_POINT = "WALKER-10"
const LANE_POINT = "E-IN" -- street height (TASK-348; the client does the same)
const SCARE_CUE = "jumpscare"
const STEP_CUE = "stalker_step"
const LEAP_CUE = "stalker_leap"
const BANG_CUE = "stalker_bang"
const ENTITY_MOD = 65536 -- AnomalyCue.Entity is 0..65535
const MAX_DT = 0.5 -- s; a late tick never counts more than this
-- Defaults when Rules/ANM-006 is missing (same numbers as the rule file)
const DEFAULT_STEPS = 6
const DEFAULT_STEP_EVERY = 1.2
const DEFAULT_AUTO_OFF = 28
const DEFAULT_LEAP_DELAY = 1
const DEFAULT_SCARE_FAINT = 0.7
const DEFAULT_LINGER = 2.5
const MAX_STEPS = 20 -- record Step is 0..20

type Stage = "Stalking" | "AtWindow" | "Done"

type State = {
	Stage: Stage,
	Front: TrailerFront.Front,
	Base: Vector3,
	Ground: number,
	Steps: number,
	Step: number,
	StepEvery: number,
	Stare: number, -- s of stare toward the next step
	Range: number,
	EndsAt: number,
	LeapAt: number,
	FinishAt: number,
	LeapDelay: number,
	ScareFaint: number,
	Linger: number,
	LastTick: number,
}

local warnedMissing = false

local function param(rule: Api.Rule?, name: string, default: number): number
	if rule == nil then
		return default
	end
	const value = rule.Params[name]
	return if type(value) == "number" and value == value and value >= 0 and value ~= math.huge then value else default
end

local function target(state: State): Vector3
	return StalkerPath.At(state.Front, state.Base, state.Ground, state.Step, state.Steps)
		+ Vector3.new(0, StalkerPath.Height, 0)
end

local function rootOf(player: Player): BasePart?
	const character = player.Character
	const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

-- The nearest Active player to the service window, wherever he is
local function nearest(ctx: Api.Context, state: State): Player?
	local best: Player? = nil
	local bestDistance = math.huge
	for _, player in ctx.Active() do
		const root = rootOf(player)
		if root ~= nil then
			const distance = (root.Position - state.Front.Window).Magnitude
			if distance < bestDistance then
				best = player
				bestDistance = distance
			end
		end
	end
	return best
end

local function finishSoon(state: State, now: number)
	state.Stage = "Done"
	state.FinishAt = now + state.Linger
end

-- At the window: leap in on the nearest player, or bang on the closed window and leave
local function leap(ctx: Api.Context, occ: Api.Occurrence, state: State, now: number)
	if ctx.Vehicle.IsShutterClosed() then
		ctx.Cue(occ, BANG_CUE, 0)
		ctx.Succeed(occ)
		finishSoon(state, now)
		return
	end
	ctx.Cue(occ, LEAP_CUE, 0)
	const victim = nearest(ctx, state)
	if victim ~= nil then
		ctx.Cue(occ, SCARE_CUE, victim.UserId % ENTITY_MOD)
		const player = victim
		task.delay(state.ScareFaint, function()
			if player.Parent ~= nil then
				Kit.Vital():Fall(player)
			end
		end)
	end
	ctx.Publish(occ, { Phase = "Failed" })
	finishSoon(state, now)
end

const Stalker: Api.Module = {
	Ref = REF,

	Start = function(ctx: Api.Context, occ: Api.Occurrence): boolean
		const trailer = MapIndex.FindPoint(TRAILER_POINT)
		if trailer == nil then
			if not warnedMissing then
				warnedMissing = true
				ctx.Log(occ, `MapPoint {TRAILER_POINT} not bound; not started (MAP-01 §16.3)`)
			end
			return false
		end
		const lane = MapIndex.FindPoint(LANE_POINT)
		const ground = if lane ~= nil then lane.Position.Y else trailer.Position.Y
		const front = TrailerFront.Of(trailer, MapIndex.FindPoint(ACROSS_POINT), ground)
		const rule = ctx.Rule(REF)
		const row = Content.Anomalies.ByKey[occ.Key]
		const state: State = {
			Stage = "Stalking",
			Front = front,
			Base = trailer.Position,
			Ground = ground,
			Steps = math.clamp(math.floor(param(rule, "Steps", DEFAULT_STEPS)), 1, MAX_STEPS),
			Step = 0,
			StepEvery = math.max(param(rule, "StepEvery", DEFAULT_STEP_EVERY), 0.2),
			Stare = 0,
			Range = if row ~= nil then row.ViewRange else 80,
			EndsAt = occ.StartedAt + param(rule, "AutoOff", DEFAULT_AUTO_OFF),
			LeapAt = math.huge,
			FinishAt = math.huge,
			LeapDelay = param(rule, "LeapDelay", DEFAULT_LEAP_DELAY),
			ScareFaint = param(rule, "ScareFaint", DEFAULT_SCARE_FAINT),
			Linger = param(rule, "Linger", DEFAULT_LINGER),
			LastTick = occ.StartedAt,
		}
		occ.State = state
		ctx.Publish(occ, { Phase = "Signal", Step = 0, Anchor = 0 })
		return true
	end,

	Tick = function(ctx: Api.Context, occ: Api.Occurrence, now: number)
		const state = occ.State :: State
		const dt = math.clamp(now - state.LastTick, 0, MAX_DT)
		state.LastTick = now

		if state.Stage == "Done" then
			if now >= state.FinishAt then
				ctx.Finish(occ)
			end
			return
		end
		if state.Stage == "AtWindow" then
			if now >= state.LeapAt then
				leap(ctx, occ, state, now)
			end
			return
		end

		-- Stalking
		if now >= state.EndsAt then
			ctx.Succeed(occ)
			finishSoon(state, now)
			return
		end
		const at = target(state)
		ctx.SeenTick(occ, at, state.Range, dt)
		local stared = false
		for _, player in ctx.Active() do
			if ctx.Looking(player, at, state.Range) then
				stared = true
				break
			end
		end
		if not stared then
			return
		end
		state.Stare += dt
		if state.Stare < state.StepEvery then
			return
		end
		state.Stare -= state.StepEvery
		state.Step += 1
		ctx.Cue(occ, STEP_CUE, state.Step)
		if state.Step >= state.Steps then
			state.Stage = "AtWindow"
			state.LeapAt = now + state.LeapDelay
			ctx.Publish(occ, { Phase = "Active", Step = state.Step })
		else
			ctx.Publish(occ, { Step = state.Step })
		end
	end,

	Stop = function(_ctx: Api.Context, occ: Api.Occurrence, _reason: Api.StopReason)
		-- nothing outside the record: the figure is client-only
		occ.State = nil
	end,
}

return Stalker
