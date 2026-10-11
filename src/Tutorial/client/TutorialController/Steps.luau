--!strict
-- Steps of the first-hot-dog tutorial (user request 2026-10-11). Texts are PROVISIONAL placeholders in English until
-- narrative-writer puts them in ui-text.md; the prompt names in quotes match Content.Actions texts.
-- Walt leads it on the phone (user request 2026-10-11, Provisional): the first step is answering the tutorial call
-- (BossCalls Trigger Tutorial); from then on each step's Say lines go on the call subtitle and the text-to-speech voice
-- of Walt when the step starts, and Done is his short praise when the player moves past it. The panel keeps the
-- current objective (Text + Hint) as a short support.
-- Number = the step shown in the panel chip ("3/8"); waiting rows share the number of the step they wait for.
-- Action = the prompt the arrow points at (nil = no world target: waiting, or a talk step).
-- Talk = no world action: the step moves on once Walt has said it (or after TALK_TIME without the call; "Got it").
-- The order of the cooking steps is decided live from the replicated state (TutorialController:Decide), never stored.
-- Say lines are fixed strings (no "{item}"): the voice is generated ahead (Prepare), a live text could not be.

export type Step = {
	Key: string,
	Number: number,
	Text: string, -- panel objective; "{item}" = the topping name
	Hint: string,
	Action: string?,
	Say: { string }?, -- Walt's lines when the step starts (nil = silent waiting row)
	Done: string?, -- Walt's praise when the player moves past this step
	Talk: boolean?,
}

const TOTAL = 8

const LIST: { Step } = {
	{
		Key = "phone",
		Number = 1,
		Text = "Answer the phone",
		Hint = 'Your boss is calling. Press "Answer" on the cart phone.',
		Action = "answer_phone",
	},
	{ Key = "wait_call", Number = 1, Text = "Your boss is about to call", Hint = "Stay near the cart.", Action = nil },
	{
		Key = "grill",
		Number = 2,
		Text = "Put a sausage on the grill",
		Hint = 'Go to the cooler and press "Grill".',
		Action = "grill_place",
		Say = { "Start by grabbing a sausage from the cooler.", "Put it right on the grill." },
		Done = "Nice!",
	},
	{
		Key = "slice",
		Number = 3,
		Text = "Slice a bun while it cooks",
		Hint = 'Hold "Slice Bun" at the bun crate.',
		Action = "bun_cut",
		Say = { "Now slice a bun while it cooks." },
		Done = "Good.",
	},
	{ Key = "slicing", Number = 3, Text = "Slicing the bun...", Hint = "Almost there!", Action = nil },
	{
		Key = "cooking",
		Number = 4,
		Text = "Sizzling! Wait for it to cook",
		Hint = 'It gets a "Collect" button when ready.',
		Action = "grill_collect",
		Say = { "Watch the grill. When the bar fills up, it's ready." },
	},
	{
		Key = "collect",
		Number = 4,
		Text = "Cooked! Collect the sausage",
		Hint = 'Press "Collect" on the grill.',
		Action = "grill_collect",
		Say = { "It's ready! Grab the sausage off the grill." },
		Done = "Got it!",
	},
	{
		Key = "assemble",
		Number = 5,
		Text = "Put the sausage in the bun",
		Hint = 'Press "Add Sausage" at the board.',
		Action = "board_add_sausage",
		Say = { "Now put the sausage in the bun, on the board." },
		Done = "Beautiful.",
	},
	{
		Key = "open",
		Number = 6,
		Text = "Hot dog ready! Open the shop",
		Hint = 'Press "Open Shop" at the sign.',
		Action = "open_sign",
		Say = { "That's a hot dog! Now flip the sign to open the shop." },
		Done = "We're open!",
	},
	{
		Key = "wait_customer",
		Number = 6,
		Text = "Wait for your first customer",
		Hint = "They line up at the counter.",
		Action = nil,
		Say = { "Folks line up at the counter. Someone's coming." },
	},
	{
		Key = "order",
		Number = 6,
		Text = "A customer! Take their order",
		Hint = 'Press "Take Order" on them.',
		Action = "take_order",
		Say = { "A customer! Go take their order." },
		Done = "Good.",
	},
	{
		Key = "toppings",
		Number = 7,
		Text = "Add {item}, like they asked",
		Hint = "Their order is on the card, top left.",
		Action = "topping_add",
		Say = { "See the order card? Add the toppings they asked for.", "Only what they asked. Nothing extra." },
		Done = "Perfect.",
	},
	{
		Key = "serve",
		Number = 7,
		Text = "Serve the hot dog!",
		Hint = 'Press "Serve" on the customer.',
		Action = "serve",
		Say = { "That's what they wanted. Now serve it!" },
	},
	{
		Key = "money",
		Number = 8,
		Text = "First sale! Nice work!",
		Hint = "Sales fill the drawer. It's banked into your money at closing.",
		Action = nil,
		Say = { "Ka-ching! Your first sale.", "Money goes in the drawer. It's banked when you close." },
		Talk = true,
	},
	{
		Key = "mart",
		Number = 8,
		Text = "Running low? Restock at the Mart",
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
