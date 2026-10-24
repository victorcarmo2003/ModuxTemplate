--!strict
-- The order talk's words, timing and text styles (Provisional texts, narrative-writer owns them). Owner 2026-10-22 ("tira
-- o botão de refuse... quando ele clicar em take order, ele vai dar aquele close na câmera, vai fazer a animação dele
-- surgindo a anomalia, daí ele vai de fila"): Take Order opens the close-up, the customer says its hi and its order letter
-- by letter (an odd one its odd line / its tic) and the talk ends by itself with the order taken, for every customer. The
-- ACCEPT / REFUSE step of DEC-353 is history. The speech itself is built by Content.OrderSpeech (pure).
--   Kinds      night -> the kinds an odd customer may say that night (one is drawn per customer, seeded by its id)
--   Lines      kind -> lines (English UI, short, Mild)
--   ByVariant  rig Variant -> its own lines instead of the night's kinds
--   Hello      an ordinary customer's first words: it opens the talk, then says its order in the same line
--   Reply      the thanks that closes an ordinary customer's line, by the order it gave (Plain = no topping, Loaded =
--              Loaded+ toppings on a hot dog, Pair = two hot dogs, Any = the rest)
--   CloseUp    the taker's camera on the customer while the talk is on (the tablet in front hidden on that screen). Owner
--              2026-10-21 ("tá muito próximo", sketch): a medium shot, head and shoulders on the right half of the
--              screen, the talk card on the left. Distance studs in front of the head, Lift over it, Drop = the aim
--              below the head (chest in frame), Shift = studs the aim turns to the screen's left (the customer lands
--              right; the lens stays on the face's axis, eye to eye, owner 2026-10-21), field of view, glide s, s it
--              holds after the talk ends (an anomaly's module scares in it once the order is taken)
--   DialogScale the talk card on the left, this much bigger than the HUD scale
--   Speech     Start = s after Take Order the customer starts talking (= the tic's LineStart); Hold = s the whole line
--              stays after its last letter before the talk ends; Min = floor of a talk (s); Stressed = share of the
--              ordinary customers that talk Stressed (by NpcId, the same on every machine); Pair = the lead-in of the 2nd
--              hot dog of a pair; BlipWords = a dialog_blip every this many words. The typing speed and the punctuation
--              pauses are Content.Tics.Rules (TypeRate, PauseStop, PauseComma)
--   Styles     how the letters look on the taker's card (TypedText): Caps = the whole line in capitals; three layers of
--              per-letter effects (Fx below): Fx on every letter always, Tic on the typed letters while the tic plays
--              (the freeze, the beats), Break on the letters past the tic's freeze once it froze. Voice = "You": from
--              the tic's resume the speaker tab reads You (the copy says your line)
--   Fx         Jitter = px each letter trembles around its spot; Wave = px of a sway along the line; Tilt = degrees each
--              letter rocks; Size = px its size wobbles; Grow = px it is bigger (laid out bigger); Swap = share of the
--              neighbour pairs (inside a word) traded at a time, for SwapTime s; Garble = share of the letters shown as a
--              Glitch char at a time; Fade = steady transparency; Flicker = extra transparency, on and off; Rate = how
--              many times a second the tremble, the glitch and the flicker change; Drop = share of the letters (not the
--              punctuation) that drop out of the line for good, one by one over DropTime s from when the layer first
--              acts on each letter (owner 2026-10-22, ANM-001: the line loses letters as the face fades)
--   StyleByVariant  rig Variant -> its style (none = Normal); an ordinary customer is Normal or Stressed
--   Glitch     the chars a garbled letter may show (ASCII: the card's font has no combining marks for a zalgo)
local Table = require(script.Parent.Table)

export type Kind = "Silent" | "Garbled" | "Almost"

export type Fx = {
	Jitter: number?,
	Wave: number?,
	Tilt: number?,
	Size: number?,
	Grow: number?,
	Swap: number?,
	SwapTime: number?,
	Garble: number?,
	Fade: number?,
	Flicker: number?,
	Rate: number?,
	Drop: number?,
	DropTime: number?,
}

export type Style = {
	Caps: boolean?,
	Fx: Fx?,
	Tic: Fx?,
	Break: Fx?,
	Voice: "You"?,
}

export type Speech = {
	Start: number,
	Hold: number,
	Min: number,
	Stressed: number,
	Pair: { string },
	BlipWords: number,
}

export type OrderTalk = {
	Kinds: { { Kind } },
	Lines: { [Kind]: { string } },
	ByVariant: { [string]: { string } },
	Hello: { string },
	Reply: { Plain: { string }, Loaded: { string }, Pair: { string }, Any: { string } },
	Loaded: number,
	CloseUp: { Distance: number, Lift: number, Drop: number, Shift: number, Fov: number, Travel: number, Hold: number },
	DialogScale: number,
	Speech: Speech,
	Styles: { [string]: Style },
	StyleByVariant: { [string]: string },
	Glitch: string,
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
		-- ANM-011 (owner 2026-10-22, Provisional): his order is a bun alone (OrderRules.BreadOnly)
		shake = { "B-bread. Just bread. Nothing in it.", "Only bread... please. Nothing else.", "J-just the bread. Hurry." },
	},
	Hello = { "Hi!", "Evening!", "Hey there.", "Hello!", "Hi, how's it going?" },
	-- Provisional texts (narrative-writer owns them)
	Reply = {
		Plain = { "Just like that. Thanks!", "Simple is best. Thank you!", "Perfect, nothing fancy." },
		Loaded = { "Yes! Pile it on. Thanks!", "Loaded, just how I like it.", "Don't skip anything, okay? Thanks!" },
		Pair = { "Two, yeah. One's for my friend. Thanks!", "Both of them, please. You're the best!" },
		Any = { "Great, thanks!", "Awesome. I'll wait right here.", "Thanks! Smells amazing already.", "Sweet, thank you!" },
	},
	Loaded = 3,
	CloseUp = { Distance = 6.5, Lift = 0, Drop = 0.2, Shift = 0.9, Fov = 45, Travel = 0.45, Hold = 1.2 },
	DialogScale = 1.35,
	-- owner 2026-10-22, Provisional
	Speech = {
		Start = 0.5, -- the close-up glides in CloseUp.Travel (0.45 s)
		Hold = 0.9,
		Min = 1.5,
		Stressed = 0.2,
		Pair = { "And one more:", "Plus another one:" },
		BlipWords = 2,
	},
	-- owner 2026-10-22 ("a letra vai variar de acordo com o tipo de pessoa"), Provisional numbers
	Styles = {
		Normal = {},
		-- "clientes estressados vem em caps lock": capitals. Owner 2026-10-22: an ordinary customer's line is one plain label
		-- (TypedText single mode, even spacing), so no shiver here (was Fx = { Jitter = 0.7, Rate = 24 })
		Stressed = { Caps = true },
		-- ANM-011 the shaker: every letter shakes and sways and trades places with its neighbour now and then
		Shake = { Fx = { Jitter = 1.6, Wave = 1.4, Tilt = 9, Swap = 0.22, SwapTime = 0.16, Rate = 16 } },
		-- ANM-012 the turned neck: normal until the freeze; the typed letters shudder with the cracks; what comes out after
		-- it is disfigured (glitch letters, size and place trembling, letters traded)
		Neck = {
			Tic = { Jitter = 1.2, Rate = 30 },
			Break = { Jitter = 2.6, Tilt = 22, Size = 5, Swap = 0.3, SwapTime = 0.1, Garble = 0.5, Flicker = 0.35, Rate = 20 },
		},
		-- ANM-013 the white eyes: the letters flicker in the glare while the eyes open; the rest comes out washed out
		Eyes = {
			Tic = { Flicker = 0.75, Rate = 12 },
			Break = { Fade = 0.4, Flicker = 0.2, Jitter = 0.4, Rate = 10 },
		},
		-- ANM-014 the big head: the letters swell with the creaks; the rest of the line comes out big and slow-swaying
		Big = {
			Tic = { Size = 3, Rate = 5 },
			Break = { Grow = 6, Wave = 1, Rate = 3 },
		},
		-- ANM-004 the copy: the original's hi types normal; after the pause your own hi comes out in a wavering echo and
		-- the speaker tab reads You
		Mirror = {
			Break = { Wave = 1.2, Fade = 0.15, Flicker = 0.15, Rate = 6 },
			Voice = "You",
		},
		-- ANM-001 the blank folks (owner 2026-10-22): normal until the freeze; while its face fades the typed letters drop
		-- out one by one (over the tic's 1.5 s hold) and flicker; the rest comes out faint, losing letters as it types
		Blank = {
			Tic = { Drop = 0.8, DropTime = 1.5, Flicker = 0.3, Rate = 10 },
			Break = { Drop = 0.5, DropTime = 0.35, Fade = 0.3, Flicker = 0.2, Rate = 8 },
		},
	},
	StyleByVariant = {
		blank = "Blank",
		shake = "Shake",
		neck = "Neck",
		eyes = "Eyes",
		bighead = "Big",
		mirror = "Mirror",
	},
	Glitch = "#%&@$*?!/|<>~^=+XZKQW",
}

return Table.record(talk)
