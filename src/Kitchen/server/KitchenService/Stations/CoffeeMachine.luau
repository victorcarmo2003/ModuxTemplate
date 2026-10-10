--!strict
-- Coffee machine (FEAT-021; UPG-007; DEC-055, DEC-069, DEC-125; architecture.md §18.12 T37, §19.8; network.md §3.5;
-- TASK-068). StationKind "coffee_machine", trailer only (Vehicles[v].HasCoffee). One Single record (slot 0).
--   brew_coffee (Prompt_Brew, hold 1)
--     Empty  + coffee stock >= 1 -> TakeStock 1 -> Working, Duration = CoffeeBrewTime of who brewed
--            (base Stations.coffee_machine.Params.BrewTime 6 s; Barista 3 s by the class stat)
--     Ready  same prompt, PromptText "Take Coffee": gives the Tool "coffee" to whoever holds it, with Restore =
--            CoffeeRestore of who brewed (base Sanity.Coffee 25; Barista 35). A refused Give (hands full, already
--            holds a coffee) keeps the cup in the machine; ItemService sends the notice.
--   Tick 10 Hz Working -> Ready at StartedAt + Duration; keeps the prompt in step with state and stock.
-- Drinking is VitalService's (ItemService:RegisterUse("coffee"), night only, Q-170 option A Provisional): brewing and
-- taking work day and night (Actions.brew_coffee Night = "Any"). Restock on Prompt_Restock is the core's.
-- Blocked until the trailer: the station only exists inside the trailer, the core switches off stations of another
-- vehicle (T36), HasCoffee is checked here and TakeStock refuses a Blocked ingredient.
-- Provisional (TASK-068):
--   * Context.Modifier has no base and ClassService has no default base for CoffeeBrewTime/CoffeeRestore, so the call
--     errors today. modifier() below catches it and falls back to the table base (Barista loses the bonus until the
--     Context passes `base` or ClassService gets the two defaults: registered on the board).
--   * Restore goes in Context.Give attrs; the core forwards it to ItemService GiveOptions.Restore (TASK-057).
--   * Snapshot "Stn": a Working or Ready cup is kept as Ready ({ Restore = n }), the dose already left the stock.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local StationApi = require(script.Parent.Parent.StationApi)

type Context = StationApi.Context
type Station = StationApi.Station

-- Private state of the machine (station.State).
type State = {
	Restore: number, -- CoffeeRestore of who brewed the cup in Working/Ready
}

const KIND = "coffee_machine"
const BREW = "brew_coffee"
const COFFEE = "coffee"
const RECORD_SLOT = 0 -- single-record station (network.md §3.5)
const BREW_STAT = "CoffeeBrewTime"
const RESTORE_STAT = "CoffeeRestore"
const RESTORE_ATTRIBUTE = "Restore" -- Give attr -> ItemService GiveOptions.Restore -> Tool attribute (network.md §7.1)
const TAKE_TEXT = "Take Coffee" -- PromptText in Ready (architecture.md §19.8; Actions.brew_coffee has "Brew Coffee")
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

local function baseBrewTime(): number
	const row = Content.Stations.ByKey[KIND]
	return if row then row.Params.BrewTime or 0 else 0
end

-- Class value of a coffee stat for the player; the table base when the class read fails (see Provisional above).
local function modifier(ctx: Context, player: Player, stat: string, base: number): number
	const ok, value = pcall(ctx.Modifier, player, stat)
	if ok and type(value) == "number" and value == value then
		return value
	end
	warnOnce(stat, `[CoffeeMachine] class value of {stat} unavailable, using base {base}: {value}`)
	return base
end

local function brewTime(ctx: Context, player: Player): number
	const seconds = modifier(ctx, player, BREW_STAT, baseBrewTime())
	const rounded = math.floor(seconds / DURATION_STEP + 0.5) * DURATION_STEP
	return math.clamp(rounded, DURATION_STEP, DURATION_MAX)
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
	if type(state) == "table" and type(state.Restore) == "number" then
		return state :: State
	end
	const fresh: State = { Restore = Content.Sanity.Coffee }
	station.State = fresh
	return fresh
