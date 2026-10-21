--!strict
-- ANM-022 The head banger (V2 family A, odd customer; TASK-591; owner 2026-10-19, Provisional Q-399).
-- Sign: it stands at the window with its head hanging forward (actor Variant "banger", Effects/Kit/OddCustomer).
-- The window does NOT send it away (Params.WindowRefuses = false in Kit/CustomerActor). Shut it and it beats its head
-- on it: cue head_bang every BangEvery s (BangFaster after BangRamp blows) while the window stays shut and it is still
-- at the counter - thud, camera shake, the shutter jumping (Effects/ANM-022). The answer: turn the shop's lights off
-- (ctx.Light.IsSwitchOn false) while it stands there: Resolved, and it walks off LeaveAfterDark s later. "Take Order"
-- on it = jumpscare + faint of who took it (Kit Scare, the Kit's Wrong). Left waiting = it gives up, no penalty.
-- Verb and numbers: Rules/ANM-022.luau. Body: Kit/CustomerActor (spawn, seen, Take Order, Stop).
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Kit.CustomerActor)

const REF = "ANM-022"
const BANG_CUE = "head_bang"
const ORDERING = "Ordering"

type Extra = {
	Banging: boolean,
	NextBang: number, -- ctx.Now() of the next blow
	Blows: number,
	Darkened: boolean, -- the lights went out: resolved, walking off
}

const base = Kit.Module({
	Ref = REF,
	Scare = true,
})

const extras: { [Api.Occurrence]: Extra } = setmetatable({}, { __mode = "k" }) :: any

local function extraOf(occ: Api.Occurrence): Extra
	local extra = extras[occ]
	if extra == nil then
		extra = { Banging = false, NextBang = 0, Blows = 0, Darkened = false }
		extras[occ] = extra
	end
	return extra
end

local function actorOf(occ: Api.Occurrence): number?
	const state = occ.State
	return if type(state) == "table" and type(state.Actor) == "number" and state.Actor ~= 0 then state.Actor else nil
end

local function number(rule: Api.Rule?, key: string, default: number): number
	const value = if rule ~= nil then rule.Params[key] else nil
	return if type(value) == "number" and value == value and value >= 0 then value else default
end

const HeadBanger: Api.Module = {
	Ref = REF,

	Start = base.Start,

	Tick = function(ctx: Api.Context, occ: Api.Occurrence, now: number)
		const extra = extraOf(occ)
		if extra.Darkened then
			return -- resolved: it walks off on its own delay
		end
		const actor = actorOf(occ)
		const customer = if actor ~= nil then Kit.Standing(actor) else nil
		const atCounter = customer ~= nil and customer.State == ORDERING
		const rule = ctx.Rule(occ.Key)
		if atCounter and actor ~= nil and not ctx.Light.IsSwitchOn() then
			-- the shop went dark while it stood there: the answer
			extra.Darkened = true
			extra.Banging = false
			ctx.Succeed(occ)
			task.delay(number(rule, "LeaveAfterDark", 0.8), function()
				if extras[occ] ~= extra then
					return -- stopped meanwhile
				end
				Kit.SendAway(actor, nil)
				ctx.Finish(occ)
			end)
			return
		end
		-- the window shut in its face: its head on the glass, faster and faster
		const shut = atCounter and ctx.Vehicle.IsShutterClosed()
		if shut and actor ~= nil then
			if not extra.Banging then
				extra.Banging = true
				extra.NextBang = now
			end
			if now >= extra.NextBang then
				extra.Blows += 1
				ctx.Cue(occ, BANG_CUE, actor)
				const gap = if extra.Blows >= number(rule, "BangRamp", 8)
					then number(rule, "BangFaster", 0.35)
					else number(rule, "BangEvery", 0.55)
				extra.NextBang = now + gap
			end
		else
			extra.Banging = false
		end
		const tick = base.Tick
		if tick ~= nil then
			tick(ctx, occ, now)
		end
	end,

	OnEvent = function(ctx: Api.Context, occ: Api.Occurrence, event: Api.Event)
		if extraOf(occ).Darkened then
			return
		end
		const handler = base.OnEvent
		if handler ~= nil then
			handler(ctx, occ, event)
		end
	end,

	Stop = function(ctx: Api.Context, occ: Api.Occurrence, reason: Api.StopReason)
		extras[occ] = nil
		base.Stop(ctx, occ, reason)
	end,
}

return HeadBanger
