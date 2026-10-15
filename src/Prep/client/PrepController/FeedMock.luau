--!strict
-- FeedMock: the stand-in "server" of `/dev prep ui` for the Order, Grill and Serve stages (TASK-177, TASK-179). It keeps a
-- tiny world (a line of customers, four grill slots, a rail) and answers the same acts the PrepService answers, in the same
-- raw shapes the Feed reads from the real controllers (Customers records, Stations records), so the preview runs the very
-- same code as Play. Nothing here touches the network, the stock or any controller; scores come from Prep/shared/Grade.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Grade = require(ReplicatedStorage.shared.Prep.Grade)

const prep = Content.Prep

export type RawCustomer = {
	Id: number,
	State: string, -- Arriving | Queued | Ordering | Waiting | Leaving (Customers set)
	Slot: number, -- 0 = out of the queue (a table), 1..5 = Q1..Q5
	Order: { string }, -- topping keys, display order
	PatienceEndsAt: number,
	PatienceSpan: number,
	Phase: string, -- None | Queue | Order
	Blank: boolean,
}

export type RawSlot = {
	Exists: boolean,
	State: string, -- Empty | Working | Ready (Stations set)
	StartedAt: number,
	Duration: number,
	Flip: number?, -- grill: flip score + 1 once flipped (Stations set), 0 / nil = not flipped
}

export type Snapshot = {
	Customers: { RawCustomer },
	Slots: { RawSlot },
	Rail: number,
	-- sausages left in the stock, -1 = unknown
	Stock: number,
}

export type World = {
	Customers: { RawCustomer },
	Slots: { RawSlot },
	Flipped: { [number]: number },
	Rail: number,
	Stock: number,
	NextId: number,
	NextSpawn: number,
}

const SLOTS = 4
const DURATION = 10 -- s on the grill (Upgrades.grill GrillTime 12 / 10 / 8)
const RAIL_ROOM = 6
const QUEUE_PHASE = 90 -- longer than the real 45 s so the preview does not empty itself
const ORDER_PHASE = 150
const REFILL = 7 -- s between new customers while the line is short
const LINE_MIN = 4

const FeedMock = {}

local function customer(id: number, state: string, slot: number, order: { string }, now: number, phase: string, span: number, left: number): RawCustomer
	return {
		Id = id,
		State = state,
		Slot = slot,
		Order = order,
		PatienceEndsAt = if phase == "None" then 0 else now + left,
		PatienceSpan = if phase == "None" then 0 else span,
		Phase = phase,
		Blank = false,
	}
end

function FeedMock.new(now: number): World
	const slots: { RawSlot } = {}
	for index = 1, SLOTS do
		table.insert(slots, { Exists = true, State = "Empty", StartedAt = 0, Duration = 0 })
	end
	-- one sausage already on the way, one ready: every cell state shows from the first second
	slots[1] = { Exists = true, State = "Working", StartedAt = now - 3.2, Duration = DURATION }
	slots[2] = { Exists = true, State = "Ready", StartedAt = now - DURATION - 1, Duration = DURATION }
	return {
		Customers = {
			customer(12, "Waiting", 0, { "ketchup", "mustard", "cheese" }, now, "Order", ORDER_PHASE, 120),
			customer(13, "Ordering", 1, { "mustard" }, now, "Queue", QUEUE_PHASE, 70),
			customer(14, "Queued", 2, { "bacon", "potato_sticks" }, now, "None", 0, 0),
			customer(15, "Arriving", 3, {}, now, "None", 0, 0),
		},
		Slots = slots,
		Flipped = {},
		Rail = 1,
		Stock = 9,
		NextId = 16,
		NextSpawn = now + REFILL,
	}
end

local function copyOrder(order: { string }): { string }
	return table.clone(order)
end

