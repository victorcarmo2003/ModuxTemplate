--!strict
-- Steps of the first-hot-dog tutorial (user request 2026-10-11). Texts are PROVISIONAL placeholders in English until
-- narrative-writer puts them in ui-text.md; the prompt names in quotes match Content.Actions texts.
-- Walt leads it on the phone (user request 2026-10-11, Provisional): the first step is answering the tutorial call
-- (BossCalls Trigger Tutorial); from then on each step's Say lines go on the call subtitle and the text-to-speech voice
-- of Walt when the step starts, and Done is his short praise when the player moves past it. The panel keeps the
-- current objective (Text, starting with the verb + Hint) as a short support, under "Step N of M".
-- Owner request 2026-10-12: after the call the player OPENS THE TRAILER (red switch on its wall; opening the trailer
-- opens the shop, there is no sign to flip) and only then does the tutorial customer come.
-- Tutorial customer (user request 2026-10-11): once the shop is open one customer comes (shared.Tutorial
-- .Rules: fixed order, no time limit) and the steps follow its order: take the order -> grill -> slice -> collect ->
-- assemble -> toppings -> serve -> money -> shopping.
-- Shopping (user request 2026-10-11, Provisional): the tutorial run starts with ONE bun (server, TutorialService), so
-- the first sale empties the crate; Walt sends the rookie to the Mart: mart_go (arrow to the Mart door) -> mart_buy
-- (the BAKERY shelf, "Buy Buns") -> mart_back (the pack in hand, back to the cart) -> restock (hold "Restock" at the
-- bun crate) -> goodbye. When the buns did not run out (a party with a veteran: no tutorial stock), the old talk step
-- "mart" stands in for the four.
-- Number = the step shown in the panel ("3/14"); waiting rows share the number of the step they wait for.
-- Action = the prompt the arrow points at (nil = no prompt: waiting, or a talk step).
-- Remind = the short nudge after IDLE s without progress (TutorialController), voiced like Say (generated ahead).
-- Talk = no world action: the step moves on once Walt has said it (or after TALK_TIME without the call; "Got it").
-- The order of the cooking steps is decided live from the replicated state (TutorialController:Decide), never stored.
-- Say lines are fixed strings (no "{item}"): the voice is generated ahead (Prepare), a live text could not be. The
-- tutorial orders are fixed (Rules.Orders: plain, then ketchup and mustard; DEC-311), so Walt names them.
-- Punctuation of the Say / Done / greeting lines shapes Walt's voice (Speech speaks sentence by sentence: a pause after
-- . ? ! and a longer one after "..."); fewer "!" = a calmer tone (user feedback 2026-10-11: "too shouted").
-- Owner 2026-10-23 (recorded his own voice for Walt, tools/voice/edits.json): the restaurant rows say his lines, longer and
-- chattier; the second tutorial order says SayAgain ("do the same thing as before": mostly silent); the trailer and Mart
-- rows (never shown in the restaurant) lost their voice lines. Texts are what he recorded: a line changed here loses its
-- audio (the voice key is the text) until it is recorded again.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TutorialRules = require(ReplicatedStorage.shared.Tutorial.Rules)

export type Step = {
	Key: string,
	Number: number,
	Text: string, -- panel objective, starts with the verb; "{item}" = the topping name
	Hint: string,
	-- Hint while the kitchen is the focused prep mode (Content.Prep.Rules.WorldKitchenPrompts = false): the world prompts
	-- of the kitchen are gone, the step is done at a station (shim until the tutorial is rewritten, TASK-183/184)
	PrepHint: string?,
	-- Hint while the tutorial customer is a drive-thru car (owner 2026-10-20: the 2nd customer); no voiced reminder then
	DriveHint: string?,
	Action: string?,
	Say: { string }?, -- Walt's lines when the step starts (nil = silent waiting row)
	-- Walt's lines on the second tutorial order instead of Say (owner 2026-10-23: the ketchup order is "the same thing as
	-- before"); nil = Say, {} = silent
	SayAgain: { string }?,
	Done: string?, -- Walt's praise when the player moves past this step
	-- Short reminder (<= 42 chars, a subtitle line) when the player made no progress on the step for a while
	-- (TutorialController IDLE): Walt says it, the panel hint shows it and the arrow pulses harder. nil = no reminder
	-- (waiting rows, talk steps)
	Remind: string?,
	Talk: boolean?,
	-- Day 1 upgrade lesson step (owner request 2026-10-14): numbered on its own ("STEP 1 OF 2", LessonTotal)
	Lesson: boolean?,
	-- restaurant-only row (TASK-393): dropped from the list when TutorialRules.Restaurant is off (the trailer tutorial
	-- keeps its exact rows, indices and voice lines)
	Restaurant: boolean?,
}

