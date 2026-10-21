--!strict
-- ANM-012 The turned neck (V2 family A, odd customer; DEC-254, DEC-255; TASK-292; anomalies-v2-proposal.md §3 A).
-- Sign: the head is turned 180 degrees, looking backwards (actor Variant "neck", client modifier Effects/Kit/OddCustomer).
-- Refuse = it leaves. "Take Order" on it = jumpscare + faint of who took it (Kit Scare). Left waiting = nothing.
-- Verb and numbers: Rules/ANM-012.luau. Body: Kit/CustomerActor.
--
-- TASK-336 (owner 2026-10-15, Provisional): being refused, she turns her neck for good with a crack.
--   Refuse          cue neck_snap (Entity = actor): the head snaps round with the `neck_crack` SFX; then the Kit as
--                   before (Resolved, she walks off).
--   Window in face  the service window closed while she stands at the counter (she was Ordering on the last tick)
--                   counts as the refusal: cue neck_snap, and SlamAfter s later she THROWS THE WINDOW OPEN again
--                   (VehicleService:SetShutter(false), cue window_slam: a bang) and walks off. Resolved, no penalty.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Kit.CustomerActor)

const REF = "ANM-012"
const ORDERING = "Ordering"
const SNAP_CUE = "neck_snap"
const SLAM_CUE = "window_slam"
const DEFAULT_SLAM_AFTER = 1.2

type Vehicles = { SetShutter: (self: any, closed: boolean, player: Player?, force: boolean?) -> boolean }

-- ShutWait (TASK-591): the ShutGrace wait of a player-closed window; a reopen in time cancels it
type Extra = { AtCounter: boolean, Snapped: boolean, Slamming: boolean, ShutWait: thread? }

const base = Kit.Module({
	Ref = REF,
	Scare = true,
})

const extras: { [Api.Occurrence]: Extra } = setmetatable({}, { __mode = "k" }) :: any

local vehicleCache: Vehicles? = nil
local function vehicles(): Vehicles
	if vehicleCache == nil then
		vehicleCache = (require :: any)(ServerScriptService.server.Vehicle.VehicleService) :: Vehicles
	end
	return vehicleCache :: Vehicles
end

local function slamAfter(ctx: Api.Context): number
	const rule = ctx.Rule(REF)
	const value = if rule ~= nil then rule.Params.SlamAfter else nil
	return if type(value) == "number" and value == value and value >= 0 then value else DEFAULT_SLAM_AFTER
end

local function actorOf(occ: Api.Occurrence): number?
	const state = occ.State
	return if type(state) == "table" and type(state.Actor) == "number" and state.Actor ~= 0 then state.Actor else nil
end

local function extraOf(occ: Api.Occurrence): Extra
	local extra = extras[occ]
	if extra == nil then
		const created: Extra = { AtCounter = false, Snapped = false, Slamming = false, ShutWait = nil }
		extras[occ] = created
		extra = created
	end
	return extra :: Extra
end

local function snap(ctx: Api.Context, occ: Api.Occurrence, actor: number)
	const extra = extraOf(occ)
	if extra.Snapped then
		return
	end
	extra.Snapped = true
	ctx.Cue(occ, SNAP_CUE, actor)
end

-- shut in her face: the crack, then she throws the window open and leaves (the refusal)
local function slam(ctx: Api.Context, occ: Api.Occurrence, actor: number)
	snap(ctx, occ, actor)
	const extra = extraOf(occ)
	extra.Slamming = true
	ctx.Succeed(occ)
	task.delay(slamAfter(ctx), function()
		if extras[occ] ~= extra then
			return -- stopped meanwhile (night over, restore)
		end
		pcall(function()
			vehicles():SetShutter(false, nil)
		end)
		ctx.Cue(occ, SLAM_CUE, actor)
		Kit.SendAway(actor, nil)
		ctx.Finish(occ)
	end)
end

const TurnedNeck: Api.Module = {
	Ref = REF,

	Start = base.Start,

	Tick = function(ctx: Api.Context, occ: Api.Occurrence, now: number)
		if extraOf(occ).Slamming then
			return -- the slam ends the occurrence (the Kit would end it as soon as she walks off)
		end
		const actor = actorOf(occ)
		if actor ~= nil then
			const customer = Kit.Standing(actor)
			extraOf(occ).AtCounter = customer ~= nil and customer.State == ORDERING
		end
		const tick = base.Tick
		if tick ~= nil then
			tick(ctx, occ, now)
		end
	end,

	OnEvent = function(ctx: Api.Context, occ: Api.Occurrence, event: Api.Event)
		const actor = actorOf(occ)
		if actor ~= nil then
			if event.Kind == "Customer" and event.Npc == actor and event.Action == "refuse" then
				snap(ctx, occ, actor)
			elseif event.Kind == "Shutter" then
				const extra = extraOf(occ)
				if extra.ShutWait ~= nil then
					task.cancel(extra.ShutWait)
					extra.ShutWait = nil
				end
				if event.Closed and extra.AtCounter and not extra.Snapped then
					-- TASK-591: shut in her face only counts once it stayed shut ShutGrace s (an accidental close
					-- reopened in time changes nothing; automatic = at once)
					const grace = if event.Player ~= nil then Content.ShopWindow.ShutGrace else 0
					extra.ShutWait = task.delay(grace, function()
						extra.ShutWait = nil
						if extras[occ] ~= extra or extra.Snapped or not ctx.Vehicle.IsShutterClosed() then
							return
						end
						slam(ctx, occ, actor)
					end)
					return
				end
			end
		end
		const handler = base.OnEvent
		if handler ~= nil then
			handler(ctx, occ, event)
		end
	end,

	Stop = function(ctx: Api.Context, occ: Api.Occurrence, reason: Api.StopReason)
		const extra = extras[occ]
		if extra ~= nil and extra.ShutWait ~= nil then
			task.cancel(extra.ShutWait)
		end
		extras[occ] = nil
		base.Stop(ctx, occ, reason)
	end,
}

return TurnedNeck
