--!strict
-- Steps of the first-hot-dog tutorial (user request 2026-10-11). Texts are PROVISIONAL placeholders in English until
-- narrative-writer puts them in ui-text.md; the prompt names in quotes match Content.Actions texts.
-- Number = the step shown in the panel chip ("3/7"); waiting rows share the number of the step they wait for.
-- Action = the prompt the arrow points at (nil = no world target: waiting, or the UI step "money").
-- The order of the cooking steps is decided live from the replicated state (TutorialController:Decide), never stored.

export type Step = {
	Key: string,
	Number: number,
	Text: string, -- "{item}" = the topping name
	Hint: string,
	Action: string?,
}

const TOTAL = 7

const LIST: { Step } = {
	{ Key = "grill", Number = 1, Text = "Put a sausage on the grill", Hint = 'Go to the cooler and press "Grill".', Action = "grill_place" },
	{ Key = "slice", Number = 2, Text = "Slice a bun while it cooks", Hint = 'Press "Slice Bun" at the bun crate.', Action = "bun_cut" },
	{ Key = "slicing", Number = 2, Text = "Slicing the bun...", Hint = "Almost there!", Action = nil },
	{ Key = "cooking", Number = 3, Text = "Sizzling! Wait for it to cook", Hint = 'It gets a "Collect" button when ready.', Action = "grill_collect" },
	{ Key = "collect", Number = 3, Text = "Cooked! Collect the sausage", Hint = 'Press "Collect" on the grill.', Action = "grill_collect" },
	{ Key = "assemble", Number = 4, Text = "Put the sausage in the bun", Hint = 'Press "Add Sausage" at the board.', Action = "board_add_sausage" },
	{ Key = "open", Number = 5, Text = "Hot dog ready! Open the shop", Hint = 'Press "Open Shop" at the sign.', Action = "open_sign" },
	{ Key = "wait_customer", Number = 5, Text = "Wait for your first customer", Hint = "They line up at the counter.", Action = nil },
	{ Key = "order", Number = 5, Text = "A customer! Take their order", Hint = 'Press "Take Order" on them.', Action = "take_order" },
	{ Key = "toppings", Number = 6, Text = "Add {item}, like they asked", Hint = "Their order is on the card, top left.", Action = "topping_add" },
	{ Key = "serve", Number = 6, Text = "Serve the hot dog!", Hint = 'Press "Serve" on the customer.', Action = "serve" },
	{ Key = "money", Number = 7, Text = "First sale! Nice work!", Hint = "Sales fill the drawer. It's banked into your money at closing.", Action = nil },
}

const ByKey: { [string]: Step } = {}
for _, step in LIST do
	ByKey[step.Key] = step
end

return table.freeze({
	Total = TOTAL,
	List = table.freeze(LIST),
	ByKey = table.freeze(ByKey),
})
