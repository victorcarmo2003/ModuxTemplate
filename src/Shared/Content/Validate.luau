--!strict
-- Content validation (content-data.md §1.4). Runs once when Content is required, on server and client.
-- Any failure is an error naming the table and the row: a bad enum would bring Lync.start() down anyway (R8).
local Actions = require(script.Parent.Actions)
local Classes = require(script.Parent.Classes)
local CustomerTypes = require(script.Parent.CustomerTypes)
local Flow = require(script.Parent.Flow)
local Ingredients = require(script.Parent.Ingredients)
local Items = require(script.Parent.Items)
local Moods = require(script.Parent.Moods)
local Notices = require(script.Parent.Notices)
local OpalLines = require(script.Parent.OpalLines)
local Orders = require(script.Parent.Orders)
local Outfits = require(script.Parent.Outfits)
local Packages = require(script.Parent.Packages)
local RunParams = require(script.Parent.RunParams)
local Shift = require(script.Parent.Shift)
local Species = require(script.Parent.Species)
local Stations = require(script.Parent.Stations)
local Stats = require(script.Parent.Stats)
local Table = require(script.Parent.Table)
local Upgrades = require(script.Parent.Upgrades)
local Vehicles = require(script.Parent.Vehicles)

const KEY_PATTERN = "^[a-z][a-z0-9_]*$"
-- Wire enum values (rule §1.3 exception): Shift phases and mood names.
const VALUE_PATTERN = "^[A-Z][A-Za-z0-9_]*$"
const BITFIELD_MAX = 32

local function fail(name: string, index: number?, key: string?, message: string): never
	if index then
		error(`[Content] {name}[{index}] '{key or "?"}': {message}`, 0)
	end
	error(`[Content] {name}: {message}`, 0)
end

local function setOf(list: { string }): { [string]: boolean }
	const out: { [string]: boolean } = {}
	for _, value in list do
		out[value] = true
	end
	return out
end

local function inRange(name: string, index: number?, key: string?, field: string, value: number, low: number, high: number)
	if value ~= value or value < low or value > high then
		fail(name, index, key, `{field} = {value} out of range [{low}, {high}]`)
	end
end

-- Keys: pattern, duplicates, non-empty.
local function checkKeys<T>(name: string, t: Table.Table<T>, pattern: string)
	if #t.List == 0 then
		fail(name, nil, nil, "empty table (enum would be empty)")
	end
	const seen: { [string]: number } = {}
	for index, key in t.Keys do
		if type(key) ~= "string" or not string.match(key, pattern) then
			fail(name, index, tostring(key), `key does not match {pattern}`)
		end
		if seen[key] then
			fail(name, index, key, `duplicate key (first at row {seen[key]})`)
		end
		seen[key] = index
	end
end

local function checkSubset(name: string, list: { string }, max: number)
	if #list == 0 then
		fail(name, nil, nil, "derived key list is empty")
	end
	if #list > max then
		fail(name, nil, nil, `derived key list has {#list} names (max {max})`)
	end
end

local function checkKeySets()
	checkKeys("Actions", Actions, KEY_PATTERN)
	checkKeys("Classes", Classes, KEY_PATTERN)
	checkKeys("CustomerTypes", CustomerTypes, KEY_PATTERN)
	checkKeys("Ingredients", Ingredients, KEY_PATTERN)
	checkKeys("Items", Items, KEY_PATTERN)
	checkKeys("Moods", Moods, VALUE_PATTERN)
	checkKeys("Notices", Notices, KEY_PATTERN)
	checkKeys("OpalLines", OpalLines, KEY_PATTERN)
	checkKeys("OrderPhases", Orders, KEY_PATTERN)
	checkKeys("Outfits", Outfits, KEY_PATTERN)
	checkKeys("Packages", Packages, KEY_PATTERN)
	checkKeys("Shift", Shift, VALUE_PATTERN)
	checkKeys("Species", Species, KEY_PATTERN)
	checkKeys("Stations", Stations, KEY_PATTERN)
	checkKeys("Upgrades", Upgrades, KEY_PATTERN)
	checkKeys("Vehicles", Vehicles, KEY_PATTERN)

	checkSubset("Ingredients.ToppingKeys", Ingredients.ToppingKeys, BITFIELD_MAX)
	checkSubset("Stations.RecordKeys", Stations.RecordKeys, 255)
	if #Classes.Keys > BITFIELD_MAX then
		fail("Classes", nil, nil, `{#Classes.Keys} classes exceed the Profile.Classes bitfield ({BITFIELD_MAX})`)
	end

	const statSeen: { [string]: boolean } = {}
	for index, stat in Stats.List do
		if statSeen[stat] then
			fail("Stats", index, stat, "duplicate stat")
		end
		statSeen[stat] = true
	end
