--!strict
-- ANM-013 The white eyes (V2 family A, odd customer; DEC-254, DEC-255; TASK-292; anomalies-v2-proposal.md §3 A).
-- Sign: all-white eyes (face EyesWhite), ordinary look otherwise (actor Variant "eyes", client modifier Effects/Kit/OddCustomer).
-- Owner 2026-10-22 (Provisional; anomalies-after-accept-proposal.md §9): no REFUSE; its order is taken at the end of the
-- talk and it waits in the delivery queue (Kit/CustomerActor). Not migrated yet: condition "Serve" (interim, no error); planned Dark
-- (serve with the shop light off, proposal §2.2). Left waiting = nothing.
-- Verb and numbers: Rules/ANM-013.luau. Body: Kit/CustomerActor.
local Kit = require(script.Parent.Kit.CustomerActor)

return Kit.Module({
	Ref = "ANM-013",
	Scare = true,
})
