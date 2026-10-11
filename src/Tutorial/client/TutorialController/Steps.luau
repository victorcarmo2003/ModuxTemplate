--!strict
-- Steps of the first-hot-dog tutorial (user request 2026-10-11). Texts are PROVISIONAL placeholders in English until
-- narrative-writer puts them in ui-text.md; the prompt names in quotes match Content.Actions texts.
-- Walt leads it on the phone (user request 2026-10-11, Provisional): the first step is answering the tutorial call
-- (BossCalls Trigger Tutorial); from then on each step's Say lines go on the call subtitle and the text-to-speech voice
-- of Walt when the step starts, and Done is his short praise when the player moves past it. The panel keeps the
-- current objective (Text, starting with the verb + Hint) as a short support, under "Step N of M".
-- Tutorial customer (user request 2026-10-11): right after the call is answered one customer comes (shared.Tutorial
-- .Rules: fixed order, no time limit) and the steps follow its order: take the order -> grill -> slice -> collect ->
-- assemble -> toppings -> (open the shop, only if still in Prep) -> serve -> money -> mart.
-- Number = the step shown in the panel ("3/9"); waiting rows share the number of the step they wait for.
-- Action = the prompt the arrow points at (nil = no prompt: waiting, or a talk step).
-- Talk = no world action: the step moves on once Walt has said it (or after TALK_TIME without the call; "Got it").
-- The order of the cooking steps is decided live from the replicated state (TutorialController:Decide), never stored.
-- Say lines are fixed strings (no "{item}"): the voice is generated ahead (Prepare), a live text could not be. The
-- tutorial order is fixed (Rules.Order = ketchup), so Walt names it.

export type Step = {
	Key: string,
	Number: number,
	Text: string, -- panel objective, starts with the verb; "{item}" = the topping name
	Hint: string,
	Action: string?,
	Say: { string }?, -- Walt's lines when the step starts (nil = silent waiting row)
	Done: string?, -- Walt's praise when the player moves past this step
	Talk: boolean?,
}

const TOTAL = 9

const LIST: { Step } = {
	{
		Key = "phone",
		Number = 1,
		Text = "Answer the phone",
		Hint = 'Your boss is calling. Press "Answer" on the cart phone.',
		Action = "answer_phone",
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
		Say = { "Go on, take their order." },
		Done = "Hot dog with ketchup. Easy.",
	},
	{
		Key = "grill",
		Number = 3,
		Text = "Grill a sausage",
		Hint = 'Grab one at the cooler: press "Grill".',
		Action = "grill_place",
		Say = { "Grab a sausage from the cooler.", "It goes right on the grill." },
		Done = "Nice!",
	},
	{
		Key = "slice",
		Number = 4,
		Text = "Slice a bun",
		Hint = 'Hold "Slice Bun" at the bun crate.',
		Action = "bun_cut",
		Say = { "Slice a bun while it cooks." },
		Done = "Good.",
	},
	{ Key = "slicing", Number = 4, Text = "Slicing the bun...", Hint = "Keep holding!", Action = nil },
	{
		Key = "cooking",
		Number = 5,
		Text = "Wait for the sausage",
		Hint = 'It gets a "Collect" button when ready.',
		Action = "grill_collect",
		Say = { "Watch the grill. When the bar fills up, it's ready." },
	},
	{
		Key = "collect",
		Number = 5,
		Text = "Collect the sausage",
		Hint = 'Press "Collect" on the grill.',
		Action = "grill_collect",
		Say = { "It's ready! Grab it off the grill." },
		Done = "Got it!",
	},
	{
		Key = "assemble",
		Number = 6,
		Text = "Put the sausage in the bun",
		Hint = 'Press "Add Sausage" at the board.',
		Action = "board_add_sausage",
		Say = { "Now put the sausage in the bun, on the board." },
		Done = "Beautiful.",
	},
	{
		Key = "toppings",
		Number = 7,
		Text = "Add {item}",
		Hint = 'Hold "Add" at the topping. The order is on the card, top left.',
		Action = "topping_add",
		Say = { "They want ketchup. Go add some.", "Only what they asked. Nothing extra." },
		Done = "Perfect.",
	},
	{
		Key = "discard",
		Number = 7,
		Text = "Throw it away",
		Hint = "That's not what they asked. Hold \"Throw Away\" at the bin, then make a new one.",
		Action = "discard",
		Say = { "Whoa, that's not what they ordered.", "Toss it in the bin and make a new one." },
	},
	{
		Key = "open",
		Number = 8,
		Text = "Open the shop",
		Hint = 'You can\'t sell yet. Press "Open Shop" at the sign.',
		Action = "open_sign",
		Say = { "Flip the sign to open the shop first." },
		Done = "We're open!",
	},
	{
		Key = "serve",
		Number = 8,
		Text = "Serve the hot dog",
		Hint = 'Press "Serve" on the customer.',
		Action = "serve",
		Say = { "That's what they wanted. Now serve it!" },
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
		Key = "mart",
		Number = 9,
		Text = "Restock at the Mart",
		Hint = "Ninth Street Mart, across the street: buy a package, bring it back.",
		Action = nil,
		Say = {
			"Running low on stuff? The Mart's across the street.",
			"Buy a package, bring it back and restock.",
			"Look both ways! These drivers don't brake.",
		},
		Talk = true,
	},
}

-- Talk steps in order after the first sale; the last one ends the tutorial
const TALKS: { string } = { "money", "mart" }

-- Walt when the call is answered (before the first step line)
const GREETING: { string } = { "Morning, Rookie! Walt here.", "I'll stay on the line and walk you through it." }
-- after the last talk step; the server hangs up after BossCallRules.Tutorial.Goodbye s (the click)
const GOODBYE: { string } = { "That's the whole job. You got this, Rookie.", "Call me if..." }
-- the player skipped the tutorial during the call
const SKIP_GOODBYE: { string } = { "Alright, you know your way around.", "I'll let you work. Call me if you need me." }

const ByKey: { [string]: Step } = {}
const IndexOf: { [string]: number } = {}
for index, step in LIST do
	ByKey[step.Key] = step
	IndexOf[step.Key] = index
end

-- Every line Walt may say in the tutorial (the voice is generated ahead with these)
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
	Greeting = table.freeze(GREETING),
	Goodbye = table.freeze(GOODBYE),
	SkipGoodbye = table.freeze(SKIP_GOODBYE),
	Lines = table.freeze(allLines()),
})
