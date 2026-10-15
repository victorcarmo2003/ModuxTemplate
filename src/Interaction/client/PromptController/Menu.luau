--!strict
-- Menu: the ordering / selection logic behind the InteractionMenu (user request 2026-10-12). Plain module, no
-- instances and no input: PromptController feeds it the in-view candidates every tick and reads back the stable list.
--   Order      stable list (max MAX_ITEMS). Priority tier first (customer service, then pick-ups, kitchen, shop, rest), then
--              distance; a row that is already listed never moves because a distance changed (new rows are inserted at
--              their sorted place, an HYSTERESIS margin in px keeps near-equal ones in arrival order)
--   Grace      a row whose prompt left the candidates stays GRACE seconds (dimmed, not usable), so nothing vanishes under
--              the cursor of the selection
--   Selected   always a current candidate (or nil). Sticky: moves only on navigation or when it stops being current
local StarterPlayer = game:GetService("StarterPlayer")
local Icons = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Icons)
local Prompt = require(script.Parent.Prompt)
local Rules = require(script.Parent.Rules)

export type State = {
	Order: { Prompt.Prompt },
	Current: { [Prompt.Prompt]: number }, -- distance of every prompt that is a candidate right now
	LastSeen: { [Prompt.Prompt]: number },
	Selected: Prompt.Prompt?,
}

const MAX_ITEMS = 4
const GRACE = 1.5
const DEFAULT_PRIORITY = 3
const DEFAULT_ICON = "Ui/sparkle"

-- Lower = higher in the list. Presentation only; Content.Actions keeps the gameplay data.
const PRIORITY: { [string]: number } = {
	take_order = 1,
	serve = 1,
	serve_table = 1,
	collect_tips = 2,
	refuse = 2,
	pick_up_item = 2,
	grill_collect = 3,
	grill_place = 3,
	bun_cut = 3,
	board_add_sausage = 3,
	topping_add = 3,
	restock = 3,
	brew_coffee = 3,
	give_coffee = 3,
	answer_phone = 3,
	buy_package = 4,
	bench_buy_upgrade = 4,
	bench_buy_item = 4,
	buy_in_place = 4,
	clean_table = 4,
	switch_light = 5,
	shutter_toggle = 5,
	trailer_enter = 5,
	trailer_exit = 5,
	safe_spot = 5,
	discard = 6,
}

const ICONS: { [string]: string } = {
	take_order = "Ui/megaphone",
	serve = "Item/hot_dog",
	serve_table = "Item/hot_dog",
	refuse = "Ui/close",
	collect_tips = "Ui/cash",
	grill_place = "Item/hot_dog",
	grill_collect = "Item/hot_dog",
	bun_cut = "Ingredient/bun",
	board_add_sausage = "Ingredient/sausage",
	discard = "Ui/close",
	restock = "Item/pack_buns",
	buy_package = "Ui/cash",
	bench_buy_upgrade = "Ui/cash",
	bench_buy_item = "Ui/cash",
	buy_in_place = "Ui/cash",
	pick_up_item = "Reaction/star",
	brew_coffee = "Item/coffee",
	give_coffee = "Item/coffee",
	switch_light = "Ui/lantern",
	answer_phone = "Hud/phone",
	shutter_toggle = "Ui/lantern",
	trailer_enter = "Notice/trailer",
	trailer_exit = "Notice/trailer",
	clean_table = "Ui/sparkle",
}

const Menu = {}

function Menu.new(): State
	return { Order = {}, Current = {}, LastSeen = {}, Selected = nil }
end

function Menu.PriorityOf(action: string): number
	return PRIORITY[action] or DEFAULT_PRIORITY
end

-- Icon name of an action target; "" when the sheet has none
function Menu.IconOf(target: Rules.Target): string
	const ingredient = target.Ingredient
	if target.Action == "topping_add" and ingredient ~= nil then
		const name = `Ingredient/{ingredient}`
		if Icons.Has(name) then
			return name
		end
	end
	const name = ICONS[target.Action] or DEFAULT_ICON
	return if Icons.Has(name) then name else ""
end

-- Short label of the touch fan ("Serve", "Ketchup", "Collect"): one word where the sheet allows it. `text` is the live
-- prompt text (it may carry the ingredient, the price or a server override such as "Take Coffee").
const SHORT: { [string]: string } = {
	take_order = "Order",
	serve = "Serve",
	serve_table = "Serve",
	refuse = "Refuse",
	collect_tips = "Collect",
	grill_place = "Grill",
	grill_collect = "Collect",
	bun_cut = "Slice",
	board_add_sausage = "Sausage",
	discard = "Trash",
	restock = "Restock",
	pick_up_item = "Take",
	brew_coffee = "Brew",
	switch_light = "Lights",
	answer_phone = "Answer",
	safe_spot = "Hide",
	shutter_toggle = "Window",
	trailer_enter = "Enter",
	trailer_exit = "Exit",
	clean_table = "Clean",
}

