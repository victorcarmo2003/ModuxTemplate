--!strict
-- ANM-009 The knock (anomalies.md N9; npcs.md NPC-017; architecture.md §19.13; FEAT-019; DEC-054, DEC-204, DEC-254,
-- DEC-255; TASK-117; TASK-333, owner 2026-10-15). Rule in Rules/ANM-009.luau. V2 family D (DEC-254): a scare whose
-- only answer is NOT opening the back door. Sound only on the server (Actor Audio, NpcCost 0); the one knocking is a
-- client-only figure outside the back door that only camera 2 shows (Effects/ANM-009, TASK-285 SecurityCam).
--
--   Start    Phase Active, Step 1, cue knock (Entity 1: "Rookie? It's me. It's Walt. Open up."). "Seen" (AudioZone,
--            FEAT-019): every active player in the trailer zone when the first knock sounds gets ctx.See.
--   Second   SecondAt s: Step 2, cue knock (Entity 2: "It's cold out here, Rookie.").
--   Door     from the start until Window + DoorGrace s: whoever OPENS the back door (Action trailer_exit / trailer_enter
--            with the leaf open, TrailerDoorService) is scared AT ONCE: cue jumpscare (Entity = UserId % 65536, only
--            that client shows the face), cue door_crack (napkins fly in), ScareFaint s later VitalService:Fall.
--            Once per player per occurrence; Phase Failed.
--   End      Window + DoorGrace s: Phase Resolved when nobody opened (Failed otherwise), Finish.
--   Stop     nothing to undo.
-- PROVISIONAL (TASK-333): the old shutter test at the end is gone (the window does nothing now); not opening is the
-- answer. The door service is resolved from its module like ANM-004 does.
local ServerScriptService = game:GetService("ServerScriptService")
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Kit.CustomerActor)

const REF = "ANM-009"
const SCARE_CUE = "jumpscare"
const ENTITY_MOD = 65536 -- AnomalyCue.Entity is 0..65535
const DOOR_ACTIONS: { [string]: boolean } = { trailer_exit = true, trailer_enter = true }
-- Defaults when Rules/ANM-009 is missing (same numbers as the rule file)
const DEFAULT_WINDOW = 12
const DEFAULT_SECOND_AT = 10.8
const DEFAULT_GRACE = 2
const DEFAULT_SCARE_FAINT = 0.5
const DEFAULT_ZONE_POINT = "TRL"
const DEFAULT_ZONE_RADIUS = 24

type TrailerDoor = { IsOpen: (self: any) -> boolean }

type State = {
	SecondAt: number,
	EndsAt: number,
	ScareFaint: number,
	ZonePoint: string,
	ZoneRadius: number,
	Second: boolean,
	Scared: { [number]: boolean },
	AnyFailed: boolean,
}

local doorCache: TrailerDoor? = nil
local function trailerDoor(): TrailerDoor
	if doorCache == nil then
		doorCache = (require :: any)(ServerScriptService.server.Vehicle.TrailerDoorService) :: TrailerDoor
	end
	return doorCache :: TrailerDoor
end

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

-- V2 error (DEC-255): the face for the one who opened, the napkins for everyone, then the faint.
local function scare(ctx: Api.Context, occ: Api.Occurrence, state: State, player: Player)
	const userId = player.UserId
	if state.Scared[userId] then
		return
	end
	state.Scared[userId] = true
	if not state.AnyFailed then
		state.AnyFailed = true
		ctx.Publish(occ, { Phase = "Failed" })
		ctx.Cue(occ, "door_crack", 0)
	end
	ctx.Cue(occ, SCARE_CUE, userId % ENTITY_MOD)
	task.delay(state.ScareFaint, function()
		if player.Parent ~= nil then
			Kit.Vital():Fall(player)
		end
	end)
end

const Knock: Api.Module = {
	Ref = REF,

	Start = function(ctx: Api.Context, occ: Api.Occurrence): boolean
		const rule = ctx.Rule(REF)
		const window = if rule ~= nil and rule.Window > 0 then rule.Window else DEFAULT_WINDOW
		const state: State = {
			SecondAt = occ.StartedAt + math.min(param(rule, "SecondAt", DEFAULT_SECOND_AT), window),
			EndsAt = occ.StartedAt + window + param(rule, "DoorGrace", DEFAULT_GRACE),
			ScareFaint = param(rule, "ScareFaint", DEFAULT_SCARE_FAINT),
			ZonePoint = text(rule, "ZonePoint", DEFAULT_ZONE_POINT),
			ZoneRadius = param(rule, "ZoneRadius", DEFAULT_ZONE_RADIUS),
			Second = false,
			Scared = {},
			AnyFailed = false,
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
		if not state.AnyFailed then
			ctx.Succeed(occ)
		end
		ctx.Finish(occ)
	end,

	-- Opening the back door while it knocks: scared at once (TASK-333)
	OnEvent = function(ctx: Api.Context, occ: Api.Occurrence, event: Api.Event)
		const state = occ.State :: State?
		if state == nil or event.Kind ~= "Action" or not DOOR_ACTIONS[event.Action] then
			return
		end
		if trailerDoor():IsOpen() then
			scare(ctx, occ, state, event.Player)
		end
	end,

	Stop = function(_ctx: Api.Context, occ: Api.Occurrence, _reason: Api.StopReason)
		occ.State = nil
	end,
}

return Knock
