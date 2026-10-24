--!strict
-- The customer's speech in the order talk, typed letter by letter (owner 2026-10-22: Take Order opens the close-up, the
-- customer says its hi and its order, an odd one its line / its tic, and the talk ends by itself with the order taken;
-- the ACCEPT / REFUSE step of DEC-353 is history). Pure: read by TabletService (how long the talk lasts, EndsAt) and by
-- TabletController (the card, the balloons, the sounds), from the same record and the same server clock, so they agree
-- without a packet.
--   Build(input)   the speech of one talk. An ordinary customer says, in one line, its hi (OrderTalk.Hello), the opening
--                  (Restaurant.Dialog.Opening), the bun, the dog and the toppings (Dialog.Ask; a pair adds
--                  OrderTalk.Speech.Pair and the 2nd hot dog) and a thanks that fits the order (OrderTalk.Reply); each
--                  item's icon pops once the words naming it are typed. An odd customer says its odd line
--                  (OrderTalk.ByVariant, else one of the night's Kinds); one with a Content.Tics row says the tic's line
--                  on the tic's clock (it types, freezes, the beats, it resumes) when its tic plays in this talk, the
--                  residue line after it. An odd line names nothing: its icons pop spread over the line (the owner: they
--                  show normal even with the text disfigured)
--   At(speech, t)  what is said t s after Take Order: chars typed, the phase (Line, Tic = frozen while the tic plays,
--                  After = resumed), the sound caption (the tic's, from its peak to the resume), items revealed, words begun
--   Plain(speech, typed)  the typed part as plain text for the balloons (capitals; a Garble break shown as glitch chars)
--   StyleOf(variant, npc)  the text style key: by Variant (OrderTalk.StyleByVariant), else Stressed for a share of the
--                  ordinary customers (OrderTalk.Speech.Stressed, by NpcId: the same on every machine), else Normal
-- Times: the line starts OrderTalk.Speech.Start s after Take Order (= the tic's LineStart, rig TicAt); it types at
-- Tics.Rules.TypeRate with the punctuation pauses (Tics.TypeTime); the talk ends Speech.Hold s after the last letter
-- (floor Speech.Min) and the order is taken then, for every customer.
local Orders = require(script.Parent.Orders)
local Ingredients = require(script.Parent.Ingredients)
local OrderTalk = require(script.Parent.OrderTalk)
local Restaurant = require(script.Parent.Restaurant)
local Tics = require(script.Parent.Tics)

export type Phase = "Line" | "Tic" | "After"

export type Input = {
	Npc: number,
	Variant: string?, -- rig Variant of an odd customer; nil / "" = ordinary
	Night: number, -- picks the odd kinds (OrderTalk.Kinds)
	Order: { [string]: boolean }, -- toppings of the 1st hot dog
	Order2: { [string]: boolean }?, -- the 2nd hot dog of a pair
	Tic: Tics.Tic?, -- the row whose tic plays in this talk
	Said: Tics.Said?, -- its line in this talk (the echo's depends on the original and the taker)
	Residue: boolean?, -- the row's tic is done (the residue line)
}

export type Speech = {
	Text: string,
	Items: { string }, -- ingredient keys in the order they pop (bun, sausage, toppings; then the 2nd hot dog)
	ItemAt: { number }, -- chars typed when item i pops
	WordAt: { number }, -- char where each word begins
	Style: string, -- OrderTalk.Styles key
	Tic: Tics.Tic?,
	Timing: Tics.Timing?,
	Break: number?, -- chars before the tic's freeze (Style.Break applies past it)
	Start: number, -- s from Take Order the line starts
	Spoken: number, -- s from Start the last letter shows
	Duration: number, -- s from Take Order the talk ends (the order is taken)
}

export type At = { Typed: number, Phase: Phase, Caption: string?, Reveal: number, Words: number }

const TALK = OrderTalk
const DIALOG = Restaurant.Dialog
const SPEECH = OrderTalk.Speech
const HASH = 2654435761 -- Knuth's multiplicative hash: exact in a double for any NpcId (16 bits)
const HASH_SPAN = 4294967296

-- Deterministic pick (the same formula as before and as Tics): every machine chooses the same line for the same customer
local function pick(list: { string }?, npc: number, salt: number): string
	if list == nil or #list == 0 then
		return ""
	end
	return list[(npc + salt) % #list + 1]
end

-- bun, sausage, then the toppings in ToppingKeys order (capped at OrderRules.MaxToppings)
local function itemsOf(order: { [string]: boolean }?): { string }
	const list: { string } = { "bun", "sausage" }
	if order == nil then
		return list
	end
	local toppings = 0
	for _, key in Ingredients.ToppingKeys do
		if order[key] then
			table.insert(list, key)
			toppings += 1
			if toppings >= Orders.Rules.MaxToppings then
				break
			end
		end
	end
	return list
end

-- The odd customer's line: its Variant's own lines, else one of the night's kinds, the same pick on every machine
local function oddLine(variant: string, npc: number, night: number): string
	const own = TALK.ByVariant[variant]
	if own ~= nil then
		return pick(own, npc, 1)
	end
	const kinds = TALK.Kinds[math.clamp(night, 1, #TALK.Kinds)]
	const kind = kinds[npc % #kinds + 1]
	return pick(TALK.Lines[kind], npc, 1)
end

-- The thanks that fits the order (owner 2026-10-21, 3rd pass)
local function replyLine(order: { [string]: boolean }, pair: boolean, npc: number): string
	const reply = TALK.Reply
	if pair then
		return pick(reply.Pair, npc, 3)
	end
	local toppings = 0
	for _, on in order do
		if on then
			toppings += 1
		end
	end
	const list = if toppings == 0 then reply.Plain elseif toppings >= TALK.Loaded then reply.Loaded else reply.Any
	return pick(list, npc, 3)
end

local function share(npc: number): number
	return ((math.abs(npc) * HASH) % HASH_SPAN) / HASH_SPAN
end

local function styleOf(variant: string?, npc: number): string
	if variant ~= nil and variant ~= "" then
		const key = TALK.StyleByVariant[variant]
		return if key ~= nil and TALK.Styles[key] ~= nil then key else "Normal"
	end
	return if share(npc) < SPEECH.Stressed then "Stressed" else "Normal"
end

local function ends(text: string): boolean
	const last = string.sub(text, -1)
	return last == "." or last == "!" or last == "?"
end

-- An ordinary customer's line: hi, the order, the thanks. Returns the text, the items and where each one pops
local function ordinary(input: Input): (string, { string }, { number })
	const npc = input.Npc
	const items: { string } = {}
	const itemAt: { number } = {}
	local text = pick(TALK.Hello, npc, 1)
	local function add(piece: string, gap: string)
		if piece == "" then
			return
		end
		text = if text == "" then piece else text .. gap .. piece
	end
	add(pick(DIALOG.Opening, npc, 1), " ")
	local function dog(order: { [string]: boolean }?, lead: string?)
		if lead ~= nil then
			add(lead, " ")
		end
		const list = itemsOf(order)
		const toppings = #list - 2
		for index, key in list do
			table.insert(items, key)
			const said = pick(DIALOG.Ask[key], npc, #items)
			const phrase = if said ~= "" then said else (string.gsub(key, "_", " "))
			-- "a bun... ...with a dog, ketchup, mustard and cheese."
			local gap = " "
			if index > 2 then
				gap = if index == #list and toppings > 1 then " and " else ", "
			end
			add(phrase, gap)
			table.insert(itemAt, #text)
		end
		if not ends(text) then
			text ..= "."
		end
	end
	dog(input.Order, nil)
	const pair = input.Order2 ~= nil
	if pair then
		dog(input.Order2, pick(SPEECH.Pair, npc, 2))
	end
	add(replyLine(input.Order, pair, npc), " ")
	return text, items, itemAt
end

local function wordsOf(text: string): { number }
	const out: { number } = {}
	local previous = " "
	for index = 1, #text do
		const char = string.sub(text, index, index)
		if char ~= " " and char ~= "\n" and (previous == " " or previous == "\n") then
			table.insert(out, index)
		end
		previous = char
	end
	return out
end

local function build(input: Input): Speech
	const npc = input.Npc
	const variant = input.Variant or ""
	local text: string
	local items: { string }
	local itemAt: { number } = {}
	local tic: Tics.Tic? = nil
	local timing: Tics.Timing? = nil
	local breakAt: number? = nil
	if variant == "" then
		text, items, itemAt = ordinary(input)
	else
		const row = Tics.ByVariant[variant]
		if row ~= nil and input.Tic == row then
			const said = input.Said or Tics.Said(row)
			text = said.Text
			tic = row
			timing = Tics.Timing(row, said)
			breakAt = (timing :: Tics.Timing).Chars
		elseif row ~= nil then
			text = if input.Residue then row.Line.Residue else row.Line.Text
		else
			text = oddLine(variant, npc, input.Night)
		end
		-- its order still shows under the line (owner 2026-10-22), spread over it; a bread-only order is the bun alone
		items = if Orders.Rules.BreadOnly[variant] then { "bun" } else itemsOf(input.Order)
		if input.Order2 ~= nil then
			for _, key in itemsOf(input.Order2) do
				table.insert(items, key)
			end
		end
		for index = 1, #items do
			table.insert(itemAt, math.max(1, math.ceil(#text * index / #items)))
		end
	end
	const spoken = if timing ~= nil then timing.End else Tics.TypeTime(text, 0, #text)
	return {
		Text = text,
		Items = items,
		ItemAt = itemAt,
		WordAt = wordsOf(text),
		Style = styleOf(variant, npc),
		Tic = tic,
		Timing = timing,
		Break = breakAt,
		Start = SPEECH.Start,
		Spoken = spoken,
		Duration = math.max(SPEECH.Start + spoken + SPEECH.Hold, SPEECH.Min),
	}
end

local function count(marks: { number }, typed: number): number
	local n = 0
	for _, mark in marks do
		if mark > typed then
			break
		end
		n += 1
	end
	return n
end

local function at(speech: Speech, elapsed: number): At
	const t = elapsed - speech.Start
	const text = speech.Text
	local typed = 0
	local phase: Phase = "Line"
	local caption: string? = nil
	const timing = speech.Timing
	const tic = speech.Tic
	if t <= 0 then
		typed = 0
	elseif timing ~= nil and tic ~= nil then
		if t < timing.Freeze then
			typed = Tics.TypedAt(text, 0, t)
		elseif t < timing.Resume then
			typed = timing.Chars
			phase = "Tic"
			if tic.Caption ~= nil and t >= timing.Peak then
				caption = tic.Caption
			end
		else
			typed = Tics.TypedAt(text, timing.Chars, t - timing.Resume)
			phase = "After"
		end
	else
		typed = Tics.TypedAt(text, 0, t)
	end
	return { Typed = typed, Phase = phase, Caption = caption, Reveal = count(speech.ItemAt, typed), Words = count(speech.WordAt, typed) }
end

-- Deterministic glitch char for letter `index` (the balloons: no clock, no randomness)
local function glitchOf(index: number): string
	const chars = TALK.Glitch
	if #chars == 0 then
		return "#"
	end
	const at = (index * 7) % #chars + 1
	return string.sub(chars, at, at)
end

local function plain(speech: Speech, typed: number): string
	local text = string.sub(speech.Text, 1, math.clamp(typed, 0, #speech.Text))
	const style = TALK.Styles[speech.Style]
	if style == nil then
		return text
	end
	if style.Caps then
		text = string.upper(text)
	end
	const broken = style.Break
	const breakAt = speech.Break
	if broken ~= nil and breakAt ~= nil and (broken.Garble or 0) > 0 and #text > breakAt then
		const out: { string } = { string.sub(text, 1, breakAt) }
		for index = breakAt + 1, #text do
			const char = string.sub(text, index, index)
			const roll = ((index * HASH) % HASH_SPAN) / HASH_SPAN
			table.insert(out, if char ~= " " and roll < (broken.Garble :: number) then glitchOf(index) else char)
		end
		text = table.concat(out)
	end
	return text
end

return table.freeze({
	Build = build,
	At = at,
	Plain = plain,
	StyleOf = styleOf,
	Items = itemsOf,
})
