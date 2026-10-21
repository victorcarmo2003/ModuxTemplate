--!strict
-- ANM-019 The roof walker, server rule (T10: never in shared). TASK-484 (DEC-294, DEC-295 / Q-367 A): "don't look up".
-- Something heavy walks across the roof; while it walks, whoever keeps the camera pitched up past LookPitch for
-- LookGrace s in a row pays -Sanity.RuleBroken (ctx.Fail, like any rule break) and it drops on them from the ceiling.
-- The look is a readable countdown (owner 2026-10-19, Q-396): the client sees its own look go up at once, the stain on
-- the ceiling opens its eyes and the blur, the red and the heart climb for Effects/ANM-019 LOOK_WARN s (< LookGrace,
-- so the full warning always comes before the server can count it); looking down before LookGrace is forgiven (the
-- Gaze arrives at 10 Hz, the module ticks at 5 Hz, so the server never counts more than the look really lasted).
-- Surviving the walk with the head down resolves it. Not critical (DEC-255). Mild (DEC-172). All numbers Provisional.
local Api = require(script.Parent.Parent.Api)
local Hide = require(script.Parent.Parent.Anomalies.Kit.Hide)

const rule: Api.Rule = {
	Anomaly = Hide.KeyOf("ANM-019"),
	Verb = "dont_look",
	LikelyWrongVerb = "look_up",
	Window = 0,
	IsCritical = false,
	Params = {
		OmenFor = 3, -- s of Phase Signal: it lands on the roof (the thud, the dust, the lamps); looking up is forgiven
		WalkFor = 16, -- s of Phase Active: the walk from one end of the roof to the other (= Content.Score ANM-019 Ramp)
		LookFrom = 1, -- s into the walk before the rule counts (the reflex glance at the landing is forgiven)
		-- degrees above the horizon (Gaze pitch) that count as looking up. TASK-593: was 35; the shop's ceiling is ~4.4
		-- studs over the eye, so looking at the stain a few studs ahead is ~25-30 degrees and never counted (owner Play
		-- 2026-10-19). Mirrored in Effects/ANM-019 LOOK_PITCH; the scene's HeadDown nudges from 20.
		LookPitch = 22,
		LookGrace = 1.2, -- s in a row above LookPitch before it counts (Q-396: was 0.6, too short to read; = the countdown)
		LeaveFor = 5, -- s the record stays Failed / Resolved so the drop or the leaving steps play, then Finish
	},
}

return rule