-- 2026-10-17 cut: the tutorial ends on the first sale (7 numbered steps); 11 with the Day 1 shopping lesson back on.
-- Restaurant (TASK-393; DEC-311 adds "step back"): 9 to the last sale, 11 with the restock steps (design/tutorial-restaurant.md §2)
const TOTAL = if TutorialRules.Restaurant
	then (if TutorialRules.Restock then 11 else 9)
	elseif TutorialRules.Shopping then 11
	else 7
-- Day 1 upgrade lesson (owner request 2026-10-14, Provisional): when the first shift ends Walt calls (BossCalls
-- call_tutorial_upgrade, his lines are the call's own) and these two steps lead the rookie to the Gear Stand to buy
-- the Bun Box (shared.Tutorial.Rules.Upgrade); the Gear Stand was closed until then (Content.Mart.FirstShiftClosed).
-- Owner 2026-10-21 (Provisional): a third step then sends the rookie back to open the window (the shop) for the night
const LESSON_TOTAL = 3

const LIST: { Step } = {
	{
		Key = "phone",
		Number = 1,
		Text = "Answer the phone",
		Hint = 'Your boss is calling. Press "Answer" on the trailer phone.',
		Action = "answer_phone",
	},
	{
		Key = "wait_call",
		Number = 1,
		Text = "Wait for the call",
		Hint = "Your boss is about to call. Stay near the phone.",
		Action = nil,
	},
	-- Owner request 2026-10-12: phone -> open the trailer -> the customer comes. TASK-284 (2026-10-14): the red switch is
	-- gone; the service window lever next to the phone opens the window and the shop at once. Same step in Prep whatever
	-- the hand holds.
	{
		Key = "open",
		Number = 2,
		Text = "Open the window",
		Hint = "Pull the window lever next to the phone.",
		Action = "shutter_toggle",
		Say = { "Do you see that lever? Go there and pull it to open the store." },
		Remind = "Pull the window lever.",
	},
	{
		Key = "wait_customer",
		Number = 3,
		Text = "Wait for your first customer",
		Hint = "They're walking up to the counter.",
		Action = nil,
		-- owner 2026-10-23: said once the lever is pulled (a Done of "open" would be dropped while the lever line still talks)
		Say = { "Nice. Here it comes, your first client." },
		SayAgain = {},
	},
	{
		Key = "order",
		Number = 3,
		Text = "Take the order",
		Hint = 'Press "Take Order" on the customer.',
		Action = "take_order",
	},
	-- Day 1 cut (owner decision 2026-10-17, Provisional): in the focused prep mode the kitchen is ONE step, "make the hot
	-- dog" at a station; the mode's own coach paw walks through grill -> bun -> sausage (the world-prompt steps below
	-- stay for the world kitchen)
	{
		Key = "cook",
		Number = 4,
		Text = "Make the hot dog",
		Hint = 'Press "Work" at a station and follow the paw.',
		Action = nil, -- the focused prep left (TASK-581); the step is never chosen
	},
	{
		Key = "grill",
		Number = 4,
		Text = "Grill a sausage",
		Hint = 'Grab one at the cooler: press "Grill".',
		PrepHint = 'Press "Work" at a station, then add a sausage on the Grill tab.',
		Action = "grill_place",
	},
	{
		Key = "slice",
		Number = 4,
		Text = "Slice a bun",
		Hint = 'Hold "Slice Bun" at the bun crate.',
		PrepHint = 'Press "Work" at a station. On the Build tab, drag the knife along the line.',
		Action = "bun_cut",
	},
	{
		Key = "slicing",
		Number = 4,
		Text = "Slicing the bun...",
		Hint = "Keep holding!",
		PrepHint = "Build the hot dog: sausage, ketchup, then Next.",
		Action = nil,
	},
	{
		Key = "cooking",
		Number = 4,
		Text = "Wait for the sausage",
		Hint = 'It gets a "Collect" button when ready.',
		PrepHint = "The bar stops when one side is done: tap the sausage to flip it, then it is ready in a couple of seconds.",
		Action = "grill_collect",
	},
	{
		Key = "collect",
		Number = 4,
		Text = "Collect the sausage",
		Hint = 'Press "Collect" on the grill.',
		PrepHint = 'Press "Work" at a station, then "Collect" on the Grill tab.',
		Action = "grill_collect",
	},
	{
		Key = "assemble",
		Number = 4,
		Text = "Put the sausage in the bun",
		Hint = 'Press "Add Sausage" at the rest rail.',
		PrepHint = 'Press "Work" at a station. On the Build tab, drag the sausage onto the bun.',
		Action = "plate_add_sausage",
	},
	{
		Key = "toppings",
		Number = 5,
		Text = "Add {item}",
		Hint = 'Hold "Add" at the topping. The order is on the card, top left.',
		-- TASK-258: seated with the bun and sausage on the plate, the order's topping goes on in the Toppings view
		PrepHint = "On the Toppings view, put it on the hot dog.",
		Action = "topping_add",
	},
	{
		Key = "discard",
		Number = 5,
		Text = "Throw it away",
		Hint = "That's not what they asked. Hold \"Throw Away\" at the bin, then make a new one.",
		Action = "discard",
	},
	-- TASK-254 (owner request 2026-10-14): the 3D prep delivery by drag, the plate onto the green DELIVER area of the customer
	{
		Key = "deliver",
		Number = 6,
		Text = "Serve the hot dog",
		-- TASK-258: only once the order's toppings are on the plate (TutorialController:MissingTopping)
		Hint = "Drag the plate onto the customer.",
		Action = nil,
	},
	{
		Key = "serve",
		Number = 6,
		Text = "Serve the hot dog",
		Hint = 'Press "Serve" on the customer.',
		Action = "serve",
	},
	-- Restaurant loop (TASK-393; design/tutorial-restaurant.md §2, Provisional texts until narrative-writer): only with
	-- TutorialRules.Restaurant (Content.Restaurant.Rules.Enabled). Order of the rows = flow order (Walt's praise only
	-- goes to the next row, HudReveal reveals by index: every row sits after "order", before "money").
	{
		Key = "r_tablet",
		Restaurant = true,
		Number = 3,
		Text = "Take the order",
		Hint = 'Press "Take Order" at the tablet.',
		DriveHint = 'A car at the drive-thru! Press "Take Order" on it.',
		Action = "tablet_take",
		Say = { "Take his order." },
		Remind = "What are you doing? I don't have the whole night. Take his order.",
	},
	-- owner 2026-10-22: Take Order opens the close-up and the customer says its order letter by letter; the talk ends by
	-- itself (the ACCEPT step of DEC-353 and its r_accept row are gone)
	{
		Key = "r_listen",
		Restaurant = true,
		Number = 3,
		Text = "Listen to the order",
		Hint = "It goes on your note, top left.",
		Action = nil,
		Say = {},
	},
	-- DEC-311 (owner 2026-10-19): fry -> cut -> leave the focus -> plate of this order -> bun -> sausage (-> sauces) -> serve
	{
		Key = "r_grill",
		Restaurant = true,
		Number = 4,
		Text = "Fry a sausage",
		Hint = 'Press "Grill" at the grill, then drag a sausage from the box onto the grill.',
		Action = "cook_focus",
		-- owner 2026-10-23: "Drag it to the grill." cut
		Say = { "Plain dog. Go to the grill.", "Take the sausage from the cooler." },
		SayAgain = { "This one wants ketchup, so just do the same thing as before for now." },
	},
	{
		Key = "r_cooking",
		Restaurant = true,
		Number = 4,
		Text = "Wait for the sausage",
		Hint = "It stops at half: then flip it.",
		Action = nil,
		Say = {},
	},
	{
		Key = "r_flip",
		Restaurant = true,
		Number = 4,
		Text = "Flip the sausage",
		Hint = "Tap when the white bar is in the green.",
		Action = nil, -- inside the grill focus: the flip mini-game
		Say = { "Now flip it." },
		SayAgain = {},
		Done = "Good.",
	},
	{
		Key = "r_collect",
		Restaurant = true,
		Number = 4,
		Text = "Send it to the rest rail",
		Hint = "Drag the ready sausage onto the rest rail (or tap it).",
		Action = nil, -- inside the grill focus (DEC-310)
		Say = { "Now take it and put it aside." },
		SayAgain = {},
	},
	{
		Key = "r_cut",
		Restaurant = true,
		Number = 5,
		Text = "Cut a bun",
		Hint = 'Press "Cut Bun" at the cutting board, then swipe across the bun.',
		Action = "cook_focus",
		Say = { "Now go to the cutting board and cut some bread." },
		SayAgain = {},
		Done = "Good.",
	},
	{
		Key = "r_leave",
		Restaurant = true,
		Number = 5,
		Text = "Step back",
		Hint = 'Press "Back" (or walk away).',
		Action = nil, -- the focus HUD pulses its Back button (CookBackHint)
		Say = {},
	},
	{
		Key = "r_take_plate",
		Restaurant = true,
		Number = 6,
		Text = "Take the plate of the order",
		Hint = 'Press "Take Plate" on the plate with their ticket.',
		Action = "plate_take",
		Say = { "Take his plate at the countertop." },
		SayAgain = {},
	},
	{
		Key = "r_bun_plate",
		Restaurant = true,
		Number = 6,
		Text = "Put the bun on the plate",
		Hint = 'Press "Add Bun" at the cut-bun crate.',
		Action = "plate_add_bun",
		Say = { "Now, take the bread" },
		SayAgain = {},
		Done = "Good.",
	},
	{
		Key = "r_rail",
		Restaurant = true,
		Number = 6,
		Text = "Take the sausage",
		Hint = 'Press "Add Sausage" at the rest rail.',
		Action = nil, -- kept for the step ids (Metrics); r_dog_plate is the live one
		Say = {},
	},
	{
		Key = "r_dog_plate",
		Restaurant = true,
		Number = 6,
		Text = "Put the sausage in the bun",
		Hint = 'Press "Add Sausage" at the rest rail.',
		Action = "plate_add_sausage",
		Say = { "Take the sausage now." },
		SayAgain = {},
	},
	{
		Key = "r_toppings",
		Restaurant = true,
		Number = 7,
		Text = "Add {item}",
		Hint = 'Press "Toppings", tap the lit {item}, then squeeze it along the arrows.',
		Action = "cook_focus",
		Say = { "Now go to the toppings table and put the ketchup." },
		Remind = "Rookie, just take the sauce.",
	},
	{
		Key = "r_discard",
		Restaurant = true,
		Number = 7,
		Text = "Throw it away",
		Hint = "That's not what they asked. Hold \"Throw Away\" at the bin.",
		Action = "discard",
		Say = { "This is not what he asked. What are you doing? No, just toss it." },
		Remind = "In the bin, Rookie.",
	},
	{
		Key = "r_pickup",
		Restaurant = true,
		Number = 8,
		Text = "Hand it over",
		Hint = 'Press "Hand Over" at the pickup counter.',
		DriveHint = 'Press "Serve" on the car at the drive-thru window.',
		Action = "pickup_serve",
		Say = { "This is a plain dog. Deliver it to the customer." },
		SayAgain = { "Well, it looks good. Just take it to the customer." },
	},
	-- co-op: a crewmate holds the hot dog (no plate in progress, own hand empty)
	{
		Key = "r_crew",
		Restaurant = true,
		Number = 8,
		Text = "Your crew has the plate",
		Hint = "They'll hand it over at pickup.",
		Action = nil,
	},
	{
		Key = "money",
		Number = if TutorialRules.Restaurant then 9 else 7,
		Text = "First sale! Nice work!",
		-- owner 2026-10-22: the tip jar left, tips go straight to the money too
		Hint = "Sales and tips go straight to the shared money.",
		Action = nil,
		Say = { "Your first sale, huh? Good." },
		Talk = true,
	},
	{
		Key = "mart_go",
		Number = 8,
		Text = "Go to the Mart",
		Hint = "Ninth Street Mart, across the street. Look both ways!",
		Action = nil,
	},
	{
		Key = "mart_buy",
		Number = 9,
		Text = "Buy a pack of buns",
		Hint = 'Hold "Buy Buns" at the BAKERY shelf.',
		Action = "buy_package",
	},
	{
		Key = "mart_back",
		Number = 10,
		Text = "Bring it back",
		Hint = "Carry the pack back to your trailer.",
		Action = nil,
	},
	{
		Key = "restock",
		Number = 11,
		Text = "Restock the buns",
		Hint = 'Hold "Restock" at the bun crate.',
		Action = "restock",
	},
	-- Restaurant restock (TASK-393, TutorialRules.Restock; owner 2026-10-17: infinite stock room, no phone order): a box
	-- from a product bay (StockShelf) of the stock room -> Restock at the station of its ingredient
	{
		Key = "r_box",
		Restaurant = true,
		Number = 10,
		Text = "Take a box",
		Hint = 'Go to the stock room. Press "Take" at a shelf.',
		Action = "take_box",
		Say = { "If you run out of ingredients, take it in the back." },
	},
	{
		Key = "r_restock",
		Restaurant = true,
		Number = 11,
		Text = "Restock the station",
		Hint = 'Hold "Restock" where it goes.',
		Action = "restock",
		Say = {},
	},
	-- stands in for the four shopping steps when the buns did not run out (no tutorial stock)
	{
		Key = "mart",
		Number = 8,
		Text = "Restock at the Mart",
		Hint = "Ninth Street Mart, across the street: buy a package, bring it back.",
		Action = nil,
		Talk = true,
	},
	-- TASK-598 (owner request 2026-10-19, Provisional): Walt's last talk step, before the goodbye: the shift ends at six
	-- (6 PM by day, 6:00 AM by night: the line says "six"). While he says it the screen goes dark around the HUD clock
	-- (TutorialController:ShiftTalk)
	{
		Key = "shift",
		Number = TOTAL,
		Text = "Your shift ends at 6:00",
		Hint = "Keep an eye on the clock, top centre.",
		Action = nil,
		-- owner 2026-10-21: the close-up on the clock lasted too long; "One more thing." cut (the other two keep their voices)
		Say = { "Your shift ends at six." },
		Talk = true,
	},
}

