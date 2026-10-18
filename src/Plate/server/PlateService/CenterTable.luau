--!strict
-- Plate registry of the restaurant central table, pure (tech/prep-conveyor.md §6, §7; DEC-304; DT-E7, DT-E10; TASK-516).
-- No Roblox API besides the Player type: PlateService owns the Tools, the prompts and the wire; this module only keeps
-- every plate of the shift and moves it between its three forms with the invariant "a plate is in exactly one form":
--   Table = on a central table slot (Slot set, Holder nil)
--   Hand  = a Tool in the inventory of Holder (Slot nil)
--   Belt  = on the conveyor of Holder (PrepService has the position; Slot nil)
-- A slot holds at most one plate. Every move is synchronous and all-or-nothing: a refused move changes nothing, so
-- "take / put never duplicates nor loses a plate" is CenterTable.alive before = after. Tested by CenterTable.selfTest()
-- (through Slots.selfTest, /dev plate test).
local CenterTable = {}

export type Form = "Table" | "Hand" | "Belt"

export type Plate = {
	Id: number, -- PlateId (Tool attribute)
	Ticket: number, -- NpcId of the order (leader of a pair), 0 = orphan / no ticket
	Line: number, -- 1 = leader's hot dog, 2 = partner's (FEAT-038), 0 = no ticket
	Since: number, -- server time the ticket was born, 0 = no ticket
	Bun: boolean,
	Dog: boolean,
	Toppings: { string }, -- assembly order
	Grade: string?, -- Content.Prep grade band of an assembled plate, nil = not assembled
	FlipBonus: boolean, -- flip bonus stamped on the sausage (paid once at the sale, TASK-517)
	Altered: boolean, -- ANM-002 / altered item inside
	Sauce: string, -- Sauce.Encode of the drawn line, "" = none
	Cut: number?, -- 0..100, written by the Cut commit (server only)
	Place: number?, -- 0..100, written by the Dog commit (server only)
	StartedAt: number?, -- os.clock() of the Cut commit (plausibility clock, server only)
	Orphan: boolean, -- the customer of the ticket left while the plate had something on it (FEAT-044 grey "?")
	Form: Form,
	Slot: number?, -- Table only
	Holder: Player?, -- Hand / Belt only
}

export type CenterTable = {
	Size: number, -- slots 1..Size (Content.Restaurant.CenterTable.Slots)
	Open: { [number]: boolean }, -- slots bound in the map (a plate only lands on an open slot)
	Plates: { [number]: Plate }, -- by Id
	BySlot: { [number]: number }, -- slot -> plate Id (Table form)
	NextId: number,
}

function CenterTable.new(size: number, open: { number }?): CenterTable
	const t: CenterTable = { Size = math.max(0, math.floor(size)), Open = {}, Plates = {}, BySlot = {}, NextId = 0 }
	if open == nil then
		for slot = 1, t.Size do
			t.Open[slot] = true
		end
	else
		for _, slot in open do
			if slot >= 1 and slot <= t.Size then
				t.Open[slot] = true
			end
		end
	end
	return t
end

-- Reads ---------------------------------------------------------------------------------------------------------------

function CenterTable.isOpen(t: CenterTable, slot: number): boolean
	return t.Open[slot] == true
end

function CenterTable.openCount(t: CenterTable): number
	local count = 0
	for _ in t.Open do
		count += 1
	end
	return count
end

function CenterTable.get(t: CenterTable, id: number): Plate?
	return t.Plates[id]
end

function CenterTable.at(t: CenterTable, slot: number): Plate?
	const id = t.BySlot[slot]
	return if id ~= nil then t.Plates[id] else nil
end

-- Plates alive in any form (DT-E10: the tablet gate counts these)
function CenterTable.alive(t: CenterTable): number
	local count = 0
	for _ in t.Plates do
		count += 1
	end
	return count
end

