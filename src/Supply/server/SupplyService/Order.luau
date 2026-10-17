--!strict
-- Pure rules of a phone order (FEAT-050; design/restaurant-flow.md; TASK-388). No Modux, no Lync, no Instances: the
-- SupplyService passes the numbers in. Boxes = { [Packages key] = count }.
--   validate  -> every key a package, every count a whole number >= 1, total 1..max, nothing blocked
--   cost      -> sum of Package.Price x count + fee (the box content and price are the Mart package, DEC-276)
--   quick     -> the order of a plain tap on the phone (no menu packet yet, Provisional): `max` boxes spread over the
--                open packages, one at a time to the package with the fewest boxes (stock + already picked), ties by
--                the Packages list order (sausages and buns first)
--   resolve   -> /dev words ("dogs", "buns", "pack_bacon", "Potato Sticks") to a Packages key
export type Boxes = { [string]: number }

export type Price = { [string]: number } -- Packages key -> price per box

export type Reason = "empty" | "too_many" | "unknown" | "blocked" | "count"

const Order = {}

-- Total boxes of an order
function Order.count(boxes: Boxes): number
	local total = 0
	for _, count in boxes do
		total += count
	end
	return total
end

-- Checks an order. allowed[key] = true for the packages on sale now (unlocked, known)
function Order.validate(boxes: Boxes, max: number, known: { [string]: any }, allowed: { [string]: boolean }): (boolean, Reason?)
	local total = 0
	for key, count in boxes do
		if known[key] == nil then
			return false, "unknown"
		end
		if type(count) ~= "number" or count ~= math.floor(count) or count < 1 then
			return false, "count"
		end
		if not allowed[key] then
			return false, "blocked"
		end
		total += count
	end
	if total < 1 then
		return false, "empty"
	end
	if total > max then
		return false, "too_many"
	end
	return true, nil
end

function Order.cost(boxes: Boxes, prices: Price, fee: number): number
	local total = fee
	for key, count in boxes do
		total += (prices[key] or 0) * count
	end
	return total
end

-- Plain-tap order: `max` boxes over `open` (Packages keys in list order), filling the lowest stock first
function Order.quick(open: { string }, stock: { [string]: number }, max: number): Boxes
	const out: Boxes = {}
	if #open == 0 then
		return out
	end
	for _ = 1, max do
		local best: string? = nil
		local bestCount = math.huge
		for _, key in open do
			const count = (stock[key] or 0) + (out[key] or 0)
			if count < bestCount then
				best = key
				bestCount = count
			end
		end
		if best == nil then
			break
		end
		out[best] = (out[best] or 0) + 1
	end
	return out
end

-- Short names for /dev (the board example says "dogs" and "buns")
const ALIASES: { [string]: string } = { dog = "sausage", dogs = "sausage", sausages = "sausage", buns = "bun" }

-- Word -> Packages key. rows = Content.Packages.List (Key, Name, Ingredient)
export type Row = { read Key: string, read Name: string, read Ingredient: string }

function Order.resolve(word: string, rows: { read [number]: Row }): string?
	const text = string.lower(word)
	const ingredient = ALIASES[text] or text
	for _, row in rows do
		if
			row.Key == text
			or row.Key == `pack_{text}`
			or row.Ingredient == ingredient
			or string.lower(row.Name) == text
			or string.gsub(string.lower(row.Name), " ", "_") == text
		then
			return row.Key
		end
	end
	return nil
end

-- Table tests (/dev supply test). Returns passed, total, failed names
function Order.selfTest(): (number, number, { string })
	const failures: { string } = {}
	local total = 0
	local function check(name: string, ok: boolean)
		total += 1
		if not ok then
			table.insert(failures, name)
		end
	end
	const known = { a = true, b = true, c = true }
	const allowed = { a = true, b = true }
	check("valid", (Order.validate({ a = 2, b = 1 }, 4, known, allowed)))
	check("empty", select(2, Order.validate({}, 4, known, allowed)) == "empty")
	check("too_many", select(2, Order.validate({ a = 5 }, 4, known, allowed)) == "too_many")
	check("unknown", select(2, Order.validate({ z = 1 }, 4, known, allowed)) == "unknown")
	check("blocked", select(2, Order.validate({ c = 1 }, 4, known, allowed)) == "blocked")
	check("count", select(2, Order.validate({ a = 1.5 }, 4, known, allowed)) == "count")
	check("cost", Order.cost({ a = 2, b = 1 }, { a = 6, b = 4 }, 2) == 18)
	const quick = Order.quick({ "a", "b" }, { a = 1 }, 4)
	check("quick fills low first", quick.a == 1 and quick.b == 3)
	check("quick total", Order.count(quick) == 4)
	check("quick none open", next(Order.quick({}, {}, 4)) == nil)
	const rows = {
		{ Key = "pack_sausages", Name = "Sausages", Ingredient = "sausage" },
		{ Key = "pack_buns", Name = "Buns", Ingredient = "bun" },
		{ Key = "pack_potato_sticks", Name = "Potato Sticks", Ingredient = "potato_sticks" },
	}
	check("resolve dogs", Order.resolve("dogs", rows) == "pack_sausages")
	check("resolve buns", Order.resolve("BUNS", rows) == "pack_buns")
	check("resolve key", Order.resolve("pack_buns", rows) == "pack_buns")
	check("resolve name", Order.resolve("potato_sticks", rows) == "pack_potato_sticks")
	check("resolve none", Order.resolve("pizza", rows) == nil)
	return total - #failures, total, failures
end

return table.freeze(Order)
