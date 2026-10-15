--!strict
-- ANM-004 The copies (N4; TASK-111; anomalies.md N4; npcs.md NPC-012; DEC-051, DEC-195, DEC-204, DEC-247).
-- An ordinary customer (the original: a normal spawn, counts in the customer cap and the ledger) and its mirrored copy
-- (actor Variant "mirror", CopyOf = original: same type, species and outfit, mirrored on the client — TASK-112) walk to
-- the counter together. Needs Params.FreeSlots free counter slots and NPC cap room, otherwise Start waits.
-- Refuse the copy = resolved. "Take Order" on the copy = Fail of who took it, arrival + Wrong, cue mirror_smile and the
-- copy walks off (then the door flow below). Refusing the original is only a lost sale (CustomerService counts it).
-- Copy left waiting = nothing.
-- Never on the same customer as N1: the copy is a "mirror" actor and the original is never an actor (CopyOf refuses).
-- Verb and numbers: Rules/ANM-004.luau. Body: Kit/CustomerActor.
--
-- "The copy knocks" (DEC-247, Provisional; the error of "Take Order" on the copy; the verb "refuse" does not change):
--   Error     Kit as before (-RuleBroken, cue mirror_smile, the copy walks off) and then, when the trailer has its back
--             door (TrailerDoorService:HasDoor; the cart has none: only the sanity cost), the occurrence does NOT end:
--   Locked    the door closes at once and locks (TrailerDoorService:SetLocked, exclusive to this anomaly); the prompt
--             stays, trying it only plays "Locked door" for who tried. The service window is untouched. No new customer
--             arrives (CustomerService:HoldSpawns) for DoorDelayMin..Max s (uniform, occ.Rng).
--   Knocking  the door unlocks; cue copy_knock (Entity = 1..KnockCount) KnockGapMin..Max s apart; the first one makes
--             the copy appear on the client for the players INSIDE the trailer (AnomalyController effect). Customers
--             flow again. Whoever OPENS the door from the 1st knock until DoorGrace s after the last one (Action event
--             trailer_exit / trailer_enter with the leaf open) is grabbed: Fail of that player (-RuleBroken, once per
--             occurrence), cue copy_grab, and VitalService:Fall (the sanity-0 path: Down, revivable with a Revive Kit by
--             a mate; Spectator when the revives of the night are spent, DEC-129). Not a lost night by itself.
--   End       nobody opened: cue copy_vanish (fade 2 s) and Succeed; opened: Finish after the grab/fade.
--   Stop      always unlocks the door and releases the customer hold.
--
-- PROVISIONAL (backend-coder, DEC-247): the door, faint and spawn-hold services are resolved from their modules like
-- Kit/CustomerActor does, until Api.Context has Door / Faint / HoldSpawns members.
local ServerScriptService = game:GetService("ServerScriptService")
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Kit.CustomerActor)

const SPAWN_TRIES = 4 -- draws for a spawn point different from the original's
const REASON = "ANM-004" -- lock / spawn-hold reason
const DOOR_ACTIONS: { [string]: boolean } = { trailer_exit = true, trailer_enter = true }
const GRAB_FINISH = 4.5 -- s after the grab: copy_grab (2 s) + fade (2 s) + margin, then the occurrence ends
const VANISH_FINISH = 0.5 -- s after copy_vanish the occurrence ends (the fade runs on the client)
-- Defaults when Rules/ANM-004 lacks the door numbers (same as the rule file)
const DEFAULT_DELAY_MIN = 8
const DEFAULT_DELAY_MAX = 12
const DEFAULT_KNOCKS = 3
const DEFAULT_GAP_MIN = 2
const DEFAULT_GAP_MAX = 3
const DEFAULT_GRACE = 2

-- Narrow views of the services the door flow talks to
type TrailerDoor = {
	HasDoor: (self: any) -> boolean,
	SetLocked: (self: any, reason: string, on: boolean) -> (),
	IsOpen: (self: any) -> boolean,
}
type Vital = { Fall: (self: any, player: Player, forced: string?) -> () }
type SpawnControl = { HoldSpawns: (self: any, reason: string, on: boolean) -> () }