-- Free open slot: the highest (new tickets land east, next to the tablet; MAP-01-r4 §16.5 d) or the lowest (Shelve)
function CenterTable.freeSlot(t: CenterTable, highest: boolean): number?
	if highest then
		for slot = t.Size, 1, -1 do
			if t.Open[slot] and t.BySlot[slot] == nil then
				return slot
			end
		end
	else
		for slot = 1, t.Size do
			if t.Open[slot] and t.BySlot[slot] == nil then
				return slot
			end
		end
	end
	return nil
end

-- Plates of a ticket, by line
function CenterTable.ofTicket(t: CenterTable, ticket: number): { Plate }
	const out: { Plate } = {}
	if ticket == 0 then
		return out
	end
	for _, plate in t.Plates do
		if plate.Ticket == ticket then
			table.insert(out, plate)
		end
	end
	table.sort(out, function(a: Plate, b: Plate): boolean
		return a.Line < b.Line
	end)
	return out
end

-- Plates in Hand / Belt form of a holder
function CenterTable.heldBy(t: CenterTable, holder: Player): { Plate }
	const out: { Plate } = {}
	for _, plate in t.Plates do
		if plate.Holder == holder then
			table.insert(out, plate)
		end
	end
	table.sort(out, function(a: Plate, b: Plate): boolean
		return a.Id < b.Id
	end)
	return out
end

function CenterTable.isAssembled(plate: Plate): boolean
	return plate.Grade ~= nil
end

-- Nothing on it (a fresh plate, or one the bin emptied)
function CenterTable.isEmpty(plate: Plate): boolean
	return not plate.Bun and not plate.Dog and #plate.Toppings == 0 and plate.Grade == nil
end

-- Same topping set, order ignored
function CenterTable.sameToppings(a: { string }, b: { string }): boolean
	if #a ~= #b then
		return false
	end
	for _, key in a do
		if table.find(b, key) == nil then
			return false
		end
	end
	return true
end

-- Frozen copy for callers outside PlateService (Of / WorkablePlate / Borrow)
function CenterTable.copy(plate: Plate): Plate
	const out = table.clone(plate)
	out.Toppings = table.freeze(table.clone(plate.Toppings))
	return table.freeze(out)
end

-- Writes --------------------------------------------------------------------------------------------------------------

local function detach(t: CenterTable, plate: Plate)
	if plate.Slot ~= nil and t.BySlot[plate.Slot] == plate.Id then
		t.BySlot[plate.Slot] = nil
	end
	plate.Slot = nil
	plate.Holder = nil
end

local function land(t: CenterTable, plate: Plate, slot: number)
	detach(t, plate)
	plate.Form = "Table"
	plate.Slot = slot
	t.BySlot[slot] = plate.Id
end

-- Zeroes the contents, keeps the ticket (bin on the belt, prep-conveyor.md §6.6)
function CenterTable.empty(plate: Plate)
	plate.Bun = false
	plate.Dog = false
	plate.Toppings = {}
	plate.Grade = nil
	plate.FlipBonus = false
	plate.Altered = false
	plate.Sauce = ""
	plate.Cut = nil
	plate.Place = nil
	plate.StartedAt = nil
end

-- A new empty plate with the ticket on the highest free open slot. nil = the table is full (nothing changes).
function CenterTable.spawn(t: CenterTable, ticket: number, line: number, since: number): Plate?
	const slot = CenterTable.freeSlot(t, true)
	if slot == nil then
		return nil
	end
	t.NextId += 1
	const plate: Plate = {
		Id = t.NextId,
		Ticket = ticket,
		Line = line,
		Since = since,
		Bun = false,
		Dog = false,
		Toppings = {},
		Grade = nil,
		FlipBonus = false,
		Altered = false,
		Sauce = "",
		Cut = nil,
		Place = nil,
		StartedAt = nil,
		Orphan = false,
		Form = "Table",
		Slot = nil,
		Holder = nil,
	}
	t.Plates[plate.Id] = plate
	land(t, plate, slot)
	return plate
end