end

local function canBrew(ctx: Context, station: Station): boolean
	if station.Kind ~= KIND or not hasCoffee(station) or record(station).State ~= "Empty" then
		return false
	end
	const amount = ctx.GetStock(ingredientOf(station))
	return amount >= 1
end

-- (enabled, text) of Prompt_Brew for the current state.
local function promptFor(ctx: Context, station: Station): (boolean, string?)
	const state = record(station).State
	if state == "Ready" then
		return hasCoffee(station), TAKE_TEXT
	end
	if state == "Working" then
		return false, nil
	end
	return canBrew(ctx, station), nil
end

local function refreshPrompt(ctx: Context, station: Station)
	const enabled, text = promptFor(ctx, station)
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
	station.State = nil
end

local function setReady(station: Station, restore: number)
	station.Records[RECORD_SLOT] = { Kind = KIND, State = "Ready", StartedAt = 0, Duration = 0, Count = 0 }
	station.State = { Restore = restore } :: State
end

-- Actions -------------------------------------------------------------------------------------------------------------

local function brew(ctx: Context, station: Station, player: Player)
	if not ctx.TakeStock(ingredientOf(station), 1) then
		return
	end
	station.Records[RECORD_SLOT] = {
		Kind = KIND,
		State = "Working",
		StartedAt = ctx.Now(),
		Duration = brewTime(ctx, player),
		Count = 0,
	}
	station.State = { Restore = restoreOf(ctx, player) } :: State
	ctx.Publish(station)
end

local function take(ctx: Context, station: Station, player: Player)
	const restore = stateOf(station).Restore
	if not ctx.Give(player, COFFEE, { [RESTORE_ATTRIBUTE] = restore }) then
		return -- refused (notice sent by ItemService): the cup stays in the machine
	end
	setEmpty(station)
	ctx.Publish(station)
end

const brewAction: StationApi.Action = {
	Validate = function(ctx: Context, station: Station, _player: Player, _anchor: Instance): (boolean, string?)
		if station.Kind ~= KIND or not hasCoffee(station) then
			return false, nil
		end
		const state = record(station).State
		if state == "Ready" then
			return true, nil
		end
		return canBrew(ctx, station), nil
	end,
	-- Inside the station lock (KitchenService:Serialize) and revalidated there: one brew or one take per cup.
	Run = function(ctx: Context, station: Station, player: Player, _anchor: Instance)
		const state = record(station).State
		if state == "Ready" then
			take(ctx, station, player)
		elseif state == "Empty" then
			brew(ctx, station, player)
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
		setEmpty(station)
		ctx.Publish(station)
		refreshPrompt(ctx, station)
	end,
	-- 10 Hz, current vehicle only: finish brewing, keep the prompt in step with the state and the stock.
	Tick = function(ctx: Context, station: Station, now: number)
		const current = record(station)
		if current.State == "Working" and now >= current.StartedAt + current.Duration then
			setReady(station, stateOf(station).Restore)
			ctx.Publish(station)
		end
		refreshPrompt(ctx, station)
	end,
	Capture = function(_ctx: Context, station: Station): any
		const state = record(station).State
		if state == "Empty" then
			return nil
		end
		return { Restore = stateOf(station).Restore }
	end,
	Restore = function(ctx: Context, station: Station, data: any)
		table.clear(station.Records)
		const restore = if type(data) == "table" then data.Restore else nil
		if type(restore) == "number" and restore == restore then
			setReady(station, math.clamp(math.floor(restore + 0.5), 0, RESTORE_MAX))
		else
			setEmpty(station)
		end
		ctx.Publish(station)
		refreshPrompt(ctx, station)
	end,
}

return CoffeeMachine