-- Door flow of one occurrence (module-level, keyed by occurrence: Kit.State is closed)
type Door = {
	Phase: "Locked" | "Knocking" | "Grabbed" | "Ending",
	Times: { number }, -- absolute server time of each knock (Times[1] also unlocks the door)
	Next: number, -- index of the next knock to send
	EndsAt: number, -- last knock + grace
	FinishAt: number?, -- Grabbed / Ending: when the occurrence ends
}

const doors: { [Api.Occurrence]: Door } = setmetatable({}, { __mode = "k" }) :: any

local trailerDoor: TrailerDoor? = nil
local vital: Vital? = nil

local function trailer(): TrailerDoor
	if trailerDoor == nil then
		trailerDoor = (require :: any)(ServerScriptService.server.Vehicle.TrailerDoorService) :: TrailerDoor
	end
	return trailerDoor :: TrailerDoor
end

local function vitals(): Vital
	if vital == nil then
		vital = (require :: any)(ServerScriptService.server.Vital.VitalService) :: Vital
	end
	return vital :: Vital
end

local function spawns(): SpawnControl
	return (Kit.Customers() :: any) :: SpawnControl
end

local function param(rule: Api.Rule?, name: string, default: number): number
	if rule == nil then
		return default
	end
	const value = rule.Params[name]
	return if type(value) == "number" and value == value and value >= 0 and value ~= math.huge then value else default
end

local function between(rng: Random, low: number, high: number): number
	if high <= low then
		return low
	end
	return rng:NextNumber(low, high)
end

local function spawnPair(ctx: Api.Context, occ: Api.Occurrence, rule: Api.Rule, state: Kit.State): number?
	const variant = rule.Params.Variant
	const need = rule.Params.FreeSlots
	if type(variant) ~= "string" or type(need) ~= "number" then
		return nil
	end
	const customers = Kit.Customers()
	const npcs = Kit.Npcs()
	-- DEC-241: the counter holds ONE customer by default; the original and its copy need two slots (Counter L2+), so the
	-- anomaly does not start while QueueSize() < FreeSlots (the agenda retries after a Counter purchase)
	if customers:QueueSize() < need or customers:QueueSize() - customers:Occupants() < need then
		return nil
	end
	if npcs:Capacity() - npcs:Count() < need then
		return nil
	end
	-- the original is an ordinary customer: it must fit in the customer cap too
	if customers:Count() >= customers:MaxCustomers() then
		return nil
	end
	const _, original = customers:Attempt()
	if original == nil then
		return nil
	end
	const from = npcs:GetNode(original)
	local point: string? = nil
	for _ = 1, SPAWN_TRIES do
		const pick = npcs:PickSpawnPoint(true, occ.Rng)
		if pick ~= from then
			point = pick
			break
		end
	end
	const copy = ctx.Spawn({ Variant = variant, CopyOf = original, From = point })
	if copy == nil then
		ctx.Log(occ, `copy of #{original} refused; the original stays an ordinary customer`)
		return nil
	end
	state.Original = original
	return copy
end

const base = Kit.Module({
	Ref = "ANM-004",
	Spawn = spawnPair,
	FailCue = "mirror_smile",
})

-- Door flow ---------------------------------------------------------------------------------------------------------