const LESSON: { Step } = {
	{
		Key = "upg_go",
		Number = 1,
		Lesson = true,
		Text = "Go to the Gear Stand",
		-- restaurant (TASK-393): the stand is inside the shop (Q-321)
		Hint = if TutorialRules.Restaurant
			then "In the back of the shop."
			else "At the Mart, across the street. Look both ways!",
		Action = nil,
		-- TASK-650 (DEC-368): the script's "PRONTAS PARA GRAVAR" caption, word for word (the voice id comes from it)
		Remind = "Six A.M. Shift's over. Gear Stand, in the back. Find something useful.",
	},
	{
		Key = "upg_buy",
		Number = 2,
		Lesson = true,
		-- owner 2026-10-21: any upgrade of the Gear Stand, the rookie picks (was "Buy the Bun Box")
		Text = "Buy an upgrade",
		Hint = 'Pick any upgrade on the Gear Stand and hold "Buy".',
		Action = "bench_buy_upgrade",
		Remind = "You can choose something. I'm gonna pay for it.",
	},
	{
		Key = "upg_open",
		Number = 3,
		Lesson = true,
		Text = "Open the window",
		Hint = "Back to the window lever: open the store for the night.",
		Action = "shutter_toggle",
		Remind = "Pull the window lever.",
	},
}
if not TutorialRules.Restaurant then
	for index = #LIST, 1, -1 do
		if LIST[index].Restaurant then
			table.remove(LIST, index)
		end
	end
