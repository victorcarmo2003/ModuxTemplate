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
		-- slots and time: Upgrades.grill (GrillSlots 2/3/4, GrillTime 8/6/4 = first side 6/4/2 s + 2 s after the flip; DEC-046, DEC-201)
		Key = "grill",
		Letter = "G",
		Record = "PerSlot",
		-- grill_flip: restaurant prompt on Att_Slot<n> (wave R0 contract, R1-A handler; tech/restaurant-flow.md §2.3)
		Actions = { "grill_collect", "grill_flip" },
		Params = {},
	},
	{
		-- capacity: Vehicles[v].RailSlots; consumed by board_add_sausage
		Key = "rail",
		Letter = "R",
		Record = "Single",
		-- rail_take: restaurant hot pile "Take Dogs" -> sausage_grilled stack (wave R0 contract, R1-A handler)
		Actions = { "rail_take" },
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
		Actions = { "topping_add", "restock", "topping_unwrap" },
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
		-- trailer only (wave 2, FEAT-021): BrewTime 6 s, Barista via the CoffeeBrewTime class stat. TASK-328 (owner request
		-- 2026-10-15, Provisional): the machine brews by itself and owns the wait; after a cup is taken it cleans for
		-- CleanTime s, then brews the next one (the player no longer has a drink cooldown)
		Key = "coffee_machine",
		Letter = "C",
		Record = "Single",
		Actions = { "brew_coffee", "restock" },
		Ingredient = "coffee",
		Params = { BrewTime = 6, CleanTime = 60 },
	},
	{
		-- focused prep seats Station_1..4 (DEC-223, prep-mode.md §6): the seat state lives in the PrepSeats set, not in
		-- Stations; Att_Stand, CamAnchor, Focus, Att_Bun and Prompt_Work hang from the model
		Key = "prep",
		Letter = "W",
		Record = "None",
		Actions = { "prep_work" },
		Params = {},
	},
	{
		-- Restaurant CUT-n (tech/restaurant-flow.md rev. 2 §2.3; design FEAT-045). Wave R0 contract: no module and no anchor
		-- yet (R1-A writes Stations/Cut.luau). Stock is Stock.bun; CutTime = Actions.bun_slice.Hold = Restaurant.Bun.CutHold
		Key = "cut",
		Letter = "CUT",
		Record = "None",
		Actions = { "bun_slice", "restock" },
		Ingredient = "bun",
		Params = { CutTime = 0.6 },
	},
} :: { Station })

return Table.with(base, {
	PerAnchor = PER_ANCHOR,
	RecordKeys = Table.keysWhere(base, function(row: Station): boolean
		return row.Record ~= "None"
	end),
})
