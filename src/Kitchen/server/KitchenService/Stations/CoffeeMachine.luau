--!strict
-- Coffee machine (FEAT-021; UPG-007; DEC-055, DEC-069, DEC-125; architecture.md §18.12 T37, §19.8; network.md §3.5;
-- TASK-068, TASK-328). StationKind "coffee_machine", trailer only (Vehicles[v].HasCoffee). One Single record (slot 0).
-- The machine owns the wait (TASK-328, owner request 2026-10-15, Provisional): it brews by itself and the player has
-- no drink cooldown any more.
--   Empty     + coffee stock >= 1 -> TakeStock 1 -> Working at once (nobody presses anything)
--   Working   "Brewing": Duration = CoffeeBrewTime (base Stations.coffee_machine.Params.BrewTime over the Coffee Maker
--             upgrade; the class of whoever took the last cup applies over it, Barista faster)
--   Ready     the cup waits on the machine until someone takes it: brew_coffee (Prompt_Brew, "Take Coffee") gives the
--             Tool "coffee" with Restore = CoffeeRestore of the taker (base Sanity.Coffee; Barista more). A refused
--             Give (hands full, already holds a coffee) keeps the cup in the machine; ItemService sends the notice.
--   Cleaning  after a take: Params.CleanTime s (60), then Empty and the next brew starts in the same tick
--   Tick 10 Hz moves the states on and keeps the prompt in step (enabled only in Ready).
-- Drinking is VitalService's (ItemService:RegisterUse("coffee"), night only, Q-170 option A Provisional): brewing and
-- taking work day and night (Actions.brew_coffee Night = "Any"). Restock on Prompt_Restock is the core's: an empty
-- machine waits for stock and brews as soon as a dose is there.
-- Blocked until the trailer: the station only exists inside the trailer, the core switches off stations of another
-- vehicle (T36), HasCoffee is checked here and TakeStock refuses a Blocked ingredient.
-- Provisional:
--   * Restore goes in Context.Give attrs; the core forwards it to ItemService GiveOptions.Restore (TASK-057).
--   * Snapshot "Stn": a Working or Ready cup is kept as Ready (the dose already left the stock); Cleaning comes back
--     Empty (the next brew starts on the first tick).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local StationApi = require(script.Parent.Parent.StationApi)

type Context = StationApi.Context
type Station = StationApi.Station

-- Private state of the machine (station.State).
type State = {
	Taker: Player?, -- who took the last cup: their class sets the next brew time (nil = the upgrade base only)
}

const KIND = "coffee_machine"
const BREW = "brew_coffee"
const COFFEE = "coffee"
const RECORD_SLOT = 0 -- single-record station (network.md §3.5)
const BREW_STAT = "CoffeeBrewTime"
const RESTORE_STAT = "CoffeeRestore"
const RESTORE_ATTRIBUTE = "Restore" -- Give attr -> ItemService GiveOptions.Restore -> Tool attribute (network.md §7.1)
const TAKE_TEXT = "Take Coffee" -- PromptText in Ready (architecture.md §19.8)
const DURATION_STEP = 0.1 -- Stations.Duration is quant(0, 120, 0.1): the server uses the value the wire carries
const DURATION_MAX = 120
const RESTORE_MAX = 1000

const warned: { [string]: boolean } = {}

local function warnOnce(key: string, message: string)
	if not warned[key] then
		warned[key] = true
		warn(message)
	end
end

local function param(key: string): number
	const row = Content.Stations.ByKey[KIND]
	return if row then row.Params[key] or 0 else 0
end

-- Class value of a coffee stat for the player over the Coffee Maker upgrade (UPG-013, TASK-324: the upgrade level is the
-- base, the class applies over it); the table base when a read fails. No player = the upgrade base only.
local function modifier(ctx: Context, player: Player?, stat: string, base: number): number
	const okEffect, effect = pcall(ctx.Effect, stat)
	if okEffect and type(effect) == "number" and effect == effect and effect > 0 then
		base = effect
	end
	if player == nil or player.Parent == nil then
		return base
	end
	const ok, value = pcall(ctx.Modifier, player, stat, base)
	if ok and type(value) == "number" and value == value then
		return value
	end
	warnOnce(stat, `[CoffeeMachine] class value of {stat} unavailable, using base {base}: {value}`)
	return base
end

local function quantized(seconds: number): number
	const rounded = math.floor(seconds / DURATION_STEP + 0.5) * DURATION_STEP
	return math.clamp(rounded, DURATION_STEP, DURATION_MAX)
end

local function brewTime(ctx: Context, player: Player?): number
	return quantized(modifier(ctx, player, BREW_STAT, param("BrewTime")))
end

local function restoreOf(ctx: Context, player: Player): number
	const value = modifier(ctx, player, RESTORE_STAT, Content.Sanity.Coffee)
	return math.clamp(math.floor(value + 0.5), 0, RESTORE_MAX)
end

local function hasCoffee(station: Station): boolean
	const vehicle = Content.Vehicles.ByKey[station.Vehicle]
	return vehicle ~= nil and vehicle.HasCoffee