-- An orphan already assembled with exactly the ordered toppings takes the ticket (Rules.OrphanReuse; prep-conveyor.md
-- §6.2, P14). The oldest one; a plate on the belt is never adopted. nil = none fits.
function CenterTable.adopt(t: CenterTable, ticket: number, line: number, order: { string }, since: number): Plate?
	local best: Plate? = nil
	for _, plate in t.Plates do
		if
			plate.Orphan
			and plate.Ticket == 0
			and plate.Form ~= "Belt"
			and CenterTable.isAssembled(plate)
			and CenterTable.sameToppings(plate.Toppings, order)
			and (best == nil or plate.Id < best.Id)
		then
			best = plate
		end
	end
	if best ~= nil then
		best.Ticket = ticket
		best.Line = line
		best.Since = since
		best.Orphan = false
	end
	return best
end

-- Table -> Hand. nil = no plate on the slot.
function CenterTable.take(t: CenterTable, slot: number, holder: Player?): Plate?
	const plate = CenterTable.at(t, slot)
	if plate == nil then
		return nil
	end
	detach(t, plate)
	plate.Form = "Hand"
	plate.Holder = holder
	return plate
end

-- Hand -> Table on that slot (open and free). false = refused, nothing changes.
function CenterTable.put(t: CenterTable, id: number, slot: number): boolean
	const plate = t.Plates[id]
	if plate == nil or plate.Form ~= "Hand" or not t.Open[slot] or t.BySlot[slot] ~= nil then
		return false
	end
	land(t, plate, slot)
	return true
end

-- Hand -> Belt, same holder, not assembled (prep-conveyor.md §2.2: a finished hot dog does not go on the belt)
function CenterTable.borrow(t: CenterTable, id: number, holder: Player?): boolean
	const plate = t.Plates[id]
	if plate == nil or plate.Form ~= "Hand" or plate.Holder ~= holder or CenterTable.isAssembled(plate) then
		return false
	end
	plate.Form = "Belt"
	return true
end

-- Belt -> Hand of the same holder
function CenterTable.giveback(t: CenterTable, id: number, holder: Player?): boolean
	const plate = t.Plates[id]
	if plate == nil or plate.Form ~= "Belt" or plate.Holder ~= holder then
		return false
	end
	plate.Form = "Hand"
	return true
end

-- Belt / Hand -> Table on the lowest free open slot. Returns the slot; nil = refused (already on the table, unknown,
-- table full: DT-E10 keeps a free slot for every live plate, so full only happens with an unbound map)
function CenterTable.shelve(t: CenterTable, id: number): number?
	const plate = t.Plates[id]
	if plate == nil or plate.Form == "Table" then
		return nil
	end
	const slot = CenterTable.freeSlot(t, false)
	if slot == nil then
		return nil
	end
	land(t, plate, slot)
	return slot
end

-- The plate ends (served, thrown out, empty orphan). Returns it (nil = unknown).
function CenterTable.remove(t: CenterTable, id: number): Plate?
	const plate = t.Plates[id]
	if plate == nil then
		return nil
	end
	detach(t, plate)
	t.Plates[id] = nil
	return plate
end

-- The customer of `ticket` left (prep-conveyor.md §7.6, P21): every plate of it loses the ticket; an empty one off the
-- belt is removed, the rest become orphans (an empty one on the belt stays: PrepService ends it). Returns the plates
-- that stay (orphans) and the ones removed.
function CenterTable.release(t: CenterTable, ticket: number): ({ Plate }, { Plate })
	const kept: { Plate } = {}
	const gone: { Plate } = {}
	for _, plate in CenterTable.ofTicket(t, ticket) do
		plate.Ticket = 0
		plate.Line = 0
		plate.Since = 0
		if CenterTable.isEmpty(plate) and plate.Form ~= "Belt" then
			CenterTable.remove(t, plate.Id)
			table.insert(gone, plate)
		else
			plate.Orphan = not CenterTable.isEmpty(plate)
			table.insert(kept, plate)
		end
	end
	return kept, gone
end

