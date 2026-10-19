--!strict
-- Grill + sausage stock (FEAT-006 steps 1-3; UPG-001; DEC-015, DEC-046, DEC-069, DEC-201, DEC-298; architecture.md §18.4,
-- §18.12; network.md §3.5; TASK-026). StationKinds "grill" and "sausage_stock" (§18.12). World kitchen (kitchen-world.md §1-§3;
-- DEC-306, DEC-308; TASK-568):
--   grill_place   (sausage_stock, tap "Grill")  1 sausage from stock -> lowest free slot of the grill of the touched anchor (its
--                 own grill, the grill that contains the stock Model, else the nearest one; one grill = lowest free slot of the
--                 vehicle); Duration = Effect GrillTime (8/6/4 s, UPG-001; DEC-305) x Modifier GrillTime of who placed it
--   Tick 10 Hz    Working -> Ready at StartedAt + Duration, flipped or not. Never burns (DEC-298): a Ready sausage waits on the
--                 grill for as long as it takes.
--   grill_flip    (optional, tap "Flip") once, only while Working. Server clock minus the tap latency (<= 0.3 s): inside
--                 Restaurant.Grill.FlipFrom..FlipTo of the Duration it stamps the bonus; the flip score is Grade.Score grill_flip
--                 of the distance to the middle of that window (kitchen-focus.md §3). The cook schedule never moves.
--                 Stations.Flip = score + 1. The bonus travels to the
--                 rest rail (Rail Entry.Flip), to the plate (attribute Flipped) and lifts the grade one band (Grade.Assembly).
--                 Anchor: PromptAction grill_flip inside the grill station, slot = attribute FlipSlot, else the Slot of its
--                 parent, else its own Slot; on Bind each one moves onto its slot anchor (one pill per slot).
--   grill_collect (grill slot anchor Att_Slot<n>, tap "Collect")  Ready slot -> end of the rest rail pile (Rail.luau)
-- One prompt per slot (R-3): Working and not flipped = Flip, Ready = Collect, else none.
-- Active slots = Slot attachments 1..GrillSlots of the current level (2/3/4); a slot added by an upgrade enters Empty,
-- slots in progress never restart (network.md §3.5). One Stations record per active slot. Snapshot: nothing kept.
-- Refusal toasts (D-04, TASK-080, via Refusal.luau): "Grill" with no stock -> out_of_stock {item}, with no free slot ->
-- grill_full; "Collect" with the rail full -> rail_full (the sausage waits on the grill). A wrong kind stays silent.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Grade = require(ReplicatedStorage.shared.Prep.Grade)
local StationApi = require(script.Parent.Parent.StationApi)
local Rail = require(script.Parent.Rail)
local Refusal = require(script.Parent.Parent.Refusal)

type Context = StationApi.Context
type Station = StationApi.Station

-- Private state of a grill: flip score by slot (set when the sausage is flipped, cleared when it leaves the slot); Bonus =
-- flipped inside the window, same lifetime.
type GrillState = { Flipped: { [number]: number }, Bonus: { [number]: boolean } }

const GRILL = "grill"
const STOCK = "sausage_stock"
const PLACE = "grill_place"
const COLLECT = "grill_collect"
const FLIP = "grill_flip"
const SAUSAGE = "sausage"
const SLOTS_STAT = "GrillSlots"
const TIME_STAT = "GrillTime"
const DURATION_STEP = 0.1 -- Stations.Duration is quant(0, 120, 0.1): the server uses the value the wire carries
const DURATION_MAX = 120
const LATENCY_MAX = 0.3 -- s: the tap latency the server gives back to a flip
-- flip score (kitchen-focus.md §3): Grade.Score grill_flip of the distance to the middle of the window, % of the cook time
local function flipScore(fraction: number): number
	const window = Content.Restaurant.Grill
	const middle = (window.FlipFrom + window.FlipTo) / 2
	return Grade.Score(Content.Prep, "grill_flip", math.abs(fraction - middle) * 100)
