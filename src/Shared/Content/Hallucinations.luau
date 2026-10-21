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
-- Scripted: true = never drawn (neither the sanity roll nor an open family D call); plays only when the server names
-- its key (owner 2026-10-20, Provisional Q-415: the Night 1 opening, Nights.Opening).
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
	Scripted: boolean?,
}

export type Rules = {
	Interval: { number }, -- {min, max} s between two rolls; the roll now uses Sanity.Tiers[k].Interval (DEC-352), kept for reference
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
	-- owner 2026-10-20 (Provisional Q-415): the owner's two new scares, family D from Night 1 (no verb, no cost)
	{ Key = "post_figure", MaxSanity = 20, FamilyD = true, Effect = "PostFigure", Cooldown = 150, Weight = 2 }, -- under the lamp
	{ Key = "shop_shadow", MaxSanity = 20, FamilyD = true, Effect = "ShopShadow", Cooldown = 120, Weight = 2 }, -- gone when seen
	-- owner 2026-10-20 (Provisional Q-415): Night 1 scripted opening (posts, the figure across the street, the call static)
	{ Key = "night_opening", MaxSanity = 1, FamilyD = true, Effect = "NightOpening", Cooldown = 0, Weight = 1, Scripted = true },
	{ Key = "monster_glimpse", MaxSanity = 20, FamilyD = true, Effect = "MonsterGlimpse", Cooldown = 180, Weight = 3 }, -- end of street; TASK-341: x3 so N2-N5 show one
} :: { Hallucination })

-- Walt's fake calls and the stranger on the radio (TASK-601; owner 2026-10-19, Q-401 A: the lore of Walt as the real
-- villain told only through these lines and the old flyers after the credits; story/walt-calls-lore.md §4, §7).
-- [night] = the lines of that night in order; Default = nights without lines, > 10, endless. Every line is a real hint
-- (the night's rule, said like the boss call) that hides a piece of the lore; Id = stable key (the "heard" mark, the
-- voice file). English placeholders until ui-text.md; a line with no pre-generated voice shows as text only.
export type Line = { Id: string, Text: string }
export type Lines = { [number]: { Line }, Default: { Line } }

local function line(id: string, text: string): Line
	return { Id = id, Text = text }
end

const waltLines: Lines = {
	[1] = {
		line("walt_n1_plenty", "Blank face? Window shut. I've taught plenty."),
		line("walt_n1_easy", "First night's easy, Rookie. Heh. Mostly."),
	},
	[2] = {
		line("walt_n2_key", "I've got a key, Rookie. I never knock."),
		line("walt_n2_plain", "Shaky one's just hungry. Feed him plain."),
	},
	[3] = {
		line("walt_n3_breaker", "Lights out? Breaker. Hold it. Don't let go."),
		line("walt_n3_they", "Keep that light on. It's all they want. Heh."),
	},
	[4] = {
		line("walt_n4_stare", "Head on backwards? Window. Don't stare."),
		line("walt_n4_next", "Who are they? ...Next question. Window shut."),
	},
	[5] = {
		line("walt_n5_friend", "Yellow raincoat? Serve her. Old friend."),
		line("walt_n5_eyes", "Someone just standing there? Eyes down."),
	},
	[6] = {
		line("walt_n6_two", "Red out there? Stay in. Opal's pouring two."),
		line("walt_n6_window", "I can see your window from here. Good work."),
	},
	[7] = {
		line("walt_n7_last", "Feet off the floor. The last one forgot."),
		line("walt_n7_better", "You're better than the last one. Much better."),
	},
	[8] = {
		line("walt_n8_notme", "Long car? Keep it shut. It's not here for me."),
		line("walt_n8_good", "Window shut till the brights go. Good Rookie."),
	},
	[9] = {
		line("walt_n9_trust", "Steps up top? Don't look up. Trust me."),
		line("walt_n9_cap", "My old cap out back? Lock the door. Next question."),
	},
	[10] = {
		line("walt_n10_off", "Lamps going out? Shop light off. Keep it off."),
		line("walt_n10_coffee", "Almost morning. I'll bring the coffee myself."),
	},
	Default = {
		line("walt_rules", "Same rules, Rookie. Window, breaker, eyes down."),
		line("walt_key", "Knocks? Not me. I've got the key."),
		line("walt_stare", "Don't stare at them too long."),
		line("walt_lights", "Won't leave? Shop light off."),
		line("walt_watching", "Keep the light on. I'm watching. Heh."),
		line("walt_wait", "Don't wait for me, Rookie."),
	},
}

const radioLines: Lines = {
	[1] = { line("radio_n1_light", "...hello...? Is the light still on over there...?") },
	[2] = { line("radio_n2_key", "...lock it... I never had a key either...") },
	[3] = { line("radio_n3_counted", "...hold the breaker... I counted too, back then...") },
	[4] = { line("radio_n4_faces", "...don't stare... they learn faces... like his...") },
	[5] = { line("radio_n5_lady", "...serve the lady... she waited for me too...") },
	[6] = { line("radio_n6_coffee", "...stay inside... the second coffee was mine once...") },
	[7] = { line("radio_n7_flyer", "...get up high... he sent me the flyer too...") },
	[8] = {
		line("radio_n8_shut", "...keep the window shut... don't let it see you..."),
		line("radio_n8_instead", "...it came for Walt once... he sent me instead..."),
	},
	[9] = {
		line("radio_n9_cap", "...the cap... he gave it to me on my tenth morning..."),
		line("radio_n9_coffee", "...don't look up... and don't take his coffee..."),
	},
	[10] = {
		line("radio_n10_me", "...it's me... the last Rookie... I took the shift..."),
		line("radio_n10_offer", "...lights off... at sunrise he'll offer you the shift..."),
	},
	Default = {
		line("radio_open", "...anyone still open out there...?"),
		line("radio_grill", "...is the grill still on...?"),
		line("radio_shut", "...keep the window shut..."),
		line("radio_wait", "...don't wait up for me..."),
		line("radio_lit", "...still on the other side... still keeping it lit..."),
	},
}

return Table.with(base, {
	Rules = Table.record(rules),
	WaltLines = waltLines,
	RadioLines = radioLines,
})