end

local function checkEffects(name: string, index: number, key: string, effects: { [string]: number })
	for stat in effects do
		if not Stats.Has[stat] then
			fail(name, index, key, `effect on unknown Stat '{stat}'`)
		end
	end
end

local function checkUpgrades()
	for index, row in Upgrades.List do
		const where = setOf(row.Vehicles)
		if #row.Vehicles == 0 then
			fail("Upgrades", index, row.Key, "Vehicles is empty")
		end
		for _, vehicle in row.Vehicles do
			if not Vehicles.ByKey[vehicle] then
				fail("Upgrades", index, row.Key, `Vehicles has unknown vehicle '{vehicle}'`)
			end
			const levels = row.Levels[vehicle]
			if levels == nil or #levels == 0 then
				fail("Upgrades", index, row.Key, `Levels.{vehicle} missing (DEC-184)`)
			end
			for position, level in levels do
				if level.Level ~= row.StartLevel + position - 1 then
					fail("Upgrades", index, row.Key, `Levels.{vehicle}[{position}].Level = {level.Level}, expected {row.StartLevel + position - 1}`)
				end
				if position == 1 and level.Price ~= 0 then
					fail("Upgrades", index, row.Key, `Levels.{vehicle}[1] is the starting level and must cost 0`)
				end
				if position > 1 and level.Price < levels[position - 1].Price then
					fail("Upgrades", index, row.Key, `Levels.{vehicle}[{position}].Price lower than the previous level`)
				end
				inRange("Upgrades", index, row.Key, `Levels.{vehicle}[{position}].Price`, level.Price, 0, 1000000)
				checkEffects("Upgrades", index, row.Key, level.Effects :: any)
			end
		end
		for vehicle in row.Levels do
			if not where[vehicle] then
				fail("Upgrades", index, row.Key, `Levels.{vehicle} exists but '{vehicle}' is not in Vehicles`)
			end
		end
		if not string.match(row.BenchSpot, "^B[1-5]$") then
			fail("Upgrades", index, row.Key, `BenchSpot '{row.BenchSpot}' is not B1..B5`)
		end
		for other = 1, index - 1 do
			if Upgrades.List[other].BenchSpot == row.BenchSpot then
				fail("Upgrades", index, row.Key, `BenchSpot {row.BenchSpot} already used by '{Upgrades.List[other].Key}'`)
			end
		end
	end
	if not Upgrades.ByKey.cooler or not Upgrades.ByKey.cooler.Levels.cart then
		fail("Upgrades", nil, nil, "cooler with cart levels is required (Ingredients.Capacity)")
	end
end

local function checkIngredients()
	const coolerLevels = #Upgrades.ByKey.cooler.Levels.cart
	for index, row in Ingredients.List do
		if not Stations.ByKey[row.Station] then
			fail("Ingredients", index, row.Key, `Station '{row.Station}' not in Stations`)
		end
		if row.Vehicle ~= nil and not Vehicles.ByKey[row.Vehicle] then
			fail("Ingredients", index, row.Key, `Vehicle '{row.Vehicle}' not in Vehicles`)
		end
		if (row.UnlockDay == 0) ~= (row.Vehicle ~= nil) then
			fail("Ingredients", index, row.Key, "UnlockDay = 0 exactly when the ingredient depends on a Vehicle")
		end
		if #row.Capacity ~= coolerLevels then
			fail("Ingredients", index, row.Key, `Capacity has {#row.Capacity} entries, Cooler has {coolerLevels} levels`)
		end
		for level, amount in row.Capacity do
			inRange("Ingredients", index, row.Key, `Capacity[{level}]`, amount, 1, 999)
			if level > 1 and amount < row.Capacity[level - 1] then
				fail("Ingredients", index, row.Key, `Capacity[{level}] lower than the previous level`)
			end
		end
		const topping = row.Kind == "Sauce" or row.Kind == "Topping"
		if topping then
			if row.OrderPrice <= 0 or row.Weight <= 0 or row.Stack == nil then
				fail("Ingredients", index, row.Key, "Sauce/Topping needs OrderPrice > 0, Weight > 0 and Stack")
			end
		elseif row.OrderPrice ~= 0 or row.Weight ~= 0 or row.Stack ~= nil then
			fail("Ingredients", index, row.Key, "only Sauce/Topping has OrderPrice, Weight and Stack")
		end
	end
