--!strict
-- CustomerService/Queue: counter queue, pure (architecture.md §18.13; FEAT-009; DEC-046; MAP-01 §9.1; TASK-032).
-- Holds the order in which customers joined the queue and answers which slot each one stands on. Slot k is the
-- MapPoint/NpcNode "Qk" (Q1 = front, the ordering spot; Q5 = west end, where the arrival routes end, §18.6).
-- Active slots come from the Counter level (UPG-003 QueueSize: 3 / 4 / 5). No Service, no network, no Instance.

export type Queue = {
	Order: { number }, -- customer ids, front first; index = slot
}

const MAX_SLOTS = 5 -- Q1..Q5 exist on MAP-01 (Counter 3)
const ENTRY_SLOT = 5 -- arrivals link only to Q5 (architecture.md §18.6)

const Queue = {}

Queue.MaxSlots = MAX_SLOTS

function Queue.new(): Queue
	return { Order = {} }
end

-- Active slots for an upgrade QueueSize value (always 1..MAX_SLOTS).
function Queue.size(queueSize: number): number
	if queueSize ~= queueSize then
		return 1
	end
	return math.clamp(math.floor(queueSize), 1, MAX_SLOTS)
end

-- PointId / NodeId of a slot.
function Queue.point(slot: number): string
	return `Q{slot}`
end

-- Node where every arriving customer enters the queue.
function Queue.entry(): string
	return Queue.point(ENTRY_SLOT)
end

-- Slot number of a node id ("Q3" -> 3), or nil when it is not a queue node.
function Queue.slotOfNode(node: string): number?
	const digits = string.match(node, "^Q(%d+)$")
	return if digits then tonumber(digits) else nil
end

-- Appends `id` at the back. Returns its slot.
function Queue.join(queue: Queue, id: number): number
	const index = table.find(queue.Order, id)
	if index ~= nil then
		return index
	end
	table.insert(queue.Order, id)
	return #queue.Order
end

-- Removes `id`; everyone behind it moves one slot up. false = it was not in the queue.
function Queue.leave(queue: Queue, id: number): boolean
	const index = table.find(queue.Order, id)
	if index == nil then
		return false
	end
	table.remove(queue.Order, index)
	return true
end

-- Slot of `id` (1 = front), or nil.
function Queue.slotOf(queue: Queue, id: number): number?
	return table.find(queue.Order, id)
end

-- Customer on the front slot (Q1), or nil.
function Queue.front(queue: Queue): number?
	return queue.Order[1]
end

function Queue.count(queue: Queue): number
	return #queue.Order
end

-- True when `occupants` (customers in the queue plus those walking to it) already fill `size` slots (FEAT-009:
-- full counter = the spawn is skipped).
function Queue.isFull(occupants: number, size: number): boolean
	return occupants >= size
end

function Queue.clear(queue: Queue)
	table.clear(queue.Order)
end

return Queue
