--!strict
-- Stash and snapshot "T" conversions (architecture.md §19.12, T50; data.md §5.2, §5.3; TASK-066). Pure: no Modux,
-- no network, no Instances. ItemService reads the Tool attributes into entries and back into GiveOptions.
-- Entry = RunStateService.StashEntry { Kind, Count, Extra }. Extra carries what the Tool needs beyond the key:
--   hot_dog -> Toppings ("ketchup,cheese", DEC-190); coffee -> Restore (tostring of the sanity it restores, §19.8).
-- Snapshot "T" item = { item, count, extra? } (data.md §5.3).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

export type Entry = { Kind: string, Count: number, Extra: string? }

-- What Give needs to rebuild one entry (subset of ItemService.GiveOptions).
export type Rebuild = { Count: number?, Toppings: string?, Restore: number? }

const HOT_DOG = "hot_dog"
const COFFEE = "coffee"
const MAX_COUNT = 999 -- RunStateService stash cap per entry
const MAX_ENTRIES = 32 -- RunStateService stash cap per member

const Stash = {}

-- Entry of one Tool from its attributes; nil for a key that is not in Content.Items.
function Stash.entry(kind: string, count: any, toppings: any, restore: any): Entry?
	const item = Content.Items.ByKey[kind]
	if item == nil then
		return nil
	end
	const amount = if item.Stackable and type(count) == "number" then math.clamp(math.floor(count), 1, MAX_COUNT) else 1
	local extra: string? = nil
	if kind == HOT_DOG and type(toppings) == "string" and toppings ~= "" then
		extra = toppings
	elseif kind == COFFEE and type(restore) == "number" then
		extra = tostring(math.floor(restore))
	end
	return { Kind = kind, Count = amount, Extra = extra }
end

-- GiveOptions fields that rebuild the Tool of an entry.
function Stash.rebuild(entry: Entry): Rebuild
	const item = Content.Items.ByKey[entry.Kind]
	const out: Rebuild = {}
	if item and item.Stackable then
		out.Count = entry.Count
	end
	if entry.Kind == HOT_DOG then
		out.Toppings = entry.Extra
	elseif entry.Kind == COFFEE and entry.Extra ~= nil then
		out.Restore = tonumber(entry.Extra)
	end
	return out
end

-- Concatenation capped at the stash limit (a stash plus the Tools in play).
function Stash.merge(a: { Entry }, b: { Entry }): { Entry }
	const out: { Entry } = {}
	for _, list in { a, b } do
		for _, entry in list do
			if #out >= MAX_ENTRIES then
				return out
			end
			table.insert(out, { Kind = entry.Kind, Count = entry.Count, Extra = entry.Extra })
		end
	end
	return out
end

-- Snapshot "T" form of a list of entries.
function Stash.encode(entries: { Entry }): { { any } }
	const out: { { any } } = {}
	for _, entry in entries do
		if entry.Extra ~= nil then
			table.insert(out, { entry.Kind, entry.Count, entry.Extra })
		else
			table.insert(out, { entry.Kind, entry.Count })
		end
	end
	return out
end

-- Entries back from the snapshot; bad items are skipped (unknown key, bad count, bad extra).
function Stash.decode(list: any): { Entry }
	const out: { Entry } = {}
	if type(list) ~= "table" then
		return out
	end
	for _, raw in list do
		if #out >= MAX_ENTRIES then
			break
		end
		if type(raw) ~= "table" or type(raw[1]) ~= "string" then
			continue
		end
		const extra = raw[3]
		if extra ~= nil and type(extra) ~= "string" then
			continue
		end
		const kind: string = raw[1]
		const count = raw[2]
		if type(count) ~= "number" or count ~= count or count < 1 then
			continue
		end
		const entry = Stash.entry(kind, count, if kind == HOT_DOG then extra else nil, nil)
		if entry == nil then
			continue
		end
		if kind == COFFEE and extra ~= nil and tonumber(extra) ~= nil then
			entry.Extra = extra
		end
		table.insert(out, entry)
	end
	return out
end

return table.freeze(Stash)
