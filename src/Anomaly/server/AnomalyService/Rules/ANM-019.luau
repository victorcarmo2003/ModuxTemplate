--!strict
-- ANM-019 The roof walker, server rule (T10: never in shared). TASK-484 (DEC-294, DEC-295 / Q-367 A): "don't look up".
-- Something heavy walks across the roof; while it walks, whoever keeps the camera pitched up past LookPitch for
-- LookGrace s in a row pays -Sanity.RuleBroken (ctx.Fail, like any rule break) and it drops in front of them. Brief
-- glances are forgiven (shorter than LookGrace; the Gaze arrives at 10 Hz, the module ticks at 5 Hz). Surviving the
-- walk with the head down resolves it. Not critical (DEC-255). Mild (DEC-172). All numbers Provisional.
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
		LookPitch = 35, -- degrees above the horizon (Gaze pitch) that count as looking up
		LookGrace = 0.6, -- s in a row above LookPitch before it counts (a glance under ~0.5 s is forgiven)
		LeaveFor = 5, -- s the record stays Failed / Resolved so the drop or the leaving steps play, then Finish
	},
}

return rule
