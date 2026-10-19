--!strict
-- Low-sanity hallucinations and family D scares (content-data.md §3.19, §6.11; architecture.md §19.15; FEAT-019;
-- script.md §8; anomalies-v2-proposal.md §3 D; DEC-038, DEC-123, DEC-168, DEC-169, DEC-172, DEC-173, DEC-254,
-- DEC-256). Owner: game-designer + art-director. Not a wire enum for the effect itself: hallucinations are
-- client-only (HallucinationController), never a prompt, never a server state, never count as an anomaly seen and
-- never move the Walker. Family D ("sustos sem verbo", DEC-254) uses the same rows: the night scheduler asks
-- HallucinationService:Scare, the client picks one FamilyD row it can play right now. No damage, no jumpscare
-- (the jumpscare belongs to the error only, DEC-256); cartoon and Mild (DEC-172).
-- MaxSanity: the effect may roll on its own while the player's sanity is below this value (thresholds 60 / 40 / 20).
-- FamilyD: true = also in the family D pool (played by the night scheduler regardless of sanity).
-- Effect: module name in HallucinationController/Effects/ (discovered).
-- Cooldown: seconds before the same effect can roll again (both paths share it). Weight: relative chance.
-- post_flicker imitates the Walker's post WITHOUT the buzz (DEC-123): the buzz is the real N7 start sign.
-- Numbers Provisional (game-designer).
local Table = require(script.Parent.Table)

export type Hallucination = {
	Key: string,
	MaxSanity: number,
	FamilyD: boolean,
	Effect: string,
	Cooldown: number,
	Weight: number,
}

export type Rules = {
	Interval: { number }, -- {min, max} seconds between two rolls while eligible
	NightOnly: boolean, -- sanity exists only at night (DEC-056)
	ScareGap: number, -- s: after a family D scare the sanity roll waits at least this long (no two in a row)
}

const rules: Rules = {
	Interval = { 20, 45 }, -- Provisional: rare enough to stay a surprise (DEC-173)
	NightOnly = true,
	ScareGap = 12, -- Provisional
}

const base = Table.new({
	-- < 60
	{ Key = "fake_call", MaxSanity = 60, FamilyD = true, Effect = "FakeCall", Cooldown = 600, Weight = 0.25 }, -- owner 2026-10-18: phone_glitch too often (was 180 / 1) -- rings, "Walt: ..."
	{ Key = "grill_hiss", MaxSanity = 60, FamilyD = true, Effect = "GrillHiss", Cooldown = 90, Weight = 1 }, -- empty grill sizzle
	{ Key = "bottle_fall", MaxSanity = 60, FamilyD = true, Effect = "BottleFall", Cooldown = 150, Weight = 1 }, -- ketchup tips over
	-- < 40
	{ Key = "roof_steps", MaxSanity = 40, FamilyD = true, Effect = "RoofSteps", Cooldown = 90, Weight = 1 }, -- steps on the roof
	{ Key = "roof_knock", MaxSanity = 40, FamilyD = true, Effect = "RoofKnock", Cooldown = 120, Weight = 1 }, -- 3 knocks on the roof
	{ Key = "ghost_customer", MaxSanity = 40, FamilyD = true, Effect = "GhostCustomer", Cooldown = 120, Weight = 1 }, -- gone on 2nd look
	{ Key = "post_flicker", MaxSanity = 40, FamilyD = true, Effect = "PostFlicker", Cooldown = 120, Weight = 1 }, -- no buzz (DEC-123)
	{ Key = "radio_voice", MaxSanity = 40, FamilyD = true, Effect = "RadioVoice", Cooldown = 600, Weight = 0.25 }, -- owner 2026-10-18: phone_glitch too often (was 180 / 1) -- static + one line
	{ Key = "street_watcher", MaxSanity = 40, FamilyD = true, Effect = "StreetWatcher", Cooldown = 150, Weight = 1 }, -- far, staring
	-- < 20
	{ Key = "whisper", MaxSanity = 20, FamilyD = true, Effect = "Whisper", Cooldown = 120, Weight = 1 }, -- "Rookie..."
	{ Key = "mart_sign_blink", MaxSanity = 20, FamilyD = true, Effect = "MartSignBlink", Cooldown = 180, Weight = 1 }, -- blinks
	{ Key = "sign_word", MaxSanity = 20, FamilyD = true, Effect = "SignWord", Cooldown = 180, Weight = 1 }, -- one odd word
	{ Key = "window_shadow", MaxSanity = 20, FamilyD = true, Effect = "WindowShadow", Cooldown = 120, Weight = 1 }, -- AST-085
	{ Key = "window_face", MaxSanity = 20, FamilyD = true, Effect = "WindowFace", Cooldown = 150, Weight = 1 }, -- face 0.3 s
	{ Key = "monster_glimpse", MaxSanity = 20, FamilyD = true, Effect = "MonsterGlimpse", Cooldown = 180, Weight = 3 }, -- end of street; TASK-341: x3 so N2-N5 show one
} :: { Hallucination })

return Table.with(base, {
	Rules = Table.record(rules),
})