end

local function checkItems()
	const rules = Items.Rules
	inRange("ItemRules", nil, nil, "HotbarSlots", rules.HotbarSlots, 1, 10)
	for category, limit in rules.CategoryLimits do
		inRange("ItemRules", nil, nil, `CategoryLimits.{category}`, limit, 1, rules.HotbarSlots)
	end
	for index, row in Items.List do
		if rules.CategoryLimits[row.Category] == nil then
			fail("Items", index, row.Key, `Category '{row.Category}' not in ItemRules.CategoryLimits`)
		end
		if row.Kind == "Package" and not row.Stackable then
			fail("Items", index, row.Key, "Package items are Stackable (Count attribute)")
		end
		const despawn = row.DropDespawn
		if type(despawn) == "number" then
			inRange("Items", index, row.Key, "DropDespawn", despawn, 0, 3600)
		elseif despawn ~= "NextShiftEnd" then
			fail("Items", index, row.Key, "DropDespawn must be seconds or NextShiftEnd")
		end
	end
end

local function checkPackages()
	const covered: { [string]: string } = {}
	for index, row in Packages.List do
		if not Ingredients.ByKey[row.Ingredient] then
			fail("Packages", index, row.Key, `Ingredient '{row.Ingredient}' not in Ingredients`)
		end
		const item = Items.ByKey[row.Item]
		if not item or item.Kind ~= "Package" then
			fail("Packages", index, row.Key, `Item '{row.Item}' is not a Package item`)
		end
		if covered[row.Ingredient] then
			fail("Packages", index, row.Key, `Ingredient '{row.Ingredient}' already sold by '{covered[row.Ingredient]}'`)
		end
		covered[row.Ingredient] = row.Key
		inRange("Packages", index, row.Key, "Amount", row.Amount, 1, 999)
		inRange("Packages", index, row.Key, "Price", row.Price, 1, 100000)
	end
	for index, row in Ingredients.List do
		if not covered[row.Key] then
			fail("Ingredients", index, row.Key, "no package restocks this ingredient")
		end
	end
end

local function checkStations()
	for index, row in Stations.List do
		for _, action in row.Actions do
			if not Actions.ByKey[action] then
				fail("Stations", index, row.Key, `Action '{action}' not in Actions`)
			end
		end
		const ingredient = row.Ingredient
		if ingredient ~= nil and ingredient ~= Stations.PerAnchor and not Ingredients.ByKey[ingredient] then
			fail("Stations", index, row.Key, `Ingredient '{ingredient}' not in Ingredients`)
		end
		for field, value in row.Params do
			inRange("Stations", index, row.Key, `Params.{field}`, value, 0, 3600)
		end
	end
end

local function checkActions()
	const phases = setOf(Shift.Keys)
	for index, row in Actions.List do
		if row.Text == "" then
			fail("Actions", index, row.Key, "empty Text")
		end
		inRange("Actions", index, row.Key, "Hold", row.Hold, 0, 10)
		inRange("Actions", index, row.Key, "Radius", row.Radius, 1, 50)
		inRange("Actions", index, row.Key, "Wave", row.Wave, 1, 4)
		const held = row.Requires.Held
		if held ~= nil and not Items.ByKey[held] and (Items.Rules.CategoryLimits :: any)[held] == nil then
			fail("Actions", index, row.Key, `Requires.Held '{held}' is neither an Item nor a category`)
		end
		if row.Requires.NotHasTopping and held ~= "hot_dog" then
			fail("Actions", index, row.Key, "Requires.NotHasTopping only applies to Held = hot_dog")
		end
		for _, phase in row.Requires.Phase or {} do
			if not phases[phase] then
				fail("Actions", index, row.Key, `Requires.Phase '{phase}' not in Shift`)
			end
		end
	end
