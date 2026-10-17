--!strict
-- Grill + sausage stock (FEAT-006 steps 1-3; UPG-001; DEC-015, DEC-046, DEC-069, DEC-201; architecture.md §18.4,
-- §18.12; network.md §3.5; TASK-026). StationKinds "grill" and "sausage_stock" (§18.12).
--   grill_place   (sausage_stock, tap "Grill")  1 sausage from stock -> lowest free slot of the vehicle's grill;
--                 Duration = Effect GrillTime (12/10/8 s) x Modifier GrillTime of who placed it (Line Cook 0.85)
--   Tick 10 Hz    Working -> Ready when the sausage was FLIPPED and StartedAt + Duration is reached (no burning in the MVP). The
--                 cook is two sides (2026-10-14): the first takes Duration - Rules.Grill.PostFlip s, then the sausage WAITS (Working,
--                 progress paused, the flip window open) until the flip; Flip re-bases StartedAt so PostFlip s (1 s) later it is Ready.
--   grill_collect (grill slot anchor Att_Slot<n>, tap "Collect")  Ready slot -> end of the rail queue (Rail.luau)
-- Active slots = Slot attachments 1..GrillSlots of the current level (2/3/4); a slot added by an upgrade enters
-- Empty, slots in progress never restart (network.md §3.5). One Stations record per active slot.
-- Prompts (Provisional, TASK-026): "Grill" off while no slot is free or the stock is 0; "Collect" on only on a Ready
-- slot with room on the rail. Snapshot: nothing kept (data.md §2.2: the shift restarts with an empty grill).
-- Refusal toasts (D-04, TASK-080, via Refusal.luau): "Grill" with no stock -> out_of_stock {item}, with no free slot ->
-- grill_full; "Collect" with the rail full -> rail_full. A wrong kind or a slot that is not Ready stays silent.
-- Prep mode (TASK-169; prep-mode.md §2): Grill.PlaceFor / Flip / CollectSlot are the same moves without a prompt. Flip
-- stamps the sausage with the SERVER clock and scores it with Prep.Grade.FlipScore (distance to 50% of the Duration,
-- window 40%..60%, no burning); the score travels with the sausage on the rail (Entry.Score). Never flipped = Messy
-- (Grades.Unflipped, Q-222) when collected through the prep mode; the world "Collect" carries no grade.
-- Restaurant (TASK-378; tech/restaurant-flow.md rev. 2 §2.3, §3.3; design FEAT-045):
--   grill_place  goes to the grill of the TOUCHED anchor: an anchor inside a grill station places on that grill; an anchor
--                of a sausage_stock places on the grill that contains the stock Model, else on the grill nearest to the
--                anchor. With one grill on the vehicle (the trailer) nothing changes: lowest free slot of the vehicle.
--   grill_flip   (behind Content.Restaurant.Rules.Enabled) anchor with PromptAction grill_flip inside the grill station; its
--                slot = attribute FlipSlot, else the Slot of its parent, else its own Slot. On only while that slot is in the
--                pause (Working, first side done, not flipped yet); Run = the same move as Grill.Flip (server clock, ping).
--                Authoring hint for the map: a separate Attachment Att_Flip<n> with FlipSlot = n and NO Slot attribute
--                (an Attachment with Slot is a slot of the grill, KitchenService CollectParts).
--   one prompt per slot (R-3, docs/tests/restaurant-e2e.md): Flip and Collect of the same slot never show together; the
--                slot state picks one (slotPrompt: pause = Flip, Ready = Collect, else none) and both refreshers and both
--                Validates follow it. On Bind (switch on) every Att_Flip<n> is moved onto the slot anchor of n (the map has
--                it 0.35 stud over the Collect), so a slot shows one pill in one place.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Grade = require(ReplicatedStorage.shared.Prep.Grade)
local StationApi = require(script.Parent.Parent.StationApi)
local Rail = require(script.Parent.Rail)
local Refusal = require(script.Parent.Parent.Refusal)

type Context = StationApi.Context
type Station = StationApi.Station

-- Private state of a grill: flip score by slot (set when the sausage is flipped, cleared when it leaves the slot).
type GrillState = { Flipped: { [number]: number } }

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
const FLIP_SLACK = 0.1 -- s: a flip this much before the pause still counts (network jitter)

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

local function flippedOf(station: Station): { [number]: number }
	const state = station.State
	if type(state) == "table" and type(state.Flipped) == "table" then
		return (state :: GrillState).Flipped
	end
	const fresh: GrillState = { Flipped = {} }
	station.State = fresh
	return fresh.Flipped
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

