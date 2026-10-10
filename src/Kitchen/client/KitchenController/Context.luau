--!strict
-- Shared contract between KitchenController and its visual parts (Stock now; Grill, Rail, Board in TASK-030).
-- A part is a plain module: no Modux, no network. KitchenController calls `Mount` once per tagged `Station` whose
-- StationKind is in `Kinds`, inside a Vide root: effects and `Vide.cleanup` inside Mount live as long as the
-- station does. The part only reads the Context (reactive Vide sources fed by the Stock and Stations sets).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

-- network.md §3.4, one per ingredient (id = Content.Ingredients.IndexOf[key])
export type StockRecord = {
	Amount: number,
	Capacity: number,
	Blocked: boolean,
}

-- network.md §3.5, id = StationId * 100 + Slot
export type SlotRecord = {
	Kind: string,
	State: string, -- "Empty" | "Working" | "Ready"
	StartedAt: number,
	Duration: number,
	Count: number,
}

export type Context = {
	-- Reactive: reading inside a Vide effect re-runs it when the record changes. nil = no record yet.
	Stock: (ingredient: string) -> StockRecord?,
	Slot: (recordId: number) -> SlotRecord?,
}

export type Part = {
	Kinds: { [string]: boolean }, -- StationKind keys this part draws
	Mount: (station: Instance, context: Context) -> (),
}

const Context = {}

-- `potato_sticks` -> `PotatoSticks`: suffix of the named fittings (architecture.md §18.4, fixed rule).
function Context.Suffix(key: string): string
	const words = string.split(key, "_")
	for index, word in words do
		words[index] = string.upper(string.sub(word, 1, 1)) .. string.sub(word, 2)
	end
	return table.concat(words)
end

-- Named fitting, searched only inside the owner (architecture.md §18.3).
function Context.Find(owner: Instance, name: string): Instance?
	return owner:FindFirstChild(name, true)
end

function Context.FindPart(owner: Instance, name: string): BasePart?
	const found = owner:FindFirstChild(name, true)
	return if found and found:IsA("BasePart") then found else nil
end

-- "7/12"
function Context.CountText(record: StockRecord?): string
	return if record then `{record.Amount}/{record.Capacity}` else ""
end

-- FEAT-007: the counter turns red with <= 2 left.
const LOW_AMOUNT = 2

function Context.IsLow(record: StockRecord?): boolean
	return record ~= nil and not record.Blocked and record.Amount <= LOW_AMOUNT
end

-- Ingredient of a single-ingredient station: attribute on the Station, else the Stations table row.
function Context.StationIngredient(station: Instance): string?
	const attribute = station:GetAttribute("Ingredient")
	if typeof(attribute) == "string" and Content.Ingredients.ByKey[attribute] then
		return attribute
	end
	const kind = station:GetAttribute("StationKind")
	const row = if typeof(kind) == "string" then Content.Stations.ByKey[kind] else nil
	const ingredient = if row then row.Ingredient else nil
	return if ingredient and Content.Ingredients.ByKey[ingredient] then ingredient else nil
end

return table.freeze(Context)
