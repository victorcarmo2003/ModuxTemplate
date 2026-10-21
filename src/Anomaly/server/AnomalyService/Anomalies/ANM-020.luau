--!strict
-- ANM-020 "The blackout" (V2 family C "falha de energia": verb RELIGAR A LUZ; DEC-254, DEC-255, DEC-256;
-- design/anomalies-v2-proposal.md §3 C; TASK-273). Contract: ../Api.luau. Rule: Rules/ANM-020.luau.
-- Environment anomaly (Actor World). Reuses the light layer of ANM-003 / ANM-010: LightService owns the dark (every
-- HushOff group out at once, IsLit false in the trailer, the switch does nothing) and the breaker prompt.
--
--   Start   LightService:BeginBlackout() (refused while another blackout is on), Phase Active, cue blackout_start
--           (the crack + the dark on the client, Effects/ANM-020: noises and a shape at the corner of the eye).
--   Verb    breaker_reset (hold 3 s at the back of the trailer; LightService validates and ends the blackout) comes
--           in as the Action event: Resolved, cue blackout_restore, Finish.
--   Error   Window s with the power still out: the shape attacks. Victims = active players inside the trailer
--           (VehicleService:IsInside) or within Params.Radius of Params.Point (TRL). Phase Failed, cue jumpscare
--           (Entity 0: the client shows the face to whoever stands in that zone), FaintDelay s later
--           VitalService:Fall of each victim (Down, revivable; DEC-255: no -RuleBroken, not a lost night by
--           itself). RestoreAfter s later the power comes back (cue blackout_restore) and the occurrence ends.
--   Stop    the blackout this occurrence began is ended (NightOver, Restore, dev stop).
--
-- PROVISIONAL (TASK-273): (a) nobody in the zone at the attack = no faint, Phase Failed all the same; (b) the power
-- comes back RestoreAfter s after the attack; (c) no "seen" sanity hit (the dark already drains sanity, VitalService).
--
-- Restaurant (TASK-444, owner request 2026-10-17; only with Content.Restaurant.Rules.Enabled; off = the trailer timeline
-- above, unchanged):
--   Omen    Start publishes Phase Signal and cue blackout_warn (the lights flicker 1-2 times, the score goes Uneasy);
--           OmenFor s later the power goes out (BeginBlackout, Phase Active, cue blackout_start: "lights off" snap,
--           the "POWER OUT / HIDE IN THE BACK" caption, the violins rise). Refused while another blackout is on.
--   Verb    the breaker (TRL-BREAKER, breaker_reset) within RestaurantWindow s: Resolved, the light comes back.
--   Hide    no longer an answer (DEC-292, owner 2026-10-18): only the breaker saves the crew.
--   Error   RestaurantWindow s with the power out: EVERY active player (DEC-292; before: in the building and not in a
--           HideZone) pays -Sanity.RuleBroken (-35, DEC-277) through ctx.Fail, with the jumpscare
--           cue for that player only (Entity = UserId % 65536). Never a faint by itself: only a sanity that reaches 0
--           falls (VitalService). Phase Failed (the choir). The dark stays until the breaker is held, or MaxDark s.
-- The Context has no blackout call yet, so LightService is resolved from its module (same lookup as Kit/CustomerActor;
-- proposed for the next TASK-106 pass: Context.Light.BeginBlackout / EndBlackout / IsBlackout).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Kit.CustomerActor)
local Hide = require(script.Parent.Kit.Hide)

const REF = "ANM-020"
const BREAKER_ACTION = "breaker_reset"
const SCARE_CUE = "jumpscare"
const START_CUE = "blackout_start"
const RESTORE_CUE = "blackout_restore"
const WARN_CUE = "blackout_warn"
-- Defaults when Rules/ANM-020 is missing (same numbers as the rule file)
const DEFAULT_WINDOW = 30
const DEFAULT_POINT = "TRL"
const DEFAULT_RADIUS = 24
const DEFAULT_FAINT = 0.7
const DEFAULT_RESTORE = 3
const DEFAULT_OMEN = 2
const DEFAULT_RESTAURANT_WINDOW = 30
const DEFAULT_MAX_DARK = 20
const DEFAULT_MARGIN = 1

type Stage = "Omen" | "Dark" | "Attacked"

type State = {
	Stage: Stage,
	DarkAt: number, -- restaurant: the end of the omen
	AttackAt: number,
	RestoreAt: number, -- set at the attack
	Point: string,
	Radius: number,
	FaintDelay: number,
	RestoreAfter: number,
	Margin: number,
}

-- Narrow view of LightService (only what this module calls)
type Light = {
	BeginBlackout: (self: any) -> (),
	EndBlackout: (self: any) -> (),
	IsBlackout: (self: any) -> boolean,
}

local lightCache: Light? = nil
local function light(): Light
	if lightCache == nil then
		lightCache = (require :: any)(ServerScriptService.server.Light.LightService) :: Light
	end
	return lightCache :: Light
end

-- The occurrence that began the current blackout (only it ends it)
local owner: Api.Occurrence? = nil

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

