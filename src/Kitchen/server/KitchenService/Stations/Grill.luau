--!strict
-- Grill + sausage stock (FEAT-006 steps 1-3; UPG-001; DEC-015, DEC-046, DEC-069, DEC-201; architecture.md §18.4,
-- §18.12; network.md §3.5; TASK-026). StationKinds "grill" and "sausage_stock" (§18.12).
--   grill_place   (sausage_stock, tap "Grill")  1 sausage from stock -> lowest free slot of the vehicle's grill;
--                 Duration = Effect GrillTime (12/10/8 s) x Modifier GrillTime of who placed it (Line Cook 0.85)
--   Tick 10 Hz    Working -> Ready when StartedAt + Duration is reached (no burning in the MVP)
--   grill_collect (grill slot anchor Att_Slot<n>, tap "Collect")  Ready slot -> end of the rail queue (Rail.luau)
-- Active slots = Slot attachments 1..GrillSlots of the current level (2/3/4); a slot added by an upgrade enters
-- Empty, slots in progress never restart (network.md §3.5). One Stations record per active slot.
-- Prompts (Provisional, TASK-026): "Grill" off while no slot is free or the stock is 0; "Collect" on only on a Ready
-- slot with room on the rail. Snapshot: nothing kept (data.md §2.2: the shift restarts with an empty grill).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local StationApi = require(script.Parent.Parent.StationApi)
local Rail = require(script.Parent.Rail)

type Context = StationApi.Context
type Station = StationApi.Station

const GRILL = "grill"
const STOCK = "sausage_stock"
const PLACE = "grill_place"
const COLLECT = "grill_collect"
const SAUSAGE = "sausage"
const SLOTS_STAT = "GrillSlots"
const TIME_STAT = "GrillTime"
const DURATION_STEP = 0.1 -- Stations.Duration is quant(0, 120, 0.1): the server uses the value the wire carries
const DURATION_MAX = 120

-- Bound grill stations (one per vehicle expected). Stale entries (station removed/re-added) are skipped by alive().
const grills: { Station } = {}

local function alive(station: Station): boolean
	const instance = station.Instance
	return instance.Parent ~= nil
		and instance:IsDescendantOf(workspace)
		and instance:GetAttribute("StationId") == station.Id
end

local function grillsOf(vehicle: string): { Station }
	const out: { Station } = {}
	for _, station in grills do
		if station.Vehicle == vehicle and alive(station) then
			table.insert(out, station)
		end
	end
	table.sort(out, function(a: Station, b: Station): boolean
		return a.Id < b.Id
	end)
	return out
end

local function slotOf(anchor: Instance): number?
	const slot = anchor:GetAttribute("Slot")
	if type(slot) == "number" and slot == math.floor(slot) and slot >= 1 then
		return slot
	end
	return nil
end

-- Slots 1..GrillSlots that have an attachment at the current level. GrillSlots is read for the current vehicle:
-- actions and Tick only run on stations of the current vehicle (KitchenService, T36).
local function activeSlots(ctx: Context, station: Station): { number }
	const limit = math.floor(ctx.Effect(SLOTS_STAT))
	const out: { number } = {}
	for slot in station.Slots do
		if slot <= limit then
			table.insert(out, slot)
		end
	end
	table.sort(out)
	return out
end

-- Records = active slots (missing ones enter Empty) + any slot still busy outside them (never dropped mid-cook).
-- Returns true when the record table changed.
local function sync(ctx: Context, station: Station): boolean
	local changed = false
	const active: { [number]: boolean } = {}
	for _, slot in activeSlots(ctx, station) do
		active[slot] = true
		if station.Records[slot] == nil then
			station.Records[slot] = StationApi.empty(GRILL)
			changed = true
		end
	end
	for slot, record in station.Records do
		if not active[slot] and record.State == "Empty" then
			station.Records[slot] = nil
			changed = true
		end
	end
	return changed
end

-- Lowest free active slot over the vehicle's grills (read only: a slot without a record yet counts as free).
local function freeSlot(ctx: Context, vehicle: string): (Station?, number?)
	for _, grill in grillsOf(vehicle) do
		for _, slot in activeSlots(ctx, grill) do
			const record = grill.Records[slot]
			if record == nil or record.State == "Empty" then
				return grill, slot
			end
		end
	end
	return nil, nil
end

local function ingredientOf(station: Station): string
	return station.Ingredient or SAUSAGE
end

local function cookTime(ctx: Context, player: Player): number
	const seconds = ctx.Effect(TIME_STAT) * ctx.Modifier(player, TIME_STAT)
	const rounded = math.floor(seconds / DURATION_STEP + 0.5) * DURATION_STEP
	return math.clamp(rounded, DURATION_STEP, DURATION_MAX)
end

local function setPrompt(ctx: Context, anchor: Instance, enabled: boolean)
	if anchor:GetAttribute("PromptEnabled") ~= enabled then
		ctx.SetPrompt(anchor, enabled, nil)
	end
end

