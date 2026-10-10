--!strict
-- ANM-003 "The stopped clock" (docs/story/anomalies.md N3; design/npcs.md NPC-011; architecture.md §19.13; FEAT-020,
-- FEAT-023, FEAT-024; DEC-054, DEC-195, DEC-204; TASK-113). Contract: ../Api.luau. Rule: Rules/ANM-003.luau.
--
--   Start   Phase Active + cue clock_stop (bank clock hands stop, ticking stops; the HUD clock keeps going, DEC-195).
--   Verb    LightService.SwitchChanged: off -> on with the switch off for >= Params.DarkHold s in a row = Resolved,
--           cue clock_resume. Back on earlier: the count resets, no failure (npcs.md N3). Works with or without the
--           Trailer Lights upgrade (the switch always drives the interior lamp).
--   Error   Window s pass without it: Fail("active") (omission on a party target, DEC-204), cue clock_resume.
--   Seen    1 s in the gaze cone of the bank clock (MapPoint AN-11, ViewRange of the row).
--   Stop    nothing to undo (the module changes no world state).
--
-- PROVISIONAL (backend-coder, TASK-113; tests/wave-3.md L3-11): with the switch already off when the clock stops, the
-- dark count starts at the stop (time in the dark before the sign does not count).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Api = require(script.Parent.Parent.Api)

const REF = "ANM-003"
const CLOCK_POINT = "AN-11" -- MapPoint of the Bellmoor Savings clock C-01 (MAP-01 §10.3)
const TICK_DT = 0.2 -- s between two Ticks (AnomalyService runs Tick at 5 Hz)

type State = {
	DeadlineAt: number,
	DarkHold: number,
	-- server time the switch went off (nil = on)
	OffSince: number?,
	Clock: Vector3?,
	ViewRange: number,
	LastTick: number,
}

local function clockPosition(): Vector3?
	const point = MapIndex.FindPoint(CLOCK_POINT)
	return if point ~= nil then point.Position else nil
end

local function finish(ctx: Api.Context, occ: Api.Occurrence, solved: boolean)
	ctx.Cue(occ, "clock_resume", 0)
	if solved then
		ctx.Succeed(occ)
	else
		ctx.Fail(occ, "active")
	end
	ctx.Finish(occ)
end

const StoppedClock: Api.Module = {
	Ref = REF,

	Start = function(ctx: Api.Context, occ: Api.Occurrence): boolean
		const rule = ctx.Rule(occ.Key)
		if rule == nil then
			-- Rules/ANM-003 missing or broken (warned at boot): no deadline to enforce
			return false
		end
		const darkHold = rule.Params.DarkHold
		const row = Content.Anomalies.ByKey[occ.Key]
		const state: State = {
			DeadlineAt = occ.StartedAt + rule.Window,
			DarkHold = if type(darkHold) == "number" then darkHold else 0,
			OffSince = if ctx.Light.IsSwitchOn() then nil else occ.StartedAt,
			Clock = clockPosition(),
			ViewRange = if row ~= nil then row.ViewRange else 0,
			LastTick = occ.StartedAt,
		}
		occ.State = state
		ctx.Publish(occ, { Phase = "Active", Step = 0, Anchor = 0 })
		ctx.Cue(occ, "clock_stop", 0)
		return true
	end,

	Tick = function(ctx: Api.Context, occ: Api.Occurrence, now: number)
		const state = occ.State :: State
		const dt = math.clamp(now - state.LastTick, 0, TICK_DT * 2)
		state.LastTick = now
		if now >= state.DeadlineAt then
			finish(ctx, occ, false)
			return
		end
		const clock = state.Clock
		if clock ~= nil and state.ViewRange > 0 then
			ctx.SeenTick(occ, clock, state.ViewRange, dt)
		end
	end,

	OnEvent = function(ctx: Api.Context, occ: Api.Occurrence, event: Api.Event)
		if event.Kind ~= "Switch" then
			return
		end
		const state = occ.State :: State
		const t = ctx.Now()
		if not event.On then
			state.OffSince = t
			return
		end
		const offSince = state.OffSince
		state.OffSince = nil
		if offSince ~= nil and t - offSince >= state.DarkHold and t < state.DeadlineAt then
			finish(ctx, occ, true)
		end
	end,

	Stop = function(_ctx: Api.Context, _occ: Api.Occurrence, _reason: Api.StopReason) end,
}

return StoppedClock