end

local function checkNotices()
	for index, row in Notices.List do
		if row.Text == "" then
			fail("Notices", index, row.Key, "empty Text")
		end
	end
end

local function checkClassesAndSpecies()
	local hasFree = false
	for index, row in Classes.List do
		const species = Species.ByKey[row.Species]
		if not species then
			fail("Classes", index, row.Key, `Species '{row.Species}' not in Species`)
		end
		if species.Class ~= row.Key then
			fail("Classes", index, row.Key, `Species '{row.Species}' points to class '{species.Class or "nil"}' (must be 1 <-> 1)`)
		end
		if species.ReservedFor ~= nil then
			fail("Classes", index, row.Key, `Species '{row.Species}' is reserved for {species.ReservedFor} (DEC-186)`)
		end
		inRange("Classes", index, row.Key, "Price", row.Price, 0, 100000)
		inRange("Classes", index, row.Key, "Tier", row.Tier, 0, 9)
		if row.Price == 0 then
			hasFree = true
		end
		for _, effect in row.Effects do
			if not Stats.Has[effect.Stat] then
				fail("Classes", index, row.Key, `effect on unknown Stat '{effect.Stat}'`)
			end
			if effect.When == "PackagesAtLeast" and effect.WhenValue == nil then
				fail("Classes", index, row.Key, "When = PackagesAtLeast needs WhenValue")
			end
		end
	end
	if not hasFree then
		fail("Classes", nil, nil, "no free class (new accounts own one, DEC-186)")
	end
	for index, row in Species.List do
		if row.Class ~= nil then
			const class = Classes.ByKey[row.Class]
			if not class or class.Species ~= row.Key then
				fail("Species", index, row.Key, `Class '{row.Class}' does not point back (1 <-> 1)`)
			end
		end
		if row.ReservedFor ~= nil and (row.Class ~= nil or row.Customer or row.Pedestrian) then
			fail("Species", index, row.Key, "reserved species cannot be class, customer or pedestrian")
		end
	end
end

local function checkLooks()
	const looks = Outfits.Looks
	const packs = setOf(looks.Packs :: { string })
	const expressions = setOf(looks.Expressions)
	for pack in packs do
		if not expressions[(looks.PackFace :: any)[pack] or ""] then
			fail("Looks", nil, nil, `PackFace.{pack} is not an expression`)
		end
	end
	for _, expression in looks.NpcNeverUses.Expressions do
		if not expressions[expression] then
			fail("Looks", nil, nil, `NpcNeverUses expression '{expression}' unknown`)
		end
	end
	for _, outfit in looks.NpcNeverUses.Outfits do
		if not Outfits.ByKey[outfit] then
			fail("Looks", nil, nil, `NpcNeverUses outfit '{outfit}' unknown`)
		end
	end
	for index, row in Outfits.List do
		for _, pack in row.Packs do
			if not packs[pack] then
				fail("Outfits", index, row.Key, `Pack '{pack}' not in Looks.Packs`)
			end
		end
		if (row.Use == "Reserved") ~= (row.ReservedFor ~= nil) then
			fail("Outfits", index, row.Key, "Use = Reserved exactly when ReservedFor is set")
		end
	end
	if not Moods.ByKey.Neutral then
		fail("Moods", nil, nil, "Neutral is required")
	end
	for index, row in Moods.List do
		if not expressions[row.Expression] then
			fail("Moods", index, row.Key, `Expression '{row.Expression}' not in Looks.Expressions`)
		end
	end
	inRange("MoodRules", nil, nil, "AnnoyedAt", Moods.Rules.AnnoyedAt, 0, 1)
end

