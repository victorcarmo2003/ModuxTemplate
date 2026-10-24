--!strict
-- Shared body of every customer anomaly (TASK-111; ANM-001/004/005 and the V2 family A; anomalies.md N1/N4/N5; npcs.md
-- NPC-009/012/013; architecture.md §19.13; FEAT-022, FEAT-023; DEC-051, DEC-054, DEC-195, DEC-204, DEC-255). Lives in a
-- Folder (Kit/), so AnomalyService:LoadModules never schedules it.
--
-- One occurrence = one actor at the counter (CustomerService:SpawnActor through ctx.Spawn).
--
-- Owner 2026-10-22 (Provisional; design/anomalies-after-accept-proposal.md §9): there is no ACCEPT / REFUSE any more. The
-- tablet takes EVERY order at the end of the talk (CustomerService:TakeOrderFor), the anomaly's too, so "take_order" on
-- the actor is never the error. The anomaly is mandatory: the player must know how to handle it from Walt's hints.
--   Arrival   Phase Active from the spawn: the actor walks to the counter like anyone. No screen layer (the scene's
--             Active keeps only what the security cameras show, Content.HorrorScenes); the talk plays the tic (TabletService).
--   Queue     "take_order" on the actor: Phase Queue (Step 0), its order joins the delivery line like a customer's, the
--             rig gets AnomalyQueue = server time (every client deforms the body: the tic's residue made explicit, Kit/Tic,
--             OddCustomer) and the condition of Rules/<Ref> Params.Condition starts. The scene's tension plays now (bars,
--             whispers of the hint, edges, colour, heart) and the caption shows the hint (Content.AnomalyHints).
--   Right end the condition held and the order was served (Complete / Perfect / Incomplete): Phase Resolved, she takes the
--             plate and goes (CustomerService); x PayMult the line price (+ Bonus) through ctx.Economy.AddSale, the
--             ledger counts it as an arrival and its result (proposal §5.5). AnomalyQueue cleared: she calms down.
--   Wrong end the condition broke: Kit.Scare (jumpscare + faint of who pays, Options.Scare) or Kit.Fail (-RuleBroken),
--             FailCue, she walks off. A "Plain" error is attention only: no jumpscare (see Plain).
--   No end    a wrong hot dog that is not the condition (Orders: Wrong) = she leaves complaining, no outcome; patience out
--             = she leaves (Hurry: that IS the timeout; Serve: OmitSanity from every active player); gone otherwise = no
--             outcome.
-- Conditions (Params.Condition.Kind; every number Provisional, defaults below):
--   Hurry   (ANM-014 "BE QUICK") serve within Seconds of entering the queue. Steps marks the clock: every Seconds/Steps the
--           record Step and the rig's AnomalyStep go up (the head swells another step, a creak). Seconds out (or her
--           patience out first) = the wrong end on the taker (the player whose talk took the order; else the nearest
--           active player).
--   NoLook  (ANM-012 "DON'T LOOK AT HER") at the instant of the serve the server's gaze of who serves must not hold her
--           head (ctx.Looking, Angle = full cone in degrees, Range studs; the Gaze packet of the Stare / "seen" checks).
--           Looking = the serve is the error (CustomerService:AddActorJudge "Wrong": $0, the hot dog stays in the hand)
--           and he pays. No fresh Gaze (not in first person) = not looking.
--   Plain   (ANM-011 "JUST BREAD", attention; proposal §9.9) served right = a plate with the bun alone (owner 2026-10-22:
--           his order has no sausage, Content.OrderRules.BreadOnly); ANY hot dog, plain or not, is thrown at the wall
--           (AddActorJudge "Return": the hot dog is lost, $0, no sale; cue plate_throw; rig AnomalyThrow = its toppings,
--           AnomalyRage = server time of the first throw: enraged until he leaves or is served plain). The first Returns
--           throws cost who served ReturnSanity and he keeps waiting; one more = thrown again, Phase Failed, -Sanity of
--           who served it, and after Content.PlateThrow.LeaveDelay he stomps off. Never a jumpscare.
--   Serve   any served order is the right end; no error (the interim of the anomalies not migrated yet, proposal §9.4).
-- Window (owner 2026-10-23, Provisional): closing the service window sends a customer anomaly away at once, before or
-- after its order, with no outcome and no scare (unjudge, Leave, Finish). The ordinary customers stay (CustomerService).
-- ANM-022 (head banger) filters the event out: the shut window is where it bangs its head.
-- Seen: 1 s in the gaze cone of the actor's head, up to Content ViewRange (ctx.SeenTick, -5 once per night).
-- Stop sends a still-standing actor away (NightOver, Restore, dev stop).
--
-- PROVISIONAL (TASK-111, backend-coder): Api.Context has no customer access beyond Spawn, so this kit resolves
-- CustomerService, NpcService and VitalService from their modules (same object the Modux core holds; AnomalyService
-- already lists them in its Require, so they are initialised first). Proposed for the next TASK-106 pass: Context.Customers.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Parent.Api)

