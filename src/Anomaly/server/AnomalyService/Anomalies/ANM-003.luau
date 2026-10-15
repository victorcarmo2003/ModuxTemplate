--!strict
-- ANM-003 "The stopped clock" (docs/story/anomalies.md N3; design/npcs.md NPC-011; architecture.md §19.13; FEAT-020,
-- FEAT-023; DEC-054, DEC-204, DEC-254, DEC-255; TASK-113; remade by TASK-340, owner 2026-10-15). Contract: ../Api.luau.
-- Rule: Rules/ANM-003.luau. V2 family C.
--
-- The bank clock stops and a church bell tolls three times (`church_bell`, ReplicatedStorage.Assets.SFX
-- "Very scary bell sound/church bell"):
--   Bell 1  Start: Phase Active, cue clock_stop (hands stop), cue bell (Entity 1) and every street post goes out at
--           once (LightService:BeginPostsOut; the trailer and its switch are untouched).
--   Bell 2  SecondAt s later (1 s): cue bell (Entity 2).
--   Bell 3  ThirdAt s after the start: cue bell (Entity 3). The trailer light must be OFF by then (the switch):
--             off -> Resolved; the posts come back RestoreAfter s later, cue clock_resume, Finish.
--             on  -> Failed: cue swarm (cartoon moths and bats pour out of the dark towards the light and the players),
--                    SwarmFor s later EVERY active player faints (VitalService:Fall; V2, DEC-255: no -RuleBroken);
--                    then the posts come back, cue clock_resume, Finish.
--   Seen    1 s in the gaze cone of the bank clock (MapPoint AN-11, ViewRange of the row).
--   Stop    the posts this occurrence put out come back.
-- PROVISIONAL (TASK-340): ThirdAt / SwarmFor / RestoreAfter in the rule. The owner accepted tying it to the game's
-- midnight; it stays on the agenda (any slot) for now: simpler, and the bell is the clock either way.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Kit.CustomerActor)

const REF = "ANM-003"
const CLOCK_POINT = "AN-11" -- MapPoint of the Bellmoor Savings clock C-01 (MAP-01 §10.3)
const TICK_DT = 0.2 -- s between two Ticks (AnomalyService runs Tick at 5 Hz)
-- Defaults when Rules/ANM-003 lacks a number (same as the rule file)
const DEFAULT_SECOND_AT = 1
const DEFAULT_THIRD_AT = 8
const DEFAULT_SWARM_FOR = 1.8
const DEFAULT_RESTORE_AFTER = 2.5

type Stage = "Tolling" | "Swarm" | "Ending"

type State = {
	Stage: Stage,
	Bells: number, -- strokes already sent
	SecondAt: number,
	ThirdAt: number,
	SwarmFor: number,
	RestoreAfter: number,
	FaintAt: number,
	EndAt: number,
	Clock: Vector3?,
	ViewRange: number,
	LastTick: number,
}

type Light = { BeginPostsOut: (self: any) -> (), EndPostsOut: (self: any) -> () }

local lightCache: Light? = nil
local function light(): Light
	if lightCache == nil then
		lightCache = (require :: any)(ServerScriptService.server.Light.LightService) :: Light
	end
	return lightCache :: Light
end

-- The occurrence that put the posts out (only it brings them back)
local owner: Api.Occurrence? = nil

local function release(occ: Api.Occurrence)
	if owner == occ then
		owner = nil
		light():EndPostsOut()
	end
end

local function param(rule: Api.Rule?, name: string, default: number): number
	if rule == nil then
		return default
	end
	const value = rule.Params[name]
	return if type(value) == "number" and value == value and value >= 0 and value ~= math.huge then value else default
end

local function clockPosition(): Vector3?
	const point = MapIndex.FindPoint(CLOCK_POINT)
	return if point ~= nil then point.Position else nil
end

local function bell(ctx: Api.Context, occ: Api.Occurrence, state: State)
	state.Bells += 1
	ctx.Publish(occ, { Step = state.Bells })
	ctx.Cue(occ, "bell", state.Bells)
end

-- Third stroke: the trailer light decides
local function third(ctx: Api.Context, occ: Api.Occurrence, state: State, now: number)
	bell(ctx, occ, state)
	if not ctx.Light.IsSwitchOn() then
		state.Stage = "Ending"
		state.EndAt = now + state.RestoreAfter
		ctx.Succeed(occ)
		return
	end
	state.Stage = "Swarm"
	state.FaintAt = now + state.SwarmFor
	ctx.Publish(occ, { Phase = "Failed" })
	ctx.Cue(occ, "swarm", 0)
end

const StoppedClock: Api.Module = {
	Ref = REF,

	Start = function(ctx: Api.Context, occ: Api.Occurrence): boolean
		const rule = ctx.Rule(occ.Key)
		const row = Content.Anomalies.ByKey[occ.Key]
		const thirdAt = param(rule, "ThirdAt", DEFAULT_THIRD_AT)
		const state: State = {
			Stage = "Tolling",
			Bells = 0,
			SecondAt = occ.StartedAt + math.min(param(rule, "SecondAt", DEFAULT_SECOND_AT), thirdAt),
			ThirdAt = occ.StartedAt + thirdAt,
			SwarmFor = param(rule, "SwarmFor", DEFAULT_SWARM_FOR),
			RestoreAfter = param(rule, "RestoreAfter", DEFAULT_RESTORE_AFTER),
			FaintAt = 0,
			EndAt = 0,
			Clock = clockPosition(),
			ViewRange = if row ~= nil then row.ViewRange else 0,
			LastTick = occ.StartedAt,
		}
		occ.State = state
		light():BeginPostsOut()
		owner = occ
		ctx.Publish(occ, { Phase = "Active", Step = 0, Anchor = 0 })
		ctx.Cue(occ, "clock_stop", 0)
		bell(ctx, occ, state)
		return true
	end,

	Tick = function(ctx: Api.Context, occ: Api.Occurrence, now: number)
		const state = occ.State :: State
		const dt = math.clamp(now - state.LastTick, 0, TICK_DT * 2)
		state.LastTick = now
		const clock = state.Clock
		if clock ~= nil and state.ViewRange > 0 then
			ctx.SeenTick(occ, clock, state.ViewRange, dt)
		end
		if state.Stage == "Tolling" then
			if state.Bells < 2 and now >= state.SecondAt then
				bell(ctx, occ, state)
			end
			if now >= state.ThirdAt then
				third(ctx, occ, state, now)
			end
		elseif state.Stage == "Swarm" then
			if now >= state.FaintAt then
				for _, player in ctx.Active() do
					Kit.Vital():Fall(player)
				end
				state.Stage = "Ending"
				state.EndAt = now + state.RestoreAfter
			end
		elseif now >= state.EndAt then
			release(occ)
			ctx.Cue(occ, "clock_resume", 0)
			ctx.Finish(occ)
		end
	end,

	Stop = function(_ctx: Api.Context, occ: Api.Occurrence, _reason: Api.StopReason)
		release(occ)
		occ.State = nil
	end,
}

return StoppedClock
