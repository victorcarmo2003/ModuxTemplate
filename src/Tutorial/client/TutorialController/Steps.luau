--!strict
-- Steps of the first-hot-dog tutorial (user request 2026-10-11). Texts are PROVISIONAL placeholders in English until
-- narrative-writer puts them in ui-text.md; the prompt names in quotes match Content.Actions texts.
-- Walt leads it on the phone (user request 2026-10-11, Provisional): the first step is answering the tutorial call
-- (BossCalls Trigger Tutorial); from then on each step's Say lines go on the call subtitle and the text-to-speech voice
-- of Walt when the step starts, and Done is his short praise when the player moves past it. The panel keeps the
-- current objective (Text, starting with the verb + Hint) as a short support, under "Step N of M".
-- Tutorial customer (user request 2026-10-11): right after the call is answered one customer comes (shared.Tutorial
-- .Rules: fixed order, no time limit) and the steps follow its order: take the order -> grill -> slice -> collect ->
-- assemble -> toppings -> (open the shop, only if still in Prep) -> serve -> money -> shopping.
-- Shopping (user request 2026-10-11, Provisional): the tutorial run starts with ONE bun (server, TutorialService), so
-- the first sale empties the crate; Walt sends the rookie to the Mart: mart_go (arrow to the Mart door) -> mart_buy
-- (the BAKERY shelf, "Buy Buns") -> mart_back (the pack in hand, back to the cart) -> restock (hold "Restock" at the
-- bun crate) -> goodbye. When the buns did not run out (a party with a veteran: no tutorial stock), the old talk step
-- "mart" stands in for the four.
-- Number = the step shown in the panel ("3/13"); waiting rows share the number of the step they wait for.
-- Action = the prompt the arrow points at (nil = no prompt: waiting, or a talk step).
-- Remind = the short nudge after IDLE s without progress (TutorialController), voiced like Say (generated ahead).
-- Talk = no world action: the step moves on once Walt has said it (or after TALK_TIME without the call; "Got it").
-- The order of the cooking steps is decided live from the replicated state (TutorialController:Decide), never stored.
-- Say lines are fixed strings (no "{item}"): the voice is generated ahead (Prepare), a live text could not be. The
-- tutorial order is fixed (Rules.Order = ketchup), so Walt names it.
-- Punctuation of the Say / Done / greeting lines shapes Walt's voice (Speech speaks sentence by sentence: a pause after
-- . ? ! and a longer one after "..."); fewer "!" = a calmer tone (user feedback 2026-10-11: "too shouted").

export type Step = {
	Key: string,
	Number: number,
	Text: string, -- panel objective, starts with the verb; "{item}" = the topping name
	Hint: string,
	Action: string?,
	Say: { string }?, -- Walt's lines when the step starts (nil = silent waiting row)
	Done: string?, -- Walt's praise when the player moves past this step
	-- Short reminder (<= 42 chars, a subtitle line) when the player made no progress on the step for a while
	-- (TutorialController IDLE): Walt says it, the panel hint shows it and the arrow pulses harder. nil = no reminder
	-- (waiting rows, talk steps)
	Remind: string?,
	Talk: boolean?,
	-- the screen-sized arrow over the target shows at any distance (not only from far away); the OPEN sign (playtest
	-- 2026-10-11: up close the player did not see which piece to press)
	AlwaysArrow: boolean?,
}

const TOTAL = 13

