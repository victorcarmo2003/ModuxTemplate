--!strict
-- ANM-008 The long car (anomalies.md N8; npcs.md NPC-016; architecture.md §19.13 "Long car", §19.14; FEAT-019,
-- FEAT-023; DEC-204, DEC-221, DEC-255; TASK-117, TASK-130; back in the agenda by TASK-331, owner 2026-10-15). Rule in
-- Rules/ANM-008.luau. Verb: close the trailer service window before the high beam (protected = window closed and inside
-- the trailer).
--
-- The car is a client-only actor (Effects/ANM-008) driven by the record's StartedAt: it rolls slowly down the Ninth WB
-- lane, suddenly speeds up to the FRONT OF THE TRAILER (shared/Anomaly/TrailerFront: TRL + WALKER-10, the same pose on
-- both sides), brakes with its nose on the window and is parked at StartedAt + ArriveAt. The server keeps the timeline:
--   Start    MapPoint TRL bound (else Start false, retried, one warning) -> TrafficService:Hold("anm_008", true),
--            Phase Signal.
--   Beam     ArriveAt + BeamDelay: Phase Active, cues car_highbeam + car_honk. Every active player in the trailer zone
--            (inside the trailer, or within ZoneRadius of ZonePoint) is tested: not protected -> scared (V2 error,
--            DEC-255: cue jumpscare with Entity = UserId % 65536, ScareFaint s later VitalService:Fall); protected ->
--            watched until the car leaves. Outside the zone = not tested (Mart).
--   Stay     beam .. beam + StayFor: whoever opens the window is scared (Shutter event, who acted, DEC-204); a watched
--            player who leaves the trailer (5 Hz check) is scared.
--   Leave    beam + StayFor: Phase Failed when anyone was scared, else Resolved (the client backs the car out and drives
--            it away), then the record stays LeaveLinger s and Finish. The Hold is released by Stop.
--   Seen     1 s in the gaze cone of the braked car (ViewRange 100) between parking and leaving.
-- PROVISIONAL (TASK-331): numbers in the rule; the old -RuleBroken became the V2 jumpscare + faint.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local TrailerFront = require(ReplicatedStorage.shared.Anomaly.TrailerFront)
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Kit.CustomerActor)

const REF = "ANM-008"
const TRAILER_POINT = "TRL"
const ACROSS_POINT = "WALKER-10"
const LANE_POINT = "E-IN" -- on the road: the car's height (TASK-348; the client effect does the same)
const HOLD_REASON = "anm_008"
const SCARE_CUE = "jumpscare"
const ENTITY_MOD = 65536 -- AnomalyCue.Entity is 0..65535
const CAR_HEIGHT = 2.5 -- studs above the ground: body of the car (target of the gaze cone)
const MAX_DT = 0.5 -- s; a late tick never counts more than this
-- Defaults when Rules/ANM-008 is missing (same numbers as the rule file)
const DEFAULT_ARRIVE_AT = 8.2
const DEFAULT_BEAM_DELAY = 2.5
const DEFAULT_STAY_FOR = 6
const DEFAULT_LEAVE_LINGER = 6
const DEFAULT_SCARE_FAINT = 0.7
const DEFAULT_ZONE_POINT = "TRL"
const DEFAULT_ZONE_RADIUS = 24

type Stage = "Arriving" | "Watching" | "Leaving"

type State = {
	Stage: Stage,
	Car: Vector3,
	Range: number,
	ParkedAt: number,
	BeamAt: number,
	LeaveAt: number,
	FinishAt: number,
	ScareFaint: number,
	ZonePoint: string,
	ZoneRadius: number,
	-- userId -> player protected at the beam, still watched until the car leaves
	Watched: { [number]: Player },
	Scared: { [number]: boolean },
	AnyFailed: boolean,
	Held: boolean,
	LastTick: number,
}