function Menu.ShortOf(target: Rules.Target, text: string): string
	const action = target.Action
	if action == "topping_add" then
		const topping = string.gsub(text, "^Add ", "")
		return topping
	elseif string.sub(action, 1, 3) == "buy" then
		const price = string.match(text, "%$%d+")
		return if price then `Buy {price}` else "Buy"
	end
	return SHORT[action] or text
end

local function priorityOf(prompt: Prompt.Prompt): number
	return Menu.PriorityOf(prompt.Target.Action)
end

-- Insertion index of `prompt` among the listed rows: before the first row that ranks lower.
local function slotFor(state: State, prompt: Prompt.Prompt, margin: number): number
	const mine = priorityOf(prompt)
	const distance = state.Current[prompt] or math.huge
	for index, other in state.Order do
		const theirs = priorityOf(other)
		const otherDistance = state.Current[other]
		if mine < theirs then
			return index
		elseif mine == theirs and (otherDistance == nil or distance + margin < otherDistance) then
			return index
		end
	end
	return #state.Order + 1
end

local function firstCurrent(state: State): Prompt.Prompt?
	for _, prompt in state.Order do
		if state.Current[prompt] ~= nil then
			return prompt
		end
	end
	return nil
end

-- Drops the row that is last, not selected, preferring one that is not current.
local function trim(state: State)
	while #state.Order > MAX_ITEMS do
		local victim: number? = nil
		for index = #state.Order, 1, -1 do
			const prompt = state.Order[index]
			if prompt ~= state.Selected then
				if state.Current[prompt] == nil then
					victim = index
					break
				elseif victim == nil then
					victim = index
				end
			end
		end
		table.remove(state.Order, victim or #state.Order)
	end
end

-- One tick. `candidates` = prompt -> screen distance of the ones in view. `frozen` (a hold is running): no row is
-- added, dropped or reordered. Returns true when the list or the selection changed.
function Menu.Update(
	state: State,
	candidates: { [Prompt.Prompt]: number },
	now: number,
	frozen: boolean,
	margin: number
): boolean
	local changed = false
	state.Current = candidates
	for prompt in candidates do
		state.LastSeen[prompt] = now
	end

	if not frozen then
		local index = 1
		while index <= #state.Order do
			const prompt = state.Order[index]
			if candidates[prompt] == nil and now - (state.LastSeen[prompt] or 0) > GRACE then
				table.remove(state.Order, index)
				state.LastSeen[prompt] = nil
				changed = true
			else
				index += 1
			end
		end

		-- New rows, nearest first, so equal tiers come out ordered by distance
		const fresh: { Prompt.Prompt } = {}
		for prompt in candidates do
			if table.find(state.Order, prompt) == nil then
				table.insert(fresh, prompt)
			end
		end
		table.sort(fresh, function(a, b)
			const pa, pb = priorityOf(a), priorityOf(b)
			if pa ~= pb then
				return pa < pb
			end
			return (candidates[a] or 0) < (candidates[b] or 0)
		end)
		for _, prompt in fresh do
			table.insert(state.Order, slotFor(state, prompt, margin), prompt)
			changed = true
		end
		trim(state)
	end

	const selected = state.Selected
	if selected == nil or candidates[selected] == nil or table.find(state.Order, selected) == nil then
		const next = firstCurrent(state)
		if next ~= selected then
			state.Selected = next
			changed = true
		end
	end
	return changed
end

-- Number of rows that are candidates right now
function Menu.CurrentCount(state: State): number
	local total = 0
	for _, prompt in state.Order do
		if state.Current[prompt] ~= nil then
			total += 1
		end
	end
	return total
end

-- Wrap-around step through the current rows. Returns true when the selection moved.
function Menu.Move(state: State, delta: number): boolean
	const usable: { Prompt.Prompt } = {}
	for _, prompt in state.Order do
		if state.Current[prompt] ~= nil then
			table.insert(usable, prompt)
		end
	end
	if #usable < 2 then
		return false
	end
	const at = if state.Selected then table.find(usable, state.Selected) or 1 else 1
	const target = usable[(at - 1 + delta) % #usable + 1]
	if target == state.Selected then
		return false
	end
	state.Selected = target
	return true
end

-- Selects a row by prompt; false when it is not a current row.
function Menu.Select(state: State, prompt: Prompt.Prompt): boolean
	if state.Current[prompt] == nil or table.find(state.Order, prompt) == nil then
		return false
	end
	state.Selected = prompt
	return true
end

function Menu.Forget(state: State, prompt: Prompt.Prompt): boolean
	const index = table.find(state.Order, prompt)
	state.LastSeen[prompt] = nil
	state.Current[prompt] = nil
	if state.Selected == prompt then
		state.Selected = nil
	end
	if index then
		table.remove(state.Order, index)
		return true
	end
	return false
end

function Menu.Clear(state: State)
	table.clear(state.Order)
	table.clear(state.LastSeen)
	state.Current = {}
	state.Selected = nil
end

return table.freeze(Menu)