const LIST: { Step } = {
	{
		Key = "phone",
		Number = 1,
		Text = "Answer the phone",
		Hint = 'Your boss is calling. Press "Answer" on the cart phone.',
		Action = "answer_phone",
		Remind = "The phone's ringing! Press Answer.",
	},
	{
		Key = "wait_call",
		Number = 1,
		Text = "Wait for the call",
		Hint = "Your boss is about to call. Stay near the cart.",
		Action = nil,
	},
	{
		Key = "wait_customer",
		Number = 2,
		Text = "Wait for your first customer",
		Hint = "They're walking up to the counter.",
		Action = nil,
		Say = { "Here comes your first customer.", "Let 'em walk up to the counter." },
	},
	{
		Key = "order",
		Number = 2,
		Text = "Take the order",
		Hint = 'Press "Take Order" on the customer.',
		Action = "take_order",
		Say = { "Go on... take their order." },
		Done = "Hot dog with ketchup... Easy.",
		Remind = "They're waiting. Take the order!",
	},
	{
		Key = "grill",
		Number = 3,
		Text = "Grill a sausage",
		Hint = 'Grab one at the cooler: press "Grill".',
		Action = "grill_place",
		Say = { "Grab a sausage from the cooler.", "It goes right on the grill." },
		Done = "Nice.",
		Remind = "Sausage on the grill. Follow the arrow.",
	},
	{
		Key = "slice",
		Number = 4,
		Text = "Slice a bun",
		Hint = 'Hold "Slice Bun" at the bun crate.',
		Action = "bun_cut",
		Say = { "Slice a bun while it cooks." },
		Done = "Good.",
		Remind = "Hold Slice Bun at the bun crate.",
	},
	{ Key = "slicing", Number = 4, Text = "Slicing the bun...", Hint = "Keep holding!", Action = nil },
	{
		Key = "cooking",
		Number = 5,
		Text = "Wait for the sausage",
		Hint = 'It gets a "Collect" button when ready.',
		Action = "grill_collect",
		Say = { "Watch the grill. When the bar fills up... it's ready." },
	},
	{
		Key = "collect",
		Number = 5,
		Text = "Collect the sausage",
		Hint = 'Press "Collect" on the grill.',
		Action = "grill_collect",
		Say = { "It's ready. Grab it off the grill." },
		Done = "Got it.",
		Remind = "It's ready! Collect it off the grill.",
	},
	{
		Key = "assemble",
		Number = 6,
		Text = "Put the sausage in the bun",
		Hint = 'Press "Add Sausage" at the board.',
		Action = "board_add_sausage",
		Say = { "Now put the sausage in the bun, on the board." },
		Done = "Beautiful.",
		Remind = "Sausage in the bun, at the board.",
	},
	{
		Key = "toppings",
		Number = 7,
		Text = "Add {item}",
		Hint = 'Hold "Add" at the topping. The order is on the card, top left.',
		Action = "topping_add",
		Say = { "They want ketchup. Go add some.", "Only what they asked... nothing extra." },
		Done = "Perfect.",
		Remind = "Ketchup! Hold Add at the ketchup.",
	},
	{
		Key = "discard",
		Number = 7,
		Text = "Throw it away",
		Hint = "That's not what they asked. Hold \"Throw Away\" at the bin, then make a new one.",
		Action = "discard",
		Say = { "Whoa... that's not what they ordered.", "Toss it in the bin and make a new one." },
		Remind = "Toss it. Hold Throw Away at the bin.",
	},
	{
		Key = "open",
		Number = 8,
		Text = "Open the shop",
		Hint = 'You can\'t sell yet. Press "Open Shop" at the sign.',
		Action = "open_sign",
		Say = { "Flip the sign to open the shop first." },
		Done = "We're open.",
		AlwaysArrow = true,
		Remind = "Shop's closed! Press Open Shop at the sign.",
	},
	{
		Key = "serve",
		Number = 8,
		Text = "Serve the hot dog",
		Hint = 'Press "Serve" on the customer.',
		Action = "serve",
		Say = { "That's what they wanted. Now serve it." },
		Remind = "Hand it over. Press Serve on them.",
	},
	{
		Key = "money",
		Number = 9,
		Text = "First sale! Nice work!",
		Hint = "Sales fill the drawer. It's banked into your money at closing.",
		Action = nil,
		Say = { "Ka-ching! Your first sale.", "Money goes in the drawer. It's banked when you close." },
		Talk = true,
	},
	{
		Key = "mart_go",
		Number = 10,
		Text = "Go to the Mart",
		Hint = "Ninth Street Mart, across the street. Look both ways!",
		Action = nil,
		Say = {
			"Uh-oh... that was your last bun.",
			"Head to the Mart, across the street.",
			"Look both ways... These drivers don't brake.",
		},
		Done = "That's the place.",
		Remind = "Mart's across the street. Follow the arrow.",
	},
	{
		Key = "mart_buy",
		Number = 11,
		Text = "Buy a pack of buns",
		Hint = 'Hold "Buy Buns" at the BAKERY shelf.',
		Action = "buy_package",
		Say = { "Bakery shelf. Grab a pack of buns." },
		Done = "Eight buns. That'll do.",
		Remind = "Bakery shelf. Hold Buy Buns.",
	},
	{
		Key = "mart_back",
		Number = 12,
		Text = "Bring it back",
		Hint = "Carry the pack back to your cart.",
		Action = nil,
		Say = { "Now bring 'em back to the cart." },
		Remind = "Bring the buns back to the cart.",
	},
	{
		Key = "restock",
		Number = 13,
		Text = "Restock the buns",
		Hint = 'Hold "Restock" at the bun crate.',
		Action = "restock",
		Say = { "Hold Restock on the bun crate." },
		Done = "Stocked up!",
		Remind = "Hold Restock at the bun crate.",
	},
	-- stands in for the four shopping steps when the buns did not run out (no tutorial stock)
	{
		Key = "mart",
		Number = 10,
		Text = "Restock at the Mart",
		Hint = "Ninth Street Mart, across the street: buy a package, bring it back.",
		Action = nil,
		Say = {
			"Running low on stuff? The Mart's across the street.",
			"Buy a package, bring it back and restock.",
			"Look both ways... These drivers don't brake.",
		},
		Talk = true,
	},
}

-- Talk steps in order after the first sale; the last one ends the tutorial. After "money" the controller goes to the
-- shopping steps instead of "mart" when the buns ran out (TutorialController:NextTalk).
const TALKS: { string } = { "money", "mart" }
-- Shopping steps (decided live from the hand, the bun stock and where the player stands)
const SHOPPING: { string } = { "mart_go", "mart_buy", "mart_back", "restock" }

-- Walt when the call is answered (before the first step line)
const GREETING: { string } = { "Morning, Rookie. Walt here.", "I'll stay on the line... and walk you through it." }
-- after the last talk step; the server hangs up after BossCallRules.Tutorial.Goodbye s (the click)
const GOODBYE: { string } = { "That's the whole job... You got this, Rookie.", "Call me if..." }
-- the player skipped the tutorial during the call
const SKIP_GOODBYE: { string } = { "Alright... you know your way around.", "I'll let you work. Call me if you need me." }

const ByKey: { [string]: Step } = {}
const IndexOf: { [string]: number } = {}
for index, step in LIST do
	ByKey[step.Key] = step
	IndexOf[step.Key] = index
end

-- Every line Walt may say in the tutorial (the voice is generated ahead with these), in the order the call needs
-- them: greeting, each step's Say + Done in flow order, the goodbye, then the reminders and the skip goodbye (the
-- loading screen preloads from the top, the rest keeps loading in the background)
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
		if step.Remind then
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
	List = table.freeze(LIST),
	ByKey = table.freeze(ByKey),
	IndexOf = table.freeze(IndexOf),
	Talks = table.freeze(TALKS),
	Shopping = table.freeze(SHOPPING),
	Greeting = table.freeze(GREETING),
	Goodbye = table.freeze(GOODBYE),
	SkipGoodbye = table.freeze(SKIP_GOODBYE),
	Lines = table.freeze(allLines()),
})
