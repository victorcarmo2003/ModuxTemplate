--!strict
-- Shared body of the customer anomalies ANM-001 (blank), ANM-004 (mirror copy) and ANM-005 (raincoat) (TASK-111;
-- anomalies.md N1/N4/N5; npcs.md NPC-009/012/013; architecture.md §19.13; FEAT-022, FEAT-023; DEC-051, DEC-054,
-- DEC-195, DEC-204). Lives in a Folder (Kit/), so AnomalyService:LoadModules never schedules it.
--
-- One occurrence = one actor at the counter (CustomerService:SpawnActor through ctx.Spawn). The verb and the numbers
-- come from Rules/<Ref>.luau (T10):
--   Verb      "refuse" or "serve": that customer action on the actor resolves (Succeed). For "serve" the sale result
--             must be one of Params.Pass (N5: an incomplete hot dog is not an error, npcs.md).
--   Wrong     Params.Wrong action on the actor -> Fail of who acted (DEC-204). The actor walks away at once (N1/N4:
--             "Take Order" on it never reaches a serve, so no money ever enters the drawer).
--   Omission  patience ran out (give_up): Params.OmissionFails -> Fail("active") (N5); otherwise no penalty (N1/N4).
--   Ledger    DEC-051: an actor is not an arrival; CountArrival + CountResult("Wrong") only on a failure, once.
--   Seen      1 s in the gaze cone of the actor's head, up to Content ViewRange (ctx.SeenTick, -5 once per night).
-- The actor gone without one of these (removed, sent away by someone else) ends the occurrence with no outcome.
-- Stop sends a still-standing actor away (NightOver, Restore, dev stop).
--
-- PROVISIONAL (TASK-111, backend-coder): Api.Context has no customer access beyond Spawn, so this kit resolves
-- CustomerService and NpcService from their modules (same object the Modux core holds; AnomalyService already lists
-- both in its Require, so they are initialised first). Proposed for the next TASK-106 pass: Context.Customers
-- { Get, Leave, Attempt, Free } and drop this lookup.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Parent.Api)

-- Narrow views of the two services (only what the kit calls)
export type CustomerView = { State: string, Variant: string? }

export type Customers = {
	Get: (self: any, id: number) -> CustomerView?,
	Leave: (self: any, id: number, mood: string?, reason: string?) -> boolean,
	Attempt: (self: any) -> (string, number?),
	Occupants: (self: any) -> number,
	QueueSize: (self: any) -> number,
	Count: (self: any) -> number,
	MaxCustomers: (self: any) -> number,
}

export type Npcs = {
	GetModel: (self: any, id: number) -> Model?,
	GetNode: (self: any, id: number) -> string?,
	Count: (self: any) -> number,
	Capacity: (self: any) -> number,
	PickSpawnPoint: (self: any, isNight: boolean, rng: Random) -> string,
}

export type State = {
	Actor: number, -- NpcId of the anomaly actor
	Original: number?, -- N4: NpcId of the ordinary customer that was copied
	LastTick: number,
	Fronted: boolean, -- the actor reached Q1 (CounterCue sent)
	Counted: boolean, -- DEC-051 arrival + Wrong already counted
}

-- Spawns the actor. nil = no slot/actor now (Start returns false, the agenda retries).
export type SpawnHook = (ctx: Api.Context, occ: Api.Occurrence, rule: Api.Rule, state: State) -> number?

export type Options = {
	Ref: string,
	Spawn: SpawnHook?, -- default: ctx.Spawn({ Variant = Params.Variant })
	CounterCue: string?, -- sent once when the actor reaches Q1 (N5 puddle)
	FailCue: string?, -- sent on a failure (N1 blank_coin, N4 mirror_smile)
}

-- Verb (Rules) -> customer action (CustomerService.Acted)
const VERB_ACTION: { [string]: string } = {
	refuse = "refuse",
	serve = "serve",
}
const GIVE_UP = "give_up"
const SERVE = "serve"
const ORDERING = "Ordering"
const LEAVING = "Leaving"
const WRONG = "Wrong"
const SHIFT_END = "shift_end"
const EYE_OFFSET = Vector3.new(0, 1.5, 0) -- root -> eye when the rig has no Head

const Kit = {}

local customersCache: Customers? = nil
local npcsCache: Npcs? = nil

function Kit.Customers(): Customers
	if customersCache == nil then
		customersCache = (require :: any)(ServerScriptService.server.Customer.CustomerService) :: Customers
	end
	return customersCache :: Customers
end

function Kit.Npcs(): Npcs
	if npcsCache == nil then
		npcsCache = (require :: any)(ServerScriptService.server.Npc.NpcService) :: Npcs
	end
	return npcsCache :: Npcs
end

-- Head of the actor's rig (the "seen" target), nil when the rig is gone.
function Kit.Position(id: number): Vector3?
	const model = Kit.Npcs():GetModel(id)
	if model == nil then
		return nil
	end
	const head = model:FindFirstChild("Head")
	if head ~= nil and head:IsA("BasePart") then
		return head.Position
	end
	return model:GetPivot().Position + EYE_OFFSET
end

