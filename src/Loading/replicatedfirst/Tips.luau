--!strict
-- Loading screen texts (Loading/Boot, LoadingController). In ReplicatedFirst so the first frame of the join has them.
-- PROVISIONAL (frontend-coder 2026-10-11): placeholder copy until narrative-writer covers the loading screen in
-- ui-text.md. Original lines only.

return table.freeze({
	Title = "SELL HOTDOGS",
	Tagline = "Work hard. Stay alert.",
	Tips = table.freeze({
		"A short line is a happy line. Grill ahead when the street gets busy.",
		"An empty cooler sells nothing. Restock at the Mart before you run out.",
		"Clean tables bring tips. Dirty tables bring nobody.",
		"Never leave the drawer alone for long. Somebody is always watching it.",
		"Mustard goes on the dog. Not on the customer.",
		"Something looks off at night? Trust your eyes and follow the rules.",
		"Upgrades pay for themselves. A faster grill means more dogs per hour.",
		"Work as a crew: one grills, one serves, one keeps an eye on the street.",
	}),
	-- steps of LoadingController (and the boot before it)
	Status = table.freeze({
		Boot = "Unfolding the umbrella...",
		Game = "Rolling the cart to the corner...",
		Kit = "Waking up the crew...",
		Assets = "Warming the grill...",
		Voices = "Rehearsing the phone call...",
		Crew = "Waiting for the rest of the crew...",
		Done = "Open for business!",
	}),
})