end

local function ingredientOf(station: Station): string
	return station.Ingredient or COFFEE
end

local function record(station: Station): StationApi.Record
	const current = station.Records[RECORD_SLOT]
	if current ~= nil then
		return current
	end
	const fresh = StationApi.empty(KIND)
	station.Records[RECORD_SLOT] = fresh
	return fresh
end

local function stateOf(station: Station): State
	const state = station.State
	if type(state) == "table" then
		return state :: State
	end
	const fresh: State = {}
	station.State = fresh
	return fresh
end

-- (enabled, text) of Prompt_Brew for the current state: only a waiting cup can be taken.
local function promptFor(station: Station): (boolean, string?)
	if record(station).State == "Ready" then
		return hasCoffee(station), TAKE_TEXT
	end
	return false, nil
end

local function refreshPrompt(ctx: Context, station: Station)
	const enabled, text = promptFor(station)
	for _, anchor in station.Anchors do
		if anchor:GetAttribute("PromptAction") ~= BREW then
			continue
		end
		if anchor:GetAttribute("PromptEnabled") ~= enabled or anchor:GetAttribute("PromptText") ~= text then
			ctx.SetPrompt(anchor, enabled, text)
		end
	end
end

local function setEmpty(station: Station)
	station.Records[RECORD_SLOT] = StationApi.empty(KIND)
end

local function setReady(station: Station)
	station.Records[RECORD_SLOT] = { Kind = KIND, State = "Ready", StartedAt = 0, Duration = 0, Count = 0 }
end

local function setTimed(station: Station, state: StationApi.SlotState, startedAt: number, duration: number)
	station.Records[RECORD_SLOT] =
		{ Kind = KIND, State = state, StartedAt = startedAt, Duration = duration, Count = 0 }
end

-- Machine -------------------------------------------------------------------------------------------------------------

-- Empty -> Working when a dose is in stock (true = the record changed)
local function tryBrew(ctx: Context, station: Station, now: number): boolean
	if not hasCoffee(station) or record(station).State ~= "Empty" then
		return false
	end
	const ingredient = ingredientOf(station)
	if ctx.GetStock(ingredient) < 1 or not ctx.TakeStock(ingredient, 1) then
		return false
	end
	setTimed(station, "Working", now, brewTime(ctx, stateOf(station).Taker))
	return true
end

local function take(ctx: Context, station: Station, player: Player)
	if not ctx.Give(player, COFFEE, { [RESTORE_ATTRIBUTE] = restoreOf(ctx, player) }) then
		return -- refused (notice sent by ItemService): the cup stays in the machine
	end
	stateOf(station).Taker = player
	setTimed(station, "Cleaning", ctx.Now(), quantized(param("CleanTime")))
	ctx.Publish(station)
end

const brewAction: StationApi.Action = {
	Validate = function(_ctx: Context, station: Station, _player: Player, _anchor: Instance): (boolean, string?)
		if station.Kind ~= KIND or not hasCoffee(station) then
			return false, nil
		end
		return record(station).State == "Ready", nil
	end,
	-- Inside the station lock (KitchenService:Serialize) and revalidated there: one take per cup.
	Run = function(ctx: Context, station: Station, player: Player, _anchor: Instance)
		if record(station).State == "Ready" then
			take(ctx, station, player)
		end
		refreshPrompt(ctx, station)
	end,
}

-- StationApi.Module ---------------------------------------------------------------------------------------------------

const CoffeeMachine: StationApi.Module = {
	Kinds = { KIND },
	Actions = {
		[BREW] = brewAction,
	},
	Bind = function(ctx: Context, station: Station)
		table.clear(station.Records)
		station.State = nil
		setEmpty(station)
		ctx.Publish(station)
		refreshPrompt(ctx, station)
	end,
	-- 10 Hz, current vehicle only: Working -> Ready, Cleaning -> Empty, Empty -> Working (stock permitting).
	Tick = function(ctx: Context, station: Station, now: number)
		const current = record(station)
		local changed = false
		if current.State == "Working" and now >= current.StartedAt + current.Duration then
			setReady(station)
			changed = true
		elseif current.State == "Cleaning" and now >= current.StartedAt + current.Duration then
			setEmpty(station)
			changed = true
		end
		if tryBrew(ctx, station, now) then
			changed = true
		end
		if changed then
			ctx.Publish(station)
		end
		refreshPrompt(ctx, station)
	end,
	Capture = function(_ctx: Context, station: Station): any
		const state = record(station).State
		if state == "Working" or state == "Ready" then
			return { Ready = true }
		end
		return nil
	end,
	Restore = function(ctx: Context, station: Station, data: any)
		table.clear(station.Records)
		station.State = nil
		-- older snapshots carried { Restore = n } for the same Ready cup
		if type(data) == "table" then
			setReady(station)
		else
			setEmpty(station)
		end
		ctx.Publish(station)
		refreshPrompt(ctx, station)
	end,
}

return CoffeeMachine