-- Locks the door and plans the knocks. Called once, right after the copy was served.
local function beginDoor(ctx: Api.Context, occ: Api.Occurrence, rule: Api.Rule, now: number)
	const rng = occ.Rng
	const first = now
		+ between(rng, param(rule, "DoorDelayMin", DEFAULT_DELAY_MIN), param(rule, "DoorDelayMax", DEFAULT_DELAY_MAX))
	const count = math.max(1, math.floor(param(rule, "KnockCount", DEFAULT_KNOCKS)))
	const gapMin = param(rule, "KnockGapMin", DEFAULT_GAP_MIN)
	const gapMax = param(rule, "KnockGapMax", DEFAULT_GAP_MAX)
	const times: { number } = { first }
	for _ = 2, count do
		table.insert(times, times[#times] + between(rng, gapMin, gapMax))
	end
	doors[occ] = {
		Phase = "Locked",
		Times = times,
		Next = 1,
		EndsAt = times[#times] + param(rule, "DoorGrace", DEFAULT_GRACE),
		FinishAt = nil,
	}
	trailer():SetLocked(REASON, true)
	spawns():HoldSpawns(REASON, true)
	ctx.Log(occ, `door locked; first knock in {string.format("%.1f", first - now)} s`)
end

local function release()
	trailer():SetLocked(REASON, false)
	spawns():HoldSpawns(REASON, false)
end

-- The opener is grabbed: pays (once per occurrence), faints through the sanity-0 path.
local function grab(ctx: Api.Context, occ: Api.Occurrence, state: Kit.State, door: Door, player: Player, now: number)
	door.Phase = "Grabbed"
	door.Next = #door.Times + 1
	door.FinishAt = now + GRAB_FINISH
	Kit.Fail(ctx, occ, state, { player })
	ctx.Cue(occ, "copy_grab", 0)
	const ok, problem = pcall(function()
		vitals():Fall(player)
	end)
	if not ok then
		ctx.Log(occ, `Fall({player.Name}) errored: {problem}`)
	end
end

local function tickDoor(ctx: Api.Context, occ: Api.Occurrence, door: Door, now: number)
	const finishAt = door.FinishAt
	if finishAt ~= nil then
		if now >= finishAt then
			ctx.Finish(occ)
		end
		return
	end
	-- knocks due (the first one also unlocks the door and lets the customers come again)
	while door.Next <= #door.Times and now >= door.Times[door.Next] do
		if door.Next == 1 then
			door.Phase = "Knocking"
			release()
		end
		ctx.Cue(occ, "copy_knock", door.Next)
		door.Next += 1
	end
	if door.Phase == "Knocking" and now >= door.EndsAt then
		-- nobody opened: the copy fades, the door is free
		door.Phase = "Ending"
		ctx.Cue(occ, "copy_vanish", 0)
		ctx.Succeed(occ)
		door.FinishAt = now + VANISH_FINISH
	end
end

return {
	Ref = base.Ref,

	Start = base.Start,

	Tick = function(ctx: Api.Context, occ: Api.Occurrence, now: number)
		const door = doors[occ]
		if door ~= nil then
			tickDoor(ctx, occ, door, now)
		elseif base.Tick ~= nil then
			base.Tick(ctx, occ, now)
		end
	end,

	OnEvent = function(ctx: Api.Context, occ: Api.Occurrence, event: Api.Event)
		const state = occ.State :: Kit.State?
		if state == nil then
			return
		end
		const door = doors[occ]
		if door ~= nil then
			-- opening the door while the copy knocks (from the 1st knock until DoorGrace s after the last)
			if event.Kind == "Action" and DOOR_ACTIONS[event.Action] and door.Phase == "Knocking" and trailer():IsOpen() then
				grab(ctx, occ, state, door, event.Player, ctx.Now())
			end
			return
		end
		const rule = ctx.Rule(occ.Key)
		if rule ~= nil and event.Kind == "Customer" and event.Npc == state.Actor and event.Action == rule.Params.Wrong then
			const who = event.Player
			if who ~= nil and trailer():HasDoor() then
				-- the error of this anomaly: same cost and cue as the Kit, but the occurrence goes on at the back door
				Kit.Fail(ctx, occ, state, { who })
				ctx.Cue(occ, "mirror_smile", state.Actor)
				Kit.SendAway(state.Actor, nil)
				beginDoor(ctx, occ, rule, ctx.Now())
				return
			end
		end
		if base.OnEvent ~= nil then
			base.OnEvent(ctx, occ, event)
		end
	end,

	Stop = function(ctx: Api.Context, occ: Api.Occurrence, reason: Api.StopReason)
		if doors[occ] ~= nil then
			doors[occ] = nil
			release()
		end
		base.Stop(ctx, occ, reason)
	end,
} :: Api.Module