-- Narrow views of the services (only what the kit calls)
export type CustomerView = { State: string, Variant: string? }

-- `bread` = a plate with the bun alone was handed over, not a hot dog (CustomerService:IsBreadPlate)
export type ActorJudge = (id: number, toppings: { string }, player: Player, bread: boolean) -> string?

export type Customers = {
	Get: (self: any, id: number) -> CustomerView?,
	Leave: (self: any, id: number, mood: string?, reason: string?) -> boolean,
	Attempt: (self: any) -> (string, number?),
	Occupants: (self: any) -> number,
	QueueSize: (self: any) -> number,
	Count: (self: any) -> number,
	MaxCustomers: (self: any) -> number,
	AddActorJudge: (self: any, judge: ActorJudge) -> () -> (),
	GetTicket: (self: any, id: number) -> { Lines: { { Price: number } } }?,
}

export type Npcs = {
	GetModel: (self: any, id: number) -> Model?,
	GetNode: (self: any, id: number) -> string?,
	Count: (self: any) -> number,
	Capacity: (self: any) -> number,
	PickSpawnPoint: (self: any, isNight: boolean, rng: Random) -> string,
}

export type Kind = "Hurry" | "NoLook" | "Plain" | "Serve"

-- Params.Condition of a rule, numbers resolved (Kit.ConditionOf)
export type Condition = {
	Kind: Kind,
	Seconds: number, -- Hurry: s from the queue to the error
	Steps: number, -- Hurry: steps of the clock (the last one is the error)
	Angle: number, -- NoLook: full gaze cone, degrees
	Range: number, -- NoLook: studs
	Returns: number, -- Plain: plates thrown back before the error
	ReturnSanity: number, -- Plain: sanity lost by who served each of those
	Sanity: number, -- Plain: sanity lost by who served the error
	OmitSanity: number, -- Serve: sanity lost by every active player when her patience runs out
	PayMult: number, -- x the line price on the right end (1 = an ordinary sale)
	Bonus: number, -- $ on top on the right end
}

