--!strict
-- Ingredients (content-data.md §3.3). Owner: game-designer (+ art-director on Icon).
-- Stock record id = IndexOf[key]. ToppingKeys (Sauce + Topping) is the Customers.Order bitfield.
local Table = require(script.Parent.Table)

export type Kind = "Base" | "Sauce" | "Topping" | "Supply"
-- DEC-142: cheese always before the cords; the rest in assembly order.
export type Stack = "BeforeCords" | "Cord" | "InOrder"

export type Ingredient = {
	Key: string,
	Ref: string,
	Name: string,
	Kind: Kind,
	OrderPrice: number, -- added to the order price (DEC-071); 0 when not an order topping
	UnlockDay: number, -- 0 = depends on Vehicle
	Vehicle: string?, -- key of Vehicles, or nil (any vehicle)
	Weight: number, -- order draw weight (DEC-071); 0 when not an order topping
	Capacity: { number }, -- one entry per Storage level (Upgrades.cooler, 4 levels)
	Station: string, -- key of Stations
	Stack: Stack?, -- only Sauce/Topping
	Icon: string, -- rbxassetid; "" = placeholder until Q-152 (DEC-156)
}

const base = Table.new({
	{
		Key = "bun",
		Ref = "ITM-001",
		Name = "Bun",
		Kind = "Base",
		OrderPrice = 0,
		UnlockDay = 1,
		Weight = 0,
		Capacity = { 12, 16, 20, 24 }, -- +4 per Storage level (owner request 2026-10-14, Provisional)
		Station = "bun_crate",
		Icon = "",
	},
	{
		Key = "sausage",
		Ref = "ITM-002",
		Name = "Sausage",
		Kind = "Base",
		OrderPrice = 0,
		UnlockDay = 1,
		Weight = 0,
		Capacity = { 12, 16, 20, 24 }, -- follows the buns (one sausage per bun; Provisional)
		Station = "sausage_stock",
		Icon = "",
	},
	{
		Key = "ketchup",
		Ref = "ITM-003",
		Name = "Ketchup",
		Kind = "Sauce",
		OrderPrice = 1,
		UnlockDay = 1,
		Weight = 10,
		Capacity = { 15, 20, 25, 30 }, -- 15 +5 per level: three purchases reach the old 30 (owner request 2026-10-14)
		Station = "toppings",
		Stack = "Cord",
		Icon = "",
	},
	{
		Key = "mustard",
		Ref = "ITM-004",
		Name = "Mustard",
		Kind = "Sauce",
		OrderPrice = 1,
		UnlockDay = 1,
		Weight = 10,
		Capacity = { 15, 20, 25, 30 }, -- same as ketchup
		Station = "toppings",
		Stack = "Cord",
		Icon = "",
	},
	{
		Key = "cheese",
		Ref = "ITM-005",
		Name = "Cheese",
		Kind = "Topping",
		OrderPrice = 2,
		UnlockDay = 2,
		Weight = 7,
		Capacity = { 5, 6, 7, 8 }, -- same rule for every topping: about half at level 1, the old level-1 cap at level 4 (Provisional)
		Station = "toppings",
		Stack = "BeforeCords",
		Icon = "",
	},
	{
		Key = "bacon",
		Ref = "ITM-006",
		Name = "Bacon",
		Kind = "Topping",
		OrderPrice = 3,
		UnlockDay = 3,
		Weight = 6,
		Capacity = { 5, 6, 7, 8 }, -- same rule (Provisional)
		Station = "toppings",
		Stack = "InOrder",
		Icon = "",
	},
	{
		Key = "potato_sticks",
		Ref = "ITM-007",
		Name = "Potato Sticks",
		Kind = "Topping",
		OrderPrice = 2,
		UnlockDay = 4,
		Weight = 6,
		Capacity = { 6, 9, 12, 15 }, -- same rule (Provisional)
		Station = "toppings",
		Stack = "InOrder",
		Icon = "",
	},
	{
		Key = "cream_cheese",
		Ref = "ITM-008",
		Name = "Cream Cheese",
		Kind = "Topping",
		OrderPrice = 2,
		UnlockDay = 6,
		Weight = 5,
		Capacity = { 6, 8, 10, 12 }, -- same rule (Provisional; Q-062)
		Station = "toppings",
		Stack = "Cord",
		Icon = "",
	},
	{
		Key = "coffee",
		Ref = "ITM-009",
		Name = "Coffee",
		Kind = "Supply",
		OrderPrice = 0,
		UnlockDay = 0,
		Vehicle = "trailer",
		Weight = 0,
		Capacity = { 20, 20, 20, 20 }, -- Storage does not change coffee
		Station = "coffee_machine",
		Icon = "",
	},
} :: { Ingredient })

return Table.with(base, {
	ToppingKeys = Table.keysWhere(base, function(row: Ingredient): boolean
		return row.Kind == "Sauce" or row.Kind == "Topping"
	end),
	-- Gift bowls (owner request 2026-10-14, Provisional): the toppings that unlock after Day 1 arrive as a CLOSED bowl the
	-- player opens once ("Open", topping_unwrap) and that comes full. The Day 1 bowls (ketchup, mustard) start open.
	GiftKeys = Table.keysWhere(base, function(row: Ingredient): boolean
		return (row.Kind == "Sauce" or row.Kind == "Topping") and row.UnlockDay > 1
	end),
})