-- Prompt of every anchor of the station with this action.
local function promptAll(ctx: Context, station: Station, action: string, want: (anchor: Instance) -> boolean)
	for _, anchor in station.Anchors do
		if anchor:GetAttribute("PromptAction") == action then
			setPrompt(ctx, anchor, want(anchor))
		end
	end
end

local function canPlace(ctx: Context, station: Station): boolean
	const amount = ctx.GetStock(ingredientOf(station))
	if amount < 1 then
		return false
	end
	const grill = freeSlot(ctx, station.Vehicle)
	return grill ~= nil
end

-- The anchor's slot, if it is the slot attachment of the current level and holds a Ready sausage.
local function readySlot(station: Station, anchor: Instance): number?
	const slot = slotOf(anchor)
	if slot == nil then
		return nil
	end
	-- an anchor tied to another upgrade level is not this level's slot
	if type(anchor:GetAttribute("Level")) == "number" and station.Slots[slot] ~= anchor then
		return nil
	end
	const record = station.Records[slot]
	if record == nil or record.State ~= "Ready" then
		return nil
	end
	return slot
end

local function refreshCollect(ctx: Context, station: Station)
	const room = Rail.Room(station.Vehicle) > 0
	promptAll(ctx, station, COLLECT, function(anchor: Instance): boolean
		return room and readySlot(station, anchor) ~= nil
	end)
end

local function refreshPlace(ctx: Context, station: Station)
	const enabled = canPlace(ctx, station)
	promptAll(ctx, station, PLACE, function(_anchor: Instance): boolean
		return enabled
	end)
end

-- Actions -------------------------------------------------------------------------------------------------------------

const place: StationApi.Action = {
	Validate = function(ctx: Context, station: Station, _player: Player, _anchor: Instance): (boolean, string?)
		if station.Kind ~= STOCK then
			return false, nil
		end
		return canPlace(ctx, station), nil
	end,
	Run = function(ctx: Context, station: Station, player: Player, _anchor: Instance)
		const grill, slot = freeSlot(ctx, station.Vehicle)
		if grill == nil or slot == nil then
			return
		end
		-- the unit leaves the stock only together with a free slot (never one without the other)
		if not ctx.TakeStock(ingredientOf(station), 1) then
			return
		end
		grill.Records[slot] = {
			Kind = GRILL,
			State = "Working",
			StartedAt = ctx.Now(),
			Duration = cookTime(ctx, player),
			Count = 0,
		}
		sync(ctx, grill)
		ctx.Publish(grill)
		refreshCollect(ctx, grill)
		refreshPlace(ctx, station)
	end,
}

const collect: StationApi.Action = {
	Validate = function(_ctx: Context, station: Station, _player: Player, anchor: Instance): (boolean, string?)
		if station.Kind ~= GRILL or readySlot(station, anchor) == nil then
			return false, nil
		end
		return Rail.Room(station.Vehicle) > 0, nil
	end,
	Run = function(ctx: Context, station: Station, _player: Player, anchor: Instance)
		const slot = readySlot(station, anchor)
		if slot == nil or not Rail.Push(ctx, station.Vehicle) then
			return
		end
		station.Records[slot] = StationApi.empty(GRILL)
		sync(ctx, station)
		ctx.Publish(station)
		refreshCollect(ctx, station)
	end,
}

-- StationApi.Module ---------------------------------------------------------------------------------------------------

const Grill = {
	Kinds = { GRILL, STOCK },
	Actions = {
		[PLACE] = place,
		[COLLECT] = collect,
	} :: { [string]: StationApi.Action },
}

function Grill.Bind(ctx: Context, station: Station)
	station.State = nil
	if station.Kind == GRILL then
		for index = #grills, 1, -1 do
			const other = grills[index]
			if other.Instance == station.Instance or not alive(other) then
				table.remove(grills, index)
			end
		end
		table.insert(grills, station)
		table.clear(station.Records)
		sync(ctx, station)
		ctx.Publish(station)
		refreshCollect(ctx, station)
	else
		refreshPlace(ctx, station)
	end
end

-- 10 Hz, current vehicle only: finish cooking, follow level/vehicle changes, keep prompts in step with stock and rail.
function Grill.Tick(ctx: Context, station: Station, now: number)
	if station.Kind ~= GRILL then
		refreshPlace(ctx, station)
		return
	end
	local changed = sync(ctx, station)
	for _, record in station.Records do
		if record.State == "Working" and now >= record.StartedAt + record.Duration then
			record.State = "Ready"
			changed = true
		end
	end
	if changed then
		ctx.Publish(station)
	end
	refreshCollect(ctx, station)
end

-- Upgrade level of the grill changed: Slots were rebuilt by KitchenService.
function Grill.Refresh(ctx: Context, station: Station)
	if station.Kind == GRILL and sync(ctx, station) then
		ctx.Publish(station)
	end
end

function Grill.Capture(_ctx: Context, _station: Station): any
	return nil
end

function Grill.Restore(ctx: Context, station: Station, _data: any)
	if station.Kind ~= GRILL then
		return
	end
	table.clear(station.Records)
	sync(ctx, station)
	ctx.Publish(station)
	refreshCollect(ctx, station)
end

return Grill
