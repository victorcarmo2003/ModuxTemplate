--!strict
-- Walt with no phone (DEC-372, TASK-638; PROVISIONAL texts and triggers, narrative-writer 2026-10-23,
-- tools/voice/elevenlabs_script.md `noite_reacoes/`). Short lines Walt says in the middle of the night, the first time
-- something happens in the run: the phone does not ring, nobody answers, the voice is close and raw (no phone filter),
-- the same for the whole party, never explained (no text, hint or icon besides the "Walt: ..." subtitle; DEC-077: no
-- replay). Only the MAIN line of the script lives here; the alternative stays in the script.
-- Server: ReactionService (src/Walt/server, TASK-639) gates and fires Net `WaltReaction`; the triggers call
-- ReactionService:React(key) (TASK-641, TASK-642, TASK-646). Client: ReactionController (TASK-640) plays the voice and the
-- subtitle. Voice: Content.VoiceLines under Rules.Speaker (recorded by TASK-662); until then AudioTextToSpeech with
-- Content.Cutscenes.Rules.Voices[Rules.TtsVoice].
local Table = require(script.Parent.Table)
local Cutscenes = require(script.Parent.Cutscenes)

export type Reaction = {
	Key: string, -- stable id (rNN_<what>); the wire enum and the dev command use it
	Ref: string, -- R1..R10 of the script
	Text: string, -- the subtitle, IDENTICAL to the script's main line (the voice id is derived from it)
	Trigger: string, -- when it plays, in words (the code that calls React owns the real condition)
}

export type Rules = {
	OncePerRun: boolean, -- a Key plays at most once per run
	MaxPerNight: number, -- reactions per night at most (the rest are dropped, not queued)
	-- VoiceLines speaker of these lines: its own speaker, so the pipeline never puts them through the phone filter
	-- (tools/voice/generate.py is_phone: only "walt" and "radio" are phone speakers) and their ids never collide with a
	-- phone line of the same text
	Speaker: string,
	TtsVoice: string, -- Content.Cutscenes.Rules.Voices key for the text-to-speech fallback (no recording yet)
	Label: string, -- the subtitle reads "<Label>: <Text>", like the calls' CallSubtitle
	FallbackTime: number, -- s the subtitle stays when the line has no recorded voice (no Length to follow)
}

local function reaction(key: string, ref: string, text: string, trigger: string): Reaction
	return { Key = key, Ref = ref, Text = text, Trigger = trigger }
end

const rows = Table.new({
	reaction("r01_breaker", "R1", "Lights back. Steady hands.", "the breaker is reset (Power.Out -> false by breaker_reset)"),
	reaction("r02_street", "R2", "Chilly out there, isn't it?", "a player goes out to the street at night (not the breaker path)"),
	reaction(
		"r03_window_cost",
		"R3",
		"That one cost you. Worth it.",
		"a customer anomaly is sent off by the window (not ANM-005: it has its own call; not ANM-022)"
	),
	reaction("r04_served_right", "R4", "I saw that. Well done.", "a customer anomaly is served the right way"),
	reaction("r05_wrong_rule", "R5", "Heh. Rules matter, kid.", "a scare for breaking a strange customer's rule"),
	reaction(
		"r06_park",
		"R6",
		"Best seat in town.",
		"a player gets close to the dark Walt in the parking lot and he fades (WaltWatch)"
	),
	reaction("r07_coffee", "R7", "Good coffee. My recipe.", "the first coffee drunk from the machine"),
	reaction("r08_notes", "R8", "I wrote those. Read slowly.", "the first read of Walt's notes paper (read_hints)"),
	reaction("r09_back_door", "R9", "Just in time. Heh.", "the back door locked in time on the knock (ANM-009)"),
	reaction(
		"r10_banger_dark",
		"R10",
		"Dark works too. Clever.",
		"the shop light is off and the head banger (ANM-022) leaves"
	),
} :: { Reaction })

const rules: Rules = {
	OncePerRun = true,
	MaxPerNight = 2,
	Speaker = "walt_near", -- PROVISIONAL name (TASK-638)
	TtsVoice = "walt",
	Label = "Walt",
	FallbackTime = 3, -- PROVISIONAL (TASK-638)
}

-- Checked at require time (Validate.luau is not this task's file): stable keys, one row per script line, real TTS voice
const refs: { [string]: boolean } = {}
for index, row in rows.List do
	if string.match(row.Key, "^r%d%d_[%l_]+$") == nil then
		error(`[Content.WaltReactions] {row.Key}: key must be rNN_<words>`)
	end
	if rows.IndexOf[row.Key] ~= index then
		error(`[Content.WaltReactions] duplicate key {row.Key}`)
	end
	if refs[row.Ref] then
		error(`[Content.WaltReactions] duplicate ref {row.Ref}`)
	end
	refs[row.Ref] = true
	if row.Text == "" then
		error(`[Content.WaltReactions] {row.Key} has no text`)
	end
end
if rules.MaxPerNight < 1 or rules.MaxPerNight ~= math.floor(rules.MaxPerNight) then
	error(`[Content.WaltReactions] Rules.MaxPerNight {rules.MaxPerNight} must be a whole number >= 1`)
end
if rules.Speaker == "walt" or rules.Speaker == "radio" then
	error(`[Content.WaltReactions] Rules.Speaker {rules.Speaker} is a phone speaker (the lines must stay unfiltered)`)
end
if Cutscenes.Rules.Voices[rules.TtsVoice] == nil then
	error(`[Content.WaltReactions] Rules.TtsVoice {rules.TtsVoice} is not a Content.Cutscenes.Rules.Voices key`)
end

return Table.with(rows, {
	Rules = Table.record(rules),
})
