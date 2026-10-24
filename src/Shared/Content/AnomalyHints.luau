--!strict
-- Hints of the customer anomalies (owner 2026-10-22, Provisional; design/anomalies-after-accept-proposal.md §9). English
-- UI text, Provisional until the narrative-writer revises it. One row per customer anomaly (Content.Anomalies Actor
-- "Customer"). Presentation only: the condition and its numbers live in the server rules (Anomaly/server/AnomalyService/
-- Rules, Params.Condition; T10); this table only says what the player is TOLD.
--
-- Owner 2026-10-22: "a gente tem aquele título ... colocar uma dica pro player, por exemplo 'seja rápido', e vai vir um
-- sussurro 'seja rápido'". When the anomaly enters the delivery queue (record Phase "Queue"):
--   - the caption (AnomalyController/Score, the "POWER OUT" card) shows Title (or Hint) over Line, Rules.CaptionTime s
--   - Rules.Sound plays (the whisper) and the words on screen say the Hint for Rules.WhisperFor s (HorrorScenes, Queue)
--   - while it waits, the scene's whispers (its old arrival Whispers steps, moved to Queue) say the Hint and Words
-- Rows:
--   Key     Content.Anomalies key (a customer anomaly)
--   Hint    the hint itself: the whisper, and the line of Walt's hints paper (another agent's, owner 2026-10-22)
--   Title   a shorter caption title when Hint is too long for a phone's caption (nil = Hint)
--   Line    the caption's second line
--   Words   more whispers while it waits (the Hint is put in front of them, three times)
--   Live    true = its condition runs in code now (caption, Hint whisper and these words play); false = planned only: the
--           anomaly has the interim "Serve" condition (no error), so no caption and its whispers are Rules.Generic
-- NOTE T10: this table replicates, and a hint names what handles the anomaly. Accepted (Provisional): the hint goes on the
-- screen of every player the moment the anomaly enters the queue anyway; no deadline, number or rule lives here.
local Table = require(script.Parent.Table)

export type Hint = {
	Key: string,
	Hint: string,
	Title: string?,
	Line: string,
	Words: { string },
	Live: boolean,
}

export type Rules = {
	CaptionTime: number, -- s the caption stays on screen
	Sound: string, -- Content.Sounds key heard with the caption (the whisper)
	SoundVolume: number,
	WhisperFor: number, -- s the words on screen say only the Hint
	WhisperRate: number, -- rate of those words (1 = Kit/Whispers default)
	Generic: { string }, -- whispers in the queue of an anomaly whose hint is not Live
}

const rows: { Hint } = {
	-- pilots (Live): their condition runs (Rules/ANM-014 Hurry, ANM-012 NoLook, ANM-011 Plain)
	{
		Key = "anm_014_big_head",
		Hint = "BE QUICK",
		Line = "SERVE IT BEFORE ITS HEAD HITS THE GLASS",
		Words = { "hurry...", "it's getting bigger", "faster", "the glass...", "be quick" },
		Live = true,
	},
	{
		Key = "anm_012_turned_neck",
		Hint = "DON'T LOOK AT HER",
		Title = "DON'T LOOK",
		Line = "EYES DOWN WHEN YOU HAND IT OVER",
		Words = { "eyes down...", "look at the tray", "don't look at her face", "she's looking at you", "don't look" },
		Live = true,
	},
	{
		Key = "anm_011_shaker",
		Hint = "JUST BREAD",
		Line = "NOTHING ON IT",
		Words = { "nothing on it", "plain...", "he's just hungry", "no toppings", "just bread" },
		Live = true,
	},
	-- the head banger (DEC-366, TASK-649): its rule already runs (ANM-022 drops the Shutter; the shop light off resolves
	-- it). Same words as Walt's N8 call and the paper (Content.Hints night 8)
	{
		Key = "anm_022_head_banger",
		Hint = "SHOP LIGHT OFF",
		Line = "WINDOW WON'T STOP HIM. LIGHT OFF.",
		Words = { "light off...", "lights off, Rookie...", "the glass won't stop him...", "turn it off..." },
		Live = true,
	},
	-- the Raincoat Lady's condition is already hers: serve her (Rules/ANM-005, "Serve" + OmitSanity)
	{
		Key = "anm_005_raincoat_lady",
		Hint = "SERVE HER",
		Line = "DON'T LEAVE HER OUT IN THE RAIN",
		Words = { "serve her", "she's cold...", "be kind", "don't make her wait" },
		Live = true,
	},
	-- planned (proposal §2): the interim "Serve" runs in code, these hints wait for their conditions
	{
		Key = "anm_013_white_eyes",
		Hint = "LIGHTS OFF",
		Line = "SERVE HER IN THE DARK",
		Words = { "the light...", "kill the lights", "in the dark", "she hates the light" },
		Live = false,
	},
	{
		Key = "anm_001_blank_folks",
		Hint = "DON'T COOK IT",
		Line = "A BLANK TICKET LEAVES ON ITS OWN",
		Words = { "blank...", "there's nothing on the ticket", "let it go", "don't cook it" },
		Live = false,
	},
	{
		Key = "anm_004_copies",
		Hint = "DON'T COOK IT",
		Line = "THAT ORDER WAS ALREADY SERVED",
		Words = { "the same order...", "they already left", "it's a copy", "don't cook it" },
		Live = false,
	},
	{
		Key = "anm_015_floater",
		Hint = "WAIT FOR THE THUD",
		Title = "WAIT FOR IT",
		Line = "SERVE IT WHEN ITS FEET TOUCH THE FLOOR",
		Words = { "its feet...", "wait...", "wait for the thud", "not yet" },
		Live = false,
	},
	{
		Key = "anm_016_starer",
		Hint = "SERVE HIM",
		Line = "AND DON'T STARE BACK",
		Words = { "serve him", "don't stare", "it never blinks", "look away" },
		Live = false,
	},
	{
		Key = "anm_023_on_camera",
		Hint = "CHECK THE CAMERAS",
		Title = "CAMERAS",
		Line = "WRONG ON CAMERA? DON'T COOK IT", -- the N10 call's words (DEC-367)
		Words = { "check the cameras", "look at the screen", "what is it really?", "don't cook it" },
		Live = false,
	},
}

const rules: Rules = {
	CaptionTime = 3,
	Sound = "whisper",
	SoundVolume = 0.9,
	WhisperFor = 2.2,
	WhisperRate = 1.4,
	Generic = {
		"IT'S WAITING FOR ITS ORDER",
		"something's wrong with it",
		"don't make it wait...",
		"just get it over with",
	},
}

return Table.with(Table.new(rows), {
	Rules = Table.record(rules),
})
