--!strict
-- Kitchen core: stations, stock and Restock (FEAT-006, FEAT-007; DEC-049, DEC-071, DEC-184; architecture.md §18.4,
-- §18.12 T37; network.md §3.4, §3.5; data.md §2.2, §3.3; content-data.md §3.3, §3.6; TASK-025). Run place only.
-- Single writer of the Stock set (record id = Content.Ingredients.IndexOf[key], always the 9 ingredients) and of the
-- Stations set (record id = StationId * 100 + Slot, written from Station.Records of the station modules).
-- Stations are found by tag Station inside a tag Vehicle; each StationKind is run by a module in Stations/*.luau
-- (StationApi.Module, discovered here: TASK-026/027/028 add files without touching this one). "restock" is ours.
-- Stock: Amount per ingredient (atom); Capacity = Ingredients[k].Capacity[Cooler level of the current vehicle]
-- (DEC-184) and Blocked = Day < UnlockDay or another vehicle are derived, never stored. Snapshot "Stk" = Amounts
-- (data.md §3.3); "Stn" = what each module's Capture returns (nil = the station restarts empty, data.md §2.2).
-- Public reads for other services (Customer order draw, Market "Out of stock"): GetStock, GetCapacity, IsBlocked,
-- Stock; write: TakeStock. The free package of the unlock day is TASK-046 (board N-03), not here.
-- Wave 2 (TASK-057; architecture.md §19.5, T36, T60; DEC-184, DEC-200):
--   * VehicleService.Swapped (connected in OnStart) -> Stock set (Capacity at the new Cooler, Blocked: coffee opens in
--     the trailer) and prompts: the old vehicle's anchors off, the new one's back to what its module last asked for
--     (Wanted, kept by Context.SetPrompt). Amount passes whole: above the new capacity it stays (Q-169 A,
--     Provisional) and reads as e.g. 30/12; Restock is refused until it drops below capacity.
--   * Restock of a full ingredient -> Notice stock_full {item} (D-04), throttled by Refusal like the station toasts.
--   * Street bin: anchor Prompt_Discard (discard) inside a Model tagged StreetBin, outside any Station/Vehicle. Own
--     branch in Evaluate (no IsCurrent, no station lock), same hand rule as BIN-C (Trash.Discardable; Q-166 a
--     Provisional: hot dog only), Consume without refund, nothing recorded.
-- Wave 3 (TASK-109; architecture.md §19.3, §19.13; network.md §13.5; ANM-002, ITM-020; Provisional):
--   * Alter(kind, slot?) -> boolean: one altered item on the current vehicle's "rail" (gray sausage at the front) or
--     "board" (bitten bun, sliced). Only in phase Night; false = no room / already one / station busy (retry later).
--     ClearAltered() removes them; it also runs by itself when the phase leaves Night (ITM-020: gone at 6:00 AM).
--     HasAltered(kind?) reads it. Stations set field Altered (0..30) is written from Record.Altered.
--   * A hot dog made with an altered item carries the Tool attribute Altered = true (Board.luau via Context.Give).
--   * Discarded(player, item, altered, where) after every Throw Away that removed the Tool (BIN-C "Vehicle", street
--     bin "Street"). Emitted(name, player, data) relays Context.Emit ("assembled"). Both fire deferred, outside the
--     station lock, so a listener may call Alter/ClearAltered.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Charm = require(ReplicatedStorage.Packages.Charm)
local Content = require(ReplicatedStorage.shared.Content)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local StationApi = require(script.StationApi)
local Refusal = require(script.Refusal)
local Trash = require(script.Stations.Trash)
local Modux = require(ServerScriptService.server.Modux)

-- [ingredient key] = units in stock. Frozen: the atom holds immutable tables.
export type Amounts = { [string]: number }
export type StockRecord = { Amount: number, Capacity: number, Blocked: boolean }

-- What a module last asked for an anchor (restored when its vehicle becomes the current one again).
type Wanted = { Enabled: boolean, Text: string? }

-- Wave 3 (TASK-109): kinds an anomaly may alter (AnomalyService Context.Kitchen.Alter).
export type AlterKind = "rail" | "board"
export type DiscardWhere = "Vehicle" | "Street"

const STATION_TAG = "Station"
const VEHICLE_TAG = "Vehicle"
const ANCHOR_TAG = "Interactable"
const BIN_TAG = "StreetBin"
const RESTOCK = "restock"
const DISCARD = "discard"
const STOCK_FULL = "stock_full"
const PACKAGE = "Package"
const COOLER_STAT = "StockCapacityLevel"
const UNLOCK_NOTICE = "ingredient_unlocked"
const MAX_STATION_ID = 99 -- network.md §1 rule 5
const SLOT_FACTOR = 100 -- record id = StationId * 100 + Slot
const MAX_SLOT = 99
const AMOUNT_MAX = 999 -- Stock.Amount / Capacity wire range (network.md §3.4)
const DURATION_MAX = 120 -- Stations.Duration wire range (network.md §3.5)
const COUNT_MAX = 30 -- Stations.Count wire range
const TICK_RATE = 10 -- station timers (architecture.md §18.12)
const ALTER_PHASE = "Night" -- altered items only exist while the night is being played (ITM-020)
const ALTER_KINDS: { [string]: boolean } = { rail = true, board = true }
const HOT_DOG = "hot_dog"

-- Package Tool item key -> package row (what a held package restocks).
const packageByItem: { [string]: Content.Package } = {}
for _, package in Content.Packages.List do
	packageByItem[package.Item] = package
end

local function fail(message: string)
	if RunService:IsStudio() then
		error(message, 0)
	end
	warn(message)
end

local function capacityAt(row: Content.Ingredient, level: number): number
	const capacity = row.Capacity
	if #capacity == 0 then
		return 0
	end
	return capacity[math.clamp(math.floor(level), 1, #capacity)]
end

-- Ingredient not unlocked on `day` or tied to another vehicle (content-data.md §3.3; coffee: trailer only).
local function blockedOn(row: Content.Ingredient, day: number, vehicle: string): boolean
	if row.UnlockDay > 0 and day < row.UnlockDay then
		return true
	end
	return row.Vehicle ~= nil and row.Vehicle ~= vehicle
end

-- Run start: full at Cooler 1 for what is open on Day 1 with the starting vehicle (DEC-049, RunParams.StartStockFull);
-- 0 for what unlocks later (Provisional: the unlock day brings its free package, DEC-071 / TASK-046).
local function startAmounts(): Amounts
	const out: Amounts = {}
	for _, row in Content.Ingredients.List do
		const open = not blockedOn(row, 1, Content.RunParams.StartVehicle)
		out[row.Key] = if open and Content.RunParams.StartStockFull then capacityAt(row, 1) else 0
	end
	return table.freeze(out)
end

-- Module calls are wrapped in pcall: one broken station never stops the others.
local function report(label: string, ok: boolean, err: any)
	if not ok then
		warn(`[KitchenService] {label} errored: {err}`)
	end
end

local function wholeNumber(value: any, low: number, high: number): number
	if type(value) ~= "number" or value ~= value then
		return low
	end
	return math.clamp(math.floor(value), low, high)
end

const KitchenService = Modux.Service("KitchenService", {
	Require = {
		"PlaceService",
		"NetService",
		"RunStateService",
		"RoundService",
		"InteractionService",
		"ItemService",
		"ClassService",
		"UpgradeService",
		"VehicleService",
	},
	Priority = 650,
})

function KitchenService:Setup()
	self.Active = false :: boolean
	self.Amounts = self.Libs.Charm.atom(startAmounts()) :: Charm.Atom<Amounts>
	-- Modules by StationKind; ModuleNames = StationKind -> file name (duplicate check)
	self.Modules = {} :: { [string]: StationApi.Module }
	self.ModuleNames = {} :: { [string]: string }
	-- Stations by StationId and by Model
	self.Stations = {} :: { [number]: StationApi.Station }
	self.ByInstance = {} :: { [Instance]: StationApi.Station }
	-- Stations record id -> StationId that owns it
	self.Published = {} :: { [number]: number }
	-- StationId -> threads waiting their turn (Serialize)
	self.Locks = {} :: { [number]: { thread } }
	-- Anchors switched off because their vehicle is not the current one
	self.Gated = {} :: { [Instance]: boolean }
	-- Last prompt state a module asked for, by station anchor
	self.Wanted = {} :: { [Instance]: Wanted }
	-- Street bin Models (tag StreetBin, outside any Station)
	self.Bins = {} :: { [Instance]: boolean }
	-- Blocked at the last ShiftStarted (ingredient_unlocked)
	self.WasBlocked = {} :: { [string]: boolean }
	self.Warned = {} :: { [string]: boolean }
	-- Amount of an ingredient changed (ingredient, amount). For services that react to stock (wave 2+).
	self.StockChanged = self.Libs.Signal.new() :: SignalLib.Signal<string, number>
	-- Wave 3 (TASK-109). Throw Away removed a Tool: (player, item key, Altered attribute, "Vehicle" | "Street").
	self.Discarded = self.Libs.Signal.new() :: SignalLib.Signal<Player, string, boolean, DiscardWhere>
	-- Wave 3 (TASK-109). Context.Emit of a station module: (event name, player or nil, data or nil).
	self.Emitted = self.Libs.Signal.new() :: SignalLib.Signal<string, Player?, { [string]: any }?>
	self.Context = self:BuildContext() :: StationApi.Context
end

-- Stock reads ---------------------------------------------------------------------------------------------------

function KitchenService:GetVehicle(): string
	return self.Dependencies.UpgradeService:GetVehicle()
end

-- Capacity at the Cooler level of the current vehicle (DEC-184). Unknown ingredient = 0.
function KitchenService:GetCapacity(ingredient: string): number
	const row = Content.Ingredients.ByKey[ingredient]
	if row == nil then
		return 0
	end
	const level = self.Dependencies.UpgradeService:GetEffect(COOLER_STAT)
	return math.min(capacityAt(row, level), AMOUNT_MAX)
end

function KitchenService:IsBlocked(ingredient: string): boolean
	const row = Content.Ingredients.ByKey[ingredient]
	if row == nil then
		return true
	end
	return blockedOn(row, self.Dependencies.RoundService:GetDay(), self:GetVehicle())
end

-- (current, capacity). Current can read above capacity after the swap to a vehicle with a smaller Cooler (Q-169 A,
-- Provisional): nothing paid is lost, Restock waits until it drops below capacity.
function KitchenService:GetStock(ingredient: string): (number, number)
	const capacity = self:GetCapacity(ingredient)
	const amount = self.Amounts()[ingredient] or 0
	return amount, capacity
end

function KitchenService:Stock(ingredient: string): StockRecord
	const amount, capacity = self:GetStock(ingredient)
	return { Amount = amount, Capacity = capacity, Blocked = self:IsBlocked(ingredient) }
end

-- Stock writes --------------------------------------------------------------------------------------------------

function KitchenService:SetAmount(ingredient: string, amount: number)
	const amounts = self.Amounts()
	const value = wholeNumber(amount, 0, AMOUNT_MAX)
	if amounts[ingredient] == value then
		return
	end
	const nextAmounts = table.clone(amounts)
	nextAmounts[ingredient] = value
	self.Amounts(table.freeze(nextAmounts))
	self.StockChanged:Fire(ingredient, value)
end

-- Takes n units if all of them are there and the ingredient is open. Synchronous: two callers in the same frame can
-- never take the same unit.
function KitchenService:TakeStock(ingredient: string, n: number): boolean
	if Content.Ingredients.ByKey[ingredient] == nil or type(n) ~= "number" or n ~= n or n < 1 then
		return false
	end
	const count = math.floor(n)
	if self:IsBlocked(ingredient) then
		return false
	end
	const amount = self:GetStock(ingredient)
	if amount < count then
		return false
	end
	self:SetAmount(ingredient, amount - count)
	return true
end

-- Stations ------------------------------------------------------------------------------------------------------

-- Requires every ModuleScript of script.Stations; one module per StationKind (repeated Kind = error).
function KitchenService:LoadModules()
	const folder = script:FindFirstChild("Stations")
	if folder == nil then
		return
	end
	const children = folder:GetChildren()
	table.sort(children, function(a: Instance, b: Instance): boolean
		return a.Name < b.Name
	end)
	for _, child in children do
		if not child:IsA("ModuleScript") then
			continue
		end
		const ok, value = pcall((require :: any), child)
		if not ok then
			fail(`[KitchenService] Stations/{child.Name} failed to load: {value}`)
			continue
		end
		const module, problem = StationApi.check(child.Name, value, Content.Stations.ByKey, Content.Actions.ByKey)
		if module == nil then
			fail(`[KitchenService] Stations/{problem}`)
			continue
		end
		for _, kind in module.Kinds do
			const owner = self.ModuleNames[kind]
			if owner ~= nil then
				error(`[KitchenService] StationKind "{kind}" is in Stations/{owner} and Stations/{child.Name}`, 0)
			end
			self.Modules[kind] = module
			self.ModuleNames[kind] = child.Name
		end
	end
end

-- One RegisterAction per action key (union of all modules + restock), architecture.md §18.12 step 1.
function KitchenService:RegisterActions()
	const keys: { [string]: boolean } = { [RESTOCK] = true }
	for _, module in self.Modules do
		for key in module.Actions do
			keys[key] = true
		end
	end
	const interaction = self.Dependencies.InteractionService
	for key in keys do
		interaction:RegisterAction(key, {
			Validate = function(player: Player, anchor: Instance, _id: number): boolean
				const ok, notice, value = self:Evaluate(key, player, anchor)
				if not ok and notice ~= nil then
					Refusal.notify(self.Context, player, notice, value)
				end
				return ok
			end,
			Run = function(player: Player, anchor: Instance, _id: number)
				self:Perform(key, player, anchor)
			end,
		})
	end
end

-- Owner of an anchor (or any descendant): nearest ancestor registered as a Station.
function KitchenService:StationOf(instance: Instance): StationApi.Station?
	local current: Instance? = instance
	while current ~= nil do
		const station = self.ByInstance[current]
		if station ~= nil then
			return station
		end
		current = current.Parent
	end
	return nil
end

function KitchenService:IsCurrent(station: StationApi.Station): boolean
	return station.Vehicle == self:GetVehicle()
end

function KitchenService:VehicleOf(model: Model): string?
	local current = model.Parent
	while current ~= nil and current ~= workspace do
		if CollectionService:HasTag(current, VEHICLE_TAG) then
			const vehicle = current:GetAttribute("Vehicle")
			if type(vehicle) == "string" and Content.Vehicles.ByKey[vehicle] ~= nil then
				return vehicle
			end
			return nil
		end
		current = current.Parent
	end
	return nil
end

-- Nearest Station ancestor of a descendant (anchor ownership, architecture.md §18.3).
local function ownerModel(instance: Instance): Instance?
	local current = instance.Parent
	while current ~= nil do
		if CollectionService:HasTag(current, STATION_TAG) then
			return current
		end
		current = current.Parent
	end
	return nil
end

-- Anchors and slot attachments of the station. A slot attachment with Level only counts on that level of the
-- upgrade whose key is the StationKind (grill); one without Level counts on every level (architecture.md §18.2).
function KitchenService:CollectParts(station: StationApi.Station)
	const model = station.Instance
	const upgrade = Content.Upgrades.ByKey[station.Kind]
	const level = if upgrade then self.Dependencies.UpgradeService:GetLevel(upgrade.Key, station.Vehicle) else nil
	const anchors: { Instance } = {}
	const slots: { [number]: Attachment } = {}
	const exact: { [number]: boolean } = {}
	for _, child in model:GetDescendants() do
		if ownerModel(child) ~= model then
			continue
		end
		if CollectionService:HasTag(child, ANCHOR_TAG) then
			table.insert(anchors, child)
		end
		if not child:IsA("Attachment") then
			continue
		end
		const slot = child:GetAttribute("Slot")
		if type(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > MAX_SLOT then
			continue
		end
		const only = child:GetAttribute("Level")
		if type(only) == "number" then
			if level ~= nil and only == level then
				slots[slot] = child
				exact[slot] = true
			end
		elseif not exact[slot] then
			slots[slot] = child
		end
	end
	station.Anchors = anchors
	station.Slots = slots
end

function KitchenService:FreeId(): number?
	for id = 1, MAX_STATION_ID do
		if self.Stations[id] == nil then
			return id
		end
	end
	return nil
end

-- Stable snapshot key: "<vehicle>/<kind>", then "/2", "/3"... for a repeated kind on the same vehicle.
function KitchenService:StableKey(vehicle: string, kind: string): string
	const base = `{vehicle}/{kind}`
	const used: { [string]: boolean } = {}
	for _, other in self.Stations do
		used[other.Key] = true
	end
	if not used[base] then
		return base
	end
	local index = 2
	while used[`{base}/{index}`] do
		index += 1
	end
	return `{base}/{index}`
end


function KitchenService:AddStation(instance: Instance)
	if self.ByInstance[instance] ~= nil or not instance:IsDescendantOf(workspace) then
		return
	end
	if not instance:IsA("Model") then
		warn(`[KitchenService] Station {instance:GetFullName()} is not a Model`)
		return
	end
	const kind = instance:GetAttribute("StationKind")
	const row = if type(kind) == "string" then Content.Stations.ByKey[kind] else nil
	if row == nil then
		warn(`[KitchenService] Station {instance:GetFullName()}: StationKind "{kind}" is not in Content.Stations`)
		return
	end
	const vehicle = self:VehicleOf(instance)
	if vehicle == nil then
		warn(`[KitchenService] Station {instance:GetFullName()} has no Vehicle ancestor with a known Vehicle`)
		return
	end
	const id = self:FreeId()
	if id == nil then
		warn(`[KitchenService] no free StationId (max {MAX_STATION_ID}) for {instance:GetFullName()}`)
		return
	end

	const attribute = instance:GetAttribute("Ingredient")
	local ingredient: string? = nil
	if type(attribute) == "string" and Content.Ingredients.ByKey[attribute] ~= nil then
		ingredient = attribute
	elseif row.Ingredient ~= nil and row.Ingredient ~= Content.Stations.PerAnchor then
		ingredient = row.Ingredient
	end

	const station: StationApi.Station = {
		Kind = row.Key,
		Vehicle = vehicle,
		Instance = instance,
		Id = id,
		Key = self:StableKey(vehicle, row.Key),
		Ingredient = ingredient,
		Slots = {},
		Anchors = {},
		Records = {},
		State = nil,
	}
	self:CollectParts(station)
	self.Stations[id] = station
	self.ByInstance[instance] = station
	instance:SetAttribute("StationId", id)

	const module = self.Modules[row.Key]
	if module ~= nil then
		report(`Bind of {row.Key}`, pcall(module.Bind, self.Context, station))
		self:Publish(station)
	elseif not self.Warned[row.Key] then
		-- Provisional: warn, not error, while TASK-026/027/028 are not in (restock still works on these stations).
		self.Warned[row.Key] = true
		warn(`[KitchenService] no module in Stations/ for StationKind "{row.Key}"`)
	end
	self:RefreshPrompts(station)
end

function KitchenService:RemoveStation(instance: Instance)
	const station = self.ByInstance[instance]
	if station == nil then
		return
	end
	self.ByInstance[instance] = nil
	self.Stations[station.Id] = nil
	self.Locks[station.Id] = nil
	table.clear(station.Records)
	self:Publish(station)
	for _, anchor in station.Anchors do
		self.Gated[anchor] = nil
		self.Wanted[anchor] = nil
	end
	if instance.Parent ~= nil then
		instance:SetAttribute("StationId", nil)
	end
end

-- Rebuilds Slots after an upgrade level change of the station's own upgrade (grill) and tells the module.
function KitchenService:RefreshSlots(upgradeKey: string, vehicle: string)
	for _, station in self.Stations do
		if station.Kind ~= upgradeKey or station.Vehicle ~= vehicle then
			continue
		end
		self:CollectParts(station)
		const module = self.Modules[station.Kind]
		if module ~= nil and module.Refresh ~= nil then
			report(`Refresh of {station.Kind}`, pcall(module.Refresh, self.Context, station))
		end
	end
end

-- Stations set ----------------------------------------------------------------------------------------------------

-- Writes station.Records into the set: add new slots, update the others, remove slots that left the table.
function KitchenService:Publish(station: StationApi.Station)
	if not self.Dependencies.NetService:IsRunning() then
		return
	end
	const set = self.Libs.Net.Stations
	const seen: { [number]: boolean } = {}
	const alive = self.Stations[station.Id] == station
	if alive then
		for slot, record in station.Records do
			const kind = Content.Stations.ByKey[record.Kind]
			if
				type(slot) ~= "number"
				or slot ~= math.floor(slot)
				or slot < 0
				or slot > MAX_SLOT
				or kind == nil
				or kind.Record == "None"
			then
				warn(`[KitchenService] {station.Kind}: bad record at slot {slot} (Kind "{record.Kind}")`)
				continue
			end
			const state = record.State
			if state ~= "Empty" and state ~= "Working" and state ~= "Ready" then
				warn(`[KitchenService] {station.Kind}: bad State "{state}" at slot {slot}`)
				continue
			end
			const id = station.Id * SLOT_FACTOR + slot
			const value = {
				Kind = record.Kind,
				State = state,
				StartedAt = if type(record.StartedAt) == "number" then record.StartedAt else 0,
				Duration = if type(record.Duration) == "number"
					then math.clamp(record.Duration, 0, DURATION_MAX)
					else 0,
				Count = wholeNumber(record.Count, 0, COUNT_MAX),
				-- wave 3: nil = nothing altered (keeps wave 1-2 records as they were)
				Altered = if type(record.Altered) == "number" and record.Altered >= 1
					then wholeNumber(record.Altered, 0, COUNT_MAX)
					else nil,
			}
			if self.Published[id] ~= nil then
				set:update(id, value)
			else
				set:add(id, value)
				self.Published[id] = station.Id
			end
			seen[id] = true
		end
	end
	for id, owner in self.Published do
		if owner == station.Id and not seen[id] then
			set:remove(id)
			self.Published[id] = nil
		end
	end
end

-- Stock set: the 9 records as they read now (Amount, Capacity of the current Cooler, Blocked).
function KitchenService:PushStock()
	const records: { StockRecord } = {}
	for index, row in Content.Ingredients.List do
		records[index] = self:Stock(row.Key)
	end
	if not self.Dependencies.NetService:IsRunning() then
		return
	end
	for index, record in records do
		self.Libs.Net.Stock:update(index, record)
	end
end

-- Street bins -------------------------------------------------------------------------------------------------------

-- A StreetBin Model outside any Station and Vehicle (T60). A bin inside a vehicle would dodge IsCurrent: refused.
function KitchenService:AddBin(instance: Instance)
	if self.Bins[instance] or not instance:IsDescendantOf(workspace) then
		return
	end
	if not instance:IsA("Model") then
		warn(`[KitchenService] StreetBin {instance:GetFullName()} is not a Model`)
		return
	end
	local current = instance.Parent
	while current ~= nil and current ~= workspace do
		if CollectionService:HasTag(current, STATION_TAG) or CollectionService:HasTag(current, VEHICLE_TAG) then
			warn(`[KitchenService] StreetBin {instance:GetFullName()} is inside a Station/Vehicle: ignored`)
			return
		end
		current = current.Parent
	end
	self.Bins[instance] = true
	local anchors = 0
	for _, child in instance:GetDescendants() do
		if CollectionService:HasTag(child, ANCHOR_TAG) and child:GetAttribute("PromptAction") == DISCARD then
			anchors += 1
		end
	end
	if anchors == 0 then
		warn(`[KitchenService] StreetBin {instance:GetFullName()} has no Interactable anchor with PromptAction discard`)
	end
end

-- Prompts ---------------------------------------------------------------------------------------------------------

-- Global state of the station's anchors that depends on the core: a station of another vehicle is off (T36);
-- restock is off while its ingredient is Blocked. Anchors of module actions are left to the module otherwise: when
-- their vehicle becomes the current one they go back to what the module last asked (Wanted; default on, no text).
function KitchenService:RefreshPrompts(station: StationApi.Station)
	const current = self:IsCurrent(station)
	const interaction = self.Dependencies.InteractionService
	for _, anchor in station.Anchors do
		const action = anchor:GetAttribute("PromptAction")
		if not current then
			if not self.Gated[anchor] then
				self.Gated[anchor] = true
				interaction:SetPrompt(anchor, false, nil)
			end
		elseif action == RESTOCK then
			self.Gated[anchor] = nil
			const ingredient = self:IngredientOf(station, anchor)
			const enabled = ingredient ~= nil and not self:IsBlocked(ingredient)
			if anchor:GetAttribute("PromptEnabled") ~= enabled then
				interaction:SetPrompt(anchor, enabled, nil)
			end
		elseif self.Gated[anchor] then
			self.Gated[anchor] = nil
			const wanted = self.Wanted[anchor]
			if wanted ~= nil then
				interaction:SetPrompt(anchor, wanted.Enabled, wanted.Text)
			else
				interaction:SetPrompt(anchor, true, nil)
			end
		end
	end
end

function KitchenService:RefreshAllPrompts()
	for _, station in self.Stations do
		self:RefreshPrompts(station)
	end
end

-- Interactions ----------------------------------------------------------------------------------------------------

-- Ingredient an anchor acts on: its own Ingredient (topping bowls), else the station's.
function KitchenService:IngredientOf(station: StationApi.Station, anchor: Instance): string?
	const own = anchor:GetAttribute("Ingredient")
	if type(own) == "string" and Content.Ingredients.ByKey[own] ~= nil then
		return own
	end
	return station.Ingredient
end

function KitchenService:Notify(player: Player, notice: string, value: number?)
	if Content.Notices.ByKey[notice] == nil then
		return -- a plain reason from a module, not a toast
	end
	self.Dependencies.RunStateService:Notify(player, notice, value)
end

-- Package in hand that restocks `ingredient`, with units left.
function KitchenService:PackageFor(player: Player, ingredient: string): (Tool?, number)
	const items = self.Dependencies.ItemService
	const tool = items:Holding(player, PACKAGE)
	if tool == nil then
		return nil, 0
	end
	const key = items:ItemOf(tool)
	const package = if key then packageByItem[key] else nil
	if package == nil or package.Ingredient ~= ingredient then
		return nil, 0
	end
	const count = items:Count(tool)
	if count <= 0 then
		return nil, 0
	end
	return tool, count
end

-- Restock (FEAT-007, DEC-049): package of this ingredient in hand, not Blocked, stock below capacity. Returns
-- (ok, notice?, value?): full (or above capacity after the swap, Q-169) -> stock_full {item}; the rest is silent.
function KitchenService:CheckRestock(
	player: Player,
	station: StationApi.Station,
	anchor: Instance
): (boolean, string?, number?)
	const ingredient = self:IngredientOf(station, anchor)
	if ingredient == nil or self:IsBlocked(ingredient) then
		return false, nil, nil
	end
	const tool = self:PackageFor(player, ingredient)
	if tool == nil then
		return false, nil, nil
	end
	const amount, capacity = self:GetStock(ingredient)
	if amount >= capacity then
		return false, STOCK_FULL, Content.Ingredients.IndexOf[ingredient]
	end
	return true, nil, nil
end

-- Moves min(left in the package, capacity - current); the leftover stays in the package, an empty one disappears.
function KitchenService:Restock(player: Player, station: StationApi.Station, anchor: Instance)
	const ingredient = self:IngredientOf(station, anchor)
	if ingredient == nil then
		return
	end
	const tool, count = self:PackageFor(player, ingredient)
	if tool == nil then
		return
	end
	const amount, capacity = self:GetStock(ingredient)
	const moved = math.min(count, capacity - amount)
	if moved <= 0 then
		return
	end
	self:SetAmount(ingredient, amount + moved)
	self.Dependencies.ItemService:SetCount(tool, count - moved)
end

-- Street bin Model that owns an anchor (nearest StreetBin ancestor), only when no Station owns it.
function KitchenService:BinOf(anchor: Instance): Instance?
	local current = anchor.Parent
	while current ~= nil and current ~= workspace do
		if self.Bins[current] then
			return current
		end
		current = current.Parent
	end
	return nil
end

-- The table's Requires of an action (phase, day/night, item in hand).
function KitchenService:MeetsRequires(key: string, player: Player): boolean
	const row = Content.Actions.ByKey[key]
	if row == nil then
		return false
	end
	const round = self.Dependencies.RoundService
	const phases = row.Requires.Phase
	if phases and not table.find(phases, round:GetPhase()) then
		return false
	end
	if (row.Night == "DayOnly" and round:IsNight()) or (row.Night == "NightOnly" and not round:IsNight()) then
		return false
	end
	const held = row.Requires.Held
	if held and self.Dependencies.ItemService:Holding(player, held) == nil then
		return false
	end
	return true
end

-- Street bin (T60): discard only, same hand rule as BIN-C. Not a vehicle station: no IsCurrent, no station lock.
function KitchenService:CheckStreet(key: string, player: Player, anchor: Instance): boolean
	if key ~= DISCARD or self:BinOf(anchor) == nil or not self:MeetsRequires(key, player) then
		return false
	end
	return Trash.Discardable(self.Context, player) ~= nil
end

-- Everything the server checks before an action of a station: member, owner station on the current vehicle, the
-- table's Requires (phase, day/night, item in hand), then restock rules or the module's Validate. An anchor without
-- a station goes to the street bin branch. Returns (ok, notice?, value?).
function KitchenService:Evaluate(key: string, player: Player, anchor: Instance): (boolean, string?, number?)
	if not self.Active or not self.Dependencies.RunStateService:IsActive(player) then
		return false, nil, nil
	end
	const station = self:StationOf(anchor)
	if station == nil then
		return self:CheckStreet(key, player, anchor), nil, nil
	end
	if not self:IsCurrent(station) or not self:MeetsRequires(key, player) then
		return false, nil, nil
	end

	if key == RESTOCK then
		return self:CheckRestock(player, station, anchor)
	end
	const module = self.Modules[station.Kind]
	const action = if module then module.Actions[key] else nil
	if action == nil then
		return false, nil, nil
	end
	const ok, notice = action.Validate(self.Context, station, player, anchor)
	return ok == true, notice, nil
end

-- Runs fn with the station locked: requests on the same station never overlap, even when one yields (FEAT-006 "only
-- one receives"; InteractionService serializes per anchor, this serializes across the anchors of a station).
function KitchenService:Serialize(station: StationApi.Station, fn: () -> ())
	const id = station.Id
	const waiting = self.Locks[id]
	if waiting ~= nil then
		table.insert(waiting, coroutine.running())
		coroutine.yield()
	else
		const queue: { thread } = {}
		self.Locks[id] = queue
	end
	const ok, err = pcall(fn)
	const queue = self.Locks[id]
	const nextThread: thread? = if queue ~= nil and #queue > 0 then table.remove(queue, 1) else nil
	if nextThread ~= nil then
		task.spawn(nextThread :: thread)
	else
		self.Locks[id] = nil
	end
	if not ok then
		warn(`[KitchenService] action on {station.Kind} errored: {err}`)
	end
end

-- Revalidated inside the lock: the state may have changed while waiting.
function KitchenService:Perform(key: string, player: Player, anchor: Instance)
	const station = self:StationOf(anchor)
	if station == nil then
		-- Street bin: Consume is synchronous, so the check and the removal can't interleave with another request.
		if self:CheckStreet(key, player, anchor) then
			const tool = Trash.Discardable(self.Context, player)
			if tool ~= nil then
				const _, item, altered = self:DiscardTarget(player)
				self.Dependencies.ItemService:Consume(player, tool)
				self:ReportDiscard(player, tool, item, altered, "Street")
			end
		end
		return
	end
	self:Serialize(station, function()
		const ok, notice, value = self:Evaluate(key, player, anchor)
		if not ok then
			if notice ~= nil then
				Refusal.notify(self.Context, player, notice, value)
			end
			return
		end
		if key == RESTOCK then
			self:Restock(player, station, anchor)
			return
		end
		const module = self.Modules[station.Kind]
		const action = if module then module.Actions[key] else nil
		if action == nil then
			return
		end
		if key ~= DISCARD then
			action.Run(self.Context, station, player, anchor)
			return
		end
		const tool, item, altered = self:DiscardTarget(player)
		action.Run(self.Context, station, player, anchor)
		self:ReportDiscard(player, tool, item, altered, "Vehicle")
	end)
end

-- Context (StationApi.Context): functions only --------------------------------------------------------------------

function KitchenService:BuildContext(): StationApi.Context
	return {
		Now = function(): number
			return workspace:GetServerTimeNow()
		end,
		TakeStock = function(ingredient: string, n: number): boolean
			return self:TakeStock(ingredient, n)
		end,
		GetStock = function(ingredient: string): (number, number)
			return self:GetStock(ingredient)
		end,
		IsBlocked = function(ingredient: string): boolean
			return self:IsBlocked(ingredient)
		end,
		Give = function(player: Player, item: string, attrs: { [string]: any }?): boolean
			const toppings = if attrs and type(attrs.Toppings) == "string" then attrs.Toppings else nil
			const count = if attrs and type(attrs.Count) == "number" then attrs.Count else nil
			const restore = if attrs and type(attrs.Restore) == "number" then attrs.Restore else nil
			const tool = self.Dependencies.ItemService:Give(player, item, {
				Toppings = toppings,
				Count = count,
				Restore = restore,
			})
			-- Provisional (TASK-109): ItemService has no GiveOptions.Altered yet (network.md §7.1 names it the
			-- writer); the attribute is set here, on the Tool it just created, until ItemService takes it over.
			if tool ~= nil and item == HOT_DOG and attrs ~= nil and attrs.Altered == true then
				tool:SetAttribute("Altered", true)
			end
			return tool ~= nil
		end,
		Held = function(player: Player): Tool?
			return self.Dependencies.ItemService:GetHeld(player)
		end,
		Consume = function(player: Player, tool: Tool)
			self.Dependencies.ItemService:Consume(player, tool)
		end,
		AddTopping = function(tool: Tool, ingredient: string): boolean
			return self.Dependencies.ItemService:AddTopping(tool, ingredient)
		end,
		Modifier = function(player: Player, stat: string): number
			if not Content.Stats.Has[stat] then
				fail(`[KitchenService] Modifier: {stat} is not a key of Content.Stats`)
				return 1
			end
			return self.Dependencies.ClassService:GetModifier(player, stat :: Content.Stat)
		end,
		Effect = function(stat: string): number
			return self.Dependencies.UpgradeService:GetEffect(stat)
		end,
		Publish = function(station: StationApi.Station)
			self:Publish(station)
		end,
		Notify = function(player: Player, notice: string, value: number?)
			self:Notify(player, notice, value)
		end,
		-- A station of another vehicle stays off; what the module asked is kept for when it becomes the current one.
		SetPrompt = function(anchor: Instance, enabled: boolean, text: string?)
			const station = self:StationOf(anchor)
			if station ~= nil then
				const wanted: Wanted = { Enabled = enabled, Text = text }
				self.Wanted[anchor] = wanted
			end
			const on = enabled and (station == nil or self:IsCurrent(station))
			self.Dependencies.InteractionService:SetPrompt(anchor, on, text)
		end,
		-- Deferred: modules emit from inside the station lock; listeners run after it.
		Emit = function(name: string, player: Player?, data: { [string]: any }?)
			task.defer(function()
				self.Emitted:Fire(name, player, data)
			end)
		end,
	}
end

-- Altered items (wave 3, TASK-109) ---------------------------------------------------------------------------------

-- Station of `kind` on the current vehicle with the lowest StationId, nil if none.
function KitchenService:CurrentStation(kind: string): StationApi.Station?
	const vehicle = self:GetVehicle()
	local best: StationApi.Station? = nil
	for _, station in self.Stations do
		if station.Kind == kind and station.Vehicle == vehicle and (best == nil or station.Id < best.Id) then
			best = station
		end
	end
	return best
end

-- One altered item (ANM-002) on the current vehicle: "rail" = gray sausage taken by the next "Add Sausage",
-- "board" = bitten bun on a free slot (`slot` nil = the board picks). Synchronous; refused outside phase Night, with
-- no room, with one already there, or while an action holds the station lock (the caller retries later).
function KitchenService:Alter(kind: AlterKind, slot: number?): boolean
	if not self.Active or not ALTER_KINDS[kind] then
		return false
	end
	if self.Dependencies.RoundService:GetPhase() ~= ALTER_PHASE then
		return false
	end
	if slot ~= nil and (type(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > MAX_SLOT) then
		return false
	end
	const station = self:CurrentStation(kind)
	if station == nil or self.Locks[station.Id] ~= nil then
		return false
	end
	const module = self.Modules[station.Kind]
	const alter = if module then module.Alter else nil
	if alter == nil then
		return false
	end
	const ok, result = pcall(alter, self.Context, station, slot)
	report(`Alter of {station.Key}`, ok, result)
	return ok and result == true
end

-- Removes every altered item still on a station (any vehicle). Returns how many stations changed.
function KitchenService:ClearAltered(): number
	local cleared = 0
	for _, station in self.Stations do
		const module = self.Modules[station.Kind]
		const clear = if module then module.ClearAltered else nil
		if clear == nil then
			continue
		end
		const ok, result = pcall(clear, self.Context, station)
		report(`ClearAltered of {station.Key}`, ok, result)
		if ok and result == true then
			cleared += 1
		end
	end
	return cleared
end

-- Some altered item on a station of the current vehicle (`kind` nil = rail or board).
function KitchenService:HasAltered(kind: AlterKind?): boolean
	const vehicle = self:GetVehicle()
	for _, station in self.Stations do
		if station.Vehicle ~= vehicle or (kind ~= nil and station.Kind ~= kind) then
			continue
		end
		for _, record in station.Records do
			if type(record.Altered) == "number" and record.Altered >= 1 then
				return true
			end
		end
	end
	return false
end

-- Held Tool before a Throw Away: (tool, item key, Altered attribute).
function KitchenService:DiscardTarget(player: Player): (Tool?, string, boolean)
	const items = self.Dependencies.ItemService
	const tool = items:GetHeld(player)
	if tool == nil then
		return nil, "", false
	end
	return tool, items:ItemOf(tool) or "", tool:GetAttribute("Altered") == true
end

-- Fires Discarded when the Throw Away really took the Tool away (ItemService forgot it).
function KitchenService:ReportDiscard(player: Player, tool: Tool?, item: string, altered: boolean, where: DiscardWhere)
	if tool == nil or self.Dependencies.ItemService.Owners[tool] ~= nil then
		return
	end
	task.defer(function()
		self.Discarded:Fire(player, item, altered, where)
	end)
end

-- Snapshot --------------------------------------------------------------------------------------------------------

-- "Stk" (data.md §3.3): Amount by ingredient key. Capacity and Blocked are derived and stay out.
function KitchenService:CaptureStock(): { [string]: number }
	return table.clone(self.Amounts())
end

-- Unknown keys are ignored; a missing ingredient keeps its current amount.
function KitchenService:RestoreStock(data: any)
	if type(data) ~= "table" then
		return
	end
	const nextAmounts = table.clone(self.Amounts())
	for _, row in Content.Ingredients.List do
		const value = data[row.Key]
		if type(value) == "number" and value == value then
			nextAmounts[row.Key] = math.clamp(math.floor(value), 0, AMOUNT_MAX)
		end
	end
	self.Amounts(table.freeze(nextAmounts))
	for key, value in nextAmounts do
		self.StockChanged:Fire(key, value)
	end
end

-- "Stn": what each module keeps, by stable key. nil from Capture = nothing (the station restarts empty).
function KitchenService:CaptureStations(): { [string]: any }
	const out: { [string]: any } = {}
	for _, station in self.Stations do
		const module = self.Modules[station.Kind]
		if module == nil then
			continue
		end
		const ok, data = pcall(module.Capture, self.Context, station)
		if not ok then
			warn(`[KitchenService] Capture of {station.Key} errored: {data}`)
		elseif data ~= nil then
			out[station.Key] = data
		end
	end
	return out
end

function KitchenService:RestoreStations(data: any)
	const saved: { [string]: any } = if type(data) == "table" then data else {}
	for _, station in self.Stations do
		const module = self.Modules[station.Kind]
		if module ~= nil then
			report(`Restore of {station.Key}`, pcall(module.Restore, self.Context, station, saved[station.Key]))
			self:Publish(station)
		end
	end
end

-- Unlocks ---------------------------------------------------------------------------------------------------------

function KitchenService:RememberBlocked()
	for _, row in Content.Ingredients.List do
		self.WasBlocked[row.Key] = self:IsBlocked(row.Key)
	end
end

-- ShiftStarted: "New: {item}!" to the party for every ingredient that opened since the last shift (network.md §4.2).
function KitchenService:AnnounceUnlocks()
	for _, row in Content.Ingredients.List do
		if self.WasBlocked[row.Key] == true and not self:IsBlocked(row.Key) then
			self.Dependencies.RunStateService:Notify("all", UNLOCK_NOTICE, Content.Ingredients.IndexOf[row.Key])
		end
	end
	self:RememberBlocked()
end

-- Lifecycle -------------------------------------------------------------------------------------------------------

KitchenService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self.Active = true

	-- InteractionService (730) built its handler table in its own OnInit, before this one (650).
	self:LoadModules()
	self:RegisterActions()

	const runState = self.Dependencies.RunStateService
	runState:RegisterSnapshot("Stk", function()
		return self:CaptureStock()
	end, function(data, _mode)
		self:RestoreStock(data)
	end)
	runState:RegisterSnapshot("Stn", function()
		return self:CaptureStations()
	end, function(data, _mode)
		self:RestoreStations(data)
	end)

	-- Signals exist since RoundService's OnInit (750 > 650)
	self.Dependencies.RoundService.ShiftStarted:Connect(function()
		self:AnnounceUnlocks()
	end)
	-- ITM-020: altered items never outlive the Night phase (NightEnd at 6:00 AM, NightLost, any later phase).
	self.Dependencies.RoundService.PhaseChanged:Connect(function(phase: string)
		if phase ~= ALTER_PHASE then
			self:ClearAltered()
		end
	end)
end)

KitchenService:OnStart(function(self)
	if not self.Active then
		return
	end

	-- UpgradeService (630) creates its signal in its OnInit, after ours: connect here.
	self.Dependencies.UpgradeService.Changed:Connect(function(key: string, _level: number, vehicle: string)
		self:RefreshSlots(key, vehicle)
	end)

	-- Stock set: always the 9 records (network.md §3.4). Lync.start already ran (NetService OnStart, 1000).
	const net = self.Libs.Net
	for index, row in Content.Ingredients.List do
		net.Stock:add(index, self:Stock(row.Key))
	end
	-- Amount, Cooler level, vehicle and Day are all atoms read in here: purchase, restock, restore, new day and
	-- vehicle swap land in the same effect. Restock prompts follow Blocked from the same reads.
	self.Libs.Charm.effect(function()
		self:PushStock()
		self:RefreshAllPrompts()
	end)

	-- VehicleService (620) creates Swapped in its OnInit, after ours (650): connect here. UpgradeService already moved
	-- to the new vehicle when it fires (§19.5), so Capacity/Blocked and IsCurrent read the new one.
	self.Dependencies.VehicleService.Swapped:Connect(function(_from: string, _to: string)
		self:PushStock()
		self:RefreshAllPrompts()
	end)

	-- Street bins (T60): indexed like the stations; the anchor itself is tracked by InteractionService (tag
	-- Interactable), which turns the prompt on because discard is registered.
	for _, instance in CollectionService:GetTagged(BIN_TAG) do
		self:AddBin(instance)
	end
	CollectionService:GetInstanceAddedSignal(BIN_TAG):Connect(function(instance)
		self:AddBin(instance)
	end)
	CollectionService:GetInstanceRemovedSignal(BIN_TAG):Connect(function(instance)
		self.Bins[instance] = nil
	end)

	-- Stations in GetFullName order, so StationIds are the same on every boot of the same place.
	const found: { Instance } = {}
	const names: { [Instance]: string } = {}
	for _, instance in CollectionService:GetTagged(STATION_TAG) do
		if instance:IsDescendantOf(workspace) then
			table.insert(found, instance)
			names[instance] = instance:GetFullName()
		end
	end
	table.sort(found, function(a: Instance, b: Instance): boolean
		return names[a] < names[b]
	end)
	for _, instance in found do
		self:AddStation(instance)
	end
	CollectionService:GetInstanceAddedSignal(STATION_TAG):Connect(function(instance)
		self:AddStation(instance)
	end)
	CollectionService:GetInstanceRemovedSignal(STATION_TAG):Connect(function(instance)
		self:RemoveStation(instance)
	end)

	self:RememberBlocked()
end)

KitchenService:OnTick(function(self)
	if not self.Active then
		return
	end
	const now = workspace:GetServerTimeNow()
	for _, station in self.Stations do
		const module = self.Modules[station.Kind]
		const tick = if module then module.Tick else nil
		if tick ~= nil and self:IsCurrent(station) then
			report(`Tick of {station.Kind}`, pcall(tick, self.Context, station, now))
		end
	end
end, TICK_RATE)

return KitchenService