end

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

local function stateOf(station: Station): GrillState
	const state = station.State
	if type(state) == "table" and type(state.Flipped) == "table" and type(state.Bonus) == "table" then
		return state :: GrillState
	end
	const fresh: GrillState = { Flipped = {}, Bonus = {} }
	station.State = fresh
	return fresh
end

local function flippedOf(station: Station): { [number]: number }
	return stateOf(station).Flipped
end

local function bonusOf(station: Station): { [number]: boolean }
	return stateOf(station).Bonus
end

-- The sausage of `slot` left the grill (or a new one came in): its flip stamps go.
local function clearStamps(station: Station, slot: number)
	flippedOf(station)[slot] = nil
	bonusOf(station)[slot] = nil
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

-- Lowest free active slot of ONE grill (`preferred` first when it is active and free).
local function freeSlotOn(ctx: Context, grill: Station, preferred: number?): number?
	const slots = activeSlots(ctx, grill)
	if preferred ~= nil and preferred >= 1 and table.find(slots, preferred) ~= nil then
		const record = grill.Records[preferred]
		if record == nil or record.State == "Empty" then
			return preferred
		end
	end
	for _, slot in slots do
		const record = grill.Records[slot]
		if record == nil or record.State == "Empty" then
			return slot
		end
	end
	return nil
end

local function positionOf(instance: Instance): Vector3?
	if instance:IsA("Attachment") then
		return instance.WorldPosition
	elseif instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Model") then
		return instance:GetPivot().Position
	end
	return nil
end

-- Grill a grill_place anchor feeds (restaurant, 2+ grills): its own grill, the grill that contains the stock Model, else
-- the grill nearest to the anchor. nil = the vehicle has at most one grill (lowest free slot of the vehicle, as before).
local function targetGrill(station: Station, anchor: Instance?): Station?
	if station.Kind == GRILL then
		return station
	end
	const list = grillsOf(station.Vehicle)
	if #list <= 1 then
		return nil
	end
	for _, grill in list do
		if station.Instance:IsDescendantOf(grill.Instance) then
			return grill
		end
	end
	const at = (if anchor then positionOf(anchor) else nil) or positionOf(station.Instance)
	if at == nil then
		return nil
	end
	local best: Station? = nil
	local bestDistance = math.huge
	for _, grill in list do
		const distance = (grill.Instance:GetPivot().Position - at).Magnitude
		if distance < bestDistance then
			best = grill
			bestDistance = distance
		end
	end
	return best
end

-- Lowest free active slot over the vehicle's grills (read only: a slot without a record yet counts as free). `preferred`
-- (prep-3d.md §7.2 N1, TASK-195): that slot when it is active and free, otherwise the lowest one (nil / 0 = as before).
local function freeSlot(ctx: Context, vehicle: string, preferred: number?): (Station?, number?)
	if preferred ~= nil and preferred >= 1 then
		for _, grill in grillsOf(vehicle) do
			const record = grill.Records[preferred]
			if table.find(activeSlots(ctx, grill), preferred) ~= nil and (record == nil or record.State == "Empty") then
				return grill, preferred
			end
		end
	end
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

-- (ok, notice?): stock first (restocking is what the player can do), then a free slot (of the anchor's grill when the
-- vehicle has 2+ grills).
local function canPlace(ctx: Context, station: Station, anchor: Instance?): (boolean, string?)
	const amount = ctx.GetStock(ingredientOf(station))
	if amount < 1 then
		return false, "out_of_stock"
	end
	const target = targetGrill(station, anchor)
	const free = if target ~= nil then freeSlotOn(ctx, target, nil) ~= nil else freeSlot(ctx, station.Vehicle) ~= nil
	if not free then
		return false, "grill_full"
	end
	return true, nil
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