-- Every plate gone (new shift, dev)
function CenterTable.clear(t: CenterTable): { Plate }
	const out: { Plate } = {}
	for _, plate in t.Plates do
		table.insert(out, plate)
	end
	table.clear(t.Plates)
	table.clear(t.BySlot)
	for _, plate in out do
		plate.Slot = nil
		plate.Holder = nil
	end
	return out
end

-- Invariant: every Table plate is on its slot and every slot points at a Table plate; Hand / Belt plates have no slot.
function CenterTable.isConsistent(t: CenterTable): boolean
	for slot, id in t.BySlot do
		const plate = t.Plates[id]
		if plate == nil or plate.Form ~= "Table" or plate.Slot ~= slot then
			return false
		end
	end
	for id, plate in t.Plates do
		if plate.Id ~= id then
			return false
		end
		if plate.Form == "Table" then
			if plate.Slot == nil or t.BySlot[plate.Slot] ~= id then
				return false
			end
		elseif plate.Slot ~= nil then
			return false
		end
	end
	return true
end

-- Table tests. Returns passed, total and the failure names.
function CenterTable.selfTest(): (number, number, { string })
	const failures: { string } = {}
	local total = 0
	local function check(name: string, ok: boolean)
		total += 1
		if not ok then
			table.insert(failures, `center {name}`)
		end
	end

	-- birth: highest free slot, one plate per call, ticket kept
	do
		const t = CenterTable.new(8)
		const a = CenterTable.spawn(t, 3, 1, 10)
		const b = CenterTable.spawn(t, 4, 1, 11)
		check("spawn highest", a ~= nil and a.Slot == 8 and a.Ticket == 3 and a.Form == "Table")
		check("spawn next", b ~= nil and b.Slot == 7)
		check("spawn empty", a ~= nil and CenterTable.isEmpty(a))
		check("alive 2", CenterTable.alive(t) == 2 and CenterTable.isConsistent(t))
		check("of ticket", #CenterTable.ofTicket(t, 3) == 1 and #CenterTable.ofTicket(t, 0) == 0)
	end
	-- full table: nothing changes
	do
		const t = CenterTable.new(2)
		CenterTable.spawn(t, 1, 1, 0)
		CenterTable.spawn(t, 2, 1, 0)
		check("full spawn nil", CenterTable.spawn(t, 3, 1, 0) == nil and CenterTable.alive(t) == 2)
	end
	-- only open slots
	do
		const t = CenterTable.new(8, { 2, 5 })
		const a = CenterTable.spawn(t, 1, 1, 0)
		check("open highest", a ~= nil and a.Slot == 5)
		check("open lowest", CenterTable.freeSlot(t, false) == 2 and CenterTable.openCount(t) == 2)
	end
	-- take / put: count stays, slot frees and fills, a second take of the same slot fails
	do
		const t = CenterTable.new(8)
		const a = CenterTable.spawn(t, 3, 1, 0) :: Plate
		const before = CenterTable.alive(t)
		const taken = CenterTable.take(t, 8, nil)
		check("take", taken ~= nil and taken.Id == a.Id and a.Form == "Hand" and a.Slot == nil)
		check("take frees", CenterTable.at(t, 8) == nil)
		check("second take nil", CenterTable.take(t, 8, nil) == nil)
		check("put on free", CenterTable.put(t, a.Id, 2) and a.Slot == 2 and CenterTable.at(t, 2) == a)
		check("count same", CenterTable.alive(t) == before and CenterTable.isConsistent(t))
		check("put twice refused", not CenterTable.put(t, a.Id, 3))
		const b = CenterTable.spawn(t, 4, 1, 0) :: Plate
		CenterTable.take(t, b.Slot :: number, nil)
		check("put on taken refused", not CenterTable.put(t, b.Id, 2) and b.Form == "Hand")
		check("put on closed refused", not CenterTable.put(t, b.Id, 9) and not CenterTable.put(t, b.Id, 0))
		check("consistent", CenterTable.isConsistent(t) and CenterTable.alive(t) == 2)
	end
	-- belt: borrow / giveback / shelve; an assembled plate does not go on the belt
	do
		const t = CenterTable.new(4)
		const a = CenterTable.spawn(t, 3, 1, 0) :: Plate
		CenterTable.take(t, a.Slot :: number, nil)
		check("borrow", CenterTable.borrow(t, a.Id, nil) and a.Form == "Belt")
		check("borrow twice refused", not CenterTable.borrow(t, a.Id, nil))
		check("giveback", CenterTable.giveback(t, a.Id, nil) and a.Form == "Hand")
		CenterTable.borrow(t, a.Id, nil)
		const slot = CenterTable.shelve(t, a.Id)
		check("shelve lowest", slot == 1 and a.Form == "Table" and CenterTable.at(t, 1) == a)
		check("shelve on table refused", CenterTable.shelve(t, a.Id) == nil)
		CenterTable.take(t, 1, nil)
		a.Grade = "Good"
		check("assembled not borrowed", not CenterTable.borrow(t, a.Id, nil))
		check("belt consistent", CenterTable.isConsistent(t) and CenterTable.alive(t) == 1)
	end
	-- release: empty plate off the belt goes, a plate with something stays as orphan; adopt an assembled orphan
	do
		const t = CenterTable.new(8)
		const empty = CenterTable.spawn(t, 5, 1, 0) :: Plate
		const full = CenterTable.spawn(t, 5, 2, 0) :: Plate
		full.Bun = true
		full.Dog = true
		full.Toppings = { "ketchup", "mustard" }
		full.Grade = "Perfect"
		const kept, gone = CenterTable.release(t, 5)
		check("release gone", #gone == 1 and gone[1] == empty and CenterTable.get(t, empty.Id) == nil)
		check("release kept", #kept == 1 and full.Orphan and full.Ticket == 0 and full.Line == 0)
		check("release slot freed", CenterTable.at(t, 8) == nil and CenterTable.isConsistent(t))
		check("adopt other order nil", CenterTable.adopt(t, 6, 1, { "ketchup" }, 1) == nil)
		const adopted = CenterTable.adopt(t, 6, 1, { "mustard", "ketchup" }, 1)
		check("adopt same set", adopted == full and full.Ticket == 6 and not full.Orphan)
		check("adopt once", CenterTable.adopt(t, 7, 1, { "mustard", "ketchup" }, 1) == nil)
		const belt = CenterTable.spawn(t, 9, 1, 0) :: Plate
		CenterTable.take(t, belt.Slot :: number, nil)
		CenterTable.borrow(t, belt.Id, nil)
		const keptBelt, goneBelt = CenterTable.release(t, 9)
		check("empty belt orphan stays", #goneBelt == 0 and #keptBelt == 1 and not belt.Orphan and belt.Ticket == 0)
	end
	-- empty keeps the ticket; remove and clear
	do
		const t = CenterTable.new(4)
		const a = CenterTable.spawn(t, 2, 1, 0) :: Plate
		a.Bun = true
		a.Grade = "Messy"
		a.Sauce = "x"
		CenterTable.empty(a)
		check("empty keeps ticket", CenterTable.isEmpty(a) and a.Ticket == 2 and a.Sauce == "")
		check("remove", CenterTable.remove(t, a.Id) == a and CenterTable.alive(t) == 0 and CenterTable.at(t, 4) == nil)
		CenterTable.spawn(t, 1, 1, 0)
		CenterTable.spawn(t, 2, 1, 0)
		check("clear", #CenterTable.clear(t) == 2 and CenterTable.alive(t) == 0 and CenterTable.freeSlot(t, true) == 4)
	end
	-- ids are never reused
	do
		const t = CenterTable.new(2)
		const a = CenterTable.spawn(t, 1, 1, 0) :: Plate
		CenterTable.remove(t, a.Id)
		const b = CenterTable.spawn(t, 1, 1, 0) :: Plate
		check("ids grow", b.Id > a.Id)
	end
	return total - #failures, total, failures
end

return CenterTable