-- Live Holds of this module (two occurrences never release each other's Hold)
local holds = 0
local warnedMissing = false

local function param(rule: Api.Rule?, name: string, default: number): number
	if rule == nil then
		return default
	end
	const value = rule.Params[name]
	return if type(value) == "number" and value == value and value >= 0 and value ~= math.huge then value else default
end

local function text(rule: Api.Rule?, name: string, default: string): string
	if rule == nil then
		return default
	end
	const value = rule.Params[name]
	return if type(value) == "string" and value ~= "" then value else default
end

local function setHold(ctx: Api.Context, state: State, on: boolean)
	if state.Held == on then
		return
	end
	state.Held = on
	holds = math.max(0, holds + (if on then 1 else -1))
	if on and holds == 1 then
		ctx.Traffic.Hold(HOLD_REASON, true)
	elseif not on and holds == 0 then
		ctx.Traffic.Hold(HOLD_REASON, false)
	end
end

local function inZone(ctx: Api.Context, state: State, player: Player): boolean
	return ctx.Vehicle.IsInside(player) or ctx.InZone(player, state.ZonePoint, state.ZoneRadius)
end

-- V2 error (DEC-255): only this player's client shows the face, then the faint. Once per player per occurrence.
local function scare(ctx: Api.Context, occ: Api.Occurrence, state: State, player: Player)
	const userId = player.UserId
	state.Watched[userId] = nil
	if state.Scared[userId] then
		return
	end
	state.Scared[userId] = true
	state.AnyFailed = true
	ctx.Cue(occ, SCARE_CUE, userId % ENTITY_MOD)
	task.delay(state.ScareFaint, function()
		if player.Parent ~= nil then
			Kit.Vital():Fall(player)
		end
	end)
end

-- The high beam: test every active player in the trailer zone.
local function beam(ctx: Api.Context, occ: Api.Occurrence, state: State)
	state.Stage = "Watching"
	ctx.Publish(occ, { Phase = "Active" })
	ctx.Cue(occ, "car_highbeam", 0)
	ctx.Cue(occ, "car_honk", 0)
	const failing: { Player } = {}
	for _, player in ctx.Active() do
		if not inZone(ctx, state, player) then
			continue -- outside the trailer zone: not tested (npcs.md N8)
		end
		if ctx.Vehicle.IsProtected(player) then
			state.Watched[player.UserId] = player
		else
			table.insert(failing, player)
		end
	end
	for _, player in failing do
		scare(ctx, occ, state, player)
	end
end

local function leave(ctx: Api.Context, occ: Api.Occurrence, state: State)
	state.Stage = "Leaving"
	state.Watched = {}
	ctx.Publish(occ, { Phase = if state.AnyFailed then "Failed" else "Resolved" })
end

const LongCar: Api.Module = {
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
		const front =
			TrailerFront.Of(trailer, MapIndex.FindPoint(ACROSS_POINT), if lane ~= nil then lane.Position.Y else nil)
		const rule = ctx.Rule(REF)
		const row = Content.Anomalies.ByKey[occ.Key]
		const parkedAt = occ.StartedAt + param(rule, "ArriveAt", DEFAULT_ARRIVE_AT)
		const beamAt = parkedAt + param(rule, "BeamDelay", DEFAULT_BEAM_DELAY)
		const leaveAt = beamAt + param(rule, "StayFor", DEFAULT_STAY_FOR)
		const state: State = {
			Stage = "Arriving",
			Car = front.Stop.Position + Vector3.new(0, CAR_HEIGHT, 0),
			Range = if row ~= nil then row.ViewRange else 0,
			ParkedAt = parkedAt,
			BeamAt = beamAt,
			LeaveAt = leaveAt,
			FinishAt = leaveAt + param(rule, "LeaveLinger", DEFAULT_LEAVE_LINGER),
			ScareFaint = param(rule, "ScareFaint", DEFAULT_SCARE_FAINT),
			ZonePoint = text(rule, "ZonePoint", DEFAULT_ZONE_POINT),
			ZoneRadius = param(rule, "ZoneRadius", DEFAULT_ZONE_RADIUS),
			Watched = {},
			Scared = {},
			AnyFailed = false,
			Held = false,
			LastTick = occ.StartedAt,
		}
		occ.State = state
		setHold(ctx, state, true)
		ctx.Publish(occ, { Phase = "Signal", Step = 0, Anchor = 0 })
		return true
	end,

	Tick = function(ctx: Api.Context, occ: Api.Occurrence, now: number)
		const state = occ.State :: State
		const dt = math.clamp(now - state.LastTick, 0, MAX_DT)
		state.LastTick = now

		if state.Stage == "Leaving" then
			if now >= state.FinishAt then
				ctx.Finish(occ)
			end
			return
		end
		if now >= state.ParkedAt and state.Range > 0 then
			ctx.SeenTick(occ, state.Car, state.Range, dt)
		end
		if state.Stage == "Arriving" and now >= state.BeamAt then
			beam(ctx, occ, state)
		end
		if state.Stage == "Watching" then
			-- a watched player left the trailer before the car left (5 Hz; Tick only runs in the Night phase)
			const out: { Player } = {}
			for _, player in state.Watched do
				if player.Parent ~= nil and not ctx.Vehicle.IsInside(player) then
					table.insert(out, player)
				end
			end
			for _, player in out do
				scare(ctx, occ, state, player)
			end
			if now >= state.LeaveAt then
				leave(ctx, occ, state)
			end
		end
	end,

	-- Action (DEC-204): opening the window while the beam is on scares who opened, wherever they are
	OnEvent = function(ctx: Api.Context, occ: Api.Occurrence, event: Api.Event)
		const state = occ.State :: State?
		if state == nil or state.Stage ~= "Watching" then
			return
		end
		if event.Kind == "Shutter" then
			const opener = event.Player
			if not event.Closed and opener ~= nil then
				scare(ctx, occ, state, opener)
			end
		end
	end,

	Stop = function(ctx: Api.Context, occ: Api.Occurrence, _reason: Api.StopReason)
		const state = occ.State :: State?
		if state ~= nil then
			setHold(ctx, state, false)
		end
		occ.State = nil
	end,
}

return LongCar