-- Slot a grill_flip anchor flips: FlipSlot, else the Slot of its parent, else its own Slot.
local function flipSlotOf(anchor: Instance): number?
	const own = anchor:GetAttribute("FlipSlot")
	if type(own) == "number" and own == math.floor(own) and own >= 1 then
		return own
	end
	const parent = anchor.Parent
	return (if parent then slotOf(parent) else nil) or slotOf(anchor)
end

-- The sausage of the slot can still be flipped: Working and not flipped yet.
local function canFlip(station: Station, slot: number): boolean
	const record = station.Records[slot]
	return record ~= nil and record.State == "Working" and record.Flip == nil and flippedOf(station)[slot] == nil
end

-- The one prompt a slot may show (R-3): FLIP while it can be flipped, COLLECT when Ready, nil otherwise.
local function slotPrompt(station: Station, slot: number, _now: number): string?
	if canFlip(station, slot) then
		return FLIP
	end
	const record = station.Records[slot]
	if record ~= nil and record.State == "Ready" then
		return COLLECT
	end
	return nil
end

local function refreshCollect(ctx: Context, station: Station)
	const room = Rail.Room(station.Vehicle) > 0
	const now = ctx.Now()
	promptAll(ctx, station, COLLECT, function(anchor: Instance): boolean
		const slot = readySlot(station, anchor)
		return room and slot ~= nil and slotPrompt(station, slot, now) == COLLECT
	end)
end

local function refreshPlace(ctx: Context, station: Station)
	promptAll(ctx, station, PLACE, function(anchor: Instance): boolean
		return (canPlace(ctx, station, anchor))
	end)
end

local function refreshFlip(ctx: Context, station: Station)
	const now = ctx.Now()
	promptAll(ctx, station, FLIP, function(anchor: Instance): boolean
		const slot = flipSlotOf(anchor)
		return slot ~= nil and slotPrompt(station, slot, now) == FLIP
	end)
end

-- R-3: each flip anchor sits on the slot anchor it flips, so Flip and Collect share one spot.
local function alignFlipAnchors(station: Station)
	for _, anchor in station.Anchors do
		if anchor:GetAttribute("PromptAction") ~= FLIP or not anchor:IsA("Attachment") then
			continue
		end
		const slot = flipSlotOf(anchor)
		const spot = if slot ~= nil then station.Slots[slot] else nil
		if spot ~= nil and spot ~= anchor then
			anchor.WorldCFrame = spot.WorldCFrame
		end
	end
end

-- Moves --------------------------------------------------------------------------

-- Moves one sausage from the stock station to the lowest free grill slot (of `target` only, when given). Synchronous, all
-- or nothing: the unit leaves the stock only together with a free slot. Returns (slot, grill) or (nil, nil, reason):
-- "NoStock" | "Full". `stock` is the station whose anchor was touched (sausage_stock, or the grill itself).
local function placeSausage(
	ctx: Context,
	stock: Station,
	player: Player,
	preferred: number?,
	target: Station?
): (number?, Station?, string?)
	local found: Station? = target
	local free: number? = nil
	if target ~= nil then
		free = freeSlotOn(ctx, target, preferred)
	else
		found, free = freeSlot(ctx, stock.Vehicle, preferred)
	end
	if found == nil or free == nil then
		return nil, nil, "Full"
	end
	const grill: Station = found
	const slot: number = free :: number
	if not ctx.TakeStock(ingredientOf(stock), 1) then
		return nil, nil, "NoStock"
	end
	grill.Records[slot] = {
		Kind = GRILL,
		State = "Working",
		StartedAt = ctx.Now(),
		Duration = cookTime(ctx, player),
		Count = 0,
		Flip = nil,
	}
	clearStamps(grill, slot)
	sync(ctx, grill)
	ctx.Publish(grill)
	refreshCollect(ctx, grill)
	refreshPlace(ctx, stock)
	if grill ~= stock then
		refreshPlace(ctx, grill)
	end
	return slot, grill, nil
end

