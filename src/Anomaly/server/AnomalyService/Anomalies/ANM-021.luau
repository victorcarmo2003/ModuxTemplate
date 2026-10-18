--!strict
-- ANM-021 The red fog (owner 2026-10-18; Rule in Rules/ANM-021.luau; scene Content.HorrorScenes anm_021_red_fog; look
-- Effects/ANM-021). Environment anomaly (Actor World, NpcCost 0), family C.
--   Start    Phase Signal: the red fog rises on the street, the bell tolls (client). OmenFor s to shut the window.
--   Glass    OmenFor: Phase Active, cue fog_bang. Every active player in the shop zone (inside the vehicle or within
--            ZoneRadius of ZonePoint) is tested: not protected (window closed and inside, ctx.Vehicle.IsProtected) ->
--            scared at once; protected -> watched.
--   Bangs    OmenFor .. OmenFor + BangFor: whoever OPENS the window (Shutter event) or a watched player who steps out of
--            the vehicle is scared. Scared = cue jumpscare (Entity = UserId % 65536), ScareFaint s later VitalService:Fall.
--   End      Phase Resolved (nobody scared) or Failed, the record stays Linger s, Finish.
-- Not -RuleBroken and not a lost night by itself (DEC-255).
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Kit.CustomerActor)

const REF = "ANM-021"
const SCARE_CUE = "jumpscare"
const BANG_CUE = "fog_bang"
const ENTITY_MOD = 65536
const DEFAULT_OMEN = 12
const DEFAULT_BANG = 14
const DEFAULT_LINGER = 5
const DEFAULT_SCARE_FAINT = 0.6
const DEFAULT_ZONE_POINT = "TRL"
const DEFAULT_ZONE_RADIUS = 24

type Stage = "Rising" | "Banging" | "Leaving"

type State = {
	Stage: Stage,
	GlassAt: number,
	EndAt: number,
	FinishAt: number,
	ScareFaint: number,
	ZonePoint: string,
	ZoneRadius: number,
	Watched: { [number]: Player },
	Scared: { [number]: boolean },
	AnyFailed: boolean,
}

local function param(rule: Api.Rule?, name: string, default: number): number
	if rule == nil then
		return default
	end
	const value = rule.Params[name]
	return if type(value) == "number" and value == value and value >= 0 then value else default
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

local function scare(ctx: Api.Context, occ: Api.Occurrence, state: State, player: Player)
	const userId = player.UserId
	state.Watched[userId] = nil
	if state.Scared[userId] then
		return
	end
	state.Scared[userId] = true
	if not state.AnyFailed then
		state.AnyFailed = true
	end
	ctx.Cue(occ, SCARE_CUE, userId % ENTITY_MOD)
	task.delay(state.ScareFaint, function()
		if player.Parent ~= nil then
			Kit.Vital():Fall(player)
		end
	end)
end

local function glass(ctx: Api.Context, occ: Api.Occurrence, state: State)
	state.Stage = "Banging"
	ctx.Publish(occ, { Phase = "Active" })
	ctx.Cue(occ, BANG_CUE, 0)
	const failing: { Player } = {}
	for _, player in ctx.Active() do
		if not inZone(ctx, state, player) then
			continue
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

const RedFog: Api.Module = {
	Ref = REF,

	Start = function(ctx: Api.Context, occ: Api.Occurrence): boolean
		const rule = ctx.Rule(REF)
		const glassAt = occ.StartedAt + param(rule, "OmenFor", DEFAULT_OMEN)
		const endAt = glassAt + param(rule, "BangFor", DEFAULT_BANG)
		occ.State = {
			Stage = "Rising",
			GlassAt = glassAt,
			EndAt = endAt,
			FinishAt = endAt + param(rule, "Linger", DEFAULT_LINGER),
			ScareFaint = param(rule, "ScareFaint", DEFAULT_SCARE_FAINT),
			ZonePoint = text(rule, "ZonePoint", DEFAULT_ZONE_POINT),
			ZoneRadius = param(rule, "ZoneRadius", DEFAULT_ZONE_RADIUS),
			Watched = {},
			Scared = {},
			AnyFailed = false,
		} :: State
		ctx.Publish(occ, { Phase = "Signal", Step = 0, Anchor = 0 })
		return true
	end,

	Tick = function(ctx: Api.Context, occ: Api.Occurrence, now: number)
		const state = occ.State :: State
		if state.Stage == "Leaving" then
			if now >= state.FinishAt then
				ctx.Finish(occ)
			end
			return
		end
		if state.Stage == "Rising" then
			if now >= state.GlassAt then
				glass(ctx, occ, state)
			end
			return
		end
		-- Banging: a watched player who steps out pays
		const out: { Player } = {}
		for _, player in state.Watched do
			if player.Parent ~= nil and not ctx.Vehicle.IsInside(player) then
				table.insert(out, player)
			end
		end
		for _, player in out do
			scare(ctx, occ, state, player)
		end
		if now >= state.EndAt then
			state.Stage = "Leaving"
			state.Watched = {}
			if state.AnyFailed then
				ctx.Publish(occ, { Phase = "Failed" })
			else
				ctx.Succeed(occ)
			end
		end
	end,

	-- opening the window while it beats on the glass scares who opened (DEC-204)
	OnEvent = function(ctx: Api.Context, occ: Api.Occurrence, event: Api.Event)
		const state = occ.State :: State?
		if state == nil or state.Stage ~= "Banging" then
			return
		end
		if event.Kind == "Shutter" and not event.Closed and event.Player ~= nil then
			scare(ctx, occ, state, event.Player)
		end
	end,

	Stop = function(_ctx: Api.Context, occ: Api.Occurrence, _reason: Api.StopReason)
		occ.State = nil
	end,
}

return RedFog
