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
	{ Key = "ingredient_unlocked", Text = "New: {item}!", Audience = "Party", ValueFrom = "Ingredients", Wave = 1 }, -- FEAT-032
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
	{ Key = "trailer_available", Text = "Old trailer for sale! Check the lot.", Audience = "Party", ValueFrom = "None", Wave = 2 },
	{ Key = "trailer_waiting", Text = "The trailer's still waiting in the lot.", Audience = "Party", ValueFrom = "None", Wave = 2 },
	{ Key = "trailer_bought", Text = "Trailer bought! It's yours next shift.", Audience = "Party", ValueFrom = "None", Wave = 2 },
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
	{ Key = "hide_taken", Text = "Someone's already hiding there.", Audience = "Player", ValueFrom = "None", Wave = 3 },
	{ Key = "item_dropped", Text = "Dropped {item}!", Audience = "Player", ValueFrom = "Items", Wave = 3 }, -- FEAT-036
} :: { Notice })