-- Moves the Ready sausage of `slot` to the rest rail with its flip stamps. Returns (ok, reason?) with reason "NotReady" |
-- "RailFull".
local function collectSlot(ctx: Context, grill: Station, slot: number): (boolean, string?)
	const record = grill.Records[slot]
	if record == nil or record.State ~= "Ready" then
		return false, "NotReady"
	end
	if Rail.Room(grill.Vehicle) <= 0 then
		return false, "RailFull"
	end
	if not Rail.Push(ctx, grill.Vehicle, flippedOf(grill)[slot], bonusOf(grill)[slot] == true) then
		return false, "RailFull"
	end
	clearStamps(grill, slot)
	grill.Records[slot] = StationApi.empty(GRILL)
	sync(ctx, grill)
	ctx.Publish(grill)
	refreshCollect(ctx, grill)
	return true, nil
end

-- Actions -------------------------------------------------------------------------------------------------------------

const place: StationApi.Action = {
	Validate = function(ctx: Context, station: Station, player: Player, anchor: Instance): (boolean, string?)
		if station.Kind ~= STOCK and station.Kind ~= GRILL then
			return false, nil
		end
		const ok, notice = canPlace(ctx, station, anchor)
		if notice == "out_of_stock" then
			Refusal.notify(ctx, player, notice, Refusal.ingredient(ingredientOf(station)))
		elseif notice ~= nil then
			Refusal.notify(ctx, player, notice, nil)
		end
		return ok, nil
	end,
	Run = function(ctx: Context, station: Station, player: Player, anchor: Instance)
		placeSausage(ctx, station, player, nil, targetGrill(station, anchor))
	end,
}

const collect: StationApi.Action = {
	Validate = function(ctx: Context, station: Station, player: Player, anchor: Instance): (boolean, string?)
		const slot = if station.Kind == GRILL then readySlot(station, anchor) else nil
		if slot == nil or slotPrompt(station, slot, ctx.Now()) ~= COLLECT then
			return false, nil
		end
		if Rail.Room(station.Vehicle) <= 0 then
			Refusal.notify(ctx, player, "rail_full", nil)
			return false, nil
		end
		return true, nil
	end,
	Run = function(ctx: Context, station: Station, _player: Player, anchor: Instance)
		const slot = readySlot(station, anchor)
		if slot == nil then
			return
		end
		collectSlot(ctx, station, slot)
	end,
}

