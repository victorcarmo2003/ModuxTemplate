--!strict
-- Boss (Walt) phone calls and their rules (content-data.md §3.19, §6.7; architecture.md §19.9; network.md §13.3;
-- FEAT-018; DEC-025, DEC-076, DEC-077, DEC-124, DEC-194). Keys are the Call.Call enum (sentinel "none").
-- Owner: narrative-writer (Lines from docs/story/ui-text.md §11; TASK-082 revises) + game-designer (triggers).
-- Trigger.Kind:
--   DayPrep        Prep of Day = Trigger.Day (Day 1 tutorial and Day 2; with the run flow of 2026-10-12 every day from
--                  Day 3 comes after a night, so the days 3+ are the call_day_after_<k> rows), or Prep of the first day
--                  after night Trigger.Night (call_day_after_<k>; Variant "quentin": the thief was caught the day
--                  before; Provisional, ui-text §11.3)
--   DayInfinite    Prep of an endless day: one row of the pool at random, never the same twice in a row
--   NightCall      Call phase of Night = Trigger.Night, first attempt
--   NightCoffee    Call phase of Night = Trigger.Night (Night 1), right after that night's own call (lower Priority); its
--                  cue CoffeeHint starts the sanity-bar / coffee-machine emphasis (VitalService:StartCoffeeHint)
--   NightRepeat    Call phase of a repeated night (Attempt > 0): exactly one row; its lines are followed by the
--                  Short lines of that night's NightCall (LinesOf below)
--   LostCritical / LostLastChance   after NightResolved("Lost"); played in the Call of the repeated night
--   RunOver        never rung (no call in NightLost/RunEnd): the run end screen quotes its lines (Provisional)
--   Hint           first time Trigger.Action is performed in the run (InteractionService.Performed)
--   Tutorial       first-hot-dog tutorial call (user request 2026-10-11, Provisional): rings in a day Prep/Open while a
--                  player of the server has the tutorial pending (Day 1 of the run, TutorialService:AnyPending); on Day 1 it replaces the DayPrep call. Never
--                  answers itself and is held open until no player has the tutorial pending, then stays
--                  Rules.Tutorial.Goodbye s more (Walt's goodbye) and hangs up. The tutorial player's client voices
--                  the step lines (TutorialController, Steps.luau); Lines are what everyone else hears.
--   UpgradeLesson  Day 1 upgrade lesson (owner request 2026-10-14, Provisional): rings once in the day Closing (6 PM,
--                  clock held by TutorialService) when the last-call line is empty and a rookie of the server has not
--                  bought the first upgrade yet (TutorialService:LessonCallDue); Walt sends them to the Gear Stand for
--                  Storage (shared.Tutorial.Rules.Upgrade). Answers itself like any day call.
-- Speaker nil = Walt. A line lasts Rules.LineTime; the current line = floor((now - StartedAt) / LineTime).
local Table = require(script.Parent.Table)
local VoiceLines = require(script.Parent.VoiceLines)
-- TASK-393: the Day 1 Gear Stand call names where the stand is (the restaurant has it in the back, Q-321)
local Restaurant = require(script.Parent.Restaurant)

export type Line = {
	Text: string,
	Speaker: string?,
}

export type TriggerKind =
	"None"
	| "DayPrep"
	| "DayInfinite"
	| "NightCall"
	| "NightCoffee"
	| "NightRepeat"
	| "LostCritical"
	| "LostLastChance"
	| "RunOver"
	| "Hint"
	| "Tutorial"
	| "UpgradeLesson"

-- Cue = something the server does when line `Line` (1-based) of a call starts talking (once per call):
--   CoffeeHint    Night 1: the sanity bar and the coffee machine are emphasised until the first coffee (VitalService)
export type CueKind = "CoffeeHint"

export type Cue = {
	Line: number,
	Kind: CueKind,
}

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
	-- LostCritical > LostLastChance > NightRepeat.
	Priority: number,
	Once: boolean, -- once per run (snapshot Bs)
	Short: { Line }?, -- NightCall only: the lines that follow the NightRepeat opener on a repeat
	Cues: { Cue }?, -- server effects tied to a line (see Cue)
}