local function checkCustomerTypes()
	const toppings = setOf(Ingredients.ToppingKeys)
	for index, row in CustomerTypes.List do
		if row.Role == "Customer" and #row.Species == 0 then
			fail("CustomerTypes", index, row.Key, "customer type without Species")
		end
		for _, key in row.Species do
			const species = Species.ByKey[key]
			if not species then
				fail("CustomerTypes", index, row.Key, `Species '{key}' not in Species`)
			end
			if species.ReservedFor ~= nil or not species.Customer then
				fail("CustomerTypes", index, row.Key, `Species '{key}' cannot be a customer (DEC-186, DEC-188)`)
			end
		end
		if #row.Outfits == 0 then
			fail("CustomerTypes", index, row.Key, "Outfits is empty")
		end
		for _, key in row.Outfits do
			const outfit = Outfits.ByKey[key]
			if not outfit or outfit.Use ~= "Civil" then
				fail("CustomerTypes", index, row.Key, `Outfit '{key}' is not a civil outfit (DEC-188)`)
			end
		end
		for ingredient, mult in row.IngredientMult do
			if not toppings[ingredient] then
				fail("CustomerTypes", index, row.Key, `IngredientMult '{ingredient}' is not a topping`)
			end
			inRange("CustomerTypes", index, row.Key, `IngredientMult.{ingredient}`, mult, 0, 10)
		end
		inRange("CustomerTypes", index, row.Key, "KShift.Chance", row.KShift.Chance, 0, 1)
		inRange("CustomerTypes", index, row.Key, "WalkSpeed", row.WalkSpeed, 1, 50)
	end
end

local function checkOrders()
	const rules = Orders.Rules
	inRange("OrderRules", nil, nil, "MaxToppings", rules.MaxToppings, 0, #Ingredients.ToppingKeys)
	for index, row in Orders.List do
		if #row.KWeights ~= rules.MaxToppings + 1 then
			fail("OrderPhases", index, row.Key, `KWeights needs {rules.MaxToppings + 1} entries (K = 0..MaxToppings)`)
		end
		local sum = 0
		for _, weight in row.KWeights do
			inRange("OrderPhases", index, row.Key, "KWeights[]", weight, 0, 1)
			sum += weight
		end
		if math.abs(sum - 1) > 1e-6 then
			fail("OrderPhases", index, row.Key, `KWeights sum to {sum}, expected 1`)
		end
		if row.ToDay ~= 0 and row.ToDay < row.FromDay then
			fail("OrderPhases", index, row.Key, "ToDay < FromDay")
		end
	end
end

local function checkRecords()
	if not Vehicles.ByKey[RunParams.StartVehicle] then
		fail("RunParams", nil, nil, `StartVehicle '{RunParams.StartVehicle}' not in Vehicles`)
	end
	if #RunParams.PartyPriceMult ~= 4 then
		fail("RunParams", nil, nil, "PartyPriceMult needs 4 entries (party 1..4)")
	end
	if #Flow.PartyMult ~= 4 then
		fail("Flow", nil, nil, "PartyMult needs 4 entries (party 1..4)")
	end
	for index, row in Vehicles.List do
		inRange("Vehicles", index, row.Key, "RailSlots", row.RailSlots, 1, 30)
		inRange("Vehicles", index, row.Key, "BoardSlots", row.BoardSlots, 1, 9)
	end
	for index, row in Shift.List do
		inRange("Shift", index, row.Key, "Duration", row.Duration, 0, 3600)
		inRange("Shift", index, row.Key, "ClockFrom", row.ClockFrom, 0, 2880)
		inRange("Shift", index, row.Key, "ClockTo", row.ClockTo, row.ClockFrom, 2880)
	end
	for _, required in { "Prep", "Open", "Closing", "Summary" } do
		if not Shift.ByKey[required] then
			fail("Shift", nil, nil, `phase '{required}' is required`)
		end
	end
	for index, row in OpalLines.List do
		if row.ToNight < row.FromNight then
			fail("OpalLines", index, row.Key, "ToNight < FromNight")
		end
	end
end

return function()
	checkKeySets()
	checkUpgrades()
	checkIngredients()
	checkItems()
	checkPackages()
	checkStations()
	checkActions()
	checkNotices()
	checkClassesAndSpecies()
	checkLooks()
	checkCustomerTypes()
	checkOrders()
	checkRecords()
end
