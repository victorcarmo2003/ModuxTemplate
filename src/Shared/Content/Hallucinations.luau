--!strict
-- Low-sanity hallucinations (content-data.md §3.19, §6.11; architecture.md §19.15; FEAT-019; script.md §8;
-- DEC-038, DEC-123, DEC-168, DEC-169, DEC-172, DEC-173). Owner: game-designer + art-director. Not a wire enum:
-- hallucinations are client-only (HallucinationController), never a prompt, never network, never a server state,
-- never count as an anomaly seen and never move the Walker.
-- MaxSanity: the effect may play while the player's own sanity is below this value (thresholds 60 / 40 / 20).
-- Effect: module name in HallucinationController/Effects/ (discovered).
-- Cooldown: seconds before the same effect can roll again. Weight: relative chance among the eligible effects.
-- post_flicker imitates the Walker's post WITHOUT the buzz (DEC-123): the buzz is the real N7 start sign.
-- Numbers Provisional (game-designer).
local Table = require(script.Parent.Table)

export type Hallucination = {
	Key: string,
	MaxSanity: number,
	Effect: string,
	Cooldown: number,
	Weight: number,
}

export type Rules = {
	Interval: { number }, -- {min, max} seconds between two rolls while eligible
	NightOnly: boolean, -- sanity exists only at night (DEC-056)
}

const rules: Rules = {
	Interval = { 20, 45 }, -- Provisional: rare enough to stay a surprise (DEC-173)
	NightOnly = true,
}

const base = Table.new({
	-- < 60
	{ Key = "fake_call", MaxSanity = 60, Effect = "FakeCall", Cooldown = 180, Weight = 1 }, -- wall phone rings, "Walt: ..."
	{ Key = "grill_hiss", MaxSanity = 60, Effect = "GrillHiss", Cooldown = 90, Weight = 1 }, -- sizzle on an empty grill
	-- < 40
	{ Key = "roof_steps", MaxSanity = 40, Effect = "RoofSteps", Cooldown = 90, Weight = 1 }, -- light steps on the roof
	{ Key = "ghost_customer", MaxSanity = 40, Effect = "GhostCustomer", Cooldown = 120, Weight = 1 }, -- gone on 2nd look
	{ Key = "post_flicker", MaxSanity = 40, Effect = "PostFlicker", Cooldown = 120, Weight = 1 }, -- no buzz (DEC-123)
	-- < 20
	{ Key = "whisper", MaxSanity = 20, Effect = "Whisper", Cooldown = 120, Weight = 1 }, -- "Rookie..."
	{ Key = "mart_sign_blink", MaxSanity = 20, Effect = "MartSignBlink", Cooldown = 180, Weight = 1 }, -- blinks once
	{ Key = "window_shadow", MaxSanity = 20, Effect = "WindowShadow", Cooldown = 120, Weight = 1 }, -- back window (AST-085)
} :: { Hallucination })

return Table.with(base, {
	Rules = Table.record(rules),
})
