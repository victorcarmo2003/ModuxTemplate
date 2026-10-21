--!strict
-- ANM-006 The stalker (DEC-260, replaces The wavers; TASK-351; owner request 2026-10-16). Rule in Rules/ANM-006.luau.
-- Verb dont_look. A tall figure stands on the far sidewalk in full view of the service window (shared/Anomaly/
-- StalkerPath on the TrailerFront frame, the same line on both sides). It only moves while somebody stares at it:
--   Start   MapPoint TRL bound (else Start false, retried, one warning) -> Phase Signal, Step 0.
--   Stare   every tick, if ANY Active player has it on screen (Looking with ViewAngle, ViewRange, line of sight to
--           its body (AimLow) OR its head (AimHigh): the counter wall hides the legs; a player inside the trailer
--           with the window closed cannot see out), the stare clock runs; each StepEvery s
--           of stare = one small step closer (record Step; the client walks it continuously). Nobody looking = still.
--   Window  Step = Steps: Phase Active, LeapDelay s later it leaps in through the service window and attacks the
--           Active player who STARED AT IT THE LONGEST (DEC-320; tie or none = the nearest to the window) (cue jumpscare Entity = UserId % 65536, ScareFaint s
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
const LEAP_CUE = "stalker_leap"
const BANG_CUE = "stalker_bang"
const ENTITY_MOD = 65536 -- AnomalyCue.Entity is 0..65535
const MAX_DT = 0.5 -- s; a late tick never counts more than this
-- Defaults when Rules/ANM-006 is missing (same numbers as the rule file)
const DEFAULT_STEPS = 20
const DEFAULT_STEP_EVERY = 0.6
const DEFAULT_VIEW_ANGLE = 110
const DEFAULT_AIM_LOW = 5
const DEFAULT_AIM_HIGH = 8.4
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
	ViewAngle: number,
	AimLow: number,
	AimHigh: number,
	EndsAt: number,
	LeapAt: number,
	FinishAt: number,
	LeapDelay: number,
	ScareFaint: number,
	Linger: number,
	LastTick: number,
	-- DEC-320 (Q-410): seconds each player stared at it this occurrence (UserId -> s); the leap goes for the top one
	StaredBy: { [number]: number },
}

local warnedMissing = false

local function param(rule: Api.Rule?, name: string, default: number): number
	if rule == nil then
		return default
	end
	const value = rule.Params[name]
	return if type(value) == "number" and value == value and value >= 0 and value ~= math.huge then value else default
end

-- Feet of the figure where it stands now (the client walks to the same record Step)
local function feet(state: State): Vector3
	return StalkerPath.At(state.Front, state.Base, state.Ground, state.Step, state.Steps)
end

-- On screen: the body or the head inside the cone with a clear line of sight
local function staring(ctx: Api.Context, player: Player, state: State, at: Vector3): boolean
	return ctx.Looking(player, at + Vector3.new(0, state.AimHigh, 0), state.Range, state.ViewAngle)
		or ctx.Looking(player, at + Vector3.new(0, state.AimLow, 0), state.Range, state.ViewAngle)
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

-- DEC-320 (Q-410, owner 2026-10-20: "quem mais olhou mesmo"): the Active player who stared at it the longest; a tie
-- (or nobody stared, e.g. dev start) goes to the nearest to the window
local function victimOf(ctx: Api.Context, state: State): Player?
	local best: Player? = nil
	local bestStare = 0
	for _, player in ctx.Active() do
		const stare = state.StaredBy[player.UserId] or 0
		if stare > bestStare then
			best = player
			bestStare = stare
		end
	end
	if best == nil then
		return nearest(ctx, state)
	end
	-- tie on the top stare: the nearest of the tied players
	const tied: { Player } = {}
	for _, player in ctx.Active() do
		if (state.StaredBy[player.UserId] or 0) >= bestStare - 1e-3 then
			table.insert(tied, player)
		end
	end
	if #tied <= 1 then
		return best
	end
	local bestDistance = math.huge
	for _, player in tied do
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

-- At the window: leap in on the player who stared the most (DEC-320), or bang on the closed window and leave
local function leap(ctx: Api.Context, occ: Api.Occurrence, state: State, now: number)
	if ctx.Vehicle.IsShutterClosed() then
		ctx.Cue(occ, BANG_CUE, 0)
		ctx.Succeed(occ)
		finishSoon(state, now)
		return
	end
	ctx.Cue(occ, LEAP_CUE, 0)
	const victim = victimOf(ctx, state)
	if victim ~= nil then
		ctx.Cue(occ, SCARE_CUE, victim.UserId % ENTITY_MOD, victim.UserId)
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
			ViewAngle = math.clamp(param(rule, "ViewAngle", DEFAULT_VIEW_ANGLE), 10, 170),
			AimLow = param(rule, "AimLow", DEFAULT_AIM_LOW),
			AimHigh = param(rule, "AimHigh", DEFAULT_AIM_HIGH),
			EndsAt = occ.StartedAt + param(rule, "AutoOff", DEFAULT_AUTO_OFF),
			LeapAt = math.huge,
			FinishAt = math.huge,
			LeapDelay = param(rule, "LeapDelay", DEFAULT_LEAP_DELAY),
			ScareFaint = param(rule, "ScareFaint", DEFAULT_SCARE_FAINT),
			Linger = param(rule, "Linger", DEFAULT_LINGER),
			LastTick = occ.StartedAt,
			StaredBy = {},
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
		const at = feet(state)
		ctx.SeenTick(occ, at + Vector3.new(0, state.AimHigh, 0), state.Range, dt)
		local stared = false
		for _, player in ctx.Active() do
			if staring(ctx, player, state, at) then
				stared = true
				state.StaredBy[player.UserId] = (state.StaredBy[player.UserId] or 0) + dt
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
		state.Step += 1 -- the client walks there smoothly with its own footsteps (no cue per step)
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
