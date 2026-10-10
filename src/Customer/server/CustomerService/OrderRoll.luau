--!strict
-- Order draw (FEAT-010; DEC-071; content-data.md §3.16; board TASK-033 v1.1, R3). Pure: requires only Content, no
-- state, no Service, no network, no global math.random. Same Random state in = same order out.
--
--   1. K from the OrderPhases row of the day (KWeights = chance of K = 0, 1, 2, 3).
--   2. Customer type shift: with CustomerTypes[t].KShift.Chance, K += KShift.Delta.
--   3. K clamped to 0..OrderRules.MaxToppings and to the number of unlocked toppings (DEC-071).
--   4. K distinct toppings drawn by weight = Ingredients[k].Weight x CustomerTypes[t].IngredientMult[k] (missing = 1)
--      x OrderRules.NewIngredientBoost when unlocked today. Unlocked = UnlockDay in 1..day and no Vehicle (same rule
--      as Stock.Blocked, network.md §3.4; no order topping belongs to a vehicle in wave 1).
--
-- Returns topping keys (Ingredients.ToppingKeys) in ToppingKeys order. Bun + sausage are implicit.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

type Candidate = { Key: string, Weight: number }

local function phaseOf(day: number, isNight: boolean): Content.OrderPhase?
	local fallback: Content.OrderPhase? = nil
	for _, phase in Content.OrderPhases.List do
		if phase.IsNight ~= isNight then
			continue
		end
		if day >= phase.FromDay and (phase.ToDay == 0 or day <= phase.ToDay) then
			return phase
		end
		if fallback == nil or phase.FromDay > fallback.FromDay then
			fallback = phase
		end
	end
	return fallback
end

local function drawIndex(weights: { number }, rng: Random): number
	local total = 0
	for _, weight in weights do
		total += math.max(weight, 0)
	end
	if total <= 0 then
		return 1
	end
	local roll = rng:NextNumber() * total
	for index, weight in weights do
		roll -= math.max(weight, 0)
		if roll < 0 then
			return index
		end
	end
	return #weights
end

const OrderRoll = {}

-- Order of one customer: topping keys. `isNight` is for wave 2 (night phase row); wave 1 calls it with day only.
function OrderRoll.Roll(day: number, customerType: string, rng: Random, isNight: boolean?): { string }
	const rules = Content.OrderRules
	const kind = Content.CustomerTypes.ByKey[customerType]
	const phase = phaseOf(day, isNight == true)

	local k = 0
	if phase ~= nil then
		k = drawIndex(phase.KWeights, rng) - 1
	end
	if kind ~= nil and kind.KShift.Chance > 0 and rng:NextNumber() < kind.KShift.Chance then
		k += kind.KShift.Delta
	end

	const candidates: { Candidate } = {}
	for _, key in Content.Ingredients.ToppingKeys do
		const row = Content.Ingredients.ByKey[key]
		if row.Vehicle ~= nil or row.UnlockDay < 1 or row.UnlockDay > day then
			continue
		end
		local weight = row.Weight
		if kind ~= nil then
			weight *= kind.IngredientMult[key] or 1
		end
		if row.UnlockDay == day then
			weight *= rules.NewIngredientBoost
		end
		if weight > 0 then
			table.insert(candidates, { Key = key, Weight = weight })
		end
	end
	k = math.clamp(k, 0, math.min(rules.MaxToppings, #candidates))

	const picked: { [string]: boolean } = {}
	for _ = 1, k do
		const weights: { number } = {}
		for index, candidate in candidates do
			weights[index] = candidate.Weight
		end
		const index = drawIndex(weights, rng)
		picked[candidates[index].Key] = true
		table.remove(candidates, index)
	end

	const order: { string } = {}
	for _, key in Content.Ingredients.ToppingKeys do
		if picked[key] then
			table.insert(order, key)
		end
	end
	return order
end

return table.freeze(OrderRoll)
