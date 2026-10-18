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
	-- open_sign (the red "Open Shop" wall switch) left with TASK-284: the service window below opens and closes the shop
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
		Wave = 3,
	},
	{ Key = "discard", Text = "Throw Away", Hold = 0.5, Radius = 7, Requires = { Held = "hot_dog" }, Night = "Any", Wave = 1 },
	-- Customer prompts: 10 (was 8; owner playtest 2026-10-12, customers too far). The anchor rides on the customer rig.
	{ Key = "take_order", Text = "Take Order", Hold = 0, Radius = 10, Requires = {}, Night = "Any", Wave = 1 },
	-- no Requires.Held: the server picks the exact hot dog from the hotbar, or answers with a hint (2026-10-12)
	{ Key = "serve", Text = "Serve", Hold = 0, Radius = 10, Requires = {}, Night = "Any", Wave = 1 },
	-- TASK-354 (owner 2026-10-17, Provisional): no handler and no anchor any more (refusing = closing the service window);
	-- the row stays for the Interact enum and the Acted/metrics verb "refuse"
	{ Key = "refuse", Text = "Refuse", Hold = 1, Radius = 10, Requires = {}, Night = "Any", Wave = 1 },
	-- Tip jar (DEC-239, user decision 2026-10-13; was "collect_cash" on the register, Q-201): tips in the jar -> party Cash
	-- now. Anchor Prompt_Collect on the TRL-TIPJAR model (TipJarService); only enabled while the shop takes entries and the
	-- jar holds money. Short hold, smaller radius than the counter prompts so it never fights the ketchup / customer pills.
	{ Key = "collect_tips", Text = "Collect Tips", Hold = 0.4, Radius = 5, Requires = {}, Night = "Any", Wave = 1 },
	{ Key = "restock", Text = "Restock", Hold = 1, Radius = 7, Requires = { Held = "Package" }, Night = "Any", Wave = 1 },
	-- Gift bowl (owner request 2026-10-14, Provisional): a topping that just unlocked comes as a CLOSED bowl; "Open" unwraps it and
	-- fills it to capacity (KitchenService, Stations/Toppings). Anchor Prompt_Unwrap_<Suf> (made at runtime when the map has none)
	-- TASK-277: a real "hold E" (1 s, was 0.5) on the gift-wrapped bowl (black Highlight, white outline)
	{ Key = "topping_unwrap", Text = "Open", Hold = 1, Radius = 7, Requires = {}, Night = "Any", Wave = 1 },
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
	{ Key = "brew_coffee", Text = "Take Coffee", Hold = 1, Radius = 7, Requires = {}, Night = "Any", Wave = 2 },
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
	-- ANM-020 blackout (TASK-273, DEC-254 family C; Provisional): Prompt_Breaker at the back of the trailer, owner LightService;
	-- enabled only while the power is out. Hold 3 s turns everything back on.
	{ Key = "breaker_reset", Text = "Reset Breaker", Hold = 3, Radius = 4, Requires = {}, Night = "Any", Wave = 3 },
	-- Prompt_Answer on the trailer phone (FEAT-018, DEC-124)
	{ Key = "answer_phone", Text = "Answer", Hold = 0, Radius = 7, Requires = {}, Night = "Any", Wave = 2 },
	-- the safe spot is a zone, not a prompt: the key exists for the enum only (content-data.md §6.9)
	{ Key = "safe_spot", Text = "Safe Spot", Hold = 0, Radius = 7, Requires = {}, Night = "NightOnly", Wave = 3 },
	-- trailer service window (FEAT-023, DEC-221): Prompt_Shutter, the lever next to the phone; owner VehicleService,
	-- PromptText "Close Window"/"Open Window" by state, cooldown 1 s in Validate (Q-173, placeholder until ui-text.md).
	-- TASK-284 (owner request 2026-10-14, Provisional): the ONLY shop lever, day and night. Open window = shop open, closed =
	-- shop closed (Content.ShopWindow); opening it in Prep starts the selling phase. Phase list = when the lever works.
	{
		Key = "shutter_toggle",
		Text = "Close Window",
		Hold = 0.5,
		Radius = 7,
		-- "Call" (owner decision 2026-10-17, Provisional): the night call no longer locks the window; opening it while Walt
		-- talks starts the night at once (RoundService:OpenShop), the call keeps going
		Requires = { Phase = { "Call", "Prep", "Open", "Closing", "Night" } },
		Night = "Any",
		Wave = 1,
	},

	-- Trailer door (user request 2026-10-11, Provisional; owner TrailerDoorService): the back door only opens by prompt.
	-- Exit Trailer inside by the door, Enter Trailer outside by the steps; both only while the trailer is the vehicle in use.
	-- Radius 3.6 x2 < ~7.65 studs between the two anchors (TrailerDoorService): the spheres must not overlap, or the
	-- menu lists the same "Open door" twice (both actions have the same text since 2026-10-12).
	{ Key = "trailer_exit", Text = "Open door", Hold = 0, Radius = 3.6, Requires = {}, Night = "Any", Wave = 3 },
	{ Key = "trailer_enter", Text = "Open door", Hold = 0, Radius = 3.6, Requires = {}, Night = "Any", Wave = 3 },
	-- restaurant back door by hand (owner 2026-10-18; RestaurantDoorService sets Open / Close / Locked as PromptText)
	{ Key = "door_toggle", Text = "Open Door", Hold = 0, Radius = 4, Requires = {}, Night = "Any", Wave = 3 },

	-- Pad tables (TASK-144; FEAT-037, UPG-008/009; Q-178 A, Q-181 A). Owner SeatingService; texts placeholder until
	-- ui-text.md (TASK-150). buy_in_place: "{item}" = "Table" / the upgrade name, "{price}" filled by the owner
	-- (PromptText); the anchor carries the attribute Upgrade (and TableIndex on a table).
	{ Key = "buy_in_place", Text = "Buy {item} — ${price}", Hold = 1.5, Radius = 7, Requires = {}, Night = "Any", Wave = 3 },
	{ Key = "clean_table", Text = "Clean Table", Hold = 1, Radius = 7, Requires = {}, Night = "Any", Wave = 3 },
	-- Order at the table (Q-209, Provisional): the customer sat after "Take Order"; the prompt sits on the table
	-- (ServeAnchor, SeatingService) and its PromptText names the table and the order ("Serve Table 2: Ketchup + Cheese").
	{ Key = "serve_table", Text = "Serve Table", Hold = 0, Radius = 8, Requires = {}, Night = "Any", Wave = 3 },

	-- Focused prep mode (DEC-223; prep-mode.md §2): Prompt_Work on each Station_n of the trailer; owner PrepService.
	-- Tap, selling phases and the day Last call (Closing, DEC-240); the server revalidates seat, phase and the other station.
	-- Conveyor (Prep.Rules.Mode = "Conveyor", prep-conveyor.md §2.2): Prompt_Work in front of the low deck = a belt seat
	{ Key = "prep_work", Text = "Work", Hold = 0, Radius = 5, Requires = { Phase = { "Open", "Closing", "Night" } }, Night = "Any", Wave = 3 },
	-- Conveyor (DEC-305, two prompts): Prompt_Grill = the grill seat (Conveyor.Seats.Grill); owner PrepService, same phases
	{ Key = "prep_grill", Text = "Grill", Hold = 0, Radius = 5, Requires = { Phase = { "Open", "Closing", "Night" } }, Night = "Any", Wave = 3 },

	-- Revive Kit (TASK-317; DEC-117, DEC-255; Provisional): Prompt_Revive on the HRP of a fallen mate's body (ReviveKitService);
	-- spends one profile.ReviveCredits of who holds it. The client shows it only with credits (ReviveKitController gate).
	{ Key = "revive_mate", Text = "Use Revive Kit", Hold = 1.5, Radius = 7, Requires = {}, Night = "Any", Wave = 3 },

	-- Security cameras (FEAT-040, TASK-285; owner request 2026-10-14, Provisional): Prompt_Cameras on the CCTV monitor of the
	-- trailer (SecurityService makes it). Opens the camera view on this client (SecurityOpen) and freezes the body while watching.
	{ Key = "watch_cameras", Text = "Cameras", Hold = 0, Radius = 6, Requires = {}, Night = "Any", Wave = 3 },

	-- Anomaly Tablet (TASK-335, TASK-345; owner request 2026-10-15, Provisional): Prompt_Tablet on the tablet in the
	-- trailer (tools/assetplace/anomaly_tablet.luau). Opens it on this client (JournalOpen); nothing else changes.
	{ Key = "read_journal", Text = "Anomaly Tablet", Hold = 0, Radius = 6, Requires = {}, Night = "Any", Wave = 3 },

	-- Restaurant (DEC-269..DEC-280; tech/restaurant-flow.md rev. 2 §4.2, design/restaurant-flow.md FEAT-043..FEAT-050).
	-- Wave R0 contracts: no anchor in the place and no handler until R1 (Content.Restaurant.Rules.Enabled). The client shows
	-- plate_put / plate_take by hand (PromptController/Rules.luau); the server revalidates. Texts placeholder (ui-text.md).
	-- TAB-1 Prompt_Take (and DT-PC, R3): the talk at the tablet (TabletService). Radius = Restaurant.Rules.TakeRadius
	{ Key = "tablet_take", Text = "Take Order", Hold = 0, Radius = 6, Requires = {}, Night = "Any", Wave = 3 },
	-- CUT-n (Stations.cut): one bun -> bun_sliced stack. Hold = Restaurant.Bun.CutHold (wave 0 of the design)
	{ Key = "bun_slice", Text = "Slice Bun", Hold = 0.6, Radius = 6, Requires = {}, Night = "Any", Wave = 3 },
	-- PLATE-n Prompt_Put: "Add Bun" / "Add Dog" / "Put Plate" by hand (PromptText from PlateService)
	{ Key = "plate_put", Text = "Put Plate", Hold = 0, Radius = 5, Requires = {}, Night = "Any", Wave = 3 },
	-- PLATE-n Prompt_Take: the plate becomes the hot_dog Tool (attribute Ticket); PromptText "Pick Up #12". Conveyor: the
	-- Prompt_Take of a central table slot, held (DEC-302 "hold E"; 0.5 s Provisional, prep-conveyor.md §7.2)
	{ Key = "plate_take", Text = "Take Plate", Hold = 0.5, Radius = 5, Requires = {}, Night = "Any", Wave = 3 },
	-- GRILL-n Att_Slot<n>: flip inside the window (Restaurant.Grill.FlipFrom..FlipTo); the server stamps Grill.Flip
	{ Key = "grill_flip", Text = "Flip", Hold = 0, Radius = 7, Requires = {}, Night = "Any", Wave = 3 },
	-- hot pile next to the grill (Stations.rail): ready dogs -> sausage_grilled stack
	{ Key = "rail_take", Text = "Take Dogs", Hold = 0, Radius = 7, Requires = {}, Night = "Any", Wave = 3 },
	-- PICKUP Prompt_Serve: hand the plate over the counter (CustomerService:ServeAtPickup). Radius = Rules.ServeRadius.
	-- Held (DEC-302; 0.5 s Provisional, prep-conveyor.md §8)
	{ Key = "pickup_serve", Text = "Hand Over", Hold = 0.5, Radius = 7, Requires = {}, Night = "Any", Wave = 3 },
	-- DT-WIN (wave R3): hand the plate out of the drive-thru window
	{ Key = "drive_serve", Text = "Hand Out", Hold = 0, Radius = 6, Requires = {}, Night = "Any", Wave = 4 },
	-- FEAT-050 supply: a StockShelf bay of the stock room always gives a box of its package (infinite, owner 2026-10-17)
	{ Key = "take_box", Text = "Take Box", Hold = 0, Radius = 6, Requires = {}, Night = "Any", Wave = 3 },
} :: { Action })