-- The slot is in the pause: Working, first side done (FLIP_SLACK early still counts), not flipped yet.
local function inPause(station: Station, slot: number, now: number): boolean
	const record = station.Records[slot]
	if record == nil or record.State ~= "Working" or record.Flip ~= nil or flippedOf(station)[slot] ~= nil then
		return false
	end
	return now >= record.StartedAt + Grade.FirstSide(Content.Prep, record.Duration) - FLIP_SLACK
end

-- The one prompt a slot may show (R-3): FLIP in the pause (restaurant only), COLLECT when Ready, nil otherwise.
local function slotPrompt(station: Station, slot: number, now: number): string?
	if Content.Restaurant.Rules.Enabled and inPause(station, slot, now) then
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

-- Restaurant on (R-3): each flip anchor sits on the slot anchor it flips, so Flip and Collect share one spot.
local function alignFlipAnchors(station: Station)
	if not Content.Restaurant.Rules.Enabled then
		return
	end
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

-- Shared moves (prompt actions and prep mode) --------------------------------------------------------------------------

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
	flippedOf(grill)[slot] = nil
	sync(ctx, grill)
	ctx.Publish(grill)
	refreshCollect(ctx, grill)
	refreshPlace(ctx, stock)
	if grill ~= stock then
		refreshPlace(ctx, grill)
	end
	return slot, grill, nil
end

-- Slot of the vehicle's grills (lowest StationId first): (grill, record) or nil.
local function findSlot(vehicle: string, slot: number): (Station?, StationApi.Record?)
	for _, grill in grillsOf(vehicle) do
		const record = grill.Records[slot]
		if record ~= nil then
			return grill, record
		end
	end
	return nil, nil
end

-- Moves the Ready sausage of `slot` to the rail with its flip score (Unflipped when it never was). Returns (ok, reason?)
-- with reason "NotReady" | "RailFull".
local function collectSlot(ctx: Context, grill: Station, slot: number, graded: boolean): (boolean, string?)
	const record = grill.Records[slot]
	if record == nil or record.State ~= "Ready" then
		return false, "NotReady"
	end
	if Rail.Room(grill.Vehicle) <= 0 then
		return false, "RailFull"
	end
	const flipped = flippedOf(grill)[slot]
	local score: number? = flipped
	if score == nil and graded then
		score = Content.Prep.Grades.Unflipped
	end
	if not Rail.Push(ctx, grill.Vehicle, score) then
		return false, "RailFull"
	end
	flippedOf(grill)[slot] = nil
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
		collectSlot(ctx, station, slot, false)
	end,
}

-- Flips the sausage of `slot` on THIS grill once (see Grill.Flip). Returns (score, nil) or (nil, reason).
local function flipOn(ctx: Context, grill: Station, slot: number, latency: number?): (number?, string?)
	const record = grill.Records[slot]
	if record == nil or record.State == "Empty" then
		return nil, "Empty"
	end
	const flipped = flippedOf(grill)
	if flipped[slot] ~= nil then
		return nil, "Flipped"
	end
	const now = ctx.Now()
	const first = Grade.FirstSide(Content.Prep, record.Duration)
	const seen = now - math.clamp(latency or 0, 0, 0.3)
	const tolerance = Content.Prep.Tolerances.ByKey["grill_flip"]
	const score = Grade.FlipScore(Content.Prep, tolerance, record.StartedAt, seen, record.Duration)
	flipped[slot] = score
	if now >= record.StartedAt + first - FLIP_SLACK then
		record.StartedAt = now - first
	end
	-- N2: the stamp goes on the wire as score + 1 (0 / nil = not flipped), cleared by Collect (empty record) and Place
	record.Flip = math.clamp(math.floor(score + 0.5), 0, 100) + 1
	ctx.Publish(grill)
	refreshFlip(ctx, grill)
	return score, nil
end

