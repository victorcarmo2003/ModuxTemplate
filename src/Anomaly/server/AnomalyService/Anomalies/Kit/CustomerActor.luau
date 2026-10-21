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
--   Window    TASK-354 (owner 2026-10-17, Provisional): there is no "Refuse" prompt any more; closing the service window
--             (Shutter event, Closed) while the actor is still in line IS the refusal: handled as Customer action
--             "refuse" by who closed (nil = automatic: no Fail, the actor still leaves). CustomerService.SendLineAway
--             skips actors, so this is the only place the window reaches them.
--             TASK-591 (owner 2026-10-19): only once the window stayed shut Content.ShopWindow.ShutGrace s (the NPCs'
--             grace): a quick reopen after an accidental close changes nothing. Params.WindowRefuses = false: the
--             window does not reach the actor at all (ANM-022 leaves only when the lights go out).
--   WrongServe TASK-591: Params.WrongServeFails = true makes a serve outside Params.Pass the error too (ANM-011: only
--             a plain hot dog calms him), not just a send-away.
-- The actor gone without one of these (removed, sent away by someone else) ends the occurrence with no outcome.
-- Stop sends a still-standing actor away (NightOver, Restore, dev stop).
--
-- V2 error (DEC-255, DEC-256; TASK-269), Options.Scare: the Wrong action is not -RuleBroken. Instead: Phase Failed,
-- cue "jumpscare" (Entity = actor; players near it see the cartoon face, Effects/Kit/Jumpscare), the ledger as
-- before, and SCARE_FAINT s later VitalService:Fall of who acted (Down, revivable with a Revive Kit; Spectator when
-- the revives of the night are spent, DEC-129). Not a lost night by itself.
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
	ShutWait: thread?, -- TASK-591: the ShutGrace wait of a player-closed window
}

-- Spawns the actor. nil = no slot/actor now (Start returns false, the agenda retries).
export type SpawnHook = (ctx: Api.Context, occ: Api.Occurrence, rule: Api.Rule, state: State) -> number?

export type Options = {
	Ref: string,
	Spawn: SpawnHook?, -- default: ctx.Spawn({ Variant = Params.Variant })
	CounterCue: string?, -- sent once when the actor reaches Q1 (N5 puddle)
	FailCue: string?, -- sent on a failure (N1 blank_coin, N4 mirror_smile)
	Scare: boolean?, -- V2 error (DEC-255): jumpscare + faint instead of -RuleBroken
}

-- Verb (Rules) -> customer action (CustomerService.Acted)
const VERB_ACTION: { [string]: string } = {
	refuse = "refuse",
	serve = "serve",
}
const GIVE_UP = "give_up"
const REFUSE = "refuse"
const SERVE = "serve"
const ORDERING = "Ordering"
const LEAVING = "Leaving"
const WRONG = "Wrong"
const SHIFT_END = "shift_end"
const EYE_OFFSET = Vector3.new(0, 1.5, 0) -- root -> eye when the rig has no Head
const SCARE_CUE = "jumpscare"
const SCARE_FAINT = 0.7 -- s from the cue to the faint: the face (~0.6 s) is on screen first (DEC-256)

type Vital = { Fall: (self: any, player: Player, forced: string?) -> () }

const Kit = {}

local customersCache: Customers? = nil
local npcsCache: Npcs? = nil
local vitalCache: Vital? = nil

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

function Kit.Vital(): Vital
	if vitalCache == nil then
		vitalCache = (require :: any)(ServerScriptService.server.Vital.VitalService) :: Vital
	end
	return vitalCache :: Vital
end

-- V2 error (DEC-255, DEC-256): jumpscare for `player` only (owner 2026-10-20: "somente naquele que morreu"; it used to
-- be every player near the actor), then `player` faints. Entity stays the actor (the client's face comes from it), User
-- = the one who pays. Ledger as Kit.Fail.
function Kit.Scare(ctx: Api.Context, occ: Api.Occurrence, state: State, player: Player)
	ctx.Publish(occ, { Phase = "Failed" })
	ctx.Cue(occ, SCARE_CUE, state.Actor, player.UserId)
	if not state.Counted then
		state.Counted = true
		ctx.Economy.CountArrival()
		ctx.Economy.CountResult(WRONG)
	end
	task.delay(SCARE_FAINT, function()
		if player.Parent ~= nil then
			Kit.Vital():Fall(player)
		end
	end)
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

local function cancelShut(state: State)
	const wait = state.ShutWait
	if wait ~= nil then
		state.ShutWait = nil
		task.cancel(wait)
	end
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

	-- One customer action on the actor (or the window standing in for "refuse"): the verb resolves, the wrong one fails
	local function act(ctx: Api.Context, occ: Api.Occurrence, state: State, action: string, player: Player?, result: string?)
		const rule = ctx.Rule(occ.Key)
		if rule == nil then
			return
		end
		cancelShut(state)
		const right = VERB_ACTION[rule.Verb]
		const wrongServe = action == SERVE and action == right and not passes(rule, result) and params(rule).WrongServeFails == true
		if action == right and not wrongServe then
			if action ~= SERVE or passes(rule, result) then
				ctx.Succeed(occ)
			end
			-- PROVISIONAL (N5 wrongServeRetry): a Wrong serve sends the actor away (CustomerService has no
			-- "keep waiting"); the right verb was used, so no penalty and no success.
			ctx.Finish(occ)
		elseif action == params(rule).Wrong or wrongServe then
			if player ~= nil then
				if options.Scare then
					Kit.Scare(ctx, occ, state, player)
				else
					Kit.Fail(ctx, occ, state, { player })
				end
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
	end

	return {
		Ref = ref,

		Start = function(ctx: Api.Context, occ: Api.Occurrence): boolean
			const rule = ruleOf(ctx, occ)
			if rule == nil then
				return false
			end
			const state: State =
					{ Actor = 0, Original = nil, LastTick = ctx.Now(), Fronted = false, Counted = false, ShutWait = nil }
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
			const state = occ.State :: State
			if event.Kind == "Customer" then
				if event.Npc ~= state.Actor then
					return
				end
				act(ctx, occ, state, event.Action, event.Player, event.Result)
			elseif event.Kind == "Shutter" then
				const rule = ctx.Rule(occ.Key)
				if rule == nil or params(rule).WindowRefuses == false then
					return
				end
				cancelShut(state)
				if not event.Closed or Kit.Standing(state.Actor) == nil then
					return -- reopened in time: nothing happened
				end
				const player = event.Player
				if player == nil then
					act(ctx, occ, state, REFUSE, nil, nil) -- automatic: at once, as for the NPCs
					return
				end
				-- the window shut in its face (TASK-354), counted only once it stayed shut (TASK-591)
				state.ShutWait = task.delay(Content.ShopWindow.ShutGrace, function()
					state.ShutWait = nil
					if occ.State == state and ctx.Vehicle.IsShutterClosed() and Kit.Standing(state.Actor) ~= nil then
						act(ctx, occ, state, REFUSE, player, nil)
					end
				end)
			end
		end,

		Stop = function(_ctx: Api.Context, occ: Api.Occurrence, reason: Api.StopReason)
			const state = occ.State :: State?
			if state == nil or state.Actor == 0 then
				return
			end
			cancelShut(state)
			Kit.SendAway(state.Actor, if reason == "Done" then nil else SHIFT_END)
		end,
	}
end

return table.freeze(Kit)
