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
-- tutorial order is fixed (Rules.Order = ketchup), so Walt names it.
-- Punctuation of the Say / Done / greeting lines shapes Walt's voice (Speech speaks sentence by sentence: a pause after
-- . ? ! and a longer one after "..."); fewer "!" = a calmer tone (user feedback 2026-10-11: "too shouted").

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
	Action: string?,
	Say: { string }?, -- Walt's lines when the step starts (nil = silent waiting row)
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
-- Restaurant (TASK-393): 8 to the first sale, 10 with the restock steps (design/tutorial-restaurant.md §2)
const TOTAL = if TutorialRules.Restaurant
	then (if TutorialRules.Restock then 10 else 8)
	elseif TutorialRules.Shopping then 11
	else 7
-- Day 1 upgrade lesson (owner request 2026-10-14, Provisional): when the first shift ends Walt calls (BossCalls
-- call_tutorial_upgrade, his lines are the call's own) and these two steps lead the rookie to the Gear Stand to buy
-- Storage (shared.Tutorial.Rules.Upgrade); the Gear Stand was closed until then (Content.Mart.FirstShiftClosed)
const LESSON_TOTAL = 2

const LIST: { Step } = {
	{
		Key = "phone",
		Number = 1,
		Text = "Answer the phone",
		Hint = 'Your boss is calling. Press "Answer" on the trailer phone.',
		Action = "answer_phone",
		Remind = "Pick up the phone.",
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
		Say = { "Open the window.", "Lever by the phone." },
		Done = "We're open.",
		Remind = "Pull the window lever.",
	},
	{
		Key = "wait_customer",
		Number = 3,
		Text = "Wait for your first customer",
		Hint = "They're walking up to the counter.",
		Action = nil,
		Say = { "Your first customer's coming." },
	},
	{
		Key = "order",
		Number = 3,
		Text = "Take the order",
		Hint = 'Press "Take Order" on the customer.',
		Action = "take_order",
		Say = { "Take their order." },
		Done = "A ketchup dog. Easy.",
		Remind = "Take the order, Rookie.",
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
		Say = { "Now make the hot dog.", "Take a station. Follow the paw." },
		Done = "Beautiful.",
		Remind = "Press Work at a station.",
	},
	{
		Key = "grill",
		Number = 4,
		Text = "Grill a sausage",
		Hint = 'Grab one at the cooler: press "Grill".',
		PrepHint = 'Press "Work" at a station, then add a sausage on the Grill tab.',
		Action = "grill_place",
		Say = { "Frank from the cooler.", "Onto the grill." },
		Done = "Nice.",
		Remind = "Frank on the grill.",
	},
	{
		Key = "slice",
		Number = 4,
		Text = "Slice a bun",
		Hint = 'Hold "Slice Bun" at the bun crate.',
		PrepHint = 'Press "Work" at a station. On the Build tab, drag the knife along the line.',
		Action = "bun_cut",
		Say = { "Slice a bun while it cooks." },
		Done = "Good.",
		Remind = "Hold to slice the bun.",
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
		Say = { "Wait for the bar." },
	},
	{
		Key = "collect",
		Number = 4,
		Text = "Collect the sausage",
		Hint = 'Press "Collect" on the grill.',
		PrepHint = 'Press "Work" at a station, then "Collect" on the Grill tab.',
		Action = "grill_collect",
		Say = { "Ready. Grab it." },
		Done = "Got it.",
		Remind = "Grab it off the grill.",
	},
	{
		Key = "assemble",
		Number = 4,
		Text = "Put the sausage in the bun",
		Hint = 'Press "Add Sausage" at the rest rail.',
		PrepHint = 'Press "Work" at a station. On the Build tab, drag the sausage onto the bun.',
		Action = "plate_add_sausage",
		Say = { "Frank in the bun." },
		Done = "Beautiful.",
		Remind = "Put it in the bun.",
	},
	{
		Key = "toppings",
		Number = 5,
		Text = "Add {item}",
		Hint = 'Hold "Add" at the topping. The order is on the card, top left.',
		-- TASK-258: seated with the bun and sausage on the plate, the order's topping goes on in the Toppings view
		PrepHint = "On the Toppings view, put it on the hot dog.",
		Action = "topping_add",
		Say = { "They want ketchup.", "Nothing extra." },
		Done = "Perfect.",
		Remind = "Ketchup on the dog, Rookie.",
	},
	{
		Key = "discard",
		Number = 5,
		Text = "Throw it away",
		Hint = "That's not what they asked. Hold \"Throw Away\" at the bin, then make a new one.",
		Action = "discard",
		Say = { "Not what they asked. Toss it." },
		Remind = "Toss it in the bin.",
	},
	-- TASK-254 (owner request 2026-10-14): the 3D prep delivery by drag, the plate onto the green DELIVER area of the customer
	{
		Key = "deliver",
		Number = 6,
		Text = "Serve the hot dog",
		-- TASK-258: only once the order's toppings are on the plate (TutorialController:MissingTopping)
		Hint = "Drag the plate onto the customer.",
		Action = nil,
		Say = { "Looks right.", "Drag the plate to them." },
		Remind = "Drag the plate to the customer.",
	},
	{
		Key = "serve",
		Number = 6,
		Text = "Serve the hot dog",
		Hint = 'Press "Serve" on the customer.',
		Action = "serve",
		Say = { "Now serve it." },
		Remind = "Hand it over.",
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
		Action = "tablet_take",
		Say = { "Take their order at the tablet." },
		Remind = "Tap the tablet, Rookie.",
	},
	{
		Key = "r_listen",
		Restaurant = true,
		Number = 3,
		Text = "Listen to the order",
		Hint = "It goes on your note, top left.",
		Action = nil,
		Say = { "Listen. It's on your note." },
		Done = "A ketchup dog. Easy.",
	},
	{
		Key = "r_cut",
		Restaurant = true,
		Number = 4,
		Text = "Slice a bun",
		Hint = 'Hold "Slice Bun" at the bun crate.',
		Action = "bun_cut",
		Say = { "Slice a bun at the board." },
		Done = "Good.",
		Remind = "Hold to slice the bun.",
	},
	{
		Key = "r_bun_plate",
		Restaurant = true,
		Number = 4,
		Text = "Put the bun on a plate",
		Hint = 'Press "Add Bun" at the cut buns.',
		Action = "plate_add_bun",
		Say = { "Bun on the plate." },
		Done = "Nice.",
		Remind = "Bun on a plate.",
	},
	{
		Key = "r_grill",
		Restaurant = true,
		Number = 5,
		Text = "Grill a sausage",
		Hint = 'Press "Grill" at the sausage box.',
		Action = "grill_place",
		Say = { "Frank on the grill." },
		Remind = "Frank on the grill.",
	},
	{
		Key = "r_cooking",
		Restaurant = true,
		Number = 5,
		Text = "Wait for the sausage",
		Hint = "Halfway, it needs a flip.",
		Action = nil,
		Say = { "Wait for the bar." },
	},
	{
		Key = "r_flip",
		Restaurant = true,
		Number = 5,
		Text = "Flip the sausage",
		Hint = 'Press "Flip" on the grill.',
		Action = "grill_flip",
		Say = { "Flip it." },
		Done = "Nice flip.",
		Remind = "Flip it now.",
	},
	{
		Key = "r_collect",
		Restaurant = true,
		Number = 5,
		Text = "Collect the sausage",
		Hint = 'Press "Collect" on the grill.',
		Action = "grill_collect",
		Say = { "Done. Off the grill." },
		Remind = "Grab it off the grill.",
	},
	{
		Key = "r_rail",
		Restaurant = true,
		Number = 5,
		Text = "Take the sausage",
		Hint = 'Press "Take Dogs" at the hot pile.',
		Action = nil, -- the hot pile left (TASK-581): the sausage goes onto the plate (r_dog_plate)
		Say = { "Grab the dog." },
		Remind = "Take it from the pile.",
	},
	{
		Key = "r_dog_plate",
		Restaurant = true,
		Number = 5,
		Text = "Put the sausage on the plate",
		Hint = 'Press "Add Sausage" at the rest rail.',
		Action = "plate_add_sausage",
		Say = { "Dog on the plate." },
		Done = "Beautiful.",
		Remind = "Dog on the plate.",
	},
	{
		Key = "r_take_plate",
		Restaurant = true,
		Number = 6,
		Text = "Pick up the plate",
		Hint = 'Press "Take Plate" at the plate stack.',
		Action = "plate_take",
		Say = { "Pick up the plate." },
		Remind = "Take the plate.",
	},
	{
		Key = "r_toppings",
		Restaurant = true,
		Number = 6,
		Text = "Add {item}",
		Hint = 'Hold "Add" at the topping. The order is on your note.',
		Action = "topping_add",
		Say = { "They want ketchup.", "Nothing extra." },
		Done = "Perfect.",
		Remind = "Ketchup on the dog, Rookie.",
	},
	{
		Key = "r_discard",
		Restaurant = true,
		Number = 6,
		Text = "Throw it away",
		Hint = "That's not what they asked. Hold \"Throw Away\" at the bin.",
		Action = "discard",
		Say = { "Not what they asked. Toss it." },
		Remind = "Toss it in the bin.",
	},
	{
		Key = "r_pickup",
		Restaurant = true,
		Number = 7,
		Text = "Hand it over",
		Hint = 'Press "Hand Over" at the pickup counter.',
		Action = "pickup_serve",
		Say = { "Hand it over at pickup." },
		Remind = "Pickup counter. Hand it over.",
	},
	-- co-op: a crewmate holds the hot dog (no plate in progress, own hand empty)
	{
		Key = "r_crew",
		Restaurant = true,
		Number = 7,
		Text = "Your crew has the plate",
		Hint = "They'll hand it over at pickup.",
		Action = nil,
	},
	{
		Key = "money",
		Number = if TutorialRules.Restaurant then 8 else 7,
		Text = "First sale! Nice work!",
		Hint = "Sales go straight to the shared money. Tips pile up in the jar.",
		Action = nil,
		Say = { "Ka-ching! First sale.", "Cash goes in the drawer." },
		Talk = true,
	},
	{
		Key = "mart_go",
		Number = 8,
		Text = "Go to the Mart",
		Hint = "Ninth Street Mart, across the street. Look both ways!",
		Action = nil,
		Say = {
			"That was your last bun.",
			"Mart's across the street.",
			"Look both ways.",
		},
		Done = "That's the place.",
		Remind = "Follow the arrow to the Mart.",
	},
	{
		Key = "mart_buy",
		Number = 9,
		Text = "Buy a pack of buns",
		Hint = 'Hold "Buy Buns" at the BAKERY shelf.',
		Action = "buy_package",
		Say = { "Grab buns at the bakery." },
		Done = "Eight buns. That'll do.",
		Remind = "Bakery shelf. Hold Buy Buns.",
	},
	{
		Key = "mart_back",
		Number = 10,
		Text = "Bring it back",
		Hint = "Carry the pack back to your trailer.",
		Action = nil,
		Say = { "Bring them to the trailer." },
		Remind = "Back to the trailer.",
	},
	{
		Key = "restock",
		Number = 11,
		Text = "Restock the buns",
		Hint = 'Hold "Restock" at the bun crate.',
		Action = "restock",
		Say = { "Hold Restock on the bun crate." },
		Done = "Stocked up!",
		Remind = "Hold Restock at the bun crate.",
	},
	-- Restaurant restock (TASK-393, TutorialRules.Restock; owner 2026-10-17: infinite stock room, no phone order): a box
	-- from a product bay (StockShelf) of the stock room -> Restock at the station of its ingredient
	{
		Key = "r_box",
		Restaurant = true,
		Number = 9,
		Text = "Take a box",
		Hint = 'Go to the stock room. Press "Take" at a shelf.',
		Action = "take_box",
		Say = { "Running low? Hit the stock room.", "Grab a box." },
		Done = "Got it.",
		Remind = "Take a box off the shelf.",
	},
	{
		Key = "r_restock",
		Restaurant = true,
		Number = 10,
		Text = "Restock the station",
		Hint = 'Hold "Restock" where it goes.',
		Action = "restock",
		Say = { "Take it to its station.", "Hold Restock." },
		Done = "Stocked up!",
		Remind = "Hold Restock at the station.",
	},
	-- stands in for the four shopping steps when the buns did not run out (no tutorial stock)
	{
		Key = "mart",
		Number = 8,
		Text = "Restock at the Mart",
		Hint = "Ninth Street Mart, across the street: buy a package, bring it back.",
		Action = nil,
		Say = {
			"Low on stuff? Try the Mart.",
			"Look both ways.",
		},
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
		Remind = if TutorialRules.Restaurant then "Follow the arrow to the Gear Stand." else "Follow the arrow to the Mart.",
	},
	{
		Key = "upg_buy",
		Number = 2,
		Lesson = true,
		Text = "Buy Storage",
		Hint = 'Hold "Buy" at the Storage stand: more buns, more sauce.',
		Action = "bench_buy_upgrade",
		Remind = "Hold Buy at Storage.",
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
-- shopping steps instead of "mart" when the buns ran out (TutorialController:NextTalk).
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
const ALWAYS: { string } = { "answer_phone", "pick_up_item" }
-- Restaurant (TASK-393): from the tablet on, the whole restaurant kitchen shows (a crewmate helping or a player getting
-- ahead is never locked out; the steps follow the shared state, design/tutorial-restaurant.md §4)
const KITCHEN: { string } = {
	"tablet_take",
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
	r_tablet = KITCHEN,
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
const GREETING: { string } = { "Morning, Rookie. Walt here.", "I'll walk you through it." }
-- after the last talk step; the server hangs up after BossCallRules.Tutorial.Goodbye s (the click)
const GOODBYE: { string } = { "That's the job. You got this.", "Call me if..." }
-- the player skipped the tutorial during the call
const SKIP_GOODBYE: { string } = { "Alright. You know the drill.", "Call me if you need me." }

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
