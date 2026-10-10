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
	Capacity: { number }, -- one entry per Cooler level (Upgrades.cooler)
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
		Capacity = { 12, 20, 30 },
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
		Capacity = { 12, 20, 30 },
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
		Capacity = { 30, 50, 75 },
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
		Capacity = { 30, 50, 75 },
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
		Capacity = { 8, 14, 20 },
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
		Capacity = { 8, 14, 20 },
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
		Capacity = { 15, 25, 35 },
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
		Capacity = { 12, 20, 30 }, -- levels 2/3 Provisional (Q-062)
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
		Capacity = { 20, 20, 20 }, -- Cooler does not change coffee
		Station = "coffee_machine",
		Icon = "",
	},
} :: { Ingredient })

return Table.with(base, {
	ToppingKeys = Table.keysWhere(base, function(row: Ingredient): boolean
		return row.Kind == "Sauce" or row.Kind == "Topping"
	end),
})