-- The raw state at `now`. Also moves the world on: cooking ends, the line gets a new face when it is short, patience runs out.
function FeedMock.Snapshot(world: World, now: number): Snapshot
	for _, slot in world.Slots do
		if slot.State == "Working" and now >= slot.StartedAt + slot.Duration then
			slot.State = "Ready"
		end
	end
	for index = #world.Customers, 1, -1 do
		const entry = world.Customers[index]
		if entry.Phase ~= "None" and now >= entry.PatienceEndsAt then
			table.remove(world.Customers, index)
		end
	end
	if #world.Customers < LINE_MIN and now >= world.NextSpawn then
		const pool = { { "ketchup" }, { "mustard", "cheese" }, {}, { "cream_cheese", "bacon" }, { "ketchup", "mustard" } }
		const order = copyOrder(pool[(world.NextId % #pool) + 1])
		local slot = 1
		for _, other in world.Customers do
			if other.State ~= "Waiting" then
				slot = math.max(slot, other.Slot + 1)
			end
		end
		table.insert(world.Customers, customer(world.NextId, if slot == 1 then "Ordering" else "Queued", slot, order, now, if slot == 1 then "Queue" else "None", QUEUE_PHASE, QUEUE_PHASE))
		world.NextId += 1
		world.NextSpawn = now + REFILL
	end
	const out: { RawCustomer } = {}
	for _, entry in world.Customers do
		table.insert(out, table.clone(entry))
	end
	const slots: { RawSlot } = {}
	for _, slot in world.Slots do
		table.insert(slots, table.clone(slot))
	end
	return { Customers = out, Slots = slots, Rail = world.Rail, Stock = world.Stock }
end

local function find(world: World, id: number): RawCustomer?
	for _, entry in world.Customers do
		if entry.Id == id then
			return entry
		end
	end
	return nil
end

-- The person at the counter is the one on Q1 (Slot 1); the others move up.
local function advance(world: World, now: number)
	for _, entry in world.Customers do
		if entry.State ~= "Waiting" and entry.Slot > 1 then
			entry.Slot -= 1
			if entry.Slot == 1 and entry.State ~= "Arriving" then
				entry.State = "Ordering"
				entry.Phase = "Queue"
				entry.PatienceSpan = QUEUE_PHASE
				entry.PatienceEndsAt = now + QUEUE_PHASE
			end
		end
	end
end

export type Outcome = { Ok: boolean, Reason: string, Grade: string, Value: number }

local function outcome(ok: boolean, reason: string, grade: string?, value: number?): Outcome
	return { Ok = ok, Reason = reason, Grade = grade or "None", Value = value or 0 }
end

-- Act of the grill / order packets. `plate` = the topping keys of the plate in hand (Serve).
function FeedMock.Grill(world: World, act: string, slot: number, now: number): Outcome
	if act == "Place" then
		if world.Stock <= 0 then
			return outcome(false, "NoStock")
		end
		for index, entry in world.Slots do
			if entry.State == "Empty" then
				world.Stock -= 1
				world.Slots[index] = { Exists = true, State = "Working", StartedAt = now, Duration = DURATION }
				return outcome(true, "None", nil, index)
			end
		end
		return outcome(false, "Invalid")
	end
	const entry = world.Slots[slot]
	if entry == nil or entry.State == "Empty" then
		return outcome(false, "Invalid")
	end
	if act == "Flip" then
		if world.Flipped[slot] ~= nil then
			return outcome(false, "Invalid")
		end
		const score = Grade.FlipScore(prep, prep.Tolerances.ByKey.grill_flip, entry.StartedAt, now, entry.Duration)
		world.Flipped[slot] = score
		return outcome(true, "None", Grade.Band(prep, score), slot)
	end
	if entry.State ~= "Ready" or world.Rail >= RAIL_ROOM then
		return outcome(false, "Invalid")
	end
	const score = world.Flipped[slot] or prep.Grades.Unflipped
	world.Flipped[slot] = nil
	world.Rail += 1
	world.Slots[slot] = { Exists = true, State = "Empty", StartedAt = 0, Duration = 0 }
	return outcome(true, "None", Grade.Band(prep, score), slot)
end

function FeedMock.Order(world: World, act: string, npc: number, now: number): Outcome
	const entry = find(world, npc)
	if entry == nil then
		return outcome(false, "NoTicket")
	end
	if act == "Take" then
		if entry.State ~= "Ordering" or entry.Slot ~= 1 then
			return outcome(false, "NoTicket")
		end
		entry.State = "Waiting"
		entry.Slot = 0 -- it sits at a table
		entry.Phase = "Order"
		entry.PatienceSpan = ORDER_PHASE
		entry.PatienceEndsAt = now + ORDER_PHASE
		advance(world, now)
		return outcome(true, "None")
	end
	return outcome(false, "NoTicket")
end

-- A Serve: the verdict of DEC-072 reduced to what the preview needs (exact = Complete, a subset = Incomplete, else Wrong).
-- Returns the outcome and the Sale of the packet that would follow (nil when nothing was served).
function FeedMock.Serve(world: World, npc: number, plate: { string }, band: string): (Outcome, { Npc: number, Result: string, Amount: number }?)
	const entry = find(world, npc)
	if entry == nil or entry.State ~= "Waiting" then
		return outcome(false, "NoTicket"), nil
	end
	local missing, extra = 0, 0
	for _, key in entry.Order do
		if table.find(plate, key) == nil then
			missing += 1
		end
	end
	for _, key in plate do
		if table.find(entry.Order, key) == nil then
			extra += 1
		end
	end
	local result = "Wrong"
	if missing == 0 and extra == 0 then
		result = if band == "Perfect" then "Perfect" else "Complete"
	elseif extra == 0 then
		result = "Incomplete"
	end
	if result ~= "Wrong" then
		for index, other in world.Customers do
			if other.Id == npc then
				table.remove(world.Customers, index)
				break
			end
		end
	end
	const amount = if result == "Perfect" then 7 elseif result == "Complete" then 5 elseif result == "Incomplete" then 2 else 0
	return outcome(true, "None"), { Npc = npc, Result = result, Amount = amount }
end

return FeedMock
