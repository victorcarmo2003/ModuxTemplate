--!strict
-- Content validation (content-data.md §1.4). Runs once when Content is required, on server and client.
-- Any failure is an error naming the table and the row: a bad enum would bring Lync.start() down anyway (R8).
local Achievements = require(script.Parent.Achievements)
local Actions = require(script.Parent.Actions)
local Animations = require(script.Parent.Animations)
local Anomalies = require(script.Parent.Anomalies)
local BossCalls = require(script.Parent.BossCalls)
local Classes = require(script.Parent.Classes)
local CustomerTypes = require(script.Parent.CustomerTypes)
local Cutscenes = require(script.Parent.Cutscenes)
local Flow = require(script.Parent.Flow)
local GemRewards = require(script.Parent.GemRewards)
local Hallucinations = require(script.Parent.Hallucinations)
local HudReveal = require(script.Parent.HudReveal)
local Ingredients = require(script.Parent.Ingredients)
local Items = require(script.Parent.Items)
local LightGroups = require(script.Parent.LightGroups)
local Mart = require(script.Parent.Mart)
local Moods = require(script.Parent.Moods)
local Nights = require(script.Parent.Nights)
local Notices = require(script.Parent.Notices)
local OpalLines = require(script.Parent.OpalLines)
local Orders = require(script.Parent.Orders)
local Outfits = require(script.Parent.Outfits)
local Packages = require(script.Parent.Packages)
local Revive = require(script.Parent.Revive)
local RunParams = require(script.Parent.RunParams)
local Sanity = require(script.Parent.Sanity)
local Seating = require(script.Parent.Seating)
local Shift = require(script.Parent.Shift)
local Sounds = require(script.Parent.Sounds)
local Species = require(script.Parent.Species)
local Stations = require(script.Parent.Stations)
local Stats = require(script.Parent.Stats)
local Table = require(script.Parent.Table)
local Thief = require(script.Parent.Thief)
local Traffic = require(script.Parent.Traffic)
local Upgrades = require(script.Parent.Upgrades)
local Trailer = require(script.Parent.Trailer)
local Vehicles = require(script.Parent.Vehicles)
local WalkPaths = require(script.Parent.WalkPaths)

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
	checkKeys("HudReveal", HudReveal, KEY_PATTERN)
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
		if row.SoldAt == "Bench" then
			if not string.match(row.BenchSpot, "^B[1-5]$") then
				fail("Upgrades", index, row.Key, `BenchSpot '{row.BenchSpot}' is not B1..B5`)
			end
			for other = 1, index - 1 do
				if Upgrades.List[other].BenchSpot == row.BenchSpot then
					fail("Upgrades", index, row.Key, `BenchSpot {row.BenchSpot} already used by '{Upgrades.List[other].Key}'`)
				end
			end
			if #row.PlaceSpots > 0 then
				fail("Upgrades", index, row.Key, "PlaceSpots is only for SoldAt InPlace")
			end
		elseif row.SoldAt == "InPlace" then
			-- TASK-144 (Q-178 A): sold on a prompt in the world, one spot per purchasable level
			if row.BenchSpot ~= "" then
				fail("Upgrades", index, row.Key, "SoldAt InPlace must have an empty BenchSpot")
			end
			for _, vehicle in row.Vehicles do
				const buyable = #row.Levels[vehicle] - 1
				if #row.PlaceSpots ~= buyable then
					fail("Upgrades", index, row.Key, `{#row.PlaceSpots} PlaceSpots for {buyable} purchasable levels on {vehicle}`)
				end
			end
		else
			fail("Upgrades", index, row.Key, `SoldAt '{tostring(row.SoldAt)}' is not Bench or InPlace`)
		end
		if row.Scope == "Pad" then
			-- Q-179 a: one level for the whole Pad, written on every vehicle at once (UpgradeService)
			const first = row.Levels[row.Vehicles[1]]
			for _, vehicle in row.Vehicles do
				const levels = row.Levels[vehicle]
				if #levels ~= #first then
					fail("Upgrades", index, row.Key, `Scope Pad: Levels.{vehicle} differs from Levels.{row.Vehicles[1]}`)
				end
				for position, level in levels do
					if level.Price ~= first[position].Price then
						fail("Upgrades", index, row.Key, `Scope Pad: Levels.{vehicle}[{position}].Price differs between vehicles`)
					end
				end
			end
		elseif row.Scope ~= "Vehicle" then
			fail("Upgrades", index, row.Key, `Scope '{tostring(row.Scope)}' is not Vehicle or Pad`)
		end
		const requires = row.Requires
		if requires ~= nil then
			const other = Upgrades.ByKey[requires.Upgrade]
			if other == nil or other == row then
				fail("Upgrades", index, row.Key, `Requires.Upgrade '{requires.Upgrade}' is not another upgrade`)
			end
			inRange("Upgrades", index, row.Key, "Requires.Level", requires.Level, 1, 9)
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
		if row.PatienceMult ~= nil then
			inRange("CustomerTypes", index, row.Key, "PatienceMult.Queue", row.PatienceMult.Queue, 0.25, 4)
			inRange("CustomerTypes", index, row.Key, "PatienceMult.Order", row.PatienceMult.Order, 0.25, 4)
		end
	end
end

