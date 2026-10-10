--!strict
-- Local pre-check of a prompt, for presentation only (architecture.md §18.3, network.md §3.4-§3.6 and §4.1).
-- PromptEnabled is the party-wide state written by the server; this adds what only this client knows (the Tool in
-- hand) and what the sets already show (stock, slot, customer state). The server revalidates every Interact.
-- Rule of doubt: when a record is missing, the prompt stays (the server decides); only known facts hide it.
-- Pure: no Modux, Lync or Vide. The controller passes the lookups in.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

-- First wave whose prompts are live (Content.Actions[...].Wave). Later-wave keys exist in the table already.
const ACTIVE_WAVE = 1

export type Held = {
	Item: string,
	Toppings: { [string]: boolean },
}

export type StockRecord = { Amount: number, Capacity: number, Blocked: boolean }
export type SlotRecord = { State: string }
export type CustomerRecord = { State: string }

export type Context = {
	Phase: string,
	IsNight: boolean,
	Held: Held?,
	Stock: (ingredient: string) -> StockRecord?,
	Slot: (stationId: number, slot: number) -> SlotRecord?,
	Customer: (npcId: number) -> CustomerRecord?,
}

-- What the rules read from the anchor (Prompt keeps these fresh from attributes).
export type Target = {
	Action: string,
	Ingredient: string?, -- anchor's Ingredient, else its Station's
	StationId: number?,
	Slot: number?,
	NpcId: number?,
}

-- Package item key -> ingredient it restocks.
const packageIngredient: { [string]: string } = {}
for _, package in Content.Packages.List do
	packageIngredient[package.Item] = package.Ingredient
end

const Rules = {}

-- Requires.Held is an Items key ("hot_dog") or an ItemRules category ("Package").
function Rules.Holds(held: Held?, required: string): boolean
	if held == nil then
		return false
	elseif held.Item == required then
		return true
	end
	const item = Content.Items.ByKey[held.Item]
	return item ~= nil and item.Category == required
end

-- "ketchup,cheese" -> set
function Rules.ParseToppings(value: string?): { [string]: boolean }
	const out: { [string]: boolean } = {}
	if value then
		for _, key in string.split(value, ",") do
			if key ~= "" then
				out[key] = true
			end
		end
	end
	return out
end

function Rules.Allows(target: Target, context: Context): boolean
	const action = Content.Actions.ByKey[target.Action]
	if action == nil or action.Wave > ACTIVE_WAVE then
		return false
	end

	if action.Night == "DayOnly" and context.IsNight then
		return false
	elseif action.Night == "NightOnly" and not context.IsNight then
		return false
	end

	const requires = action.Requires
	const phases = requires.Phase
	if phases and not table.find(phases, context.Phase) then
		return false
	end

	const held = context.Held
	if requires.Held and not Rules.Holds(held, requires.Held) then
		return false
	end

	const ingredient = target.Ingredient
	if requires.NotHasTopping and held and ingredient and held.Toppings[ingredient] then
		return false
	end

	-- Restock needs the package of this station's ingredient (content-data.md §3.18).
	if target.Action == "restock" and held and ingredient then
		const restocks = packageIngredient[held.Item]
		if restocks ~= ingredient then
			return false
		end
	end

	-- network.md §3.4 (L-02): "Add X" hides with Amount = 0 or Blocked; "Restock" hides with Amount = Capacity or
	-- Blocked, never with Amount = 0 (an empty bowl is exactly when you restock).
	if ingredient and (target.Action == "topping_add" or target.Action == "restock") then
		const stock = context.Stock(ingredient)
		if stock then
			if stock.Blocked then
				return false
			elseif target.Action == "topping_add" and stock.Amount <= 0 then
				return false
			elseif target.Action == "restock" and stock.Amount >= stock.Capacity then
				return false
			end
		end
	end

	-- network.md §3.5: "Collect" only on a Ready slot.
	if target.Action == "grill_collect" and target.StationId and target.Slot then
		const slot = context.Slot(target.StationId, target.Slot)
		if slot and slot.State ~= "Ready" then
			return false
		end
	end

	-- network.md §3.6: "Take Order" only while Ordering, "Serve" only while Waiting.
	if target.NpcId and (target.Action == "take_order" or target.Action == "serve") then
		const customer = context.Customer(target.NpcId)
		if customer then
			const wanted = if target.Action == "take_order" then "Ordering" else "Waiting"
			if customer.State ~= wanted then
				return false
			end
		end
	end

	return true
end

return table.freeze(Rules)
