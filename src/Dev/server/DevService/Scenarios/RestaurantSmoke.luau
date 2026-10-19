--!strict
-- Restaurant smoke (R-6, docs/tests/restaurant-e2e.md; tech/restaurant-flow.md §5 R2): one customer end to end with
-- Content.Restaurant.Rules.Enabled, no UI. Called by Commands/Smoke.luau (`/dev smoke` with the switch on, or
-- `/dev smoke restaurant`). Every world action goes through InteractionService:Drain, the same server path as a
-- prompt (range, PromptEnabled, gates, the owner's Validate and Run): the player's character is moved next to each
-- anchor first. Steps, PASS / FAIL each (a FAIL skips the rest, they depend on it):
--   setup        day 2 (no tutorial), ordinary arrivals off, Prep -> Open, plates cleared, stock filled,
--                kitchen items of the player's hotbar removed
--   customer     DevSpawn, someone in Ordering at Q1 (30 s)
--   tablet       tablet_take on TAB-1 -> Talking -> the customer is Waiting (talk + 5 s)
--   cooking focus (kitchen-focus.md §1): the prompts open the focus; the gestures go through KitchenService.Cook.Act, the
--   same path as the Cook packet (reach, rate, station locks), with a fixed score of 90
--   plate        plate_take on the plate pile -> a plate Tool with Ticket = the customer
--   cut          cook_focus at the board, Cut -> Bun on the plate
--   grill        cook_focus at the grill, Place on slot 1 -> Flip in the window -> Ready -> Dog -> the hot_dog Tool, same Ticket
--   condiments   cook_focus at the table, Topping for every topping of the order
--   pickup       pickup_serve on PICKUP -> the customer is no longer Waiting (cash delta reported)
--   table        the customer sits (Dining) or takes it away (leaves) within 20 s
--   cleanup      arrivals back on, plates cleared, the character back where it was
-- Report: "RESTAURANT SMOKE: N/M PASS" then one line per step. Dev mode only; it changes the run state: throwaway Play.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Api = require(script.Parent.Parent.Api)
local Content = require(ReplicatedStorage.shared.Content)

export type Dev = (name: string, ...any) -> string

type Step = { Name: string, Run: () -> string? }

const ANCHOR_TAG = "Interactable"
const KITCHEN_ITEMS: { [string]: boolean } = { plate = true, hot_dog = true }
const SETTLE = 0.4
const LIFT = Vector3.new(0, 2.5, 0)

local function waitFor(predicate: () -> boolean, timeout: number): boolean
	const limit = os.clock() + timeout
	while os.clock() < limit do
		if predicate() then
			return true
		end
		task.wait(0.2)
	end
	return predicate()
end

local function positionOf(anchor: Instance): Vector3?
	if anchor:IsA("Attachment") then
		return anchor.WorldPosition
	elseif anchor:IsA("BasePart") then
		return anchor.Position
	elseif anchor:IsA("Model") then
		return anchor:GetPivot().Position
	end
	return nil
end

local function run(api: Api.Context, dev: Dev, caller: Player?): string
	const player = caller or Players:GetPlayers()[1]
	if player == nil then
		error("no player in the server (start Play with a client)", 0)
	end
	const interaction = api.Get("InteractionService")
	const kitchen = api.Get("KitchenService")
	const items = api.Get("ItemService")
	const tablets = api.Get("TabletService")
	const customers = api.Get("CustomerService")
	const round = api.Get("RoundService")
	const economy = api.Get("EconomyService")

	-- last rejection of an Interact sent by this smoke (InteractionService.Rejected)
	local rejected: string? = nil
	const connection = interaction.Rejected:Connect(function(who: Player, _id: number, action: string, reason: string)
		if who == player then
			rejected = `{action} -> {reason}`
		end
	end)

	local npc = 0
	local plateTool: Tool? = nil
	local hotDog: Tool? = nil
	local home: CFrame? = nil

	local function root(): BasePart
		const character = player.Character
		const part = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if part == nil or not part:IsA("BasePart") then
			error(`{player.Name} has no live character`, 0)
		end
		return part
	end

	-- Interactable anchors with this action in the Workspace; `filter` narrows (current vehicle, ingredient...)
	local function anchors(action: string, filter: ((anchor: Instance) -> boolean)?): { Instance }
		const out: { Instance } = {}
		for _, anchor in CollectionService:GetTagged(ANCHOR_TAG) do
			if anchor:IsDescendantOf(workspace) and anchor:GetAttribute("PromptAction") == action then
				if filter == nil or filter(anchor) then
					table.insert(out, anchor)
				end
			end
		end
		return out
	end

	local function current(anchor: Instance): boolean
		const station = kitchen:StationOf(anchor)
		return station ~= nil and station.Vehicle == kitchen:GetVehicle()
	end

	local function enabled(anchor: Instance): boolean
		return anchor:GetAttribute("PromptEnabled") ~= false
	end

	-- First live anchor of the action (enabled first), or an error naming the action
	local function pick(action: string, filter: ((anchor: Instance) -> boolean)?): Instance
		const list = anchors(action, filter)
		for _, anchor in list do
			if enabled(anchor) then
				return anchor
			end
		end
		if list[1] == nil then
			error(`no {action} anchor in the map`, 0)
		end
		return list[1]
	end

	-- The prompt, as a player would fire it: stand next to the anchor, then the server path of Interact
	local function act(anchor: Instance, action: string)
		const at = positionOf(anchor)
		if at == nil then
			error(`{action}: anchor {anchor:GetFullName()} has no position`, 0)
		end
		const id = interaction:IdOf(anchor)
		if id == nil then
			error(`{action}: anchor {anchor:GetFullName()} has no EntityId`, 0)
		end
		root().CFrame = CFrame.new(at + LIFT)
		task.wait(0.1)
		rejected = nil
		interaction:Drain(player, id, action)
		task.wait(SETTLE)
	end

	local function why(): string
		return if rejected then ` (rejected: {rejected})` else ""
	end

	local function toolOf(key: string): Tool?
		for _, tool in items:Tools(player) do
			if items:ItemOf(tool) == key then
				return tool
			end
		end
		return nil
	end

	local function equip(tool: Tool)
		const character = player.Character
		const humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid == nil then
			error("no Humanoid to equip the hot dog", 0)
		end
		humanoid:EquipTool(tool)
		task.wait(0.1)
	end

	-- the Prompt_Cook of a cooking focus station
	local function cookAnchor(station: string): Instance
		return pick("cook_focus", function(anchor: Instance): boolean
			return anchor:GetAttribute("Cook") == station
		end)
	end

	local function customerState(): string
		const customer = customers:Get(npc)
		return if customer then customer.State else "gone"
	end

	-- toppings of the first line of the order (ToppingKeys order)
	local function orderToppings(): { string }
		const customer = customers:Get(npc)
		const out: { string } = {}
		if customer == nil then
			return out
		end
		for _, key in Content.Ingredients.ToppingKeys do
			if customer.Order[key] then
				table.insert(out, key)
			end
		end
		return out
	end

	const steps: { Step } = {
		{
			Name = "setup",
			Run = function(): string?
				home = root().CFrame
				task.wait(0.5)
				dev("day", "2")
				task.wait(1)
				dev("customer", "off")
				-- "day 2" is Night 1 since DEC-300: Call (boss) then Night; skip until the shop takes customers
				for _ = 1, 3 do
					if economy:IsDrawerOpen() then
						break
					end
					dev("skip")
					task.wait(1)
				end
				if not economy:IsDrawerOpen() then
					error(`drawer closed in phase {round:GetPhase()} (needs Open)`, 0)
				end
				dev("plate", "clear")
				for _, tool in items:Tools(player) do
					const key = items:ItemOf(tool)
					if key ~= nil and KITCHEN_ITEMS[key] then
						items:Consume(player, tool)
					end
				end
				for _, key in { "bun", "sausage" } do
					const _, capacity = kitchen:GetStock(key)
					kitchen:SetAmount(key, math.max(capacity, 5))
				end
				for _, key in Content.Ingredients.ToppingKeys do
					if not kitchen:IsBlocked(key) then
						const _, capacity = kitchen:GetStock(key)
						kitchen:SetAmount(key, capacity)
					end
				end
				return `phase {round:GetPhase()}, day {round:GetDay()}, vehicle {kitchen:GetVehicle()}`
			end,
		},
		{
			Name = "customer",
			Run = function(): string?
				const outcome, id = customers:DevSpawn()
				const ok = waitFor(function(): boolean
					const front = customers:Front()
					const customer = if front then customers:Get(front) else nil
					if customer ~= nil and customer.State == "Ordering" then
						npc = front :: number
						return true
					end
					return false
				end, 30)
				if not ok then
					error(`spawn {outcome} {id or "-"}: nobody in Ordering at Q1 in 30 s`, 0)
				end
				return `customer {npc} at Q1 (spawn {outcome})`
			end,
		},
		{
			Name = "tablet",
			Run = function(): string?
				const tablet = tablets.Tablets[1]
				if tablet == nil or tablet.Anchor == nil then
					error("TAB-1 not bound", 0)
				end
				-- the customer may still be walking up at Q1: the tablet only takes an Ordering head, and its prompt turns on
				-- with TabletService's next Step (a tap before that is refused "state")
				const anchor = tablet.Anchor :: Instance
				waitFor(function(): boolean
					return customerState() == "Ordering" and anchor:GetAttribute("PromptEnabled") == true
				end, 10)
				act(anchor, "tablet_take")
				if tablet.State ~= "Talking" or tablet.Npc ~= npc then
					-- why the tablet refused, from the same checks (TabletService:Check / CustomerService:CanActOn)
					const ok, notice = tablets:Check(player, tablet)
					error(
						`tablet {tablet.State} with {tablet.Npc} after tablet_take{why()}; prompt {tostring(anchor:GetAttribute("PromptEnabled"))}, check {tostring(ok)} {notice or ""}, can act {tostring(customers:CanActOn(player, npc, "Ordering"))}, front {tostring(customers:Front())}, drawer {tostring(economy:IsDrawerOpen())}`,
						0
					)
				end
				const talk = tablet.EndsAt - tablet.StartedAt
				const waited1 = waitFor(function(): boolean
					return customerState() == "Waiting"
				end, talk + 5)
				if not waited1 then
					error(`customer {npc} is {customerState()} {string.format("%.1f", talk + 5)} s after the talk began`, 0)
				end
				const customer = customers:Get(npc)
				return string.format(
					"talk %.1f s; #%s; order [%s]",
					talk,
					tostring(if customer then customer.Number else nil),
					table.concat(orderToppings(), ",")
				)
			end,
		},
		{
			Name = "plate",
			Run = function(): string?
				act(pick("plate_take"), "plate_take")
				const tool = toolOf("plate")
				if tool == nil then
					error(`no plate after plate_take{why()}`, 0)
				end
				plateTool = tool
				if tool:GetAttribute("Ticket") ~= npc then
					error(`plate Ticket {tool:GetAttribute("Ticket")} (expected {npc}: the oldest ticket)`, 0)
				end
				return `plate {tool:GetAttribute("PlateId")} Ticket {npc}`
			end,
		},
		{
			Name = "cut",
			Run = function(): string?
				equip(plateTool :: Tool)
				act(cookAnchor("Board"), "cook_focus")
				kitchen.Cook.Act(player, { Act = "Cut", Slot = 0, Score = 90 })
				task.wait(0.2)
				if (plateTool :: Tool):GetAttribute("Bun") ~= true then
					error(`no Bun on the plate after Cut{why()}`, 0)
				end
				return "bun cut onto the plate"
			end,
		},
		{
			Name = "grill",
			Run = function(): string?
				equip(plateTool :: Tool)
				act(cookAnchor("Grill"), "cook_focus")
				const grill = kitchen.Cook.Target("Grill")
				const id = if grill then grill:GetAttribute("StationId") else nil
				const station = if type(id) == "number" then kitchen.Stations[id] else nil
				if station == nil then
					error("no grill station bound", 0)
				end
				-- the lowest free place (a sausage of an earlier run never burns and keeps its place); none free but one Ready:
				-- that one goes onto the plate
				local slot = 0
				local readySlot = 0
				const slots: { number } = {}
				for index in station.Records do
					table.insert(slots, index)
				end
				table.sort(slots)
				for _, index in slots do
					const value = station.Records[index]
					if slot == 0 and value.State == "Empty" then
						slot = index
					elseif readySlot == 0 and value.State == "Ready" then
						readySlot = index
					end
				end
				if slot == 0 and readySlot == 0 then
					error(`no free or ready place on the grill ({#slots} active)`, 0)
				end
				local record: any = nil
				local function state(value: any): string
					return if value ~= nil then tostring(value.State) else "none"
				end
				local function read(): any
					return station.Records[if slot ~= 0 then slot else readySlot]
				end
				local function isWorking(): boolean
					record = read()
					return state(record) == "Working"
				end
				if slot ~= 0 then
					const stock = kitchen:GetStock("sausage")
					kitchen.Cook.Act(player, { Act = "Place", Slot = slot, Score = 0 })
					if not waitFor(isWorking, 3) then
						error(`place {slot} is {state(read())} after Place (sausage stock {stock}){why()}`, 0)
					end
					const window = Content.Restaurant.Grill
					waitFor(function(): boolean
						const now = workspace:GetServerTimeNow()
						return (now - record.StartedAt) / record.Duration >= (window.FlipFrom + window.FlipTo) / 2
					end, 20)
					kitchen.Cook.Act(player, { Act = "Flip", Slot = slot, Score = 0 })
				end
				const used = if slot ~= 0 then slot else readySlot
				local function isReady(): boolean
					record = read()
					return state(record) == "Ready"
				end
				if not waitFor(isReady, 20) then
					error(`place {used} not Ready{why()}`, 0)
				end
				kitchen.Cook.Act(player, { Act = "Dog", Slot = used, Score = 90 })
				task.wait(0.3)
				const tool = toolOf("hot_dog")
				if tool == nil then
					error(`no hot_dog after Dog{why()}`, 0)
				end
				if tool:GetAttribute("Ticket") ~= npc then
					error(`hot_dog Ticket {tool:GetAttribute("Ticket")} (expected {npc})`, 0)
				end
				hotDog = tool
				return `hot_dog Ticket {npc}, Scores {tostring(tool:GetAttribute("Scores"))}, dish {tool:FindFirstChild("Dish") ~= nil}`
			end,
		},
		{
			Name = "condiments",
			Run = function(): string?
				const tool = hotDog :: Tool
				equip(tool)
				act(cookAnchor("Toppings"), "cook_focus")
				for _, key in orderToppings() do
					kitchen.Cook.Act(player, { Act = "Topping", Slot = 0, Score = 90, Key = key })
					task.wait(0.15)
					if table.find(items:Toppings(tool), key) == nil then
						error(`{key} not on the hot dog after Topping{why()}`, 0)
					end
				end
				return `[{table.concat(items:Toppings(tool), ",")}]`
			end,
		},
		{
			Name = "pickup",
			Run = function(): string?
				const binding = Content.Restaurant.Binding
				local anchor: Instance? = nil
				for _, model in CollectionService:GetTagged(binding.PickupTag) do
					if model:IsDescendantOf(workspace) then
						anchor = model:FindFirstChild(binding.PickupPrompt, true)
						if anchor ~= nil then
							break
						end
					end
				end
				if anchor == nil then
					error(`no {binding.PickupTag} {binding.PickupPrompt} in the map`, 0)
				end
				equip(hotDog :: Tool)
				const cash = economy:GetCash()
				act(anchor :: Instance, "pickup_serve")
				const waited4 = waitFor(function(): boolean
					return customerState() ~= "Waiting"
				end, 3)
				if not waited4 then
					error(`customer {npc} still Waiting after pickup_serve{why()}`, 0)
				end
				return `customer {npc} {customerState()}, cash {cash} -> {economy:GetCash()}`
			end,
		},
		{
			Name = "table",
			Run = function(): string?
				local how = ""
				const ok = waitFor(function(): boolean
					const customer = customers:Get(npc)
					if customer == nil then
						how = "gone (take-away)"
						return true
					elseif customer.Dining or customer.AtTable then
						how = "at a table"
						return true
					elseif customer.State == "Leaving" then
						how = "leaving (take-away: no free table)"
						return true
					end
					return false
				end, 20)
				if not ok then
					error(`customer {npc} is {customerState()} 20 s after the hand-over, neither seated nor leaving`, 0)
				end
				return `customer {npc} {how} (Seating.SitAt {Content.Seating.SitAt})`
			end,
		},
	}

	const lines: { string } = {}
	local passed = 0
	local failed = false
	for _, step in steps do
		if failed then
			table.insert(lines, `  SKIP {step.Name}`)
			continue
		end
		const ok, result = pcall(step.Run)
		if ok then
			passed += 1
			table.insert(lines, `  PASS {step.Name}: {result or ""}`)
		else
			failed = true
			table.insert(lines, `  FAIL {step.Name}: {tostring(result)}`)
		end
		api.Log(`[Smoke] restaurant {lines[#lines]}`)
	end

	-- cleanup: never counted, never fails the report
	connection:Disconnect()
	pcall(dev, "arrivals", "on")
	pcall(dev, "plate", "clear")
	if home ~= nil then
		pcall(function()
			root().CFrame = home :: CFrame
		end)
	end
	return `RESTAURANT SMOKE: {passed}/{#steps} PASS\n{table.concat(lines, "\n")}`
end

return table.freeze({ run = run })