-- Restaurant "Flip" on a slot of the touched grill, only in the pause (TASK-378).
const flip: StationApi.Action = {
	Validate = function(ctx: Context, station: Station, _player: Player, anchor: Instance): (boolean, string?)
		if not Content.Restaurant.Rules.Enabled or station.Kind ~= GRILL then
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

-- Public API for the prep mode (KitchenService/Plate.luau; every call is synchronous) ------------------------------------

-- Sausage from `stock` (a sausage_stock station) to the lowest free grill slot. (slot, nil) or (nil, reason): "NoStock" | "Full".
-- `preferred` = the slot the player dropped on (PrepGrill Slot 1..8): used when free, else the lowest free one; nil / 0 = lowest.
function Grill.PlaceFor(ctx: Context, stock: Station, player: Player, preferred: number?): (number?, string?)
	if stock.Kind ~= STOCK then
		return nil, "Full"
	end
	const slot, _, reason = placeSausage(ctx, stock, player, preferred)
	return slot, reason
end

-- Flips the sausage of `slot` once, only after the first side is done (the pause). The score comes from the SERVER clock: the
-- delay between the pause and the flip. The flip re-bases StartedAt so the second side runs PostFlip s from now.
-- Returns (score, nil) or (nil, reason): "Empty" | "Flipped" | "Early".
-- TASK-257: `latency` = s the tap took to reach the server (Player:GetNetworkPing, clamped): the swing is graded where the player
-- saw it. A flip before the pause is accepted with the worst grade and keeps the cooking schedule (no time is skipped); a flip
-- in the pause re-bases StartedAt so the second side runs PostFlip s from now.
-- TASK-378: the restaurant "Flip" prompt runs the same move on the touched grill (flipOn).
function Grill.Flip(ctx: Context, vehicle: string, slot: number, latency: number?): (number?, string?)
	const grill = findSlot(vehicle, slot)
	if grill == nil then
		return nil, "Empty"
	end
	return flipOn(ctx, grill, slot, latency)
end

-- Ready sausage of `slot` to the rail, graded (never flipped = Grades.Unflipped). (true, nil) or (false, reason): "Empty" | "NotReady" | "RailFull".
function Grill.CollectSlot(ctx: Context, vehicle: string, slot: number): (boolean, string?)
	const grill = findSlot(vehicle, slot)
	if grill == nil then
		return false, "Empty"
	end
	return collectSlot(ctx, grill, slot, true)
end

-- The bin by drag (prep mode, 2026-10-12): the sausage of `slot` (raw, cooking or ready, flipped or not) is thrown away. The unit
-- that left the stock is lost. (true, nil) or (false, "Empty").
function Grill.Discard(ctx: Context, vehicle: string, slot: number): (boolean, string?)
	const grill, record = findSlot(vehicle, slot)
	if grill == nil or record == nil or record.State == "Empty" then
		return false, "Empty"
	end
	flippedOf(grill)[slot] = nil
	grill.Records[slot] = StationApi.empty(GRILL)
	sync(ctx, grill)
	ctx.Publish(grill)
	refreshCollect(ctx, grill)
	return true, nil
end

-- Flip score of the sausage in `slot`, nil = not flipped (or no sausage).
function Grill.FlipScoreOf(vehicle: string, slot: number): number?
	const grill = findSlot(vehicle, slot)
	return if grill then flippedOf(grill)[slot] else nil
end

-- Dev (`prep kitchen`): pretends `seconds` have passed for the sausage of `slot` (no waiting for the 10 Hz Tick).
function Grill.DevAge(ctx: Context, vehicle: string, slot: number, seconds: number): boolean
	const grill, record = findSlot(vehicle, slot)
	if grill == nil or record == nil or record.State == "Empty" then
		return false
	end
	record.StartedAt -= seconds
	if record.State == "Working" and record.Flip ~= nil and ctx.Now() >= record.StartedAt + record.Duration then
		record.State = "Ready"
	end
	ctx.Publish(grill)
	refreshCollect(ctx, grill)
	return true
end

-- Dev: Flip field of the record of `slot` as the wire carries it (score + 1), 0 = nil / no record.
function Grill.DevFlipWire(vehicle: string, slot: number): number
	const _, record = findSlot(vehicle, slot)
	return if record and record.Flip then record.Flip else 0
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

-- Dev: Duration of the sausage in `slot`, 0 = none.
function Grill.DevDuration(vehicle: string, slot: number): number
	const _, record = findSlot(vehicle, slot)
	return if record and record.State ~= "Empty" then record.Duration else 0
end

function Grill.Bind(ctx: Context, station: Station)
	station.State = if station.Kind == GRILL then { Flipped = {} } :: GrillState else nil
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
		-- an unflipped sausage waits for the flip however long it takes (no burning)
		if record.State == "Working" and record.Flip ~= nil and now >= record.StartedAt + record.Duration then
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
	sync(ctx, station)
	ctx.Publish(station)
	refreshCollect(ctx, station)
end

return Grill
