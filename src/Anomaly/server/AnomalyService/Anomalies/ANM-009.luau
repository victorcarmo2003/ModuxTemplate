--!strict
-- ANM-009 The knock (anomalies.md N9; npcs.md NPC-017; architecture.md §19.13; FEAT-019, FEAT-023; DEC-054, DEC-195,
-- DEC-204, DEC-221; TASK-117, TASK-130). Rule in Rules/ANM-009.luau. Verb: close the trailer service window
-- (architecture.md §19.14: protected = window closed and inside the trailer). Sound only (Actor Audio, NpcCost 0): nothing in the world moves on
-- the server; the back door never opens for real and has no prompt (DEC-054).
--
--   Start    Phase Active + cue knock (Entity 1: "Rookie? It's me. It's Walt. Open up."). "Seen" (AudioZone,
--            FEAT-019): every active player in the trailer zone when the first knock sounds gets ctx.See.
--   Second   SecondAt s: cue knock (Entity 2: "It's cold out here, Rookie.").
--   End      Window s (the last knock ends): every active player in the trailer zone who is not protected fails
--            (personal target, DEC-204); nothing is measured before. Outside the zone (Mart) = not tested. Any
--            failure -> cue door_crack (DEC-195 flavour: the door opens a finger, napkins fly). Phase Failed when
--            anyone failed, else Resolved; Finish.
--   Stop     nothing to undo.
--
-- PROVISIONAL (backend-coder, TASK-117; tests/wave-3.md L3-15): trailer zone = flat radius around MapPoint TRL (Rules
-- Params), a player inside the trailer always counts as in the zone.
local Api = require(script.Parent.Parent.Api)

const REF = "ANM-009"
-- Defaults when Rules/ANM-009 is missing (same numbers as the rule file)
const DEFAULT_WINDOW = 12
const DEFAULT_SECOND_AT = 10.8
const DEFAULT_ZONE_POINT = "TRL"
const DEFAULT_ZONE_RADIUS = 24

type State = {
	SecondAt: number,
	EndsAt: number,
	ZonePoint: string,
	ZoneRadius: number,
	Second: boolean,
}

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

local function inZone(ctx: Api.Context, state: State, player: Player): boolean
	return ctx.Vehicle.IsInside(player) or ctx.InZone(player, state.ZonePoint, state.ZoneRadius)
end

const Knock: Api.Module = {
	Ref = REF,

	Start = function(ctx: Api.Context, occ: Api.Occurrence): boolean
		const rule = ctx.Rule(REF)
		const window = if rule ~= nil and rule.Window > 0 then rule.Window else DEFAULT_WINDOW
		const state: State = {
			SecondAt = occ.StartedAt + math.min(param(rule, "SecondAt", DEFAULT_SECOND_AT), window),
			EndsAt = occ.StartedAt + window,
			ZonePoint = text(rule, "ZonePoint", DEFAULT_ZONE_POINT),
			ZoneRadius = param(rule, "ZoneRadius", DEFAULT_ZONE_RADIUS),
			Second = false,
		}
		occ.State = state
		ctx.Publish(occ, { Phase = "Active", Step = 1, Anchor = 0 })
		ctx.Cue(occ, "knock", 1)
		-- AudioZone "seen": in the zone of the sound when it starts (the first knock)
		for _, player in ctx.Active() do
			if inZone(ctx, state, player) then
				ctx.See(occ, player)
			end
		end
		return true
	end,

	Tick = function(ctx: Api.Context, occ: Api.Occurrence, now: number)
		const state = occ.State :: State
		if not state.Second and now >= state.SecondAt then
			state.Second = true
			ctx.Publish(occ, { Step = 2 })
			ctx.Cue(occ, "knock", 2)
		end
		if now < state.EndsAt then
			return
		end
		const failing: { Player } = {}
		for _, player in ctx.Active() do
			if not ctx.Vehicle.IsProtected(player) and inZone(ctx, state, player) then
				table.insert(failing, player)
			end
		end
		if #failing > 0 then
			ctx.Fail(occ, failing)
			ctx.Cue(occ, "door_crack", 0)
		end
		ctx.Publish(occ, { Phase = if #failing > 0 then "Failed" else "Resolved" })
		ctx.Finish(occ)
	end,

	Stop = function(_ctx: Api.Context, occ: Api.Occurrence, _reason: Api.StopReason)
		occ.State = nil
	end,
}

return Knock
