--!strict
-- ShowcaseService/Catalog: the list the panel shows (docs/tech/showcase.md). Server only: the correct verb of an anomaly
-- comes from Rules/ (T10), so the list reaches the client only through the dev-only ShowcaseCatalog packet.
-- New item = one entry here (+ a handler in ShowcaseService when it needs a new "sc" argument).
--
-- Item.Tab: "Anomalies" | "Scares" | "Mechanics". Group = sub-heading. Actions are buttons; the client sends back
-- ShowcaseDo { Action = action.Id, Id = item.Id, Arg = action.Arg }:
--   trigger / resolve / wrong / stop   anomaly lifecycle (Id = ANM Ref)
--   dev      Arg = a DevService command line ("thief now L2"); only commands in ShowcaseService.DEV_ALLOWED
--   sc       Arg = a ShowcaseService helper ("revive", "tp:SS", ...)
--   scare    Id = hallucination key or "sting:<sound key>" (plays on the player's client)
--   scarestop  stops the hallucination playing on the client
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Resolve = require(script.Parent.Resolve)
local Rules = require(game:GetService("ServerScriptService").server.Anomaly.AnomalyService.Rules)

export type Action = { Id: string, Label: string, Arg: string }
export type Item = {
	Tab: string,
	Group: string,
	Id: string,
	Name: string,
	Ref: string,
	Desc: string,
	Verb: string,
	Actions: { Action },
}

const Catalog = {}

local function clip(text: string, max: number): string
	return if #text > max then string.sub(text, 1, max) else text
end

local function act(id: string, label: string, arg: string?): Action
	return { Id = id, Label = clip(label, 28), Arg = clip(arg or "", 80) }
end

-- Anomalies -------------------------------------------------------------------------------------------------------------

const ANOMALY_DESC: { [string]: string } = {
	["ANM-001"] = "A faceless customer walks to the counter (empty order bubble, no breathing). Taking its order costs sanity; refusing resolves it; leaving it is free.",
	["ANM-004"] = "Two identical customers, the copy is mirrored. Refuse the copy. Taking the copy's order fails; refusing the original is only a lost sale.",
	["ANM-005"] = "The Raincoat Lady drips on a dry night. Always serve her; refusing her (or letting her patience run out) fails.",
	["ANM-006"] = "A tall figure across the street only moves while someone stares at it. At the window it leaps in on the nearest player (closed window: it bangs and leaves). Look away and it fades by itself.",
	["ANM-008"] = "A long black car parks across the street and flashes its high beam at the trailer. Close the service window before the flash and keep it shut.",
	["ANM-009"] = "Three knocks, a pause, three more at the back door ('Walt' voice). Close the service window and stay inside until it stops.",
	["ANM-010"] = "The Juniper posts go out one by one to the corner. Be at the Mart sign (safe spot) when the last post goes out; stay until the lights return.",
}

const VERB_TEXT: { [string]: string } = {
	refuse = "Refuse the customer",
	serve = "Serve her",
	dont_look = "Do NOT look at it",
	light = "Light switch off ~5 s, then on",
	shutter = "Close the service window (or leave for the Mart)",
	discard = "Throw the altered item away",
	safe_spot = "Stand at the Mart sign (safe spot)",
}

local function verbLine(ref: string): string
	const rule = Rules.Get(ref)
	if rule == nil then
		return "(no rule file)"
	end
	local text = VERB_TEXT[rule.Verb] or rule.Verb
	if rule.LikelyWrongVerb ~= nil then
		text ..= ` | wrong: {rule.LikelyWrongVerb}`
	end
	if rule.Window > 0 then
		text ..= ` | window {rule.Window}s`
	end
	if rule.IsCritical then
		text ..= " | CRITICAL: loses the night"
	end
	return clip(text, 160)
end

local function anomalyItems(): { Item }
	const out: { Item } = {}
	-- in play order
	const rows: { Content.Anomaly } = {}
	for _, row in Content.Anomalies.List do
		table.insert(rows, row)
	end
	table.sort(rows, function(a: Content.Anomaly, b: Content.Anomaly): boolean
		if a.Night ~= b.Night then
			return a.Night < b.Night
		end
		return a.Ref < b.Ref
	end)
	for _, row in rows do
		const ref = row.Ref
		const actions: { Action } = { act("trigger", "Trigger") }
		if Resolve.HasCorrect(ref) then
			table.insert(actions, act("resolve", "Correct verb"))
		end
		if Resolve.HasWrong(ref) then
			table.insert(actions, act("wrong", "Wrong verb"))
		end
		table.insert(actions, act("stop", "Reset"))
		table.insert(out, {
			Tab = "Anomalies",
			Group = `Night {row.Night}`,
			Id = ref,
			Name = row.Name,
			Ref = ref,
			Desc = clip(ANOMALY_DESC[ref] or row.Name, 300),
			Verb = verbLine(ref),
			Actions = actions,
		})
	end
	return out
end

-- Scares ----------------------------------------------------------------------------------------------------------------

const SCARE_DESC: { [string]: string } = {
	fake_call = "Sanity < 60. The wall phone rings and a fake 'Walt' line plays on the subtitle strip.",
	grill_hiss = "Sanity < 60. A sizzle from an empty grill.",
	roof_steps = "Sanity < 40. Light steps on the trailer roof.",
	ghost_customer = "Sanity < 40. A customer at the counter is gone when you look a second time.",
	post_flicker = "Sanity < 40. A Juniper post flickers WITHOUT the buzz (the buzz is the real Walker sign).",
	whisper = "Sanity < 20. A low 'Rookie...' behind one shoulder (line on screen if the sound is silent).",
	mart_sign_blink = "Sanity < 20. The Mart OPEN sign blinks once.",
	window_shadow = "Sanity < 20. A shadow passes in the trailer's back window.",
}

const STINGS: { { Key: string, Name: string, Desc: string } } = {
	{ Key = "jumpscare", Name = "Jumpscare hit", Desc = "The on-screen jumpscare sound of the Walker's last step (ANM-007), at the DEC-173 scare cap." },
	{ Key = "horror_sting", Name = "Anomaly start sting", Desc = "Played when a fresh anomaly record appears (AnomalyController)." },
	{ Key = "horror_chase_stop", Name = "Anomaly resolved sting", Desc = "Played when an anomaly turns Resolved." },
	{ Key = "anomaly_see", Name = "Anomaly seen sting", Desc = "Played when your own sanity drops for seeing an anomaly." },
	{ Key = "horror_dramatic", Name = "Night lost sting", Desc = "Played when the NightLost phase starts." },
	{ Key = "scary_violins", Name = "Last window violins", Desc = "Played when the night turns to its Last window (5-6 AM)." },
	{ Key = "car_honk_goofy", Name = "Long car goofy honk", Desc = "The comic honk of the ANM-008 car (outside the scare cap)." },
}

local function scareItems(): { Item }
	const out: { Item } = {}
	for _, row in Content.Hallucinations.List do
		table.insert(out, {
			Tab = "Scares",
			Group = `Hallucinations (< {row.MaxSanity})`,
			Id = row.Key,
			Name = row.Key,
			Ref = row.Effect,
			Desc = clip(SCARE_DESC[row.Key] or row.Effect, 300),
			Verb = "Client only: no prompt, no packet, never an anomaly",
			Actions = { act("scare", "Play"), act("scarestop", "Stop") },
		})
	end
	for _, sting in STINGS do
		if Content.Sounds.ByKey[sting.Key] ~= nil then
			table.insert(out, {
				Tab = "Scares",
				Group = "Stings and jumpscares",
				Id = `sting:{sting.Key}`,
				Name = sting.Name,
				Ref = sting.Key,
				Desc = clip(sting.Desc, 300),
				Verb = "Sound only",
				Actions = { act("scare", "Play") },
			})
		end
	end
	return out
end

-- Mechanics -------------------------------------------------------------------------------------------------------------

local function mech(
	group: string,
	id: string,
	name: string,
	desc: string,
	verb: string,
	actions: { Action }
): Item
	return {
		Tab = "Mechanics",
		Group = group,
		Id = id,
		Name = name,
		Ref = "",
		Desc = clip(desc, 300),
		Verb = clip(verb, 160),
		Actions = actions,
	}
end

local function customerItems(): { Item }
	const day: { Action } = { act("sc", "Random customer", "cust:random") }
	const night: { Action } = {}
	for _, pair in Content.Flow.Groups.Pairs do
		const label = if pair.Leader == pair.Partner then `{pair.Leader} x2` else `{pair.Leader}+{pair.Partner}`
		const list = if pair.Shift == "Day" then day else night
		if #list < 8 then
			table.insert(list, act("dev", label, `customer group {pair.Leader}+{pair.Partner}`))
		end
	end
	const out: { Item } = {
		mech(
			"People",
			"mech_customer_day",
			"Customers (day pairs)",
			"Spawns a customer now at an arrival door; the queue and NPC caps still apply. Pairs walk and wait together.",
			"Take order, make the hot dog, serve (or refuse)",
			day
		),
	}
	if #night > 0 then
		table.insert(
			out,
			mech(
				"People",
				"mech_customer_night",
				"Customers (night pairs)",
				"Night pairs (never the same species twice, so the ANM-004 copy stays readable).",
				"Take order, make the hot dog, serve (or refuse)",
				night
			)
		)
	end
	return out
end

local function mechanicItems(): { Item }
	const out: { Item } = {
		mech(
			"Sanity and life",
			"mech_sanity",
			"Sanity",
			"Per player at night. The look changes by band (Day, Mid, Night). Hallucinations roll below 60 / 40 / 20. Zero makes you fall.",
			"Coffee restores; the dark drains; broken rules and seeing anomalies cost",
			{
				act("sc", "-10", "sanity:-10"),
				act("sc", "+10", "sanity:+10"),
				act("sc", "Set 100%", "sanity:max"),
				act("sc", "Set 50", "sanity:50"),
				act("sc", "Set 25", "sanity:25"),
				act("sc", "Set 5", "sanity:5"),
			}
		),
		mech(
			"Sanity and life",
			"mech_faint",
			"Faint, Down, Spectator",
			"Sanity 0 with revives left: Down (ragdoll, items stashed, until 6 AM). Out of revives: Spectator. The body fades after the fallback time (no ambulance in this build).",
			"A teammate revives (wave 4); here use Revive",
			{
				act("dev", "Faint (Down)", "down"),
				act("dev", "Spectator", "spectate"),
				act("sc", "Revive", "revive"),
				act("dev", "Status", "sanity"),
			}
		),
		mech(
			"Sanity and life",
			"mech_ambulance",
			"Ambulance and medics",
			"NOT IN THIS BUILD (wave 4: AmbulanceService, Revive Kit, medics). The default body fallback fades a fallen body; 'Revive' stands in for the ambulance.",
			"n/a (stand-in: Revive in Faint)",
			{
				act("sc", "Revive (stand-in)", "revive"),
				act("dev", "Hold traffic (ambulance)", "traffic hold ambulance on"),
				act("dev", "Release traffic", "traffic hold ambulance off"),
			}
		),
		mech(
			"Sanity and life",
			"mech_night_result",
			"Wipe window and night result",
			"Nobody standing for 10 s loses the night (wipe); the critical rule loses it at once. A lost night repeats or ends the run (boss chance).",
			"Keep one player standing until 6 AM",
			{
				act("dev", "Lose (wipe)", "lose wipe"),
				act("dev", "Lose (critical)", "lose critical"),
				act("dev", "Win night", "win"),
			}
		),
		mech(
			"Light",
			"mech_dark",
			"Dark rule",
			"At night, standing outside every light zone drains sanity (-1 per s after 3 s). The trailer switch, posts and the Mart sign are the lights.",
			"Stay in the light; coffee",
			{
				act("sc", "Force dark", "dark:on"),
				act("sc", "Force lit", "dark:off"),
				act("sc", "Auto", "dark:auto"),
				act("dev", "Lights off", "light off"),
				act("dev", "Lights on", "light on"),
				act("dev", "Hush start", "light hush"),
				act("dev", "Hush end", "light end"),
			}
		),
		mech(
			"Light",
			"mech_coffee",
			"Coffee",
			"The coffee machine restores sanity (night only, cooldown). Night 1 teaches it with a HUD emphasis and an arrow.",
			"Drink coffee at the machine",
			{ act("dev", "Fill machine", "coffee 10"), act("dev", "Night 1 hint", "sanity hint") }
		),
		mech(
			"Street",
			"mech_thief",
			"Thief (Quick Quentin)",
			"By day a thief lurks near the trailer and grabs from the drawer. Whistle or catch him. The panel spawns him now at a lurk spot.",
			"Chase or whistle him away",
			{
				act("dev", "Spawn (any)", "thief now"),
				act("dev", "Lurk L1", "thief now L1"),
				act("dev", "Lurk L2", "thief now L2"),
				act("dev", "Lurk L3", "thief now L3"),
				act("dev", "Status", "thief"),
			}
		),
		mech(
			"Street",
			"mech_traffic",
			"Cars and hit",
			"Street cars run on Juniper. A hit knocks you down (ragdoll, drops what you hold, short immunity). Hit works any time you have a body.",
			"Cross at the crosswalk; keep off the road",
			{
				act("sc", "Run me over", "carhit"),
				act("dev", "Spawn car", "traffic spawn"),
				act("dev", "Clear cars", "traffic clear"),
				act("dev", "Cars status", "traffic"),
			}
		),
		mech(
			"Trailer",
			"mech_shutter",
			"Service window",
			"Trailer only: the window closes at night (button next to the switch). Closed = protected inside; ANM-008 and ANM-009 test it.",
			"Close at night, open after",
			{
				act("dev", "Close window", "shutter close"),
				act("dev", "Open window", "shutter open"),
				act("dev", "Am I inside?", "shutter in"),
			}
		),
		mech(
			"Trailer",
			"mech_vehicle",
			"Food Trailer",
			"The trailer is the only vehicle from Day 1 (window, lights, coffee). Status shows the window and the pose.",
			"n/a",
			{
				act("dev", "Open the window", "trailer reset"),
				act("dev", "Status", "trailer status"),
			}
		),
		mech(
			"Trailer",
			"mech_teleport",
			"Places (teleport)",
			"Moves you to a map point: the Mart safe spot (ANM-010), the trailer pad (zone of ANM-008 / ANM-009).",
			"n/a",
			{ act("sc", "Safe spot (SS)", "tp:SS"), act("sc", "Trailer pad (TRL)", "tp:TRL") }
		),
		mech(
			"Kitchen",
			"mech_altered",
			"Altered item (ANM-002 prop)",
			"Places the gray sausage / bitten bun without running the anomaly (night phase only). Discard it at a bin.",
			"Throw it away",
			{
				act("dev", "On the rail", "alter rail"),
				act("dev", "On a board", "alter board"),
				act("dev", "Clear", "alter clear"),
			}
		),
	}
	for _, item in customerItems() do
		table.insert(out, item)
	end
	return out
end

-- Whole list, anomalies first
function Catalog.Build(): { Item }
	const out: { Item } = {}
	for _, list in { anomalyItems(), scareItems(), mechanicItems() } do
		for _, item in list do
			table.insert(out, item)
		end
	end
	return out
end

return table.freeze(Catalog)
