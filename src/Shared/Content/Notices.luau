--!strict
-- Toast notices (content-data.md §3.19, §6.9; network.md §4.2, §13.10). Owner of the texts: narrative-writer
-- (placeholders until ui-text.md, TASK-082). Keys are the Notice.Kind enum: every wave 1-3 key is here already.
-- ValueFrom says how the client reads Notice.Value: a plain number ({value}) or the IndexOf of a table row
-- ({item} = Ingredients or Items, {upgrade} = Upgrades, {class} = Classes, {achievement} = Achievements).
-- Wave = first wave that emits the key (documentation; the enum carries every row).
local Table = require(script.Parent.Table)

export type Audience = "Player" | "Party"
export type ValueFrom = "None" | "Number" | "Ingredients" | "Upgrades" | "Classes" | "Achievements" | "Items"

export type Notice = {
	Key: string,
	Text: string,
	Audience: Audience,
	ValueFrom: ValueFrom,
	Wave: number,
}

return Table.new({
	-- wave 1
	{ Key = "hands_full", Text = "Hands full", Audience = "Player", ValueFrom = "None", Wave = 1 }, -- FEAT-005, DEC-174
	{ Key = "package_limit", Text = "You can carry {value} packs", Audience = "Player", ValueFrom = "Number", Wave = 1 },
	{ Key = "not_enough_cash", Text = "Not enough cash (${value})", Audience = "Player", ValueFrom = "Number", Wave = 1 },
	{ Key = "upgrade_bought", Text = "{upgrade} upgraded!", Audience = "Party", ValueFrom = "Upgrades", Wave = 1 }, -- FEAT-015
	-- Gear Stand hint at closing time (Q-203 Provisional; MarketService: once per shift, only with money for an upgrade or before the first purchase)
	{ Key = "mart_hint", Text = "Upgrades are on sale at the Mart.", Audience = "Party", ValueFrom = "None", Wave = 1 },
	-- Day Last call (DEC-240, user decision 2026-10-13): 6 PM, no new customer, the trailer stays open until the line and the
	-- tables are served. Sent by CustomerService when the day Closing starts. Provisional text
	{ Key = "last_call", Text = "Last call! Serve who is still here.", Audience = "Party", ValueFrom = "None", Wave = 1 },
	{ Key = "ingredient_unlocked", Text = "New: {item}!", Audience = "Party", ValueFrom = "Ingredients", Wave = 1 }, -- FEAT-032
	-- gift bowl still closed (owner request 2026-10-14, Provisional): use / restock refused until "Open"
	{ Key = "topping_wrapped", Text = "Open the {item} bowl first!", Audience = "Player", ValueFrom = "Ingredients", Wave = 1 },
	-- free package of the unlock day taken with the hands full: straight into the stock (Provisional, FEAT-007)
	{ Key = "ingredient_stocked", Text = "New: {item} (stocked)", Audience = "Player", ValueFrom = "Ingredients", Wave = 1 },
	{ Key = "class_bought", Text = "{class} unlocked!", Audience = "Player", ValueFrom = "Classes", Wave = 1 }, -- DEC-186
	{ Key = "class_selected", Text = "Now playing as {class}", Audience = "Player", ValueFrom = "Classes", Wave = 1 },
	{ Key = "not_enough_gems", Text = "Not enough gems ({value})", Audience = "Player", ValueFrom = "Number", Wave = 1 },
	{ Key = "class_locked", Text = "{class} is locked", Audience = "Player", ValueFrom = "Classes", Wave = 1 },

	-- D-04 (wave-1-report.md §4; ui-text.md §10.3): refusals that were silent in wave 1. Only to the player who acted,
	-- throttled 2 s (TASK-081). Emitted by TASK-080 (stations, Mart), TASK-057 (restock), TASK-053 (Take Order).
	{ Key = "grill_full", Text = "The grill is full.", Audience = "Player", ValueFrom = "None", Wave = 2 },
	{ Key = "rail_full", Text = "The warmer is full.", Audience = "Player", ValueFrom = "None", Wave = 2 },
	{ Key = "board_full", Text = "No room on the board.", Audience = "Player", ValueFrom = "None", Wave = 2 },
	{ Key = "out_of_stock", Text = "Out of {item}! Restock it.", Audience = "Player", ValueFrom = "Ingredients", Wave = 2 },
	{ Key = "topping_max", Text = "3 toppings max!", Audience = "Player", ValueFrom = "None", Wave = 2 },
	{ Key = "topping_repeat", Text = "It already has {item}.", Audience = "Player", ValueFrom = "Ingredients", Wave = 2 },
	{ Key = "stock_full", Text = "{item} is already full.", Audience = "Player", ValueFrom = "Ingredients", Wave = 2 },
	{ Key = "shelf_locked", Text = "{item} isn't in stock yet.", Audience = "Player", ValueFrom = "Ingredients", Wave = 2 },
	{ Key = "bench_busy", Text = "Someone's buying that right now.", Audience = "Player", ValueFrom = "None", Wave = 2 },
	{ Key = "upgrade_maxed", Text = "{upgrade} is maxed out.", Audience = "Player", ValueFrom = "Upgrades", Wave = 2 },
	{ Key = "shop_closed", Text = "Open the shop first!", Audience = "Player", ValueFrom = "None", Wave = 2 },

	-- wave 2 (content-data.md §6.9; ui-text.md §10.1, §10.2)
	-- (trailer_available / trailer_waiting / trailer_cash / trailer_bought left with the trailer purchase, 2026-10-12)
	{ Key = "gems_gained", Text = "+{value} Gems!", Audience = "Player", ValueFrom = "Number", Wave = 2 }, -- DEC-104
	{ Key = "afk_no_gems", Text = "No gems today. Serve 3 full orders!", Audience = "Party", ValueFrom = "None", Wave = 2 },
	{
		Key = "achievement",
		Text = "Badge unlocked: {achievement}!",
		Audience = "Player",
		ValueFrom = "Achievements",
		Wave = 2,
	}, -- DEC-058
	{ Key = "thief_caught", Text = "Nice catch! +${value}", Audience = "Party", ValueFrom = "Number", Wave = 2 }, -- DEC-050
	{ Key = "thief_stole", Text = "The drawer got raided! -${value}", Audience = "Party", ValueFrom = "Number", Wave = 2 },
	{ Key = "coffee_cooldown", Text = "Coffee again in {value}s", Audience = "Player", ValueFrom = "Number", Wave = 2 },
	{ Key = "coffee_full", Text = "Already wide awake. Save it!", Audience = "Player", ValueFrom = "None", Wave = 2 },
	-- drink refused by day while Q-170 option A stands (Provisional)
	{ Key = "coffee_night_only", Text = "Save it for the night shift.", Audience = "Player", ValueFrom = "None", Wave = 2 },
	-- give_coffee to a mate who already holds one (CategoryLimits.Coffee = 1, FEAT-021)
	{ Key = "coffee_has_one", Text = "They already have a coffee.", Audience = "Player", ValueFrom = "None", Wave = 2 },

	-- wave 3
	-- counter action refused with the trailer window closed (DEC-221, Q-173); placeholder until ui-text.md
	{ Key = "shutter_closed", Text = "The window's shut. Open it to serve.", Audience = "Player", ValueFrom = "None", Wave = 3 },
	{ Key = "item_dropped", Text = "Dropped {item}!", Audience = "Player", ValueFrom = "Items", Wave = 3 }, -- FEAT-036
	-- Pad tables (TASK-144; FEAT-037): after a purchase in place, to the party (Value = table index 1..5); placeholder
	-- until ui-text.md (TASK-150). A refusal for cash reuses not_enough_cash.
	-- Serve with no hot dog to use (owner request 2026-10-12, Provisional): a hot dog sits in the hotbar but none is in hand /
	-- exact for the order, or the player carries none at all. A wrong hot dog in hand is still served (existing rules).
	{ Key = "serve_hold_hot_dog", Text = "Hold the hot dog you want to serve", Audience = "Player", ValueFrom = "None", Wave = 3 },
	{ Key = "serve_nothing", Text = "Nothing to serve yet", Audience = "Player", ValueFrom = "None", Wave = 3 },
	{ Key = "table_added", Text = "Table added!", Audience = "Party", ValueFrom = "Number", Wave = 3 },

	-- Focused prep mode (DEC-223; Prep.Reasons points at these). Only to the player who acted; Provisional texts
	{ Key = "prep_busy", Text = "Someone's already there.", Audience = "Player", ValueFrom = "None", Wave = 3 },
	{ Key = "prep_locked", Text = "Not right now.", Audience = "Player", ValueFrom = "None", Wave = 3 },
	{ Key = "prep_no_sausage", Text = "No sausage on the warmer yet.", Audience = "Player", ValueFrom = "None", Wave = 3 },
	{ Key = "prep_too_fast", Text = "Too fast! Try again.", Audience = "Player", ValueFrom = "None", Wave = 3 },
	{ Key = "prep_kicked", Text = "Prep interrupted.", Audience = "Player", ValueFrom = "None", Wave = 3 },
	{ Key = "tutorial_one_sausage", Text = "One sausage is plenty for now.", Audience = "Player", ValueFrom = "None", Wave = 3 },
	{ Key = "prep_idle", Text = "Stepped away from the station.", Audience = "Player", ValueFrom = "None", Wave = 3 },
} :: { Notice })