local function checkOrders()
	const rules = Orders.Rules
	inRange("OrderRules", nil, nil, "MaxToppings", rules.MaxToppings, 0, #Ingredients.ToppingKeys)
	inRange("OrderRules", nil, nil, "QueuePatience", rules.QueuePatience, 1, rules.WireSpanMax)
	inRange("OrderRules", nil, nil, "OrderPatienceBase", rules.OrderPatienceBase, 1, rules.WireSpanMax)
	inRange("OrderRules", nil, nil, "OrderPatiencePerK", rules.OrderPatiencePerK, 0, 60)
	inRange("OrderRules", nil, nil, "WireSpanMax", rules.WireSpanMax, 1, 255)
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
	inRange("RunParams", nil, nil, "NightsFromDay", RunParams.NightsFromDay, 2, 50)
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

-- Wave 2 (TASK-047; content-data.md §6) ---------------------------------------------------------------------------

const SELLING_PHASES: { [string]: boolean } = { Open = true, Night = true }
const SKIP_PHASES: { [string]: boolean } = { Intro = true, Call = true, Finale = true }

local function checkShiftWave2()
	for index, row in Shift.List do
		if row.Selling and not SELLING_PHASES[row.Key] then
			fail("Shift", index, row.Key, "Selling is only for Open and Night (architecture.md §19.4)")
		end
		if row.SkipWithoutProbe and not SKIP_PHASES[row.Key] then
			fail("Shift", index, row.Key, "SkipWithoutProbe is only for Intro, Call and Finale (§19.0 rule 4)")
		end
		const night = row.Night
		if night ~= nil then
			if row.Kind == "Day" then
				fail("Shift", index, row.Key, "Night override on a Day-only phase")
			end
			inRange("Shift", index, row.Key, "Night.Duration", night.Duration, 0, 3600)
			inRange("Shift", index, row.Key, "Night.ClockFrom", night.ClockFrom, 0, 2880)
			inRange("Shift", index, row.Key, "Night.ClockTo", night.ClockTo, night.ClockFrom, 2880)
		end
	end
	for key in SELLING_PHASES do
		const row = Shift.ByKey[key]
		if row == nil or not row.Selling then
			fail("Shift", nil, nil, `phase '{key}' must exist with Selling = true`)
		end
	end
end

-- Highest Priority and longest call among the rows of a trigger kind (0, 0 when there is none).
local function kindStats(kind: BossCalls.TriggerKind): (number, number)
	local priority, count = 0, 0
	for _, row in BossCalls.List do
		if row.Trigger.Kind == kind then
			priority = math.max(priority, row.Priority)
			count = math.max(count, #row.Lines)
		end
	end
	return priority, count
end

local function checkBossCalls()
	checkKeys("BossCalls", BossCalls, KEY_PATTERN)
	const rules = BossCalls.Rules
	inRange("BossCallRules", nil, nil, "LineTime", rules.LineTime, 0.5, 10)
	inRange("BossCallRules", nil, nil, "AutoAnswer", rules.AutoAnswer, 1, 120)
	if BossCalls.Keys[1] ~= "none" or BossCalls.List[1].Trigger.Kind ~= "None" then
		fail("BossCalls", 1, BossCalls.Keys[1], "first row must be the sentinel 'none' (Trigger None)")
	end

	const nightCalls: { [number]: string } = {}
	const hints: { [string]: string } = {}
	local repeatKey = ""
	local repeats = 0
	local maxShort = 0
	for index, row in BossCalls.List do
		const trigger = row.Trigger
		const kind = trigger.Kind
		inRange("BossCalls", index, row.Key, "Priority", row.Priority, 1, 4)
		if kind ~= "None" and #row.Lines == 0 then
			fail("BossCalls", index, row.Key, "call without Lines")
		end
		for position, line in row.Lines do
			if line.Text == "" then
				fail("BossCalls", index, row.Key, `Lines[{position}] is empty`)
			end
		end
		if row.Cues ~= nil then
			for position, cue in row.Cues do
				if cue.Line < 1 or cue.Line > #row.Lines then
					fail("BossCalls", index, row.Key, `Cues[{position}].Line {cue.Line} is outside 1..{#row.Lines}`)
				end
			end
		end
		if row.Short ~= nil and kind ~= "NightCall" then
			fail("BossCalls", index, row.Key, "Short only on NightCall rows")
		end
		if kind == "DayPrep" or kind == "DayInfinite" or kind == "Hint" or kind == "Tutorial" then
			if #row.Lines > rules.DayMaxLines then
				fail("BossCalls", index, row.Key, `{#row.Lines} lines, day calls have at most {rules.DayMaxLines}`)
			end
		elseif #row.Lines * rules.LineTime > rules.NightMaxSeconds then
			fail("BossCalls", index, row.Key, `{#row.Lines * rules.LineTime} s, night calls last at most {rules.NightMaxSeconds} s`)
		end
		if kind == "DayPrep" and (trigger.Day == nil) == (trigger.Night == nil) then
			fail("BossCalls", index, row.Key, "DayPrep needs exactly one of Trigger.Day or Trigger.Night")
		end
		if kind == "NightCall" then
			const night = trigger.Night or 0
			if night < 1 or night > RunParams.Nights then
				fail("BossCalls", index, row.Key, `NightCall Trigger.Night must be 1..{RunParams.Nights}`)
			end
			if nightCalls[night] then
				fail("BossCalls", index, row.Key, `second NightCall for night {night} (first '{nightCalls[night]}')`)
			end
			nightCalls[night] = row.Key
			const short = row.Short or {}
			if #short == 0 then
				fail("BossCalls", index, row.Key, "NightCall needs Short (lines played on a repeated night)")
			end
			maxShort = math.max(maxShort, #short)
		elseif kind == "NightRepeat" then
			repeats += 1
			repeatKey = row.Key
		elseif kind == "Hint" then
			const action = trigger.Action or ""
			if not Actions.ByKey[action] then
				fail("BossCalls", index, row.Key, `Hint Trigger.Action '{action}' not in Actions`)
			end
			if hints[action] then
				fail("BossCalls", index, row.Key, `second hint for '{action}' (first '{hints[action]}')`)
			end
			hints[action] = row.Key
		end
	end
	-- first-hot-dog tutorial call (Provisional): one Tutorial row, named by Rules.Tutorial; Covers are real actions
	const tutorial = rules.Tutorial
	const tutorialRow = BossCalls.ByKey[tutorial.Call]
	if tutorialRow == nil or tutorialRow.Trigger.Kind ~= "Tutorial" then
		fail("BossCallRules", nil, nil, `Tutorial.Call '{tutorial.Call}' is not a Tutorial row`)
	end
	inRange("BossCallRules", nil, nil, "Tutorial.Goodbye", tutorial.Goodbye, 1, 15)
	for _, action in tutorial.Covers do
		if not Actions.ByKey[action] then
			fail("BossCallRules", nil, nil, `Tutorial.Covers '{action}' not in Actions`)
		end
	end
	for night = 1, RunParams.Nights do
		if nightCalls[night] == nil then
			fail("BossCalls", nil, nil, `night {night} has no NightCall`)
		end
	end
	if repeats ~= 1 then
		fail("BossCalls", nil, nil, `exactly one NightRepeat call is required (found {repeats})`)
	end

	-- Calls sharing one Call phase play in Priority order and must fit its cap (L2-12 of the wave 2 test plan).
	const callCap = Shift.ByKey.Call.Duration
	const firstNight = BossCalls.ByKey[nightCalls[1]]
	const trailerP, trailerN = kindStats("TrailerBought")
	if trailerN > 0 and trailerP <= firstNight.Priority then
		fail("BossCalls", nil, nil, "TrailerBought needs a higher Priority than NightCall (plays first on Night 1)")
	end
	const _, coffeeN = kindStats("NightCoffee")
	if (trailerN + #firstNight.Lines + coffeeN) * rules.LineTime > callCap then
		fail("BossCalls", nil, nil, `trailer call + {firstNight.Key} + coffee call exceed the Call cap ({callCap} s)`)
	end
	const repeatRow = BossCalls.ByKey[repeatKey]
	const criticalP, criticalN = kindStats("LostCritical")
	const lastP, lastN = kindStats("LostLastChance")
	if not (criticalP > lastP and lastP > repeatRow.Priority) then
		fail("BossCalls", nil, nil, "Priority order on a repeated night: LostCritical > LostLastChance > NightRepeat")
	end
	const repeatN = #repeatRow.Lines + maxShort
	if repeatN * rules.LineTime > rules.NightMaxSeconds then
		fail("BossCalls", nil, nil, "NightRepeat + the longest Short exceed NightMaxSeconds")
	end
	if (criticalN + lastN + repeatN) * rules.LineTime > callCap then
		fail("BossCalls", nil, nil, `critical + last chance + short exceed the Call cap ({callCap} s)`)
	end
end

local function checkNights()
	checkKeys("Nights", Nights, KEY_PATTERN)
	if #Nights.List ~= RunParams.Nights then
		fail("Nights", nil, nil, `{#Nights.List} rows, RunParams.Nights = {RunParams.Nights}`)
	end
	local previous = 0
	for index, row in Nights.List do
		if row.Index ~= index then
			fail("Nights", index, row.Key, `Index = {row.Index}, expected {index} (list order)`)
		end
		inRange("Nights", index, row.Key, "Duration", row.Duration, 60, 3600)
		if row.Duration <= previous then
			fail("Nights", index, row.Key, "Duration must increase night after night (DEC-127)")
		end
		previous = row.Duration
		if not string.match(row.NewAnomaly, "^anm_%d%d%d_[a-z0-9_]+$") then
			fail("Nights", index, row.Key, `NewAnomaly '{row.NewAnomaly}' is not an anomaly key (anm_###_name)`)
		end
		const call = BossCalls.ByKey[row.Call]
		if call == nil or call.Trigger.Kind ~= "NightCall" or call.Trigger.Night ~= index then
			fail("Nights", index, row.Key, `Call '{row.Call}' is not the NightCall of night {index}`)
		end
		const short = BossCalls.ByKey[row.ShortCall]
		if short == nil or short.Trigger.Kind ~= "NightRepeat" then
			fail("Nights", index, row.Key, `ShortCall '{row.ShortCall}' is not the NightRepeat call`)
		end
		inRange("Nights", index, row.Key, "MaxSimultaneous", row.MaxSimultaneous, 1, Flow.MaxActorsNight)
		inRange("Nights", index, row.Key, "MinGap", row.MinGap, 0, 600)
		inRange("Nights", index, row.Key, "Customers.BaseInterval", row.Customers.BaseInterval, 1, 600)
		inRange("Nights", index, row.Key, "Customers.Max", row.Customers.Max, 0, Flow.MaxCustomersNight)
	end
	const nightPhase = Shift.ByKey.Night
	local cursor = nightPhase.ClockFrom
	for _, name in { "Calm", "Shift", "Last" } do
		const window = (Nights.Windows :: any)[name] :: { number }
		if #window ~= 2 or window[1] ~= cursor or window[2] <= window[1] then
			fail("Nights", nil, nil, `Windows.{name} must start at {cursor} and end after it (contiguous)`)
		end
		cursor = window[2]
	end
	if cursor ~= nightPhase.ClockTo then
		fail("Nights", nil, nil, `Windows end at {cursor}, the Night phase ends at {nightPhase.ClockTo}`)
	end
	inRange("Flow", nil, nil, "NightInterval", Flow.NightInterval, 1, 600)
end

local function checkLightsAndSanity()
	checkKeys("LightGroups", LightGroups, KEY_PATTERN)
	const zoneOwner: { [string]: string } = {}
	for index, row in LightGroups.List do
		if row.Vehicle ~= nil and not Vehicles.ByKey[row.Vehicle] then
			fail("LightGroups", index, row.Key, `Vehicle '{row.Vehicle}' not in Vehicles`)
		end
		if (row.Kind == "Upgrade") ~= (row.Upgrade ~= nil) then
			fail("LightGroups", index, row.Key, "Upgrade is set exactly when Kind = Upgrade")
		end
		if row.Upgrade ~= nil and not Upgrades.ByKey[row.Upgrade] then
			fail("LightGroups", index, row.Key, `Upgrade '{row.Upgrade}' not in Upgrades`)
		end
		if (row.Kind == "Switch" or row.Kind == "Upgrade") and row.Vehicle == nil then
			fail("LightGroups", index, row.Key, "switch groups belong to a vehicle")
		end
		if row.Kind ~= "Posts" and #row.Zones == 0 then
			fail("LightGroups", index, row.Key, "group without Zones")
		end
		for _, zone in row.Zones do
			if zoneOwner[zone] then
				fail("LightGroups", index, row.Key, `zone {zone} already in '{zoneOwner[zone]}'`)
			end
			zoneOwner[zone] = row.Key
		end
		inRange("LightGroups", index, row.Key, "Cooldown", row.Cooldown, 0, 10)
		inRange("LightGroups", index, row.Key, "Step", row.Step, 0, 10)
	end
	if #LightGroups.List > 255 then
		fail("LightGroups", nil, nil, "more than 255 groups (Lights set id)")
	end

	const phases = setOf(Shift.Keys)
	for _, phase in Sanity.DarkPhases do
		if not phases[phase] then
			fail("Sanity", nil, nil, `DarkPhases '{phase}' not in Shift`)
		end
	end
	inRange("Sanity", nil, nil, "Start", Sanity.Start, 1, 200)
	inRange("Sanity", nil, nil, "Bands.High", Sanity.Bands.High, Sanity.Bands.Mid, Sanity.Start)
	inRange("Sanity", nil, nil, "Bands.Mid", Sanity.Bands.Mid, 1, Sanity.Bands.High)
	inRange("Sanity", nil, nil, "SeeAngle", Sanity.SeeAngle, 1, 180)
	inRange("Sanity", nil, nil, "BasicLampRadius", Sanity.BasicLampRadius, 0, 100)
	inRange("Revive", nil, nil, "MaxPerNight", Revive.MaxPerNight, 0, 10)
	inRange("Revive", nil, nil, "WipeWindow", Revive.WipeWindow, 1, 120)
	inRange("Revive", nil, nil, "BodyFallback", Revive.BodyFallback, 0, 600)
end

local function checkThiefAndRewards()
	for day, chance in Thief.ChanceByDay.Days do
		inRange("Thief", nil, nil, `ChanceByDay.Days[{day}]`, chance, 0, 1)
	end
	inRange("Thief", nil, nil, "ChanceByDay.Default", Thief.ChanceByDay.Default, 0, 1)
	const window = Thief.WindowClock
	const open = Shift.ByKey.Open
	if #window ~= 2 or window[1] < open.ClockFrom or window[2] > open.ClockTo or window[2] <= window[1] then
		fail("Thief", nil, nil, "WindowClock must be {from, to} inside the Open phase")
	end
	inRange("Thief", nil, nil, "ApproachTime", Thief.ApproachTime, 0.5, 30)
	inRange("Thief", nil, nil, "CapRetry", Thief.CapRetry, 1, 600)
	if #Thief.Lurks == 0 or #Thief.Exits == 0 then
		fail("Thief", nil, nil, "Lurks and Exits cannot be empty")
	end

	checkKeys("Achievements", Achievements, KEY_PATTERN)
	for index, row in Achievements.List do
		inRange("Achievements", index, row.Key, "Target", row.Target, 1, 100000)
		inRange("Achievements", index, row.Key, "Gems", row.Gems, 0, 100000)
	end
	for field, value in GemRewards :: any do
		if type(value) == "number" then
			inRange("GemRewards", nil, nil, field, value, 0, 100000)
		end
	end
end

local function checkMedia()
	checkKeys("Animations", Animations, KEY_PATTERN)
	for index, row in Animations.List do
		if row.Id ~= "" and not string.match(row.Id, "^rbxassetid://%d+$") then
			fail("Animations", index, row.Key, `Id '{row.Id}' is neither empty nor rbxassetid://<n>`)
		end
		inRange("Animations", index, row.Key, "FadeTime", row.FadeTime, 0, 2)
		inRange("Animations", index, row.Key, "Speed", row.Speed, 0.1, 5)
	end
	for set, roles in Animations.Locomotion :: any do
		const rig = (Animations.SetRig :: any)[set]
		if rig == nil then
			fail("Animations", nil, nil, `Locomotion.{set} has no rig in SetRig`)
		end
		for role, key in roles :: { [string]: string } do
			const row = Animations.ByKey[key]
			if row == nil or row.Rig ~= rig then
				fail("Animations", nil, nil, `Locomotion.{set}.{role} = '{key}' is not a {rig} animation`)
			end
		end
	end

	checkKeys("Sounds", Sounds, KEY_PATTERN)
	for index, row in Sounds.List do
		if row.Id ~= "" and not string.match(row.Id, "^rbxassetid://%d+$") then
			fail("Sounds", index, row.Key, `Id '{row.Id}' is neither empty nor rbxassetid://<n>`)
		end
		inRange("Sounds", index, row.Key, "Volume", row.Volume, 0, 1)
		inRange("Sounds", index, row.Key, "Crossfade", row.Crossfade, 0, 30)
	end
	checkKeys("Music", Sounds.Music, KEY_PATTERN)
	const phases = setOf(Shift.Keys)
	for index, cue in Sounds.Music.List do
		const sound = Sounds.ByKey[cue.Sound]
		if sound == nil or sound.Group ~= "Music" then
			fail("Music", index, cue.Key, `Sound '{cue.Sound}' is not a Music sound`)
		end
		for _, phase in cue.When.Phase or {} do
			if not phases[phase] then
				fail("Music", index, cue.Key, `When.Phase '{phase}' not in Shift`)
			end
		end
		const window = cue.When.Window
		if window ~= nil and (Nights.Windows :: any)[window] == nil then
			fail("Music", index, cue.Key, `When.Window '{window}' not in Nights.Windows`)
		end
	end
	inRange("SoundRules", nil, nil, "MaxVoices", Sounds.Rules.MaxVoices, 1, 64)
	-- shift music pools: Music rows played once (user decision 2026-10-10)
	const rules = Sounds.Rules
	const pools: { { string } } = { rules.ShiftMusic.Day, rules.ShiftMusic.Night }
	for _, pool in pools do
		if #pool == 0 then
			fail("SoundRules", nil, nil, "ShiftMusic pool is empty")
		end
		for _, key in pool do
			const sound = Sounds.ByKey[key]
			if sound == nil or sound.Group ~= "Music" or sound.Looped then
				fail("SoundRules", nil, key, `ShiftMusic '{key}' is not a Music sound with Looped = false`)
			end
		end
	end
	if not phases[rules.ShiftMusicPhase] then
		fail("SoundRules", nil, nil, `ShiftMusicPhase '{rules.ShiftMusicPhase}' not in Shift`)
	end
	inRange("SoundRules", nil, nil, "ShiftMusicFresh", rules.ShiftMusicFresh, 0, 60)
	const beds: { string } = { rules.Ambient.Day, rules.Ambient.Night }
	for _, key in rules.AmbientZones do
		table.insert(beds, key)
	end
	for _, key in beds do
		const sound = Sounds.ByKey[key]
		if sound == nil or sound.Group ~= "Ambient" or not sound.Looped then
			fail("SoundRules", nil, key, `Ambient '{key}' is not a looped Ambient sound`)
		end
	end
	for _, phase in rules.AmbientOff do
		if not phases[phase] then
			fail("SoundRules", nil, nil, `AmbientOff '{phase}' not in Shift`)
		end
	end
	const tension = Sounds.ByKey[rules.Tension.Key]
	if tension == nil or tension.Group ~= "Ambient" or not tension.Looped then
		fail("SoundRules", nil, rules.Tension.Key, `Tension '{rules.Tension.Key}' is not a looped Ambient sound`)
	end
	if (Nights.Windows :: any)[rules.Tension.Window] == nil then
		fail("SoundRules", nil, nil, `Tension.Window '{rules.Tension.Window}' not in Nights.Windows`)
	end
	for field, key in rules.Stings :: any do
		const sound = Sounds.ByKey[key]
		if sound == nil or sound.Looped then
			fail("SoundRules", nil, key, `Stings.{field} '{key}' is not a one-shot sound`)
		end
	end
end

local function checkWave2Records()
	const trailer = Vehicles.ByKey.trailer
	const reminder = if trailer then trailer.Reminder else nil
	if trailer and reminder then
		inRange("Vehicles", nil, "trailer", "Reminder.FirstNight", reminder.FirstNight, trailer.OfferAfterNight, 1000)
		inRange("Vehicles", nil, "trailer", "Reminder.Every", reminder.Every, 1, 100)
	end
	inRange("Trailer", nil, nil, "OfferAfterNight", Trailer.OfferAfterNight, 1, RunParams.Nights - 1)
	inRange("RunParams", nil, nil, "BindingWave", RunParams.BindingWave, 1, 4)
	for index, row in Items.List do
		if row.Use and row.Kind ~= "Consumable" and row.Kind ~= "Revive" then
			fail("Items", index, row.Key, "only Consumable and Revive items have Use")
		end
	end
	const valueTables: { [string]: boolean } =
		{ Ingredients = true, Upgrades = true, Classes = true, Achievements = true, Items = true }
	for index, row in Notices.List do
		inRange("Notices", index, row.Key, "Wave", row.Wave, 1, 4)
		const from = row.ValueFrom
		if from ~= "None" and from ~= "Number" and not valueTables[from] then
			fail("Notices", index, row.Key, `ValueFrom '{from}' unknown`)
		end
		if string.find(row.Text, "{achievement}", 1, true) and from ~= "Achievements" then
			fail("Notices", index, row.Key, "{achievement} needs ValueFrom = Achievements")
		end
	end
end

-- Wave 3 (TASK-096; content-data.md §3.14, §6.10, §6.11) -----------------------------------------------------------

-- T10: the shared anomaly table never carries the answer. These belong to AnomalyService/Rules/ (server only).
const ANOMALY_SERVER_FIELDS: { [string]: boolean } = {
	Verb = true,
	CorrectVerb = true,
	LikelyWrongVerb = true,
	WrongVerb = true,
	Window = true,
	Deadline = true,
	Duration = true,
	Params = true,
	Steps = true,
	IsCritical = true,
	Critical = true,
	Rule = true,
	Rules = true,
}
const ANOMALY_ACTORS: { [string]: boolean } =
	{ Customer = true, Street = true, Vehicle = true, World = true, Audio = true, Item = true }
-- Actors that take a slot on the night cap of anomaly actors (npcs.md: N1, N4, N5, N7, N8)
const ACTOR_COSTS: { [string]: boolean } = { Customer = true, Street = true, Vehicle = true }
const CUE_KINDS: { [string]: boolean } = { Visual = true, Audio = true, Both = true }

local function checkAnomalies()
	checkKeys("Anomalies", Anomalies, "^anm_%d%d%d_[a-z0-9_]+$")
	checkKeys("AnomalyCues", Anomalies.Cues, KEY_PATTERN)
	if #Anomalies.List ~= RunParams.Nights then
		fail("Anomalies", nil, nil, `{#Anomalies.List} rows, one debut per night needs {RunParams.Nights} (DEC-060)`)
	end
	for index, cue in Anomalies.Cues.List do
		if not CUE_KINDS[cue.Kind] then
			fail("AnomalyCues", index, cue.Key, `Kind '{cue.Kind}' is not Visual, Audio or Both`)
		end
		inRange("AnomalyCues", index, cue.Key, "Duration", cue.Duration, 0, 30)
	end

	const debut: { [number]: string } = {}
	const cueUsed: { [string]: boolean } = {}
	const last = Nights.Windows.Last
	local scriptedCost = 0
	for index, row in Anomalies.List do
		const key = row.Key
		for field in row :: any do
			if ANOMALY_SERVER_FIELDS[field] then
				fail("Anomalies", index, key, `field '{field}' is server-only (T10: put it in AnomalyService/Rules/)`)
			end
		end
		inRange("Anomalies", index, key, "Night", row.Night, 1, RunParams.Nights)
		if debut[row.Night] then
			fail("Anomalies", index, key, `second debut on night {row.Night} (first '{debut[row.Night]}')`)
		end
		debut[row.Night] = key
		if row.Ref ~= string.format("ANM-%03d", row.Night) then
			fail("Anomalies", index, key, `Ref '{row.Ref}' must be ANM-00k for debut night k (DEC-096)`)
		end
		if string.sub(key, 5, 7) ~= string.sub(row.Ref, 5, 7) then
			fail("Anomalies", index, key, `key number differs from Ref '{row.Ref}'`)
		end
		if row.Name == "" then
			fail("Anomalies", index, key, "empty Name")
		end
		-- Cart / trailer classification (user request 2026-10-12): the nights before the trailer is offered are cart-only
		if row.Trailer ~= "None" and row.Trailer ~= "Helps" and row.Trailer ~= "Needs" then
			fail("Anomalies", index, key, `Trailer '{tostring(row.Trailer)}' is not None, Helps or Needs`)
		elseif row.Trailer ~= "None" and row.Night <= Trailer.OfferAfterNight then
			fail(
				"Anomalies",
				index,
				key,
				`Trailer {row.Trailer} on night {row.Night}: nights up to {Trailer.OfferAfterNight} are always in the cart and need Trailer None`
			)
		elseif row.Trailer == "Needs" and Anomalies.StandIn(row) == nil then
			fail("Anomalies", index, key, "Trailer Needs without an earlier anomaly with Trailer None to stand in")
		end
		const night = Nights.List[row.Night]
		if night and night.NewAnomaly ~= key then
			fail("Anomalies", index, key, `Nights[{row.Night}].NewAnomaly is '{night.NewAnomaly}'`)
		end
		if not ANOMALY_ACTORS[row.Actor] then
			fail("Anomalies", index, key, `Actor '{row.Actor}' unknown`)
		end
		if row.NpcCost ~= (if ACTOR_COSTS[row.Actor] then 1 else 0) then
			fail("Anomalies", index, key, `NpcCost {row.NpcCost}: Customer/Street/Vehicle cost 1, the rest 0 (npcs.md)`)
		end
		if row.Scope ~= "Party" and row.Scope ~= "PerPlayer" then
			fail("Anomalies", index, key, `Scope '{row.Scope}' is not Party or PerPlayer (DEC-073)`)
		end
		if row.SeeMode == "Cone" then
			inRange("Anomalies", index, key, "ViewRange", row.ViewRange, 1, 1000)
		elseif row.SeeMode == "AudioZone" then
			if row.ViewRange ~= 0 then
				fail("Anomalies", index, key, "ViewRange must be 0 with SeeMode AudioZone")
			end
		else
			fail("Anomalies", index, key, `SeeMode '{row.SeeMode}' is not Cone or AudioZone`)
		end
		for _, other in row.ExclusiveWith do
			const target = Anomalies.ByKey[other]
			if target == nil or other == key then
				fail("Anomalies", index, key, `ExclusiveWith '{other}' is not another anomaly`)
			end
			if not table.find(target.ExclusiveWith, key) then
				fail("Anomalies", index, key, `ExclusiveWith '{other}' is not symmetric`)
			end
		end
		const scripted = row.Scripted
		if scripted then
			if scripted.Night ~= RunParams.Nights then
				fail("Anomalies", index, key, `Scripted only on the last night ({RunParams.Nights}, FEAT-027)`)
			end
			if scripted.Night < row.Night then
				fail("Anomalies", index, key, "Scripted before the debut night")
			end
			if scripted.Clock < last[1] or scripted.Clock >= last[2] then
				fail("Anomalies", index, key, `Scripted.Clock {scripted.Clock} outside Nights.Windows.Last`)
			end
			scriptedCost += row.NpcCost
		end
		if #row.Cues == 0 then
			fail("Anomalies", index, key, "Cues is empty")
		end
		for _, cue in row.Cues do
			if not Anomalies.Cues.ByKey[cue] then
				fail("Anomalies", index, key, `Cue '{cue}' not in AnomalyCues`)
			end
			cueUsed[cue] = true
		end
	end
	for night = 1, RunParams.Nights do
		if debut[night] == nil then
			fail("Anomalies", nil, nil, `night {night} has no debut (one new anomaly per night, DEC-060)`)
		end
	end
	if scriptedCost > Flow.MaxActorsNight then
		fail("Anomalies", nil, nil, `scripted occurrences cost {scriptedCost} actors (cap {Flow.MaxActorsNight})`)
	end
	for index, cue in Anomalies.Cues.List do
		if not cueUsed[cue.Key] then
			fail("AnomalyCues", index, cue.Key, "no anomaly uses this cue")
		end
	end
end

local function checkHallucinations()
	checkKeys("Hallucinations", Hallucinations, KEY_PATTERN)
	const bands = Sanity.Bands
	const effects: { [string]: string } = {}
	local hasHigh, hasMid, hasLow = false, false, false
	for index, row in Hallucinations.List do
		inRange("Hallucinations", index, row.Key, "MaxSanity", row.MaxSanity, 1, bands.High)
		if row.MaxSanity == bands.High then
			hasHigh = true
		elseif row.MaxSanity == bands.Mid then
			hasMid = true
		elseif row.MaxSanity < bands.Mid then
			hasLow = true
		end
		if not string.match(row.Effect, "^[A-Z][A-Za-z0-9]*$") then
			fail("Hallucinations", index, row.Key, `Effect '{row.Effect}' is not a module name`)
		end
		if effects[row.Effect] then
			fail("Hallucinations", index, row.Key, `Effect '{row.Effect}' already used by '{effects[row.Effect]}'`)
		end
		effects[row.Effect] = row.Key
		inRange("Hallucinations", index, row.Key, "Cooldown", row.Cooldown, 0, 3600)
		inRange("Hallucinations", index, row.Key, "Weight", row.Weight, 0.01, 100)
	end
	if not (hasHigh and hasMid and hasLow) then
		fail("Hallucinations", nil, nil, `needs effects below {bands.High}, below {bands.Mid} and lower (FEAT-019)`)
	end
	const interval = Hallucinations.Rules.Interval
	if #interval ~= 2 or interval[1] < 1 or interval[2] < interval[1] then
		fail("HallucinationRules", nil, nil, "Interval must be {min, max} with 1 <= min <= max")
	end
end

const BEAT_KINDS: { [string]: boolean } =
	{ Fade = true, Text = true, MoveTo = true, LookAt = true, Focus = true, Prompt = true, Line = true, Actor = true }
const BEAT_TEXT: { [string]: boolean } = { Text = true, Prompt = true, Line = true }

local function checkCutscenes()
	checkKeys("Cutscenes", Cutscenes, KEY_PATTERN)
	if Cutscenes.Keys[1] ~= "none" then
		fail("Cutscenes", 1, Cutscenes.Keys[1], "first row must be the sentinel 'none'")
	end
	for _, required in { "intro", "finale", "credits" } do
		if not Cutscenes.ByKey[required] then
			fail("Cutscenes", nil, nil, `scene '{required}' is required (FEAT-004, FEAT-027)`)
		end
	end
	for index, row in Cutscenes.List do
		const key = row.Key
		inRange("Cutscenes", index, key, "Cap", row.Cap, 0, 600)
		inRange("Cutscenes", index, key, "Duration", row.Duration, 0, row.Cap)
		if row.Participants ~= "ConnectedAtStart" then
			fail("Cutscenes", index, key, "Participants must be ConnectedAtStart (DEC-205)")
		end
		if key ~= "none" and #row.Marks ~= 4 then
			fail("Cutscenes", index, key, `{#row.Marks} Marks, a party of 4 needs 4`)
		end
		const nextKey = row.Next
		if nextKey ~= nil and (nextKey == key or nextKey == "none" or not Cutscenes.ByKey[nextKey]) then
			fail("Cutscenes", index, key, `Next '{nextKey}' is not another scene`)
		end
		local previous = 0
		for position, beat in row.Beats do
			if not BEAT_KINDS[beat.Kind] then
				fail("Cutscenes", index, key, `Beats[{position}].Kind '{beat.Kind}' unknown`)
			end
			if beat.At < previous or beat.At > row.Duration then
				fail("Cutscenes", index, key, `Beats[{position}].At = {beat.At} out of order or after Duration`)
			end
			previous = beat.At
			if beat.Target == "" then
				fail("Cutscenes", index, key, `Beats[{position}] without Target`)
			end
			if BEAT_TEXT[beat.Kind] and (beat.Text == nil or beat.Text == "") then
				fail("Cutscenes", index, key, `Beats[{position}] ({beat.Kind}) needs Text`)
			end
			const arrive = beat.Arrive
			if arrive ~= nil and (beat.Kind ~= "MoveTo" or arrive < beat.At or arrive > row.Duration) then
				fail("Cutscenes", index, key, `Beats[{position}].Arrive = {arrive}: MoveTo only, between At and Duration`)
			end
			const fov = beat.Fov
			if fov ~= nil and ((beat.Kind ~= "LookAt" and beat.Kind ~= "Focus") or fov < 20 or fov > 100) then
				fail("Cutscenes", index, key, `Beats[{position}].Fov = {fov}: LookAt/Focus only, 20..100`)
			end
		end
	end
	const rules = Cutscenes.Rules
	if #rules.Stand.Slots ~= 4 then
		fail("Cutscenes.Rules", nil, "Stand", `{#rules.Stand.Slots} Stand.Slots, a party of 4 needs 4`)
	end
	inRange("Cutscenes.Rules", nil, "Walk", "MinSpeed", rules.Walk.MinSpeed, 1, rules.Walk.MaxSpeed)
	inRange("Cutscenes.Rules", nil, "Walk", "Accel", rules.Walk.Accel, 1, 100)
	for speaker, voice in rules.Voices do
		inRange("Cutscenes.Rules", nil, speaker, "Voices.Volume", voice.Volume, 0, 1)
	end
	for car, row in rules.Cars do
		if Traffic.Routes.ByKey[row.Route] == nil then
			fail("Cutscenes.Rules", nil, car, `Cars.Route '{row.Route}' is not a Traffic route`)
		end
		if Sounds.ByKey[row.Horn] == nil then
			fail("Cutscenes.Rules", nil, car, `Cars.Horn '{row.Horn}' is not a sound`)
		end
		inRange("Cutscenes.Rules", nil, car, "Cars.Look", row.Look, 1, #Traffic.Looks.Shapes * #Traffic.Looks.Paints)
	end
	const intro = Cutscenes.ByKey.intro
	-- the intro starts after the ClientReady wait (Rules.ReadyTimeout at most), inside the same phase
	const introNeeds = intro.Cap + Cutscenes.Rules.ReadyTimeout
	if introNeeds > Shift.ByKey.Intro.Duration then
		fail(
			"Cutscenes",
			nil,
			"intro",
			`Cap {intro.Cap} + ReadyTimeout {Cutscenes.Rules.ReadyTimeout} above the Intro phase cap ({Shift.ByKey.Intro.Duration} s)`
		)
	end
	-- finale and its Next chain play inside the Finale phase
	local total, hops = 0, 0
	local scene: string? = "finale"
	while scene ~= nil do
		const row = Cutscenes.ByKey[scene]
		total += row.Cap
		hops += 1
		if hops > #Cutscenes.List then
			fail("Cutscenes", nil, "finale", "Next chain loops")
		end
		scene = row.Next
	end
	if total > Shift.ByKey.Finale.Duration then
		fail("Cutscenes", nil, "finale", `finale chain caps sum {total} s, Finale phase cap is {Shift.ByKey.Finale.Duration} s`)
	end
end

const LOOK_MAX = 32 -- Traffic.Look on the wire (TASK-097 widens it from Lync.int(1, 16))

local function checkTraffic()
	checkKeys("Traffic.Routes", Traffic.Routes, "^TR%-%d+$")
	checkKeys("Traffic.Crosswalks", Traffic.Crosswalks, "^CW%-%d+$")
	checkKeys("Traffic.Conflicts", Traffic.Conflicts, "^[A-Z]+%-[A-Z0-9]+$")
	if #Traffic.Routes.List > 32 then
		fail("Traffic.Routes", nil, nil, "more than 32 routes (Traffic.Route = Lync.int(1, 32))")
	end
	for index, row in Traffic.Crosswalks.List do
		if next(row.Lines) == nil then
			fail("Traffic.Crosswalks", index, row.Key, "Lines is empty")
		end
		const linked = row.Linked
		if linked ~= nil then
			const other = Traffic.Crosswalks.ByKey[linked]
			if other == nil or other.Linked ~= row.Key then
				fail("Traffic.Crosswalks", index, row.Key, `Linked '{linked}' does not link back`)
			end
		end
	end

	local hasNightRoute = false
	for index, row in Traffic.Routes.List do
		const key = row.Key
		if row.Path == "" or row.Lane == "" then
			fail("Traffic.Routes", index, key, "Path and Lane are required")
		end
		if row.Shift ~= "Day" and row.Shift ~= "DayNight" then
			fail("Traffic.Routes", index, key, `Shift '{row.Shift}' is not Day or DayNight`)
		end
		inRange("Traffic.Routes", index, key, "Weight", row.Weight, 0.01, 100)
		for _, conflict in row.Conflicts do
			if not Traffic.Conflicts.ByKey[conflict] then
				fail("Traffic.Routes", index, key, `Conflict '{conflict}' not in Traffic.Conflicts`)
			end
		end
		local crossesCw1 = false
		for position, stop in row.Stops do
			if stop.Kind == "Pare" then
				if row.Shift == "DayNight" then
					fail("Traffic.Routes", index, key, "a Ninth route (DayNight) has no PARE (DEC-133)")
				end
				if stop.Ref ~= stop.Line then
					fail("Traffic.Routes", index, key, `Stops[{position}]: a PARE stop has Ref = Line`)
				end
			elseif stop.Kind == "Crosswalk" then
				const cw = Traffic.Crosswalks.ByKey[stop.Ref]
				if cw == nil then
					fail("Traffic.Routes", index, key, `Stops[{position}].Ref '{stop.Ref}' not in Traffic.Crosswalks`)
				end
				local found = false
				for _, line in cw.Lines do
					if line == stop.Line then
						found = true
					end
				end
				if not found then
					fail("Traffic.Routes", index, key, `Stops[{position}].Line '{stop.Line}' is not a line of {stop.Ref}`)
				end
				if stop.Ref == "CW-1" then
					crossesCw1 = true
				end
			else
				fail("Traffic.Routes", index, key, `Stops[{position}].Kind '{stop.Kind}' is not Pare or Crosswalk`)
			end
		end
		const direction = row.JuniperSouth
		if direction ~= nil and ((direction ~= "NB" and direction ~= "SB") or not crossesCw1) then
			fail("Traffic.Routes", index, key, "JuniperSouth must be NB or SB on a route that crosses CW-1")
		end
		if direction == nil and crossesCw1 then
			fail("Traffic.Routes", index, key, "crosses CW-1 without JuniperSouth (its flow is per direction)")
		end
		if row.Shift == "DayNight" then
			hasNightRoute = true
		end
	end

	inRange("Traffic", nil, nil, "MaxCars", Traffic.MaxCars, 1, 8)
	local cursor: number? = nil
	for position, row in Traffic.Density do
		const where = `Density[{position}]`
		if cursor ~= nil and row.From ~= cursor then
			fail("Traffic", nil, nil, `{where}.From = {row.From}, expected {cursor} (contiguous)`)
		end
		if row.To <= row.From then
			fail("Traffic", nil, nil, `{where}: To must be after From`)
		end
		cursor = row.To
		inRange("Traffic", nil, nil, `{where}.MaxCars`, row.MaxCars, 0, Traffic.MaxCars)
		if row.Night and row.MaxCars > 1 then
			fail("Traffic", nil, nil, `{where}: night traffic is rare, at most 1 car (DEC-198)`)
		end
		if row.Night and row.MaxCars > 0 and not hasNightRoute then
			fail("Traffic", nil, nil, `{where}: night cars but no DayNight route`)
		end
		if row.MaxCars > 0 then
			const interval = row.Interval
			if #interval ~= 2 or interval[1] <= 0 or interval[2] < interval[1] then
				fail("Traffic", nil, nil, `{where}.Interval must be min, max with 0 < min <= max`)
			end
		end
	end

	const looks = #Traffic.Looks.Shapes * #Traffic.Looks.Paints
	if looks == 0 or looks > LOOK_MAX then
		fail("Traffic", nil, nil, `{looks} looks (shapes x paints), must be 1..{LOOK_MAX}`)
	end
	for _, reason in { "anm_008", "anm_010", "cutscene" } do
		if not table.find(Traffic.HoldReasons, reason) then
			fail("Traffic", nil, nil, `HoldReasons misses '{reason}' (FEAT-033)`)
		end
	end
	inRange("Traffic", nil, nil, "SpeedStraight", Traffic.SpeedStraight, 1, 100)
	inRange("Traffic", nil, nil, "SpeedCrossing", Traffic.SpeedCrossing, 1, Traffic.SpeedStraight)
	inRange("Traffic", nil, nil, "HitMinSpeed", Traffic.HitMinSpeed, 0, Traffic.SpeedStraight)
	inRange("Traffic", nil, nil, "HitTolerance", Traffic.HitTolerance, 1, 30)
	inRange("Traffic", nil, nil, "KnockTime", Traffic.KnockTime, 0.5, 10)
	inRange("Traffic", nil, nil, "GetUpTime", Traffic.GetUpTime, 0, 5)
	inRange("Traffic", nil, nil, "ImmuneTime", Traffic.ImmuneTime, 0, 60)
	if Traffic.HitsNpcs then
		fail("Traffic", nil, nil, "HitsNpcs must be false (DEC-133)")
	end

	const crossing = Traffic.Crossing
	inRange("Traffic.Crossing", nil, nil, "PareStop", crossing.PareStop, 0.1, 10)
	inRange("Traffic.Crossing", nil, nil, "BrakeDecel", crossing.BrakeDecel, 1, 200)
	const braking = Traffic.SpeedStraight ^ 2 / (2 * crossing.BrakeDecel)
	if crossing.ReserveRadius < braking then
		fail("Traffic.Crossing", nil, nil, `ReserveRadius {crossing.ReserveRadius} below the braking distance {braking}`)
	end
	if crossing.MaxWait < crossing.NpcCrossTime then
		fail("Traffic.Crossing", nil, nil, "MaxWait below NpcCrossTime (the NPC would still be on the road)")
	end
	inRange("Traffic.Crossing", nil, nil, "SpawnMinDist", crossing.SpawnMinDist, 0, 500)
	inRange("Traffic.Crossing", nil, nil, "LaneGap", crossing.LaneGap, 0, 60)
	const south = crossing.JuniperSouthInterval
	if #south ~= 2 or south[1] <= 0 or south[2] < south[1] then
		fail("Traffic.Crossing", nil, nil, "JuniperSouthInterval must be min, max with 0 < min <= max")
	end
end

local function checkWalkPaths()
	-- Rows come from the MAP-01 binding (TASK-098); empty is valid (no wire enum).
	const rules = WalkPaths.Rules
	inRange("WalkPathRules", nil, nil, "MaxPaths", rules.MaxPaths, 1, 255)
	inRange("WalkPathRules", nil, nil, "Slots", rules.Slots, Flow.DayWalkers[2], 255)
	inRange("WalkPathRules", nil, nil, "LodDistance", rules.LodDistance, 10, 1000)
	const speed = rules.Speed
	if #speed ~= 2 or speed[1] < 4 or speed[2] > 12 or speed[2] < speed[1] then
		fail("WalkPathRules", nil, nil, "Speed must be min, max inside 4..12 (Pedestrians.Speed quant)")
	end
	if #WalkPaths.List > rules.MaxPaths then
		fail("WalkPaths", nil, nil, `{#WalkPaths.List} paths, Pedestrians.Path holds {rules.MaxPaths}`)
	end
	const seen: { [string]: boolean } = {}
	for index, row in WalkPaths.List do
		if not string.match(row.Key, KEY_PATTERN) or seen[row.Key] then
			fail("WalkPaths", index, row.Key, "bad or duplicate key")
		end
		seen[row.Key] = true
		if #row.Nodes < 2 then
			fail("WalkPaths", index, row.Key, "a path needs at least 2 nodes")
		end
		for position = 2, #row.Nodes do
			if row.Nodes[position] == row.Nodes[position - 1] then
				fail("WalkPaths", index, row.Key, `Nodes[{position}] repeats the previous node`)
			end
		end
		if row.Shift ~= "Day" and row.Shift ~= "Night" and row.Shift ~= "Any" then
			fail("WalkPaths", index, row.Key, `Shift '{row.Shift}' is not Day, Night or Any`)
		end
		inRange("WalkPaths", index, row.Key, "Weight", row.Weight, 0.01, 100)
	end
end

-- Mart v2 (TASK-135): closed phases exist in Shift; pedestals = every Upgrades.BenchSpot once + the special slot;
-- every pedestal behind at most one door; timings and sizes positive.
-- Pad tables and pairs (TASK-144; FEAT-037, FEAT-038; content-data.md §3.25).
local function checkSeating()
	const name = "Seating"
	const phases = setOf(Shift.PhaseKeys)
	inRange(name, nil, nil, "UnlockDay", Seating.UnlockDay, 1, 100)
	inRange(name, nil, nil, "Tables", Seating.Tables, 1, 16)
	const tables = Upgrades.ByKey[Seating.UpgradeKey]
	if tables == nil or tables.SoldAt ~= "InPlace" or tables.Scope ~= "Pad" then
		fail(name, nil, nil, `UpgradeKey '{Seating.UpgradeKey}' must be an InPlace upgrade with Scope Pad`)
	end
	-- Groups: contiguous TableIndex 1..Tables, each with its own InPlace upgrade whose last level buys them all
	local expectedFirst = 1
	for _, group in Seating.Groups do
		if group.First ~= expectedFirst or group.Count < 1 then
			fail(name, nil, nil, `Groups '{group.Key}': First {group.First} must continue the previous group ({expectedFirst}) with Count >= 1`)
		end
		expectedFirst = group.First + group.Count
		const upgrade = Upgrades.ByKey[group.UpgradeKey]
		if upgrade == nil or upgrade.SoldAt ~= "InPlace" then
			fail(name, nil, nil, `Groups '{group.Key}': UpgradeKey '{group.UpgradeKey}' must be an InPlace upgrade`)
		end
		if not Stats.Has[group.Stat] then
			fail(name, nil, nil, `Groups '{group.Key}': Stat '{group.Stat}' is not a key of Stats`)
		end
		for _, vehicle in group.Vehicles do
			const levels = upgrade.Levels[vehicle]
			if levels == nil then
				fail(name, nil, nil, `Groups '{group.Key}': upgrade '{group.UpgradeKey}' has no levels on '{vehicle}'`)
			end
			if (levels[#levels].Effects :: any)[group.Stat] ~= group.Count then
				fail(name, nil, nil, `Groups '{group.Key}': max {group.Stat} on {vehicle} must be Count ({group.Count})`)
			end
		end
	end
	if expectedFirst - 1 ~= Seating.Tables then
		fail(name, nil, nil, `Groups cover {expectedFirst - 1} tables, Tables is {Seating.Tables}`)
	end
	if Seating.Groups[1].UpgradeKey ~= Seating.UpgradeKey then
		fail(name, nil, nil, "Groups[1] is the Pad group: its UpgradeKey must be Seating.UpgradeKey")
	end
	const lights = Upgrades.ByKey[Seating.LightsKey]
	if lights == nil or lights.SoldAt ~= "InPlace" then
		fail(name, nil, nil, `LightsKey '{Seating.LightsKey}' must be an InPlace upgrade`)
	end
	const eat = Seating.EatTime
	inRange(name, nil, nil, "EatTime.Day", eat.Day, 1, 120)
	inRange(name, nil, nil, "EatTime.Night", eat.Night, 1, 120)
	inRange(name, nil, nil, "EatTime.GroupExtra", eat.GroupExtra, 0, 60)
	inRange(name, nil, nil, "EatTime.Jitter", eat.Jitter, 0, math.min(eat.Day, eat.Night) - 1)
	inRange(name, nil, nil, "TableTip", Seating.TableTip, 0, 100)
	inRange(name, nil, nil, "MaxTip", Seating.MaxTip, Seating.TableTip * 2, 65535)
	inRange(name, nil, nil, "MaxDiners.Day", Seating.MaxDiners.Day, 0, Flow.MaxCustomersDay)
	inRange(name, nil, nil, "MaxDiners.Night", Seating.MaxDiners.Night, 0, Flow.MaxCustomersNight)
	inRange(name, nil, nil, "SitHeadroom", Seating.SitHeadroom, 0, Flow.MaxCustomersNight)
	inRange(name, nil, nil, "NightSitMult", Seating.NightSitMult, 0, 1)
	inRange(name, nil, nil, "GroupSitBonus", Seating.GroupSitBonus, 0, 1)
	inRange(name, nil, nil, "SitChanceCap", Seating.SitChanceCap, 0, 1)
	inRange(name, nil, nil, "GhostTransparency", Seating.GhostTransparency, 0, 1)
	inRange(name, nil, nil, "GhostDimTransparency", Seating.GhostDimTransparency, Seating.GhostTransparency, 1)
	inRange(name, nil, nil, "StandTimeout", Seating.StandTimeout, 1, 120)
	inRange(name, nil, nil, "WalkTimeout", Seating.WalkTimeout, 1, 30)
	inRange(name, nil, nil, "Approach", Seating.Approach, 0, 10)
	const holds: { [string]: number } = { buy_in_place = Seating.BuyHold, clean_table = Seating.CleanHold }
	for key, hold in holds do
		const action = Actions.ByKey[key]
		if action == nil then
			fail(name, nil, nil, `Actions.{key} missing`)
		end
		if action.Hold ~= hold or action.Radius ~= Seating.PromptRadius then
			fail(name, nil, nil, `Actions.{key} Hold/Radius differ from Seating (BuyHold/CleanHold, PromptRadius)`)
		end
	end
	if not Notices.ByKey.table_added then
		fail(name, nil, nil, "Notices.table_added missing")
	end
	for _, phase in Seating.SitPhases do
		if not phases[phase] then
			fail(name, nil, nil, `SitPhases '{phase}' is not a Shift phase`)
		end
	end
	for _, key in Seating.TensionAnomalies do
		if not Anomalies.ByKey[key] then
			fail(name, nil, nil, `TensionAnomalies '{key}' not in Anomalies`)
		end
	end
	if #Seating.States ~= 5 then
		fail(name, nil, nil, "States must be Locked, Ghost, Free, Occupied, Dirty")
	end
	if #Seating.Seats.Solo ~= 1 or #Seating.Seats.Pair ~= 2 or #Seating.Seats.Couple ~= 2 then
		fail(name, nil, nil, "Seats: Solo needs 1 seat, Pair and Couple 2")
	end
	for _, list in { Seating.Seats.Solo, Seating.Seats.Pair, Seating.Seats.Couple } do
		for _, seat in list do
			inRange(name, nil, nil, "Seats", seat, 1, Seating.Binding.SeatCount)
		end
	end
	for index, row in CustomerTypes.List do
		inRange("CustomerTypes", index, row.Key, "SitChance", row.SitChance, 0, 1)
	end

	-- Flow.Groups (FEAT-038)
	const groups = Flow.Groups
	const g = "Flow.Groups"
	inRange(g, nil, nil, "ChanceDay", groups.ChanceDay, 0, 1)
	inRange(g, nil, nil, "ChanceNight", groups.ChanceNight, 0, 1)
	inRange(g, nil, nil, "FromDay", groups.FromDay, 1, 10000)
	inRange(g, nil, nil, "FromNight", groups.FromNight, 1, 10)
	inRange(g, nil, nil, "IntervalMult", groups.IntervalMult, 1, 5)
	inRange(g, nil, nil, "PatienceBonus", groups.PatienceBonus, 0, 120)
	inRange(g, nil, nil, "PartnerSpeedMult", groups.PartnerSpeedMult, 1, 3)
	inRange(g, nil, nil, "Leash", groups.Leash, 1, 50)
	-- Flow.Adopt (TASK-163, Provisional)
	const adopt = Flow.Adopt
	const a = "Flow.Adopt"
	inRange(a, nil, nil, "ChanceDay", adopt.ChanceDay, 0, 1)
	inRange(a, nil, nil, "ChanceNight", adopt.ChanceNight, 0, 1)
	inRange(a, nil, nil, "FromDay", adopt.FromDay, 1, 10000)
	inRange(a, nil, nil, "FromNight", adopt.FromNight, 0, 10)
	inRange(a, nil, nil, "MaxDistance", adopt.MaxDistance, 0, 200)
	inRange(a, nil, nil, "MinGapSeconds", adopt.MinGapSeconds, 0, 600)
	inRange(a, nil, nil, "NoticeLead", adopt.NoticeLead, 0, 5)
	inRange(a, nil, nil, "Beat", adopt.Beat, 0, 5)
	-- Flow.Guarantee (Q-202, Provisional): limits in seconds; Day 1 never waits longer than later days
	const guarantee = Flow.Guarantee
	const gu = "Flow.Guarantee"
	inRange(gu, nil, nil, "MaxEmpty", guarantee.MaxEmpty, 1, 120)
	inRange(gu, nil, nil, "MaxEmptyDay1", guarantee.MaxEmptyDay1, 1, guarantee.MaxEmpty)
	inRange(gu, nil, nil, "Spread", guarantee.Spread, 0, 30)
	-- Day length (Q-200): a day shift (Prep + Open + Closing + Summary) must stay a short turn, and the flow must
	-- bring at least 8 customers in the open shop on Day 1 (mean interval x jitter)
	const openRow = Shift.ByKey.Open
	if Flow.BaseInterval > 0 and openRow.Duration / Flow.BaseInterval < 8 then
		fail("Flow", nil, nil, `Open {openRow.Duration} s / BaseInterval {Flow.BaseInterval} s brings fewer than 8 customers on Day 1`)
	end
	const dayTurn = Shift.ByKey.Prep.Duration
		+ openRow.Duration
		+ Shift.ByKey.Closing.Duration
		+ Shift.ByKey.Summary.Duration
	if dayTurn > 330 then
		fail("Shift", nil, nil, `day turn is {dayTurn} s (Prep + Open + Closing + Summary): playtest target is ~270 s, cap 330`)
	end
	if #adopt.FirstDelay ~= 2 or adopt.FirstDelay[1] > adopt.FirstDelay[2] then
		fail(a, nil, nil, "FirstDelay must be {min, max} with min <= max")
	end
	for _, value in adopt.FirstDelay do
		inRange(a, nil, nil, "FirstDelay", value, 0, 600)
	end
	for index, pair in groups.Pairs do
		const label = `{pair.Leader}+{pair.Partner}`
		const leader = CustomerTypes.ByKey[pair.Leader]
		const partner = CustomerTypes.ByKey[pair.Partner]
		if leader == nil or partner == nil or leader.Role ~= "Customer" or partner.Role ~= "Customer" then
			fail("Flow.Groups.Pairs", index, label, "Leader and Partner must be customer types")
		end
		if pair.Shift ~= "Day" and pair.Shift ~= "Night" then
			fail("Flow.Groups.Pairs", index, label, `Shift '{tostring(pair.Shift)}' is not Day or Night`)
		end
		inRange("Flow.Groups.Pairs", index, label, "Weight", pair.Weight, 0, 1000)
		for _, kind in { leader, partner } do
			if kind.Shift ~= "Any" and kind.Shift ~= pair.Shift then
				fail("Flow.Groups.Pairs", index, label, `{kind.Key} never comes on the {pair.Shift} shift`)
			end
		end
		-- every leader species leaves the partner another species (night) or another outfit (day)
		for _, species in leader.Species do
			local other = false
			for _, candidate in partner.Species do
				if candidate ~= species then
					other = true
				end
			end
			if not other and (pair.Shift == "Night" or #partner.Outfits < 2) then
				fail("Flow.Groups.Pairs", index, label, `no valid partner look when the leader is a {species}`)
			end
		end
	end
end

local function checkMart()
	const phases = setOf(Shift.PhaseKeys)
	const closed: { [string]: boolean } = {}
	for _, phase in Mart.KioskClosedPhases do
		if not phases[phase] then
			fail("Mart", nil, nil, `KioskClosedPhases '{phase}' is not a Shift phase`)
		end
		if closed[phase] then
			fail("Mart", nil, nil, `KioskClosedPhases '{phase}' repeated`)
		end
		closed[phase] = true
	end

	const spots: { [string]: boolean } = {}
	for _, upgrade in Upgrades.List do
		if upgrade.SoldAt == "Bench" then
			spots[upgrade.BenchSpot] = true
		end
	end
	const pedestals: { [string]: boolean } = {}
	local specials = 0
	for index, row in Mart.Pedestals do
		if pedestals[row.Slot] then
			fail("Mart", index, row.Slot, "pedestal Slot repeated")
		end
		pedestals[row.Slot] = true
		if row.Offer == "Upgrade" then
			if not spots[row.Slot] then
				fail("Mart", index, row.Slot, "Offer Upgrade but no Upgrades row has this BenchSpot")
			end
		elseif row.Offer == "Special" then
			specials += 1
		else
			fail("Mart", index, row.Slot, `Offer '{tostring(row.Offer)}' is not Upgrade or Special`)
		end
	end
	for spot in spots do
		if not pedestals[spot] then
			fail("Mart", nil, nil, `Upgrades BenchSpot '{spot}' has no pedestal`)
		end
	end
	if specials ~= 1 then
		fail("Mart", nil, nil, `{specials} Special pedestals (need 1, FEAT-035 S1)`)
	end

	const covered: { [string]: string } = {}
	const doorKeys: { [string]: boolean } = {}
	for index, door in Mart.Doors do
		if door.Key == "" or doorKeys[door.Key] then
			fail("Mart", index, door.Key, "door Key empty or repeated")
		end
		doorKeys[door.Key] = true
		for _, slot in door.Pedestals do
			if not pedestals[slot] then
				fail("Mart", index, door.Key, `pedestal '{slot}' is not in Pedestals`)
			end
			if covered[slot] then
				fail("Mart", index, door.Key, `pedestal '{slot}' already behind door {covered[slot]}`)
			end
			covered[slot] = door.Key
		end
	end

	inRange("Mart", nil, nil, "Door.CloseTime", Mart.Door.CloseTime, 0.1, 10)
	inRange("Mart", nil, nil, "Door.OpenTime", Mart.Door.OpenTime, 0.1, 10)
	inRange("Mart", nil, nil, "Door.Stagger", Mart.Door.Stagger, 0, 2)
	inRange("Mart", nil, nil, "Mini.Size", Mart.Mini.Size, 0.2, 5)
	inRange("Mart", nil, nil, "Mini.Lift", Mart.Mini.Lift, 0, 5)
	inRange("Mart", nil, nil, "Mini.Bob", Mart.Mini.Bob, 0, 2)
	inRange("Mart", nil, nil, "Mini.BobPeriod", Mart.Mini.BobPeriod, 0.1, 30)
	inRange("Mart", nil, nil, "Mini.SpinPeriod", Mart.Mini.SpinPeriod, 0.1, 60)
	inRange("Mart", nil, nil, "Mini.ActiveRadius", Mart.Mini.ActiveRadius, 1, 500)
	inRange("Mart", nil, nil, "Mini.LockedTransparency", Mart.Mini.LockedTransparency, 0, 1)
	inRange("Mart", nil, nil, "Purchase.PopTime", Mart.Purchase.PopTime, 0.05, 5)
	inRange("Mart", nil, nil, "Purchase.PopScale", Mart.Purchase.PopScale, 1, 3)
	inRange("Mart", nil, nil, "Purchase.PopTurns", Mart.Purchase.PopTurns, 0, 10)
	inRange("Mart", nil, nil, "Purchase.Confetti", Mart.Purchase.Confetti, 0, 100)
	inRange("Mart", nil, nil, "Purchase.RiseDelay", Mart.Purchase.RiseDelay, 0, 5)
	inRange("Mart", nil, nil, "Purchase.RiseTime", Mart.Purchase.RiseTime, 0.05, 5)
	inRange("Mart", nil, nil, "Purchase.OpalLineGap", Mart.Purchase.OpalLineGap, 0, 600)
	inRange("Mart", nil, nil, "Purchase.OpalLineRadius", Mart.Purchase.OpalLineRadius, 0, 100)
	inRange("Mart", nil, nil, "Plate.Distance", Mart.Plate.Distance, 1, 500)
	inRange("Mart", nil, nil, "Plate.Lift", Mart.Plate.Lift, 0.5, 6)
	inRange("Mart", nil, nil, "Plate.Width", Mart.Plate.Width, 120, 400)
	-- Gear Stand cooldown (Q-203): whole shifts, 2 = one full shift off; the wire field Upgrades.Wait is 0..255
	inRange("Mart", nil, nil, "Cooldown.Turns", Mart.Cooldown.Turns, 1, 20)
	if Mart.Cooldown.Turns ~= math.floor(Mart.Cooldown.Turns) then
		fail("Mart", nil, nil, "Cooldown.Turns must be a whole number of shifts")
	end
	inRange("Mart", nil, nil, "Hint.Reach", Mart.Hint.Reach, 1, 100)
	const hinted: { [string]: boolean } = {}
	for _, phase in Mart.Hint.Phases do
		if not phases[phase] then
			fail("Mart", nil, nil, `Hint.Phases '{phase}' is not a Shift phase`)
		elseif Shift.ByKey[phase].Selling then
			fail("Mart", nil, nil, `Hint.Phases '{phase}' is a selling phase: the hint is for the end of the shift`)
		end
		if hinted[phase] then
			fail("Mart", nil, nil, `Hint.Phases '{phase}' repeated`)
		end
		hinted[phase] = true
	end
	inRange("Mart", nil, nil, "Fallback.DoorHeight", Mart.Fallback.DoorHeight, 1, 30)
	if Mart.Tags.Pedestal == "" or Mart.Tags.Shutter == "" or Mart.Tags.Slot == "" then
		fail("Mart", nil, nil, "Tags must not be empty")
	end
end

-- HudController asks for exactly these keys (src/Hud/client/HudController.luau)
const HUD_REVEAL_REQUIRED: { string } = { "clock", "order_card", "toasts", "money", "shift", "sanity" }

local function checkHudReveal()
	for index, row in HudReveal.List do
		if row.Trigger ~= "Start" and row.Trigger ~= "Step" and row.Trigger ~= "TutorialEnd" and row.Trigger ~= "Night" then
			fail("HudReveal", index, row.Key, `Trigger '{tostring(row.Trigger)}' is not Start, Step, TutorialEnd or Night`)
		end
		if row.Trigger == "Step" then
			if not string.match(row.Step, KEY_PATTERN) then
				fail("HudReveal", index, row.Key, `Trigger Step needs a tutorial step key, got '{row.Step}'`)
			end
		elseif row.Step ~= "" then
			fail("HudReveal", index, row.Key, "Step is only for Trigger Step")
		end
		if row.Trigger == "Night" then
			inRange("HudReveal", index, row.Key, "Night", row.Night, 1, 99)
		elseif row.Night ~= 0 then
			fail("HudReveal", index, row.Key, "Night is only for Trigger Night")
		end
		if row.Pulse and row.Trigger ~= "Night" then
			fail("HudReveal", index, row.Key, "Pulse is only for Trigger Night")
		end
	end
	for _, key in HUD_REVEAL_REQUIRED do
		if HudReveal.ByKey[key] == nil then
			fail("HudReveal", nil, nil, `missing row '{key}' (HudController needs it)`)
		end
	end
end

return function()
	checkKeySets()
	checkHudReveal()
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
	checkShiftWave2()
	checkBossCalls()
	checkNights()
	checkLightsAndSanity()
	checkThiefAndRewards()
	checkMedia()
	checkWave2Records()
	checkAnomalies()
	checkHallucinations()
	checkCutscenes()
	checkTraffic()
	checkWalkPaths()
	checkMart()
	checkSeating()
end
