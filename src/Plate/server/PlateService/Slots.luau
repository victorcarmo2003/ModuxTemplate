--!strict
-- Plate slots of the assembly table, pure (tech/restaurant-flow.md rev. 2 §2.2; design FEAT-044; TASK-379). No Roblox API:
-- PlateService owns the instances, the Tools and the wire; this module only decides which slot a ticket lands on and
-- what a put may do. Tested by Slots.selfTest() (/dev plate test).
--
-- A slot holds a ticket (Npc of the customer, Line of a pair) and/or contents (bun, sausage, toppings of a plate put
-- back). Npc = 0 means "no ticket": the slot is free for the next order and keeps whatever is on it (pre-prep, an
-- orphan whose customer left). Ticket landing (pick): with preppedFirst, a free plate that already has bun + sausage
-- and no topping outside the order (an identical one first), else the lowest free slot with nothing outside the order,
-- else the lowest free slot.
local Slots = {}

export type Slot = {
	Index: number,
	Npc: number, -- NpcId of the ticket, 0 = none
	Line: number, -- 1 = leader's hot dog, 2 = partner's (FEAT-038), 0 = no ticket
	Bun: boolean,
	Sausage: boolean,
	Toppings: { string }, -- a plate put back after the condiments (assembly order)
	Since: number, -- server time the ticket landed, 0 = no ticket
	Orphan: boolean, -- its customer left while the plate had something on it (FEAT-044 grey "?")
	Altered: boolean, -- ANM-002 / altered hot dog put back (wave R4 reads it)
}

-- What a put adds: "bun" (bun_sliced), "sausage" (sausage_grilled) or "plate" (a whole hot_dog put back)
export type PutKind = "bun" | "sausage" | "plate"

-- Notice key of a refused put / take (Content.Notices)
export type Refusal = "plate_full" | "plate_not_ready"

function Slots.new(index: number): Slot
	return {
		Index = index,
		Npc = 0,
		Line = 0,
		Bun = false,
		Sausage = false,
		Toppings = {},
		Since = 0,
		Orphan = false,
		Altered = false,
	}
end

function Slots.isFree(slot: Slot): boolean
	return slot.Npc == 0
end

-- Bun and sausage on it: the plate can be taken (Q 3 of the tech §9: no half plate leaves the slot)
function Slots.isReady(slot: Slot): boolean
	return slot.Bun and slot.Sausage
end

function Slots.isEmpty(slot: Slot): boolean
	return not slot.Bun and not slot.Sausage and #slot.Toppings == 0
end

-- Something on it or a ticket on it
function Slots.isOccupied(slot: Slot): boolean
	return slot.Npc ~= 0 or not Slots.isEmpty(slot)
end

-- Every topping of `toppings` is in `order`
function Slots.fits(toppings: { string }, order: { string }): boolean
	for _, key in toppings do
		if table.find(order, key) == nil then
			return false
		end
	end
	return true
end

function Slots.countFree(slots: { Slot }): number
	local count = 0
	for _, slot in slots do
		if Slots.isFree(slot) then
			count += 1
		end
	end
	return count
end

-- Slot a new ticket lands on, among `slots` (the active ones, any order). nil = none free.
function Slots.pick(slots: { Slot }, order: { string }, preppedFirst: boolean): Slot?
	local prepped: Slot? = nil
	local preppedScore = -1
	local clean: Slot? = nil
	local any: Slot? = nil
	for _, slot in slots do
		if not Slots.isFree(slot) then
			continue
		end
		const fits = Slots.fits(slot.Toppings, order)
		if preppedFirst and fits and Slots.isReady(slot) then
			-- identical first (every ordered topping already on it), then the one with more of the order, then the lower index
			const score = #slot.Toppings
			if score > preppedScore or (score == preppedScore and prepped ~= nil and slot.Index < prepped.Index) then
				prepped = slot
				preppedScore = score
			end
		end
		if fits and (clean == nil or slot.Index < clean.Index) then
			clean = slot
		end
		if any == nil or slot.Index < any.Index then
			any = slot
		end
	end
	return prepped or clean or any
end

-- Puts a ticket on the slot
function Slots.assign(slot: Slot, npc: number, line: number, at: number)
	slot.Npc = npc
	slot.Line = line
	slot.Since = at
	slot.Orphan = false
end

-- The ticket goes away, the contents stay (serve the next order). Orphan when something was on it.
function Slots.release(slot: Slot)
	slot.Npc = 0
	slot.Line = 0
	slot.Since = 0
	slot.Orphan = not Slots.isEmpty(slot)
end

-- Back to an empty slot with no ticket (plate taken, shift start, dev clear)
function Slots.clear(slot: Slot)
	slot.Npc = 0
	slot.Line = 0
	slot.Bun = false
	slot.Sausage = false
	slot.Toppings = {}
	slot.Since = 0
	slot.Orphan = false
	slot.Altered = false
end

