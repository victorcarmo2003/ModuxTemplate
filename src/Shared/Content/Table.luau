--!strict
-- Builds a frozen content table from a list of rows (content-data.md §1.2).
-- No validation here: Validate.luau checks keys, duplicates and references with table name and row.

export type Table<T> = {
	List: { T },
	Keys: { string },
	ByKey: { [string]: T },
	IndexOf: { [string]: number },
}

const Table = {}

local function freezeDeep<V>(value: V): V
	if type(value) == "table" and not table.isfrozen(value :: any) then
		for _, child in value :: any do
			freezeDeep(child)
		end
		table.freeze(value :: any)
	end
	return value
end

-- List order is the record id for Stock and Upgrades (IndexOf); the wire never sees it (Lync sorts enum names).
function Table.new<T>(list: { T }): Table<T>
	const keys: { string } = {}
	const byKey: { [string]: T } = {}
	const indexOf: { [string]: number } = {}
	for index, row in list do
		const key = (row :: any).Key :: string
		table.insert(keys, key)
		if byKey[key] == nil then
			byKey[key] = row
			indexOf[key] = index
		end
	end
	return freezeDeep({
		List = list,
		Keys = keys,
		ByKey = byKey,
		IndexOf = indexOf,
	})
end

-- Same table plus derived or single-record fields (ToppingKeys, RecordKeys, Rules...).
function Table.with<T, E>(base: Table<T>, extra: E): Table<T> & E
	const out = table.clone(base :: any)
	for field, value in extra :: any do
		out[field] = value
	end
	return freezeDeep(out) :: any
end

-- Single record (RunParams, ItemRules...): plain table, frozen all the way down.
function Table.record<R>(record: R): R
	return freezeDeep(record)
end

-- Keys of the rows that pass the filter, in list order.
function Table.keysWhere<T>(base: Table<T>, keep: (T) -> boolean): { string }
	const out: { string } = {}
	for _, row in base.List do
		if keep(row) then
			table.insert(out, (row :: any).Key)
		end
	end
	return table.freeze(out)
end

return table.freeze(Table)
