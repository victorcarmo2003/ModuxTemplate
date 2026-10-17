--!strict
-- /dev words of the supply (FEAT-050). Pure: no Modux, no Lync, no Instances.
--   resolve  -> "dogs", "buns", "pack_bacon", "Potato Sticks" to a Content.Packages key
export type Row = { read Key: string, read Name: string, read Ingredient: string }

const Words = {}

-- Short names for /dev (the board example says "dogs" and "buns")
const ALIASES: { [string]: string } = { dog = "sausage", dogs = "sausage", sausages = "sausage", buns = "bun" }

-- Word -> Packages key. rows = Content.Packages.List (Key, Name, Ingredient)
function Words.resolve(word: string, rows: { read [number]: Row }): string?
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
function Words.selfTest(): (number, number, { string })
	const failures: { string } = {}
	local total = 0
	local function check(name: string, ok: boolean)
		total += 1
		if not ok then
			table.insert(failures, name)
		end
	end
	const rows = {
		{ Key = "pack_sausages", Name = "Sausages", Ingredient = "sausage" },
		{ Key = "pack_buns", Name = "Buns", Ingredient = "bun" },
		{ Key = "pack_potato_sticks", Name = "Potato Sticks", Ingredient = "potato_sticks" },
	}
	check("resolve dogs", Words.resolve("dogs", rows) == "pack_sausages")
	check("resolve buns", Words.resolve("BUNS", rows) == "pack_buns")
	check("resolve key", Words.resolve("pack_buns", rows) == "pack_buns")
	check("resolve name", Words.resolve("potato_sticks", rows) == "pack_potato_sticks")
	check("resolve none", Words.resolve("pizza", rows) == nil)
	return total - #failures, total, failures
end

return table.freeze(Words)
