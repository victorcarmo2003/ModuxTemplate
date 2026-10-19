--!strict
-- Resting rail (FEAT-006 step 3; architecture.md §18.4, §18.12; network.md §3.5; TASK-026). StationKind "rail".
-- No actions: a FIFO of grilled sausages fed by "Collect" on the grill (Grill.luau) and drained by "Add Sausage" on
-- the board (Board.luau, TASK-027). One Stations record (Slot 0): State Ready with >= 1 sausage, Count = how many.
-- Capacity = Content.Vehicles[station.Vehicle].RailSlots (cart 6, trailer 8).
-- Other station modules use the functions below (require(script.Parent.Rail)); KitchenService serializes per
-- station, and every call here is synchronous, so a Push/Pop never interleaves with another one.
-- Snapshot: nothing kept (data.md §2.2: the shift restarts with an empty rail).
-- Wave 3 (TASK-109, ANM-002, ITM-020): Alter puts one gray sausage at the FRONT of the queue (the next "Add Sausage"
-- of any player takes it), using one rail place, no stock. At most one altered sausage per rail. Record.Altered =
-- its position 1..Count (nil when none). Pop tells the board whether the sausage it took was the altered one.
-- Restaurant (TASK-378; tech/restaurant-flow.md rev. 2 §2.3, design FEAT-045), behind Content.Restaurant.Rules.Enabled:
--   rail_take (anchor with PromptAction rail_take inside the rail station, tap "Take Dogs")  the front sausages -> the
--             sausage_grilled stack in hand (Tool Count, cap Content.Restaurant.Stacks.Sausage), or a new sausage_grilled
--             Tool when the hand holds none (ItemService limits: hotbar, CategoryLimits.Ingredient -> hands_full). Takes as
--             many as fit, FIFO; Count of the record drops by the same amount. The altered sausage (ANM-002) is never
--             taken here (it stays at the front for the board; the restaurant anomalies come with wave R4): with it at the
--             front the prompt is off. Prompt off while the rail is empty or the flag is off.
-- Conveyor kitchen (TASK-515; tech/prep-conveyor.md §5, DT-E6), Content.Prep.Rules.Mode = "Conveyor": this rail IS the shared rest
-- table. Capacity = Content.Prep.Conveyor.Rest.Capacity (8, DEC-305); fed by the grill's auto rest (Grill.luau), drained by any
-- assembler through PrepStage Dog: PopAt(position) takes THAT sausage (any position without someone else's claim; the
-- claims live in PrepService, the client suggests the front one, P10). Every entry carries the flip-bonus stamp
-- (Entry.Flip, true = flipped inside the window), handed back by PopAt / At / Pop / Front so PrepService can write it on the
-- plate as FlipBonus (paid once per plate at the sale, TASK-517). "Take Dogs" (rail_take) is off in the conveyor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local StationApi = require(script.Parent.Parent.StationApi)
local Refusal = require(script.Parent.Parent.Refusal)

type Context = StationApi.Context
type Station = StationApi.Station

-- One sausage on the rail: server time it arrived; Altered = the anomaly's gray sausage (ITM-020); Score = grill flip
-- score 0..100 stamped by the server (prep mode, TASK-169; nil = not graded: world "Collect", altered sausage).
-- Flip = the conveyor flip bonus stamp (TASK-515; false outside the conveyor, for an unflipped or late-flipped sausage and
-- for the altered one).
type Entry = { At: number, Altered: boolean, Score: number?, Flip: boolean }

-- What PopAt / At hand back (tech/prep-conveyor.md §10.2, Bridge.Dog): a copy, never the queue entry itself.
export type Taken = { Score: number?, Flip: boolean, Altered: boolean }

-- Private state of a rail station: sausages in take order (front = next "Add Sausage").
type RailState = { Queue: { Entry } }

const KIND = "rail"
const RECORD_SLOT = 0 -- single-record station (network.md §3.5)
const COUNT_MAX = 30 -- Stations.Count wire range
const TAKE = "rail_take"
const ITEM = "sausage_grilled"

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

local function beltMode(): boolean
	return Content.Prep.Rules.Mode == "Conveyor"
end

-- Conveyor: the rest table holds Conveyor.Rest.Capacity (Validate keeps it <= Vehicles.trailer.RailSlots and PrepGrab.Slot 8).
local function capacityOf(station: Station): number
	if beltMode() then
		return math.clamp(math.floor(Content.Prep.Conveyor.Rest.Capacity), 0, COUNT_MAX)
	end
	const vehicle = Content.Vehicles.ByKey[station.Vehicle]
	const slots = if vehicle then vehicle.RailSlots else 0
	return math.clamp(slots, 0, COUNT_MAX)
end

local function copyOf(entry: Entry): Taken
	return { Score = entry.Score, Flip = entry.Flip, Altered = entry.Altered }
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

-- Restaurant "Take Dogs" ------------------------------------------------------------------------------------------------

local function stackCap(): number
	return math.max(math.floor(Content.Restaurant.Stacks.Sausage), 1)
end

-- Held sausage_grilled stack and its Count (nil, 0 when the hand holds something else or nothing).
local function heldStack(ctx: Context, player: Player): (Tool?, number)
	const tool = ctx.Held(player)
	if tool == nil or tool:GetAttribute("Item") ~= ITEM then
		return nil, 0
	end
	const raw = tool:GetAttribute("Count")
	return tool, if type(raw) == "number" then math.floor(raw) else 1
end

-- Sausages "Take Dogs" can take now from the front (stops at the altered one).
local function takeable(station: Station): number
	local count = 0
	for _, entry in stateOf(station).Queue do
		if entry.Altered then
			break
		end
		count += 1
	end
	return count