end
for _, step in LESSON do
	table.insert(LIST, step)
end

-- Talk steps in order after the first sale; the last one ends the tutorial. After "money" the controller goes to the
-- shopping steps instead of "mart" when the buns ran out (TutorialController:NextTalk). "shift" (TASK-598) is not in the
-- list: every end of the tutorial goes through it (TutorialController:ShiftTalk), then the goodbye.
const TALKS: { string } = { "money", "mart" }
-- Shopping steps (decided live from the hand, the bun stock and where the player stands)
const SHOPPING: { string } = { "mart_go", "mart_buy", "mart_back", "restock" }

-- TutorialPromptGate (PromptController filter, presentation only): prompts shown during a step = the step's own Action +
-- the actions of the next step(s) listed here (so a player who gets ahead is never locked out) + ALWAYS. Waiting steps
-- release nothing extra. Server stays authoritative.
-- prep_work (Prompt_Work of Station_n, focused prep mode): the kitchen steps are done at a station, so the prompt is
-- never gated (it only exists in the selling phases anyway: Content.Actions Requires.Phase).
-- trailer_exit / trailer_enter: the back door is never gated (the tutorial must not lock the player in or out of the trailer)
-- pick_up_item: an item dropped by a car hit must always be recoverable, whatever the step (owner bug 2026-10-16)
-- read_hints: Walt's notes on the counter (owner 2026-10-22: the paper must always open, tutorial or not)
const ALWAYS: { string } = { "answer_phone", "pick_up_item", "read_hints" }
-- Restaurant (TASK-393): from the tablet on, the whole restaurant kitchen shows (a crewmate helping or a player getting
-- ahead is never locked out; the steps follow the shared state, design/tutorial-restaurant.md §4)
const KITCHEN: { string } = {
	"tablet_take",
	"cook_focus",
	"bun_cut",
	"plate_take",
	"plate_add_bun",
	"plate_add_sausage",
	"grill_place",
	"grill_flip",
	"grill_collect",
	"topping_add",
	"discard",
	"pickup_serve",
	-- owner 2026-10-20: the 2nd tutorial customer is a drive-thru car, ordered and served on its own prompt
	"take_order",
	"serve",
}
-- restock steps: the stock room bays and the stations
const RESTOCK: { string } = { "take_box", "restock" }
const NEXT_ACTIONS: { [string]: { string } } = {
	phone = { "shutter_toggle" },
	wait_call = { "shutter_toggle" }, -- 2026-10-17: never lock the window behind a late phone
	open = { "take_order" },
	wait_customer = { "take_order" },
	order = { "grill_place" },
	cook = { "serve" },
	grill = { "bun_cut", "grill_collect" },
	slice = { "grill_collect", "grill_place" },
	slicing = { "grill_collect" },
	cooking = { "plate_add_sausage" },
	collect = { "plate_add_sausage", "bun_cut" },
	assemble = { "topping_add" },
	toppings = { "serve" },
	discard = { "grill_place", "plate_add_sausage" },
	serve = {},
	deliver = { "serve" },
	money = { "buy_package" },
	mart_go = { "buy_package" },
	mart_buy = { "restock" },
	mart_back = { "restock" },
	restock = {},
	mart = { "buy_package", "restock" },
	upg_go = { "bench_buy_upgrade" },
	upg_buy = {},
	shift = KITCHEN, -- a few seconds of talk: the kitchen stays usable
	r_tablet = KITCHEN,
	r_leave = KITCHEN,
	r_listen = KITCHEN,
	r_cut = KITCHEN,
	r_bun_plate = KITCHEN,
	r_grill = KITCHEN,
	r_cooking = KITCHEN,
	r_flip = KITCHEN,
	r_collect = KITCHEN,
	r_rail = KITCHEN,
	r_dog_plate = KITCHEN,
	r_take_plate = KITCHEN,
	r_toppings = KITCHEN,
	r_discard = KITCHEN,
	r_pickup = KITCHEN,
	r_crew = KITCHEN,
	r_box = RESTOCK,
	r_restock = RESTOCK,
}
-- Restaurant: the tablet already shows while the window opens, the restock steps follow the first sale
if TutorialRules.Restaurant then
	NEXT_ACTIONS.open = { "take_order", "tablet_take" }
	NEXT_ACTIONS.wait_customer = { "take_order", "tablet_take" }
	NEXT_ACTIONS.money = RESTOCK
