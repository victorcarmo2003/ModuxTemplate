--!strict
-- Central table slots as the clients see them, pure (tech/prep-conveyor.md §7.1; DEC-303 Q-383, DEC-304; TASK-516; was
-- the PLATE-n pass of TASK-379, retired from the restaurant by DEC-302). No Roblox API: PlateService owns the instances,
-- the Tools and the wire; this module only says what one slot of the Net.Restaurant Plates set shows. The plates
-- themselves live in CenterTable.luau. Tested by Slots.selfTest() (/dev plate test), which also runs CenterTable's.
--
-- Slot state for the client (prep-conveyor.md §7.1):
--   Free      no plate (Npc 0, no Orphan)
--   Empty     a plate with its ticket and nothing on it (born at "take order")
--   Building  bun and/or dog, no grade
--   Assembled a grade (Perfect / Good / Messy): ready for the PICKUP
--   Orphan    the customer left; only kept while something is on it (prep-conveyor.md §7.6)
const CenterTable = require(script.Parent.CenterTable)

const Slots = {}

export type State = "Free" | "Empty" | "Building" | "Assembled" | "Orphan"

-- Plain record of one slot (the wire struct of Net.Restaurant Plates; PlateService swaps nil optionals for Lync.none
-- on update)
export type Record = {
	Npc: number,
	Line: number,
	Bun: boolean,
	Sausage: boolean,
	Toppings: { [string]: boolean },
	Since: number,
	Orphan: boolean?,
	Altered: boolean?,
	Grade: string?,
}

function Slots.state(plate: CenterTable.Plate?): State
	if plate == nil then
		return "Free"
	elseif plate.Orphan or plate.Ticket == 0 then
		return "Orphan"
	elseif plate.Grade ~= nil then
		return "Assembled"
	elseif plate.Bun or plate.Dog then
		return "Building"
	end
	return "Empty"
end

function Slots.toppingSet(list: { string }): { [string]: boolean }
	const out: { [string]: boolean } = {}
	for _, key in list do
		out[key] = true
	end
	return out
end

-- Topping list of a bitfield set, in `keys` order (Content.Ingredients.ToppingKeys)
function Slots.toppingList(set: { [string]: boolean }?, keys: { string }): { string }
	const out: { string } = {}
	if set == nil then
		return out
	end
	for _, key in keys do
		if set[key] then
			table.insert(out, key)
		end
	end
	return out
end

-- Grade on the wire: only a key of `gradeKeys` (Content.Prep.GradeKeys), never "None" (None = not assembled)
function Slots.wireGrade(grade: string?, gradeKeys: { string }): string?
	if grade == nil or grade == "None" or table.find(gradeKeys, grade) == nil then
		return nil
	end
	return grade
end

-- Record of a slot (nil plate = free)
function Slots.record(plate: CenterTable.Plate?, gradeKeys: { string }): Record
	if plate == nil then
		return {
			Npc = 0,
			Line = 0,
			Bun = false,
			Sausage = false,
			Toppings = {},
			Since = 0,
			Orphan = nil,
			Altered = nil,
			Grade = nil,
		}
	end
	return {
		Npc = math.clamp(plate.Ticket, 0, 65535),
		Line = math.clamp(plate.Line, 0, 2),
		Bun = plate.Bun,
		Sausage = plate.Dog,
		Toppings = Slots.toppingSet(plate.Toppings),
		Since = plate.Since,
		Orphan = if plate.Orphan then true else nil,
		Altered = if plate.Altered then true else nil,
		Grade = Slots.wireGrade(plate.Grade, gradeKeys),
	}
end

-- Table tests (pure; /dev plate test): the slot view + CenterTable.selfTest. Returns passed, total and the failures.
function Slots.selfTest(): (number, number, { string })
	const failures: { string } = {}
	local total = 0
	local function check(name: string, ok: boolean)
		total += 1
		if not ok then
			table.insert(failures, name)
		end
	end
	const grades = { "None", "Messy", "Good", "Perfect" }

	do
		const t = CenterTable.new(8)
		check("free", Slots.state(CenterTable.at(t, 8)) == "Free")
		const plate = CenterTable.spawn(t, 3, 1, 5) :: CenterTable.Plate
		check("empty", Slots.state(plate) == "Empty")
		const record = Slots.record(plate, grades)
		check("record ticket", record.Npc == 3 and record.Line == 1 and record.Since == 5 and record.Grade == nil)
		plate.Bun = true
		check("building", Slots.state(plate) == "Building")
		plate.Dog = true
		plate.Toppings = { "ketchup" }
		plate.Grade = "Perfect"
		check("assembled", Slots.state(plate) == "Assembled")
		const done = Slots.record(plate, grades)
		check("record assembled", done.Sausage and done.Toppings.ketchup == true and done.Grade == "Perfect")
		plate.Grade = "None"
		check("grade None not on the wire", Slots.record(plate, grades).Grade == nil)
		CenterTable.release(t, 3)
		check("orphan", Slots.state(plate) == "Orphan" and Slots.record(plate, grades).Orphan == true)
		const free = Slots.record(nil, grades)
		check("record free", free.Npc == 0 and free.Orphan == nil and next(free.Toppings) == nil)
	end
	check(
		"topping list order",
		table.concat(Slots.toppingList({ mustard = true, ketchup = true }, { "ketchup", "mustard" }), ",") == "ketchup,mustard"
	)

	const _, count, centerFailures = CenterTable.selfTest()
	total += count
	for _, name in centerFailures do
		table.insert(failures, name)
	end
	return total - #failures, total, failures
end

return Slots
