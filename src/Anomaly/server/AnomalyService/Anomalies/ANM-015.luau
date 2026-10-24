--!strict
-- ANM-015 The floater (V2 family A, odd customer; DEC-254, DEC-255; TASK-292; anomalies-v2-proposal.md §3 A).
-- Sign: it hovers a hand above the ground, no footsteps (actor Variant "float", client modifier Effects/Kit/OddCustomer).
-- Owner 2026-10-22 (Provisional; anomalies-after-accept-proposal.md §9): no REFUSE; its order is taken at the end of the
-- talk and it waits in the delivery queue (Kit/CustomerActor). Not migrated yet: condition "Serve" (interim, no error); planned Grounded
-- (serve while it is on the floor, proposal §2.7). Left waiting = nothing.
-- Verb and numbers: Rules/ANM-015.luau. Body: Kit/CustomerActor.
local Kit = require(script.Parent.Kit.CustomerActor)

return Kit.Module({
	Ref = "ANM-015",
	Scare = true,
})
