--!strict
-- Cut-bun pile (FEAT-006 steps 4-5; DEC-190, DEC-215; architecture.md §18.4, §18.12; network.md §3.5; TASK-027). StationKind
-- "board". World kitchen (kitchen-world.md §1-§3; DEC-306, DEC-308; TASK-568/569): the model TLR_BUN_CUT, slots Att_Bun1..n,
-- n = Content.Vehicles[vehicle].BoardSlots (8). One Stations record per active slot (Kind "board"):
--   Empty     free place
--   Working   bun being sliced (StartedAt + Duration = Stations.bun_crate.Params.CutTime, 0.8 s)
--   Ready     cut bun waiting on the pile
-- "Slice Bun" is on the bun crate (BunCrate.luau) and uses Board.Free/Board.Place below.
--   plate_add_bun (Prompt_Board, tap "Add Bun")  the oldest cut bun (DEC-190) goes on the plate in the hand of who touched
--                 (ctx.FillPlate; with a sausage already on it the plate becomes the hot_dog Tool); the place frees up.
-- Refusals (toasts via Refusal.luau): no cut bun -> pile_empty; the plate already has a bun -> plate_full. No plate in hand
-- stays silent (the client shows the prompt only with one, Requires.Held = plate).
-- Snapshot: nothing kept (data.md §2.2: the shift restarts with an empty pile).
-- Wave 3 (TASK-109, ANM-002, ITM-020): Alter puts a bitten bun, already cut (Ready), on a free active slot (Record.Altered =
-- 1, no stock). A plate that takes it carries Altered (the hot dog it becomes keeps the Tool attribute Altered = true).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local StationApi = require(script.Parent.Parent.StationApi)
local Refusal = require(script.Parent.Parent.Refusal)

type Context = StationApi.Context
type Station = StationApi.Station

const KIND = "board"
const ADD = "plate_add_bun"
const BUN = "Bun"

-- Bound boards (one per vehicle expected). Stale entries (station removed/re-added) are skipped by alive().
const bound: { Station } = {}

local function alive(station: Station): boolean
	const instance = station.Instance
	return instance.Parent ~= nil
		and instance:IsDescendantOf(workspace)
		and instance:GetAttribute("StationId") == station.Id
end

-- Slots 1..BoardSlots of the station's vehicle that have an attachment.
local function activeSlots(station: Station): { number }
	const vehicle = Content.Vehicles.ByKey[station.Vehicle]
	const limit = if vehicle then vehicle.BoardSlots else 0
	const out: { number } = {}
	for slot in station.Slots do
		if slot <= limit then
			table.insert(out, slot)
		end
	end
	table.sort(out)
	return out
end

-- Records = active slots (missing ones enter Empty) + any busy slot outside them (never dropped with a bun on it).
local function sync(station: Station): boolean
	local changed = false
	const active: { [number]: boolean } = {}
	for _, slot in activeSlots(station) do
		active[slot] = true
		if station.Records[slot] == nil then
			station.Records[slot] = StationApi.empty(KIND)
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

-- Oldest cut bun (earliest StartedAt + Duration, then lowest Slot), nil if none.
local function oldestReady(station: Station): number?
	local best: number? = nil
	local bestAt = math.huge
	for slot, record in station.Records do
		if record.State ~= "Ready" then
			continue
		end
		const at = record.StartedAt + record.Duration
		if at < bestAt or (at == bestAt and best ~= nil and slot < best) then
			best = slot
			bestAt = at
		end
	end
	return best
end

-- Actions -------------------------------------------------------------------------------------------------------------

-- (plate?, notice?): a plate in hand without a bun and a cut bun on the pile.
local function canAdd(ctx: Context, station: Station, player: Player): (Tool?, string?)
	if station.Kind ~= KIND then
		return nil, nil
	end
	const plate = ctx.HeldPlate(player)
	if plate == nil then
		return nil, nil
	end
	if plate:GetAttribute(BUN) == true then
		return nil, "plate_full"
	end
	if oldestReady(station) == nil then
		return nil, "pile_empty"
	end
	return plate, nil
end

const add: StationApi.Action = {
	Validate = function(ctx: Context, station: Station, player: Player, _anchor: Instance): (boolean, string?)
		const plate, notice = canAdd(ctx, station, player)
		if notice ~= nil then
			Refusal.notify(ctx, player, notice, nil)
		end
		return plate ~= nil, nil
	end,
	-- Inside the board lock, synchronous: two players on the same bun never both get it; the bun leaves only when the plate
	-- took it.
	Run = function(ctx: Context, station: Station, player: Player, _anchor: Instance)
		const plate = canAdd(ctx, station, player)
		const slot = oldestReady(station)
		if plate == nil or slot == nil then
			return
		end
		const bun = station.Records[slot]
		const altered = bun ~= nil and (bun.Altered or 0) > 0
		if not ctx.FillPlate(player, plate, "Bun", { Altered = altered }) then
			return
		end
		station.Records[slot] = StationApi.empty(KIND)
		sync(station)
		ctx.Publish(station)
	end,
}

