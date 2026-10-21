--!strict
-- The order talk's choice (owner 2026-10-21, DEC-353; design/gameplay-flow-review.md §3d; Provisional texts, narrative-writer
-- owns them). After the tablet talk the customer has said its line; the player who took it picks SERVE (the order is
-- taken) or REFUSE (only that customer leaves). An anomaly customer (rig attribute Variant, CustomerService SpawnActor)
-- never says a normal order: by night it goes silent, garbled or "almost normal" (Kinds); the Raincoat Lady says something
-- warm on purpose (she is served). One rule for the player: it looked or sounded wrong? Refuse.
--   Kinds      night -> the kinds an odd customer may say that night (one is drawn per customer, seeded by its id)
--   Lines      kind -> lines (English UI, short, Mild)
--   ByVariant  rig Variant -> its own lines instead of the night's kinds
--   Hello      an ordinary customer's answer to the greeting (the order comes only after ACCEPT, 2nd pass 2026-10-21)
--   CloseUp    the taker's camera on the customer's face while the talk is on (the tablet in front hidden on that
--              screen): studs in front of the head, lift, field of view, glide s, s it holds after the talk ends
--   DialogScale the talk card on the left, this much bigger than the HUD scale
-- A refused ordinary customer walks off with one of Content.ShopWindow.ShutLines over its head (no scare, only the sale).
local Table = require(script.Parent.Table)

export type Kind = "Silent" | "Garbled" | "Almost"

export type OrderTalk = {
	Kinds: { { Kind } },
	Lines: { [Kind]: { string } },
	ByVariant: { [string]: { string } },
	Hello: { string },
	CloseUp: { Distance: number, Lift: number, Fov: number, Travel: number, Hold: number },
	DialogScale: number,
	Serve: string,
	Refuse: string,
}

const talk: OrderTalk = {
	-- N1-3 obvious, N2-6 garbled, N6-10 subtle (owner 2026-10-21)
	Kinds = {
		{ "Silent" },
		{ "Silent", "Garbled" },
		{ "Silent", "Garbled" },
		{ "Garbled" },
		{ "Garbled" },
		{ "Garbled", "Almost" },
		{ "Almost" },
		{ "Almost" },
		{ "Almost" },
		{ "Almost" },
	},
	Lines = {
		Silent = { "...", ". . . . .", "..." },
		Garbled = {
			"H-h-hot... d-dog... f-for... me",
			"Wh... what is... a... hot dog",
			"Hungry. Hungry. Hungrrrry.",
			"I w-want... the... the... the...",
			"Onnne... onne... hot... d0g",
		},
		Almost = {
			"One hot dog. With your teeth.",
			"Same as last time.",
			"Do you remember my face?",
			"I'll wait. I always wait.",
			"Make it warm. Like you.",
			"One for me. One for the one behind you.",
		},
	},
	ByVariant = {
		raincoat = { "Something warm, dear. I've waited so long.", "Just a hot dog, love. Take your time." },
	},
	Hello = { "Hi!", "Evening!", "Hey there.", "Hello!", "Hi, how's it going?" },
	CloseUp = { Distance = 2.4, Lift = 0.15, Fov = 50, Travel = 0.45, Hold = 1.2 },
	DialogScale = 1.35,
	Serve = "ACCEPT",
	Refuse = "REFUSE",
}

return Table.record(talk)
