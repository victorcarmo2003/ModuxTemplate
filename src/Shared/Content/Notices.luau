--!strict
-- Toast notices (content-data.md §3.19; network.md §4.2). Owner of the texts: narrative-writer (placeholders until
-- ui-text.md). Keys are the Notice.Kind enum. Wave 1 keys only; later waves append rows.
-- ValueFrom says how the client reads Notice.Value: a plain number ({value}) or the IndexOf of a table row
-- ({item} = Ingredients, {upgrade} = Upgrades, {class} = Classes).
local Table = require(script.Parent.Table)

export type Audience = "Player" | "Party"
export type ValueFrom = "None" | "Number" | "Ingredients" | "Upgrades" | "Classes"

export type Notice = {
	Key: string,
	Text: string,
	Audience: Audience,
	ValueFrom: ValueFrom,
}

return Table.new({
	{ Key = "hands_full", Text = "Hands full", Audience = "Player", ValueFrom = "None" }, -- FEAT-005, DEC-174
	{ Key = "package_limit", Text = "You can carry {value} packs", Audience = "Player", ValueFrom = "Number" },
	{ Key = "not_enough_cash", Text = "Not enough cash (${value})", Audience = "Player", ValueFrom = "Number" },
	{ Key = "upgrade_bought", Text = "{upgrade} upgraded!", Audience = "Party", ValueFrom = "Upgrades" }, -- FEAT-015
	{ Key = "ingredient_unlocked", Text = "New: {item}!", Audience = "Party", ValueFrom = "Ingredients" }, -- FEAT-032
	{ Key = "class_bought", Text = "{class} unlocked!", Audience = "Player", ValueFrom = "Classes" }, -- DEC-186
	{ Key = "class_selected", Text = "Now playing as {class}", Audience = "Player", ValueFrom = "Classes" },
	{ Key = "not_enough_gems", Text = "Not enough gems ({value})", Audience = "Player", ValueFrom = "Number" },
	{ Key = "class_locked", Text = "{class} is locked", Audience = "Player", ValueFrom = "Classes" },
} :: { Notice })