local function release(occ: Api.Occurrence)
	if owner == occ then
		owner = nil
		light():EndBlackout()
	end
end

local function restore(ctx: Api.Context, occ: Api.Occurrence)
	release(occ)
	ctx.Cue(occ, RESTORE_CUE, 0)
	ctx.Finish(occ)
end

-- Restaurant (TASK-444; DEC-292, owner 2026-10-18): hiding no longer saves anyone. Only the breaker ends the dark in time;
-- when the window runs out EVERY active player pays -35 (DEC-277), wherever they stand, no faint by itself. (Before
-- DEC-292: whoever was in the building and not in a HideZone.)
local function attackRestaurant(ctx: Api.Context, occ: Api.Occurrence, state: State, now: number)
	state.Stage = "Attacked"
	state.RestoreAt = now + state.RestoreAfter
	const victims: { Player } = {}
	for _, player in ctx.Active() do
		table.insert(victims, player)
	end
	ctx.Publish(occ, { Phase = "Failed" })
	if #victims == 0 then
		ctx.Log(occ, "nobody active: nobody paid")
		return
	end
	for _, player in victims do
		ctx.Cue(occ, SCARE_CUE, Hide.EntityOf(player), player.UserId)
	end
	ctx.Fail(occ, victims)
end

-- 30 s in the dark: the shape attacks whoever is in the trailer zone.
local function attack(ctx: Api.Context, occ: Api.Occurrence, state: State, now: number)
	attackRestaurant(ctx, occ, state, now)
end

const Blackout: Api.Module = {
	Ref = REF,

	Start = function(ctx: Api.Context, occ: Api.Occurrence): boolean
		const service = light()
		if service:IsBlackout() then
			return false -- another blackout is on: the agenda tries again later
		end
		const rule = ctx.Rule(REF)
		const window = param(rule, "RestaurantWindow", DEFAULT_RESTAURANT_WINDOW)
		const omen = param(rule, "OmenFor", DEFAULT_OMEN)
		const state: State = {
			Stage = if omen > 0 then "Omen" else "Dark",
			DarkAt = occ.StartedAt + omen,
			AttackAt = occ.StartedAt + omen + window,
			RestoreAt = 0,
			Point = text(rule, "Point", DEFAULT_POINT),
			Radius = param(rule, "Radius", DEFAULT_RADIUS),
			FaintDelay = param(rule, "FaintDelay", DEFAULT_FAINT),
			RestoreAfter = param(rule, "MaxDark", DEFAULT_MAX_DARK),
			Margin = param(rule, "Margin", DEFAULT_MARGIN),
		}
		occ.State = state
		if state.Stage == "Omen" then
			-- TASK-444: the lights flicker first (the record goes out as Signal, the score goes Uneasy)
			ctx.Publish(occ, { Phase = "Signal", Step = 0, Anchor = 0 })
			ctx.Cue(occ, WARN_CUE, 0)
			return true
		end
		service:BeginBlackout()
		owner = occ
		ctx.Publish(occ, { Phase = "Active", Step = 0, Anchor = 0 })
		ctx.Cue(occ, START_CUE, 0)
		return true
	end,

	Tick = function(ctx: Api.Context, occ: Api.Occurrence, now: number)
		const state = occ.State :: State
		if state.Stage == "Omen" then
			if now < state.DarkAt then
				return
			end
			if light():IsBlackout() then
				-- another blackout took the power meanwhile: this one has nothing to add
				ctx.Finish(occ)
				return
			end
			state.Stage = "Dark"
			light():BeginBlackout()
			owner = occ
			ctx.Publish(occ, { Phase = "Active" })
			ctx.Cue(occ, START_CUE, 0)
		elseif state.Stage == "Dark" then
			if not light():IsBlackout() then
				-- the power came back some other way (new shift, restore): nothing left to do
				owner = nil
				ctx.Finish(occ)
			elseif now >= state.AttackAt then
				attack(ctx, occ, state, now)
			end
		elseif now >= state.RestoreAt then
			restore(ctx, occ)
		end
	end,

	OnEvent = function(ctx: Api.Context, occ: Api.Occurrence, event: Api.Event)
		if event.Kind ~= "Action" or event.Action ~= BREAKER_ACTION then
			return
		end
		const state = occ.State :: State
		if state.Stage == "Attacked" then
			-- TASK-444: after the attack the dark stays until somebody holds the breaker (the record stays Failed)
			owner = nil
			ctx.Cue(occ, RESTORE_CUE, 0)
			ctx.Finish(occ)
			return
		end
		if state.Stage ~= "Dark" then
			return
		end
		-- LightService already put the power back (its Run); this occurrence only resolves
		owner = nil
		ctx.Succeed(occ)
		ctx.Cue(occ, RESTORE_CUE, 0)
		ctx.Finish(occ)
	end,

	Stop = function(_ctx: Api.Context, occ: Api.Occurrence, _reason: Api.StopReason)
		release(occ)
		occ.State = nil
	end,
}

return Blackout
