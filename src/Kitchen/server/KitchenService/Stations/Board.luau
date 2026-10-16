--!strict
-- Cutting board (FEAT-006 steps 4-5; DEC-190, DEC-215; architecture.md §18.4, §18.12; network.md §3.5; TASK-027).
-- StationKind "board". Shared slots: Slot attachments Att_Bun1..n, n = Content.Vehicles[vehicle].BoardSlots (cart 2,
-- trailer 3). One Stations record per active slot (Kind "board"):
--   Empty     free slot
--   Working   whole bun being sliced (StartedAt + Duration = Stations.bun_crate.Params.CutTime, 0.8 s)
--   Ready     sliced bun waiting for "Add Sausage"
-- "Slice Bun" is on the bun crate (BunCrate.luau) and uses Board.Free/Board.Place below.
--   board_add_sausage (Prompt_Board, tap, one prompt)  rail >= 1 and a sliced bun: the oldest sliced bun (DEC-190)
--                 gets the oldest sausage of the rail (Rail.Pop) and becomes the HotDog Tool in the hand of who
--                 touched; the slot is freed. Hotbar full = ItemService refuses with "Hands full" and nothing moves.
-- Prompts (Provisional, TASK-027): "Add Sausage" on only with a sliced bun and >= 1 sausage on the rail.
-- Snapshot: nothing kept (data.md §2.2: the shift restarts with an empty board).
-- Wave 3 (TASK-109, ANM-002, ITM-020): Alter puts a bitten bun, already sliced (Ready), on a free active slot
-- (Record.Altered = 1, no stock). A hot dog made with an altered bun or the rail's altered sausage gets the Tool
-- attribute Altered = true (ctx.Give -> ItemService GiveOptions.Altered). Every hot dog made emits "assembled" (player, { Altered }) through ctx.Emit.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local StationApi = require(script.Parent.Parent.StationApi)
local Rail = require(script.Parent.Rail)

type Context = StationApi.Context
type Station = StationApi.Station

const KIND = "board"
const ADD = "board_add_sausage"
const HOT_DOG = "hot_dog"

-- Private state: slots held by an open prep plate (TASK-169). A reserved slot is never finished by Tick nor taken by
-- "Add Sausage"; Board.Reserve / ClaimAltered / Release are the only writers.
type BoardState = { Reserved: { [number]: boolean } }

-- Bound boards (one per vehicle expected). Stale entries (station removed/re-added) are skipped by alive().
const bound: { Station } = {}

local function reservedOf(station: Station): { [number]: boolean }
	const state = station.State
	if type(state) == "table" and type(state.Reserved) == "table" then
		return (state :: BoardState).Reserved
	end
	const fresh: BoardState = { Reserved = {} }
	station.State = fresh
	return fresh.Reserved
end

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

-- Oldest sliced bun (earliest StartedAt + Duration, then lowest Slot), nil if none.
local function oldestReady(station: Station): number?
	local best: number? = nil
	local bestAt = math.huge
	const reserved = reservedOf(station)
	for slot, record in station.Records do
		if record.State ~= "Ready" or reserved[slot] then
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

local function canAdd(station: Station): boolean
	return station.Kind == KIND and oldestReady(station) ~= nil and Rail.Count(station.Vehicle) >= 1
end

local function refreshAdd(ctx: Context, station: Station)
	const enabled = canAdd(station)
	for _, anchor in station.Anchors do
		if anchor:GetAttribute("PromptAction") == ADD and anchor:GetAttribute("PromptEnabled") ~= enabled then
			ctx.SetPrompt(anchor, enabled, nil)
		end
	end
end

-- Actions -------------------------------------------------------------------------------------------------------------