export type State = {
	Actor: number, -- NpcId of the anomaly actor
	Original: number?, -- N4: NpcId of the ordinary customer that was copied
	LastTick: number,
	Fronted: boolean, -- the actor reached Q1 (CounterCue sent)
	Counted: boolean, -- DEC-051 arrival + result already counted
	Queued: boolean, -- its order was taken: the condition runs
	QueuedAt: number, -- server time it entered the queue
	Taker: Player?, -- whose talk took the order
	Step: number, -- Hurry: steps published
	Broke: Player?, -- who broke the condition at the serve being sold (AddActorJudge), read by the serve event
	Returned: number, -- Plain: plates thrown back
	Thrown: string?, -- Plain: toppings of the hot dog being thrown ("mustard,onion"), from the judge to the return event
	Leaving: boolean, -- Plain: the error was thrown, he stomps off after LeaveDelay (every serve is Wrong meanwhile)
	Unjudge: (() -> ())?, -- removes its AddActorJudge
	-- a serve was sold and CustomerService walks her out itself (with the plate when it was good): Stop does not send her
	Served: boolean,
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

const TAKE_ORDER = "take_order"
const SERVE = "serve"
const REFUSE = "refuse"
const GIVE_UP = "give_up"
const RETURN = "return"
const LEAVING = "Leaving"
const WRONG = "Wrong"
const SHIFT_END = "shift_end"
const EYE_OFFSET = Vector3.new(0, 1.5, 0) -- root -> eye when the rig has no Head
const SCARE_CUE = "jumpscare"
const THROW_CUE = "plate_throw"
const SCARE_FAINT = 0.7 -- s from the cue to the faint: the face (~0.6 s) is on screen first (DEC-256)
-- rig attributes read by every client (Effects/Kit/Tic, OddCustomer): the server time the actor entered the delivery
-- queue (its body deformed), and the Hurry step
const QUEUE_ATTRIBUTE = "AnomalyQueue"
const STEP_ATTRIBUTE = "AnomalyStep"
-- Plain (proposal §9.9): server time of his first throw (enraged: the face, the bugged body) and the toppings of the plate
-- being thrown (the client's copy of it), both read by every client (Effects/Kit/Tantrum)
const RAGE_ATTRIBUTE = "AnomalyRage"
const THROW_ATTRIBUTE = "AnomalyThrow"
const LEAVE_MOOD = "Complaining" -- Content.Moods: he stomps off complaining
const GOOD: { [string]: boolean } = { Complete = true, Perfect = true, Incomplete = true }
const FULL: { [string]: boolean } = { Complete = true, Perfect = true }
const KINDS: { [string]: boolean } = { Hurry = true, NoLook = true, Plain = true, Serve = true }
-- Provisional defaults (Rules/<Ref> Params.Condition overrides each)
const DEFAULTS = table.freeze({
	Seconds = 40,
	Steps = 4,
	Angle = 30,
	Range = 24,
	Returns = 1,
	ReturnSanity = 0,
	Sanity = 5,
	OmitSanity = 0,
	PayMult = 1,
	Bonus = 0,
})

type Vital = {
	Fall: (self: any, player: Player, forced: string?) -> (),
	AddSanity: (self: any, player: Player, delta: number, cause: string) -> number,
}

const Kit = {}

Kit.QueueAttribute = QUEUE_ATTRIBUTE
Kit.StepAttribute = STEP_ATTRIBUTE
Kit.RageAttribute = RAGE_ATTRIBUTE
Kit.ThrowAttribute = THROW_ATTRIBUTE

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

-- A fresh state for `actor` (0 = not spawned yet).
function Kit.NewState(ctx: Api.Context, actor: number, original: number?): State
	return {
		Actor = actor,
		Original = original,
		LastTick = ctx.Now(),
		Fronted = false,
		Counted = false,
		Queued = false,
		QueuedAt = 0,
		Taker = nil,
		Step = 0,
		Broke = nil,
		Returned = 0,
		Thrown = nil,
		Leaving = false,
		Unjudge = nil,
		Served = false,
	}
end

local function number(source: { [string]: any }, key: string, default: number): number
	const value = source[key]
	return if type(value) == "number" and value == value and value >= 0 and value ~= math.huge then value else default
end

-- Patience scale of an actor the player must not serve (Rule Params.Unservable, owner 2026-10-22, Provisional): both
-- clocks run Content.OrderRules.UnservablePatienceScale of their time; nil = ordinary patience
function Kit.PatienceScale(rule: Api.Rule?): number?
	if rule ~= nil and rule.Params.Unservable == true then
		return Content.OrderRules.UnservablePatienceScale
	end
	return nil
end

-- Params.Condition of a rule with every number resolved; a missing or unknown Kind = "Serve" (no error possible).
function Kit.ConditionOf(rule: Api.Rule?): Condition
	const raw = if rule ~= nil then rule.Params.Condition else nil
	const source: { [string]: any } = if type(raw) == "table" then raw else {}
	const kind = if type(source.Kind) == "string" and KINDS[source.Kind] then source.Kind :: Kind else "Serve"
	return {
		Kind = kind,
		Seconds = math.max(number(source, "Seconds", DEFAULTS.Seconds), 1),
		Steps = math.max(math.floor(number(source, "Steps", DEFAULTS.Steps)), 1),
		Angle = math.clamp(number(source, "Angle", DEFAULTS.Angle), 1, 180),
		Range = number(source, "Range", DEFAULTS.Range),
		Returns = math.floor(number(source, "Returns", DEFAULTS.Returns)),
		ReturnSanity = number(source, "ReturnSanity", DEFAULTS.ReturnSanity),
		Sanity = number(source, "Sanity", DEFAULTS.Sanity),
		OmitSanity = number(source, "OmitSanity", DEFAULTS.OmitSanity),
		PayMult = math.max(number(source, "PayMult", DEFAULTS.PayMult), 1),
		Bonus = math.floor(number(source, "Bonus", DEFAULTS.Bonus)),
	}
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

-- A rig attribute of the actor (the body every client deforms)
local function mark(id: number, name: string, value: any)
	const model = Kit.Npcs():GetModel(id)
	if model ~= nil then
		model:SetAttribute(name, value)
	end
end

local function unjudge(state: State)
	const remove = state.Unjudge
	if remove ~= nil then
		state.Unjudge = nil
		remove()
	end
end

-- Price of the actor's first line (the x PayMult of the right end); 0 when the ticket is gone.
local function priceOf(id: number): number
	const ticket = Kit.Customers():GetTicket(id)
	const line = if ticket ~= nil then ticket.Lines[1] else nil
	return if line ~= nil and type(line.Price) == "number" then line.Price else 0
end

-- Who pays an omission (Hurry): the taker while active, else the active player nearest to the actor.
local function payerOf(ctx: Api.Context, state: State): Player?
	const active = ctx.Active()
	const taker = state.Taker
	if taker ~= nil and table.find(active, taker) ~= nil then
		return taker
	end
	const at = Kit.Position(state.Actor)
	local best: Player? = nil
	local bestDistance = math.huge
	for _, player in active do
		const character = player.Character
		const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if root ~= nil and root:IsA("BasePart") then
			const distance = if at ~= nil then (root.Position - at).Magnitude else 0
			if distance < bestDistance then
				best = player
				bestDistance = distance
			end
		end
	end
	return best
end

-- Builds the module of one customer anomaly.
function Kit.Module(options: Options): Api.Module
	const ref = options.Ref
	local warned = false

	local function conditionOf(ctx: Api.Context, occ: Api.Occurrence): Condition
		return Kit.ConditionOf(ctx.Rule(occ.Key))
	end

	local function defaultSpawn(ctx: Api.Context, _occ: Api.Occurrence, rule: Api.Rule, _state: State): number?
		const variant = rule.Params.Variant
		if type(variant) ~= "string" then
			return nil
		end
		return ctx.Spawn({ Variant = variant, PatienceScale = Kit.PatienceScale(rule) })
	end
	const spawn: SpawnHook = options.Spawn or defaultSpawn

	-- The wrong end on `player` (nil = nobody to pay: only the phase): the jumpscare or -RuleBroken, the fail cue, she goes
	local function wrong(ctx: Api.Context, occ: Api.Occurrence, state: State, player: Player?)
		unjudge(state)
		if player ~= nil then
			if options.Scare then
				Kit.Scare(ctx, occ, state, player)
			else
				Kit.Fail(ctx, occ, state, { player })
			end
		else
			ctx.Publish(occ, { Phase = "Failed" })
		end
		const cue = options.FailCue
		if cue ~= nil then
			ctx.Cue(occ, cue, state.Actor)
		end
		Kit.SendAway(state.Actor, nil)
		ctx.Finish(occ)
	end

	-- The right end: Resolved, the x PayMult (+ Bonus), the ledger; she calms down and takes the plate (CustomerService)
	local function right(ctx: Api.Context, occ: Api.Occurrence, state: State, result: string)
		unjudge(state)
		const condition = conditionOf(ctx, occ)
		ctx.Succeed(occ)
		local extra = condition.Bonus
		if FULL[result] then
			extra += math.floor(priceOf(state.Actor) * (condition.PayMult - 1))
		end
		if extra > 0 then
			ctx.Economy.AddSale(extra)
		end
		if not state.Counted then
			state.Counted = true
			ctx.Economy.CountArrival()
			ctx.Economy.CountResult(result)
		end
		mark(state.Actor, QUEUE_ATTRIBUTE, nil)
		mark(state.Actor, STEP_ATTRIBUTE, nil)
		-- Plain: served plain at last, his rage goes
		mark(state.Actor, RAGE_ATTRIBUTE, nil)
		mark(state.Actor, THROW_ATTRIBUTE, nil)
		ctx.Finish(occ)
	end

	-- Plain's error (attention, proposal §9.9): no jumpscare. Failed and -Sanity of who served now; he stays for the throw,
	-- the TUM and his line (Content.PlateThrow.LeaveDelay; every serve meanwhile is Wrong, the judge) and stomps off
	local function plainWrong(ctx: Api.Context, occ: Api.Occurrence, state: State, player: Player?)
		const condition = conditionOf(ctx, occ)
		state.Leaving = true
		ctx.Publish(occ, { Phase = "Failed" })
		if player ~= nil and condition.Sanity > 0 then
			Kit.Vital():AddSanity(player, -condition.Sanity, `anomaly:{occ.Key}`)
		end
		if not state.Counted then
			state.Counted = true
			ctx.Economy.CountArrival()
			ctx.Economy.CountResult(WRONG)
		end
		task.delay(Content.PlateThrow.LeaveDelay, function()
			unjudge(state)
			if Kit.Standing(state.Actor) ~= nil then
				Kit.Customers():Leave(state.Actor, LEAVE_MOOD, nil)
			end
			ctx.Finish(occ)
		end)
	end

	-- Plain: a topping hot dog was taken from `player` (CustomerService "return": lost, no sale). He throws it at the wall
	-- (cue; the clients copy the plate from AnomalyThrow) and gets enraged; the first Returns throws cost ReturnSanity and he
	-- keeps waiting, the next one is the error
	local function thrown(ctx: Api.Context, occ: Api.Occurrence, state: State, player: Player?)
		if state.Leaving then
			return
		end
		const condition = conditionOf(ctx, occ)
		state.Returned += 1
		mark(state.Actor, THROW_ATTRIBUTE, state.Thrown or "")
		state.Thrown = nil
		const model = Kit.Npcs():GetModel(state.Actor)
		if model ~= nil and model:GetAttribute(RAGE_ATTRIBUTE) == nil then
			model:SetAttribute(RAGE_ATTRIBUTE, ctx.Now())
		end
		ctx.Cue(occ, THROW_CUE, state.Actor)
		if state.Returned > condition.Returns then
			plainWrong(ctx, occ, state, player)
			return
		end
		if player ~= nil and condition.ReturnSanity > 0 then
			Kit.Vital():AddSanity(player, -condition.ReturnSanity, `anomaly:{occ.Key}`)
		end
	end

	-- Asked by CustomerService before the sale of a serve on the actor (AddActorJudge): the condition's verdict
	local function judge(
		ctx: Api.Context,
		occ: Api.Occurrence,
		state: State,
		id: number,
		toppings: { string },
		player: Player,
		bread: boolean
	): string?
		if id ~= state.Actor or not state.Queued or occ.State ~= state then
			return nil
		end
		if state.Leaving then
			return "Wrong" -- Plain: thrown for good, he is about to stomp off; no sale, no throw
		end
		const condition = conditionOf(ctx, occ)
		if condition.Kind == "NoLook" then
			const head = Kit.Position(state.Actor)
			if head ~= nil and ctx.Looking(player, head, condition.Range, condition.Angle) then
				state.Broke = player
				return "Wrong"
			end
		elseif condition.Kind == "Plain" and not bread then
			-- owner 2026-10-22: JUST BREAD = a plate with the bun alone; any hot dog (the sausage, with or without toppings)
			-- is thrown (the return event, thrown); the throw count decides the error
			state.Thrown = table.concat(toppings, ",")
			return "Return"
		end
		return nil
	end

	-- "take_order" on the actor (the end of the talk): the delivery queue and its condition
	local function enterQueue(ctx: Api.Context, occ: Api.Occurrence, state: State, player: Player?)
		if state.Queued then
			return
		end
		state.Queued = true
		state.QueuedAt = ctx.Now()
		state.Taker = player
		state.Step = 0
		state.Returned = 0
		state.Thrown = nil
		state.Unjudge = Kit.Customers():AddActorJudge(function(id: number, toppings: { string }, server: Player, bread: boolean): string?
			return judge(ctx, occ, state, id, toppings, server, bread)
		end)
		mark(state.Actor, QUEUE_ATTRIBUTE, state.QueuedAt)
		mark(state.Actor, STEP_ATTRIBUTE, 0)
		ctx.Publish(occ, { Phase = "Queue", Step = 0 })
	end

	-- the serve was sold (Acted "serve", the SaleResult): the condition decided before (judge), the food decides the rest
	local function served(ctx: Api.Context, occ: Api.Occurrence, state: State, player: Player?, result: string?)
		if state.Leaving then
			return -- Plain: a Wrong serve while he was about to stomp off (CustomerService walks him out now)
		end
		const broke = state.Broke
		state.Broke = nil
		if broke ~= nil then
			const condition = conditionOf(ctx, occ)
			if condition.Kind == "Plain" then
				-- `/dev cond fail`: the last throw at once
				state.Returned = math.max(state.Returned, condition.Returns)
				thrown(ctx, occ, state, broke)
			else
				wrong(ctx, occ, state, broke)
			end
			return
		end
		-- CustomerService concludes the sale right after this event: she takes the plate (good) or complains (Wrong) and
		-- walks off on her own; Stop must not send her away first (she would leave without the plate)
		state.Served = true
		if result ~= nil and GOOD[result] then
			right(ctx, occ, state, result)
			return
		end
		-- a wrong hot dog (not the condition): she leaves complaining (CustomerService), no outcome
		unjudge(state)
		ctx.Finish(occ)
	end

	-- patience ran out (no player)
	local function gaveUp(ctx: Api.Context, occ: Api.Occurrence, state: State)
		if state.Leaving then
			return -- Plain: already on his way out (plainWrong finishes)
		end
		const condition = conditionOf(ctx, occ)
		if state.Queued and condition.Kind == "Hurry" then
			wrong(ctx, occ, state, payerOf(ctx, state))
			return
		end
		if state.Queued and condition.OmitSanity > 0 then
			for _, player in ctx.Active() do
				Kit.Vital():AddSanity(player, -condition.OmitSanity, `anomaly:{occ.Key}`)
			end
		end
		unjudge(state)
		ctx.Finish(occ)
	end

	-- Hurry's clock (5 Hz): a step every Seconds / Steps, the error at Seconds
	local function hurry(ctx: Api.Context, occ: Api.Occurrence, state: State, now: number)
		const condition = conditionOf(ctx, occ)
		if condition.Kind ~= "Hurry" then
			return
		end
		const elapsed = now - state.QueuedAt
		if elapsed >= condition.Seconds then
			state.Step = condition.Steps
			mark(state.Actor, STEP_ATTRIBUTE, condition.Steps)
			ctx.Publish(occ, { Step = condition.Steps })
			wrong(ctx, occ, state, payerOf(ctx, state))
			return
		end
		const step = math.floor(elapsed / (condition.Seconds / condition.Steps))
		if step > state.Step then
			state.Step = step
			mark(state.Actor, STEP_ATTRIBUTE, step)
			ctx.Publish(occ, { Step = step })
		end
	end

	return {
		Ref = ref,

		Start = function(ctx: Api.Context, occ: Api.Occurrence): boolean
			const rule = ctx.Rule(occ.Key)
			if rule == nil then
				if not warned then
					warned = true
					ctx.Log(occ, `no rule (Rules/{ref}.luau); not started`)
				end
				return false
			end
			const state = Kit.NewState(ctx, 0, nil)
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
				-- gone without an end (removed, sent away by another system): no outcome
				unjudge(state)
				ctx.Finish(occ)
				return
			end
			const dt = now - state.LastTick
			state.LastTick = now
			if not state.Fronted and customer.State == "Ordering" then
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
			if state.Queued then
				hurry(ctx, occ, state, now)
			end
		end,

		OnEvent = function(ctx: Api.Context, occ: Api.Occurrence, event: Api.Event)
			const state = occ.State :: State
			-- Shutter: a closed window sends her away (header, Window)
			if event.Kind == "Shutter" then
				if event.Closed then
					unjudge(state)
					Kit.SendAway(state.Actor, nil)
					ctx.Finish(occ)
				end
				return
			end
			if event.Kind ~= "Customer" or event.Npc ~= state.Actor then
				return
			end
			const action = event.Action
			if action == TAKE_ORDER then
				enterQueue(ctx, occ, state, event.Player)
			elseif action == SERVE then
				served(ctx, occ, state, event.Player, event.Result)
			elseif action == RETURN then
				-- Plain: the topping hot dog was taken; he throws the plate at the wall
				thrown(ctx, occ, state, event.Player)
			elseif action == GIVE_UP then
				gaveUp(ctx, occ, state)
			elseif action == REFUSE then
				-- no REFUSE any more (owner 2026-10-22); an old caller (RefuseOne) still only sends her away, no outcome
				unjudge(state)
				Kit.SendAway(state.Actor, nil)
				ctx.Finish(occ)
			end
		end,

		Stop = function(_ctx: Api.Context, occ: Api.Occurrence, reason: Api.StopReason)
			const state = occ.State :: State?
			if state == nil then
				return
			end
			unjudge(state)
			if state.Actor == 0 or (state.Served and reason == "Done") then
				return
			end
			Kit.SendAway(state.Actor, if reason == "Done" then nil else SHIFT_END)
		end,
	}
end

-- Dev (`/dev cond`, Dev/Commands/Cond) ----------------------------------------------------------------------------------

-- One line about the occurrence: phase of the condition, its clock, who took the order, plates sent back.
function Kit.Describe(ctx: Api.Context, occ: Api.Occurrence): string
	const state = occ.State
	if type(state) ~= "table" or type(state.Actor) ~= "number" then
		return `{occ.Ref}: no actor yet`
	end
	const typed = state :: State
	const condition = Kit.ConditionOf(ctx.Rule(occ.Key))
	const parts: { string } = { `{occ.Ref} #{typed.Actor} {condition.Kind}` }
	if not typed.Queued then
		const customer = Kit.Customers():Get(typed.Actor)
		table.insert(parts, `not queued yet ({if customer ~= nil then customer.State else "gone"})`)
	else
		const elapsed = ctx.Now() - typed.QueuedAt
		table.insert(parts, string.format("queued %.1f s, taker %s", elapsed, if typed.Taker then typed.Taker.Name else "-"))
		if condition.Kind == "Hurry" then
			table.insert(parts, string.format("step %d/%d, %.1f s left", typed.Step, condition.Steps, condition.Seconds - elapsed))
		elseif condition.Kind == "NoLook" then
			table.insert(parts, string.format("cone %g deg, range %g", condition.Angle, condition.Range))
		elseif condition.Kind == "Plain" then
			table.insert(
				parts,
				string.format(
					"thrown %d/%d (-%g each, -%g the last)%s",
					typed.Returned,
					condition.Returns + 1,
					condition.ReturnSanity,
					condition.Sanity,
					if typed.Leaving then ", leaving" else ""
				)
			)
		end
	end
	table.insert(parts, string.format("pay x%g +$%d", condition.PayMult, condition.Bonus))
	return table.concat(parts, ", ")
end

-- NoLook as the server sees `player` now: would a serve right now be the error?
function Kit.DevLook(ctx: Api.Context, occ: Api.Occurrence, player: Player): string
	const state = occ.State
	if type(state) ~= "table" or type(state.Actor) ~= "number" then
		return `{occ.Ref}: no actor yet`
	end
	const condition = Kit.ConditionOf(ctx.Rule(occ.Key))
	const head = Kit.Position(state.Actor)
	if head == nil then
		return `{occ.Ref}: the rig is gone`
	end
	const looking = ctx.Looking(player, head, condition.Range, condition.Angle)
	return `{player.Name} {if looking then "LOOKS at her (a serve now = the error)" else "does not look (a serve now is safe)"}`
		.. string.format(" [cone %g deg, range %g; no fresh Gaze = not looking]", condition.Angle, condition.Range)
end

-- Hurry: `seconds` left from now (the clock moves, the steps follow on the next tick).
function Kit.DevHurry(ctx: Api.Context, occ: Api.Occurrence, seconds: number): string
	const state = occ.State
	if type(state) ~= "table" or state.Queued ~= true then
		return `{occ.Ref}: not in the queue`
	end
	const typed = state :: State
	const condition = Kit.ConditionOf(ctx.Rule(occ.Key))
	typed.QueuedAt = ctx.Now() - math.max(condition.Seconds - seconds, 0)
	typed.Step = 0
	mark(typed.Actor, STEP_ATTRIBUTE, 0)
	ctx.Publish(occ, { Step = 0 })
	return `{occ.Ref}: {seconds} s left of {condition.Seconds}`
end

return table.freeze(Kit)
