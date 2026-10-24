--!strict
-- Walt's notes (owner request 2026-10-22, Provisional). The tip jar left the front counter; a sheet of paper lies there now
-- (MapId Rules.MapId, MAP01_Restaurant.Trailer.Front.HintNote). Every night, once Walt's night call is over, that night's tip
-- is written on it: pencil scribble from the paper (Rules.Sound) and a "NEW!" sticker until the player reads it. Reading it
-- (Rules.Action) brings the camera close over the paper, every tip of the run so far, newest on top, with its night.
-- Server: HintService (when a tip is written, the prompt). Client: HintController (the paper, the close-up, the scare of the
-- customer who arrived while the player was reading). Texts: English, short, Walt's voice; they follow Nights[k].NewAnomaly
-- and the conditions of docs/design/anomalies-after-accept-proposal.md (narrative-writer revises). All Provisional.
local Table = require(script.Parent.Table)
local Actions = require(script.Parent.Actions)
local Nights = require(script.Parent.Nights)
local RunParams = require(script.Parent.RunParams)
local Sounds = require(script.Parent.Sounds)

export type Hint = {
	Key: string, -- hint_night_<k>
	Night: number, -- written once this night's call is over
	Lines: { string }, -- one line per tip; CAPS = the rule
}

-- The customer who walked up to the counter (Q1) or the drive-thru window while the player was reading: when the player
-- looks up from the paper it is already there (SuspenseController:Startle, the forgotten-customer scare)
export type Scare = {
	MinRead: number, -- s the player stayed on the paper for an arrival to count
	MinStand: number, -- s the customer stood there before the player looked up
	Cooldown: number, -- s between two of these scares on one client
	Delay: number, -- s after leaving the paper (the camera back in the head) before the scare plays
}

export type Rules = {
	Action: string, -- Content.Actions key of the paper prompt
	MapId: string, -- MapId attribute of the paper (BasePart or Model)
	Anchor: string, -- prompt Attachment inside it (HintService makes it when the place has none)
	AnchorLift: number, -- studs above the top of the paper for a runtime anchor
	Sound: string, -- Content.Sounds key: the pencil, on screen (heard from the phone)
	Title: string,
	NewText: string, -- sticker on the paper until this player reads it
	Empty: string, -- the paper before the first tip
	-- s the writing waits once the night's Call phase is over for Walt's night call (still talking, queued) before writing
	-- anyway (a call that never ends must not keep the tip off the paper)
	CallWait: number,
	Scare: Scare,
}

local function hint(night: number, ...: string): Hint
	return { Key = `hint_night_{night}`, Night = night, Lines = { ... } }
end

-- The novelty of each night (Nights[k].NewAnomaly) plus its second debut of the restaurant calls (BossCalls). The CAPS words
-- are the same as the customer anomalies' whispered hint (Content.AnomalyHints Hint: BE QUICK, DON'T LOOK AT HER, ...), so
-- the paper, the whisper and the caption say one thing; written apart on purpose (each table has its own owner)
const rows = Table.new({
	-- N1 anm_001_blank_folks (NoServe) + the breaker and the window of Walt's N1 call (DEC-365, DEC-367; TASK-649, the
	-- call's captions in tools/voice/elevenlabs_script.md dia_02/)
	hint(
		1,
		"Power trips? Breaker's outside. HOLD IT till the lights come back.",
		"Something wrong at the window? SHUT IT. They'll go. So does the money.",
		"No face? Blank ticket? DON'T COOK IT. He leaves on his own."
	),
	-- N2 anm_011_shaker (Plain) + anm_009_knock
	hint(2, "Shaky one? JUST BREAD. Nothing on it.", "Knocks out back? I have a key. LOCK IT."),
	-- N3 anm_020_blackout + anm_004_copies (NoServe)
	hint(3, "Lights out? Breaker. HOLD IT till they're back.", "Same order twice? It's a copy. DON'T COOK IT."),
	-- N4 anm_012_turned_neck (NoLook) + anm_006_stalker
	hint(4, "Head on backwards? DON'T LOOK AT HER when you hand it over.", "Someone across the street? Don't stare."),
	-- N5 anm_013_white_eyes (Dark) + anm_005_raincoat_lady (Serve)
	hint(5, "White eyes? LIGHTS OFF, then serve her.", "Raincoat lady? SERVE HER. Be nice."),
	-- N6 anm_014_big_head (Hurry) + anm_021_red_fog. Owner 2026-10-22: the window no longer reaches a customer anomaly
	-- (anomalies-after-accept-proposal.md §9.5), only the red fog outside
	hint(6, "Head growing? BE QUICK. Serve it fast.", "Red fog? Shut the window till it's gone."),
	-- N7 anm_017_crawler + anm_015_floater (Grounded; DEC-367, the call's words)
	hint(
		7,
		"Scratching under the floor? UP ON THE COUNTER.",
		"Feet not touching the floor? Don't serve yet. WAIT FOR THE THUD."
	),
	-- N8 anm_008_long_car + anm_022_head_banger: the window does not send it away, the shop light off does (DEC-366)
	hint(8, "Long car at the drive-thru? Shut it. Keep it shut.", "Head on the glass? Window won't help. SHOP LIGHT OFF."),
	-- N9 anm_019_roof_walker + anm_016_starer (Serve; DEC-367, the call's words)
	hint(9, "Steps on the roof? DON'T LOOK UP.", "Never blinks? SERVE HIM like normal. Just don't stare back."),
	-- N10 anm_010_hush + anm_023_on_camera (NoServe; DEC-367, DEC-368: the call's words)
	hint(
		10,
		"Lamps going out outside? SHOP LIGHT OFF.",
		"Looks normal? CHECK THE CAMERAS. Wrong on camera? DON'T COOK IT.",
		"Last night, Rookie. -W"
	),
} :: { Hint })

const rules: Rules = {
	Action = "read_hints",
	MapId = "HINT-NOTE",
	Anchor = "Prompt_Read",
	AnchorLift = 0.5,
	Sound = "pencil_write",
	Title = "NOTES",
	NewText = "NEW!",
	Empty = "Nothing yet.\nWalt writes here after his night call.",
	CallWait = 60,
	Scare = {
		MinRead = 1.5,
		MinStand = 0.75,
		Cooldown = 30,
		Delay = 0.45,
	},
}

-- One tip per night of the run, every night has one, and the prompt and the sound exist (checked at require time)
const byNight: { [number]: Hint } = {}
for _, row in rows.List do
	if row.Night < 1 or row.Night > RunParams.Nights or row.Night ~= math.floor(row.Night) then
		error(`[Content.Hints] {row.Key}: Night {row.Night} is not a night of the run (1..{RunParams.Nights})`)
	end
	if byNight[row.Night] ~= nil then
		error(`[Content.Hints] two tips for night {row.Night}`)
	end
	if #row.Lines == 0 then
		error(`[Content.Hints] {row.Key} has no line`)
	end
	byNight[row.Night] = row
end
for _, night in Nights.List do
	if byNight[night.Index] == nil then
		error(`[Content.Hints] night {night.Index} has no tip`)
	end
end
if Actions.ByKey[rules.Action] == nil then
	error(`[Content.Hints] Rules.Action {rules.Action} is not a Content.Actions key`)
end
if Sounds.ByKey[rules.Sound] == nil then
	error(`[Content.Hints] Rules.Sound {rules.Sound} is not a Content.Sounds key`)
end

return Table.with(rows, {
	Rules = Table.record(rules),
	-- night -> its tip (nil = none)
	ByNight = table.freeze(byNight),
})
