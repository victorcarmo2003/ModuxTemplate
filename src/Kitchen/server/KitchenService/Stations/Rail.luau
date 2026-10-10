--!strict
-- Resting rail (FEAT-006 step 3; architecture.md §18.4, §18.12; network.md §3.5; TASK-026). StationKind "rail".
-- No actions: a FIFO of grilled sausages fed by "Collect" on the grill (Grill.luau) and drained by "Add Sausage" on
-- the board (Board.luau, TASK-027). One Stations record (Slot 0): State Ready with >= 1 sausage, Count = how many.
-- Capacity = Content.Vehicles[station.Vehicle].RailSlots (cart 6, trailer 8).
-- Other station modules use the functions below (require(script.Parent.Rail)); KitchenService serializes per
-- station, and every call here is synchronous, so a Push/Pop never interleaves with another one.
-- Snapshot: nothing kept (data.md §2.2: the shift restarts with an empty rail).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local StationApi = require(script.Parent.Parent.StationApi)

type Context = StationApi.Context
type Station = StationApi.Station

-- Private state of a rail station: server time each sausage arrived, oldest first.
type RailState = { Queue: { number } }

const KIND = "rail"
const RECORD_SLOT = 0 -- single-record station (network.md §3.5)
const COUNT_MAX = 30 -- Stations.Count wire range

-- Bound rail stations (one per vehicle expected). Stale entries (station removed/re-added) are skipped by alive().
const bound: { Station } = {}

local function alive(station: Station): boolean
	const instance = station.Instance
	return instance.Parent ~= nil
		and instance:IsDescendantOf(workspace)
		and instance:GetAttribute("StationId") == station.Id
end

local function stateOf(station: Station): RailState
	const state = station.State
	if type(state) == "table" and type(state.Queue) == "table" then
		return state :: RailState
	end
	const fresh: RailState = { Queue = {} }
	station.State = fresh
	return fresh
end

local function capacityOf(station: Station): number
	const vehicle = Content.Vehicles.ByKey[station.Vehicle]
	const slots = if vehicle then vehicle.RailSlots else 0
	return math.clamp(slots, 0, COUNT_MAX)
end

local function write(ctx: Context, station: Station)
	const count = #stateOf(station).Queue
	station.Records[RECORD_SLOT] = {
		Kind = KIND,
		State = if count > 0 then "Ready" else "Empty",
		StartedAt = 0,
		Duration = 0,
		Count = count,
	}
	ctx.Publish(station)
end

const Rail = {
	Kinds = { KIND },
	Actions = {} :: { [string]: StationApi.Action },
}

-- Public API for the other station modules --------------------------------------------------------------------------

-- Rail of a vehicle (first alive one by StationId), nil if the vehicle has none.
function Rail.Find(vehicle: string): Station?
	local best: Station? = nil
	for _, station in bound do
		if station.Vehicle == vehicle and alive(station) and (best == nil or station.Id < best.Id) then
			best = station
		end
	end
	return best
end

-- Sausages resting on the vehicle's rail.
function Rail.Count(vehicle: string): number
	const station = Rail.Find(vehicle)
	return if station then #stateOf(station).Queue else 0
end

-- Free places on the vehicle's rail (0 without a rail).
function Rail.Room(vehicle: string): number
	const station = Rail.Find(vehicle)
	if station == nil then
		return 0
	end
	return math.max(capacityOf(station) - #stateOf(station).Queue, 0)
end

-- Adds one grilled sausage at the end of the queue. False when there is no rail or it is full.
function Rail.Push(ctx: Context, vehicle: string): boolean
	const station = Rail.Find(vehicle)
	if station == nil then
		return false
	end
	const queue = stateOf(station).Queue
	if #queue >= capacityOf(station) then
		return false
	end
	table.insert(queue, ctx.Now())
	write(ctx, station)
	return true
end

-- Takes the oldest sausage (FIFO). False when the rail is empty.
function Rail.Pop(ctx: Context, vehicle: string): boolean
	const station = Rail.Find(vehicle)
	if station == nil then
		return false
	end
	const queue = stateOf(station).Queue
	if #queue == 0 then
		return false
	end
	table.remove(queue, 1)
	write(ctx, station)
	return true
end

-- StationApi.Module ---------------------------------------------------------------------------------------------------

function Rail.Bind(ctx: Context, station: Station)
	for index = #bound, 1, -1 do
		const other = bound[index]
		if other.Instance == station.Instance or not alive(other) then
			table.remove(bound, index)
		end
	end
	table.insert(bound, station)
	station.State = { Queue = {} } :: RailState
	write(ctx, station)
end

function Rail.Capture(_ctx: Context, _station: Station): any
	return nil
end

function Rail.Restore(ctx: Context, station: Station, _data: any)
	table.clear(stateOf(station).Queue)
	write(ctx, station)
end

return Rail
