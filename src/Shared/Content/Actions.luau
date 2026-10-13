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
	{ Key = "open_sign", Text = "Open Shop", Hold = 0.3, Radius = 6, Requires = { Phase = { "Prep", "Open" } }, Night = "Any", Wave = 1 },
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
	-- Customer prompts: 10 (was 8; owner playtest 2026-10-12, customers too far). The anchor rides on the customer rig.
	{ Key = "take_order", Text = "Take Order", Hold = 0, Radius = 10, Requires = {}, Night = "Any", Wave = 1 },
	-- no Requires.Held: the server picks the exact hot dog from the hotbar, or answers with a hint (2026-10-12)
	{ Key = "serve", Text = "Serve", Hold = 0, Radius = 10, Requires = {}, Night = "Any", Wave = 1 },
	{ Key = "refuse", Text = "Refuse", Hold = 1, Radius = 10, Requires = {}, Night = "Any", Wave = 1 },
	-- Cash register (Q-201, Provisional): drawer -> party Cash now. Anchor Prompt_Collect on the DRAWER / TRL-DRAWER model
	-- (CashDeskService); only enabled while the drawer is open and holds money. Short hold, smaller radius than the
	-- counter prompts so it never fights the ketchup / customer pills.
	{ Key = "collect_cash", Text = "Collect Cash", Hold = 0.4, Radius = 5, Requires = {}, Night = "Any", Wave = 1 },
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
	-- service window actions from FEAT-021/FEAT-023 (A7, architecture.md §19.26). Every wave 2-3 row is here already, so the
	-- wave 3 content task does not reopen this file.
	{ Key = "bench_buy_item", Text = "Buy {item} — ${price}", Hold = 1.5, Radius = 7, Requires = {}, Night = "Any", Wave = 4 },
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
	-- Prompt_Answer on the trailer phone (FEAT-018, DEC-124)
	{ Key = "answer_phone", Text = "Answer", Hold = 0, Radius = 7, Requires = {}, Night = "Any", Wave = 2 },
	-- the safe spot is a zone, not a prompt: the key exists for the enum only (content-data.md §6.9)
	{ Key = "safe_spot", Text = "Safe Spot", Hold = 0, Radius = 7, Requires = {}, Night = "NightOnly", Wave = 3 },
	-- trailer service window (FEAT-023, DEC-221): Prompt_Shutter next to the light switch; owner VehicleService,
	-- PromptText "Close Window"/"Open Window" by state, cooldown 1 s in Validate (Q-173, placeholder until ui-text.md)
	{ Key = "shutter_toggle", Text = "Close Window", Hold = 0.5, Radius = 7, Requires = {}, Night = "NightOnly", Wave = 3 },

	-- Trailer door (user request 2026-10-11, Provisional; owner TrailerDoorService): the back door only opens by prompt.
	-- Exit Trailer inside by the door, Enter Trailer outside by the steps; both only while the trailer is the vehicle in use.
	{ Key = "trailer_exit", Text = "Open door", Hold = 0, Radius = 1.4, Requires = {}, Night = "Any", Wave = 3 },
	{ Key = "trailer_enter", Text = "Open door", Hold = 0, Radius = 1.4, Requires = {}, Night = "Any", Wave = 3 },

	-- Pad tables (TASK-144; FEAT-037, UPG-008/009; Q-178 A, Q-181 A). Owner SeatingService; texts placeholder until
	-- ui-text.md (TASK-150). buy_in_place: "{item}" = "Table" / the upgrade name, "{price}" filled by the owner
	-- (PromptText); the anchor carries the attribute Upgrade (and TableIndex on a table).
	{ Key = "buy_in_place", Text = "Buy {item} — ${price}", Hold = 1.5, Radius = 7, Requires = {}, Night = "Any", Wave = 3 },
	{ Key = "clean_table", Text = "Clean Table", Hold = 1, Radius = 7, Requires = {}, Night = "Any", Wave = 3 },
	-- Order at the table (Q-209, Provisional): the customer sat after "Take Order"; the prompt sits on the table
	-- (ServeAnchor, SeatingService) and its PromptText names the table and the order ("Serve Table 2: Ketchup + Cheese").
	{ Key = "serve_table", Text = "Serve Table", Hold = 0, Radius = 8, Requires = {}, Night = "Any", Wave = 3 },

	-- Focused prep mode (DEC-223; prep-mode.md §2): Prompt_Work on each Station_n of the trailer; owner PrepService.
	-- Tap, selling phases only; the server revalidates seat, phase and the other station of the player.
	{ Key = "prep_work", Text = "Work", Hold = 0, Radius = 5, Requires = { Phase = { "Open", "Night" } }, Night = "Any", Wave = 3 },
} :: { Action })
