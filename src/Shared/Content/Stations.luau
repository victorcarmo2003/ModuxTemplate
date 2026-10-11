--!strict
-- Vehicle kitchen stations (content-data.md §3.6; architecture.md §18.4; DEC-190, DEC-201, DEC-215).
-- StationKind on the tagged Model = key. The Stations set uses only rows with Record ~= "None" (RecordKeys),
-- record id = StationId * 100 + Slot (network.md §3.5). Drawer/POS, OPEN sign and Mart are not stations.
local Table = require(script.Parent.Table)

export type Record = "PerSlot" | "Single" | "None"

export type Station = {
	Key: string,
	Letter: string, -- MAP-01 §7.1 letter (documentation only)
	Record: Record,
	Actions: { string }, -- keys of Actions anchored on this station
	Ingredient: string?, -- key of Ingredients, "PerAnchor" (attribute on each anchor) or nil
	Params: { [string]: number }, -- numbers owned by the station; level/vehicle numbers come from Upgrades/Vehicles
}

const PER_ANCHOR = "PerAnchor"

const base = Table.new({
	{
		Key = "sausage_stock",
		Letter = "S",
		Record = "None",
		Actions = { "grill_place", "restock" },
		Ingredient = "sausage",
		Params = {},
	},
	{
		-- slots and time: Upgrades.grill (GrillSlots 2/3/4, GrillTime 12/10/8; DEC-046, DEC-201)
		Key = "grill",
		Letter = "G",
		Record = "PerSlot",
		Actions = { "grill_collect" },
		Params = {},
	},
	{
		-- capacity: Vehicles[v].RailSlots; consumed by board_add_sausage
		Key = "rail",
		Letter = "R",
		Record = "Single",
		Actions = {},
		Params = {},
	},
	{
		Key = "bun_crate",
		Letter = "B",
		Record = "None",
		Actions = { "bun_cut", "restock" },
		Ingredient = "bun",
		Params = { CutTime = 0.8 }, -- FEAT-006; 1.5 -> 0.8 s to match the knife sound bun_slice (user request 2026-10-11)
	},
	{
		-- slot count: Vehicles[v].BoardSlots (cart 2, trailer 3; DEC-190, DEC-215); one prompt on the board
		Key = "board",
		Letter = "T",
		Record = "PerSlot",
		Actions = { "board_add_sausage" },
		Params = {},
	},
	{
		-- 6 toppings; state lives in Stock (Amount, Blocked), DEC-156
		Key = "toppings",
		Letter = "K",
		Record = "None",
		Actions = { "topping_add", "restock" },
		Ingredient = PER_ANCHOR,
		Params = {},
	},
	{
		Key = "trash",
		Letter = "BIN-C",
		Record = "None",
		Actions = { "discard" },
		Params = {},
	},
	{
		-- trailer only (wave 2, FEAT-021): BrewTime 6 s, Barista via the CoffeeBrewTime class stat
		Key = "coffee_machine",
		Letter = "C",
		Record = "Single",
		Actions = { "brew_coffee", "restock" },
		Ingredient = "coffee",
		Params = { BrewTime = 6 },
	},
} :: { Station })

return Table.with(base, {
	PerAnchor = PER_ANCHOR,
	RecordKeys = Table.keysWhere(base, function(row: Station): boolean
		return row.Record ~= "None"
	end),
})