end

-- Walt when the call is answered (before the first step line)
const GREETING: { string } = {
	"Hello, Rookie! My name is Walt. I've noticed that you're new here, so I'm gonna walk you through this.",
}
-- after the last talk step; the server hangs up after BossCallRules.Tutorial.Goodbye s (the click)
const GOODBYE: { string } = { "That's your job. Call me if you need me." }
-- the player skipped the tutorial during the call
const SKIP_GOODBYE: { string } = { "That's your job. Call me if you need me." }

const ByKey: { [string]: Step } = {}
const IndexOf: { [string]: number } = {}
for index, step in LIST do
	ByKey[step.Key] = step
	IndexOf[step.Key] = index
end

-- Every line Walt may say in the tutorial (the voice is generated ahead with these), in the order the call needs
-- them: greeting, each step's Say + Done in flow order, the goodbye, then the reminders and the skip goodbye (the
-- loading screen preloads from the top, the rest keeps loading in the background)
-- Restaurant (TASK-393): the trailer kitchen and Mart rows never show there, so their lines are not generated ahead
const TRAILER_ONLY: { [string]: boolean } = {}
if TutorialRules.Restaurant then
	for _, key in
		{ "cook", "grill", "slice", "slicing", "cooking", "collect", "assemble", "toppings", "discard", "deliver", "serve" }
	do
		TRAILER_ONLY[key] = true
	end
	for _, key in { "mart_go", "mart_buy", "mart_back", "restock", "mart" } do
		TRAILER_ONLY[key] = true
	end
