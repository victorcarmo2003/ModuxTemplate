--!strict
-- NpcService/Look: what a customer looks like (DEC-149, DEC-188; content-data.md §3.10a, §3.10b, §3.16). TASK-031.
-- Pure: only Content. Customer type -> one of its fixed species + a civil outfit drawn uniformly (DEC-188 b). Never
-- the crew uniform (Looks.NpcNeverUses) nor a reserved species (raccoon, DEC-186).
-- Pedestrians (NPC-019) are wave 2 (DEC-183, Q-162): Pick refuses any type whose Role is not "Customer".
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

export type Choice = { CustomerType: string, Species: string, Outfit: string }

const Look = {}

local function validSpecies(key: string): boolean
	const row = Content.Species.ByKey[key]
	return row ~= nil and row.Customer and row.ReservedFor == nil
end

local function validOutfit(key: string): boolean
	const row = Content.Outfits.ByKey[key]
	return row ~= nil and row.Use == "Civil" and table.find(Content.Looks.NpcNeverUses.Outfits, key) == nil
end

local function pickFrom(list: { string }, rng: Random): string
	return list[rng:NextInteger(1, #list)]
end

-- Pool key: rigs with the same species and customer type share geometry (accessories come from the type); the civil
-- outfit is only an attribute the client dresses (T40), so it does not split the pool.
function Look.Key(species: string, customerType: string): string
	return `{species}/{customerType}`
end

-- Weighted draw among the customer types unlocked for this shift (Weight.Day / Weight.Night, UnlockDay /
-- UnlockNight, Shift). nil when no type qualifies.
function Look.PickType(day: number, night: number, isNight: boolean, rng: Random): string?
	const keys: { string } = {}
	const weights: { number } = {}
	local total = 0
	for _, row in Content.CustomerTypes.List do
		if row.Role ~= "Customer" then
			continue
		end
		local weight: number
		local unlocked: boolean
		if isNight then
			weight = row.Weight.Night
			unlocked = row.Shift ~= "Day" and row.UnlockNight >= 1 and night >= row.UnlockNight
		else
			weight = row.Weight.Day
			unlocked = row.Shift ~= "Night" and row.UnlockDay >= 1 and day >= row.UnlockDay
		end
		if unlocked and weight > 0 then
			table.insert(keys, row.Key)
			table.insert(weights, weight)
			total += weight
		end
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber() * total
	for index, weight in weights do
		roll -= weight
		if roll < 0 then
			return keys[index]
		end
	end
	return keys[#keys]
end

-- Species and outfit for `customerType`. `species`/`outfit` force a value (must still be valid for the type).
-- Returns nil + reason when the request breaks a rule.
function Look.Pick(customerType: string, rng: Random, species: string?, outfit: string?): (Choice?, string?)
	const row = Content.CustomerTypes.ByKey[customerType]
	if row == nil then
		return nil, `unknown CustomerType '{customerType}'`
	end
	if row.Role ~= "Customer" then
		return nil, `CustomerType '{customerType}' is a {row.Role} (wave 2, Q-162)`
	end

	const speciesList: { string } = {}
	for _, key in row.Species do
		if validSpecies(key) then
			table.insert(speciesList, key)
		end
	end
	const outfitList: { string } = {}
	for _, key in row.Outfits do
		if validOutfit(key) then
			table.insert(outfitList, key)
		end
	end
	if #speciesList == 0 or #outfitList == 0 then
		return nil, `CustomerType '{customerType}' has no valid species or civil outfit`
	end

	if species ~= nil and table.find(speciesList, species) == nil then
		return nil, `species '{species}' is not a customer species of '{customerType}'`
	end
	if outfit ~= nil and table.find(outfitList, outfit) == nil then
		return nil, `outfit '{outfit}' is not a civil outfit of '{customerType}'`
	end

	return {
		CustomerType = customerType,
		Species = species or pickFrom(speciesList, rng),
		Outfit = outfit or pickFrom(outfitList, rng),
	},
		nil
end

return table.freeze(Look)