-- StationApi.Module ---------------------------------------------------------------------------------------------------

const Board = {
	Kinds = { KIND },
	Actions = {
		[ADD] = add,
	} :: { [string]: StationApi.Action },
}

-- Public API for BunCrate.luau ----------------------------------------------------------------------------------------

-- Board of a vehicle (first alive one by StationId), nil if the vehicle has none.
function Board.Find(vehicle: string): Station?
	local best: Station? = nil
	for _, station in bound do
		if station.Vehicle == vehicle and alive(station) and (best == nil or station.Id < best.Id) then
			best = station
		end
	end
	return best
end

-- Lowest free active slot of the vehicle's board (read only), nil if none.
function Board.Free(vehicle: string): number?
	const station = Board.Find(vehicle)
	if station == nil then
		return nil
	end
	for _, slot in activeSlots(station) do
		const record = station.Records[slot]
		if record == nil or record.State == "Empty" then
			return slot
		end
	end
	return nil
end

-- Cut buns waiting on the vehicle's pile (Ready).
function Board.Count(vehicle: string): number
	const station = Board.Find(vehicle)
	if station == nil then
		return 0
	end
	local count = 0
	for _, record in station.Records do
		if record.State == "Ready" then
			count += 1
		end
	end
	return count
end

-- Puts a whole bun on that slot, sliced in `duration` seconds. False when the slot is not free. Synchronous.
function Board.Place(ctx: Context, vehicle: string, slot: number, duration: number): boolean
	const station = Board.Find(vehicle)
	if station == nil then
		return false
	end
	const record = station.Records[slot]
	if (record ~= nil and record.State ~= "Empty") or station.Slots[slot] == nil then
		return false
	end
	station.Records[slot] = {
		Kind = KIND,
		State = "Working",
		StartedAt = ctx.Now(),
		Duration = duration,
		Count = 0,
	}
	sync(station)
	ctx.Publish(station)
	return true
end

-- Wave 3 (TASK-109): a bitten bun, already cut, on `slot` (nil = lowest free active slot). One per board.
function Board.Alter(ctx: Context, station: Station, slot: number?): boolean
	for _, record in station.Records do
		if (record.Altered or 0) > 0 then
			return false
		end
	end
	local target: number? = nil
	for _, active in activeSlots(station) do
		const record = station.Records[active]
		if (slot == nil or slot == active) and (record == nil or record.State == "Empty") then
			target = active
			break
		end
	end
	if target == nil then
		return false
	end
	station.Records[target] = {
		Kind = KIND,
		State = "Ready",
		StartedAt = ctx.Now(),
		Duration = 0,
		Count = 0,
		Altered = 1,
	}
	sync(station)
	ctx.Publish(station)
	return true
end

-- Removes the bitten bun (its slot frees up). True when there was one.
function Board.ClearAltered(ctx: Context, station: Station): boolean
	local removed = false
	for slot, record in station.Records do
		if (record.Altered or 0) > 0 then
			station.Records[slot] = StationApi.empty(KIND)
			removed = true
		end
	end
	if removed then
		sync(station)
		ctx.Publish(station)
	end
	return removed
end

function Board.Bind(ctx: Context, station: Station)
	for index = #bound, 1, -1 do
		const other = bound[index]
		if other.Instance == station.Instance or not alive(other) then
			table.remove(bound, index)
		end
	end
	table.insert(bound, station)
	station.State = nil
	table.clear(station.Records)
	sync(station)
	ctx.Publish(station)
end

-- 10 Hz, current vehicle only: finish slicing.
function Board.Tick(ctx: Context, station: Station, now: number)
	local changed = sync(station)
	for _, record in station.Records do
		if record.State == "Working" and now >= record.StartedAt + record.Duration then
			record.State = "Ready"
			changed = true
		end
	end
	if changed then
		ctx.Publish(station)
	end
end

function Board.Capture(_ctx: Context, _station: Station): any
	return nil
end

function Board.Restore(ctx: Context, station: Station, _data: any)
	table.clear(station.Records)
	sync(station)
	ctx.Publish(station)
end

return Board
