--!strict
-- Rest rail pile (FEAT-006 step 3; architecture.md §18.4, §18.12; network.md §3.5; TASK-026). StationKind "rail".
-- World kitchen (kitchen-world.md §1-§3; DEC-306, DEC-308; TASK-568/569): a FIFO of grilled sausages fed by "Collect" on the
-- grill (Grill.luau) and drained by "Add Sausage" (plate_add_sausage, Prompt_Rail): the oldest sausage goes on the plate in the
-- hand of who touched (ctx.FillPlate; with a bun already on it the plate becomes the hot_dog Tool). One Stations record
-- (Slot 0): State Ready with >= 1 sausage, Count = how many. Capacity = Content.Vehicles[station.Vehicle].RailSlots (8).
-- Other station modules use the functions below (require(script.Parent.Rail)); KitchenService serializes per station, and
-- every call here is synchronous, so a Push/Pop never interleaves with another one.
-- Refusals (toasts via Refusal.luau): empty pile -> pile_empty; the plate already has a sausage -> plate_full; no bun on it yet
-- -> plate_needs_bun. No plate in
-- hand stays silent (the client shows the prompt only with one, Requires.Held = plate).
-- Snapshot: nothing kept (data.md §2.2: the shift restarts with an empty rail).
-- Wave 3 (TASK-109, ANM-002, ITM-020): Alter puts one gray sausage at the FRONT of the queue (the next "Add Sausage" of any
-- player takes it, and the plate carries Altered), using one rail place, no stock. At most one altered sausage per rail.
-- Record.Altered = its position 1..Count (nil when none).
-- Every entry carries the flip-bonus stamp (Entry.Flip, true = flipped inside the window, Grill.luau): it goes on the plate
-- as Flipped and lifts the grade one band (Grade.Assembly, kitchen-world.md §4).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local PlateTool = require(ReplicatedStorage.shared.Plate.PlateTool)
local StationApi = require(script.Parent.Parent.StationApi)
local Refusal = require(script.Parent.Parent.Refusal)

type Context = StationApi.Context
type Station = StationApi.Station

-- One sausage on the rail: server time it arrived; Altered = the anomaly's gray sausage (ITM-020); Score = grill flip
-- score 0..100 (nil = not flipped); Flip = the flip bonus stamp (false for an unflipped / late-flipped / altered sausage).
type Entry = { At: number, Altered: boolean, Score: number?, Flip: boolean }

-- Private state of a rail station: sausages in take order (front = next "Add Sausage").
type RailState = { Queue: { Entry } }

const KIND = "rail"
const RECORD_SLOT = 0 -- single-record station (network.md §3.5)
const COUNT_MAX = 30 -- Stations.Count wire range
const ADD = "plate_add_sausage"
const SAUSAGE = "Sausage"

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

-- Position 1..#Queue of the altered sausage, nil when there is none.
local function alteredAt(queue: { Entry }): number?
	for index, entry in queue do
		if entry.Altered then
			return index
		end
	end
	return nil
end

local function write(ctx: Context, station: Station)
	const queue = stateOf(station).Queue
	const count = #queue
	const altered = alteredAt(queue)
	station.Records[RECORD_SLOT] = {
		Kind = KIND,
		State = if count > 0 then "Ready" else "Empty",
		StartedAt = 0,
		Duration = 0,
		Count = count,
		Altered = if altered ~= nil and altered <= COUNT_MAX then altered else nil,
	}
	ctx.Publish(station)
end

-- "Add Sausage" -------------------------------------------------------------------------------------------------------

-- (plate?, notice?): a plate in hand without a sausage and a sausage on the pile.
local function canAdd(ctx: Context, station: Station, player: Player): (Tool?, string?)
	if station.Kind ~= KIND then
		return nil, nil
	end
	const plate = ctx.HeldPlate(player)
	if plate == nil then
		return nil, nil
	end
	if plate:GetAttribute(SAUSAGE) == true then
		return nil, "plate_full"
	end
	if plate:GetAttribute("Bun") ~= true then
		return nil, "plate_needs_bun" -- plate, bun, then sausage (owner 2026-10-19)
	end
	if #stateOf(station).Queue < 1 then
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
	-- Inside the rail lock, synchronous: the front sausage leaves only when the plate took it.
	Run = function(ctx: Context, station: Station, player: Player, _anchor: Instance)
		const plate = canAdd(ctx, station, player)
		const queue = stateOf(station).Queue
		const front = queue[1]
		if plate == nil or front == nil then
			return
		end
		-- the flip score first (cooking focus, DEC-310): FillPlate may turn the plate into the hot dog, which carries Scores over
		PlateTool.SetScore(plate, "flip", front.Score or Content.Prep.Grades.Unflipped)
		if not ctx.FillPlate(player, plate, "Sausage", { Altered = front.Altered, Flipped = front.Flip }) then
			return
		end
		table.remove(queue, 1)
		write(ctx, station)
	end,
}

const Rail = {
	Kinds = { KIND },
	Actions = {
		[ADD] = add,
	} :: { [string]: StationApi.Action },
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

-- Adds one grilled sausage at the end of the queue. False when there is no rail or it is full. `score` = the grill flip
-- score (nil = not flipped), `flip` = the flip bonus stamp (nil = false).
function Rail.Push(ctx: Context, vehicle: string, score: number?, flip: boolean?): boolean
	const station = Rail.Find(vehicle)
	if station == nil then
		return false
	end
	const queue = stateOf(station).Queue
	if #queue >= capacityOf(station) then
		return false
	end
	const entry: Entry = { At = ctx.Now(), Altered = false, Score = score, Flip = flip == true }
	table.insert(queue, entry)
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

-- Wave 3 (TASK-109): one altered sausage at the front of this rail. False without room or with one already there.
-- `slot` is ignored (the position is always the next one to be used, ITM-020).
function Rail.Alter(ctx: Context, station: Station, _slot: number?): boolean
	const queue = stateOf(station).Queue
	if alteredAt(queue) ~= nil or #queue >= capacityOf(station) then
		return false
	end
	const entry: Entry = { At = ctx.Now(), Altered = true, Flip = false }
	table.insert(queue, 1, entry)
	write(ctx, station)
	return true
end

-- Removes the altered sausage (the place it held frees up). True when there was one.
function Rail.ClearAltered(ctx: Context, station: Station): boolean
	const queue = stateOf(station).Queue
	const index = alteredAt(queue)
	if index == nil then
		return false
	end
	table.remove(queue, index)
	write(ctx, station)
	return true
end

function Rail.Capture(_ctx: Context, _station: Station): any
	return nil
end

function Rail.Restore(ctx: Context, station: Station, _data: any)
	table.clear(stateOf(station).Queue)
	write(ctx, station)
end

return Rail