-- Flips the sausage of `slot` on THIS grill once, only while Working (a Ready one is done cooking). Inside
-- Restaurant.Grill.FlipFrom..FlipTo of the Duration (server clock, `latency` = the tap's way to the server, clamped) it stamps
-- the bonus. The cook schedule never moves. Returns (score, nil) or (nil, reason): "Empty" | "Flipped" | "Ready".
local function flipOn(ctx: Context, grill: Station, slot: number, latency: number?): (number?, string?)
	const record = grill.Records[slot]
	if record == nil or record.State == "Empty" then
		return nil, "Empty"
	end
	if flippedOf(grill)[slot] ~= nil then
		return nil, "Flipped"
	end
	if record.State ~= "Working" then
		return nil, "Ready"
	end
	const seen = ctx.Now() - math.clamp(latency or 0, 0, LATENCY_MAX)
	const window = Content.Restaurant.Grill
	const fraction = if record.Duration > 0 then (seen - record.StartedAt) / record.Duration else -1
	const bonus = fraction >= window.FlipFrom and fraction <= window.FlipTo
	const score = flipScore(fraction)
	flippedOf(grill)[slot] = score
	bonusOf(grill)[slot] = bonus
	record.Flip = score + 1
	ctx.Publish(grill)
	refreshFlip(ctx, grill)
	return score, nil
end

-- "Flip" on a slot of the touched grill, while it cooks.
const flip: StationApi.Action = {
	Validate = function(ctx: Context, station: Station, _player: Player, anchor: Instance): (boolean, string?)
		if station.Kind ~= GRILL then
			return false, nil
		end
		const slot = flipSlotOf(anchor)
		return slot ~= nil and slotPrompt(station, slot, ctx.Now()) == FLIP, nil
	end,
	Run = function(ctx: Context, station: Station, player: Player, anchor: Instance)
		const slot = flipSlotOf(anchor)
		if slot == nil then
			return
		end
		flipOn(ctx, station, slot, player:GetNetworkPing())
	end,
}

-- StationApi.Module ---------------------------------------------------------------------------------------------------

const Grill = {
	Kinds = { GRILL, STOCK },
	Actions = {
		[PLACE] = place,
		[COLLECT] = collect,
		[FLIP] = flip,
	} :: { [string]: StationApi.Action },
}

-- Public API (KitchenService) ------------------------------------------------------------------------------------------

-- The grill of a vehicle with the lowest StationId, nil when it has none.
function Grill.Find(vehicle: string): Station?
	return grillsOf(vehicle)[1]
end

-- Cooking focus (kitchen-focus.md §1 #3): one sausage from `stock` (the sausage_stock station) onto `slot` of `grill` when that
-- slot is active and free. (true, nil) or (false, notice?): out_of_stock / grill_full (the caller toasts), nil = silent.
function Grill.PlaceAt(ctx: Context, grill: Station, stock: Station, player: Player, slot: number): (boolean, string?)
	if grill.Kind ~= GRILL or stock.Kind ~= STOCK then
		return false, nil
	end
	if table.find(activeSlots(ctx, grill), slot) == nil then
		return false, nil
	end
	const record = grill.Records[slot]
	if record ~= nil and record.State ~= "Empty" then
		return false, "grill_full"
	end
	if ctx.GetStock(ingredientOf(stock)) < 1 then
		return false, "out_of_stock"
	end
	const placed = placeSausage(ctx, stock, player, slot, grill)
	return placed == slot, nil
end

-- Cooking focus: flips the sausage of `slot` (only while it cooks, once). Returns its flip score, nil = refused.
function Grill.FlipAt(ctx: Context, grill: Station, slot: number, latency: number?): number?
	const score = flipOn(ctx, grill, slot, latency)
	return score
end

-- Cooking focus (DEC-310): the Ready sausage of `slot` goes to the rest rail with its flip stamps, as "Collect" does.
-- Returns (ok, reason?) with reason "NotReady" | "RailFull".
function Grill.CollectAt(ctx: Context, grill: Station, slot: number): (boolean, string?)
	return collectSlot(ctx, grill, slot)
end

-- Sausages on the grills of the vehicle (any slot that is not Empty).
function Grill.Busy(vehicle: string): number
	local count = 0
	for _, grill in grillsOf(vehicle) do
		for _, record in grill.Records do
			if record.State ~= "Empty" then
				count += 1
			end
		end
	end
	return count
end

function Grill.Bind(ctx: Context, station: Station)
	station.State = if station.Kind == GRILL then { Flipped = {}, Bonus = {} } :: GrillState else nil
	if station.Kind == GRILL then
		for index = #grills, 1, -1 do
			const other = grills[index]
			if other.Instance == station.Instance or not alive(other) then
				table.remove(grills, index)
			end
		end
		table.insert(grills, station)
		alignFlipAnchors(station)
		table.clear(station.Records)
		sync(ctx, station)
		ctx.Publish(station)
		refreshCollect(ctx, station)
		refreshPlace(ctx, station)
		refreshFlip(ctx, station)
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
		-- no pause, flipped or not; never burns (DEC-298)
		if record.State == "Working" and now >= record.StartedAt + record.Duration then
			record.State = "Ready"
			changed = true
		end
	end
	if changed then
		ctx.Publish(station)
	end
	refreshCollect(ctx, station)
	refreshPlace(ctx, station)
	refreshFlip(ctx, station)
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
	table.clear(flippedOf(station))
	table.clear(bonusOf(station))
	sync(ctx, station)
	ctx.Publish(station)
	refreshCollect(ctx, station)
end

return Grill
