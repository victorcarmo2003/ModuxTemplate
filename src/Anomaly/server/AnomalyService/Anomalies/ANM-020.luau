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
-- The Context has no blackout call yet, so LightService is resolved from its module (same lookup as Kit/CustomerActor;
-- proposed for the next TASK-106 pass: Context.Light.BeginBlackout / EndBlackout / IsBlackout).
local ServerScriptService = game:GetService("ServerScriptService")
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Kit.CustomerActor)

const REF = "ANM-020"
const BREAKER_ACTION = "breaker_reset"
const SCARE_CUE = "jumpscare"
const START_CUE = "blackout_start"
const RESTORE_CUE = "blackout_restore"
-- Defaults when Rules/ANM-020 is missing (same numbers as the rule file)
const DEFAULT_WINDOW = 30
const DEFAULT_POINT = "TRL"
const DEFAULT_RADIUS = 24
const DEFAULT_FAINT = 0.7
const DEFAULT_RESTORE = 3

type Stage = "Dark" | "Attacked"

type State = {
	Stage: Stage,
	AttackAt: number,
	RestoreAt: number, -- set at the attack
	Point: string,
	Radius: number,
	FaintDelay: number,
	RestoreAfter: number,
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

-- 30 s in the dark: the shape attacks whoever is in the trailer zone.
local function attack(ctx: Api.Context, occ: Api.Occurrence, state: State, now: number)
	state.Stage = "Attacked"
	state.RestoreAt = now + state.RestoreAfter
	const victims: { Player } = {}
	for _, player in ctx.Active() do
		if ctx.Vehicle.IsInside(player) or ctx.InZone(player, state.Point, state.Radius) then
			table.insert(victims, player)
		end
	end
	ctx.Publish(occ, { Phase = "Failed" })
	ctx.Cue(occ, SCARE_CUE, 0)
	if #victims == 0 then
		ctx.Log(occ, "the shape attacked an empty trailer: nobody fainted")
		return
	end
	task.delay(state.FaintDelay, function()
		for _, player in victims do
			if player.Parent ~= nil then
				Kit.Vital():Fall(player)
			end
		end
	end)
end

const Blackout: Api.Module = {
	Ref = REF,

	Start = function(ctx: Api.Context, occ: Api.Occurrence): boolean
		const service = light()
		if service:IsBlackout() then
			return false -- another blackout is on: the agenda tries again later
		end
		const rule = ctx.Rule(REF)
		const window = if rule ~= nil and rule.Window > 0 then rule.Window else DEFAULT_WINDOW
		const state: State = {
			Stage = "Dark",
			AttackAt = occ.StartedAt + window,
			RestoreAt = 0,
			Point = text(rule, "Point", DEFAULT_POINT),
			Radius = param(rule, "Radius", DEFAULT_RADIUS),
			FaintDelay = param(rule, "FaintDelay", DEFAULT_FAINT),
			RestoreAfter = param(rule, "RestoreAfter", DEFAULT_RESTORE),
		}
		occ.State = state
		service:BeginBlackout()
		owner = occ
		ctx.Publish(occ, { Phase = "Active", Step = 0, Anchor = 0 })
		ctx.Cue(occ, START_CUE, 0)
		return true
	end,

	Tick = function(ctx: Api.Context, occ: Api.Occurrence, now: number)
		const state = occ.State :: State
		if state.Stage == "Dark" then
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
