--!strict
-- Mart packages (content-data.md §3.4; items.md, DEC-049, DEC-071). Owner: game-designer.
-- Shelf anchors carry Package = key (architecture.md §18.4). Carry limit: ItemRules.CategoryLimits.Package.
local Table = require(script.Parent.Table)

export type Package = {
	Key: string,
	Ref: string,
	Name: string,
	Ingredient: string, -- key of Ingredients
	Amount: number, -- units/uses added on Restock
	Price: number, -- party cash
	Item: string, -- key of Items (the Tool carried to the station)
}

return Table.new({
	{ Key = "pack_sausages", Ref = "ITM-011", Name = "Sausages", Ingredient = "sausage", Amount = 8, Price = 6, Item = "pack_sausages" },
	{ Key = "pack_buns", Ref = "ITM-012", Name = "Buns", Ingredient = "bun", Amount = 8, Price = 4, Item = "pack_buns" },
	{ Key = "pack_ketchup", Ref = "ITM-013", Name = "Ketchup", Ingredient = "ketchup", Amount = 20, Price = 4, Item = "pack_ketchup" },
	{ Key = "pack_mustard", Ref = "ITM-014", Name = "Mustard", Ingredient = "mustard", Amount = 20, Price = 4, Item = "pack_mustard" },
	{ Key = "pack_cheese", Ref = "ITM-015", Name = "Cheese", Ingredient = "cheese", Amount = 6, Price = 6, Item = "pack_cheese" },
	{ Key = "pack_bacon", Ref = "ITM-016", Name = "Bacon", Ingredient = "bacon", Amount = 6, Price = 9, Item = "pack_bacon" },
	{
		Key = "pack_potato_sticks",
		Ref = "ITM-017",
		Name = "Potato Sticks",
		Ingredient = "potato_sticks",
		Amount = 10,
		Price = 5,
		Item = "pack_potato_sticks",
	},
	{
		Key = "pack_cream_cheese",
		Ref = "ITM-018",
		Name = "Cream Cheese",
		Ingredient = "cream_cheese",
		Amount = 8,
		Price = 6,
		Item = "pack_cream_cheese",
	},
	{ Key = "pack_coffee", Ref = "ITM-019", Name = "Coffee", Ingredient = "coffee", Amount = 10, Price = 5, Item = "pack_coffee" },
} :: { Package })
