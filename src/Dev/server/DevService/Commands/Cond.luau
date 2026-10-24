--!strict
-- Conditions of the customer anomalies in the delivery queue (owner 2026-10-22, Provisional; design/anomalies-after-
-- accept-proposal.md §9; Anomaly/server/AnomalyService/Anomalies/Kit/CustomerActor). Through the real services: the
-- Anomalies set, the cues, the scene, the caption and the sale behave as in play.
--   cond                      the customer anomalies running: phase, condition, clock, taker, plates sent back
--   cond run <anomaly>        starts it now (as `trigger`, jumping to the Night phase) and takes its order for you the
--                             moment it reaches the counter (as the end of the talk, no talk): straight into the queue.
--                             Pilots: 014 (Hurry), 012 (NoLook), 011 (Plain)
--   cond take [anomaly]       takes the order of the anomaly standing at the counter for you now (the end of the talk)
--   cond look [anomaly]       NoLook: would your serve right now be the error? (the server's gaze of you, her head)
--   cond hurry <s> [anomaly]  Hurry: <s> seconds left on its clock (0 = the error on the next tick)
--   cond serve [toppings]     puts a hot dog with these toppings in your hand ("mustard", "mustard onion"; none / "plain"
--                             = plain) and serves it to the newest customer anomaly through the real path (ServeFor: its
--                             judge, the sale). Plain (011): a topping = the plate thrown at the wall, -15 the first time,
--                             -5 and he stomps off the second (Content.PlateThrow); plain = the right end
--   cond win [anomaly]        forces the right end (as a Complete serve: Resolved, the x PayMult, she leaves)
--   cond fail [anomaly]       forces the wrong end with you as who pays (NoLook / Hurry: the jumpscare; Plain: the last
--                             throw, -Sanity, he stomps off after the line)
-- [anomaly] = key, ANM-###, number or name; omitted = the newest customer anomaly running.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Parent.Kit)

const USAGE = "cond [run <anomaly> | take | look | hurry <s> | serve [toppings] | win | fail] [anomaly]"
const HOT_DOG = "hot_dog"
const PLAIN = "plain"
const RUN_WAIT = 90 -- s `cond run` waits for the actor to reach the counter
const RUN_POLL = 0.25

type Occurrence = { Id: number, Key: string, Ref: string, State: any }

type Anomalies = {
	Context: any,
	DevForce: (self: any, anomaly: string, example: boolean) -> string,
	DevRuns: (self: any) -> { { Id: number, Key: string, Ref: string, Phase: string, Step: number, Age: number } },
	DevOccurrence: (self: any, anomaly: string) -> any,
	DevEmit: (self: any, event: any) -> (),
}

type Customers = {
	Get: (self: any, id: number) -> { State: string }?,
	TakeOrderFor: (self: any, player: Player, id: number?) -> boolean,
	ServeFor: (self: any, player: Player, tool: Tool?, target: number) -> string?,
}

type Items = {
	Give: (self: any, player: Player, key: string, options: { Toppings: string?, Equip: boolean? }?) -> Tool?,
}

type ActorKit = {
	Describe: (ctx: any, occ: any) -> string,
	DevLook: (ctx: any, occ: any, player: Player) -> string,
	DevHurry: (ctx: any, occ: any, seconds: number) -> string,
	SendAway: (id: number, reason: string?) -> boolean,
	ConditionOf: (rule: any) -> { Kind: string },
}

local function isCustomer(key: string): boolean
	const row = Content.Anomalies.ByKey[key]
	return row ~= nil and row.Actor == "Customer"
end

local function actorOf(occ: Occurrence): number?
	const state = occ.State
	return if type(state) == "table" and type(state.Actor) == "number" and state.Actor ~= 0 then state.Actor else nil
end

const Cond: Api.Module = function(ctx: Api.Context): { Api.Command }
	const anomalies = ctx.Get("AnomalyService") :: Anomalies
	const customers = ctx.Get("CustomerService") :: Customers
	const items = ctx.Get("ItemService") :: Items
	const round = ctx.Get("RoundService")
	local actorKit: ActorKit? = nil

	local function kit(): ActorKit
		if actorKit == nil then
			actorKit = (require :: any)(ServerScriptService.server.Anomaly.AnomalyService.Anomalies.Kit.CustomerActor) :: ActorKit
		end
		return actorKit :: ActorKit
	end

	-- the occurrence named by `word` (a customer anomaly), or the newest customer anomaly running
	local function occurrence(word: string?): Occurrence
		if word ~= nil and word ~= "" then
			const key = Kit.anomaly(word)
			if not isCustomer(key) then
				error(`{key} is not a customer anomaly`, 0)
			end
			const found = anomalies:DevOccurrence(key)
			if found == nil then
				error(`{key} is not running ("cond run {word}")`, 0)
			end
			return found :: Occurrence
		end
		local newestKey: string? = nil
		local newestAge = math.huge
		for _, entry in anomalies:DevRuns() do
			if isCustomer(entry.Key) and entry.Age < newestAge then
				newestKey = entry.Key
				newestAge = entry.Age
			end
		end
		if newestKey == nil then
			error("no customer anomaly running (cond run <anomaly>)", 0)
		end
		return anomalies:DevOccurrence(newestKey) :: Occurrence
	end

	local function caller(player: Player?): Player
		if player == nil then
			error("run it from the chat (it acts as you)", 0)
		end
		return player
	end

	local function state(): string
		const lines: { string } = {}
		for _, entry in anomalies:DevRuns() do
			if isCustomer(entry.Key) then
				const occ = anomalies:DevOccurrence(entry.Key)
				if occ ~= nil then
					table.insert(lines, `#{entry.Id} {entry.Phase} step {entry.Step}: {kit().Describe(anomalies.Context, occ)}`)
				end
			end
		end
		return if #lines > 0 then table.concat(lines, "\n") else "no customer anomaly running (cond run <anomaly>)"
	end

	local function take(occ: Occurrence, player: Player): string
		const actor = actorOf(occ)
		if actor == nil then
			return `{occ.Ref}: no actor yet`
		end
		const customer = customers:Get(actor)
		if customer == nil or customer.State ~= "Ordering" then
			return `{occ.Ref} #{actor} is not at the counter ({if customer then customer.State else "gone"})`
		end
		if not customers:TakeOrderFor(player, actor) then
			return `{occ.Ref} #{actor}: TakeOrderFor refused (pickup line full? not at Q1?)`
		end
		return `{occ.Ref} #{actor}: order taken by {player.Name}, now in the queue`
	end

	-- the end of the condition as if a serve had been sold: Complete (right) or the condition broken by `player` (wrong)
	local function finish(occ: Occurrence, player: Player, right: boolean): string
		const actor = actorOf(occ)
		if actor == nil then
			return `{occ.Ref}: no actor yet`
		end
		if not right then
			occ.State.Broke = player
		end
		anomalies:DevEmit({
			Kind = "Customer",
			Npc = actor,
			Action = "serve",
			Player = player,
			Result = if right then "Complete" else "Wrong",
		})
		-- Plain's wrong end walks him off itself, after the throw and his line (Content.PlateThrow.LeaveDelay)
		const plain = kit().ConditionOf(anomalies.Context.Rule(occ.Key)).Kind == "Plain"
		if right or not plain then
			kit().SendAway(actor, nil)
		end
		return `{occ.Ref} #{actor}: forced the {if right then "right" else "wrong"} end`
	end

	-- a hot dog with `toppings` ("" = plain) in the hand of `player`, served to the actor through the real path (ServeFor:
	-- the condition's judge, then the sale; Plain's throw takes it away)
	local function serve(occ: Occurrence, player: Player, toppings: string): string
		const actor = actorOf(occ)
		if actor == nil then
			return `{occ.Ref}: no actor yet`
		end
		const tool = items:Give(player, HOT_DOG, { Toppings = toppings })
		if tool == nil then
			return "no room for a hot dog in your hands (Give refused)"
		end
		const result = customers:ServeFor(player, tool, actor)
		const shown = if toppings == "" then PLAIN else toppings
		return `{occ.Ref} #{actor}: served a {shown} hot dog -> {result or "no sale (thrown back, or not servable now: is its order taken?)"}`
	end

	local function run(args: { string }, player: Player?): string?
		const verb = if args[1] then string.lower(args[1]) else nil
		if verb == nil or verb == "state" then
			return state()
		elseif verb == "run" then
			const who = caller(player)
			if args[2] == nil then
				error(`usage: {USAGE}`, 0)
			end
			const key = Kit.anomaly(table.concat(args, " ", 2))
			if not isCustomer(key) then
				error(`{key} is not a customer anomaly`, 0)
			end
			const moved = Kit.toNight(round, nil)
			const started = anomalies:DevForce(key, false)
			task.spawn(function()
				const deadline = os.clock() + RUN_WAIT
				while os.clock() < deadline do
					task.wait(RUN_POLL)
					const occ = anomalies:DevOccurrence(key)
					const actor = if occ ~= nil then actorOf(occ :: Occurrence) else nil
					const customer = if actor ~= nil then customers:Get(actor) else nil
					if occ ~= nil and actor ~= nil and customer ~= nil and customer.State == "Ordering" then
						ctx.Log(`cond run: {take(occ :: Occurrence, who)}`)
						return
					end
				end
				ctx.Log(`cond run: {key} never reached the counter in {RUN_WAIT} s`)
			end)
			return `{if moved ~= "" then `{moved}: ` else ""}{started}; its order is taken for {who.Name} at the counter`
		elseif verb == "take" then
			return take(occurrence(args[2]), caller(player))
		elseif verb == "look" then
			return kit().DevLook(anomalies.Context, occurrence(args[2]), caller(player))
		elseif verb == "hurry" then
			const seconds = tonumber(args[2] or "")
			if seconds == nil or seconds < 0 then
				error(`usage: {USAGE}`, 0)
			end
			return kit().DevHurry(anomalies.Context, occurrence(args[3]), seconds)
		elseif verb == "serve" then
			const words: { string } = {}
			for index = 2, #args do
				const word = string.lower(args[index])
				if word ~= PLAIN then
					table.insert(words, word)
				end
			end
			return serve(occurrence(nil), caller(player), table.concat(words, ","))
		elseif verb == "win" or verb == "fail" then
			return finish(occurrence(args[2]), caller(player), verb == "win")
		end
		error(`usage: {USAGE}`, 0)
	end

	return {
		{
			Name = "cond",
			Usage = USAGE,
			Help = "Customer anomaly conditions in the delivery queue (014 Hurry, 012 NoLook, 011 Plain): run, take, look, hurry, serve, win, fail",
			Run = run,
		},
	}
end

return Cond
