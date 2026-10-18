--!strict
-- ANM-019 The roof walker, "don't look up" (TASK-484; DEC-294, DEC-295 / Q-367 A; design/horror-cinematic.md ANM-019).
-- Contract: ../Api.luau. Numbers: Rules/ANM-019.luau. Look: Content.HorrorScenes anm_019_roof_walker + Effects/ANM-019.
--
--   Omen    Start: Phase Signal. It lands on the roof (the scene: the thud, dust, lamps swaying). OmenFor s, no rule yet.
--   Walk    Phase Active for WalkFor s: the heavy steps cross the roof from one end to the other. From LookFrom s on,
--           every tick (5 Hz) each Active player's Gaze pitch (ctx.Pitch) is read: above LookPitch for LookGrace s in a
--           row = caught (a shorter glance resets). No fresh Gaze (third person, cameras, lag) never counts.
--   Caught  the first tick with someone caught: the walk ends there. Every player caught on that tick gets the cue
--           "jumpscare" (Entity = UserId % 65536: only that client sees it drop in front of the window and the hit) and
--           pays -Sanity.RuleBroken (ctx.Fail). Phase Failed (the others hear it leave). LeaveFor s later, Finish.
--   Safe    WalkFor s with nobody caught: Phase Resolved (the steps reach the far end and go), LeaveFor s later, Finish.
-- No actor, no HideZone, no faint by itself (only a sanity at 0 falls, VitalService). Works in the trailer and in the
-- restaurant (no map point needed: the client puts the walk over each player's own head).
local Api = require(script.Parent.Parent.Api)

const REF = "ANM-019"
const SCARE_CUE = "jumpscare"
const ENTITY_MOD = 65536 -- AnomalyCue.Entity range
-- Defaults when Rules/ANM-019 is missing (same numbers as the rule file)
const DEFAULT_OMEN = 3
const DEFAULT_WALK = 16
const DEFAULT_LOOK_FROM = 1
const DEFAULT_PITCH = 35
const DEFAULT_GRACE = 0.6
const DEFAULT_LEAVE = 5

type Stage = "Omen" | "Walk" | "Over"

type State = {
	Stage: Stage,
	WalkAt: number,
	LookAt: number,
	EndsAt: number,
	OverAt: number, -- set when the walk ends (caught or safe)
	Pitch: number,
	Grace: number,
	Leave: number,
	UpSince: { [Player]: number }, -- server time the look went above Pitch (cleared when it comes down)
}

local function param(rule: Api.Rule?, name: string, default: number): number
	if rule == nil then
		return default
	end
	const value = rule.Params[name]
	return if type(value) == "number" and value == value and value >= 0 and value ~= math.huge then value else default
end

local function over(ctx: Api.Context, occ: Api.Occurrence, state: State, now: number, caught: { Player })
	state.Stage = "Over"
	state.OverAt = now + state.Leave
	table.clear(state.UpSince)
	if #caught == 0 then
		ctx.Succeed(occ)
		return
	end
	ctx.Publish(occ, { Phase = "Failed" })
	for _, player in caught do
		ctx.Cue(occ, SCARE_CUE, player.UserId % ENTITY_MOD)
	end
	ctx.Fail(occ, caught)
end

-- Players whose look has been up for Grace s in a row at `now` (the others' timers are kept or cleared)
local function lookers(ctx: Api.Context, state: State, now: number): { Player }
	const caught: { Player } = {}
	const seen: { [Player]: boolean } = {}
	for _, player in ctx.Active() do
		seen[player] = true
		const pitch = ctx.Pitch(player)
		if pitch == nil or pitch < state.Pitch then
			state.UpSince[player] = nil
			continue
		end
		const since = state.UpSince[player]
		if since == nil then
			state.UpSince[player] = now
		elseif now - since >= state.Grace then
			table.insert(caught, player)
		end
	end
	for player in state.UpSince do
		if not seen[player] then
			state.UpSince[player] = nil
		end
	end
	return caught
end

local function walk(ctx: Api.Context, occ: Api.Occurrence, state: State)
	state.Stage = "Walk"
	ctx.Publish(occ, { Phase = "Active" })
end

const RoofWalker: Api.Module = {
	Ref = REF,

	Start = function(ctx: Api.Context, occ: Api.Occurrence): boolean
		const rule = ctx.Rule(REF)
		const omen = param(rule, "OmenFor", DEFAULT_OMEN)
		const walkFor = math.max(1, param(rule, "WalkFor", DEFAULT_WALK))
		const walkAt = occ.StartedAt + omen
		const state: State = {
			Stage = if omen > 0 then "Omen" else "Walk",
			WalkAt = walkAt,
			LookAt = walkAt + math.min(param(rule, "LookFrom", DEFAULT_LOOK_FROM), walkFor),
			EndsAt = walkAt + walkFor,
			OverAt = 0,
			Pitch = math.clamp(param(rule, "LookPitch", DEFAULT_PITCH), 5, 85),
			Grace = param(rule, "LookGrace", DEFAULT_GRACE),
			Leave = param(rule, "LeaveFor", DEFAULT_LEAVE),
			UpSince = {},
		}
		occ.State = state
		const phase: Api.Phase = if state.Stage == "Omen" then "Signal" else "Active"
		ctx.Publish(occ, { Phase = phase, Step = 0, Anchor = 0 })
		return true
	end,

	Tick = function(ctx: Api.Context, occ: Api.Occurrence, now: number)
		const state = occ.State :: State
		if state.Stage == "Omen" then
			if now < state.WalkAt then
				return
			end
			walk(ctx, occ, state)
		end
		if state.Stage == "Walk" then
			if now >= state.EndsAt then
				over(ctx, occ, state, now, {})
				return
			end
			if now < state.LookAt then
				return
			end
			const caught = lookers(ctx, state, now)
			if #caught > 0 then
				ctx.Log(occ, `{#caught} player(s) looked up: it drops`)
				over(ctx, occ, state, now, caught)
			end
		elseif state.Stage == "Over" and now >= state.OverAt then
			ctx.Finish(occ)
		end
	end,

	Stop = function(_ctx: Api.Context, occ: Api.Occurrence, _reason: Api.StopReason)
		occ.State = nil
	end,
}

return RoofWalker