const add: StationApi.Action = {
	Validate = function(_ctx: Context, station: Station, _player: Player, _anchor: Instance): (boolean, string?)
		return canAdd(station), nil
	end,
	-- Inside the board lock. Give, Pop and the slot write are synchronous: no other action runs in between, so two
	-- players on the same bun never both get a hot dog. Give first: a refused Give ("Hands full", notified by
	-- ItemService) leaves the rail and the bun untouched.
	Run = function(ctx: Context, station: Station, player: Player, _anchor: Instance)
		const slot = oldestReady(station)
		if slot == nil or Rail.Count(station.Vehicle) < 1 then
			return
		end
		-- read before Give: the altered sausage is at the front of the rail, so it is the one Pop takes
		const bun = station.Records[slot]
		const altered = (bun ~= nil and (bun.Altered or 0) > 0) or Rail.FrontAltered(station.Vehicle)
		if not ctx.Give(player, HOT_DOG, if altered then { Altered = true } else nil) then
			return
		end
		if not Rail.Pop(ctx, station.Vehicle) then
			warn(`[Board] hot dog given to {player.Name} but the rail was empty`)
		end
		station.Records[slot] = StationApi.empty(KIND)
		sync(station)
		ctx.Publish(station)
		refreshAdd(ctx, station)
		ctx.Emit("assembled", player, { Altered = altered })
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

-- Prep mode (TASK-169) -----------------------------------------------------------------------------------------------

-- Holds a free slot for a plate: `slot` if it is free and active, else the lowest free one. The record reads Working
-- for `duration` seconds (the plate's lifetime) and Tick leaves it alone. Returns the slot, nil = no free slot.
-- TASK-260 (owner request 2026-10-14): the plate of a slot is seen by EVERY player in the world. The board model carries the
-- attribute `Plate<slot>` (replicated): nil = no plate, else the cosmetic PlateMask of the plate (0 = the bun only). Written
-- here at Reserve / Claim (0) and Release (nil), and by KitchenService:SetPlateMask as the plate grows.
const PLATE_ATTRIBUTE = "Plate"

function Board.SetPlate(vehicle: string, slot: number, mask: number?)
	const station = Board.Find(vehicle)
	if station == nil or station.Instance.Parent == nil then
		return
	end
	station.Instance:SetAttribute(`{PLATE_ATTRIBUTE}{slot}`, mask)
end

function Board.Reserve(ctx: Context, vehicle: string, slot: number?, duration: number): number?
	const station = Board.Find(vehicle)
	if station == nil then
		return nil
	end
	local target: number? = nil
	if slot ~= nil then
		const record = station.Records[slot]
		if station.Slots[slot] ~= nil and (record == nil or record.State == "Empty") then
			for _, active in activeSlots(station) do
				if active == slot then
					target = slot
					break
				end
			end
		end
	end
	if target == nil then
		target = Board.Free(vehicle)
	end
	if target == nil then
		return nil
	end
	station.Records[target] = {
		Kind = KIND,
		State = "Working",
		StartedAt = ctx.Now(),
		Duration = math.clamp(duration, 0, 120),
		Count = 0,
	}
	reservedOf(station)[target] = true
	sync(station)
	ctx.Publish(station)
	Board.SetPlate(vehicle, target, 0)
	return target
end

-- Takes the sliced altered bun (ANM-002) that sits free on the board for a plate. Returns its slot, nil = none.
-- TASK-346: `preferred` (the seat's slot) receives the bun when it is a free active slot, so the 3D Build view that works on
-- the seat's slot hides the world's copy and draws it as the plate's bun.
function Board.ClaimAltered(ctx: Context, vehicle: string, preferred: number?): number?
	const station = Board.Find(vehicle)
	if station == nil then
		return nil
	end
	const reserved = reservedOf(station)
	for slot, record in station.Records do
		if record.State == "Ready" and (record.Altered or 0) > 0 and not reserved[slot] then
			local target = slot
			if preferred ~= nil and preferred ~= slot and table.find(activeSlots(station), preferred) ~= nil then
				const free = station.Records[preferred]
				if not reserved[preferred] and (free == nil or free.State == "Empty") then
					station.Records[preferred] = record
					station.Records[slot] = StationApi.empty(KIND)
					target = preferred
					sync(station)
					ctx.Publish(station)
				end
			end
			reserved[target] = true
			refreshAdd(ctx, station)
			Board.SetPlate(vehicle, target, 0)
			return target
		end
	end
	return nil
end

-- True while the plate still holds this slot (an altered bun may be cleared at 6:00 AM under it).
function Board.Holds(vehicle: string, slot: number): boolean
	const station = Board.Find(vehicle)
	if station == nil then
		return false
	end
	const record = station.Records[slot]
	return reservedOf(station)[slot] == true and record ~= nil and record.State ~= "Empty"
end

-- Ends a plate's hold. keep = the altered bun goes back to the board as it was (Ready, free); otherwise the slot empties.
function Board.Release(ctx: Context, vehicle: string, slot: number, keep: boolean)
	const station = Board.Find(vehicle)
	if station == nil then
		return
	end
	const reserved = reservedOf(station)
	if not reserved[slot] then
		return
	end
	reserved[slot] = nil
	Board.SetPlate(vehicle, slot, nil)
	if not keep then
		station.Records[slot] = StationApi.empty(KIND)
	end
	sync(station)
	ctx.Publish(station)
	refreshAdd(ctx, station)
end

-- Wave 3 (TASK-109): a bitten bun, already sliced, on `slot` (nil = lowest free active slot). One per board.
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
	refreshAdd(ctx, station)
	return true
end

-- Removes the bitten bun (its slot frees up). True when there was one.
function Board.ClearAltered(ctx: Context, station: Station): boolean
	local removed = false
	const reserved = reservedOf(station)
	for slot, record in station.Records do
		if (record.Altered or 0) > 0 then
			station.Records[slot] = StationApi.empty(KIND)
			reserved[slot] = nil -- a plate holding it finds the slot gone (Board.Holds = false)
			removed = true
		end
	end
	if removed then
		sync(station)
		ctx.Publish(station)
		refreshAdd(ctx, station)
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
	station.State = { Reserved = {} } :: BoardState
	table.clear(station.Records)
	sync(station)
	ctx.Publish(station)
	refreshAdd(ctx, station)
end

-- 10 Hz, current vehicle only: finish slicing, keep "Add Sausage" in step with the rail.
function Board.Tick(ctx: Context, station: Station, now: number)
	local changed = sync(station)
	const reserved = reservedOf(station)
	for slot, record in station.Records do
		if record.State == "Working" and not reserved[slot] and now >= record.StartedAt + record.Duration then
			record.State = "Ready"
			changed = true
		end
	end
	if changed then
		ctx.Publish(station)
	end
	refreshAdd(ctx, station)
end

function Board.Capture(_ctx: Context, _station: Station): any
	return nil
end

function Board.Restore(ctx: Context, station: Station, _data: any)
	table.clear(station.Records)
	table.clear(reservedOf(station))
	sync(station)
	ctx.Publish(station)
	refreshAdd(ctx, station)
end

return Board
