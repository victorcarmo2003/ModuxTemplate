--!strict
-- Prompt actions (content-data.md §3.18; FEAT-005..008, FEAT-011, FEAT-015; DEC-066, DEC-190).
-- Keys are the Interact.Action enum. Later-wave keys exist already (enum and binding check need them) with no
-- active prompt in wave 1. Requires holds only what the client can pre-check for presentation (hand + phase);
-- the server revalidates everything (slot free, stock, cash...).
local Table = require(script.Parent.Table)

export type Night = "Any" | "DayOnly" | "NightOnly"

export type Requires = {
	Held: string?, -- key of Items or an ItemRules category ("Package")
	NotHasTopping: boolean?, -- Held hot dog must not already carry the anchor's ingredient
	Phase: { string }?, -- keys of Shift
}

export type Action = {
	Key: string,
	Text: string, -- "{item}" = Name of the anchor's ingredient/package; "{price}"/"{upgrade}" filled by the owner
	Hold: number, -- seconds; 0 = tap
	Radius: number, -- studs (server adds slack on validation)
	Requires: Requires,
	Night: Night,
	Wave: number, -- first wave with an active prompt
}

return Table.new({
	-- wave 1
	{ Key = "open_sign", Text = "Open Shop", Hold = 0, Radius = 10, Requires = { Phase = { "Prep" } }, Night = "Any", Wave = 1 },
	{ Key = "grill_place", Text = "Grill", Hold = 0, Radius = 7, Requires = {}, Night = "Any", Wave = 1 },
	{ Key = "grill_collect", Text = "Collect", Hold = 0, Radius = 7, Requires = {}, Night = "Any", Wave = 1 },
	{ Key = "bun_cut", Text = "Slice Bun", Hold = 0.5, Radius = 7, Requires = {}, Night = "Any", Wave = 1 },
	{ Key = "board_add_sausage", Text = "Add Sausage", Hold = 0, Radius = 7, Requires = {}, Night = "Any", Wave = 1 },
	{
		Key = "topping_add",
		Text = "Add {item}",
		Hold = 1,
		Radius = 7,
		Requires = { Held = "hot_dog", NotHasTopping = true },
		Night = "Any",
		Wave = 1,
	},
	{ Key = "discard", Text = "Throw Away", Hold = 0.5, Radius = 7, Requires = { Held = "hot_dog" }, Night = "Any", Wave = 1 },
	{ Key = "take_order", Text = "Take Order", Hold = 0, Radius = 10, Requires = {}, Night = "Any", Wave = 1 },
	{ Key = "serve", Text = "Serve", Hold = 0, Radius = 10, Requires = { Held = "hot_dog" }, Night = "Any", Wave = 1 },
	{ Key = "refuse", Text = "Refuse", Hold = 1, Radius = 10, Requires = {}, Night = "Any", Wave = 1 },
	{ Key = "restock", Text = "Restock", Hold = 1, Radius = 7, Requires = { Held = "Package" }, Night = "Any", Wave = 1 },
	{ Key = "buy_package", Text = "Buy {item} — ${price}", Hold = 0.5, Radius = 7, Requires = {}, Night = "Any", Wave = 1 },
	{
		Key = "bench_buy_upgrade",
		Text = "Buy {upgrade} — ${price}",
		Hold = 1.5,
		Radius = 7,
		Requires = {},
		Night = "Any",
		Wave = 1,
	},
	-- wave 1: only the free pack of the unlock day (display model, not a Tool; N-03, Provisional).
	-- Dropped items (wave 3, FEAT-036) reuse it with PromptHold = 0.5 on the anchor.
	{ Key = "pick_up_item", Text = "Take", Hold = 0, Radius = 7, Requires = {}, Night = "Any", Wave = 1 },

	-- later waves (texts Provisional until ui-text.md; owners: game-designer, narrative-writer). Holds of the coffee and
	-- hide actions from FEAT-021/FEAT-023 (A7, architecture.md §19.26). Every wave 2-3 row is here already, so the
	-- wave 3 content task does not reopen this file.
	{ Key = "bench_buy_item", Text = "Buy {item} — ${price}", Hold = 1.5, Radius = 7, Requires = {}, Night = "Any", Wave = 4 },
	{ Key = "buy_trailer", Text = "Buy Trailer — ${price}", Hold = 2, Radius = 10, Requires = {}, Night = "DayOnly", Wave = 2 },
	-- "Take Coffee" when the machine is Ready (PromptText from CoffeeMachine.luau, architecture.md §19.8)
	{ Key = "brew_coffee", Text = "Brew Coffee", Hold = 1, Radius = 7, Requires = {}, Night = "Any", Wave = 2 },
	-- on the Prompt_Give anchor of a crew mate's HRP (CharacterService); the owner never targets its own
	{
		Key = "give_coffee",
		Text = "Give",
		Hold = 0.5,
		Radius = 7,
		Requires = { Held = "coffee" },
		Night = "NightOnly",
		Wave = 2,
	},
	{ Key = "switch_light", Text = "Lights", Hold = 0, Radius = 7, Requires = {}, Night = "Any", Wave = 2 },
	-- Prompt_Answer on the cart and trailer phones (FEAT-018, DEC-124)
	{ Key = "answer_phone", Text = "Answer", Hold = 0, Radius = 7, Requires = {}, Night = "Any", Wave = 2 },
	{ Key = "hide", Text = "Hide", Hold = 0.5, Radius = 7, Requires = {}, Night = "NightOnly", Wave = 3 },
	-- the safe spot is a zone, not a prompt: the key exists for the enum only (content-data.md §6.9)
	{ Key = "safe_spot", Text = "Hide", Hold = 0, Radius = 7, Requires = {}, Night = "NightOnly", Wave = 3 },
	-- leave a hide point (FEAT-023); local button of HideController
	{ Key = "get_up", Text = "Get Up", Hold = 0, Radius = 10, Requires = {}, Night = "NightOnly", Wave = 3 },
} :: { Action })