end

local function refreshTake(ctx: Context, station: Station)
	const on = not beltMode() and takeable(station) > 0
	for _, anchor in station.Anchors do
		if anchor:GetAttribute("PromptAction") == TAKE and anchor:GetAttribute("PromptEnabled") ~= on then
			ctx.SetPrompt(anchor, on, nil)
		end
	end
end

const take: StationApi.Action = {
	Validate = function(ctx: Context, station: Station, player: Player, _anchor: Instance): (boolean, string?)
		if beltMode() or station.Kind ~= KIND or takeable(station) < 1 then
			return false, nil
		end
		const tool, count = heldStack(ctx, player)
		if tool ~= nil and count >= stackCap() then
			Refusal.notify(ctx, player, "hands_full", nil)
			return false, nil
		end
		return true, nil
	end,
	-- Inside the rail lock, synchronous: the Tool first (the hand limits can refuse it), then the sausages leave the rail.
	Run = function(ctx: Context, station: Station, player: Player, _anchor: Instance)
		const tool, count = heldStack(ctx, player)
		const room = stackCap() - (if tool ~= nil then count else 0)
		const amount = math.min(room, takeable(station))
		if amount < 1 then
			return
		end
		if tool ~= nil then
			ctx.Consume(player, tool)
		end
		if not ctx.Give(player, ITEM, { Count = count + amount }) then
			if tool ~= nil then
				warn(`[Rail] sausage_grilled stack of {player.Name} lost on restack ({count})`)
			end
			return -- a new stack refused: ItemService already told the player (hands_full)
		end
		const queue = stateOf(station).Queue
		for _ = 1, amount do
			table.remove(queue, 1)
		end
		write(ctx, station)
		refreshTake(ctx, station)
	end,
}

const Rail = {
	Kinds = { KIND },
	Actions = {
		[TAKE] = take,
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

-- Adds one grilled sausage at the end of the queue. False when there is no rail or it is full. `score` = the flip score
-- of the prep mode grill (nil = the sausage carries no grade). `flip` = the conveyor flip-bonus stamp (TASK-515; nil = false).
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

-- Front sausage without taking it: (exists, altered, score, flip bonus). Read only.
function Rail.Front(vehicle: string): (boolean, boolean, number?, boolean)
	const station = Rail.Find(vehicle)
	const front = if station then stateOf(station).Queue[1] else nil
	if front == nil then
		return false, false, nil, false
	end
	return true, front.Altered, front.Score, front.Flip
end

-- Sausage at position `index` (1 = the front, 1..Count) without taking it: a copy, nil when there is none. Read only.
function Rail.At(vehicle: string, index: number): Taken?
	const station = Rail.Find(vehicle)
	const entry = if station then stateOf(station).Queue[index] else nil
	return if entry then copyOf(entry) else nil
end

-- Conveyor rest table (TASK-515; prep-conveyor.md §5, §10.2 Bridge.Dog / KitchenService:TakeRest): takes the sausage at position
-- `index` (1 = the front; any position, the altered one included: it is how ANM-002 reaches a plate). The places behind it move
-- one forward (PrepService reindexes its claims, SausageLeft). Returns (copy of the entry with Score, Flip = the flip bonus
-- for the plate's FlipBonus, Altered; nil) or (nil, "Empty"). Synchronous.
function Rail.PopAt(ctx: Context, vehicle: string, index: number): (Taken?, string?)
	const station = Rail.Find(vehicle)
	if station == nil or index ~= math.floor(index) then
		return nil, "Empty"
	end
	const queue = stateOf(station).Queue
	const entry = queue[index]
	if entry == nil then
		return nil, "Empty"
	end
	table.remove(queue, index)
	write(ctx, station)
	return copyOf(entry), nil
end

-- True when the next sausage "Add Sausage" would take is the altered one (read only).
function Rail.FrontAltered(vehicle: string): boolean
	const station = Rail.Find(vehicle)
	if station == nil then
		return false
	end
	const front = stateOf(station).Queue[1]
	return front ~= nil and front.Altered
end

-- Takes the front sausage (FIFO; an altered one sits at the front). Returns (taken, it was the altered one, its grill
-- flip score or nil, its conveyor flip bonus).
function Rail.Pop(ctx: Context, vehicle: string): (boolean, boolean, number?, boolean)
	const station = Rail.Find(vehicle)
	if station == nil then
		return false, false, nil, false
	end
	const queue = stateOf(station).Queue
	if #queue == 0 then
		return false, false, nil, false
	end
	const entry = table.remove(queue, 1)
	write(ctx, station)
	if entry == nil then
		return false, false, nil, false
	end
	return true, entry.Altered, entry.Score, entry.Flip
end

-- The bin by drag (prep mode, 2026-10-12): removes the sausage at position `index` (1 = the front) of the vehicle's rail. The altered
-- sausage is never thrown away from here (only a hot dog resolves ANM-002). (true, nil) or (false, "Empty" | "Altered").
function Rail.DiscardAt(ctx: Context, vehicle: string, index: number): (boolean, string?)
	const station = Rail.Find(vehicle)
	if station == nil then
		return false, "Empty"
	end
	const queue = stateOf(station).Queue
	const entry = queue[index]
	if entry == nil then
		return false, "Empty"
	end
	if entry.Altered then
		return false, "Altered"
	end
	table.remove(queue, index)
	write(ctx, station)
	return true, nil
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
	refreshTake(ctx, station)
end

-- 10 Hz, current vehicle only: keep "Take Dogs" in step with the rail (fed by the grill's Collect) and the flag.
function Rail.Tick(ctx: Context, station: Station, _now: number)
	refreshTake(ctx, station)
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
