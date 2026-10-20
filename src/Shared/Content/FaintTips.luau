--!strict
-- Faint tips (DEC-317 emenda; design/faint-screen-flow.md §3 etapa D; Provisional, narrative-writer reviews): what made
-- the player faint and how to get past it next time. VitalService sends the cause of the fall (its `LastCause`:
-- "anomaly:<key>", "stare:<key>", "see:<key>", "suspense:<key>", "dark", ...) with `FaintCause`; the client turns it
-- into a card here. An anomaly cause uses its Journal page (Title, first Fight line) unless `Kinds` gives a line of
-- its own; an anomaly the player has not met yet never spoils it (`Unknown`). Any other cause falls to `Generic`.
export type Tip = {
	Title: string,
	Tip: string,
}

export type FaintTips = {
	-- by the prefix of the cause (the part before ":"; the whole cause when it has none)
	Kinds: { [string]: Tip },
	-- anomaly causes: Tip when the anomaly has no Journal page; Title "" = the Journal title
	Anomaly: Tip,
	-- "stare:<key>": the tip (the title is the anomaly's)
	Stare: string,
	Unknown: Tip,
	Generic: Tip,
	Label: string, -- small caption over the title
}

const tips: FaintTips = {
	Kinds = {
		suspense = { Title = "Something was watching", Tip = "Don't look where you hear it breathing." },
		dark = { Title = "The dark got you", Tip = "Stay in the light. Fix the breaker fast." },
	},
	Anomaly = { Title = "", Tip = "Check its page in the Journal before the next night." },
	Stare = "Don't stare. Look away when your heart starts racing.",
	Unknown = { Title = "Something you haven't met yet", Tip = "Keep your eyes open. Not every customer is a customer." },
	Generic = { Title = "Your nerves gave out", Tip = "Drink coffee before your sanity runs low." },
	Label = "WHAT GOT YOU",
}

return table.freeze(tips)