-- Customer record of the actor while it still stands in the line (nil = gone or leaving).
function Kit.Standing(id: number): CustomerView?
	const customer = Kit.Customers():Get(id)
	if customer == nil or customer.State == LEAVING then
		return nil
	end
	return customer
end

-- Sends the actor away if it is still standing. false = already gone or leaving.
function Kit.SendAway(id: number, reason: string?): boolean
	if Kit.Standing(id) == nil then
		return false
	end
	return Kit.Customers():Leave(id, nil, reason)
end

-- DEC-204 who pays + DEC-051 ledger (arrival + Wrong, once per occurrence).
function Kit.Fail(ctx: Api.Context, occ: Api.Occurrence, state: State, who: { Player } | "active")
	ctx.Fail(occ, who)
	if not state.Counted then
		state.Counted = true
		ctx.Economy.CountArrival()
		ctx.Economy.CountResult(WRONG)
	end
end

local function params(rule: Api.Rule): { [string]: any }
	return rule.Params
end

local function passes(rule: Api.Rule, result: string?): boolean
	const pass = params(rule).Pass
	if result == nil or type(pass) ~= "table" then
		return false
	end
	return table.find(pass :: { string }, result) ~= nil
end

local function defaultSpawn(ctx: Api.Context, _occ: Api.Occurrence, rule: Api.Rule, _state: State): number?
	const variant = params(rule).Variant
	if type(variant) ~= "string" then
		return nil
	end
	return ctx.Spawn({ Variant = variant })
end

-- Builds the module of one customer anomaly.
function Kit.Module(options: Options): Api.Module
	const ref = options.Ref
	const spawn: SpawnHook = options.Spawn or defaultSpawn
	local warned = false

	local function ruleOf(ctx: Api.Context, occ: Api.Occurrence): Api.Rule?
		const rule = ctx.Rule(occ.Key)
		if rule == nil or VERB_ACTION[rule.Verb] == nil or type(rule.Params.Wrong) ~= "string" then
			if not warned then
				warned = true
				ctx.Log(occ, `no usable rule (Rules/{ref}.luau: Verb refuse/serve + Params.Wrong); not started`)
			end
			return nil
		end
		return rule
	end

	return {
		Ref = ref,

		Start = function(ctx: Api.Context, occ: Api.Occurrence): boolean
			const rule = ruleOf(ctx, occ)
			if rule == nil then
				return false
			end
			const state: State = { Actor = 0, Original = nil, LastTick = ctx.Now(), Fronted = false, Counted = false }
			const actor = spawn(ctx, occ, rule, state)
			if actor == nil then
				return false
			end
			state.Actor = actor
			occ.State = state
			ctx.Publish(occ, { Phase = "Active", Anchor = actor })
			return true
		end,

		Tick = function(ctx: Api.Context, occ: Api.Occurrence, now: number)
			const state = occ.State :: State
			const customer = Kit.Standing(state.Actor)
			if customer == nil then
				-- gone without a verb (removed, sent away by another system): no outcome
				ctx.Finish(occ)
				return
			end
			const dt = now - state.LastTick
			state.LastTick = now
			if not state.Fronted and customer.State == ORDERING then
				state.Fronted = true
				const cue = options.CounterCue
				if cue ~= nil then
					ctx.Cue(occ, cue, state.Actor)
				end
			end
			const position = Kit.Position(state.Actor)
			const row = Content.Anomalies.ByKey[occ.Key]
			if position ~= nil and row ~= nil then
				ctx.SeenTick(occ, position, row.ViewRange, dt)
			end
		end,

		OnEvent = function(ctx: Api.Context, occ: Api.Occurrence, event: Api.Event)
			if event.Kind ~= "Customer" then
				return
			end
			const state = occ.State :: State
			if event.Npc ~= state.Actor then
				return
			end
			const rule = ctx.Rule(occ.Key)
			if rule == nil then
				return
			end
			const action = event.Action
			const right = VERB_ACTION[rule.Verb]
			const player = event.Player
			if action == right then
				if action ~= SERVE or passes(rule, event.Result) then
					ctx.Succeed(occ)
				end
				-- PROVISIONAL (N5 wrongServeRetry): a Wrong serve sends the actor away (CustomerService has no
				-- "keep waiting"); the right verb was used, so no penalty and no success.
				ctx.Finish(occ)
			elseif action == params(rule).Wrong then
				if player ~= nil then
					Kit.Fail(ctx, occ, state, { player })
				end
				const cue = options.FailCue
				if cue ~= nil then
					ctx.Cue(occ, cue, state.Actor)
				end
				Kit.SendAway(state.Actor, nil)
				ctx.Finish(occ)
			elseif action == GIVE_UP then
				if params(rule).OmissionFails == true then
					Kit.Fail(ctx, occ, state, "active")
				end
				ctx.Finish(occ)
			end
		end,

		Stop = function(_ctx: Api.Context, occ: Api.Occurrence, reason: Api.StopReason)
			const state = occ.State :: State?
			if state == nil or state.Actor == 0 then
				return
			end
			Kit.SendAway(state.Actor, if reason == "Done" then nil else SHIFT_END)
		end,
	}
end

return table.freeze(Kit)
