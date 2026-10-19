--!strict
-- Restaurant smoke (R-6, docs/tests/restaurant-e2e.md; tech/restaurant-flow.md §5 R2): one customer end to end with
-- Content.Restaurant.Rules.Enabled, no UI. Called by Commands/Smoke.luau (`/dev smoke` with the switch on, or
-- `/dev smoke restaurant`). Every world action goes through InteractionService:Drain, the same server path as a
-- prompt (range, PromptEnabled, gates, the owner's Validate and Run): the player's character is moved next to each
-- anchor first. Steps, PASS / FAIL each (a FAIL skips the rest, they depend on it):
--   setup        day 2 (no tutorial), ordinary arrivals off, Prep -> Open, plates cleared, stock filled,
--                kitchen items of the player's hotbar removed
--   customer     DevSpawn, someone in Ordering at Q1 (30 s)
--   tablet       tablet_take on TAB-1 -> Talking -> the customer is Waiting with a ticket on a plate (talk + 5 s)
--   cut          bun_slice on a CUT-n -> bun_sliced in the hotbar
--   plate bun    plate_put on the ticket's plate -> Bun
--   grill        grill_place -> Flip on (pause) -> grill_flip -> Collect on -> grill_collect -> rail +1
--   rail         rail_take -> sausage_grilled in the hotbar
--   plate dog    plate_put -> Sausage; plate_take -> hot_dog with Ticket = the customer
--   condiments   topping_add for every topping of the order (hot dog equipped)
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
const KITCHEN_ITEMS: { [string]: boolean } = { bun_sliced = true, sausage_grilled = true, hot_dog = true }
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
	const plates = api.Get("PlateService")
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
	local plateIndex = 0
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

	local function plate(): any
		const slot = plates.Slots[plateIndex]
		if slot == nil then
			error(`PLATE-{plateIndex} is not bound`, 0)
		end
		return slot
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
				if round:GetPhase() == "Prep" then
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
				act(tablet.Anchor, "tablet_take")
				if tablet.State ~= "Talking" or tablet.Npc ~= npc then
					error(`tablet {tablet.State} with {tablet.Npc} after tablet_take{why()}`, 0)
				end
				const talk = tablet.EndsAt - tablet.StartedAt
				const waited1 = waitFor(function(): boolean
					return customerState() == "Waiting"
				end, talk + 5)
				if not waited1 then
					error(`customer {npc} is {customerState()} {string.format("%.1f", talk + 5)} s after the talk began`, 0)
				end
				const slots = plates:SlotsOf(npc)
				if slots[1] == nil then
					error(`customer {npc} Waiting but no plate holds its ticket`, 0)
				end
				plateIndex = slots[1].Index
				const customer = customers:Get(npc)
				return string.format(
					"talk %.1f s; #%s on PLATE-%d; order [%s]",
					talk,
					tostring(if customer then customer.Number else nil),
					plateIndex,
					table.concat(orderToppings(), ",")
				)
			end,
		},
		{
			Name = "cut",
			Run = function(): string?
				act(pick("bun_slice", current), "bun_slice")
				const tool = toolOf("bun_sliced")
				if tool == nil then
					error(`no bun_sliced in the hotbar after bun_slice{why()}`, 0)
				end
				return `bun_sliced x{items:Count(tool)}`
			end,
		},
		{
			Name = "plate bun",
			Run = function(): string?
				act(plates.PutAnchors[plateIndex], "plate_put")
				if not plate().Bun then
					error(`PLATE-{plateIndex} has no bun after plate_put{why()}`, 0)
				end
				return `PLATE-{plateIndex} bun`
			end,
		},
		{
			Name = "grill",
			Run = function(): string?
				const rail = kitchen:RailCount()
				act(pick("grill_place", current), "grill_place")
				local flip: Instance? = nil
				const waited2 = waitFor(function(): boolean
					for _, anchor in anchors("grill_flip", current) do
						if anchor:GetAttribute("PromptEnabled") == true then
							flip = anchor
							return true
						end
					end
					return false
				end, 30)
				if not waited2 then
					error(`no Flip prompt on in 30 s after grill_place{why()}`, 0)
				end
				act(flip :: Instance, "grill_flip")
				local collect: Instance? = nil
				const waited3 = waitFor(function(): boolean
					for _, anchor in anchors("grill_collect", current) do
						if anchor:GetAttribute("PromptEnabled") == true then
							collect = anchor
							return true
						end
					end
					return false
				end, 10)
				if not waited3 then
					error(`no Collect prompt on in 10 s after grill_flip{why()}`, 0)
				end
				act(collect :: Instance, "grill_collect")
				if kitchen:RailCount() <= rail then
					error(`rail {kitchen:RailCount()} after grill_collect (was {rail}){why()}`, 0)
				end
				return `rail {rail} -> {kitchen:RailCount()}`
			end,
		},
		{
			Name = "rail",
			Run = function(): string?
				act(pick("rail_take", current), "rail_take")
				const tool = toolOf("sausage_grilled")
				if tool == nil then
					error(`no sausage_grilled in the hotbar after rail_take{why()}`, 0)
				end
				return `sausage_grilled x{items:Count(tool)}`
			end,
		},
		{
			Name = "plate dog",
			Run = function(): string?
				act(plates.PutAnchors[plateIndex], "plate_put")
				if not plate().Sausage then
					error(`PLATE-{plateIndex} has no sausage after plate_put{why()}`, 0)
				end
				act(plates.TakeAnchors[plateIndex], "plate_take")
				const tool = toolOf("hot_dog")
				if tool == nil then
					error(`no hot_dog after plate_take{why()}`, 0)
				end
				if tool:GetAttribute("Ticket") ~= npc then
					error(`hot_dog Ticket {tool:GetAttribute("Ticket")} (expected {npc})`, 0)
				end
				hotDog = tool
				return `hot_dog Ticket {npc}`
			end,
		},
		{
			Name = "condiments",
			Run = function(): string?
				const tool = hotDog :: Tool
				const wanted = orderToppings()
				for _, key in wanted do
					equip(tool)
					act(pick("topping_add", function(anchor: Instance): boolean
						return current(anchor) and anchor:GetAttribute("Ingredient") == key
					end), "topping_add")
					if table.find(items:Toppings(tool), key) == nil then
						error(`{key} not on the hot dog after topping_add{why()}`, 0)
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
