--!strict
-- ANM-001 The blank folks (N1; TASK-111; anomalies.md N1; npcs.md NPC-009; DEC-051, DEC-195, DEC-204).
-- A faceless customer (actor Variant "blank": smooth face, empty order bubble, no breathing idle — client, TASK-112)
-- walks to the counter. Refuse = resolved. "Take Order" on it = Fail of who took it, arrival + Wrong in the ledger,
-- cue blank_coin (DEC-195 flavor: a coin with no design in the drawer, $0, visual only) and it walks off slowly.
-- Left waiting until patience runs out = no penalty. V2 (DEC-255): the error is jumpscare + faint, not -RuleBroken. Verb and numbers: Rules/ANM-001.luau. Body: Kit/CustomerActor.
-- Owner 2026-10-22 (Provisional; anomalies-after-accept-proposal.md §9): no REFUSE; its order is taken at the end of the
-- talk and it waits in the delivery queue. Not migrated yet: condition "Serve" (interim, no error); planned NoServe.
local Kit = require(script.Parent.Kit.CustomerActor)

return Kit.Module({
	Ref = "ANM-001",
	FailCue = "blank_coin",
	Scare = true, -- V2 error: jumpscare + faint (DEC-255, TASK-269)
})
