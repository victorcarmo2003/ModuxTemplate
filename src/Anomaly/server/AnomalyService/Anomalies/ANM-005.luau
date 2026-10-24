--!strict
-- ANM-005 The Raincoat Lady (N5; TASK-111; anomalies.md N5; npcs.md NPC-013; DEC-051, DEC-195, DEC-204).
-- Actor Variant "raincoat" (yellow raincoat, eyes closed, dripping on a dry night, full face — client, TASK-112)
-- orders like any customer. Serving her Complete/Perfect/Incomplete = resolved (incomplete pays the 50% floor, not an
-- error). "Refuse" = Fail of who refused. Patience running out = Fail of every active member (party target).
-- DEC-195: no +$1; rain over the trailer and "Thank you, dear." are not sent (no cue for them in Content).
-- Cue raincoat_drip (puddle) when she reaches Q1. Verb and numbers: Rules/ANM-005.luau. Body: Kit/CustomerActor.
-- Owner 2026-10-22 (Provisional; anomalies-after-accept-proposal.md §9): no REFUSE; its order is taken at the end of the
-- talk and it waits in the delivery queue (Kit/CustomerActor). Not migrated yet: condition "Serve" (interim):
-- served = Resolved; her patience out = -OmitSanity from every active player, no jumpscare (proposal §2.10).
local Kit = require(script.Parent.Kit.CustomerActor)

return Kit.Module({
	Ref = "ANM-005",
	CounterCue = "raincoat_drip",
})
