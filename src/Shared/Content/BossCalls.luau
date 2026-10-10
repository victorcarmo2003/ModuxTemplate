--!strict
-- Boss (Walt) phone calls and their rules (content-data.md §3.19, §6.7; architecture.md §19.9; network.md §13.3;
-- FEAT-018; DEC-025, DEC-076, DEC-077, DEC-124, DEC-194). Keys are the Call.Call enum (sentinel "none").
-- Owner: narrative-writer (Lines from docs/story/ui-text.md §11; TASK-082 revises) + game-designer (triggers).
-- Trigger.Kind:
--   DayPrep        Prep of Day = Trigger.Day (days 1-5; Variant "quentin": the thief was caught the day before), or
--                  Prep of the first day after night Trigger.Night (call_day_after_<k>; Provisional, ui-text §11.3)
--   DayInfinite    Prep of an endless day: one row of the pool at random, never the same twice in a row
--   NightCall      Call phase of Night = Trigger.Night, first attempt
--   NightRepeat    Call phase of a repeated night (Attempt > 0): exactly one row; its lines are followed by the
--                  Short lines of that night's NightCall (LinesOf below)
--   TrailerBought  VehicleService.Swapped; plays in the Call of Night 1, before call_night_1
--   LostCritical / LostLastChance   after NightResolved("Lost"); played in the Call of the repeated night
--   RunOver        never rung (no call in NightLost/RunEnd): the run end screen quotes its lines (Provisional)
--   Hint           first time Trigger.Action is performed in the run (InteractionService.Performed)
-- Speaker nil = Walt. A line lasts Rules.LineTime; the current line = floor((now - StartedAt) / LineTime).
local Table = require(script.Parent.Table)

export type Line = {
	Text: string,
	Speaker: string?,
}

export type TriggerKind =
	"None"
	| "DayPrep"
	| "DayInfinite"
	| "NightCall"
	| "NightRepeat"
	| "TrailerBought"
	| "LostCritical"
	| "LostLastChance"
	| "RunOver"
	| "Hint"

export type Trigger = {
	Kind: TriggerKind,
	Day: number?,
	Night: number?,
	Action: string?, -- key of Actions (Hint)
	Variant: string?, -- "quentin"
}

export type BossCall = {
	Key: string,
	Lines: { Line },
	Trigger: Trigger,
	-- 1 (low) .. 4 (highest); one call at a time, highest first. Fixed orders inside one Call phase (Validate):
	-- TrailerBought > NightCall; LostCritical > LostLastChance > NightRepeat.
	Priority: number,
	Once: boolean, -- once per run (snapshot Bs)
	Short: { Line }?, -- NightCall only: the lines that follow the NightRepeat opener on a repeat
}

export type Rules = {
	LineTime: number, -- seconds per line (subtitle and voice)
	AutoAnswer: number, -- seconds ringing before the call answers itself
	DayMaxLines: number,
	NightMaxSeconds: number,
}

local function lines(...: string): { Line }
	const out: { Line } = {}
	for _, text in { ... } do
		table.insert(out, { Text = text })
	end
	return out
end

local function day(key: string, dayIndex: number, variant: string?, body: { Line }): BossCall
	return {
		Key = key,
		Lines = body,
		Trigger = { Kind = "DayPrep", Day = dayIndex, Variant = variant },
		Priority = 2,
		Once = true,
	}
end

-- Prep of the first day after night k (the day number varies with the trailer purchase)
local function dayAfter(night: number, body: { Line }): BossCall
	return {
		Key = `call_day_after_{night}`,
		Lines = body,
		Trigger = { Kind = "DayPrep", Night = night },
		Priority = 2,
		Once = true,
	}
end

local function infinite(index: number, text: string): BossCall
	return {
		Key = `call_day_infinite_{index}`,
		Lines = lines(text),
		Trigger = { Kind = "DayInfinite" },
		Priority = 2,
		Once = false,
	}
end

local function nightCall(index: number, body: { Line }, short: { Line }): BossCall
	return {
		Key = `call_night_{index}`,
		Lines = body,
		Trigger = { Kind = "NightCall", Night = index },
		Priority = 3,
		Once = true,
		Short = short,
	}
end

local function hint(key: string, action: string, body: { Line }): BossCall
	return {
		Key = key,
		Lines = body,
		Trigger = { Kind = "Hint", Action = action },
		Priority = 1,
		Once = true,
	}
end

