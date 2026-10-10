--!strict
-- ANM-002 "The wrong food" (docs/story/anomalies.md N2; design/npcs.md NPC-010, ITM-020; architecture.md §19.13;
-- FEAT-023, FEAT-024; DEC-051, DEC-054, DEC-195, DEC-204; TASK-113). Contract: ../Api.luau. Rule: Rules/ANM-002.luau.
--
--   Start   KitchenService:Alter on a kind of Params.Kinds (random order from occ.Rng): gray sausage at the front of
--           the rail or bitten bun on a board slot. Both refused -> false (the agenda retries). Phase Active.
--   Verb    KitchenService.Discarded with Altered (the item, or the hot dog made with it; BIN-C or street bin) ->
--           Resolved.
--   Error   CustomerService serve rule: a hot dog with the Altered attribute is served -> "Wrong" (no payment,
--           Settle counts it), the hot dog is consumed (it turns to smoke in the customer's hand), cue smoke on the
--           customer's NpcId, Fail of who served (DEC-204). The rule is registered once and stays: an altered hot dog
--           outliving its occurrence still serves Wrong (no Fail, no cue: there is no occurrence to pay for).
--   Omission not an error: the item stays until used or discarded; KitchenService/ItemService clear it at 6:00 AM.
--   Lost    the item is gone with no discard and no serve (dropped on a car hit, FEAT-036) -> closes with no success
--           and no failure after Params.LostGrace s.
--   Seen    1 s in the gaze cone of the station holding it, or of the hot dog in someone's hand (ViewRange of the row).
--   Stop    Restore (night lost, dev stop, new shift) with no other ANM-002 left: KitchenService and ItemService
--           ClearAltered. NightOver: they clear by themselves when the phase leaves Night.
--
-- Several occurrences can be alive at once (3 on the debut night): the altered items carry no occurrence id, so each
-- resolution goes to the oldest live occurrence (FIFO). One hot dog made with both the gray sausage and the bitten
-- bun ends two occurrences: discard resolves both; serving fails only the oldest (one penalty per hot dog), the other
-- just ends.
--
-- PROVISIONAL (backend-coder, TASK-113): Api.Context has no serve rule, item reads or ClearAltered, so this module
-- reaches CustomerService, KitchenService, ItemService and RunStateService (all in the AnomalyService Require) by
-- requiring their ModuleScripts at Start; the architect may move those into the Context. An altered item dropped on
-- the counter from a spectator's stash (Drops, DROP-T) is not counted as present.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)

const REF = "ANM-002"
const HOT_DOG = "hot_dog"
const ALTERED = "Altered" -- Tool attribute written by ItemService (network.md §7.1)
const ALTERED_MARK = "!" -- stash Extra prefix of an altered hot dog (ItemService/Stash.luau)
const TICK_DT = 0.2 -- s between two Ticks (AnomalyService runs Tick at 5 Hz)

type Kind = "rail" | "board"

type State = {
	Kind: Kind,
	ViewRange: number,
	LostGrace: number,
	LastTick: number,
}

type Live = { Ctx: Api.Context, Occ: Api.Occurrence }

type Station = { Kind: string, Instance: Model, Records: { [number]: { [string]: any } } }

type Kitchen = {
	CurrentStation: (self: any, kind: string) -> Station?,
	ClearAltered: (self: any) -> number,
}

type Items = {
	ByPlayer: { [Player]: { [Tool]: boolean } },
	IsAltered: (self: any, tool: Tool) -> boolean,
	InPlay: (self: any, tool: Tool, player: Player) -> boolean,
	Consume: (self: any, player: Player, tool: Tool) -> (),
	ClearAltered: (self: any) -> number,
}

type RunState = {
	Members: () -> { [number]: { Stash: { { Kind: string, Count: number, Extra: string? } } } },
}

type Customers = {
	AddServeRule: (self: any, rule: (customer: { Id: number }, tool: Tool, player: Player) -> string?) -> () -> (),
}

type Services = { Kitchen: Kitchen, Items: Items, RunState: RunState, Customers: Customers }

-- Live occurrences, oldest first (StartedAt order)
const live: { Live } = {}
-- Events already given to an occurrence (OnEvent runs for every live occurrence; one item = one resolution)
const claimed: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
-- Since when fewer altered items than live occurrences exist (nil = none missing)
local missingSince: number? = nil
local services: Services? = nil
local ruleRegistered = false

-- The services this module reads (PROVISIONAL, see header). Required lazily: AnomalyService Requires all four, so they
-- are initialized before any occurrence starts.
local function getServices(): Services
	const cached = services
	if cached ~= nil then
		return cached
	end
	const server: any = ServerScriptService:WaitForChild("server")
	const found: Services = {
		Kitchen = (require :: any)(server.Kitchen.KitchenService) :: Kitchen,
		Items = (require :: any)(server.Item.ItemService) :: Items,
		RunState = (require :: any)(server.Run.RunStateService) :: RunState,
		Customers = (require :: any)(server.Customer.CustomerService) :: Customers,
	}
	services = found
	return found
end

local function indexOf(occ: Api.Occurrence): number?
	for index, entry in live do
		if entry.Occ == occ then
			return index
		end
	end
	return nil
end

local function oldest(): Live?
	return live[1]
end

local function stationCount(kitchen: Kitchen, kind: Kind): (number, Station?)
	const station = kitchen:CurrentStation(kind)
	if station == nil then
		return 0, nil
	end
	local count = 0
	for _, record in station.Records do
		const altered = record.Altered
		if type(altered) == "number" and altered >= 1 then
			count += 1
		end
	end
	return count, station
end

-- Altered items still in the game: on the current vehicle's rail and board, Tools in play, member stashes.
local function presence(): number
	const s = getServices()
	const rail = stationCount(s.Kitchen, "rail")
	const board = stationCount(s.Kitchen, "board")
	local count = rail + board
	for player, owned in s.Items.ByPlayer do
		for tool in owned do
			if s.Items:IsAltered(tool) and s.Items:InPlay(tool, player) then
				count += 1
			end
		end
	end
	for _, member in s.RunState.Members() do
		for _, entry in member.Stash do
			const extra = entry.Extra
			if entry.Kind == HOT_DOG and extra ~= nil and string.sub(extra, 1, #ALTERED_MARK) == ALTERED_MARK then
				count += 1
			end
		end
	end
	return count
end

-- Where to look for the "seen" cone: the station holding an altered item (own kind first), else a hot dog in hand.
local function target(kind: Kind): Vector3?
	const s = getServices()
	const other: Kind = if kind == "rail" then "board" else "rail"
	for _, k in { kind, other } do
		const count, station = stationCount(s.Kitchen, k)
		if count > 0 and station ~= nil then
			return station.Instance:GetPivot().Position
		end
	end
	for player, owned in s.Items.ByPlayer do
		const character = player.Character
		for tool in owned do
			if tool.Parent == character and character ~= nil and s.Items:IsAltered(tool) then
				const handle = tool:FindFirstChild("Handle")
				if handle ~= nil and handle:IsA("BasePart") then
					return handle.Position
				end
			end
		end
	end
	return nil
end

-- Ends `count` live occurrences, oldest first. outcome: "solved" (all Succeed), "served" (first: smoke + Fail of
-- who served; the rest just end), "lost" (no success, no failure).
local function resolve(count: number, outcome: "solved" | "served" | "lost", player: Player?, npcId: number?)
	const doomed: { Live } = {}
	for index = 1, math.min(count, #live) do
		table.insert(doomed, live[index])
	end
	for index, entry in doomed do
		const ctx, occ = entry.Ctx, entry.Occ
		if outcome == "solved" then
			ctx.Succeed(occ)
		elseif outcome == "served" and index == 1 then
			ctx.Cue(occ, "smoke", npcId or 0)
			if player ~= nil then
				ctx.Fail(occ, { player })
			end
		elseif outcome == "lost" then
			ctx.Log(occ, "altered item gone without discard or serve: closed with no result")
		end
		ctx.Finish(occ)
	end
end

-- How many occurrences an item that just left ends: those with no altered item left, at least one.
local function ending(): number
	return math.max(1, #live - presence())
end

-- Serve of an altered hot dog (after the serve rule returned Wrong, outside the serve flow).
local function onAlteredServe(player: Player, tool: Tool, npcId: number)
	const s = getServices()
	if s.Items:InPlay(tool, player) then
		-- the hot dog turns to smoke in the customer's hand (DEC-195): it leaves the server's hand
		s.Items:Consume(player, tool)
	end
	if #live == 0 then
		return
	end
	resolve(ending(), "served", player, npcId)
end

local function registerServeRule()
	if ruleRegistered then
		return
	end
	ruleRegistered = true
	getServices().Customers:AddServeRule(function(customer: { Id: number }, tool: Tool, player: Player): string?
		if tool:GetAttribute(ALTERED) ~= true then
			return nil
		end
		const npcId = customer.Id
		task.defer(onAlteredServe, player, tool, npcId)
		return "Wrong"
	end)
end

const WrongFood: Api.Module = {
	Ref = REF,

	Start = function(ctx: Api.Context, occ: Api.Occurrence): boolean
		const rule = ctx.Rule(occ.Key)
		if rule == nil then
			-- Rules/ANM-002 missing or broken (warned at boot)
			return false
		end
		const kinds: { Kind } = {}
		const listed = rule.Params.Kinds
		if type(listed) == "table" then
			for _, kind in listed do
				if kind == "rail" or kind == "board" then
					table.insert(kinds, kind)
				end
			end
		end
		if #kinds == 0 then
			return false
		end
		-- random first kind, the other as fallback (one draw per attempt: same run = same draws)
		const first = occ.Rng:NextInteger(1, #kinds)
		local placed: Kind? = nil
		for offset = 0, #kinds - 1 do
			const kind = kinds[(first - 1 + offset) % #kinds + 1]
			if ctx.Kitchen.Alter(kind) then
				placed = kind
				break
			end
		end
		if placed == nil then
			return false
		end
		registerServeRule()
		const row = Content.Anomalies.ByKey[occ.Key]
		const grace = rule.Params.LostGrace
		const state: State = {
			Kind = placed,
			ViewRange = if row ~= nil then row.ViewRange else 0,
			LostGrace = if type(grace) == "number" then grace else 0,
			LastTick = occ.StartedAt,
		}
		occ.State = state
		table.insert(live, { Ctx = ctx, Occ = occ })
		ctx.Publish(occ, { Phase = "Active", Step = 0, Anchor = 0 })
		return true
	end,

	Tick = function(ctx: Api.Context, occ: Api.Occurrence, now: number)
		const state = occ.State :: State
		const dt = math.clamp(now - state.LastTick, 0, TICK_DT * 2)
		state.LastTick = now
		const position = target(state.Kind)
		if position ~= nil and state.ViewRange > 0 then
			ctx.SeenTick(occ, position, state.ViewRange, dt)
		end
		-- the shared "lost" check runs once per tick, on the oldest occurrence
		const first = oldest()
		if first == nil or first.Occ ~= occ then
			return
		end
		const missing = #live - presence()
		if missing <= 0 then
			missingSince = nil
			return
		end
		const since = missingSince
		if since == nil then
			missingSince = now
		elseif now - since >= state.LostGrace then
			missingSince = nil
			resolve(missing, "lost", nil, nil)
		end
	end,

	OnEvent = function(_ctx: Api.Context, _occ: Api.Occurrence, event: Api.Event)
		if event.Kind ~= "Discard" or not event.Altered or claimed[event] then
			return
		end
		claimed[event] = true
		resolve(ending(), "solved", nil, nil)
	end,

	Stop = function(_ctx: Api.Context, occ: Api.Occurrence, reason: Api.StopReason)
		const index = indexOf(occ)
		if index ~= nil then
			table.remove(live, index)
		end
		if #live == 0 then
			missingSince = nil
		end
		if reason == "Restore" and #live == 0 then
			const s = getServices()
			s.Kitchen:ClearAltered()
			s.Items:ClearAltered()
		end
	end,
}

return WrongFood
