--!strict
-- Hotbar Tools and ItemRules (content-data.md §3.5; DEC-040, DEC-103, DEC-174, DEC-190). Owner: game-designer.
-- The Tool in the kit is ReplicatedStorage.Assets.Items.Tools/<key> (architecture.md §18.9.1).
-- Tool attributes (written only by ItemService, network.md §7.1): Item, Count, Toppings (HotDog), Altered (wave 3).
-- Drop rules: FEAT-036 (only the equipped Tool drops when hit). DropDespawn = seconds on the street (90 s Provisional, DEC-197,
-- A10); items left by a spectator on the counter (DROP-T) last until the end of the next shift (ItemService rule).
local Table = require(script.Parent.Table)

export type Kind = "Package" | "Consumable" | "Product" | "Revive" | "Anomaly" | "Ingredient"
export type Category = "Package" | "HotDog" | "Coffee" | "Altered" | "Revive" | "Ingredient"
export type DropOnHit = "Keep" | "Lost" | "Vanish"

export type Item = {
	Key: string,
	Ref: string,
	Name: string, -- Tool name in the hotbar
	Kind: Kind,
	Category: Category, -- key of ItemRules.CategoryLimits
	Stackable: boolean, -- count in the Tool attribute Count
	DropOnHit: DropOnHit,
	DropDespawn: number | "NextShiftEnd", -- seconds on the street; 0 = immediately
	KeepOnSpectate: boolean,
	Use: boolean, -- active item: ItemService:RegisterUse handles Tool.Activated (coffee, revive_kit; T51)
}

export type ItemRules = {
	HotbarSlots: number, -- total Tools per player; the 5th is refused with "Hands full" (DEC-174)
	CategoryLimits: { [Category]: number },
}

local function pack(key: string, ref: string, name: string): Item
	return {
		Key = key,
		Ref = ref,
		Name = name,
		Kind = "Package",
		Category = "Package",
		Stackable = true,
		DropOnHit = "Keep",
		DropDespawn = 90, -- FEAT-036; 90 s Provisional (DEC-197 said 60; user request 2026-10-11)
		KeepOnSpectate = false,
		Use = false,
	}
end

const base = Table.new({
	pack("pack_sausages", "ITM-011", "Sausages"),
	pack("pack_buns", "ITM-012", "Buns"),
	pack("pack_ketchup", "ITM-013", "Ketchup"),
	pack("pack_mustard", "ITM-014", "Mustard"),
	pack("pack_cheese", "ITM-015", "Cheese"),
	pack("pack_bacon", "ITM-016", "Bacon"),
	pack("pack_potato_sticks", "ITM-017", "Potato Sticks"),
	pack("pack_cream_cheese", "ITM-018", "Cream Cheese"),
	pack("pack_coffee", "ITM-019", "Ground Coffee"), -- D-10 (TASK-081)
	{
		Key = "coffee",
		Ref = "ITM-009",
		Name = "Coffee",
		Kind = "Consumable",
		Category = "Coffee",
		Stackable = true,
		DropOnHit = "Keep", -- Provisional (user request 2026-10-11): a car hit never destroys what was bought / made
		DropDespawn = 90,
		KeepOnSpectate = false,
		Use = true, -- drink at night (FEAT-021; Q-170)
	},
	{
		Key = "hot_dog",
		Ref = "ITM-010",
		Name = "Hot Dog",
		Kind = "Product",
		Category = "HotDog",
		Stackable = false,
		DropOnHit = "Keep", -- Provisional (user request 2026-10-11), toppings travel with the drop
		DropDespawn = 90,
		KeepOnSpectate = false,
		Use = false,
	},
	{
		Key = "altered_item",
		Ref = "ITM-020",
		Name = "Altered Item",
		Kind = "Anomaly",
		Category = "Altered",
		Stackable = false,
		DropOnHit = "Vanish",
		DropDespawn = 0,
		KeepOnSpectate = false,
		Use = false,
	},
	{
		Key = "revive_kit",
		Ref = "ITM-021",
		Name = "Rescue Whistle", -- display name proposed in ui-text.md; key stays revive_kit
		Kind = "Revive",
		Category = "Revive",
		Stackable = false,
		DropOnHit = "Keep",
		DropDespawn = 90, -- FEAT-036; 90 s Provisional (DEC-197 said 60; user request 2026-10-11)
		KeepOnSpectate = false,
		Use = true, -- wave 4 (ReviveService)
	},
	-- Restaurant (tech/restaurant-flow.md rev. 2 §4.2, design FEAT-045/FEAT-050; wave R0, kit Tools come with R1-E).
	-- Stacks: Count = pieces in hand, capped by Content.Restaurant.Stacks (Bun / Sausage; UPG-018/019 raise it)
	{
		Key = "bun_sliced",
		Ref = "ITM-022",
		Name = "Buns",
		Kind = "Ingredient",
		Category = "Ingredient",
		Stackable = true,
		DropOnHit = "Keep",
		DropDespawn = 90,
		KeepOnSpectate = false,
		Use = false,
	},
	{
		Key = "sausage_grilled",
		Ref = "ITM-023",
		Name = "Dogs",
		Kind = "Ingredient",
		Category = "Ingredient",
		Stackable = true,
		DropOnHit = "Keep",
		DropDespawn = 90,
		KeepOnSpectate = false,
		Use = false,
	},
	-- Conveyor plate (DEC-304, prep-conveyor.md §6.3, DT-E8): the plate NOT assembled yet, in the hand (born empty with the
	-- ticket on the central table). Assembled (Finish accepted) it becomes hot_dog. Same HotDog category: 2 plates in hand at
	-- most (DEC-299). Attributes written by PlateService: PlateId, Ticket, TicketLine, Orphan, Bun, Dog, Toppings, FlipBonus.
	-- Not in the run snapshot (Stash). Ref ITM-025: Provisional, to be registered in design/items.md
	{
		Key = "plate",
		Ref = "ITM-025",
		Name = "Plate",
		Kind = "Product",
		Category = "HotDog",
		Stackable = false,
		DropOnHit = "Keep",
		DropDespawn = 90,
		KeepOnSpectate = false,
		Use = false,
	},
	-- FEAT-050 stock box from the service hatch: attribute Package (Content.Packages key) + Count = units left; Restock like a
	-- Mart package (category Package, same per-player limit: 2, PackageLimit stat 3)
	{
		Key = "stock_box",
		Ref = "ITM-024",
		Name = "Box",
		Kind = "Package",
		Category = "Package",
		Stackable = true,
		DropOnHit = "Keep",
		DropDespawn = 90,
		KeepOnSpectate = false,
		Use = false,
	},
} :: { Item })

const rules: ItemRules = {
	HotbarSlots = 4, -- DEC-174
	CategoryLimits = {
		Package = 2, -- DEC-049; PackageLimit stat (bear) raises it to 3 inside the 4 slots
		HotDog = 2, -- FEAT-005, Provisional
		Coffee = 1,
		Altered = 1,
		Revive = 1, -- DEC-100
		Ingredient = 2, -- restaurant stacks: one bun_sliced + one sausage_grilled (design FEAT-045, Provisional)
	},
}

return Table.with(base, {
	Rules = Table.record(rules),
})