const WALKER = "And never watch the Walker."
const QUENTIN = "Heard you caught Quentin in the act. Nice."

const base = Table.new({
	{ Key = "none", Lines = {}, Trigger = { Kind = "None" }, Priority = 1, Once = false },

	-- Day 1 opens the tutorial; the rest of it are the Hint rows at the end (ui-text.md §11.1)
	day(
		"call_day_1",
		1,
		nil,
		lines(
			"Morning, Rookie! I'll stay on the line.",
			"Tap the sausage box. It goes on the grill.",
			"Flip the sign to OPEN when you're ready."
		)
	),

	-- days 2-5 (ui-text.md §11.2); variant "quentin" inserts the Quentin line as the 2nd line (day >= 3)
	day(
		"call_day_2",
		2,
		nil,
		lines(
			"Morning! Cheese came in. Folks love cheese.",
			"Oh — keep an eye on your cash drawer.",
			"Some folks have quick hands.",
			"Stay close to the cart."
		)
	),
	day("call_day_3", 3, nil, lines("Bacon day! Smell that?", "That's the smell of money.", "You're doing great, Rookie. Really.")),
	day(
		"call_day_3_quentin",
		3,
		"quentin",
		lines("Bacon day! Smell that?", QUENTIN, "That's the smell of money.", "You're doing great, Rookie. Really.")
	),
	day(
		"call_day_4",
		4,
		nil,
		lines(
			"New stuff: potato sticks. Kids love 'em.",
			"Bigger grill on the Mart's back wall.",
			"See that old trailer in the lot?",
			"Not yet. Heh."
		)
	),
	day(
		"call_day_4_quentin",
		4,
		"quentin",
		lines(
			"New stuff: potato sticks. Kids love 'em.",
			QUENTIN,
			"Bigger grill on the Mart's back wall.",
			"See that old trailer in the lot?",
			"Not yet. Heh."
		)
	),
	day(
		"call_day_5",
		5,
		nil,
		lines(
			"Big day, Rookie. See that old trailer?",
			"It's for sale. Buy it with the shop money.",
			"Don't ask how that works. Just trust me.",
			"She's been waiting for the right person.",
			"A long time."
		)
	),
	day(
		"call_day_5_quentin",
		5,
		"quentin",
		lines(
			"Big day, Rookie. See that old trailer?",
			QUENTIN,
			"It's for sale. Buy it with the shop money.",
			"Don't ask how that works. Just trust me.",
			"She's been waiting for the right person.",
			"A long time."
		)
	),

	-- the day after night k (ui-text.md §11.3)
	dayAfter(1, lines("Morning! You made it.", "Told you nights were quiet.", "Grill's hot. Go sell some dogs.")),
	dayAfter(2, lines("Morning, Rookie. Sleep okay?", "Good. Don't think about it too hard.")),
	dayAfter(3, lines("Bank clock's ticking fine today. See?", "Nice and normal. Sell some dogs.")),
	dayAfter(4, lines("Just one Mr. Pickett today, I hope. Heh.", "...That was a joke. Mostly.")),
	dayAfter(5, lines("She liked you. The lady. I can tell.", "Forget I said that. Grill's waiting.")),
	dayAfter(6, lines("Ever notice nobody lives upstairs?", "In the daytime, I mean.", "Huh. Next question.")),
	dayAfter(7, lines("You kept your eyes down. Good.", "I used to count the lamps. It helps.")),
	dayAfter(8, lines("Long night, huh? Coffee's on me.", "Tell Opal it's for Walt. She knows.")),
	dayAfter(
		9,
		lines(
			"Rookie. About the knocking.",
			"That wasn't me.",
			"I need you to believe that.",
			"Tonight's the last one.",
			"Then you get answers. I promise."
		)
	),

	-- endless days (ui-text.md §11.4)
	infinite(1, "Another day, another dog."),
	infinite(2, "Proud of you, Rookie. Really."),
	infinite(3, "Grill's hot. Let's go."),
	infinite(4, "The trailer's still there. Just saying."),
	infinite(5, "Nice and normal. Just how I like it."),
	infinite(6, "Ketchup, mustard, a smile. That's the job."),

	-- trailer bought (ui-text.md §11.5): in the Call of Night 1, before call_night_1 (Priority 4 > 3)
	{
		Key = "call_trailer_bought",
		Lines = lines(
			"You bought the old girl! Heh.",
			"She looks good on that corner.",
			"The cart gets a rest now.",
			"Listen... I need someone on nights.",
			"Can you cover the night shift? Tonight?",
			"There are a few... house rules.",
			"Nothing big. I'll tell you as we go."
		),
		Trigger = { Kind = "TrailerBought" },
		Priority = 4,
		Once = true,
	},

	-- nights (ui-text.md §11.6); the last line is the short form of the rule. Short = what follows the NightRepeat
	-- opener on a repeat: the short form, plus the Walker reminder from Night 8 (not 7: its short form is the Walker)
	nightCall(
		1,
		lines(
			"Evening, Rookie. First night.",
			"Nights are... quieter.",
			"Some customers might look a little off.",
			"If someone walks up with no face —",
			"no eyes, no mouth — don't serve them.",
			"Just refuse. They'll wander off.",
			"Keep the grill hot. See you at six.",
			"No face? Refuse them."
		),
		lines("No face? Refuse them.")
	),
	nightCall(
		2,
		lines(
			"Night two. You did fine last night.",
			"Check your food before it goes out.",
			"A gray sausage, or a bun with a bite",
			"in it you didn't take — toss it.",
			"Trash can. Don't serve it.",
			"And still no faces. Remember faces.",
			"Wrong food? Throw it away."
		),
		lines("Wrong food? Throw it away.")
	),
	nightCall(
		3,
		lines(
			"Evening. Can you see the bank clock?",
			"Keep an eye on it. And an ear. It ticks.",
			"If it stops, flip the trailer lights off.",
			"Count to five. Then back on.",
			"That gets it going again.",
			"Don't leave it stuck. Trust me on this.",
			"Clock stops? Lights off, count five, lights on."
		),
		lines("Clock stops? Lights off, count five, lights on.")
	),
	nightCall(
		4,
		lines(
			"Rookie... there's something you should know.",
			"Sometimes a customer shows up twice.",
			"Same face, same clothes.",
			"One of them is a copy.",
			"The copy is backwards.",
			"Look at their shirt. Their watch. Backwards.",
			"Refuse the backwards one. Serve the real one.",
			"Who are they? ...Next question.",
			"Two of them? Refuse the backwards one."
		),
		lines("Two of them? Refuse the backwards one.")
	),
	nightCall(
		5,
		lines(
			"Tonight, a lady in a yellow raincoat",
			"might come by.",
			"It won't be raining.",
			"She'll be dripping anyway.",
			"Serve her. Always. Whatever she asks for.",
			"Don't refuse her. Don't make her wait.",
			"She's a... very old customer. Be nice.",
			"Yellow raincoat? Always serve her."
		),
		lines("Yellow raincoat? Always serve her.")
	),
	nightCall(
		6,
		lines(
			"Evening. Folks upstairs might wave tonight.",
			"Don't wave back. Don't even look up.",
			"They just want someone to notice them.",
			"Eyes on your grill. They'll get bored.",
			"I know. I know. I'll explain someday.",
			"Someone waving upstairs? Don't look up."
		),
		lines("Someone waving upstairs? Don't look up.")
	),
	nightCall(
		7,
		lines(
			"Rookie. Listen close. This one matters most.",
			"Down Juniper Street, someone walks",
			"toward the trailer.",
			"Every time you look at them,",
			"they get closer.",
			"Whatever you do,",
			"never let them reach your light.",
			"Don't watch the Walker. Not for a second.",
			"When the far lamp buzzes, they're there.",
			"Tell your crew.",
			"Whatever you do, never watch the Walker."
		),
		lines("Whatever you do, never watch the Walker.")
	),
	nightCall(
		8,
		lines(
			"Evening. You're doing better than I ever did.",
			"If a long car parks across the street",
			"with its lights on you —",
			"close the service window. Stay inside.",
			"Don't open it till you hear it drive away.",
			"Can't serve with it shut. Folks will wait.",
			"Regular cars never stop there. That one does.",
			WALKER,
			"Long car? Close the window. Keep it shut."
		),
		lines("Long car? Close the window. Keep it shut.", WALKER)
	),
	nightCall(
		9,
		lines(
			"One more thing. This is important.",
			"I never come to the trailer at night. Never.",
			"If someone knocks on the back door",
			"and says it's me —",
			"it isn't. Close the window. Stay inside.",
			"Keep it shut till the knocking stops.",
			"...I'm sorry I didn't tell you sooner.",
			WALKER,
			"Knocking? It's not me. Close the window."
		),
		lines("Knocking? It's not me. Close the window.", WALKER)
	),
	nightCall(
		10,
		lines(
			"Last night, Rookie. Ten.",
			"Nobody's made it to ten since... well.",
			"Tonight the street might go dark.",
			"Lamp by lamp.",
			"When the lamps start going out,",
			"leave the trailer.",
			"Go to the Mart. Stand under the OPEN sign.",
			"It never goes out.",
			"Come back when the lamps come back.",
			WALKER,
			"See you at sunrise. I promise.",
			"Lamps going out? Go to the Mart sign."
		),
		lines("Lamps going out? Go to the Mart sign.", WALKER)
	),
	{
		Key = "call_night_short",
		Lines = lines("Same night, Rookie. Same rules.", "You know them."),
		Trigger = { Kind = "NightRepeat" },
		Priority = 2,
		Once = false,
	},

	-- lost night (ui-text.md §11.7). In the Call of the repeated night, by Priority: critical (4) -> last chance
	-- (3) -> short (2). One last-chance text for solo and party (no variant).
	{
		Key = "call_lost_critical",
		Lines = lines("You watched it, didn't you?", "...It's okay. Breathe."),
		Trigger = { Kind = "LostCritical" },
		Priority = 4,
		Once = false,
	},
	{
		Key = "call_lost_last_chance",
		Lines = lines(
			"Rough night. Let's try that again.",
			"Everyone's back on their feet.",
			"But listen. This is the only time",
			"I can do this, Rookie.",
			"Be careful out there."
		),
		Trigger = { Kind = "LostLastChance" },
		Priority = 3,
		Once = false,
	},
	-- never rung: quoted as "Walt: ..." on the run end screen (ui-text.md §14). Provisional.
	{
		Key = "call_run_over",
		Lines = lines("That's two, Rookie.", "I can't put you on nights anymore.", "Go home. Rest. You did more than most."),
		Trigger = { Kind = "RunOver" },
		Priority = 4,
		Once = false,
	},

	-- Day 1 tutorial hints (ui-text.md §11.1): each plays once, after the first time the party performs the action
	hint("hint_grill_place", "grill_place", lines("When the bar fills up, grab it.")),
	hint("hint_grill_collect", "grill_collect", lines("It waits on the warmer. Now slice a bun.")),
	hint("hint_bun_cut", "bun_cut", lines("Pop a sausage in the bun.")),
	hint("hint_board_add_sausage", "board_add_sausage", lines("There's your hot dog. Wait for an order.")),
	hint("hint_open_sign", "open_sign", lines("We're open! Folks line up at the counter.")),
	hint(
		"hint_take_order",
		"take_order",
		lines("See the bubble? That's the order.", "Add only what they asked for. Nothing extra.")
	),
	hint(
		"hint_serve",
		"serve",
		lines(
			"Nice! Money goes in the drawer.",
			"Running low? The Mart's across the street.",
			"Look both ways! These drivers don't brake."
		)
	),
	hint(
		"hint_buy_package",
		"buy_package",
		lines("Careful crossing. Get hit, and you drop it.", "Gear's on the back wall.", "Sometimes there's something special.")
	),
	hint("hint_restock", "restock", lines("That's how you restock. Easy.")),
	hint("hint_discard", "discard", lines("Messed one up? Toss it. No harm done.")),
	hint("hint_bench_buy_upgrade", "bench_buy_upgrade", lines("New gear's already on the cart. Heh.")),
} :: { BossCall })

const rules: Rules = {
	LineTime = 2.5, -- FEAT-018
	AutoAnswer = 15, -- FEAT-018
	DayMaxLines = 7,
	NightMaxSeconds = 45,
}

-- Lines actually spoken for a call. A NightRepeat call continues with the Short lines of the night being repeated;
-- every other call is its own Lines. Server (timing) and client (subtitle) use this same function.
local function linesOf(key: string, night: number): { Line }
	const row = base.ByKey[key]
	if row == nil then
		return {}
	end
	if row.Trigger.Kind ~= "NightRepeat" then
		return row.Lines
	end
	const source = base.ByKey[`call_night_{night}`]
	const short = if source then source.Short else nil
	if short == nil then
		return row.Lines
	end
	const out = table.clone(row.Lines)
	for _, line in short do
		table.insert(out, line)
	end
	return out
end

return Table.with(base, {
	Rules = Table.record(rules),
	LinesOf = linesOf,
})