end
local function allLines(): { string }
	const out: { string } = {}
	const seen: { [string]: boolean } = {}
	local function add(text: string)
		if not seen[text] then
			seen[text] = true
			table.insert(out, text)
		end
	end
	for _, text in GREETING do
		add(text)
	end
	for _, step in LIST do
		if TRAILER_ONLY[step.Key] then
			continue
		end
		for _, text in step.Say or {} do
			add(text)
		end
		for _, text in step.SayAgain or {} do
			add(text)
		end
		if step.Done then
			add(step.Done)
		end
	end
	for _, text in GOODBYE do
		add(text)
	end
	for _, step in LIST do
		if step.Remind and not TRAILER_ONLY[step.Key] then
			add(step.Remind)
		end
	end
	for _, text in SKIP_GOODBYE do
		add(text)
	end
	return out
end

return table.freeze({
	Total = TOTAL,
	LessonTotal = LESSON_TOTAL,
	List = table.freeze(LIST),
	ByKey = table.freeze(ByKey),
	IndexOf = table.freeze(IndexOf),
	Talks = table.freeze(TALKS),
	Shopping = table.freeze(SHOPPING),
	AlwaysActions = table.freeze(ALWAYS),
	NextActions = table.freeze(NEXT_ACTIONS),
	Greeting = table.freeze(GREETING),
	Goodbye = table.freeze(GOODBYE),
	SkipGoodbye = table.freeze(SKIP_GOODBYE),
	Lines = table.freeze(allLines()),
})
