--!strict
-- ANM-004 The copies (N4; TASK-111; anomalies.md N4; npcs.md NPC-012; DEC-051, DEC-195, DEC-204, DEC-247).
-- An ordinary customer (the original: a normal spawn, counts in the customer cap and the ledger) comes to the counter
-- ALONE; Params.CopyDelay s after it left the counter (served, refused, gave up or went to a table) its mirrored copy
-- (actor Variant "mirror": the original's type, species and outfit read at Start, mirrored on the client — TASK-112)
-- comes back alone (TASK-347, Provisional: the night counter holds ONE NPC, Flow.NightQueueSize / TASK-287, so the
-- pair can never stand together). Start needs one free counter slot and NPC cap room, otherwise it waits. From Start
-- until the copy spawns no other customer arrives (HoldSpawns), so the slot is the copy's; no room for the copy within
-- COPY_WAIT s = the occurrence ends with no outcome. The original goes through CustomerService:Attempt, so the dev
-- "arrivals off" (DevNoArrivals, regular flow only) never stops it.
-- Refuse the copy = resolved. "Take Order" on the copy = Fail of who took it, arrival + Wrong, cue mirror_smile and the
-- copy walks off. Refusing the original is only a lost sale (CustomerService counts it).
-- Copy left waiting = nothing.
-- Never on the same customer as N1: the copy is a "mirror" actor and the original is an ordinary Attempt spawn.
-- Verb and numbers: Rules/ANM-004.luau. Body: Kit/CustomerActor.
--
-- DEC-307: the copy's back-door flow (DEC-247) left with the trailer: the restaurant has no trailer door, so the error
-- is the Kit's cost only. The spawn-hold service is resolved from its module like Kit/CustomerActor does.
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Kit.CustomerActor)

const SPAWN_TRIES = 4 -- draws for a spawn point different from the original's
const LEAVING = "Leaving"
const DEFAULT_COPY_DELAY = 2 -- s from the original leaving the counter to the copy's spawn (same as the rule file)
const COPY_WAIT = 30 -- s the copy may wait for a slot / NPC room after its delay; then the occurrence ends, no outcome
const REASON = "ANM-004" -- lock / spawn-hold reason

-- Narrow view of the spawn-hold service
type SpawnControl = { HoldSpawns: (self: any, reason: string, on: boolean) -> () }

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

-- Look of the original, read at Start (the copy spawns after the original left: CopyOf would refuse it by then)
type Look = { CustomerType: string, Species: string, Outfit: string }
type NpcLook = { CustomerType: string, Species: string, Outfit: string }

-- Waiting phase of one occurrence (TASK-347): the original is at the counter, the copy has not spawned yet
type Wait = {
	Original: number,
	Look: Look,
	From: string?, -- the original's spawn node (the copy picks another one)
	LeftAt: number?, -- server time the original left the counter
}

const waits: { [Api.Occurrence]: Wait } = setmetatable({}, { __mode = "k" }) :: any

-- Spawns the original (an ordinary customer) and starts the waiting phase. false = no slot / room now.
local function startOriginal(ctx: Api.Context, occ: Api.Occurrence): boolean
	const rule = ctx.Rule(occ.Key)
	if rule == nil or type(rule.Params.Variant) ~= "string" or type(rule.Params.Wrong) ~= "string" then
		return false
	end
	const customers = Kit.Customers()
	const npcs = Kit.Npcs()
	if customers:QueueSize() - customers:Occupants() < 1 or npcs:Capacity() - npcs:Count() < 1 then
		return false
	end
	if customers:Count() >= customers:MaxCustomers() then
		return false
	end
	const _, original = customers:Attempt()
	if original == nil then
		return false
	end
	const source = ((npcs :: any):Get(original)) :: NpcLook?
	if source == nil then
		return false
	end
	waits[occ] = {
		Original = original,
		Look = { CustomerType = source.CustomerType, Species = source.Species, Outfit = source.Outfit },
		From = npcs:GetNode(original),
		LeftAt = nil,
	}
	const state: Kit.State = { Actor = 0, Original = original, LastTick = ctx.Now(), Fronted = false, Counted = false }
	occ.State = state
	spawns():HoldSpawns(REASON, true)
	ctx.Log(occ, `original #{original} at the counter; its copy comes after it leaves`)
	return true
end

-- Waits for the original to leave the counter, then spawns the copy alone in the slot it left.
local function tickWait(ctx: Api.Context, occ: Api.Occurrence, wait: Wait, now: number)
	const rule = ctx.Rule(occ.Key)
	const state = occ.State :: Kit.State
	if rule == nil then
		return
	end
	if wait.LeftAt == nil then
		const customer = Kit.Customers():Get(wait.Original)
		if customer ~= nil and customer.State ~= LEAVING and not (customer :: any).AtTable then
			return
		end
		wait.LeftAt = now
		return
	end
	const due = (wait.LeftAt :: number) + param(rule, "CopyDelay", DEFAULT_COPY_DELAY)
	if now < due then
		return
	end
	if now >= due + COPY_WAIT then
		waits[occ] = nil
		spawns():HoldSpawns(REASON, false)
		ctx.Log(occ, `no room for the copy of #{wait.Original}; dropped`)
		ctx.Finish(occ)
		return
	end
	local point: string? = nil
	for _ = 1, SPAWN_TRIES do
		const pick = Kit.Npcs():PickSpawnPoint(true, occ.Rng)
		if pick ~= wait.From then
			point = pick
			break
		end
	end
	const look = wait.Look
	-- the hold also stops actors: lifted for this spawn only, set again when it is refused (retried next tick)
	spawns():HoldSpawns(REASON, false)
	const copy = ctx.Spawn({
		Variant = rule.Params.Variant,
		CustomerType = look.CustomerType,
		Species = look.Species,
		Outfit = look.Outfit,
		From = point,
	})
	if copy == nil then
		spawns():HoldSpawns(REASON, true)
		return
	end
	waits[occ] = nil
	state.Actor = copy
	state.LastTick = now
	ctx.Publish(occ, { Phase = "Active", Anchor = copy })
	ctx.Log(occ, `copy #{copy} of #{wait.Original} spawned`)
end

const base = Kit.Module({
	Ref = "ANM-004",
	FailCue = "mirror_smile",
})

return {
	Ref = base.Ref,

	Start = startOriginal,

	Tick = function(ctx: Api.Context, occ: Api.Occurrence, now: number)
		const wait = waits[occ]
		if wait ~= nil then
			tickWait(ctx, occ, wait, now)
		elseif base.Tick ~= nil then
			base.Tick(ctx, occ, now)
		end
	end,

	OnEvent = function(ctx: Api.Context, occ: Api.Occurrence, event: Api.Event)
		const state = occ.State :: Kit.State?
		if state == nil or waits[occ] ~= nil then
			return -- waiting phase: the original is an ordinary customer, no verb on it
		end
		if base.OnEvent ~= nil then
			base.OnEvent(ctx, occ, event)
		end
	end,

	Stop = function(ctx: Api.Context, occ: Api.Occurrence, reason: Api.StopReason)
		if waits[occ] ~= nil then
			waits[occ] = nil
			spawns():HoldSpawns(REASON, false)
		end
		base.Stop(ctx, occ, reason)
	end,
} :: Api.Module