-- First-hot-dog tutorial call (Trigger Tutorial). PROVISIONAL (frontend-coder, user request 2026-10-11).
export type TutorialRules = {
	Call: string, -- key of the Tutorial row
	Goodbye: number, -- s the call stays on after the last tutorial ended (Walt's goodbye line), then hangs up
	-- actions the tutorial teaches: their Hint rows count as heard once the tutorial call is queued
	Covers: { string },
}

export type Rules = {
	LineTime: number, -- seconds per line (subtitle and voice)
	AutoAnswer: number, -- seconds ringing before the call answers itself (not the Tutorial call)
	DayMaxLines: number,
	NightMaxSeconds: number,
	Tutorial: TutorialRules,
}

const QUENTIN = "You caught Quentin. Nice work."

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

-- Prep of the first day after night k (night k is played on day k + 1, so this is Day k + 2). Variant "quentin" is the
-- same call with Walt's Quentin line inserted as the 2nd line (the thief was caught the day before)
local function dayAfter(night: number, body: { Line }, variant: string?): BossCall
	return {
		Key = if variant then `call_day_after_{night}_{variant}` else `call_day_after_{night}`,
		Lines = body,
		Trigger = { Kind = "DayPrep", Night = night, Variant = variant },
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

-- TASK-492: the restaurant text of a night call (Lines + Short), used instead of the trailer one when
-- Restaurant.Rules.Enabled. It names the premiere that actually runs there (Restaurant.Switch.NewAnomalies) and its
-- restaurant answer (horror-cinematic.md §9); nil = the trailer text fits both
type RestaurantCall = {
	Lines: { Line },
	Short: { Line },
}

local function nightCall(index: number, body: { Line }, short: { Line }, restaurantCall: RestaurantCall?): BossCall
	const variant = if Restaurant.Switch.On then restaurantCall else nil
	return {
		Key = `call_night_{index}`,
		Lines = if variant then variant.Lines else body,
		Trigger = { Kind = "NightCall", Night = index },
		Priority = 3,
		Once = true,
		Short = if variant then variant.Short else short,
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

const base = Table.new({
	{ Key = "none", Lines = {}, Trigger = { Kind = "None" }, Priority = 1, Once = false },

	-- Day 1 opens the tutorial; the rest of it are the Hint rows at the end (ui-text.md §11.1)
	-- Owner D3 2026-10-12 (PROVISIONAL): every call is short: <= 6 words per line, <= 3 lines (nights <= 4, the last
	-- one is the short form of the rule; a repeated night plays the opener + Short)
	day(
		"call_day_1",
		1,
		nil,
		lines("Morning, Rookie! I'm on the line.", "Tap the frank box. Grill it.", "Open up when ready.")
	),

	-- Day 2 (ui-text.md §11.2; user request 2026-10-12): the first day shift that is followed by a night in the trailer, so
	-- Walt warns about it. Days 3+ are the call_day_after_<k> rows below (their old "day N" calls were folded into them).
	day(
		"call_day_2",
		2,
		nil,
		lines("Cheese is in. Folks love cheese.", "Watch your drawer. Quick hands.", "You work late tonight. I'll ring.")
	),
	-- the day after night k (ui-text.md §11.3). Day 3 (after N1) carries the old "bacon" call and Day 4 (after N2) the
	-- "potato sticks" one, each with its quentin variant (the old call_day_3/call_day_4, which could never ring any more).
	dayAfter(1, lines("Morning! Told you nights were quiet.", "Bacon's in. Smell that?", "Grill's hot. Sell some dogs.")),
	dayAfter(1, lines("Morning! You made it.", QUENTIN, "Bacon's in. Go sell some dogs."), "quentin"),
	dayAfter(2, lines("Morning, Rookie. Sleep okay?", "Good. Don't think about it.", "Potato sticks today. Bigger grill, too.")),
	dayAfter(2, lines("Morning, Rookie. Sleep okay?", QUENTIN, "Potato sticks and a bigger grill."), "quentin"),
	dayAfter(3, lines("Bank clock's ticking fine. See?", "Nice and normal. Sell some dogs.")),
	dayAfter(4, lines("One Mr. Pickett today, I hope.", "...That was a joke. Mostly.")),
	dayAfter(5, lines("She liked you. The lady.", "Forget I said that.")),
	dayAfter(6, lines("Ever notice nobody lives upstairs?", "In the daytime, I mean.", "Huh. Next question.")),
	dayAfter(7, lines("You kept your eyes down. Good.", "I counted the lamps. It helps.")),
	dayAfter(8, lines("Long night, huh? Coffee's on me.", "Tell Opal it's for Walt.")),
	dayAfter(9, lines("Rookie. About the knocking.", "That wasn't me. Believe that.", "Tonight's the last. I promise.")),

	-- endless days (ui-text.md §11.4)
	infinite(1, "Another day, another dog."),
	infinite(2, "Proud of you, Rookie. Really."),
	infinite(3, "Grill's hot. Let's go."),
	infinite(4, "Corner's quiet. Too quiet. Heh."),
	infinite(5, "Nice and normal. Just right."),
	infinite(6, "Ketchup, mustard, smile. That's the job."),

	-- Night 1 coffee (user request 2026-10-11, Provisional): the night starts at 50 sanity (Sanity.FirstNightStart) and Walt
	-- sends the rookie to the coffee machine right after the rules call. Short, TTS-friendly ("..." for the pauses, no
	-- numbers, no sausage). Line 1 starts the HUD emphasis (CoffeeHint). Not Once: a repeated Night 1 starts at 50 again.
	{
		Key = "call_night_1_coffee",
		Lines = lines("You sound tired, Rookie...", "Have some coffee.", "It'll keep your head on straight."),
		Trigger = { Kind = "NightCoffee", Night = 1 },
		Priority = 2,
		Once = false,
		Cues = { { Line = 1, Kind = "CoffeeHint" } },
	},

	-- nights (TASK-316, V2: DEC-254..257; anomalies-v2-proposal.md §5): each call presents only the novelty of the night
	-- (Nights[k].NewAnomaly); the last line is its short form. Short = what follows the NightRepeat opener on a repeat.
	-- DEC-261 (TASK-354): "Refuse" became "Shut the window" (no Refuse button); those lines have no voice yet (TTS
	-- fallback) until tools/voice runs again.
	-- owner 2026-10-18: the night calls were too long (4-7 lines, ~15 s) and the voice ran behind the subtitle; now 2-3
	-- lines each, only the sign and the answer. Short = what follows the NightRepeat opener on a repeat.
	nightCall(
		1,
		lines("Evening, Rookie. Some customers look off.", "No face? Shut the window.", "And don't stay outside too long."),
		lines("No face? Shut the window.")
	),
	nightCall(
		2,
		lines("Someone shaking all over?", "Shut the window. Keep working."),
		lines("Shaking? Shut the window."),
		-- TASK-561: ANM-009 debuts tonight in the restaurant (back door opened by hand); Walt has a key and never knocks
		{ Lines = lines("Someone shaking all over? Shut the window.", "Knocks on the back door?", "I've got a key. Don't open."), Short = lines("Shaking? Window. Knocks? Don't open.") }
	),
	nightCall(
		3,
		lines("Lights might go out tonight.", "Breaker's out back. Hold it."),
		lines("Lights out? Breaker. Hold it."),
		{ Lines = lines("Lights might go out tonight.", "Breaker's on the light panel. Hold it."), Short = lines("Lights out? Breaker. Hold it.") }
	),
	nightCall(
		4,
		lines("Head turned all the way back?", "That's no customer. Shut the window."),
		lines("Head on backwards? Shut the window."),
		{ Lines = lines("Head turned all the way back? Shut the window.", "Someone across the street? Don't look."), Short = lines("Backwards head? Window. Watcher? Don't look.") }
	),
	nightCall(
		5,
		lines("White eyes? Twins in line? Shut the window.", "Bell rings? Light off by the third."),
		lines("White eyes or twins? Shut the window."),
		{ Lines = lines("White eyes? Twins in line? Shut the window.", "Red fog on the street?", "Shut it. Stay inside till it's gone."), Short = lines("Eyes, twins, red fog? Shut the window.") }
	),
	nightCall(
		6,
		lines("Lights buzz? Heavy steps?", "Hide out back, behind the trailer."),
		lines("Buzzing lights? Hide out back."),
		{ Lines = lines("Head way too big for them?", "Shut the window."), Short = lines("Big head? Shut the window.") }
	),
	nightCall(
		7,
		lines("Scratching under the trailer?", "Out the back and hide. Quick."),
		lines("Scratching? Hide out back."),
		{ Lines = lines("Scratching under the floor?", "Get off the floor. Climb the counter."), Short = lines("Scratching? Up on the counter.") }
	),
	nightCall(
		8,
		lines("Whispers say hide? Hide out back.", "Car flashes its brights? Shut the window."),
		lines("Whispers? Hide. Headlights? Window."),
		{ Lines = lines("A long car at the drive-thru?", "Shut the window. Keep it shut."), Short = lines("Long car? Shut it. Keep it shut.") }
	),
	nightCall(
		9,
		lines("Steps on the roof? Get out and hide.", "Knocks out back? It's not me. Don't open."),
		lines("Roof steps? Hide. Knocks? Don't open."),
		{ Lines = lines("Steps on the roof? Don't look up.", "Knocks on the back door?", "It's not me. Don't open."), Short = lines("Roof steps? Don't look up. Knocks? Don't open.") }
	),
	nightCall(
		10,
		lines("Last night, Rookie.", "Lamps dying? Run inside the Mart."),
		lines("Lamps out? Run inside the Mart."),
		{ Lines = lines("Last night, Rookie.", "Lamps dying outside? Shop light off.", "Keep it off till they're back."), Short = lines("Lamps out? Shop light off.") }
	),
	{
		Key = "call_night_short",
		Lines = lines("Same night, Rookie. Same rules."),
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
		Lines = lines("Rough night. Let's try again.", "Everyone's back on their feet.", "Only chance I get. Be careful."),
		Trigger = { Kind = "LostLastChance" },
		Priority = 3,
		Once = false,
	},
	-- never rung: quoted as "Walt: ..." on the run end screen (ui-text.md §14). Provisional.
	{
		Key = "call_run_over",
		Lines = lines("That's two, Rookie.", "No more nights for you.", "Go home. You did well."),
		Trigger = { Kind = "RunOver" },
		Priority = 4,
		Once = false,
	},

	-- first-hot-dog tutorial (Trigger Tutorial, Provisional): Walt stays on the line while a rookie learns; these
	-- lines are only for whoever is not doing the tutorial (the rookie hears TutorialController's step lines)
	{
		Key = "call_tutorial",
		Lines = lines("Got a rookie today!", "I'm walking them through it."),
		Trigger = { Kind = "Tutorial" },
		Priority = 4,
		Once = false,
	},

	-- Day 1 upgrade lesson (Trigger UpgradeLesson; owner request 2026-10-14, Provisional texts until narrative-writer)
	{
		Key = "call_tutorial_upgrade",
		Lines = lines(
			"Shift's over, Rookie. Nice work.",
			"Before tonight, get some gear.",
			if Restaurant.Rules.Enabled then "Gear Stand, in the back." else "Gear Stand, at the Mart.",
			"Get Storage. More buns, more sauce.",
			"Short on cash? I've got you."
		),
		Trigger = { Kind = "UpgradeLesson" },
		Priority = 4,
		Once = true,
	},

	-- Day 1 tutorial hints (ui-text.md §11.1): each plays once, after the first time the party performs the action
	hint("hint_grill_place", "grill_place", lines("Bar full? Grab it.")),
	hint("hint_grill_collect", "grill_collect", lines("Now slice a bun.")),
	hint("hint_bun_cut", "bun_cut", lines("Pop a frank in the bun.")),
	hint("hint_board_add_sausage", "board_add_sausage", lines("Hot dog's ready. Wait for orders.")),
	-- TASK-284: the window lever opens the shop (key kept: BossCalls ids)
	hint("hint_open_sign", "shutter_toggle", lines("We're open! Folks are lining up.", "Shut the window, shop's closed.")),
	hint(
		"hint_take_order",
		"take_order",
		lines("See the bubble? That's the order.", "Nothing extra.")
	),
	hint(
		"hint_serve",
		"serve",
		lines("Nice! Tips go in the jar.", "Low on stock? Grab a box in the pantry.")
	),
	hint(
		"hint_buy_package",
		"buy_package",
		lines("Careful crossing. Get hit, drop it.", "Gear's on the back wall.", "Sometimes there's something special.")
	),
	hint("hint_restock", "restock", lines("That's how you restock. Easy.")),
	hint("hint_discard", "discard", lines("Messed up? Toss it. No harm.")),
	hint("hint_bench_buy_upgrade", "bench_buy_upgrade", lines("New gear's in the kitchen. Heh.")),
} :: { BossCall })

const rules: Rules = {
	LineTime = 2.5, -- FEAT-018
	AutoAnswer = 15, -- FEAT-018
	DayMaxLines = 7,
	NightMaxSeconds = 45,
	Tutorial = {
		Call = "call_tutorial",
		Goodbye = 6,
		-- every action the tutorial walks through (Mart trip included): no hint call rings after Walt's goodbye
		Covers = {
			"grill_place",
			"grill_collect",
			"bun_cut",
			"board_add_sausage",
			"shutter_toggle",
			"take_order",
			"serve",
			"topping_add",
			"discard",
			"buy_package",
			"restock",
		},
	},
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

-- Line timing (owner 2026-10-18: the voice ran behind a fixed 2.5 s subtitle and was cut): each line lasts its
-- pre-generated voice (Content.VoiceLines, Length) + LINE_GAP; a line with no voice keeps Rules.LineTime. Server
-- (EndsAt, the current line) and client (subtitle, voice) use these same functions, so everyone is on the same line.
const LINE_GAP = 0.45 -- s of silence between two lines
const MIN_LINE = 1.4 -- s: even a one-word line stays readable

-- the same normalisation as Cutscene/Speech.Spoken (the VoiceLines.Index key)
local function spoken(text: string): string
	local out = string.gsub(text, "%d[%d%-%s]*%d", "")
	out = string.gsub(out, "^[%s%.,!%?]+", "")
	out = string.gsub(out, "%s+", " ")
	return out
end

local function durationOf(line: Line): number
	const speaker = string.lower(line.Speaker or "walt")
	const key = VoiceLines.Index[speaker .. "\0" .. spoken(line.Text)]
	const voice = if key ~= nil then VoiceLines.Lines[key] else nil
	if voice == nil then
		return rules.LineTime
	end
	return math.max(voice.Length + LINE_GAP, MIN_LINE)
end

-- total length of a call's lines (s)
local function lengthOf(list: { Line }): number
	local total = 0
	for _, line in list do
		total += durationOf(line)
	end
	return total
end

-- index of the line speaking `elapsed` s into the call (1..#list), #list + 1 when it is over
local function lineAt(list: { Line }, elapsed: number): number
	local t = 0
	for index, line in list do
		t += durationOf(line)
		if elapsed < t then
			return index
		end
	end
	return #list + 1
end

return Table.with(base, {
	Rules = Table.record(rules),
	LinesOf = linesOf,
	LengthOf = lengthOf,
	LineAt = lineAt,
	DurationOf = durationOf,
})