-- May `kind` go on the slot? `ticket` = Ticket of the hot dog put back (nil = none). Sausage only on a bun (FEAT-045
-- "Montagem"); a whole plate only on an empty slot whose ticket (if any) is the plate's own.
function Slots.canPut(slot: Slot, kind: PutKind, ticket: number?): (boolean, Refusal?)
	if kind == "bun" then
		if slot.Bun then
			return false, "plate_full"
		end
		return true, nil
	elseif kind == "sausage" then
		if not slot.Bun then
			return false, "plate_not_ready"
		end
		if slot.Sausage then
			return false, "plate_full"
		end
		return true, nil
	end
	if not Slots.isEmpty(slot) then
		return false, "plate_full"
	end
	if slot.Npc ~= 0 and ticket ~= nil and ticket ~= slot.Npc then
		return false, "plate_full"
	end
	return true, nil
end

-- Kind to put when the hand holds nothing that says it: what the slot needs next (bun, then sausage); a whole plate
-- is only put by holding it. nil = nothing to add.
function Slots.needs(slot: Slot): PutKind?
	if not slot.Bun then
		return "bun"
	elseif not slot.Sausage then
		return "sausage"
	end
	return nil
end

-- Table tests (pure; /dev plate test). Returns passed, total and the failure lines.
function Slots.selfTest(): (number, number, { string })
	const failures: { string } = {}
	local total = 0
	local function check(name: string, ok: boolean)
		total += 1
		if not ok then
			table.insert(failures, name)
		end
	end
	local function row(count: number): { Slot }
		const out: { Slot } = {}
		for index = 1, count do
			table.insert(out, Slots.new(index))
		end
		return out
	end

	-- lowest free index
	do
		const slots = row(4)
		Slots.assign(slots[1], 10, 1, 1)
		const picked = Slots.pick(slots, {}, true)
		check("lowest free", picked ~= nil and picked.Index == 2)
	end
	-- prepped first (bun + sausage) over a lower empty one
	do
		const slots = row(4)
		slots[3].Bun = true
		slots[3].Sausage = true
		const picked = Slots.pick(slots, { "ketchup" }, true)
		check("prepped first", picked ~= nil and picked.Index == 3)
		const plain = Slots.pick(slots, { "ketchup" }, false)
		check("prepped off = lowest", plain ~= nil and plain.Index == 1)
	end
	-- identical put-back plate beats a bare prepped one; a wrong topping is never preferred
	do
		const slots = row(4)
		for _, index in { 2, 3, 4 } do
			slots[index].Bun = true
			slots[index].Sausage = true
		end
		slots[2].Toppings = { "mustard" }
		slots[4].Toppings = { "ketchup" }
		const picked = Slots.pick(slots, { "ketchup" }, true)
		check("identical first", picked ~= nil and picked.Index == 4)
		slots[1].Toppings = { "mustard" }
		slots[3].Npc = 9
		slots[4].Npc = 9
		const fallback = Slots.pick(slots, { "cheese" }, true)
		check("wrong topping last", fallback ~= nil and fallback.Index == 1)
	end
	-- full = nil
	do
		const slots = row(2)
		Slots.assign(slots[1], 1, 1, 1)
		Slots.assign(slots[2], 2, 1, 1)
		check("full", Slots.pick(slots, {}, true) == nil and Slots.countFree(slots) == 0)
	end
	-- release keeps the contents, marks the orphan; clear empties
	do
		const slot = Slots.new(1)
		Slots.assign(slot, 7, 1, 5)
		Slots.release(slot)
		check("release empty = not orphan", slot.Npc == 0 and not slot.Orphan)
		Slots.assign(slot, 7, 2, 5)
		slot.Bun = true
		Slots.release(slot)
		check("release keeps bun", slot.Npc == 0 and slot.Line == 0 and slot.Since == 0 and slot.Bun and slot.Orphan)
		Slots.clear(slot)
		check("clear", Slots.isEmpty(slot) and not slot.Orphan and slot.Npc == 0)
	end
	-- puts
	do
		const slot = Slots.new(1)
		check("sausage needs bun", select(2, Slots.canPut(slot, "sausage")) == "plate_not_ready")
		check("bun ok", (Slots.canPut(slot, "bun")))
		slot.Bun = true
		check("second bun refused", select(2, Slots.canPut(slot, "bun")) == "plate_full")
		check("sausage ok", (Slots.canPut(slot, "sausage")))
		check("plate on bun refused", select(2, Slots.canPut(slot, "plate")) == "plate_full")
		check("needs sausage", Slots.needs(slot) == "sausage")
		slot.Sausage = true
		check("ready", Slots.isReady(slot) and Slots.needs(slot) == nil)
		const ghost = Slots.new(2)
		Slots.assign(ghost, 5, 1, 1)
		check("plate on own ticket", (Slots.canPut(ghost, "plate", 5)))
		check("plate on other ticket", not (Slots.canPut(ghost, "plate", 6)))
		check("plate with no ticket", (Slots.canPut(ghost, "plate", nil)))
	end
	return total - #failures, total, failures
end

return Slots
